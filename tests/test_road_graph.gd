# gdlint:ignore = max-public-methods
extends GutTest
## Unit tests for A* road graph pathfinding.

var _grid = preload("res://src/road_grid.gd").new()
var _graph = preload("res://src/road_graph.gd").new()

# ================================================================
# Basic pathfinding
# ================================================================


func test_same_intersection_returns_empty() -> void:
	var pos := Vector3(
		_grid.get_road_center_near(3, 0.0),
		0.0,
		_grid.get_road_center_near(5, 0.0),
	)
	var path: Array[Vector3] = _graph.find_path(pos, pos, _grid)
	assert_eq(
		path.size(),
		0,
		"Same start and goal should return empty path",
	)


func test_adjacent_ns_intersection() -> void:
	var from := Vector3(
		_grid.get_road_center_near(3, 0.0),
		0.0,
		_grid.get_road_center_near(5, 0.0),
	)
	var to := Vector3(
		_grid.get_road_center_near(4, 0.0),
		0.0,
		_grid.get_road_center_near(5, 0.0),
	)
	var path: Array[Vector3] = _graph.find_path(from, to, _grid)
	assert_eq(
		path.size(),
		2,
		"Adjacent intersections should produce 2-waypoint path",
	)
	assert_almost_eq(path[0].x, from.x, 1.0)
	assert_almost_eq(path[1].x, to.x, 1.0)
	assert_almost_eq(path[0].z, path[1].z, 1.0)


func test_adjacent_ew_intersection() -> void:
	var from := Vector3(
		_grid.get_road_center_near(3, 0.0),
		0.0,
		_grid.get_road_center_near(5, 0.0),
	)
	var to := Vector3(
		_grid.get_road_center_near(3, 0.0),
		0.0,
		_grid.get_road_center_near(6, 0.0),
	)
	var path: Array[Vector3] = _graph.find_path(from, to, _grid)
	assert_eq(
		path.size(),
		2,
		"Adjacent EW intersections should produce 2-waypoint path",
	)
	assert_almost_eq(path[0].x, path[1].x, 1.0)


func test_multi_step_path() -> void:
	var from := Vector3(
		_grid.get_road_center_near(1, 0.0),
		0.0,
		_grid.get_road_center_near(1, 0.0),
	)
	var to := Vector3(
		_grid.get_road_center_near(4, 0.0),
		0.0,
		_grid.get_road_center_near(1, 0.0),
	)
	var path: Array[Vector3] = _graph.find_path(from, to, _grid)
	assert_eq(
		path.size(),
		4,
		"3-hop path should produce 4 waypoints (start + 3 steps)",
	)


func test_path_follows_grid_not_diagonal() -> void:
	var from := Vector3(
		_grid.get_road_center_near(3, 0.0),
		0.0,
		_grid.get_road_center_near(3, 0.0),
	)
	var to := Vector3(
		_grid.get_road_center_near(5, 0.0),
		0.0,
		_grid.get_road_center_near(5, 0.0),
	)
	var path: Array[Vector3] = _graph.find_path(from, to, _grid)
	assert_true(
		path.size() >= 3,
		"Diagonal path needs at least 3 waypoints",
	)
	# Each segment should be axis-aligned (same X or same Z)
	for i in range(path.size() - 1):
		var dx := absf(path[i].x - path[i + 1].x)
		var dz := absf(path[i].z - path[i + 1].z)
		assert_true(
			dx < 2.0 or dz < 2.0,
			"Segment %d-%d must be axis-aligned (dx=%f, dz=%f)" % [i, i + 1, dx, dz],
		)


# ================================================================
# Tile boundary crossing
# ================================================================


func test_path_crosses_tile_boundary() -> void:
	var span: float = _grid.get_grid_span()
	var from := Vector3(
		_grid.get_road_center_near(9, 0.0),
		0.0,
		_grid.get_road_center_near(5, 0.0),
	)
	var to := Vector3(
		_grid.get_road_center_near(1, span),
		0.0,
		_grid.get_road_center_near(5, 0.0),
	)
	var path: Array[Vector3] = _graph.find_path(from, to, _grid)
	assert_true(
		path.size() >= 2,
		"Cross-tile path should have >= 2 waypoints, got %d" % path.size(),
	)
	assert_almost_eq(path[0].x, from.x, 2.0)
	assert_almost_eq(
		path[path.size() - 1].x,
		to.x,
		2.0,
	)


# ================================================================
# Heuristic consistency
# ================================================================


func test_path_length_within_bound() -> void:
	var from := Vector3(
		_grid.get_road_center_near(1, 0.0),
		0.0,
		_grid.get_road_center_near(1, 0.0),
	)
	var to := Vector3(
		_grid.get_road_center_near(8, 0.0),
		0.0,
		_grid.get_road_center_near(8, 0.0),
	)
	var euclidean := from.distance_to(to)
	var path: Array[Vector3] = _graph.find_path(from, to, _grid)
	assert_true(path.size() >= 2, "Should find a path")

	var path_length := 0.0
	for i in range(path.size() - 1):
		path_length += path[i].distance_to(path[i + 1])

	assert_true(
		path_length <= euclidean * 2.0,
		"Path length %f should be <= 2x Euclidean %f" % [path_length, euclidean],
	)


# ================================================================
# Edge cases
# ================================================================


func test_from_off_road_position() -> void:
	var from := Vector3(20.0, 0.0, 20.0)
	var to := Vector3(
		_grid.get_road_center_near(7, 0.0),
		0.0,
		_grid.get_road_center_near(7, 0.0),
	)
	var path: Array[Vector3] = _graph.find_path(from, to, _grid)
	assert_true(
		path.size() >= 2,
		"Should find path from off-road position",
	)


