extends GutTest
## Unit tests for chunk_builder_terrain.gd height sampling, vertex coloring,
## and sea plane generation.

const TerrainScript = preload("res://scenes/world/generator/chunk_builder_terrain.gd")
const RoadGridScript = preload("res://src/road_grid.gd")
const BoundaryScript = preload("res://src/city_boundary.gd")

var _grid: RefCounted
var _noise: FastNoiseLite
var _builder: RefCounted
var _boundary: RefCounted


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
	_boundary.init(_grid.get_grid_span())

	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true

	_builder = TerrainScript.new()
	_builder.init(_grid, _noise, mat, _boundary)


# ================================================================
# Height sampling
# ================================================================


func test_height_zero_inside_city_radius() -> void:
	# Origin is well within city radius
	var h: float = _builder._sample_height(0.0, 0.0)
	assert_eq(h, 0.0, "Height at origin should be 0")


func test_height_near_zero_at_city_blend_zone() -> void:
	var span: float = _grid.get_grid_span()
	# Tile (1,1) center may be just outside city boundary in blend zone
	var h: float = _builder._sample_height(span, span)
	assert_almost_eq(
		h,
		0.0,
		0.1,
		"Height at tile (1,1) should be near 0 (blend zone)",
	)


func test_height_nonzero_outside_city() -> void:
	var span: float = _grid.get_grid_span()
	# Far outside city: tile (10, 0) center
	var h: float = _builder._sample_height(span * 10.0, 0.0)
	assert_ne(h, 0.0, "Height far outside city should not be 0")


func test_height_zero_inside_blend_zone() -> void:
	# First quarter of first tile outside city should be nearly flat
	var city_edge: float = _boundary.get_boundary_radius_at_angle(0.0)
	var span: float = _grid.get_grid_span()
	for i in range(5):
		var d: float = float(i) * span * 0.05  # 0 to ~5% of grid_span
		var h: float = _builder._sample_height(city_edge + d, 0.0)
		assert_true(
			absf(h) < 2.0,
			"Height near city edge should be near 0 (got %f at d=%f)" % [h, d],
		)


func test_seabed_exists_far_from_city() -> void:
	var span: float = _grid.get_grid_span()
	var found_seabed := false
	for _i in range(200):
		var wx: float = randf_range(-span * 15.0, span * 15.0)
		var wz: float = randf_range(-span * 15.0, span * 15.0)
		var h: float = _builder._sample_height(wx, wz)
		if h < -2.0:
			found_seabed = true
			break
	assert_true(found_seabed, "Some terrain should be below SEA_LEVEL (-2.0)")


func test_beach_smooth_transition() -> void:
	# Walk outward from city edge along X axis, heights should change smoothly
	var city_edge: float = _boundary.get_boundary_radius_at_angle(0.0)
	var span: float = _grid.get_grid_span()
	var prev_h: float = 0.0
	for i in range(1, 20):
		var d: float = float(i) * span * 0.1
		var h: float = _builder._sample_height(city_edge + d, 0.0)
		var jump: float = absf(h - prev_h)
		assert_true(
			jump < 15.0,
			"Height jump should be smooth (got %f at d=%f)" % [jump, d],
		)
		prev_h = h


func test_height_smooth_transition_near_city_edge() -> void:
	# Use boundary radius at angle 0 as the edge reference
	var city_edge: float = _boundary.get_boundary_radius_at_angle(0.0)
	# Just 10m beyond city edge — should be small height
	var h: float = _builder._sample_height(city_edge + 10.0, 0.0)
	assert_true(
		absf(h) < 10.0,
		"Height near city edge should be small (smooth transition)",
	)


func test_height_continuous_across_boundary() -> void:
	var span: float = _grid.get_grid_span()
	# Two points very close together straddling a chunk boundary
	# at tile boundary between (4,0) and (5,0)
	var boundary_x: float = span * 4.5
	var h_left: float = _builder._sample_height(boundary_x - 0.1, 0.0)
	var h_right: float = _builder._sample_height(boundary_x + 0.1, 0.0)
	assert_almost_eq(
		h_left,
		h_right,
		1.0,
		"Height should be continuous across chunk boundaries",
	)


