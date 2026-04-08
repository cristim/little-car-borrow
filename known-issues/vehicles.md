# Vehicles - Known Issues

Reviewed: 2026-03-25
Files: all 20 files in scenes/vehicles/

---

## CRITICAL

### C3 — `boat_controller.gd:94-98`: Buoyancy force position ignores center_of_mass offset
`apply_force` position doesn't account for custom center_of_mass `Vector3(0, -0.8, 0)`.
Forces applied as if hull is 0.8m higher than actual.

---

## IMPORTANT

### I6 — `police_ai_controller.gd:677`: Cross-traffic mask includes pedestrians
Police yield at intersections for jaywalkers during pursuit. Mask `112` includes
pedestrians(32) unlike NPC controller mask `88`.

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
