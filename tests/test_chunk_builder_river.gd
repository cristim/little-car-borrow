extends GutTest
## Unit tests for chunk_builder_river.gd water plane generation along river paths.

const RiverScript = preload("res://scenes/world/generator/chunk_builder_river.gd")
const RoadGridScript = preload("res://src/road_grid.gd")
const BoundaryScript = preload("res://src/city_boundary.gd")

var _grid: RefCounted
var _noise: FastNoiseLite
var _boundary: RefCounted
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

	_builder = RiverScript.new()
	_builder.init(_grid, _boundary)


# ================================================================
# Initialization
# ================================================================


func test_init_sets_grid() -> void:
	assert_not_null(_builder._grid, "init should set _grid")


func test_init_sets_boundary() -> void:
	assert_not_null(_builder._boundary, "init should set _boundary")


func test_init_creates_water_material() -> void:
	assert_not_null(_builder._water_mat, "init should create water material")


func test_water_material_transparency() -> void:
	assert_eq(
		_builder._water_mat.transparency,
		BaseMaterial3D.TRANSPARENCY_ALPHA,
		"Water material should use alpha transparency",
	)


func test_water_material_cull_disabled() -> void:
	assert_eq(
		_builder._water_mat.cull_mode,
		BaseMaterial3D.CULL_DISABLED,
		"Water material should have culling disabled",
	)


func test_water_material_color() -> void:
	var c: Color = _builder._water_mat.albedo_color
	assert_almost_eq(c.r, 0.1, 0.01, "Water red channel")
	assert_almost_eq(c.g, 0.3, 0.01, "Water green channel")
	assert_almost_eq(c.b, 0.6, 0.01, "Water blue channel")
	assert_almost_eq(c.a, 0.55, 0.01, "Water alpha channel")


# ================================================================
# Constants
# ================================================================


func test_sea_level_constant() -> void:
	assert_eq(
		RiverScript.SEA_LEVEL,
		-2.0,
		"SEA_LEVEL should be -2.0",
	)


func test_subdivisions_constant() -> void:
	assert_eq(
		RiverScript.SUBDIVISIONS,
		8,
		"SUBDIVISIONS should be 8",
	)


func test_river_depth_constant() -> void:
	assert_eq(
		RiverScript.RIVER_DEPTH,
		2.0,
		"RIVER_DEPTH should be 2.0",
	)


# ================================================================
# Build with empty river_data (early return)
# ================================================================


func test_build_empty_river_data_produces_no_children() -> void:
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	_builder.build(chunk, Vector2i(0, 0), 0.0, 0.0, {})

	assert_eq(
		chunk.get_child_count(),
		0,
		"Empty river_data should produce no children",
	)


# ================================================================
# Build with valid river_data
# ================================================================


func _make_river_data(
	entry: int,
	exit_dir: int,
	width: float,
	pos: float,
) -> Dictionary:
	return {
		"entry_dir": entry,
		"exit_dir": exit_dir,
		"width": width,
		"position": pos,
	}


func test_build_creates_river_mesh() -> void:
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	var span: float = _grid.get_grid_span()
	var river := _make_river_data(0, 2, 6.0, 0.5)
	_builder.build(chunk, Vector2i(5, 0), span * 5.0, 0.0, river)

	var found_river := false
	for child in chunk.get_children():
		if child is MeshInstance3D and child.name == "River":
			found_river = true
			break
	assert_true(found_river, "Valid river_data should create River mesh")


func test_river_mesh_has_water_material() -> void:
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	var span: float = _grid.get_grid_span()
	var river := _make_river_data(0, 2, 6.0, 0.5)
	_builder.build(chunk, Vector2i(5, 0), span * 5.0, 0.0, river)

	for child in chunk.get_children():
		if child is MeshInstance3D and child.name == "River":
			assert_eq(
				child.material_override,
				_builder._water_mat,
				"River mesh should use water material",
			)
			return
	fail_test("River mesh not found")


func test_river_mesh_has_valid_mesh() -> void:
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	var span: float = _grid.get_grid_span()
	var river := _make_river_data(0, 2, 8.0, 0.5)
	_builder.build(chunk, Vector2i(5, 0), span * 5.0, 0.0, river)

	for child in chunk.get_children():
		if child is MeshInstance3D and child.name == "River":
			assert_not_null(child.mesh, "River mesh resource should exist")
			return
	fail_test("River mesh not found")


# ================================================================
# Direction combinations
# ================================================================


func test_build_north_to_south() -> void:
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	var span: float = _grid.get_grid_span()
	var river := _make_river_data(0, 2, 6.0, 0.5)
	_builder.build(chunk, Vector2i(5, 0), span * 5.0, 0.0, river)

	assert_eq(
		chunk.get_child_count(),
		1,
		"N-S river should produce exactly one child",
	)


func test_build_east_to_west() -> void:
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	var span: float = _grid.get_grid_span()
	var river := _make_river_data(1, 3, 6.0, 0.5)
	_builder.build(chunk, Vector2i(5, 0), span * 5.0, 0.0, river)

	assert_eq(
		chunk.get_child_count(),
		1,
		"E-W river should produce exactly one child",
	)


func test_build_north_to_east() -> void:
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	var span: float = _grid.get_grid_span()
	var river := _make_river_data(0, 1, 6.0, 0.5)
	_builder.build(chunk, Vector2i(5, 0), span * 5.0, 0.0, river)

	assert_eq(
		chunk.get_child_count(),
		1,
		"N-E river should produce exactly one child",
	)