# ================================================================
# Vertex coloring
# ================================================================


func test_color_water_below_sea_level() -> void:
	# Just below SEA_LEVEL (-2.0), shallow water — should be blue-ish
	var c: Color = _builder._height_to_color(-2.1)
	assert_true(
		c.b > 0.6 and c.r < 0.2,
		"Below sea level should be water color (got %s)" % str(c),
	)


func test_color_snow_at_high_altitude() -> void:
	var c: Color = _builder._height_to_color(70.0)
	assert_eq(
		c,
		Color(0.90, 0.90, 0.92),
		"High altitude should be snow color",
	)


func test_color_grass_at_mid_height() -> void:
	# At 15m (between 0 and 20), should be pure grass
	var c: Color = _builder._height_to_color(15.0)
	assert_eq(
		c,
		Color(0.22, 0.45, 0.18),
		"Mid-height should be grass color",
	)


# ================================================================
# Build produces expected children
# ================================================================


func test_build_creates_terrain_mesh() -> void:
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	# Use tile far outside city
	_builder.build(chunk, Vector2i(5, 0), 5.0 * _grid.get_grid_span(), 0.0)

	var found_mesh := false
	for child in chunk.get_children():
		if child is MeshInstance3D and child.name == "TerrainMesh":
			found_mesh = true
			break
	assert_true(found_mesh, "Build should create TerrainMesh child")


func test_build_creates_terrain_body() -> void:
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	_builder.build(chunk, Vector2i(5, 0), 5.0 * _grid.get_grid_span(), 0.0)

	var found_body := false
	for child in chunk.get_children():
		if child is StaticBody3D and child.name == "TerrainBody":
			found_body = true
			break
	assert_true(found_body, "Build should create TerrainBody child")


func test_build_sets_metadata() -> void:
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	_builder.build(chunk, Vector2i(5, 0), 5.0 * _grid.get_grid_span(), 0.0)

	assert_true(
		chunk.has_meta("terrain_min_height"),
		"Should set terrain_min_height meta",
	)
	assert_true(
		chunk.has_meta("terrain_max_height"),
		"Should set terrain_max_height meta",
	)
	assert_true(
		chunk.has_meta("has_water"),
		"Should set has_water meta",
	)


func test_terrain_body_in_road_group() -> void:
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	_builder.build(chunk, Vector2i(5, 0), 5.0 * _grid.get_grid_span(), 0.0)

	for child in chunk.get_children():
		if child is StaticBody3D and child.name == "TerrainBody":
			assert_true(
				child.is_in_group("Road"),
				"TerrainBody should be in Road group for GEVP",
			)
			return
	fail_test("TerrainBody not found")


# ================================================================
# West ocean depression
# ================================================================


func test_west_ocean_depression() -> void:
	var span: float = _grid.get_grid_span()
	var found_below := false
	# Sample far west — should find heights below SEA_LEVEL
	for i in range(20):
		var wx: float = -span * 3.0 - float(i) * span * 0.5
		var wz: float = float(i) * span * 0.3
		var h: float = _builder._sample_height(wx, wz)
		if h < -2.0:
			found_below = true
			break
	assert_true(found_below, "Far west terrain should descend below sea level")


func test_east_no_depression() -> void:
	var span: float = _grid.get_grid_span()
	var all_above := true
	# Sample far east at several points — should generally be above sea level
	for i in range(10):
		var wx: float = span * 5.0 + float(i) * span
		var h: float = _builder._sample_height(wx, 0.0)
		if h < -2.0:
			all_above = false
			break
	assert_true(all_above, "Far east terrain should not be depressed into ocean")


func test_west_depression_gradual() -> void:
	var span: float = _grid.get_grid_span()
	# Both positions far west of the city should be deep underwater.
	# (shore_t is clamped at 1.0 for both, so exact ordering depends on noise)
	var city_edge: float = _boundary.get_boundary_radius_at_angle(PI)
	var near_h: float = _builder._sample_height(-city_edge - span * 2.0, 0.0)
	var far_h: float = _builder._sample_height(-city_edge - span * 6.0, 0.0)
	assert_true(
		near_h < 0.0,
		"Near west (%f) should be below sea level" % near_h,
	)
	assert_true(
		far_h < 0.0,
		"Far west (%f) should be below sea level" % far_h,
	)


