extends GutTest
## Unit tests for city_boundary.gd noise-modulated circular boundary.

const BoundaryScript = preload("res://src/city_boundary.gd")
const RoadGridScript = preload("res://src/road_grid.gd")

var _boundary: RefCounted
var _grid_span: float


func before_each() -> void:
	var grid: RefCounted = RoadGridScript.new()
	_grid_span = grid.get_grid_span()
	_boundary = BoundaryScript.new()
	_boundary.init(_grid_span)


func test_origin_is_inside_city() -> void:
	assert_true(
		_boundary.is_city_tile(Vector2i(0, 0)),
		"Origin tile should be inside city",
	)


func test_far_tile_is_outside_city() -> void:
	assert_false(
		_boundary.is_city_tile(Vector2i(10, 10)),
		"Tile (10,10) should be outside city",
	)


func test_boundary_radius_positive() -> void:
	for i in range(36):
		var angle: float = float(i) * TAU / 36.0
		var r: float = _boundary.get_boundary_radius_at_angle(angle)
		assert_gt(r, 0.0, "Boundary radius must be positive at angle %f" % angle)


func test_boundary_radius_within_expected_range() -> void:
	# Use actual constants from city_boundary.gd (BASE_RADIUS=0.76, VARIATION=0.16)
	var min_expected: float = (0.76 - 0.16 + 0.5) * _grid_span  # 1.1 * span
	var max_expected: float = (0.76 + 0.16 + 0.5) * _grid_span  # 1.42 * span
	for i in range(72):
		var angle: float = float(i) * TAU / 72.0
		var r: float = _boundary.get_boundary_radius_at_angle(angle)
		assert_true(
			r >= min_expected and r <= max_expected,
			(
				"Radius %f at angle %f should be in [%f, %f]"
				% [
					r,
					angle,
					min_expected,
					max_expected,
				]
			),
		)


func test_boundary_seamless_at_zero_twopi() -> void:
	var r0: float = _boundary.get_boundary_radius_at_angle(0.0)
	var r_tau: float = _boundary.get_boundary_radius_at_angle(TAU)
	assert_almost_eq(
		r0,
		r_tau,
		0.01,
		"Boundary should be seamless at 0 and TAU",
	)


func test_signed_distance_negative_at_origin() -> void:
	var d: float = _boundary.get_signed_distance(0.0, 0.0)
	assert_lt(d, 0.0, "Signed distance at origin should be negative (inside)")


func test_signed_distance_positive_far_away() -> void:
	var d: float = _boundary.get_signed_distance(10000.0, 10000.0)
	assert_gt(d, 0.0, "Signed distance far away should be positive (outside)")


func test_boundary_deterministic() -> void:
	var b2: RefCounted = BoundaryScript.new()
	b2.init(_grid_span)
	for i in range(36):
		var angle: float = float(i) * TAU / 36.0
		var r1: float = _boundary.get_boundary_radius_at_angle(angle)
		var r2: float = b2.get_boundary_radius_at_angle(angle)
		assert_eq(
			r1,
			r2,
			"Two instances should produce same radius at angle %f" % angle,
		)


func test_polygon_has_correct_point_count() -> void:
	var poly: PackedVector2Array = _boundary.get_boundary_polygon(72)
	assert_eq(
		poly.size(),
		72,
		"Polygon should have 72 points",
	)


func test_is_city_tile_deterministic() -> void:
	var b2: RefCounted = BoundaryScript.new()
	b2.init(_grid_span)
	for x in range(-5, 6):
		for y in range(-5, 6):
			var tile := Vector2i(x, y)
			assert_eq(
				_boundary.is_city_tile(tile),
				b2.is_city_tile(tile),
				"Tile (%d,%d) should be deterministic" % [x, y],
			)


func test_ground_height_zero_inside_city() -> void:
	var b: RefCounted = BoundaryScript.new()
	b.init(_grid_span, _make_terrain_noise())
	var h: float = b.get_ground_height(0.0, 0.0)
	assert_eq(h, 0.0, "Ground height at origin (inside city) should be 0.0")


