# Project History

## Timeline

### Phase 0 — Setup (2026-02-28)
Initial project scaffolding: Godot 4 project, gdtoolkit in `.venv/`, GUT test framework, GEVP vehicle physics addon (patched for Godot 4.5), pre-commit linting hook, autoload singletons, and state machine base classes.

Key inflection: `class_name` removed from state machine on day one after Godot 4.5 parse-error cascade was discovered (`Remove class_name from state machine to fix Godot 4.5 parse errors`).

### Phase 1 — Greybox Driving (2026-02-28)
Greybox vehicle with GEVP physics, chase camera, debug HUD (speed/FPS), main scene with ground/lighting/obstacles. Camera-follow and wheel-mesh-axis bugs fixed same day.

### Phase 2 — Walking Player + Enter/Exit (2026-02-28)
`CharacterBody3D` player with state machine (Idle, Walking, Running). Vehicle enter/exit states (EnteringVehicle, Driving, ExitingVehicle). Third-person orbit camera, interaction prompt, steal progress bar UI, `InteractionZone` on vehicles, `InputManager` context switching between FOOT and VEHICLE.

### Phase 3 — Infinite City (2026-02-28 – 2026-03-02)
Chunk-based infinite city generator with road grid math (`road_grid.gd`). Procedural greybox city and pause menu. Web export + GitHub Pages deployment. NPC traffic system, procedural walk animation, door animations.

### Phase 4 — Police / Wanted System (2026-03-02)
`WantedLevelManager`, `CollisionCrimeDetector`, vehicle theft crime signal. Police vehicle scene with light bar and siren (procedural audio). `PoliceManager` spawns police scaled to wanted level. Police AI controller with patrol/pursuit states. Wanted-level HUD (5 stars). `AudioManager` autoload.

### Phase 5 — Missions (2026-03-03)
`MissionManager` autoload, `MissionMarker` scene, `MissionMarkerManager`. Delivery, taxi, and theft mission flows. Mission HUD for objectives/timer. EventBus signals for mission lifecycle.

### Phase 6 — Pedestrians (2026-03-02 – 2026-03-03)
Greybox pedestrian model upgraded to articulated humanoid. Walk/Idle/Flee states. `PedestrianManager` for sidewalk spawning. Hit-pedestrian crime integration. Pedestrian ragdoll on high-speed impact.

### Phase 7 — Day-Night Cycle (2026-03-03)
`DayNightManager` autoload (24-hour cycle). Environment animation (sun arc, ambient light). Streetlights added to chunk generation. NPC density and ambient audio vary with time of day.

### Phase 8 — Audio Pass (2026-03-02 – 2026-03-03)
Engine tone generator, tire screech, police siren, ambient city soundscape, UI sounds for wanted-level changes. All attached to `AudioManager` bus setup. Procedural in-vehicle radio with multi-genre music, ADSR envelopes, chord progressions, drum patterns, and TTS (later rewritten to sample playback, 2026-03-04).

### Phase 9 — Minimap + Consolidated HUD (2026-03-03)
`GameHUD` consolidates DebugHUD, WantedHUD, and MissionHUD. Minimap `Control` with `_draw()` rendering. Vehicle tracking groups for minimap. Weapon panel added to HUD.

### Phase 10 — Vehicle & World Polish (2026-03-03 – 2026-03-10)
- Procedural curved car body builder (`car_body_builder.gd`) with doors, windows, and interior rooms.
- Vehicle damage, fire, explosion, and decal system. Destroyed cars remain as burned husks.
- CC0 PBR textures for roads, buildings, sidewalks, and ground.
- Player health system with HUD bar, death/respawn, game-over screen.
- Player weapon system: shooting, gun mesh, crosshair, multi-weapon support (weapon 1–4), weapon pickups.
- Police officer articulated model with run/shoot animations, ragdoll on run-over.
- A* road-graph pathfinding integrated into police pursuit AI. Police helicopter with flight states, shooting, and audio.
- Player flashlight and camera-pitch aiming.
- Vehicle lights (headlights, tail lights, reverse lights) on NPC/police vehicles; L-key toggle.
- Save/load settings; persistent money and mission progress.
- Performance pass: material caching, NPC/police LOD, physics freeze at distance, MultiMesh streetlights, pedestrian frame throttling.

### Phase 11 — Open World (Biomes + Terrain) (2026-03-08 – 2026-03-11)
Organic noise-modulated city boundary. Terrain chunk builder (noise heightmap) outside city. Suburb, farmland, and mountain biome builders. Village chunk builder. Edge-aware terrain height blending and river carving. Rural roads with collision. Biome-specific tree density (pine variant, autumn colors). Minimap shows terrain, buildings, rivers, rural roads. Tile data persistence to disk; F9 runtime chunk regeneration. Self-healing edge repair for terrain seam fallthrough. Water detection for player and vehicles; swimming state.

