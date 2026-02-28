# Technical Decisions

## 2026-02-27: Vehicle Physics System
- **Decision**: Use GEVP (Godot Easy Vehicle Physics) with custom VehicleController
- **Alternatives**: Built-in VehicleBody3D, KidsCanCode sphere-car, VitaVehicle
- **Rationale**: GEVP provides raycast-based RigidBody3D with detailed tire/suspension physics. MIT licensed. Works with Godot 4.5. Has arcade car preset we can start from. We write our own controller to map our input actions instead of using GEVP's VehicleController (which expects different input map names).
- **Status**: Validated - cloned from GitHub, code reviewed, well-structured Vehicle/Wheel separation
