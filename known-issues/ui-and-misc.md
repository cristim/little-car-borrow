# Known Issues: UI and Miscellaneous Files

Reviewed: 2026-03-25
Updated: 2026-04-10
Files covered: debug_hud.gd, game_hud.gd, interaction_prompt.gd, minimap_hud.gd,
mission_hud.gd, steal_progress_bar.gd, wanted_hud.gd, audio_panel.gd,
controls_panel.gd, pause_menu.gd, touch_controls.gd, ui_sounds.gd,
mission_marker.gd, mission_marker_manager.gd, pedestrian.gd,
pedestrian_model.gd, pedestrian_ragdoll.gd, pedestrian_flee.gd,
pedestrian_idle.gd, pedestrian_walk.gd, police_officer.gd

---

## IMPORTANT

### I1 — `minimap_hud.gd`: `_draw_clipped_line` misses lines crossing circle with both endpoints outside
**File:** `scenes/ui/hud/minimap_hud.gd`, lines 734-739
**Status:** Deferred — requires segment-circle intersection geometry; complex fix with risk
of breaking the clipping logic for the common case.

### I3 — `controls_panel.gd`: Rebind saves only first keyboard/mouse event per action
**File:** `scenes/ui/menus/controls_panel.gd`, lines 116-131
**Status:** Working as intended — one binding per input type per action is the design goal.
Each `InputEventKey` / `InputEventMouseButton` slot is saved separately; re-pressing a key
replaces only that slot. Not a bug.

---

## LOW

### L1 — `debug_hud.gd`: Orphaned script superseded by `game_hud.gd`
### L2 — `wanted_hud.gd` / `mission_hud.gd`: Same orphan issue
### L3 — `audio_panel.gd` / `controls_panel.gd`: Fragile parent path navigation
### L4 — `minimap_hud.gd`: Road grid jitter from `get_road_center_near` snapping
### L5 — `touch_controls.gd`: Joystick thumb not reset on pause
### L7 — `mission_marker.gd`: Magic number 8 for collision layer

---

## Resolved (this cycle)

- **I2** — `_rebuild_clip_circle` now called lazily on first `_draw()`, connected to `resized` signal
- **I4** — `InputManager.toggle_fullscreen()` public wrapper added; pause_menu updated
- **I5** — `_markers[mid] = []` reserved before spawn to block duplicate dropoff on concurrent signals
- **I6** — `move_and_slide()` now called inside throttle skip branch; gravity guarded by `is_on_floor()`
- **I7** — `is_on_floor()` guard added to pedestrian_flee, pedestrian_walk, pedestrian_idle
- **I8** — `get_unlocked()` / `get_current_weapon_index()` accessors added to PlayerWeapon
- **I9** — Color gradient fixed: continuous lerp over 0..30 (grass→rock) and 30..50 (rock→snow)
