# Player States - Known Issues

Reviewed: 2026-03-25
Files: player.gd, player_camera.gd, player_flashlight.gd, player_model.gd,
player_weapon.gd, states/driving.gd, entering_vehicle.gd, exiting_vehicle.gd,
idle.gd, running.gd, swimming.gd, walking.gd

## LOW

### L1 — `player.gd:42-46`: Stale `nearest_vehicle` reference if vehicle freed without area exit
### L4 — Five files: `SEA_LEVEL := -2.0` duplicated (needs single source of truth)
### L5 — `player_model.gd:293`: Accesses private `pw._current_idx` from sibling node
### L6 — `player_model.gd:262`: Armed-aim guard uses `parent.visible` instead of InputManager
