extends GutTest
## Unit tests for road_grid.gd shared road grid math with infinite tiling.

const RoadGridScript = preload("res://src/road_grid.gd")

var _grid: RefCounted


func before_each() -> void:
	_grid = RoadGridScript.new()


# --- Constants ---


func test_grid_size_is_ten() -> void:
	assert_eq(RoadGridScript.GRID_SIZE, 10)


func test_road_width_is_eight() -> void:
	assert_eq(RoadGridScript.ROAD_WIDTH, 8.0)


func test_boulevard_width_is_twelve() -> void:
	assert_eq(RoadGridScript.BOULEVARD_WIDTH, 12.0)


func test_alley_width_is_four() -> void:
	assert_eq(RoadGridScript.ALLEY_WIDTH, 4.0)


func test_boulevard_index_is_five() -> void:
	assert_eq(RoadGridScript.BOULEVARD_INDEX, 5)


func test_alley_index_is_two() -> void:
	assert_eq(RoadGridScript.ALLEY_INDEX, 2)


# --- get_road_width ---


func test_get_road_width_normal_road() -> void:
	assert_eq(_grid.get_road_width(0), 8.0)
	assert_eq(_grid.get_road_width(1), 8.0)
	assert_eq(_grid.get_road_width(3), 8.0)
	assert_eq(_grid.get_road_width(10), 8.0)


func test_get_road_width_boulevard() -> void:
	assert_eq(_grid.get_road_width(5), 12.0)


func test_get_road_width_alley() -> void:
	assert_eq(_grid.get_road_width(2), 4.0)


# --- get_grid_span ---


func test_grid_span_positive() -> void:
	assert_gt(_grid.get_grid_span(), 0.0, "Grid span should be positive")


func test_grid_span_equals_sum_of_roads_and_blocks() -> void:
	var expected := 0.0
	for i in range(RoadGridScript.GRID_SIZE + 1):
		expected += _grid.get_road_width(i)
	expected += RoadGridScript.BLOCK_SIZE * RoadGridScript.GRID_SIZE
	assert_almost_eq(
		_grid.get_grid_span(),
		expected,
		0.001,
		"Grid span should equal sum of all road widths + all block widths",
	)


# --- _road_centers initialization ---


func test_road_centers_count() -> void:
	assert_eq(
		_grid._road_centers.size(),
		RoadGridScript.GRID_SIZE + 1,
		"Should have GRID_SIZE + 1 road centers",
	)


func test_road_centers_are_sorted() -> void:
	for i in range(_grid._road_centers.size() - 1):
		assert_lt(
			_grid._road_centers[i],
			_grid._road_centers[i + 1],
			"Road centers should be in ascending order",
		)


func test_road_centers_span_roughly_symmetric() -> void:
	var first: float = _grid._road_centers[0]
	var last: float = _grid._road_centers[_grid._road_centers.size() - 1]
	assert_almost_eq(
		absf(first + last),
		0.0,
		_grid.get_grid_span() * 0.1,
		"Road centers should be roughly symmetric around 0",
	)


# --- get_road_center_local ---


func test_get_road_center_local_matches_internal_array() -> void:
	for i in range(RoadGridScript.GRID_SIZE + 1):
		assert_eq(
			_grid.get_road_center_local(i),
			_grid._road_centers[i],
		)


# --- get_road_center_near ---


func test_get_road_center_near_at_origin() -> void:
	var center: float = _grid.get_road_center_near(0, 0.0)
	assert_almost_eq(
		center,
		_grid._road_centers[0],
		0.001,
		"Near origin, road 0 center should be its local center",
	)


func test_get_road_center_near_one_tile_away() -> void:
	var span: float = _grid.get_grid_span()
	var center: float = _grid.get_road_center_near(0, span)
	var expected: float = _grid._road_centers[0] + span
	assert_almost_eq(
		center,
		expected,
		0.001,
		"One tile away, center should shift by one grid span",
	)