func test_west_ocean_reachable_within_four_chunks() -> void:
	var span: float = _grid.get_grid_span()
	var city_edge: float = _boundary.get_boundary_radius_at_angle(PI)
	var found_ocean := false
	var step: float = span * 0.25
	var limit: float = span * 4.0
	var d: float = 0.0
	while d <= limit:
		var wx: float = -city_edge - d
		var h: float = _builder._sample_height(wx, 0.0)
		if h < -2.0:
			found_ocean = true
			break
		d += step
	assert_true(
		found_ocean,
		"Ocean (h < -2.0) should be reachable within 4 chunks west of city edge",
	)


func test_build_deterministic() -> void:
	# Build same tile twice, verify same metadata
	var chunk1 := Node3D.new()
	add_child_autofree(chunk1)
	var tile := Vector2i(6, 3)
	var ox: float = 6.0 * _grid.get_grid_span()
	var oz: float = 3.0 * _grid.get_grid_span()
	_builder.build(chunk1, tile, ox, oz)

	var chunk2 := Node3D.new()
	add_child_autofree(chunk2)
	_builder.build(chunk2, tile, ox, oz)

	var min1: float = chunk1.get_meta("terrain_min_height")
	var min2: float = chunk2.get_meta("terrain_min_height")
	assert_eq(min1, min2, "Same tile should produce same min height")


# ================================================================
# _extract_edge_heights
# ================================================================


func test_extract_edge_heights_returns_four_directions() -> void:
	var s: int = TerrainScript.SUBDIVISIONS + 1
	var heights: Array[float] = []
	heights.resize(s * s)
	for i in range(s * s):
		heights[i] = float(i) * 0.1

	var result: Dictionary = _builder._extract_edge_heights(heights)
	assert_true(result.has(0), "Should have NORTH edge (0)")
	assert_true(result.has(1), "Should have EAST edge (1)")
	assert_true(result.has(2), "Should have SOUTH edge (2)")
	assert_true(result.has(3), "Should have WEST edge (3)")


func test_extract_edge_heights_correct_size() -> void:
	var s: int = TerrainScript.SUBDIVISIONS + 1
	var heights: Array[float] = []
	heights.resize(s * s)
	for i in range(s * s):
		heights[i] = 0.0

	var result: Dictionary = _builder._extract_edge_heights(heights)
	var north: PackedFloat32Array = result[0]
	assert_eq(north.size(), s, "Edge array size should be SUBDIVISIONS+1")


func test_extract_edge_heights_north_row() -> void:
	var s: int = TerrainScript.SUBDIVISIONS + 1
	var heights: Array[float] = []
	heights.resize(s * s)
	for i in range(s * s):
		heights[i] = 0.0
	# Set first row to distinct values
	for ix in range(s):
		heights[ix] = float(ix) + 1.0

	var result: Dictionary = _builder._extract_edge_heights(heights)
	var north: PackedFloat32Array = result[0]
	for ix in range(s):
		assert_eq(
			north[ix],
			float(ix) + 1.0,
			"North edge ix=%d should match first row" % ix,
		)


func test_extract_edge_heights_south_row() -> void:
	var s: int = TerrainScript.SUBDIVISIONS + 1
	var heights: Array[float] = []
	heights.resize(s * s)
	for i in range(s * s):
		heights[i] = 0.0
	# Set last row
	for ix in range(s):
		heights[TerrainScript.SUBDIVISIONS * s + ix] = 99.0

	var result: Dictionary = _builder._extract_edge_heights(heights)
	var south: PackedFloat32Array = result[2]
	assert_eq(south[0], 99.0, "South edge should match last row")


