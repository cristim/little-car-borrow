# Technical Decisions

## 2026-02-27: Vehicle Physics System
- **Decision**: Use GEVP (Godot Easy Vehicle Physics) with custom VehicleController
- **Alternatives**: Built-in VehicleBody3D, KidsCanCode sphere-car, VitaVehicle
- **Rationale**: GEVP provides raycast-based RigidBody3D with detailed tire/suspension physics. MIT licensed. Works with Godot 4.5. Has arcade car preset we can start from. We write our own controller to map our input actions instead of using GEVP's VehicleController (which expects different input map names).
- **Status**: Validated - cloned from GitHub, code reviewed, well-structured Vehicle/Wheel separation

## 2026-02-28: Player + Vehicle Enter/Exit Architecture
- **Decision**: Single player scene with 6-state StateMachine. Two independent cameras (PlayerCamera + VehicleCamera) swap via `make_active()`. VehicleCamera is a child of the vehicle scene. InputManager context (FOOT/VEHICLE) guards both player camera and vehicle_controller inputs.
- **Alternatives**: Separate player-on-foot and player-driving scenes, unified camera that morphs between modes
- **Rationale**: Single scene avoids complexity of spawning/despawning player nodes. Dual cameras are simpler than a morphing camera - each mode has its own tuning. VehicleCamera as vehicle child means each vehicle type can customize its camera. InputManager guard in vehicle_controller prevents ghost inputs when on foot.
- **Status**: Implemented - Phase 2 complete