func test_get_road_center_near_negative_tile() -> void:
	var span: float = _grid.get_grid_span()
	var center: float = _grid.get_road_center_near(0, -span)
	var expected: float = _grid._road_centers[0] - span
	assert_almost_eq(
		center,
		expected,
		0.001,
		"Negative tile offset should shift center by -span",
	)


func test_get_road_center_near_boulevard() -> void:
	var span: float = _grid.get_grid_span()
	var ref: float = span * 3.0
	var center: float = (
		_grid
		. get_road_center_near(
			RoadGridScript.BOULEVARD_INDEX,
			ref,
		)
	)
	var dist: float = absf(center - ref)
	assert_lt(
		dist,
		span,
		"Nearest boulevard center should be within one span of ref",
	)


# --- get_nearest_road_index ---


func test_get_nearest_road_index_at_road_center() -> void:
	for i in range(RoadGridScript.GRID_SIZE + 1):
		var coord: float = _grid._road_centers[i]
		var idx: int = _grid.get_nearest_road_index(coord)
		assert_eq(
			idx,
			i,
			"At road center %d, nearest index should be %d" % [i, i],
		)


func test_get_nearest_road_index_offset_by_one_span() -> void:
	var span: float = _grid.get_grid_span()
	for i in range(RoadGridScript.GRID_SIZE + 1):
		var coord: float = _grid._road_centers[i] + span
		var idx: int = _grid.get_nearest_road_index(coord)
		assert_eq(idx, i, "Should find same road index one tile over")


func test_get_nearest_road_index_midpoint_between_roads() -> void:
	var mid: float = (_grid._road_centers[0] + _grid._road_centers[1]) / 2.0
	var idx: int = _grid.get_nearest_road_index(mid)
	assert_true(
		idx == 0 or idx == 1,
		"Midpoint between roads 0 and 1 should return 0 or 1",
	)


# --- get_chunk_coord ---


func test_get_chunk_coord_at_origin() -> void:
	var coord: Vector2i = _grid.get_chunk_coord(Vector2(0.0, 0.0))
	assert_eq(coord, Vector2i(0, 0))


func test_get_chunk_coord_one_tile_east() -> void:
	var span: float = _grid.get_grid_span()
	var coord: Vector2i = _grid.get_chunk_coord(Vector2(span, 0.0))
	assert_eq(coord, Vector2i(1, 0))


func test_get_chunk_coord_one_tile_south() -> void:
	var span: float = _grid.get_grid_span()
	var coord: Vector2i = _grid.get_chunk_coord(Vector2(0.0, span))
	assert_eq(coord, Vector2i(0, 1))


func test_get_chunk_coord_negative() -> void:
	var span: float = _grid.get_grid_span()
	var coord: Vector2i = _grid.get_chunk_coord(Vector2(-span, -span))
	assert_eq(coord, Vector2i(-1, -1))


func test_get_chunk_coord_near_boundary() -> void:
	var span: float = _grid.get_grid_span()
	var nearly: float = span * 0.5 - 0.1
	var coord: Vector2i = _grid.get_chunk_coord(Vector2(nearly, nearly))
	assert_eq(coord, Vector2i(0, 0))


func test_get_chunk_coord_just_past_boundary() -> void:
	var span: float = _grid.get_grid_span()
	var beyond: float = span * 0.5 + 0.1
	var coord: Vector2i = _grid.get_chunk_coord(Vector2(beyond, beyond))
	assert_eq(coord, Vector2i(1, 1))


# --- get_chunk_origin ---


func test_get_chunk_origin_at_zero() -> void:
	var origin: Vector2 = _grid.get_chunk_origin(Vector2i(0, 0))
	assert_almost_eq(origin.x, 0.0, 0.001)
	assert_almost_eq(origin.y, 0.0, 0.001)


func test_get_chunk_origin_positive() -> void:
	var span: float = _grid.get_grid_span()
	var origin: Vector2 = _grid.get_chunk_origin(Vector2i(2, 3))
	assert_almost_eq(origin.x, 2.0 * span, 0.001)
	assert_almost_eq(origin.y, 3.0 * span, 0.001)