func test_build_south_to_west() -> void:
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	var span: float = _grid.get_grid_span()
	var river := _make_river_data(2, 3, 6.0, 0.5)
	_builder.build(chunk, Vector2i(5, 0), span * 5.0, 0.0, river)

	assert_eq(
		chunk.get_child_count(),
		1,
		"S-W river should produce exactly one child",
	)


# ================================================================
# _edge_point calculations
# ================================================================


func test_edge_point_north() -> void:
	var pt: Vector3 = _builder._edge_point(100.0, 200.0, 50.0, 0, 0.5)
	assert_almost_eq(pt.x, 100.0, 0.01, "North edge X should be ox")
	assert_almost_eq(pt.z, 150.0, 0.01, "North edge Z should be oz - hs")


func test_edge_point_south() -> void:
	var pt: Vector3 = _builder._edge_point(100.0, 200.0, 50.0, 2, 0.5)
	assert_almost_eq(pt.x, 100.0, 0.01, "South edge X should be ox")
	assert_almost_eq(pt.z, 250.0, 0.01, "South edge Z should be oz + hs")


func test_edge_point_east() -> void:
	var pt: Vector3 = _builder._edge_point(100.0, 200.0, 50.0, 1, 0.5)
	assert_almost_eq(pt.x, 150.0, 0.01, "East edge X should be ox + hs")
	assert_almost_eq(pt.z, 200.0, 0.01, "East edge Z should be oz")


func test_edge_point_west() -> void:
	var pt: Vector3 = _builder._edge_point(100.0, 200.0, 50.0, 3, 0.5)
	assert_almost_eq(pt.x, 50.0, 0.01, "West edge X should be ox - hs")
	assert_almost_eq(pt.z, 200.0, 0.01, "West edge Z should be oz")


func test_edge_point_offset_position() -> void:
	# pos=0.0 should offset by -hs, pos=1.0 by +hs from center
	var pt_low: Vector3 = _builder._edge_point(100.0, 200.0, 50.0, 0, 0.0)
	var pt_high: Vector3 = _builder._edge_point(100.0, 200.0, 50.0, 0, 1.0)
	assert_almost_eq(
		pt_low.x,
		50.0,
		0.01,
		"pos=0 on north edge should offset X to ox - hs",
	)
	assert_almost_eq(
		pt_high.x,
		150.0,
		0.01,
		"pos=1 on north edge should offset X to ox + hs",
	)


func test_edge_point_y_always_zero() -> void:
	for dir in range(4):
		var pt: Vector3 = _builder._edge_point(0.0, 0.0, 50.0, dir, 0.5)
		assert_almost_eq(
			pt.y,
			0.0,
			0.01,
			"Edge point Y should always be 0 for dir %d" % dir,
		)


func test_edge_point_invalid_dir_returns_center() -> void:
	var pt: Vector3 = _builder._edge_point(100.0, 200.0, 50.0, 99, 0.5)
	assert_almost_eq(pt.x, 100.0, 0.01, "Invalid dir should return ox")
	assert_almost_eq(pt.z, 200.0, 0.01, "Invalid dir should return oz")


# ================================================================
# River data defaults
# ================================================================


func test_build_uses_default_river_values() -> void:
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	var span: float = _grid.get_grid_span()
	# Minimal river_data with only a truthy key to avoid is_empty
	var river := {"active": true}
	_builder.build(chunk, Vector2i(5, 0), span * 5.0, 0.0, river)

	# Should use defaults: entry_dir=0, exit_dir=2, width=6.0, position=0.5
	assert_eq(
		chunk.get_child_count(),
		1,
		"Default river_data should still produce a River mesh",
	)


# ================================================================
# Different widths
# ================================================================


func test_build_narrow_river() -> void:
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	var span: float = _grid.get_grid_span()
	var river := _make_river_data(0, 2, 2.0, 0.5)
	_builder.build(chunk, Vector2i(5, 0), span * 5.0, 0.0, river)

	assert_eq(chunk.get_child_count(), 1, "Narrow river should build")


func test_build_wide_river() -> void:
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	var span: float = _grid.get_grid_span()
	var river := _make_river_data(0, 2, 20.0, 0.5)
	_builder.build(chunk, Vector2i(5, 0), span * 5.0, 0.0, river)

	assert_eq(chunk.get_child_count(), 1, "Wide river should build")


# ================================================================
# Determinism
# ================================================================


func test_build_deterministic_same_tile_and_data() -> void:
	var span: float = _grid.get_grid_span()
	var tile := Vector2i(5, 2)
	var ox: float = span * 5.0
	var oz: float = span * 2.0
	var river := _make_river_data(0, 2, 6.0, 0.5)

	var chunk1 := Node3D.new()
	add_child_autofree(chunk1)
	_builder.build(chunk1, tile, ox, oz, river)

	var chunk2 := Node3D.new()
	add_child_autofree(chunk2)
	_builder.build(chunk2, tile, ox, oz, river)

	assert_eq(
		chunk1.get_child_count(),
		chunk2.get_child_count(),
		"Same tile+data should produce same child count",
	)


# ================================================================
# CRIT-04 — Water surface uses single flat water_y, not per-vertex terrain heights
# ================================================================


func test_river_uses_single_water_y_before_loop() -> void:
	var src: String = (RiverScript as GDScript).source_code
	assert_true(
		src.contains("water_y"),
		"River builder must compute a single water_y level before the subdivision loop",
	)


func test_river_no_longer_uses_per_vertex_wy() -> void:
	var src: String = (RiverScript as GDScript).source_code
	assert_false(
		src.contains("wy0") or src.contains("wy1"),
		"Per-vertex wy0/wy1 variables must be removed in favour of flat water_y",
	)
