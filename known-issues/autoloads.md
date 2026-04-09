# Autoloads - Known Issues

Reviewed: 2026-03-25
Scope: all files under `src/autoloads/`

---

## HIGH

### H1 — `game_manager.gd`: `_try_unlock_shotgun` called repeatedly with no guard
**File:** `src/autoloads/game_manager.gd`, lines 25-26, 91-97

Called on every `add_money` above 500. Same issue in `wanted_level_manager.gd` for rifle
and `mission_manager.gd` for SMG.

**Fix:** Add `_shotgun_unlocked` flag and skip once set.

### H2 — `game_manager.gd`: `deduct_money` allows negative amount (bypasses tracking)
**File:** `src/autoloads/game_manager.gd`, lines 30-36

**Fix:** Add `if amount <= 0: return false`.

### H3 — `mission_manager.gd`: Active mission timer can emit negative value
**File:** `src/autoloads/mission_manager.gd`, lines 47-50

**Fix:** Clamp before emit: `_mission_timer = maxf(_mission_timer - delta, 0.0)`.

### H4 — `mission_manager.gd`: Vehicle variant identification via body scale is fragile
**File:** `src/autoloads/mission_manager.gd`, lines 211-221, 347-365

**Fix:** Store variant name as vehicle metadata at spawn time.

### H5 — `day_night_manager.gd`: Midnight rollover can skip emit on large frame delta
**File:** `src/autoloads/day_night_manager.gd`, lines 20-25

**Fix:** Track previous quantized hour and emit once per unique value.

### H6 — `audio_manager.gd`: `play_sfx`/`play_ui` don't guard against null stream
**File:** `src/autoloads/audio_manager.gd`, lines 67-83

### H7 — `audio_manager.gd`: `_buses_created` flag prevents recovery after AudioServer reset
**File:** `src/autoloads/audio_manager.gd`, lines 17-25

---

## MEDIUM

### M1 — `event_bus.gd`: ~15 declared signals are never emitted anywhere
**File:** `src/autoloads/event_bus.gd`

Including: `player_respawned`, `police_search_started/ended`, `vehicle_destroyed`,
`vehicle_speed_changed`, `vehicle_damaged`, `pedestrian_killed`, `weapon_switched`,
`weapon_unlocked`, `show_notification`, `show/hide_interaction_prompt`,
`player_entered/exited_water`, `vehicle_entered_water`.

### M2 — `settings_manager.gd`: Audio volume applied before AudioManager._ready() runs
**File:** `src/autoloads/settings_manager.gd`, lines 43-46

Depends on autoload ordering in project.godot.

### M3 — `day_night_manager.gd`: Negative `time_speed` causes negative `current_hour`
**File:** `src/autoloads/day_night_manager.gd`, line 10

**Fix:** Use `wrapf(current_hour, 0.0, 24.0)` instead of `fmod`.

---

## CROSS-CUTTING

### XH1 — Weapon-unlock pattern copy-pasted three times with no deduplication
`game_manager.gd:91`, `mission_manager.gd:368`, `wanted_level_manager.gd:56`

### XH2 — All three managers use `get_nodes_in_group("player")[0]` without `is_instance_valid`