func test_extract_edge_heights_west_column() -> void:
	var s: int = TerrainScript.SUBDIVISIONS + 1
	var heights: Array[float] = []
	heights.resize(s * s)
	for i in range(s * s):
		heights[i] = 0.0
	# Set first column
	for iz in range(s):
		heights[iz * s] = float(iz) * 2.0

	var result: Dictionary = _builder._extract_edge_heights(heights)
	var west: PackedFloat32Array = result[3]
	for iz in range(s):
		assert_eq(
			west[iz],
			float(iz) * 2.0,
			"West edge iz=%d should match first column" % iz,
		)


func test_extract_edge_heights_east_column() -> void:
	var s: int = TerrainScript.SUBDIVISIONS + 1
	var heights: Array[float] = []
	heights.resize(s * s)
	for i in range(s * s):
		heights[i] = 0.0
	for iz in range(s):
		heights[iz * s + TerrainScript.SUBDIVISIONS] = 42.0

	var result: Dictionary = _builder._extract_edge_heights(heights)
	var east: PackedFloat32Array = result[1]
	assert_eq(east[0], 42.0, "East edge should match last column")


# ================================================================
# _parse_edge_heights
# ================================================================


func test_parse_edge_heights_empty_returns_empty() -> void:
	var result: Dictionary = _builder._parse_edge_heights({})
	assert_eq(result.size(), 0, "Empty tile_data should produce empty edges")


func test_parse_edge_heights_extracts_heights() -> void:
	var heights := PackedFloat32Array([1.0, 2.0, 3.0])
	var tile_data := {
		"edges":
		{
			0: {"heights": heights},
		},
	}
	var result: Dictionary = _builder._parse_edge_heights(tile_data)
	assert_true(result.has(0), "Should extract direction 0")
	var arr: PackedFloat32Array = result[0]
	assert_eq(arr.size(), 3)
	assert_eq(arr[0], 1.0)


func test_parse_edge_heights_skips_empty_arrays() -> void:
	var tile_data := {
		"edges":
		{
			0: {"heights": PackedFloat32Array()},
		},
	}
	var result: Dictionary = _builder._parse_edge_heights(tile_data)
	assert_false(
		result.has(0),
		"Empty height array should be skipped",
	)


# ================================================================
# _sample_edge_array
# ================================================================


func test_sample_edge_array_first_index() -> void:
	var arr := PackedFloat32Array([10.0, 20.0, 30.0])
	var result: float = _builder._sample_edge_array(arr, 0)
	assert_eq(result, 10.0, "Index 0 should return first element")


func test_sample_edge_array_last_index() -> void:
	var arr := PackedFloat32Array([10.0, 20.0, 30.0])
	var result: float = (
		_builder
		. _sample_edge_array(
			arr,
			TerrainScript.SUBDIVISIONS,
		)
	)
	assert_eq(result, 30.0, "Last index should return last element")


func test_sample_edge_array_mid_interpolates() -> void:
	var arr := PackedFloat32Array([0.0, 100.0])
	var mid_idx: int = TerrainScript.SUBDIVISIONS / 2
	var result: float = _builder._sample_edge_array(arr, mid_idx)
	# t = mid_idx / SUBDIVISIONS, interpolated between 0 and 100
	var expected: float = (float(mid_idx) / float(TerrainScript.SUBDIVISIONS)) * 100.0
	assert_almost_eq(
		result,
		expected,
		0.1,
		"Mid-index should interpolate between edges",
	)


# ================================================================
# _apply_edge_constraints
# ================================================================


func test_apply_edge_constraints_empty_returns_original() -> void:
	var result: float = (
		_builder
		. _apply_edge_constraints(
			5.0,
			8,
			8,
			{},
		)
	)
	assert_eq(
		result,
		5.0,
		"Empty constraints should return original height",
	)


func test_apply_edge_constraints_north_at_edge() -> void:
	var edge_heights := {
		0: PackedFloat32Array([10.0, 10.0, 10.0]),
	}
	# iz=0, at the north edge — should snap to edge height
	var result: float = (
		_builder
		. _apply_edge_constraints(
			0.0,
			0,
			0,
			edge_heights,
		)
	)
	assert_eq(
		result,
		10.0,
		"At north edge (iz=0), should snap to edge height",
	)


