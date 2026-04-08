# Player States - Known Issues

Reviewed: 2026-03-25
Files: player.gd, player_camera.gd, player_flashlight.gd, player_model.gd,
player_weapon.gd, states/driving.gd, entering_vehicle.gd, exiting_vehicle.gd,
idle.gd, running.gd, swimming.gd, walking.gd

## MEDIUM

### M4 — `swimming.gd:99`: `_is_over_water()` defined but never called (dead code)

### M5 — Multiple files: `_is_over_water()` and `_get_camera_relative_direction()` duplicated verbatim
Present in idle.gd, walking.gd, running.gd, swimming.gd.


---

## LOW

### L1 — `player.gd:42-46`: Stale `nearest_vehicle` reference if vehicle freed without area exit
### L2 — `player_camera.gd:25`: `_yaw` never wrapped, accumulates to large float values
### L3 — `driving.gd:211-222`: Boat tiller animation reads input without InputManager check
### L4 — Five files: `SEA_LEVEL := -2.0` duplicated (needs single source of truth)
### L5 — `player_model.gd:293`: Accesses private `pw._current_idx` from sibling node
### L6 — `player_model.gd:262`: Armed-aim guard uses `parent.visible` instead of InputManager