func test_get_chunk_origin_negative() -> void:
	var span: float = _grid.get_grid_span()
	var origin: Vector2 = _grid.get_chunk_origin(Vector2i(-1, -2))
	assert_almost_eq(origin.x, -1.0 * span, 0.001)
	assert_almost_eq(origin.y, -2.0 * span, 0.001)


func test_chunk_coord_and_origin_roundtrip() -> void:
	for cx in range(-2, 3):
		for cz in range(-2, 3):
			var chunk := Vector2i(cx, cz)
			var origin: Vector2 = _grid.get_chunk_origin(chunk)
			var recovered: Vector2i = _grid.get_chunk_coord(origin)
			assert_eq(
				recovered,
				chunk,
				"Roundtrip for chunk %s should match" % str(chunk),
			)


# --- is_on_ramp ---


func test_is_on_ramp_at_origin_center_is_false() -> void:
	assert_false(_grid.is_on_ramp(0.0, 0.0))


func test_is_on_ramp_at_known_ramp_position() -> void:
	var origin: Vector2 = _grid.get_chunk_origin(Vector2i(0, 0))
	var blvd_x: float = _grid._road_centers[RoadGridScript.BOULEVARD_INDEX] + origin.x
	var ramp_z: float = -80.0 + origin.y
	assert_true(
		_grid.is_on_ramp(blvd_x, ramp_z),
		"Should detect ramp at boulevard z=-80 position",
	)


func test_is_on_ramp_at_second_ramp_position() -> void:
	var origin: Vector2 = _grid.get_chunk_origin(Vector2i(0, 0))
	var blvd_x: float = _grid._road_centers[RoadGridScript.BOULEVARD_INDEX] + origin.x
	var ramp_z: float = 80.0 + origin.y
	assert_true(
		_grid.is_on_ramp(blvd_x, ramp_z),
		"Should detect ramp at boulevard z=+80 position",
	)


func test_is_on_ramp_at_third_ramp_position() -> void:
	var origin: Vector2 = _grid.get_chunk_origin(Vector2i(0, 0))
	var ramp_x: float = -60.0 + origin.x
	var road7_z: float = _grid._road_centers[7] + origin.y
	assert_true(
		_grid.is_on_ramp(ramp_x, road7_z),
		"Should detect ramp at x=-60 road7 position",
	)


func test_is_on_ramp_at_fourth_ramp_position() -> void:
	var origin: Vector2 = _grid.get_chunk_origin(Vector2i(0, 0))
	var ramp_x: float = 60.0 + origin.x
	var road3_z: float = _grid._road_centers[3] + origin.y
	assert_true(
		_grid.is_on_ramp(ramp_x, road3_z),
		"Should detect ramp at x=+60 road3 position",
	)


func test_is_on_ramp_far_from_any_ramp() -> void:
	assert_false(
		_grid.is_on_ramp(5000.0, 5000.0),
		"Arbitrary far position should not be on a ramp",
	)


func test_is_on_ramp_works_in_different_chunk() -> void:
	var origin: Vector2 = _grid.get_chunk_origin(Vector2i(3, -2))
	var blvd_x: float = _grid._road_centers[RoadGridScript.BOULEVARD_INDEX] + origin.x
	var ramp_z: float = -80.0 + origin.y
	assert_true(
		_grid.is_on_ramp(blvd_x, ramp_z),
		"Ramp detection should work in non-origin chunks",
	)


func test_is_on_ramp_just_outside_exclusion_zone() -> void:
	var origin: Vector2 = _grid.get_chunk_origin(Vector2i(0, 0))
	var blvd_x: float = _grid._road_centers[RoadGridScript.BOULEVARD_INDEX] + origin.x
	var ramp_z: float = -80.0 + origin.y
	assert_false(
		_grid.is_on_ramp(blvd_x + 5.1, ramp_z + 6.1),
		"Just outside exclusion zone should not be on ramp",
	)


