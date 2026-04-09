# Architecture

## Autoloads (Global Singletons)
| Name | File | Purpose |
|------|------|---------|
| EventBus | src/autoloads/event_bus.gd | Signal hub for decoupled communication |
| GameManager | src/autoloads/game_manager.gd | Game state, money, save/load, pause |
| InputManager | src/autoloads/input_manager.gd | Foot/vehicle/menu input context switching |
| WantedLevelManager | src/autoloads/wanted_level_manager.gd | Crime heat tracking, wanted level 0-5 |
| AudioManager | src/autoloads/audio_manager.gd | Bus management (SFX/Music/Ambient), play helpers |
| MissionManager | src/autoloads/mission_manager.gd | Mission lifecycle: generation, acceptance, tracking, completion (delivery/taxi/theft) |
| DayNightManager | src/autoloads/day_night_manager.gd | 24-hour cycle compressed to 20 real minutes; emits time_of_day_changed every 0.5 game-hours |
| SettingsManager | src/autoloads/settings_manager.gd | Persists display (fullscreen) and audio bus volumes to user://settings.cfg |

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
- Grid span: ~484m per tile (10 blocks × 40m + 11 roads; `BLOCK_SIZE = 40.0`)

## Infinite City (Phase 3)
- **Chunk-based generation**: `scenes/world/city.gd` orchestrates chunk load/unload
- One chunk = one full grid tile (~488m x 488m), stored in `_chunks: Dictionary[Vector2i, Node3D]`
- Chunks loaded within 2.0× grid_span, unloaded beyond 3.0× (checked every 0.5s via `UPDATE_INTERVAL`)
- Each chunk contains: roads, block ground, sidewalks, buildings, trees, ramps, lane markings
- **Builders** (split into `scenes/world/generator/`):
  - `chunk_builder_roads.gd` — merged road/ground/sidewalk meshes via SurfaceTool + compound collision
  - `chunk_builder_buildings.gd` — buildings grouped by material palette (12 colors), ~12 draw calls; window geometry split across 2 shared-material MeshInstance3D nodes (WindowsOff/WindowsOn) for GPU batching
  - `chunk_builder_trees.gd` — MultiMeshInstance3D with per-instance color, ~6 draw calls
  - `chunk_builder_markings.gd` — lane lines + zebra crossings, 1 draw call
  - `chunk_builder_ramps.gd` — fun ramps on boulevards
- **Performance**: ~22 draw calls/chunk, ~5 StaticBody3D/chunk (was ~1500/~960)
  - Shared material palette (~25 total) instead of ~550 unique materials per chunk
  - Window batching: 2 global shared materials (`_window_mat_off`/`_window_mat_on`) replace 8 per-chunk copies; geometry redistributed between WindowsOff/WindowsOn MeshInstance3D on day/night transitions rather than toggling emission per-material
  - SurfaceTool merges geometry into ArrayMesh per category
  - MultiMesh for trees with `use_colors = true` + `vertex_color_use_as_albedo`; flag pre-set on shared materials in `init()` so `_build_multimesh()` reuses them directly without `.duplicate()` per chunk
  - All per-builder transient materials (`_field_mat`, `_fence_mat`, `_sea_mat`) created once in `init()`, not inside `build()`
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
  - Spawn radius 120m, despawn 160m, min 60m from player; 2 spawns/tick every 1.0s
  - Picks random road + direction, uses `road_grid.gd` for road centers
  - Listens to `EventBus.vehicle_entered` to detect stolen vehicles
- **NPCVehicleController** (`scenes/vehicles/npc_vehicle_controller.gd`): AI waypoint driver
  - Uses `road_grid.gd` for infinite tiling — drives seamlessly across chunk boundaries
  - Drives intersection-to-intersection, random turns (no U-turns)
  - Right-hand lane offset (`road_width/4` from center)
  - PD controller for steering, proportional throttle; `CRUISE_SPEED = 40 km/h`
  - **Collision avoidance**: forward + side raycasts (mask=90: Static+PlayerVehicle+NPC+Police)
    - Forward ray (`RAY_LENGTH = 25m`): `< 3m` hard brake, `3-12m` proportional brake, `> 12m` normal
    - Side rays (±`SIDE_RAY_ANGLE = 20°`, `SIDE_RAY_LENGTH = 15m`): compare left/right hit distance → steer avoidance correction
    - Cross-intersection rays (`CROSS_RAY_LENGTH = 10m`, perpendicular to travel): set `_cross_traffic` flag for yield logic
  - **Stuck detection**: `STUCK_TIMEOUT = 0.8s` (0.4s when hitting a wall with obstacle close ahead); triggers multi-phase escape (REVERSE → STEER → RETURN)
  - `deactivate()` stops AI when player steals the vehicle