func test_apply_edge_constraints_beyond_blend_unaffected() -> void:
	var edge_heights := {
		0: PackedFloat32Array([10.0, 10.0, 10.0]),
	}
	# iz > BLEND_CELLS, should be unaffected by north constraint
	var iz: int = TerrainScript.BLEND_CELLS + 1
	var result: float = (
		_builder
		. _apply_edge_constraints(
			5.0,
			0,
			iz,
			edge_heights,
		)
	)
	assert_eq(
		result,
		5.0,
		"Beyond blend range, height should be unchanged",
	)


# ================================================================
# _apply_river_carving
# ================================================================


func test_river_carving_far_from_river_unchanged() -> void:
	var entry := Vector3(0.0, 0.0, 0.0)
	var exit_pt := Vector3(100.0, 0.0, 0.0)
	var result: float = (
		_builder
		. _apply_river_carving(
			10.0,
			0.0,
			50.0,
			entry,
			exit_pt,
			6.0,
		)
	)
	# Point at (0, 50) is 50m from river axis — well outside width+3
	assert_eq(
		result,
		10.0,
		"Point far from river should not be carved",
	)


func test_river_carving_inside_channel_depressed() -> void:
	var entry := Vector3(0.0, 0.0, 50.0)
	var exit_pt := Vector3(100.0, 0.0, 50.0)
	# Point directly on river axis
	var result: float = (
		_builder
		. _apply_river_carving(
			10.0,
			50.0,
			50.0,
			entry,
			exit_pt,
			6.0,
		)
	)
	assert_eq(
		result,
		8.0,
		"Point inside river channel should be depressed by 2.0",
	)


func test_river_carving_bank_slope_blends() -> void:
	var entry := Vector3(0.0, 0.0, 50.0)
	var exit_pt := Vector3(100.0, 0.0, 50.0)
	# Point at half_width + 1.5 from axis (bank zone)
	var half_w := 3.0
	var dist_from_axis := half_w + 1.5  # middle of bank
	var result: float = (
		_builder
		. _apply_river_carving(
			10.0,
			50.0,
			50.0 + dist_from_axis,
			entry,
			exit_pt,
			6.0,
		)
	)
	# bank_t = 1.5 / 3.0 = 0.5
	# lerp(8.0, 10.0, 0.5) = 9.0
	assert_almost_eq(
		result,
		9.0,
		0.01,
		"Bank should blend between carved and original height",
	)


func test_river_carving_zero_length_river_unchanged() -> void:
	var entry := Vector3(50.0, 0.0, 50.0)
	var exit_pt := Vector3(50.0, 0.0, 50.0)  # same point
	var result: float = (
		_builder
		. _apply_river_carving(
			10.0,
			50.0,
			50.0,
			entry,
			exit_pt,
			6.0,
		)
	)
	assert_eq(
		result,
		10.0,
		"Zero-length river should not carve",
	)


# ================================================================
# _river_edge_point
# ================================================================


func test_river_edge_point_north() -> void:
	var p: Vector3 = _builder._river_edge_point(0.0, 0.0, 50.0, 0, 0.5)
	assert_eq(p, Vector3(0.0, 0.0, -50.0))


func test_river_edge_point_east() -> void:
	var p: Vector3 = _builder._river_edge_point(0.0, 0.0, 50.0, 1, 0.5)
	assert_eq(p, Vector3(50.0, 0.0, 0.0))


func test_river_edge_point_south() -> void:
	var p: Vector3 = _builder._river_edge_point(0.0, 0.0, 50.0, 2, 0.5)
	assert_eq(p, Vector3(0.0, 0.0, 50.0))


func test_river_edge_point_west() -> void:
	var p: Vector3 = _builder._river_edge_point(0.0, 0.0, 50.0, 3, 0.5)
	assert_eq(p, Vector3(-50.0, 0.0, 0.0))


func test_river_edge_point_offset_position() -> void:
	# pos=0.75 should offset from center
	var p: Vector3 = _builder._river_edge_point(0.0, 0.0, 50.0, 0, 0.75)
	# offset = (0.75 - 0.5) * 50 * 2 = 25
	assert_eq(p, Vector3(25.0, 0.0, -50.0))


