# World Managers - Known Issues

Reviewed: 2026-03-25
Files: city.gd, ambient_audio.gd, day_night_environment.gd, pedestrian_manager.gd,
police_manager.gd, radio_system.gd, traffic_manager.gd, weapon_pickup.gd

---

## IMPORTANT

### I2 — `day_night_environment.gd:67,192-207`: `_mat_active` hardcoded size 4
Used as parallel array to `city._window_mats`. No enforced coupling. Out-of-bounds
access if window mat count changes.

**Fix:** Size `_mat_active` dynamically from `mats.size()`.

---

## MINOR

### M1 — `traffic_manager.gd:313-318` / `police_manager.gd:252-257`: LOD freeze on to-be-freed vehicles
Freeze/unfreeze block runs on vehicles already queued for removal. Wasted physics write.

### M2 — `city.gd:116-140`: `_flush_timer` gated behind player existence
Tile cache not flushed until player spawns. Edits from initial generation only
persisted on scene teardown.
