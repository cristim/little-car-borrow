# Vehicles - Known Issues

Reviewed: 2026-03-25
Files: all 20 files in scenes/vehicles/

---

## IMPORTANT

### I8 — `boat_body_init.gd`: Engine mesh from builder silently discarded
Builder returns `"engine"` and `"stern_z"` keys but boat_body_init only reads hull/cabin/windshield.
Outboard motor is invisible.

---

## LOW

### L1 — `helicopter_ai.gd:158-161`: Body tilt snaps instantly on forward flight start
### L3 — `vehicle_health.gd:368`: Fire sound not explicitly stopped on explosion
### L4 — `police_ai_controller.gd:344`: Dismounted officer may not be in "police_officer" group
### L5 — `police_siren.gd`: No distance culling on siren generator (unlike engine_audio)
