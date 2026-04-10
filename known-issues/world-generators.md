# World Generators - Known Issues

Reviewed: 2026-03-25
Updated: 2026-04-10
Files: all 16 chunk builder files in scenes/world/generator/

---

## IMPORTANT

### IMP-09 — `chunk_builder_buildings.gd:505-506`: Door wall collision uses exterior span
Collision opening doesn't match visual door position.
**Status:** Deferred — file is ~12 k lines; requires careful investigation to avoid
regressing other building collision. Not tackled this cycle.

---

## Stale (no longer issues)

- **IMP-06** — Streetlight Y was already set to `_grid.SIDEWALK_HEIGHT` (0.10 m), not 0.0.
  Lights only placed on flat city chunks where terrain is 0. No change needed.
- **IMP-08** — Tree materials are created once in `init()` and passed in; no per-chunk
  duplication occurs. Stale.
- **LOW-04** — `chunk_builder_farmland.gd` creates `_field_mat` in `init()`, not `build()`.
  Stale.

---

## Resolved (this cycle)

- **IMP-05** — `_apply_edge_constraints` rewritten with normalised weighted average so all
  four edges (N, S, W, E) contribute to `total_weight`; corner cells blend symmetrically.
- **IMP-07** — Rural road collision boxes now compute `atan2` slope angle and apply
  `rotation.x` (N-S) / `rotation.z` (E-W) so boxes follow terrain grade.
- **LOW-01** — Trees added to left/top sidewalks (mirrored loops); all four sides covered.
- **LOW-02** — Unused `BANK_SLOPE_WIDTH` constant removed from `chunk_builder_river.gd`.
- **LOW-03** — Local `_sample_height()` in villages replaced with `_boundary.get_ground_height()`;
  identical logic, duplication removed.
