# World Managers - Known Issues

Reviewed: 2026-03-25
Files: city.gd, ambient_audio.gd, day_night_environment.gd, pedestrian_manager.gd,
police_manager.gd, radio_system.gd, traffic_manager.gd, weapon_pickup.gd

---

## IMPORTANT

### I1 — `ambient_audio.gd:139,222-226`: Negative gust envelope on long gusts
`_gust_remaining` can reach 3.5s but `_gen_gust` divides by GUST_DURATION (2.5),
making `progress` negative. `sin(progress * PI)` flips noise polarity, producing
audible pop/click at gust start.

**Fix:** Clamp `progress` to `[0.0, 1.0]`.

### I2 — `day_night_environment.gd:67,192-207`: `_mat_active` hardcoded size 4
Used as parallel array to `city._window_mats`. No enforced coupling. Out-of-bounds
access if window mat count changes.

**Fix:** Size `_mat_active` dynamically from `mats.size()`.

### I3 — `police_manager.gd:127`: Police can spawn on alley road (width 4m)
`randi_range(0, GRID_SIZE)` includes alley index. Police vehicle (~2m wide) overlaps
kerb/buildings on 4m road.

**Fix:** Skip alley road index in `_try_spawn`.

### I4 — `radio_system.gd:778-781`: TTS queue is unbounded
No depth cap on `_tts_queue`. Extended chase accumulates stale announcements that
play long after chase ends.

**Fix:** Cap at depth 3, drop oldest on overflow.

### I5 — `pedestrian/traffic/police_manager.gd`: `_fetch_biome_map` called at `_ready` before city_manager
All three call `_fetch_biome_map()` from `_ready()`. If they initialize before city.gd,
`_biome_map` stays null for the entire session (never re-fetched).

**Fix:** Lazy-fetch on first use, or defer by one frame.

---

## MINOR

### M1 — `traffic_manager.gd:313-318` / `police_manager.gd:252-257`: LOD freeze on to-be-freed vehicles
Freeze/unfreeze block runs on vehicles already queued for removal. Wasted physics write.

### M2 — `city.gd:116-140`: `_flush_timer` gated behind player existence
Tile cache not flushed until player spawns. Edits from initial generation only
persisted on scene teardown.
