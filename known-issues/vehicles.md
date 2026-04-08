# Vehicles - Known Issues

Reviewed: 2026-03-25
Files: all 20 files in scenes/vehicles/

---

## CRITICAL

### C2 — `collision_crime_detector.gd:91-97`: `add_child` called after `copy_visual_from`
Ragdoll visuals placed relative to world origin instead of impact point because ragdoll
has no world transform when visuals are copied.

**Fix:** Call `add_child(ragdoll)` before `copy_visual_from(pedestrian)`.

### C3 — `boat_controller.gd:94-98`: Buoyancy force position ignores center_of_mass offset
`apply_force` position doesn't account for custom center_of_mass `Vector3(0, -0.8, 0)`.
Forces applied as if hull is 0.8m higher than actual.

---

## IMPORTANT

### I2 — `helicopter_ai.gd:263`: Shoot sound lambda missing `is_instance_valid` guard
If helicopter freed before 0.3s timer fires, attempts to call method on freed object.

### I3 — `helicopter_ai.gd:407`: Global `randf()` used in rotor audio instead of `_rng.randf()`
Heavy use of global RNG from audio can skew seed state affecting game logic.

### I4 — `vehicle_health.gd:85`: Floating-point exact equality on Vector3
`hit_normal.abs() != Vector3.UP` uses exact comparison; should use `is_equal_approx`.

### I5 — `vehicle_lights.gd:143-148`: Night restore bypasses `_manual_off` state
Per-frame restore in `_physics_process` overrides manual-off every frame at night.
Impossible to turn off lights at night while driving.

### I6 — `police_ai_controller.gd:677`: Cross-traffic mask includes pedestrians
Police yield at intersections for jaywalkers during pursuit. Mask `112` includes
pedestrians(32) unlike NPC controller mask `88`.

### I7 — `boat_audio.gd:79` / `engine_audio.gd:82`: Idle burble/wobble 1000x too slow
Phase increment divides by `SAMPLE_RATE` (22050) inside `_process()` instead of frame rate.
2 Hz burble becomes ~0.006 Hz (1 cycle per 167 seconds).

### I8 — `boat_body_init.gd`: Engine mesh from builder silently discarded
Builder returns `"engine"` and `"stern_z"` keys but boat_body_init only reads hull/cabin/windshield.
Outboard motor is invisible.

---

## LOW

### L1 — `helicopter_ai.gd:158-161`: Body tilt snaps instantly on forward flight start
### L2 — `car_body_builder.gd:716`: `base.inset` accessed on dict that may lack the key
### L3 — `vehicle_health.gd:368`: Fire sound not explicitly stopped on explosion
### L4 — `police_ai_controller.gd:344`: Dismounted officer may not be in "police_officer" group
### L5 — `police_siren.gd`: No distance culling on siren generator (unlike engine_audio)
