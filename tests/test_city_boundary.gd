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
	var min_expected: float = (3.8 - 0.8 + 0.5) * _grid_span  # 3.5 * span
	var max_expected: float = (3.8 + 0.8 + 0.5) * _grid_span  # 5.1 * span
	for i in range(72):
		var angle: float = float(i) * TAU / 72.0
		var r: float = _boundary.get_boundary_radius_at_angle(angle)
		assert_true(
			r >= min_expected and r <= max_expected,
			"Radius %f at angle %f should be in [%f, %f]" % [
				r, angle, min_expected, max_expected,
			],
		)


func test_boundary_seamless_at_zero_twopi() -> void:
	var r0: float = _boundary.get_boundary_radius_at_angle(0.0)
	var r_tau: float = _boundary.get_boundary_radius_at_angle(TAU)
	assert_almost_eq(
		r0, r_tau, 0.01,
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
			r1, r2,
			"Two instances should produce same radius at angle %f" % angle,
		)


func test_polygon_has_correct_point_count() -> void:
	var poly: PackedVector2Array = _boundary.get_boundary_polygon(72)
	assert_eq(
		poly.size(), 72,
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
