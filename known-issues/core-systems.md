# Core Systems - Known Issues

Reviewed: 2026-04-09
Files: biome_map.gd, chunk_persistence.gd, city_boundary.gd, river_map.gd,
road_graph.gd, road_grid.gd, tile_cache.gd, tile_profile.gd, tile_resolver.gd,
weapon_mesh_builder.gd, state_machine/state.gd, state_machine/state_machine.gd

## LOW

### L1 — `road_grid.gd:38`: Road center accumulation may double-count intermediate half-widths
Needs verification against actual game behavior.