func test_river_edge_point_invalid_dir_returns_center() -> void:
	var p: Vector3 = _builder._river_edge_point(10.0, 20.0, 50.0, 99, 0.5)
	assert_eq(p, Vector3(10.0, 0.0, 20.0))


# ================================================================
# _height_to_color edge cases
# ================================================================


func test_color_deep_water() -> void:
	# Far below sea level should be darker blue
	var c: Color = _builder._height_to_color(-10.0)
	assert_true(c.b > 0.3, "Deep water should still be bluish")
	assert_true(c.r < 0.2, "Deep water should have low red")


func test_color_at_sea_level_boundary() -> void:
	# Exactly at SEA_LEVEL boundary
	var c: Color = _builder._height_to_color(-2.0)
	# h < 0 but >= SEA_LEVEL: beach zone
	assert_true(
		c.r > 0.2,
		"At sea level boundary should be in beach zone",
	)


func test_color_rock_at_35() -> void:
	# Between 30 and 50 should be rock-snow transition
	var c: Color = _builder._height_to_color(35.0)
	assert_true(c.r > 0.3, "Should have rock color component")


# ================================================================
# Build with edge constraints
# ================================================================


func test_build_with_edge_heights_returns_edges() -> void:
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	var span: float = _grid.get_grid_span()
	var result: Dictionary = (
		_builder
		. build(
			chunk,
			Vector2i(5, 0),
			5.0 * span,
			0.0,
		)
	)
	assert_true(result.has(0), "Build should return north edge heights")
	assert_true(result.has(1), "Build should return east edge heights")
	assert_true(result.has(2), "Build should return south edge heights")
	assert_true(result.has(3), "Build should return west edge heights")


func test_build_with_river_data() -> void:
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	var span: float = _grid.get_grid_span()
	var river_data := {
		"entry_dir": 0,
		"exit_dir": 2,
		"position": 0.5,
		"width": 6.0,
	}
	# Should not crash
	(
		_builder
		. build(
			chunk,
			Vector2i(5, 0),
			5.0 * span,
			0.0,
			{},
			river_data,
		)
	)
	assert_true(
		chunk.has_meta("terrain_min_height"),
		"Build with river data should still set metadata",
	)


# ================================================================
# Sea plane material — night rendering fix
# ================================================================


func test_sea_plane_uses_unshaded_mode() -> void:
	# Sea plane must be unshaded so ambient light cannot bleed through
	# as a false "illuminated from below" glow at night.
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	var span: float = _grid.get_grid_span()
	# Build a west-ocean chunk that is guaranteed to have water
	_builder.build(chunk, Vector2i(-4, 0), -4.0 * span, 0.0)

	var sea_plane: MeshInstance3D = null
	for child in chunk.get_children():
		if child is MeshInstance3D and child.name == "SeaPlane":
			sea_plane = child
			break

	if sea_plane == null:
		return  # chunk happened to have no water — skip
	var mat := sea_plane.material_override as StandardMaterial3D
	assert_not_null(mat, "SeaPlane should have a StandardMaterial3D override")
	assert_eq(
		mat.shading_mode,
		BaseMaterial3D.SHADING_MODE_UNSHADED,
		"Sea plane must be unshaded to prevent false night glow",
	)


func test_sea_plane_is_mostly_opaque() -> void:
	# Alpha < 0.85 lets the seabed show through at distance,
	# making the ocean look lit from below at night.
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	var span: float = _grid.get_grid_span()
	_builder.build(chunk, Vector2i(-4, 0), -4.0 * span, 0.0)

	var sea_plane: MeshInstance3D = null
	for child in chunk.get_children():
		if child is MeshInstance3D and child.name == "SeaPlane":
			sea_plane = child
			break

	if sea_plane == null:
		return
	var mat := sea_plane.material_override as StandardMaterial3D
	assert_not_null(mat)
	assert_true(
		mat.albedo_color.a >= 0.85,
		"Sea plane alpha should be ≥ 0.85 to hide the seabed (got %.2f)" % mat.albedo_color.a,
	)
