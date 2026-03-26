# World Generators - Known Issues

Reviewed: 2026-03-25
Files: all 16 chunk builder files in scenes/world/generator/

---

## CRITICAL

### CRIT-01 — `chunk_builder_terrain.gd:145-146`: HeightMapShape3D origin misaligned with visual mesh
TerrainBody positioned at `Vector3(ox, 0.0, oz)` but HeightMapShape3D origin is at
cell (0,0) centre. Visual mesh starts at `ox - span*0.5`. Collision offset grows with
slope angle, causing vehicle fall-through on slopes.

**Fix:** `body.position = Vector3(ox - span * 0.5, 0.0, oz - span * 0.5)`

### CRIT-02 — `chunk_builder_bridge.gd:53-64`: Bridges ignore river crossing position
Bridge deck centred at chunk centre, but river `position` field (0-1 normalized offset)
is never read. Bridge and water can be tens of metres apart.

### CRIT-03 — `chunk_builder_bridge.gd:54,89`: Bridge spawned on elevated terrain regardless of river
Condition `h_ns > 0.5` places bridge whenever terrain exceeds 0.5m, independent of
whether river actually crosses that highway.

### CRIT-04 — `chunk_builder_river.gd:54-57`: Water surface height is terrain-relative, not flat
`wy0 = h0 - RIVER_DEPTH * 0.5` varies per vertex, producing stepped non-planar water
that clips through banks and looks broken.

**Fix:** Use single fixed water level per river segment.

---

## IMPORTANT

### IMP-01 — `chunk_builder_piers.gd:165,185-221`: No `generate_normals()` on pilings; dead loop
Pilings render with zero normals. Dead for-loop at lines 191-193.

### IMP-02 — `chunk_builder_piers.gd:237-238`: Second boat spawned 1.6m past pier end
For i=1: offset = `12.0*0.8 + 4.0 = 13.6m` past 12m pier. Boat sinks immediately.

### IMP-03 — `chunk_builder_ramps.gd:51-89`: Stunt park fence has no collision
Fence MeshInstance3D added with no StaticBody3D backing.

### IMP-04 — `chunk_builder_farmland.gd:115-122`: Farmland fences have no collision
Same issue as IMP-03 for farmland fence meshes.

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

### IMP-10 — `chunk_builder_markings.gd:35-42`: Empty mesh always created
No `has_verts` guard; wasted draw call per city chunk.

---

## LOW

### LOW-01 — `chunk_builder_trees.gd:52-90`: City trees only on right/bottom side of roads
### LOW-02 — `chunk_builder_river.gd:8`: BANK_SLOPE_WIDTH defined but never used
### LOW-03 — `chunk_builder_villages.gd:193`: `_sample_height` duplicated from terrain builder
### LOW-04 — `chunk_builder_farmland.gd:105-107`: Field material created per build() call
### LOW-05 — `chunk_builder_piers.gd:191-193`: Dead for-loop in `_add_piling`
