# Autoloads - Known Issues

Reviewed: 2026-03-25
Scope: all files under `src/autoloads/`

---

## MEDIUM

### M1 — `event_bus.gd`: ~15 declared signals are never emitted anywhere
**File:** `src/autoloads/event_bus.gd`

Including: `player_respawned`, `police_search_started/ended`, `vehicle_destroyed`,
`vehicle_speed_changed`, `vehicle_damaged`, `pedestrian_killed`, `weapon_switched`,
`weapon_unlocked`, `show_notification`, `show/hide_interaction_prompt`,
`player_entered/exited_water`, `vehicle_entered_water`.

These are intentional API stubs reserved for future systems; not a bug.

### M2 — `settings_manager.gd`: Audio volume applied before AudioManager._ready() runs
**File:** `src/autoloads/settings_manager.gd`, lines 43-46

Depends on autoload ordering in project.godot.

---

## CROSS-CUTTING

### XH1 — Weapon-unlock pattern copy-pasted three times with no deduplication
`game_manager.gd:91`, `mission_manager.gd:368`, `wanted_level_manager.gd:56`

Cosmetic duplication; deferred refactor.
