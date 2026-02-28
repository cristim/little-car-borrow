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

## City Layout (Phase 3)
- **Builder script**: `scenes/world/city.gd` generates all geometry procedurally at `_ready()`
- **Grid**: 10x10 blocks, 11 N-S + 11 E-W roads
- **Road widths**: 8m standard, 12m boulevard (index 5), 4m alley (index 2)
- **Sidewalks**: 2.5m wide strips on each road side, 0.15m above road surface
- **Buildings**: 1-3 per block, seeded RNG (seed 42), 5-20m tall, muted colors, layer 2
- **Trees**: cylinder trunk + sphere canopy every 15m along sidewalks, layer 2
- **Ramps**: 4 tilted-box ramps on boulevard and cross-streets, group "Road", layer 1
- **Safety ground**: WorldBoundaryShape3D at Y=-5, group "Road"
- All road/sidewalk surfaces in group `"Road"` for GEVP tire friction

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
- Max 20 active NPC vehicles, 30 pedestrians
- Spawn radius 200m, despawn 250m
