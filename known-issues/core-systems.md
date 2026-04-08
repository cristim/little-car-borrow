# Core Systems - Known Issues

Reviewed: 2026-03-25
Files: biome_map.gd, chunk_persistence.gd, city_boundary.gd, river_map.gd,
road_graph.gd, road_grid.gd, tile_cache.gd, tile_profile.gd, tile_resolver.gd,
weapon_mesh_builder.gd, state_machine/state.gd, state_machine/state_machine.gd

---

## IMPORTANT

---

## LOW

### L1 — `road_grid.gd:38`: Road center accumulation may double-count intermediate half-widths
Needs verification against actual game behavior.

### L2 — `state_machine.gd`: `initial_state` export not validated as own child

### L3 — `chunk_persistence.gd`: `save_tile()` bypasses dirty-batch tracking

### L4 — `weapon_mesh_builder.gd`: Unknown weapon_name produces empty Node3D with no muzzle_local_pos meta