func test_distant_goal_handles_gracefully() -> void:
	var from := Vector3(0.0, 0.0, 0.0)
	var to := Vector3(2000.0, 0.0, 2000.0)
	var path: Array[Vector3] = _graph.find_path(from, to, _grid)
	# Should return empty (beyond MAX_SEARCH_RADIUS) without crashing
	assert_eq(
		path.size(),
		0,
		"Distant goal should return empty path",
	)


func test_waypoints_at_road_level() -> void:
	var from := Vector3(
		_grid.get_road_center_near(2, 0.0),
		5.0,
		_grid.get_road_center_near(2, 0.0),
	)
	var to := Vector3(
		_grid.get_road_center_near(6, 0.0),
		-3.0,
		_grid.get_road_center_near(6, 0.0),
	)
	var path: Array[Vector3] = _graph.find_path(from, to, _grid)
	for i in range(path.size()):
		assert_eq(
			path[i].y,
			0.0,
			"Waypoint %d Y should be 0.0 (road level)" % i,
		)


# ================================================================
# Neighbor generation
# ================================================================


func test_neighbor_count_interior() -> void:
	var pos := Vector3(
		_grid.get_road_center_near(5, 0.0),
		0.0,
		_grid.get_road_center_near(5, 0.0),
	)
	var neighbors: Array = _graph._get_neighbors(5, 5, pos, _grid)
	assert_eq(neighbors.size(), 4)


func test_neighbor_count_at_tile_edge() -> void:
	var pos := Vector3(
		_grid.get_road_center_near(0, 0.0),
		0.0,
		_grid.get_road_center_near(0, 0.0),
	)
	var neighbors: Array = _graph._get_neighbors(0, 0, pos, _grid)
	assert_eq(
		neighbors.size(),
		4,
		"Edge node should have 4 neighbors (wrapping)",
	)


func test_neighbors_are_distinct() -> void:
	var pos := Vector3(
		_grid.get_road_center_near(5, 0.0),
		0.0,
		_grid.get_road_center_near(5, 0.0),
	)
	var neighbors: Array = _graph._get_neighbors(5, 5, pos, _grid)
	for i in range(neighbors.size()):
		for j in range(i + 1, neighbors.size()):
			var pi: Vector3 = neighbors[i][2]
			var pj: Vector3 = neighbors[j][2]
			assert_true(
				pi.distance_to(pj) > 10.0,
				"Neighbors %d and %d must be distinct" % [i, j],
			)


func test_neighbors_are_axis_aligned() -> void:
	var pos := Vector3(
		_grid.get_road_center_near(5, 0.0),
		0.0,
		_grid.get_road_center_near(5, 0.0),
	)
	var neighbors: Array = _graph._get_neighbors(5, 5, pos, _grid)
	for n in neighbors:
		var n_pos: Vector3 = n[2]
		var same_x := absf(n_pos.x - pos.x) < 2.0
		var same_z := absf(n_pos.z - pos.z) < 2.0
		assert_true(
			same_x or same_z,
			"Neighbor must share X or Z road with current node",
		)


func test_neighbors_in_correct_directions() -> void:
	var pos := Vector3(
		_grid.get_road_center_near(5, 0.0),
		0.0,
		_grid.get_road_center_near(5, 0.0),
	)
	var neighbors: Array = _graph._get_neighbors(5, 5, pos, _grid)
	# neighbors[0] = North (Z < current)
	assert_true(
		(neighbors[0][2] as Vector3).z < pos.z,
		"North neighbor should have Z < current",
	)
	# neighbors[1] = South (Z > current)
	assert_true(
		(neighbors[1][2] as Vector3).z > pos.z,
		"South neighbor should have Z > current",
	)
	# neighbors[2] = East (X > current)
	assert_true(
		(neighbors[2][2] as Vector3).x > pos.x,
		"East neighbor should have X > current",
	)
	# neighbors[3] = West (X < current)
	assert_true(
		(neighbors[3][2] as Vector3).x < pos.x,
		"West neighbor should have X < current",
	)


# ================================================================
# Key generation
# ================================================================


func test_make_key_same_tile() -> void:
	var span: float = _grid.get_grid_span()
	var pos := Vector3(10.0, 0.0, 10.0)
	var key: Vector3i = _graph._make_key(3, 5, pos, span)
	# tile_x=0, tile_z=0, so key = (3, 5, 0)
	assert_eq(key.x, 3)
	assert_eq(key.y, 5)


func test_make_key_different_tiles_differ() -> void:
	var span: float = _grid.get_grid_span()
	var pos_a := Vector3(10.0, 0.0, 10.0)
	var pos_b := Vector3(10.0 + span, 0.0, 10.0)
	var key_a: Vector3i = _graph._make_key(3, 5, pos_a, span)
	var key_b: Vector3i = _graph._make_key(3, 5, pos_b, span)
	assert_ne(
		key_a,
		key_b,
		"Same indices in different tiles must produce different keys",
	)


# ================================================================
# A* search radius anchored to goal_pos (core/C1)
# ================================================================


func test_search_radius_uses_goal_pos_not_start_pos() -> void:
	# C1: pruning neighbors by distance to start_pos cuts off valid paths
	# when start-to-goal > MAX_SEARCH_RADIUS/2. Must use goal_pos.
	var src: String = (_graph.get_script() as GDScript).source_code
	assert_false(
		src.contains("distance_to(start_pos) > MAX_SEARCH_RADIUS"),
		"Search radius must NOT be anchored to start_pos",
	)
	assert_true(
		src.contains("distance_to(goal_pos) > MAX_SEARCH_RADIUS"),
		"Search radius must be anchored to goal_pos",
	)
