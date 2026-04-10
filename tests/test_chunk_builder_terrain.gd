extends GutTest
## Unit tests for chunk_builder_terrain.gd heightmap and edge-constraint blending.

const TerrainScript = preload("res://scenes/world/generator/chunk_builder_terrain.gd")
const RoadGridScript = preload("res://src/road_grid.gd")
const BoundaryScript = preload("res://src/city_boundary.gd")

var _grid: RefCounted
var _noise: FastNoiseLite
var _boundary: RefCounted
var _terrain_mat: StandardMaterial3D
var _builder: RefCounted


func before_each() -> void:
	_grid = RoadGridScript.new()

	_noise = FastNoiseLite.new()
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 0.003
	_noise.fractal_octaves = 4
	_noise.fractal_lacunarity = 2.0
	_noise.fractal_gain = 0.5
	_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_noise.seed = 42

	_boundary = BoundaryScript.new()
	_boundary.init(_grid.get_grid_span(), _noise)

	_terrain_mat = StandardMaterial3D.new()
	_terrain_mat.vertex_color_use_as_albedo = true

	_builder = TerrainScript.new()
	_builder.init(_grid, _noise, _terrain_mat, _boundary)


# ================================================================
# Initialization
# ================================================================


func test_init_stores_grid() -> void:
	assert_eq(_builder._grid, _grid, "init should store grid reference")


func test_init_stores_boundary() -> void:
	assert_eq(_builder._boundary, _boundary, "init should store boundary reference")


func test_init_creates_sea_mat() -> void:
	assert_not_null(_builder._sea_mat, "init should create sea material")


# ================================================================
# Constants
# ================================================================


func test_subdivisions_positive() -> void:
	assert_true(TerrainScript.SUBDIVISIONS > 0, "SUBDIVISIONS should be positive")


func test_sea_level_negative() -> void:
	assert_true(TerrainScript.SEA_LEVEL < 0.0, "SEA_LEVEL should be negative")


func test_blend_cells_positive() -> void:
	assert_true(TerrainScript.BLEND_CELLS > 0, "BLEND_CELLS should be positive")


# ================================================================
# Build produces expected children
# ================================================================


func test_build_creates_terrain_mesh() -> void:
	var span: float = _grid.get_grid_span()
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	_builder.build(chunk, Vector2i(5, 2), span * 5.0, span * 2.0)

	var found := false
	for child in chunk.get_children():
		if child is MeshInstance3D and child.name == "TerrainMesh":
			found = true
			assert_not_null(child.mesh, "TerrainMesh should have a mesh resource")
	assert_true(found, "build() should create a TerrainMesh child")


func test_build_creates_terrain_body() -> void:
	var span: float = _grid.get_grid_span()
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	_builder.build(chunk, Vector2i(5, 2), span * 5.0, span * 2.0)

	var found := false
	for child in chunk.get_children():
		if child is StaticBody3D and child.name == "TerrainBody":
			found = true
			assert_eq(child.collision_layer, 1, "TerrainBody should be on ground layer")
			assert_true(child.is_in_group("Road"), "TerrainBody should be in Road group")
	assert_true(found, "build() should create a TerrainBody child")


func test_build_returns_edge_heights_dict() -> void:
	var span: float = _grid.get_grid_span()
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	var result = _builder.build(chunk, Vector2i(5, 2), span * 5.0, span * 2.0)

	assert_true(result is Dictionary, "build() should return a Dictionary of edge heights")
	assert_true(result.has(0), "Edge heights should include NORTH (0)")
	assert_true(result.has(1), "Edge heights should include EAST (1)")
	assert_true(result.has(2), "Edge heights should include SOUTH (2)")
	assert_true(result.has(3), "Edge heights should include WEST (3)")


func test_build_sets_terrain_min_max_meta() -> void:
	var span: float = _grid.get_grid_span()
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	_builder.build(chunk, Vector2i(5, 2), span * 5.0, span * 2.0)

	assert_true(
		chunk.has_meta("terrain_min_height"),
		"chunk should have terrain_min_height meta"
	)
	assert_true(
		chunk.has_meta("terrain_max_height"),
		"chunk should have terrain_max_height meta"
	)
	assert_true(chunk.has_meta("has_water"), "chunk should have has_water meta")


# ================================================================
# Determinism
# ================================================================


func test_build_deterministic() -> void:
	var span: float = _grid.get_grid_span()
	var tile := Vector2i(5, 2)
	var ox: float = span * 5.0
	var oz: float = span * 2.0

	var chunk1 := Node3D.new()
	add_child_autofree(chunk1)
	_builder.build(chunk1, tile, ox, oz)

	var chunk2 := Node3D.new()
	add_child_autofree(chunk2)
	_builder.build(chunk2, tile, ox, oz)

	assert_eq(
		chunk1.get_child_count(),
		chunk2.get_child_count(),
		"Same tile should produce same child count",
	)


# ================================================================
# IMP-05 — Corner blending: total_weight updated for all four edges
# ================================================================


func test_edge_constraint_total_weight_updated_for_all_edges() -> void:
	var src: String = (TerrainScript as GDScript).source_code
	# The fix requires total_weight += t after each of the four edge checks.
	# Count occurrences of "total_weight +=" — must be 4 (one per edge).
	var count := 0
	var search_str := "total_weight +="
	var pos := 0
	while true:
		var idx: int = src.find(search_str, pos)
		if idx == -1:
			break
		count += 1
		pos = idx + search_str.length()
	assert_eq(
		count,
		4,
		"IMP-05: total_weight must be updated for all four edges (found %d)" % count,
	)


func test_edge_constraint_uses_weighted_average() -> void:
	var src: String = (TerrainScript as GDScript).source_code
	assert_true(
		src.contains("weighted_target"),
		"IMP-05: _apply_edge_constraints must use weighted_target for normalised blend",
	)
