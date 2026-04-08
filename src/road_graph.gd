extends RefCounted
## A* pathfinding over the implicit road intersection graph.
## Uses road_grid.gd for world positions -- handles infinite tiling.
##
## Usage: var _graph = preload("res://src/road_graph.gd").new()

const MAX_SEARCH_RADIUS := 500.0
const MAX_ITERATIONS := 800


## Find shortest road-path between two world positions.
## Returns Array[Vector3] of intersection waypoints (empty if no path).
func find_path(from_world: Vector3, to_world: Vector3, grid: RefCounted) -> Array[Vector3]:
	var from_ns: int = grid.get_nearest_road_index(from_world.x)
	var from_ew: int = grid.get_nearest_road_index(from_world.z)
	var to_ns: int = grid.get_nearest_road_index(to_world.x)
	var to_ew: int = grid.get_nearest_road_index(to_world.z)

	var start_pos: Vector3 = _get_intersection_pos(from_ns, from_ew, from_world, grid)
	var goal_pos: Vector3 = _get_intersection_pos(to_ns, to_ew, to_world, grid)

	if start_pos.distance_to(goal_pos) < 1.0:
		return []

	var grid_span: float = grid.get_grid_span()

	# open_list entries: [f_cost, g_cost, node_key, world_pos]
	var open_list: Array = []
	var closed_set: Dictionary = {}
	var came_from: Dictionary = {}
	var g_scores: Dictionary = {}
	var positions: Dictionary = {}

	var start_key: Vector3i = _make_key(from_ns, from_ew, start_pos, grid_span)
	var goal_key: Vector3i = _make_key(to_ns, to_ew, goal_pos, grid_span)

	var h: float = start_pos.distance_to(goal_pos)
	open_list.append([h, 0.0, start_key, start_pos])
	g_scores[start_key] = 0.0
	positions[start_key] = start_pos

	var iterations := 0
	while open_list.size() > 0 and iterations < MAX_ITERATIONS:
		iterations += 1

		var current: Array = open_list.pop_front()
		var current_g: float = current[1]
		var current_key: Vector3i = current[2]
		var current_pos: Vector3 = current[3]

		if current_key == goal_key:
			return _reconstruct_path(came_from, positions, current_key, start_key)

		if closed_set.has(current_key):
			continue
		closed_set[current_key] = true

		# Extract road indices from key
		var ns_idx: int = current_key.x % 11
		var ew_idx: int = current_key.y % 11
		if ns_idx < 0:
			ns_idx += 11
		if ew_idx < 0:
			ew_idx += 11

		var neighbors: Array = _get_neighbors(ns_idx, ew_idx, current_pos, grid)

		for neighbor in neighbors:
			var n_ns: int = neighbor[0]
			var n_ew: int = neighbor[1]
			var n_pos: Vector3 = neighbor[2]

			if n_pos.distance_to(start_pos) > MAX_SEARCH_RADIUS:
				continue

			var n_key: Vector3i = _make_key(n_ns, n_ew, n_pos, grid_span)
			if closed_set.has(n_key):
				continue

			var edge_cost: float = current_pos.distance_to(n_pos)
			var tentative_g: float = current_g + edge_cost

			var existing_g: float = g_scores.get(n_key, INF)
			if tentative_g >= existing_g:
				continue

			g_scores[n_key] = tentative_g
			came_from[n_key] = current_key
			positions[n_key] = n_pos

			var n_h: float = n_pos.distance_to(goal_pos)
			var n_f: float = tentative_g + n_h
			_insert_sorted(open_list, [n_f, tentative_g, n_key, n_pos])

	return []


func _get_intersection_pos(ns_idx: int, ew_idx: int, ref: Vector3, grid: RefCounted) -> Vector3:
	var x: float = grid.get_road_center_near(ns_idx, ref.x)
	var z: float = grid.get_road_center_near(ew_idx, ref.z)
	return Vector3(x, 0.0, z)


func _make_key(ns_idx: int, ew_idx: int, world_pos: Vector3, grid_span: float) -> Vector3i:
	var tile_x: int = int(roundf(world_pos.x / grid_span))
	var tile_z: int = int(roundf(world_pos.z / grid_span))
	return Vector3i(ns_idx + tile_x * 11, ew_idx + tile_z * 11, 0)


## Returns Array of [ns_idx, ew_idx, world_pos] for 4 orthogonal neighbors.
func _get_neighbors(
	ns_idx: int,
	ew_idx: int,
	current_pos: Vector3,
	grid: RefCounted,
) -> Array:
	var gs: int = grid.GRID_SIZE
	var span: float = grid.get_grid_span()
	var result: Array = []

	# North (Z decreasing)
	var n_ew: int = ew_idx - 1
	if n_ew < 0:
		n_ew = gs
	var n_ref := Vector3(current_pos.x, 0.0, current_pos.z - 20.0)
	var n_pos: Vector3 = _get_intersection_pos(ns_idx, n_ew, n_ref, grid)
	if n_pos.z >= current_pos.z - 1.0:
		n_ref.z -= span
		n_pos = _get_intersection_pos(ns_idx, n_ew, n_ref, grid)
	result.append([ns_idx, n_ew, n_pos])

	# South (Z increasing)
	var s_ew: int = ew_idx + 1
	if s_ew > gs:
		s_ew = 0
	var s_ref := Vector3(current_pos.x, 0.0, current_pos.z + 20.0)
	var s_pos: Vector3 = _get_intersection_pos(ns_idx, s_ew, s_ref, grid)
	if s_pos.z <= current_pos.z + 1.0:
		s_ref.z += span
		s_pos = _get_intersection_pos(ns_idx, s_ew, s_ref, grid)
	result.append([ns_idx, s_ew, s_pos])

	# East (X increasing)
	var e_ns: int = ns_idx + 1
	if e_ns > gs:
		e_ns = 0
	var e_ref := Vector3(current_pos.x + 20.0, 0.0, current_pos.z)
	var e_pos: Vector3 = _get_intersection_pos(e_ns, ew_idx, e_ref, grid)
	if e_pos.x <= current_pos.x + 1.0:
		e_ref.x += span
		e_pos = _get_intersection_pos(e_ns, ew_idx, e_ref, grid)
	result.append([e_ns, ew_idx, e_pos])

	# West (X decreasing)
	var w_ns: int = ns_idx - 1
	if w_ns < 0:
		w_ns = gs
	var w_ref := Vector3(current_pos.x - 20.0, 0.0, current_pos.z)
	var w_pos: Vector3 = _get_intersection_pos(w_ns, ew_idx, w_ref, grid)
	if w_pos.x >= current_pos.x - 1.0:
		w_ref.x -= span
		w_pos = _get_intersection_pos(w_ns, ew_idx, w_ref, grid)
	result.append([w_ns, ew_idx, w_pos])

	return result


func _reconstruct_path(
	came_from: Dictionary,
	positions: Dictionary,
	current_key: Vector3i,
	start_key: Vector3i,
) -> Array[Vector3]:
	var path: Array[Vector3] = []
	var key: Vector3i = current_key
	while key != start_key:
		var pos: Vector3 = positions[key]
		path.append(pos)
		key = came_from[key]
	path.append(positions[start_key])
	path.reverse()
	return path


## Insert entry maintaining ascending f-cost order via binary search.
func _insert_sorted(open_list: Array, entry: Array) -> void:
	var f: float = entry[0]
	var lo := 0
	var hi: int = open_list.size()
	while lo < hi:
		var mid: int = (lo + hi) / 2
		if open_list[mid][0] < f:
			lo = mid + 1
		else:
			hi = mid
	open_list.insert(lo, entry)
