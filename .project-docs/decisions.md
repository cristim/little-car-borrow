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