- **VehicleController** has `active` flag — only processes input when true
  - Driving state sets `active = true`, ExitingVehicle state sets `active = false`
  - Prevents all VehicleControllers from responding to input simultaneously
- Player added to `"player"` group for TrafficManager to find

## Police / Wanted System (Phase 5)
- **WantedLevelManager** autoload: heat accumulates from crimes, decays over time
  - Heat thresholds: [0, 20, 50, 100, 170, 260] for levels 0-5
  - 5s decay delay after last crime, then 3.0 heat/s decay
- **CollisionCrimeDetector**: monitors player vehicle collisions
  - Hit vehicle = 10 heat, hit pedestrian = 25 heat, vehicle theft = 30 heat
  - 1s cooldown per crime type to prevent spam
- **WantedHUD**: 5 stars top-right, flash yellow when active
- **PoliceManager**: spawns police on roads when wanted > 0
  - Max police per level: `[0, 3, 5, 8, 12, 16]` for levels 0-5; spawn radius 180m, despawn 250m
  - Gradual 10s despawn when wanted drops to 0; spawns helicopter at level 5
- **PoliceAIController**: PATROL (road following) / PURSUE (chase player)
  - LOS detection: `LOS_RANGE = 100m`; within `LOS_LOCK_RANGE = 80m` pursuit is never abandoned
  - `LOS_LOST_TIMEOUT = 40s` before dropping pursuit; `LOS_CHECK_INTERVAL = 0.2s`
  - Officers dismount within `DISMOUNT_RANGE = 12m`, up to 2 per car, 15s cooldown
  - Pursuit speed `PURSUIT_SPEED = 60 km/h`; patrol speed `PATROL_SPEED = 40 km/h`
  - A* road-graph pathfinding refreshed every 2s; direct chase within 30m
- **Police vehicle**: white/blue, red/blue light bar, procedural siren

