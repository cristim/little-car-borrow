# Core Systems - Known Issues

Reviewed: 2026-03-25
Files: biome_map.gd, chunk_persistence.gd, city_boundary.gd, river_map.gd,
road_graph.gd, road_grid.gd, tile_cache.gd, tile_profile.gd, tile_resolver.gd,
weapon_mesh_builder.gd, state_machine/state.gd, state_machine/state_machine.gd

---

## IMPORTANT

### I2 — `biome_map.gd:76`: Double-scaling makes biome noise nearly constant
`_biome_noise` has `frequency = 0.08`. `_get_rural_biome` calls it with `wx * 0.01`,
giving effective frequency `0.0008`. Rural biomes are near-uniform across the map.

**Fix:** Remove `* 0.01` scaling, or raise noise frequency to compensate.

### I3 — `tile_profile.gd:15-27`: BIOME_ADJACENCY is asymmetric
`"suburb"` lists `"ocean"` but `"ocean"` doesn't list `"suburb"`. Result of
`biomes_compatible()` depends on argument order, causing non-deterministic seam
mismatches depending on chunk resolution order.

### I4 — `tile_resolver.gd:83-85`: Bridge biome not validated against all neighbors
`_find_compatible_biome` returns first match without checking other already-resolved
neighbors. Can produce invalid biome assignments in complex adjacency situations.

### I5 — `road_graph.gd:28-29`: "same intersection" and "no path" both return `[]`
Callers cannot distinguish the two cases.

---

## LOW

### L1 — `road_grid.gd:38`: Road center accumulation may double-count intermediate half-widths
Needs verification against actual game behavior.

### L2 — `state_machine.gd`: `initial_state` export not validated as own child

### L3 — `chunk_persistence.gd`: `save_tile()` bypasses dirty-batch tracking

### L4 — `weapon_mesh_builder.gd`: Unknown weapon_name produces empty Node3D with no muzzle_local_pos meta