# --- get_road_center_near (additional) ---


func test_get_road_center_near_returns_float() -> void:
	var result: float = _grid.get_road_center_near(0, 0.0)
	assert_true(result is float, "get_road_center_near should return a float")


func test_get_road_center_near_far_ref_coord_within_one_span() -> void:
	var span: float = _grid.get_grid_span()
	var ref_coord: float = 500.0
	var result: float = _grid.get_road_center_near(0, ref_coord)
	assert_lt(
		absf(result - ref_coord),
		span,
		"Result should be within one grid span of ref_coord",
	)


func test_get_road_center_near_large_negative_ref_coord() -> void:
	var span: float = _grid.get_grid_span()
	var ref_coord: float = -500.0
	var result: float = _grid.get_road_center_near(0, ref_coord)
	assert_lt(
		absf(result - ref_coord),
		span,
		"Result should be within one grid span of large negative ref_coord",
	)


# --- get_nearest_road_index (additional) ---


func test_get_nearest_road_index_at_origin_is_valid() -> void:
	var idx: int = _grid.get_nearest_road_index(0.0)
	assert_true(
		idx >= 0 and idx <= RoadGridScript.GRID_SIZE,
		"Index at origin should be between 0 and GRID_SIZE",
	)


func test_get_nearest_road_index_large_coord_is_valid() -> void:
	var idx: int = _grid.get_nearest_road_index(10000.0)
	assert_true(
		idx >= 0 and idx <= RoadGridScript.GRID_SIZE,
		"Index at large coord should be between 0 and GRID_SIZE",
	)


func test_get_nearest_road_index_large_negative_coord_is_valid() -> void:
	var idx: int = _grid.get_nearest_road_index(-10000.0)
	assert_true(
		idx >= 0 and idx <= RoadGridScript.GRID_SIZE,
		"Index at large negative coord should be between 0 and GRID_SIZE",
	)


# --- get_chunk_coord (additional) ---


func test_get_chunk_coord_origin_returns_zero_zero() -> void:
	var coord: Vector2i = _grid.get_chunk_coord(Vector2(0.0, 0.0))
	assert_eq(coord, Vector2i(0, 0), "Origin should map to chunk (0,0)")


func test_get_chunk_coord_one_span_east_returns_one_zero() -> void:
	var span: float = _grid.get_grid_span()
	var coord: Vector2i = _grid.get_chunk_coord(Vector2(span, 0.0))
	assert_eq(coord, Vector2i(1, 0), "One span east should map to chunk (1,0)")


# --- get_chunk_origin (additional) ---


func test_get_chunk_origin_zero_zero_is_origin() -> void:
	var origin: Vector2 = _grid.get_chunk_origin(Vector2i(0, 0))
	assert_almost_eq(origin.x, 0.0, 0.001, "Chunk (0,0) origin x should be 0")
	assert_almost_eq(origin.y, 0.0, 0.001, "Chunk (0,0) origin y should be 0")


func test_get_chunk_origin_one_zero_x_equals_span() -> void:
	var span: float = _grid.get_grid_span()
	var origin: Vector2 = _grid.get_chunk_origin(Vector2i(1, 0))
	assert_almost_eq(
		origin.x,
		span,
		0.001,
		"Chunk (1,0) origin x should equal grid span",
	)


# --- is_on_ramp (additional) ---


func test_is_on_ramp_does_not_crash_at_arbitrary_position() -> void:
	var result: bool = _grid.is_on_ramp(999.0, 999.0)
	assert_true(result == true or result == false, "is_on_ramp should not crash")


func test_is_on_ramp_boulevard_at_minus_80_is_true() -> void:
	var blvd_x: float = _grid.get_road_center_near(RoadGridScript.BOULEVARD_INDEX, 0.0)
	assert_true(
		_grid.is_on_ramp(blvd_x, -80.0),
		"Boulevard x at z=-80 should be on ramp",
	)
