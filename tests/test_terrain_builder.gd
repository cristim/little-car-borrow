extends GutTest
## Unit tests for chunk_builder_terrain.gd height sampling, vertex coloring,
## and sea plane generation.

const TerrainScript = preload(
	"res://scenes/world/generator/chunk_builder_terrain.gd"
)
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
		h, 0.0, 0.1,
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
	var h_left: float = _builder._sample_height(
		boundary_x - 0.1, 0.0
	)
	var h_right: float = _builder._sample_height(
		boundary_x + 0.1, 0.0
	)
	assert_almost_eq(
		h_left, h_right, 1.0,
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
		c, Color(0.90, 0.90, 0.92),
		"High altitude should be snow color",
	)


func test_color_grass_at_mid_height() -> void:
	# At 15m (between 0 and 20), should be pure grass
	var c: Color = _builder._height_to_color(15.0)
	assert_eq(
		c, Color(0.22, 0.45, 0.18),
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
	# Compare height near city vs far west — far west should be much lower
	var city_edge: float = _boundary.get_boundary_radius_at_angle(PI)
	var near_h: float = _builder._sample_height(-city_edge - span * 2.0, 0.0)
	var far_h: float = _builder._sample_height(-city_edge - span * 6.0, 0.0)
	assert_true(
		far_h < near_h,
		"Far west (%f) should be lower than near west (%f)" % [far_h, near_h],
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
