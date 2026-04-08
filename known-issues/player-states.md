# Player States - Known Issues

Reviewed: 2026-03-25
Files: player.gd, player_camera.gd, player_flashlight.gd, player_model.gd,
player_weapon.gd, states/driving.gd, entering_vehicle.gd, exiting_vehicle.gd,
idle.gd, running.gd, swimming.gd, walking.gd

---

## HIGH

### H4 — `player_weapon.gd:81`: No holster-on-death
`_armed` stays true; gun mesh remains on model after player dies.

### H5 — `player_weapon.gd:242-244`: `apply_impulse` passes world-space offset
Second argument should be local-space offset from center of mass. Applies incorrect
torque on rotated vehicles.

---

## MEDIUM

### M1 — `player_model.gd:85-101`: Float comparison `!= 0.0` never matches lerpf result
Rotation reset block runs every idle frame forever. Minor CPU waste.

### M2 — `player_flashlight.gd:23`: `look_at` degenerates when camera looks straight down

### M3 — `player_flashlight.gd:26-29`: `toggle_flashlight` handled without InputManager context check
Pressing L while driving toggles both vehicle lights and personal flashlight.

### M4 — `swimming.gd:99`: `_is_over_water()` defined but never called (dead code)

### M5 — Multiple files: `_is_over_water()` and `_get_camera_relative_direction()` duplicated verbatim
Present in idle.gd, walking.gd, running.gd, swimming.gd.

### M6 — `driving.gd:88-102`: Dynamically instantiated boat camera never removed on exit
Persists as orphaned child node after player disembarks.

### M7 — `player_weapon.gd:262-271`: Ragdolls added to scene root with no lifetime timer or cap

---

## LOW

### L1 — `player.gd:42-46`: Stale `nearest_vehicle` reference if vehicle freed without area exit
### L2 — `player_camera.gd:25`: `_yaw` never wrapped, accumulates to large float values
### L3 — `driving.gd:211-222`: Boat tiller animation reads input without InputManager check
### L4 — Five files: `SEA_LEVEL := -2.0` duplicated (needs single source of truth)
### L5 — `player_model.gd:293`: Accesses private `pw._current_idx` from sibling node
### L6 — `player_model.gd:262`: Armed-aim guard uses `parent.visible` instead of InputManager
