# Architecture

## Autoloads (Global Singletons)
| Name | File | Purpose |
|------|------|---------|
| EventBus | src/autoloads/event_bus.gd | Signal hub for decoupled communication |
| GameManager | src/autoloads/game_manager.gd | Game state, money, save/load, pause |
| InputManager | src/autoloads/input_manager.gd | Foot/vehicle input context switching |

More autoloads will be added: AudioManager, WantedLevelManager, MissionManager, WorldManager.

## Player System
- **CharacterBody3D** with capsule collider (layer 3/PlayerFoot, mask 1+2)
- **6 states**: Idle, Walking, Running, EnteringVehicle, Driving, ExitingVehicle
- **PlayerCamera**: mouse-look orbit via SpringArm3D, follows parent position
- **InteractionArea** (Area3D, mask layer 9/Trigger) detects nearby vehicles
- **PlayerUI** (CanvasLayer): InteractionPrompt + StealProgressBar
- Camera-relative WASD movement, player rotates to face movement direction

## Vehicle Enter/Exit
- Vehicle has **InteractionZone** (Area3D, layer 9, group `vehicle_interaction`)
- Player walks near vehicle -> prompt appears -> hold F 1.5s to steal
- Driving state: hides player, switches InputManager to VEHICLE, activates VehicleCamera
- Exit: teleports player to DoorMarker, restores FOOT context, player camera

## Camera System
- **PlayerCamera** (`scenes/player/player_camera.gd`): mouse-look orbit, active in FOOT context
- **VehicleCamera** (`scenes/vehicles/vehicle_camera.gd`): speed-based chase cam, child of vehicle scene
- States call `make_active()` on the appropriate camera to swap

## Key Patterns
- **Node-based state machines** for player, police, pedestrians, traffic
- **EventBus signals** for cross-system communication
- **Composition over inheritance** for game entities
- **Data-driven config** via exported vars and custom Resources
- **Object pooling** for spawnable entities (traffic, pedestrians, police)

## Road Grid (`src/road_grid.gd`)
- **RefCounted** utility — no `class_name`, used via `preload("res://src/road_grid.gd").new()`
- Single source of truth for all grid constants (GRID_SIZE, BLOCK_SIZE, road widths, etc.)
- Precomputes road centers at `_init()`, provides infinite tiling via `roundf()`:
  - `get_road_center_local(i)` — center within one tile
  - `get_road_center_near(i, ref)` — nearest world-space center to any reference coordinate
  - `get_nearest_road_index(coord)` — closest road index at any world position
  - `get_chunk_coord(pos)` / `get_chunk_origin(chunk)` — tile coordinate mapping
- Grid span: ~488m per tile (10 blocks + 11 roads)

## Infinite City (Phase 3)
- **Chunk-based generation**: `scenes/world/city.gd` orchestrates chunk load/unload
- One chunk = one full grid tile (~488m x 488m), stored in `_chunks: Dictionary[Vector2i, Node3D]`
- Chunks loaded within 1.2x grid_span, unloaded beyond 1.5x (checked every 0.5s, max ~4 chunks)
- Each chunk contains: roads, block ground, sidewalks, buildings, trees, ramps, lane markings
- **Builders** (split into `scenes/world/generator/`):
  - `chunk_builder_roads.gd` — merged road/ground/sidewalk meshes via SurfaceTool + compound collision
  - `chunk_builder_buildings.gd` — buildings grouped by material palette (12 colors), ~12 draw calls
  - `chunk_builder_trees.gd` — MultiMeshInstance3D with per-instance color, ~6 draw calls
  - `chunk_builder_markings.gd` — lane lines + zebra crossings, 1 draw call
  - `chunk_builder_ramps.gd` — fun ramps on boulevards
- **Performance**: ~22 draw calls/chunk, ~5 StaticBody3D/chunk (was ~1500/~960)
  - Shared material palette (~25 total) instead of ~550 unique materials per chunk
  - SurfaceTool merges geometry into ArrayMesh per category
  - MultiMesh for trees with `use_colors = true` + `vertex_color_use_as_albedo`
  - Compound collision bodies: one StaticBody3D with many BoxShape3D children
- **Buildings**: deterministic per-chunk RNG seeded with `hash(tile)`, 1-4 per block
- **Trees**: seeded with `hash(tile) ^ 0x7F3A` for independent variety
- **Lane markings**: dashed center lines, solid edge lines, boulevard double-center + lane dividers
- **Zebra crossings**: at every intersection (4 per intersection, bars perpendicular to traffic)
- **Safety ground**: WorldBoundaryShape3D at Y=-5 (infinite, created once)
- All road/sidewalk surfaces in group `"Road"` for GEVP tire friction
- Road widths: 8m standard, 12m boulevard (index 5), 4m alley (index 2)

## NPC Traffic (Phase 4)
- **TrafficManager** (`scenes/world/traffic_manager.gd`): spawns/despawns NPC vehicles around player
  - Spawn radius 200m, despawn 250m, max 80 vehicles, min 40m from player
  - Timer-based (0.5s interval, 3 spawns/tick), picks random road + direction
  - Uses `road_grid.gd` for road centers — spawns on correct roads at any world position
  - Listens to `EventBus.vehicle_entered` to detect stolen vehicles
- **NPCVehicleController** (`scenes/vehicles/npc_vehicle_controller.gd`): AI waypoint driver
  - Uses `road_grid.gd` for infinite tiling — drives seamlessly across chunk boundaries
  - Drives intersection-to-intersection, random turns (no U-turns)
  - Right-hand lane offset (`road_width/4` from center)
  - PD controller for steering, proportional throttle
  - **Collision avoidance**: forward + side raycasts (mask=26: Static+PlayerVehicle+NPC, every 5 frames)
    - Forward ray (20m): `< 5m` hard brake, `5-15m` proportional brake, `> 15m` normal
    - Side rays (±20°, 15m): compare left/right hit distance → steer avoidance correction
  - `deactivate()` stops AI when player steals the vehicle
- **VehicleController** has `active` flag — only processes input when true
  - Driving state sets `active = true`, ExitingVehicle state sets `active = false`
  - Prevents all VehicleControllers from responding to input simultaneously
- Player added to `"player"` group for TrafficManager to find

## Pause Menu
- **File**: `scenes/ui/menus/pause_menu.gd` + `.tscn`
- CanvasLayer with `process_mode = PROCESS_MODE_ALWAYS`
- Toggled by `pause` input action (Esc key)
- Pauses scene tree, shows semi-transparent overlay + Resume/Quit buttons
- Saves and restores InputManager context (FOOT/VEHICLE) around pause

## Collision Layers
| Layer | Name | Used By |
|-------|------|---------|
| 1 | Ground | Terrain, ground plane |
| 2 | Static | Buildings, barriers, props |
| 3 | PlayerFoot | Player CharacterBody3D (on foot) |
| 4 | PlayerVehicle | Vehicle driven by player |
| 5 | NPCVehicle | Traffic cars, parked cars |
| 6 | Pedestrian | NPC pedestrians |
| 7 | Police | Police vehicles and officers |
| 8 | Projectile | Bullets, explosions |
| 9 | Trigger | Interaction areas, mission triggers |
| 10 | Navigation | NavMesh obstacles |

## Performance Budget
- 60 FPS at 1080p
- Max 80 NPC vehicles, 30 pedestrians
- Spawn radius 200m, despawn 250m
- ~22 draw calls per chunk, ~5 StaticBody3D per chunk, ~25 shared materials total