### Police Officer (On Foot)
- **File**: `scenes/police/police_officer.gd`
- **CharacterBody3D**, group `"police_officer"`, `collision_layer = 4` (NPC), `collision_mask = 3` (Ground + Static)
- Spawned by **PoliceAIController** when vehicle is within `DISMOUNT_RANGE`; builds greybox model procedurally in `_build_model()`
- **Chase**: moves at `CHASE_SPEED = 5.5 m/s` toward player (or player's current vehicle); faces movement direction each frame
- **Shooting**: fires within `SHOOT_RANGE = 30m` every `SHOOT_COOLDOWN = 1.2s` (±0.2s jitter); performs LOS raycast against layers 1+2 before firing; 60% hit chance per shot dealing `SHOOT_DAMAGE = 8 HP`
- **Audio**: procedural gunshot via `AudioStreamGenerator` — short 0.08s noise burst with quadratic envelope
- **Limb animation**: shoulder and hip pivot nodes animated on a sine-based run cycle; right arm raises to aim pose (`-PI/2`) during `_shoot_pose_timer = 0.4s` after each shot
- **Despawn**: `queue_free()` when distance to player exceeds `DESPAWN_DIST = 80m`
- Targets player vehicle position when player is driving (`current_vehicle` property check)

## Audio System (Phase 9)
- **AudioManager** autoload: creates SFX/Music/Ambient buses
- **EngineAudio**: procedural AudioStreamGenerator on every vehicle
  - Frequency 80-300 Hz mapped to speed, 2 harmonics, idle wobble
- **PoliceSiren**: two-tone wail 600-800 Hz, active during pursuit
- **TireScreechAudio**: filtered noise on lateral slip / handbrake
- **AmbientAudio**: city drone (55+82 Hz) + random horn honks
- **UISounds**: ascending/descending tones for wanted level changes

## Pedestrian System (Phase 7)
- **PedestrianModel**: greybox capsule+box head, 8 random colors
- **Pedestrian**: CharacterBody3D (layer 6) with state machine
  - Walk (1.4 m/s on sidewalks), Idle (2-8s), Flee (4 m/s from vehicles)
  - ProximityArea (8m sphere) detects vehicles > 5 km/h
  - Hit by player vehicle: queue_free + crime_committed
- **PedestrianManager**: spawn radius 80m, despawn 100m (50m behind when moving), min 35m from player; sidewalk placement; spawn rate scales with time of day (0.3× at night, 0.6× at dawn/dusk, 1.0× daytime)

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

## Boat System
- **BoatController** (`scenes/vehicles/boat_controller.gd`): Archimedes buoyancy on a RigidBody3D
  - 8 hull sample points (local y=−0.3) × 4900 N/m depth force each
  - Buoyancy always runs (boat floats when unoccupied); thrust/steering only when `active = true`
  - Anti-roll torque (`_stabilize`) keeps boat level; wave height uses sine function
  - `set_passenger(mass)` adds player weight to `_body.mass` so displacement accounts for rider
- **Waterline occluder** (`scenes/vehicles/boat_body_builder.gd` + `boat_body_init.gd`):
  - `_build_waterline_cap(profiles)` returns a flat opaque mesh at local y≈0.05
  - Instantiated as `WaterlineCap` MeshInstance3D inside the `Body` node
  - Dark bilge colour (fully opaque) depth-occludes the water plane from inside the hull
- **Boat seating** (`scenes/player/states/driving.gd`):
  - Player origin (feet) placed at boat local y=−0.50 so hip pivot (y+0.80) aligns with seat top (y=0.30)
  - Manual gravity settling: `_boat_seat_vel_y -= 9.8 * delta` each frame until reaching seat_world.y
  - Player X/Z locked to seat local position each frame so they follow the moving boat

## Pier Generation (`scenes/world/generator/chunk_builder_piers.gd`)
- `build()` finds a coastal edge, builds pier geometry + collision, spawns 1–2 boats
- **Pier collision**: BoxShape3D dimensions derived from `pier_dir` — `PIER_LENGTH` goes on the axis the pier runs along so X-axis piers get correct 12 m span (was always 12 m on Z, causing fall-through)
- Box thickness 0.5 m, centre lowered by half-thickness so top face is flush with deck
- **Boat spawn**: placed at `PIER_LENGTH + 2.0 + i*4.0` from shore (was `PIER_LENGTH * 0.8` — inside pier)
- Lateral offset `PIER_WIDTH/2 + 3.5` keeps boats clear of dock edge and shore

## Player Fall Damage (`scenes/player/player.gd`)
- `_fall_peak_y` records the highest y reached since leaving the floor
- On landing: `fall_dist = _fall_peak_y - landing_y`; damage = `(fall_dist − 3.0) × 10 HP/m`
- Safe threshold 3 m (curb/small ledge); ~50 HP at 8 m; lethal at ~13 m
- Calls `GameManager.take_damage()` — HUD and death logic respond normally

## Weapon System (`scenes/player/player_weapon.gd`)
- 4 weapons: Pistol, SMG, Shotgun, Rifle (switched with keys 1–4 or mouse wheel)
- Raycast from PlayerCamera pivot through crosshair (anchor 35% screen height)
- **Effective ranges**: Pistol 80 m, SMG 70 m, Shotgun 40 m, Rifle 200 m
- Spread (cone half-angle in radians): Pistol 0.0, SMG 0.03, Shotgun 0.08, Rifle 0.005
- Shotgun fires 6 pellets; each pellet deals `total_damage / pellets`
- Hits: pedestrians → ragdoll + crime; police → ragdoll + crime; RigidBody3D → impulse + VehicleHealth; StaticBody3D → bullet decal
- Procedural gunshot audio via AudioStreamGenerator (snap + body tone + filtered tail)

## Performance Budget
- 60 FPS at 1080p
- NPC vehicles: spawn 120m, despawn 160m; police: spawn 180m, despawn 250m; pedestrians: spawn 80m, despawn 100m
- ~22 draw calls per chunk, ~5 StaticBody3D per chunk, ~25 shared materials total

## Helicopter System
- **Files**: `scenes/vehicles/helicopter.gd` + `scenes/vehicles/helicopter_controller.gd`
- **CharacterBody3D**, group `"helicopter"`, `collision_layer = 16` (NPC vehicles), `collision_mask = 3` (Ground + Static)
- All geometry built procedurally at `_ready()` via `helicopter_body_builder.gd`; fuselage has two surfaces (opaque body + translucent glass)
- **InteractionArea** (Area3D, `collision_layer = 256`, group `vehicle_interaction`) allows player boarding same as cars
- **DoorMarker** at local `(-3.5, 0, 0)` — player spawns here on dismount
- **HelicopterController** (`extends Node`, `active` flag): mirrors VehicleController/BoatController interface
  - `ASCEND_FORCE = 24.0 m/s`, `DESCEND_FORCE = 8.0 m/s`, `HOVER_SINK = 1.5 m/s` passive sink when no vertical input
  - `FORWARD_SPEED = 42.0 m/s`, `BACK_SPEED = 15.0 m/s`, `YAW_SPEED = 1.8 rad/s`
  - Controls: W/S = pitch/forward-back, A/D = yaw (tail rotor), Space = ascend (jump action), Shift = descend (sprint action)
  - Visual tilt: `TILT_MAX = 0.22 rad`, `TILT_RATE = 4.0`; Body node X/Z rotation follows pitch/yaw inputs via lerp
  - Rotor animation: main rotor `ROTOR_SPIN = 20.0 rad/s` (Y-axis), tail rotor `TAIL_ROTOR_SPIN = 32.0 rad/s` (X-axis)
- When unoccupied (`active = false`) helicopter falls under gravity (`GRAVITY = 9.8`) via `move_and_slide()`
- Spawned on helipads by `chunk_builder_helipad.gd` at `HELI_SPAWN_Y = 1.85` above pad surface

## Radio System
- **File**: `scenes/world/radio_system.gd`; placed as a child node inside vehicle scenes
- Press T (`radio_next` action) to cycle through stations or turn off
- **5 genre stations**: Pop (`"Little Car FM Pop"`), Rock (`"Car Rock Radio"`), Jazz (`"Smooth Jazz Drive"`), Electronic, Classical
- **Playback**: `AudioStreamPolyphonic` plays melody, bass, and percussion simultaneously; notes generated by pitching sample files via `pitch_scale`
- **Chord progressions**: 6 pre-defined progressions (I-IV-V-I, I-V-vi-IV, I-vi-IV-V, etc.) as scale-degree index arrays
- **16-step drum patterns** per genre; each step carries velocities for kick, snare, hi-hat, open hat
- **Drum samples**: kick, snare, snare_brush, hi-hat closed/open, ride (preloaded WAVs from `assets/audio/samples/drums/`)
- **Melodic samples**: piano, guitar_dist, bass_guitar, sax, upright_bass, synth_lead, synth_bass, violin (from `assets/audio/samples/melodic/`)
- **Station switching** includes a short static burst (`STATIC_DURATION = 0.4s`) via `AudioStreamGenerator`
- **DJ chatter**: TTS-based lines play on a `DJ_INTERVAL_MIN/MAX = 25–50s` timer per station; each genre has 4 DJ lines
- **Police scanner**: plays announcements every `POLICE_ANNOUNCE_INTERVAL = 20s` when player has wanted level > 0
- Music interval between notes: `MUSIC_INTERVAL_MIN/MAX = 2–5s`

## Terrain & Biome System
- **Biome assignment** (`src/biome_map.gd`): every chunk tile gets a biome string before generation
  - Inner ~60% of city boundary radius → `"city_center"`; rest of boundary → `"city"`
  - 1-tile ring outside boundary → `"suburb"`
  - West of `OCEAN_WEST_THRESHOLD = -2.5 × grid_span` → `"ocean"`
  - Rural biomes noise-driven: `"mountain"` (high noise + far from city), `"forest"`, `"village"` (secondary noise check), `"farmland"` (default)
  - `is_city_biome()` returns true for city/city_center/suburb — those chunks use the road-grid builders
- **City chunk load path** (biome is city/suburb): runs road, building, tree, marking, ramp, light, window builders as before; suburb biome additionally runs `chunk_builder_suburb.gd` in place of city buildings
- **Terrain chunk load path** (non-city biomes): runs `chunk_builder_terrain.gd` first, then biome-specific overlays

### Terrain builders (non-city chunks)

| Builder | File | What it produces |
|---------|------|-----------------|
| `chunk_builder_terrain` | `generator/chunk_builder_terrain.gd` | 16×16 subdivided heightmap mesh with vertex color (water/sand/grass/rock/snow by height) + HeightMapShape3D collision on layer 1 (`"Road"` group); sea plane if `min_height < SEA_LEVEL (-2.0)`; edge-height constraints blended 3 cells inward for seamless chunk borders; river carving depresses terrain 2 m along river path |
| `chunk_builder_mountain` | `generator/chunk_builder_mountain.gd` | 5–15 random rock formations (BoxMesh) on terrain cells `h > 15 m`; StaticBody3D collision on layer 2; seed `hash(tile) ^ 0x12CC` |
| `chunk_builder_river` | `generator/chunk_builder_river.gd` | Translucent water plane strip from entry to exit edge; 8 subdivisions following terrain height minus `RIVER_DEPTH (2.0 m)`; alpha 0.55 semi-transparent material |
| `chunk_builder_rural_roads` | `generator/chunk_builder_rural_roads.gd` | Dark asphalt road strips along highway indices 0 and 5 (N-S and E-W); follows terrain height with `ROAD_Y_OFFSET = 0.15 m`; skips underwater segments; per-segment BoxShape3D collision in `"Road"` group |
| `chunk_builder_rural_trees` | `generator/chunk_builder_rural_trees.gd` | Roadside trees (spaced 20–30 m, 5 m from road edge) + forest clusters; 6 canopy variants (sphere, cone, tall, flat, sphere2, pine); MultiMeshInstance3D per variant; density varies by biome (forest: 4–7 clusters, mountain: 2–4, farmland: 1–2) |
| `chunk_builder_farmland` | `generator/chunk_builder_farmland.gd` | 3–7 colored field quads (30–80 m, green/wheat/plowed/dark green) + wood fences (60% chance); vertex color material; no collision on fields |
| `chunk_builder_villages` | `generator/chunk_builder_villages.gd` | 0–1 village per chunk (40% chance); finds flat spot (`FLATNESS_THRESHOLD = 2 m` variance over 30 m radius); 3–8 small buildings (4–8 m) with pitched roofs; MultiMaterial merged mesh; seed `hash(tile) ^ 0xBEEF` |
| `chunk_builder_suburb` | `generator/chunk_builder_suburb.gd` | ~50% of blocks get 1–2 residential buildings (3–8 m tall, 6–14 m footprint, wider 4 m yard margins); pitched roofs; residential-scale windows (0.7×0.8 m); doors on random face; same WindowsOn/WindowsOff batching as city buildings; interior geometry; seed `hash(tile) ^ 0x50BB` |
| `chunk_builder_bridge` | `generator/chunk_builder_bridge.gd` | Road deck (`DECK_WIDTH = 10 m`, `DECK_THICKNESS = 0.4 m`) + railings (`RAILING_HEIGHT = 1 m`) where highways cross rivers; in `"Road"` group; only built when `river_data` is non-empty |
| `chunk_builder_helipad` | `generator/chunk_builder_helipad.gd` | 2 helipads per suburb chunk (`PAD_SIZE = 14 m`); concrete pad + `"H"` marking decal; spawns parked helicopter at `HELI_SPAWN_Y = 1.85` above surface; pad in `"helipad"` group with `helipad_center` meta for minimap |

- River data flows from `_river_map` (stored in `city.gd`) into terrain, river, and bridge builders via `tile_data`/`river_data` dictionaries
- All terrain StaticBody3D on layer 1 + `"Road"` group so GEVP tire physics work on rural roads and helipads

## Vehicle Health
- **File**: `scenes/vehicles/vehicle_health.gd` (`extends Node`, child of RigidBody3D vehicle)
- `MAX_HEALTH = 100.0`; damage sources: bullets via `take_damage(amount, hit_pos, hit_normal)`, emits `EventBus.vehicle_damaged`
- **Visual feedback**: body mesh darkens proportional to damage (`ratio = health / MAX_HEALTH`); bullet hole decals (0.15 m PlaneMesh, max `MAX_BULLET_HOLES = 10`, oldest removed when limit exceeded)
- **Fire threshold**: `FIRE_THRESHOLD = 30.0 HP`; at or below triggers GPUParticles3D fire (orange-yellow color ramp, `FIRE_AMOUNT = 60`) + smoke particles (`SMOKE_AMOUNT = 30`); crackling fire audio via `AudioStreamGenerator`
- **Burn timer**: `BURN_TIME = 6.0s` after catching fire → `_explode()`
- **Explosion**: emits `EventBus.force_exit_vehicle` + `EventBus.vehicle_destroyed`; applies 500 N upward impulse; deactivates NPC/police controllers; kills light bar and siren; body turns fully black; vehicle frozen in place (`freeze = true`)

## Weapon Pickups
- **File**: `scenes/world/weapon_pickup.gd` (`extends Node3D`)
- `weapon_idx` exported var selects which weapon from `PlayerWeapon.WEAPONS` array
- Mesh built at `_ready()` via `src/weapon_mesh_builder.gd`; emission glow added (blue, energy 0.5)
- `MeshPivot` node bobs (`sin(_spin_time * 2.0) × 0.1 m`) and rotates (`1.5 rad/s`)
- **Trigger**: Area3D detects player (group `"player"`) or player vehicle (collision_layer bit 3/8); finds `PlayerWeapon` node and calls `unlock_weapon(weapon_idx)`; `queue_free()` on pickup

## Building Interiors
- **File**: `scenes/world/building_door.gd` (`extends Node3D`, created by `chunk_builder_buildings._create_door_node()`)
- Door opens/closes on `interact` (F key) when player is in `InteractionZone`; animated via `Tween` over `ANIM_DURATION = 0.3s` to `OPEN_ANGLE = -1.2 rad`
- Auto-closes after `AUTO_CLOSE_DELAY = 10s` via one-shot Timer
- Shows `"[F] Open"` / `"[F] Close"` via `EventBus.show_interaction_prompt` / `hide_interaction_prompt`
- City and suburb buildings with a wide enough door face (`>= DOOR_WIDTH + 0.5 = 1.7 m`) get a door node; narrower faces use solid box geometry

## Player Flashlight
- **File**: `scenes/player/player_flashlight.gd` (`extends SpotLight3D`, child of player scene)
- Toggles with `toggle_flashlight` action (L key); `_manual_off` flag prevents auto-on when manually turned off
- **Auto-on**: subscribes to `EventBus.time_of_day_changed`; turns on automatically during night or dusk/dawn (`DayNightManager.is_night()` / `is_dusk_or_dawn()`)
- **Aim**: each frame resolves active Camera3D from viewport and `look_at()` target 50 m along camera forward direction

## Mission System
- **MissionManager** autoload (`src/autoloads/mission_manager.gd`): mission lifecycle management
  - `MAX_AVAILABLE = 8` missions offered at once; refreshed every `REFRESH_INTERVAL = 20s` when no mission is active
  - `_available_missions: Array[Dictionary]` + `_active_mission: Dictionary` (plain Dictionaries, no class_name)
- **Mission Dictionary keys**: `id` (unique string), `type` ("delivery"/"taxi"/"theft"), `title`, `objective`, `reward` (int, dollars), `time_limit` (0.0 = none), `state` ("available"/"pickup"/"active"/"completed"/"failed"), `start_pos`, `pickup_pos`, `dropoff_pos`, `vehicle_variant`
- **Mission types**:
  - **Delivery**: start → pickup (40–150 m away) → dropoff (150–400 m away); reward $300–800; time limit 90–150s
  - **Taxi**: player must be in a vehicle to accept; dropoff 100–300 m from start; reward $200–500; time limit 60–120s
  - **Theft**: steal a specific vehicle variant (sedan/sports/suv/hatchback/van/pickup); no time limit; reward $500–1500; dropoff spawns after player enters matching vehicle
- **Progression**: `accept_mission()` → marker_reached("pickup") → marker_reached("dropoff") → `complete_mission()`; `GameManager.add_money(reward)` on completion; first completion also unlocks SMG weapon
- **MissionMarkerManager** (`scenes/missions/mission_marker_manager.gd`): spawns/despawns `MissionMarker` instances in response to EventBus signals; colors: start=green, pickup=blue, dropoff=yellow
- **MissionMarker** (`scenes/missions/mission_marker.gd`): glowing emissive column (`extends Node3D`, group `"mission_marker"`); pulses X/Z scale (±10%); snaps to ground via raycast on layer 1; emits `EventBus.mission_marker_reached(mission_id, marker_type)` when player or player vehicle enters trigger

## Vehicle Water Interaction
- **File**: `scenes/vehicles/vehicle_water_detector.gd` (`extends Node`, child of RigidBody3D vehicles)
- Disabled automatically on boats (`BoatController` present) — boats use buoyancy instead
- Polls every `CHECK_INTERVAL = 0.1s`; triggers when `vehicle.global_position.y <= SEA_LEVEL (-2.0)` AND terrain height at that XZ position is below sea level (ocean tile, not underground)
- **Sinking behavior** (one-shot, `_sinking` flag prevents re-trigger):
  - Sets `linear_damp = 2.0`, `angular_damp = 3.0` to simulate water resistance
  - Emits `EventBus.force_exit_vehicle` (ejects player) + `EventBus.vehicle_entered_water`
  - Deactivates NPC/police controllers; kills vehicle lights and engine audio
  - Spawns `GPUParticles3D` bubble effect (30 particles, `lifetime = 2.0s`, blue-tinted spheres rising upward)