### Phase 12 — Boats (2026-03-15)
Boat physics controller with Archimedes 8-point buoyancy. Procedural boat body builder (3 hull variants). Boat player-state integration. Pier generation and interactive boat spawning. Procedural outboard motor audio. Visual wake effects. Player seating and steering tuned.

### Phase 13 — Helicopter (2026-03-08 + 2026-03-29 – 2026-04-03)
Helicopter body builder (mesh generation). Helicopter AI with flight states, shooting, and audio. Integrated into police manager (spawns at high wanted level). Helipad markings on tall buildings, helipad H icons on minimap. Rotor disk tilts with fuselage. Extensive geometry and physics fixes through April.

### Phase 14 — Sky, Weather, and Visual Polish (2026-03-28)
Stars, moon phases, weather clouds, fog. Sun arc correction, realistic blue daytime sky, warm band confined to sunrise/sunset. Window lights per-face with gradual night patterns and periodic toggling. Procedural face details and appearance variety on NPCs and player. Pedestrian walk animation via pivot-based limbs.

### Phase 15 — Refactoring, Testing & CI (2026-03-26 – 2026-04-08)
Comprehensive GUT test suite added for all systems. Pre-commit hooks for gdlint, gdformat, and coverage. `player_state` base class with shared helpers. `vehicle_ai_base` with shared Direction enum, constants, and methods. `character_model_base.gd` for shared gait animation. `VehicleSpawnHelper` extracts surface probing. Window materials batched (2 shared mats). Terrain noise centralized in `city_boundary.gd`. Legacy `debug_hud`, `wanted_hud`, and `mission_hud` deleted (absorbed by `GameHUD`). SOLID/DRY architecture analysis documented.

---

## Key Architectural Inflection Points

| Date | Event |
|------|-------|
| 2026-02-28 | `class_name` banned project-wide — Godot 4.5 cascading parse errors; all scripts use `extends "res://path/to/script.gd"` instead |
| 2026-02-28 | GEVP integrated and patched for Godot 4.5 compatibility |
| 2026-03-02 | Chunk-based infinite streaming city replaces static scene |
| 2026-03-02 | EventBus autoload adopted for all cross-system signals |
| 2026-03-03 | State machine pattern (`state.gd` + `state_machine.gd`) governs both player and pedestrian logic |
| 2026-03-07 | GUT 9.6.0 compatibility fix required for Godot 4.5 |
| 2026-03-08 | Organic city boundary separates city tiles from terrain biome tiles |
| 2026-03-08 | Tile profile, cache, biome map, and resolver added — world generation becomes data-driven |
| 2026-03-15 | Boat subsystem introduced first water vehicle with buoyancy physics |
| 2026-03-28 | `RandomNumberGenerator` gotcha documented: instances require `.randomize()` — global helpers are auto-seeded, instances are not |
| 2026-04-08 | Pre-commit CI hooks (gdlint, gdformat, coverage) formalised in repo |

---

## Recent Changes

*(reverse chronological, significant commits as of 2026-04-08)*

- **2026-04-08** Delete legacy `debug_hud`, `wanted_hud`, `mission_hud` — fully absorbed by `GameHUD`
- **2026-04-08** Add `vehicle_ai_base` with shared Direction enum, constants, and helper methods
- **2026-04-08** Add CI pre-commit hooks for gdlint, gdformat, and test coverage
- **2026-04-08** Add `player_state` base class with shared helpers; centralize terrain noise in `city_boundary.gd`
- **2026-04-08** Batch window materials — 2 shared materials replace 8 per-chunk copies (perf)
- **2026-04-08** Extract vehicle spawn surface probing into `VehicleSpawnHelper`; tilt NPC vehicles to terrain slope at spawn
- **2026-04-07** Fall damage proportional to height; increase weapon effective ranges
- **2026-04-03** Rotor disk tilts with fuselage during flight
- **2026-04-01** Fix boat seat position alignment; fix engine pivot visual rotation sign
- **2026-03-31** Fix pier collision box dimensions; fix boats spawning stuck at pier tip
- **2026-03-29** Archimedes 8-point volume-based buoyancy — boat floats at correct draft
- **2026-03-29** Add helicopter vehicle with helipad spawning and player integration (full feature)
- **2026-03-28** Add sky features: stars, moon phases, weather clouds, fog
- **2026-03-28** Add player jump; fix police shooting through walls
- **2026-03-26** Comprehensive test suite pass: chunk builders, world/city, boat subsystems, player state machine
- **2026-03-15** Complete boat subsystem: physics, body builder, pier, audio, wake effects
- **2026-03-10** Biome system: suburb, farmland, mountain builders; rivers and bridges; tile persistence
- **2026-03-08** Organic city boundary; terrain chunk builder; weapon system overhaul; vehicle damage/explosion
