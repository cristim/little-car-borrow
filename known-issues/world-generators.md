# World Generators - Known Issues

Reviewed: 2026-03-25
Files: all 16 chunk builder files in scenes/world/generator/

---

## IMPORTANT

### IMP-05 — `chunk_builder_terrain.gd:347-374`: Corner cell edge blending inconsistent
WEST and EAST apply at full weight, overriding NORTH+SOUTH blend at corner cells.

### IMP-06 — `chunk_builder_lights.gd:59,71`: Streetlight Y hardcoded to 0.0
Underground or floating on non-flat terrain chunks.

### IMP-07 — `chunk_builder_rural_roads.gd:130-134`: Flat collision boxes on sloped roads
Horizontal BoxShape3D 0.3m thick diverges from visual quad on slopes >15 degrees.
Causes GEVP vehicle fall-through.

### IMP-08 — `chunk_builder_rural_trees.gd` / `chunk_builder_trees.gd`: Material duplicated per chunk
New StandardMaterial3D per multimesh per chunk prevents GPU batching.

### IMP-09 — `chunk_builder_buildings.gd:505-506`: Door wall collision uses exterior span
Collision opening doesn't match visual door position.

---

## LOW

### LOW-01 — `chunk_builder_trees.gd:52-90`: City trees only on right/bottom side of roads
### LOW-02 — `chunk_builder_river.gd:8`: BANK_SLOPE_WIDTH defined but never used
### LOW-03 — `chunk_builder_villages.gd:193`: `_sample_height` duplicated from terrain builder
### LOW-04 — `chunk_builder_farmland.gd:105-107`: Field material created per build() call
