# Technical Decisions

## 2026-02-27: Vehicle Physics System
- **Decision**: Use GEVP (Godot Easy Vehicle Physics) with custom VehicleController
- **Alternatives**: Built-in VehicleBody3D, KidsCanCode sphere-car, VitaVehicle
- **Rationale**: GEVP provides raycast-based RigidBody3D with detailed tire/suspension physics. MIT licensed. Works with Godot 4.5. Has arcade car preset we can start from. We write our own controller to map our input actions instead of using GEVP's VehicleController (which expects different input map names).
- **Status**: Validated - cloned from GitHub, code reviewed, well-structured Vehicle/Wheel separation

## 2026-03-30: Boat Buoyancy — Archimedes vs Simple Spring
- **Decision**: Volume-based Archimedes buoyancy (8 hull points × ρ·g·A·depth)
- **Alternatives**: Single spring force at centre of mass; 4-point linear spring
- **Rationale**: 4-point linear spring at constant `BUOYANCY_STRENGTH` gave equilibrium below sea level — boat interior appeared flooded. Archimedes formula gives correct equilibrium draft (≈0.22 m) so the deck stays above water. 8 distributed points also provide realistic pitch/roll response.
- **Status**: Implemented in `boat_controller.gd`

## 2026-03-30: Boat Seating — Manual Gravity vs Physics Bench Collision
- **Decision**: Manual gravity settling in `driving.gd` (`_boat_seat_vel_y -= 9.8 * delta`)
- **Alternatives**: Add a bench `CollisionShape3D` inside the boat RigidBody3D and re-enable player `move_and_slide()`
- **Rationale**: Player physics is disabled while driving (prevents interference with vehicle movement). Adding a bench collider inside a RigidBody3D with a CharacterBody3D is fragile — the nested rigid/character physics can jitter. Manual settling is deterministic and has zero physics coupling.
- **Status**: Implemented in `driving.gd`; player origin targets local y=−0.50 (hip pivot aligns with seat top at y=0.30)

## 2026-02-28: Player + Vehicle Enter/Exit Architecture
- **Decision**: Single player scene with 6-state StateMachine. Two independent cameras (PlayerCamera + VehicleCamera) swap via `make_active()`. VehicleCamera is a child of the vehicle scene. InputManager context (FOOT/VEHICLE) guards both player camera and vehicle_controller inputs.
- **Alternatives**: Separate player-on-foot and player-driving scenes, unified camera that morphs between modes
- **Rationale**: Single scene avoids complexity of spawning/despawning player nodes. Dual cameras are simpler than a morphing camera - each mode has its own tuning. VehicleCamera as vehicle child means each vehicle type can customize its camera. InputManager guard in vehicle_controller prevents ghost inputs when on foot.
- **Status**: Implemented - Phase 2 complete

## 2026-03-02: Road Grid Utility — RefCounted vs Node/Autoload
- **Decision**: `road_grid.gd` extends `RefCounted`; instantiated on demand via `preload("res://src/road_grid.gd").new()`
- **Alternatives**: Autoload singleton; Node attached to a scene
- **Rationale**: The road grid is pure math (no scene tree membership, no signals, no `_process`). RefCounted keeps it allocation-scoped and avoids scene-tree pollution. Any script that needs road math can instantiate it locally without depending on a globally registered autoload, making tests straightforward and eliminating hidden coupling.
- **Status**: Implemented in `src/road_grid.gd`; used by `npc_vehicle_controller.gd`, `police_ai_controller.gd`, `mission_manager.gd`, and chunk builders

## 2026-03-03: Mission System Data Model — Plain Dictionary vs Resource/class_name
- **Decision**: Missions are plain GDScript `Dictionary` values; no `class_name`, no `Resource` subclass
- **Alternatives**: `MissionData` Resource subclass; custom `class_name MissionData` script
- **Rationale**: `class_name` is broken in Godot 4.5 — it causes cascading parse errors across the project (see MEMORY.md). Resources require file-backed `.tres` files or a registered class name, both of which hit the same issue. Plain Dictionaries are reliable, require no type registration, and support duck-typed field access (`mission.get("type", "")`). The tradeoff (no static typing) is acceptable because all mission creation is in `mission_manager.gd`.
- **Status**: Implemented in `src/autoloads/mission_manager.gd`

## 2026-03-08: Terrain Biome System — Deterministic Noise-Based Assignment vs Runtime Procedural Dispatch
- **Decision**: Per-tile biome assigned deterministically in `biome_map.gd` using a fixed-seed `FastNoiseLite` (seed 123) combined with distance from city boundary and terrain noise
- **Alternatives**: Assign biome at chunk build time using random state; fully procedural per-vertex coloring without biome concept
- **Rationale**: A fixed seed means any tile coordinate always resolves to the same biome regardless of load order or player position — essential for an infinite world where chunks are loaded and unloaded continuously. Runtime random dispatch would produce different biomes on reload. The noise+distance formula gives geographically coherent regions (suburb ring → farmland → forest → mountain) without baking or pre-computation.
- **Status**: Implemented in `src/biome_map.gd`; dispatches to `chunk_builder_suburb`, `chunk_builder_farmland`, `chunk_builder_mountain`, `chunk_builder_villages`

## 2026-03-08: NPC Road-Following — Waypoint Intersection Approach vs NavMesh
- **Decision**: NPC vehicles follow roads by tracking the nearest road-grid intersection as a waypoint, computed each frame from `road_grid.gd` math
- **Alternatives**: Godot NavigationServer3D with baked NavMesh; A* over a discrete road graph
- **Rationale**: NavMesh requires baking against static geometry — impossible in an infinite procedural world where roads extend indefinitely in all directions. A* over a pre-built graph has the same pre-computation problem. The road grid provides exact lane-centre positions at any world coordinate via `get_road_center_near()`, so NPC steering needs only a heading vector and a lane-error scalar. No baking, no memory overhead for path nodes, and it works at any player-reachable distance.
- **Status**: Implemented in `scenes/vehicles/npc_vehicle_controller.gd` (extends `vehicle_ai_base.gd`)

## 2026-03-29: Helicopter Flight Model — CharacterBody3D with Manual Velocity vs RigidBody3D
- **Decision**: Helicopter uses `CharacterBody3D`; `helicopter_controller.gd` sets `velocity` directly and calls `move_and_slide()` each physics frame
- **Alternatives**: `RigidBody3D` with `apply_central_force` / torque for lift and thrust
- **Rationale**: `RigidBody3D` introduces unwanted physics coupling: gravity, angular drag, and integration drift make hover feel floaty and precise altitude control difficult. Flight-sim style controls (collective up/down, yaw, forward/back) map cleanly onto direct velocity assignment — `CharacterBody3D.move_and_slide()` handles collision response without the instability of competing forces. The same pattern is used by the player on foot, keeping the codebase consistent.
- **Status**: Implemented in `scenes/vehicles/helicopter_controller.gd`

## 2026-04-08: Weapon Impulse — Local-Space vs World-Space Offset
- **Decision**: `apply_impulse(impulse, body.to_local(hit_pos))` using body-local coordinates
- **Alternatives**: `hit_pos - body.global_position` (world-space offset, was the bug)
- **Rationale**: Godot 4 `apply_impulse` expects the position argument in the body's local coordinate frame. Passing `hit_pos - body.global_position` is a world-space vector that ignores the body's rotation, producing incorrect torque on rotated vehicles (e.g., car facing sideways). `body.to_local(hit_pos)` correctly accounts for the body orientation.
- **Status**: Fixed in `player_weapon.gd`