func test_ground_height_below_sea_level_west_ocean() -> void:
	var b: RefCounted = BoundaryScript.new()
	b.init(_grid_span, _make_terrain_noise())
	var found_below := false
	for i in range(5, 15):
		var wx: float = -_grid_span * float(i)
		var h: float = b.get_ground_height(wx, 0.0)
		if h < -2.0:
			found_below = true
			break
	assert_true(
		found_below,
		"At least one far-west sample should be below sea level (-2.0)",
	)


func test_mesh_height_zero_inside_city() -> void:
	var b: RefCounted = BoundaryScript.new()
	b.init(_grid_span, _make_terrain_noise())
	# Origin is inside city — bilinear corners are all 0.0
	assert_eq(b.get_mesh_height(0.0, 0.0), 0.0)


func test_mesh_height_bounded_by_corners() -> void:
	# Bilinear interpolation must produce a value between the min and max
	# of the four surrounding grid corners.  This is the key invariant that
	# prevents trees from floating above or sinking below the terrain mesh.
	var b: RefCounted = BoundaryScript.new()
	b.init(_grid_span, _make_terrain_noise())
	var step: float = _grid_span / float(BoundaryScript.TERRAIN_SUBDIVISIONS)
	# Sample several arbitrary points well outside the city
	var test_points: Array[Vector2] = [
		Vector2(_grid_span * 2.3, _grid_span * 0.5),
		Vector2(_grid_span * 1.8, _grid_span * 1.8),
		Vector2(_grid_span * 3.0, _grid_span * 0.0),
	]
	for pt: Vector2 in test_points:
		var wx: float = pt.x
		var wz: float = pt.y
		var gx: float = floor(wx / step) * step
		var gz: float = floor(wz / step) * step
		var h00: float = b.get_ground_height(gx, gz)
		var h10: float = b.get_ground_height(gx + step, gz)
		var h01: float = b.get_ground_height(gx, gz + step)
		var h11: float = b.get_ground_height(gx + step, gz + step)
		var lo: float = minf(minf(h00, h10), minf(h01, h11))
		var hi: float = maxf(maxf(h00, h10), maxf(h01, h11))
		var mh: float = b.get_mesh_height(wx, wz)
		assert_true(
			mh >= lo - 0.001 and mh <= hi + 0.001,
			(
				"get_mesh_height(%g,%g)=%g must be within corner range [%g,%g]"
				% [
					wx,
					wz,
					mh,
					lo,
					hi,
				]
			),
		)


func test_mesh_height_matches_corners_exactly_on_grid() -> void:
	# At a grid vertex the bilinear result must exactly equal get_ground_height.
	var b: RefCounted = BoundaryScript.new()
	b.init(_grid_span, _make_terrain_noise())
	var step: float = _grid_span / float(BoundaryScript.TERRAIN_SUBDIVISIONS)
	var wx: float = step * 40.0  # arbitrary integer multiple — on-grid
	var wz: float = step * 25.0
	assert_almost_eq(
		b.get_mesh_height(wx, wz),
		b.get_ground_height(wx, wz),
		0.001,
		"get_mesh_height at a grid vertex must equal get_ground_height",
	)


func test_rural_trees_source_uses_mesh_height() -> void:
	var src: String = (
		(load("res://scenes/world/generator/chunk_builder_rural_trees.gd") as GDScript).source_code
	)
	assert_true(
		src.contains("get_mesh_height"),
		"Rural tree builder must use get_mesh_height for tree placement",
	)


static func _make_terrain_noise() -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = 0.003
	n.fractal_octaves = 4
	n.fractal_lacunarity = 2.0
	n.fractal_gain = 0.5
	n.fractal_type = FastNoiseLite.FRACTAL_FBM
	n.seed = 42
	return n
