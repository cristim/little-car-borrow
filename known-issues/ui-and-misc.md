# Known Issues: UI and Miscellaneous Files

Reviewed: 2026-03-25
Files covered: debug_hud.gd, game_hud.gd, interaction_prompt.gd, minimap_hud.gd,
mission_hud.gd, steal_progress_bar.gd, wanted_hud.gd, audio_panel.gd,
controls_panel.gd, pause_menu.gd, touch_controls.gd, ui_sounds.gd,
mission_marker.gd, mission_marker_manager.gd, pedestrian.gd,
pedestrian_model.gd, pedestrian_ragdoll.gd, pedestrian_flee.gd,
pedestrian_idle.gd, pedestrian_walk.gd, police_officer.gd

---

## CRITICAL

### C1 — `game_hud.gd`: `_on_mission_completed` reads active mission after it has been cleared
**File:** `scenes/ui/hud/game_hud.gd`, line 112
**Severity:** Critical (logic bug — reward is always $0)

`_on_mission_completed` calls `MissionManager.get_active_mission()` to read the reward.
However, `mission_completed` is emitted by MissionManager *after* it has already
cleared `_active_mission` to `{}`. The returned dictionary will be empty, so
`mission.get("reward", 0)` always returns 0 and the reward label always shows `+$0`.

The same bug exists in `mission_hud.gd` line 59 for the same reason.

**Fix:** The `mission_completed` signal should carry the reward amount directly, or the
signal should be emitted before the active mission is cleared.

---

### C2 — `ui_sounds.gd`: Tone queue dequeues the wrong element
**File:** `scenes/ui/ui_sounds.gd`, lines 35-52
**Severity:** Critical (audio plays wrong tones in wrong order)

The dequeue logic pops `_tone_queue[0]` on line 52 when `_tone_remaining` reaches
zero -- but on the same pass the code already reset `_tone_remaining = TONE_DURATION`
for the next tone and reads `_tone_queue[0]` as the frequency for the ongoing frame.

**Fix:** Pop the queue and reset phase at the start of each new tone.

---

### C4 — `police_officer.gd`: New AudioStreamPlayer3D leaked every shot
**File:** `scenes/police/police_officer.gd`, lines 122-147
**Severity:** Critical (memory/node leak -- one new node per gunshot every 1.2s per officer)

If the officer is `queue_free()`-d while the 0.3s cleanup timer is pending, Godot
attempts to free an already-freed node.

**Fix:** Keep a single reusable AudioStreamPlayer3D as a child node.

---

## IMPORTANT

### I1 — `minimap_hud.gd`: `_draw_clipped_line` misses lines crossing circle with both endpoints outside
**File:** `scenes/ui/hud/minimap_hud.gd`, lines 734-739

### I2 — `minimap_hud.gd`: `_rebuild_clip_circle` uses `size` before layout ready
**File:** `scenes/ui/hud/minimap_hud.gd`, lines 67-83

### I3 — `controls_panel.gd`: Rebind saves only first keyboard/mouse event per action
**File:** `scenes/ui/menus/controls_panel.gd`, lines 116-131

### I4 — `pause_menu.gd`: Calls private `InputManager._toggle_fullscreen()`
**File:** `scenes/ui/menus/pause_menu.gd`, line 61

### I5 — `mission_marker_manager.gd`: Race condition on mission fail/vehicle enter in same frame
**File:** `scenes/missions/mission_marker_manager.gd`, lines 80-93

### I6 — `pedestrian.gd`: Gravity applied without `move_and_slide()` when throttled
**File:** `scenes/pedestrians/pedestrian.gd`, lines 33-37

### I7 — `pedestrian_flee/walk/idle.gd`: Gravity accumulates unboundedly when grounded
**File:** pedestrian_flee.gd:29, pedestrian_walk.gd:25, pedestrian_idle.gd:19

### I8 — `game_hud.gd`: Accesses private fields `_unlocked`, `_current_idx` on PlayerWeapon
**File:** `scenes/ui/hud/game_hud.gd`, lines 199-201

### I9 — `minimap_hud.gd`: Color gradient gap between h=0 and h=20
**File:** `scenes/ui/hud/minimap_hud.gd`, lines 718-720

---

## LOW

### L1 — `debug_hud.gd`: Orphaned script superseded by `game_hud.gd`
### L2 — `wanted_hud.gd` / `mission_hud.gd`: Same orphan issue
### L3 — `audio_panel.gd` / `controls_panel.gd`: Fragile parent path navigation
### L4 — `minimap_hud.gd`: Road grid jitter from `get_road_center_near` snapping
### L5 — `touch_controls.gd`: Joystick thumb not reset on pause
### L6 — `police_officer.gd`: Gunshot uses "Ambient" bus instead of "SFX"
### L7 — `mission_marker.gd`: Magic number 8 for collision layer
