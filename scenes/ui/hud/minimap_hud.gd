extends Control
## Minimap drawn via _draw() — roads, vehicles, markers, compass.
## Supports zoom (+/-) and fullscreen map toggle (M).
## In fullscreen mode, arrow keys pan the view.

const MINI_SIZE := 300.0
const MINI_CENTER := 150.0
const MINI_RADIUS := 140.0
const ZOOM_LEVELS: Array[float] = [0.15, 0.25, 0.5, 0.75, 1.0]
const DEFAULT_ZOOM_IDX := 2
const BG_COLOR := Color(0.08, 0.08, 0.12, 0.85)
const BORDER_COLOR := Color(0.7, 0.7, 0.7, 0.8)
const ROAD_COLOR := Color(0.35, 0.35, 0.4, 0.7)
const PLAYER_COLOR := Color(0.2, 0.9, 0.3)
const NPC_COLOR := Color(0.5, 0.5, 0.5)
const POLICE_COLOR := Color(1.0, 0.2, 0.2)
const MARKER_START_COLOR := Color(0.2, 0.9, 0.2)
const MARKER_PICKUP_COLOR := Color(0.3, 0.5, 1.0)
const MARKER_DROPOFF_COLOR := Color(1.0, 0.9, 0.2)
const HELI_COLOR := Color(1.0, 0.3, 0.3)
const HELIPAD_COLOR := Color(0.2, 0.85, 0.95)
const TERRAIN_COLOR := Color(0.22, 0.45, 0.18, 0.5)
const WATER_COLOR := Color(0.15, 0.35, 0.65, 0.5)
const VILLAGE_COLOR := Color(0.55, 0.40, 0.25, 0.8)
const SUBURB_COLOR := Color(0.35, 0.45, 0.30, 0.5)
const FARMLAND_COLOR := Color(0.55, 0.50, 0.25, 0.5)
const MOUNTAIN_COLOR := Color(0.50, 0.48, 0.44, 0.5)
const FOREST_COLOR := Color(0.12, 0.38, 0.10, 0.5)
const OCEAN_COLOR := Color(0.10, 0.25, 0.55, 0.6)
const CITY_BOUNDARY_COLOR := Color(0.25, 0.25, 0.35, 0.25)
const CITY_BOUNDARY_LINE_COLOR := Color(0.6, 0.6, 0.7, 0.5)
const BUILDING_COLOR := Color(0.45, 0.42, 0.48, 0.6)
const BUILDING_TALL_COLOR := Color(0.55, 0.50, 0.58, 0.7)
const RIVER_COLOR := Color(0.2, 0.45, 0.8, 0.7)
const RURAL_ROAD_COLOR := Color(0.4, 0.38, 0.35, 0.6)
const RAMP_PARK_COLOR := Color(1.0, 0.6, 0.1, 0.9)
const BOUNDARY_SEGMENTS := 72
const TERRAIN_SUBCELLS := 8
const SEA_LEVEL := -2.0
const HIGHWAY_INDICES := [0, 5]

var _grid = preload("res://src/road_grid.gd").new()
var _river_map: RefCounted = null
var _biome_map_ref: RefCounted = null
var _player: Node3D = null
var _frame_count := 0
var _boundary_polygon := PackedVector2Array()
var _boundary_cached := false
var _boundary: RefCounted = null
var _clip_circle := PackedVector2Array()
var _city_node: Node = null  # cached city_manager reference

# Dynamic map state
var _zoom_idx: int = DEFAULT_ZOOM_IDX
var _scale: float = 0.5
var _fullscreen := false
var _map_size: float = MINI_SIZE
var _map_center: float = MINI_CENTER
var _map_radius: float = MINI_RADIUS
var _pan_offset := Vector3.ZERO  # world-space pan in fullscreen


func _ready() -> void:
	custom_minimum_size = Vector2(MINI_SIZE, MINI_SIZE)
	_scale = ZOOM_LEVELS[_zoom_idx]
	resized.connect(_rebuild_clip_circle)
	# Do NOT call _rebuild_clip_circle here — size is (0, 0) at _ready time


func _rebuild_clip_circle() -> void:
	if _fullscreen:
		# Use rectangular clip for fullscreen
		_clip_circle = PackedVector2Array(
			[
				Vector2(0, 0),
				Vector2(size.x, 0),
				Vector2(size.x, size.y),
				Vector2(0, size.y),
			]
		)
		return
	var center := Vector2(_map_center, _map_center)
	_clip_circle.resize(64)
	for i in range(64):
		var angle: float = float(i) * TAU / 64.0
		_clip_circle[i] = center + Vector2(cos(angle), sin(angle)) * _map_radius


func _process(delta: float) -> void:
	if not _player:
		_player = (get_tree().get_first_node_in_group("player") as Node3D)
	# Fullscreen pan with arrow keys
	if _fullscreen:
		var pan_speed: float = 200.0 / _scale
		if Input.is_action_pressed("move_forward"):
			_pan_offset.z -= pan_speed * delta
		if Input.is_action_pressed("move_backward"):
			_pan_offset.z += pan_speed * delta
		if Input.is_action_pressed("move_left"):
			_pan_offset.x -= pan_speed * delta
		if Input.is_action_pressed("move_right"):
			_pan_offset.x += pan_speed * delta
	_frame_count += 1
	if _frame_count % 5 == 0:
		queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("map_toggle"):
		_toggle_fullscreen()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("map_zoom_in"):
		_change_zoom(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("map_zoom_out"):
		_change_zoom(-1)
		get_viewport().set_input_as_handled()


func _change_zoom(direction: int) -> void:
	_zoom_idx = clampi(_zoom_idx + direction, 0, ZOOM_LEVELS.size() - 1)
	_scale = ZOOM_LEVELS[_zoom_idx]
	_rebuild_clip_circle()


func _toggle_fullscreen() -> void:
	_fullscreen = not _fullscreen
	if _fullscreen:
		var vp_size := get_viewport_rect().size
		_map_size = minf(vp_size.x, vp_size.y)
		_map_center = _map_size * 0.5
		_map_radius = _map_center - 10.0
		custom_minimum_size = vp_size
		size = vp_size
		anchor_left = 0.0
		anchor_top = 0.0
		anchor_right = 1.0
		anchor_bottom = 1.0
		_pan_offset = Vector3.ZERO
	else:
		_map_size = MINI_SIZE
		_map_center = MINI_CENTER
		_map_radius = MINI_RADIUS
		custom_minimum_size = Vector2(MINI_SIZE, MINI_SIZE)
		size = Vector2(MINI_SIZE, MINI_SIZE)
		anchor_left = 1.0
		anchor_top = 0.0
		anchor_right = 1.0
		anchor_bottom = 0.0
		_pan_offset = Vector3.ZERO
	_rebuild_clip_circle()


func _draw() -> void:
	if _clip_circle.is_empty():
		_rebuild_clip_circle()
	if not _player:
		return

	var player_pos := _get_tracking_position() + _pan_offset
	var yaw: float = 0.0 if _fullscreen else _get_heading_yaw()

	# Background
	var center := Vector2(_map_center, _map_center)
	if _fullscreen:
		draw_rect(Rect2(Vector2.ZERO, size), BG_COLOR)
	else:
		draw_circle(center, _map_radius, BG_COLOR)

	# City boundary outline
	_draw_city_boundary(player_pos, yaw)

	# Terrain under roads
	_draw_terrain(player_pos, yaw)

	# City building blocks
	_draw_city_blocks(player_pos, yaw)

	# Rivers on terrain
	_draw_rivers(player_pos, yaw)

	# Rural roads on terrain
	_draw_rural_roads(player_pos, yaw)

	# Roads
	_draw_roads(player_pos, yaw)

	# NPC vehicles (gray dots)
	_draw_group_dots("npc_vehicle", player_pos, yaw, NPC_COLOR, 2.0)

	# Police vehicles (red dots)
	_draw_group_dots("police_vehicle", player_pos, yaw, POLICE_COLOR, 3.0)

	# Police helicopter (distinct icon)
	_draw_heli_icons(player_pos, yaw)

	# Helipads ("H" icon)
	_draw_helipad_icons(player_pos, yaw)

	# Mission markers (colored diamonds)
	_draw_mission_markers(player_pos, yaw)

	# Player arrow at center
	_draw_player_arrow(yaw)

	# Compass letters
	_draw_compass(yaw)

	# Border
	if _fullscreen:
		draw_rect(Rect2(Vector2.ZERO, size), BORDER_COLOR, false, 2.0)
		# Zoom level indicator
		var zoom_text := "Zoom: %dx  [+/-] zoom  [M] close" % (_zoom_idx + 1)
		draw_string(
			ThemeDB.fallback_font,
			Vector2(10, size.y - 10),
			zoom_text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			14,
			Color(0.8, 0.8, 0.8, 0.7),
		)
	else:
		draw_arc(center, _map_radius, 0.0, TAU, 64, BORDER_COLOR, 2.0)


func _draw_city_boundary(ppos: Vector3, yaw: float) -> void:
	if not _boundary_cached:
		var city_node := get_tree().get_first_node_in_group("city_manager")
		if not city_node or not city_node.has_meta("city_boundary"):
			return
		_boundary = city_node.get_meta("city_boundary")
		_boundary_polygon = _boundary.get_boundary_polygon(BOUNDARY_SEGMENTS)
		if city_node.has_meta("river_map"):
			_river_map = city_node.get_meta("river_map")
		if city_node.has_meta("biome_map"):
			_biome_map_ref = city_node.get_meta("biome_map")
		_boundary_cached = true

	if _boundary_polygon.is_empty():
		return

	# Transform world XZ polygon to minimap space
	var map_pts := PackedVector2Array()
	map_pts.resize(_boundary_polygon.size())
	for i in range(_boundary_polygon.size()):
		var wp := _boundary_polygon[i]
		map_pts[i] = _world_to_minimap(Vector3(wp.x, 0.0, wp.y), ppos, yaw)

	# Clip polygon to minimap circle
	var clipped: Array[PackedVector2Array] = Geometry2D.intersect_polygons(map_pts, _clip_circle)
	for poly in clipped:
		draw_colored_polygon(poly, CITY_BOUNDARY_COLOR)
		# Close the polyline by appending the first point
		poly.append(poly[0])
		draw_polyline(poly, CITY_BOUNDARY_LINE_COLOR, 1.5)


func _draw_roads(ppos: Vector3, yaw: float) -> void:
	var view_range := _map_radius / _scale
	# Draw nearby road segments as lines
	for ri in range(_grid.GRID_SIZE + 1):
		var is_highway: bool = ri in HIGHWAY_INDICES
		var width := 2.0 if is_highway else 1.5

		# N-S roads (along Z axis)
		var rx: float = _grid.get_road_center_near(ri, ppos.x)
		var draw_ns := true
		if not is_highway and _boundary:
			draw_ns = _boundary.get_signed_distance(rx, ppos.z) < 0.0
		if draw_ns:
			var top := _world_to_minimap(Vector3(rx, 0.0, ppos.z - view_range), ppos, yaw)
			var bot := _world_to_minimap(Vector3(rx, 0.0, ppos.z + view_range), ppos, yaw)
			_draw_clipped_line(top, bot, ROAD_COLOR, width)

		# E-W roads (along X axis)
		var rz: float = _grid.get_road_center_near(ri, ppos.z)
		var draw_ew := true
		if not is_highway and _boundary:
			draw_ew = _boundary.get_signed_distance(ppos.x, rz) < 0.0
		if draw_ew:
			var left := _world_to_minimap(Vector3(ppos.x - view_range, 0.0, rz), ppos, yaw)
			var right := _world_to_minimap(Vector3(ppos.x + view_range, 0.0, rz), ppos, yaw)
			_draw_clipped_line(left, right, ROAD_COLOR, width)


func _draw_terrain(ppos: Vector3, yaw: float) -> void:
	if not _city_node or not is_instance_valid(_city_node):
		_city_node = get_tree().get_first_node_in_group("city_manager")
	if not _city_node:
		return
	var city_node: Node = _city_node

	var grid_span: float = _grid.get_grid_span()

	for child in city_node.get_children():
		if not child is Node3D:
			continue
		if not child.has_meta("chunk_type"):
			continue
		if child.get_meta("chunk_type") != "terrain":
			continue

		var chunk_node: Node3D = child as Node3D
		var tile: Vector2i = chunk_node.get_meta("tile")
		var origin: Vector2 = _grid.get_chunk_origin(tile)
		var chunk_ox: float = origin.x
		var chunk_oz: float = origin.y
		var hs := grid_span * 0.5

		# Quick distance cull: skip chunks too far to overlap minimap
		var world_dx: float = chunk_ox - ppos.x
		var world_dz: float = chunk_oz - ppos.z
		var world_dist: float = sqrt(world_dx * world_dx + world_dz * world_dz)
		if world_dist > _map_radius / _scale + hs * 1.42:
			continue

		if _boundary:
			# Height-based sub-cell coloring
			var sub_size: float = grid_span / TERRAIN_SUBCELLS
			for sy in range(TERRAIN_SUBCELLS):
				for sx in range(TERRAIN_SUBCELLS):
					var x0: float = chunk_ox - hs + sx * sub_size
					var z0: float = chunk_oz - hs + sy * sub_size
					var x1: float = x0 + sub_size
					var z1: float = z0 + sub_size
					var cx: float = (x0 + x1) * 0.5
					var cz: float = (z0 + z1) * 0.5
					var h: float = _boundary.get_ground_height(cx, cz)
					var col := _height_to_minimap_color(h)

					var quad: PackedVector2Array = [
						_world_to_minimap(Vector3(x0, 0.0, z0), ppos, yaw),
						_world_to_minimap(Vector3(x1, 0.0, z0), ppos, yaw),
						_world_to_minimap(Vector3(x1, 0.0, z1), ppos, yaw),
						_world_to_minimap(Vector3(x0, 0.0, z1), ppos, yaw),
					]
					var clipped: Array[PackedVector2Array] = Geometry2D.intersect_polygons(
						quad, _clip_circle
					)
					for poly in clipped:
						draw_colored_polygon(poly, col)
		else:
			# Fallback: flat color per chunk, biome-aware
			var corners: Array[Vector3] = [
				Vector3(chunk_ox - hs, 0.0, chunk_oz - hs),
				Vector3(chunk_ox + hs, 0.0, chunk_oz - hs),
				Vector3(chunk_ox + hs, 0.0, chunk_oz + hs),
				Vector3(chunk_ox - hs, 0.0, chunk_oz + hs),
			]
			var map_pts: PackedVector2Array = []
			for c in corners:
				map_pts.append(_world_to_minimap(c, ppos, yaw))
			var base_color := _biome_to_color(
				chunk_node.get_meta("biome", ""),
				chunk_node.get_meta("has_water", false),
			)
			var clipped: Array[PackedVector2Array] = Geometry2D.intersect_polygons(
				map_pts, _clip_circle
			)
			for poly in clipped:
				draw_colored_polygon(poly, base_color)

		var has_village: bool = chunk_node.get_meta("has_village", false)
		if has_village:
			var vc: Vector2 = (
				chunk_node
				. get_meta(
					"village_center",
					Vector2(chunk_ox, chunk_oz),
				)
			)
			var vpos := Vector3(vc.x, 0.0, vc.y)
			var vmp := _world_to_minimap(vpos, ppos, yaw)
			if _in_circle(vmp):
				draw_rect(
					Rect2(
						vmp - Vector2(4, 4),
						Vector2(8, 8),
					),
					VILLAGE_COLOR,
				)

	# Stunt parks can be on any chunk type (suburb = city)
	for child in city_node.get_children():
		if not child is Node3D:
			continue
		if not child.get_meta("has_stunt_park", false):
			continue
		var sc: Vector2 = (
			child
			. get_meta(
				"stunt_park_center",
				Vector2.ZERO,
			)
		)
		var spos := Vector3(sc.x, 0.0, sc.y)
		var smp := _world_to_minimap(spos, ppos, yaw)
		if _in_circle(smp):
			_draw_diamond(smp, 5.0, RAMP_PARK_COLOR)


func _draw_city_blocks(ppos: Vector3, yaw: float) -> void:
	if not _boundary:
		return
	var view_range := _map_radius / _scale

	# Draw filled blocks between road grid lines inside the city
	for rx_i in range(_grid.GRID_SIZE):
		var rx0: float = _grid.get_road_center_near(rx_i, ppos.x)
		var rx1: float = _grid.get_road_center_near(rx_i + 1, ppos.x)
		var rwx0: float = _grid.get_road_width(rx_i) * 0.5
		var rwx1: float = _grid.get_road_width(rx_i + 1) * 0.5
		var bx0: float = rx0 + rwx0
		var bx1: float = rx1 - rwx1
		var mid_x: float = (bx0 + bx1) * 0.5
		if absf(mid_x - ppos.x) > view_range + 50.0:
			continue
		for rz_i in range(_grid.GRID_SIZE):
			var rz0: float = _grid.get_road_center_near(rz_i, ppos.z)
			var rz1: float = _grid.get_road_center_near(rz_i + 1, ppos.z)
			var rwz0: float = _grid.get_road_width(rz_i) * 0.5
			var rwz1: float = _grid.get_road_width(rz_i + 1) * 0.5
			var bz0: float = rz0 + rwz0
			var bz1: float = rz1 - rwz1
			var mid_z: float = (bz0 + bz1) * 0.5
			if absf(mid_z - ppos.z) > view_range + 50.0:
				continue
			# Only inside city boundary
			if _boundary.get_signed_distance(mid_x, mid_z) > 0:
				continue
			var quad: PackedVector2Array = [
				_world_to_minimap(Vector3(bx0, 0.0, bz0), ppos, yaw),
				_world_to_minimap(Vector3(bx1, 0.0, bz0), ppos, yaw),
				_world_to_minimap(Vector3(bx1, 0.0, bz1), ppos, yaw),
				_world_to_minimap(Vector3(bx0, 0.0, bz1), ppos, yaw),
			]
			var clipped: Array[PackedVector2Array] = Geometry2D.intersect_polygons(
				quad, _clip_circle
			)
			for poly in clipped:
				draw_colored_polygon(poly, BUILDING_COLOR)


func _draw_rivers(ppos: Vector3, yaw: float) -> void:
	if not _river_map:
		return
	var grid_span: float = _grid.get_grid_span()
	var view_range := _map_radius / _scale
	var center_tile := _grid.get_chunk_coord(Vector2(ppos.x, ppos.z))
	var scan := int(ceilf(view_range / grid_span)) + 1
	for dy in range(-scan, scan + 1):
		for dx in range(-scan, scan + 1):
			var tile := Vector2i(center_tile.x + dx, center_tile.y + dy)
			var rd: Dictionary = _river_map.get_river_at(tile)
			if rd.is_empty():
				continue
			var origin: Vector2 = _grid.get_chunk_origin(tile)
			var hs: float = grid_span * 0.5
			var entry := _river_edge_pt(
				origin.x,
				origin.y,
				hs,
				rd.get("entry_dir", 0),
				rd.get("position", 0.5),
			)
			var exit_pt := _river_edge_pt(
				origin.x,
				origin.y,
				hs,
				rd.get("exit_dir", 2),
				rd.get("position", 0.5),
			)
			var width: float = rd.get("width", 6.0) * _scale
			width = maxf(width, 2.0)
			var mp_a := _world_to_minimap(entry, ppos, yaw)
			var mp_b := _world_to_minimap(exit_pt, ppos, yaw)
			if _in_circle(mp_a) or _in_circle(mp_b):
				draw_line(mp_a, mp_b, RIVER_COLOR, width)


func _draw_rural_roads(ppos: Vector3, yaw: float) -> void:
	if not _boundary:
		return
	var view_range := _map_radius / _scale
	var grid_span: float = _grid.get_grid_span()
	for hi in HIGHWAY_INDICES:
		# N-S rural roads
		var rx: float = _grid.get_road_center_near(hi, ppos.x)
		if _boundary.get_signed_distance(rx, ppos.z) > 0.0:
			var h: float = _boundary.get_ground_height(rx, ppos.z)
			if h >= SEA_LEVEL:
				var top := _world_to_minimap(
					Vector3(rx, 0.0, ppos.z - view_range),
					ppos,
					yaw,
				)
				var bot := _world_to_minimap(
					Vector3(rx, 0.0, ppos.z + view_range),
					ppos,
					yaw,
				)
				_draw_clipped_line(top, bot, RURAL_ROAD_COLOR, 1.5)
		# E-W rural roads
		var rz: float = _grid.get_road_center_near(hi, ppos.z)
		if _boundary.get_signed_distance(ppos.x, rz) > 0.0:
			var h: float = _boundary.get_ground_height(ppos.x, rz)
			if h >= SEA_LEVEL:
				var left := _world_to_minimap(
					Vector3(ppos.x - view_range, 0.0, rz),
					ppos,
					yaw,
				)
				var right := _world_to_minimap(
					Vector3(ppos.x + view_range, 0.0, rz),
					ppos,
					yaw,
				)
				_draw_clipped_line(left, right, RURAL_ROAD_COLOR, 1.5)


func _river_edge_pt(
	ox: float,
	oz: float,
	hs: float,
	dir: int,
	pos: float,
) -> Vector3:
	var offset: float = (pos - 0.5) * hs * 2.0
	match dir:
		0:
			return Vector3(ox + offset, 0.0, oz - hs)
		1:
			return Vector3(ox + hs, 0.0, oz + offset)
		2:
			return Vector3(ox + offset, 0.0, oz + hs)
		3:
			return Vector3(ox - hs, 0.0, oz + offset)
	return Vector3(ox, 0.0, oz)


func _draw_group_dots(
	group_name: String,
	ppos: Vector3,
	yaw: float,
	color: Color,
	radius: float,
) -> void:
	var nodes := get_tree().get_nodes_in_group(group_name)
	var view_sq := (_map_radius / _scale) * (_map_radius / _scale)
	for node in nodes:
		if not is_instance_valid(node):
			continue
		var npos: Vector3 = (node as Node3D).global_position
		var dx := npos.x - ppos.x
		var dz := npos.z - ppos.z
		if dx * dx + dz * dz > view_sq:
			continue
		var mp := _world_to_minimap(npos, ppos, yaw)
		if _in_circle(mp):
			draw_circle(mp, radius, color)


func _draw_mission_markers(ppos: Vector3, yaw: float) -> void:
	var markers := get_tree().get_nodes_in_group("mission_marker")
	for marker in markers:
		if not is_instance_valid(marker):
			continue
		var mpos: Vector3 = (marker as Node3D).global_position
		var mp := _world_to_minimap(mpos, ppos, yaw)
		if not _in_circle(mp):
			continue
		var mtype: String = marker.get("marker_type")
		var color := MARKER_START_COLOR
		if mtype == "pickup":
			color = MARKER_PICKUP_COLOR
		elif mtype == "dropoff":
			color = MARKER_DROPOFF_COLOR
		_draw_diamond(mp, 5.0, color)


func _draw_heli_icons(ppos: Vector3, yaw: float) -> void:
	var helis := get_tree().get_nodes_in_group("police_helicopter")
	var view_sq := (_map_radius / _scale) * (_map_radius / _scale)
	for heli in helis:
		if not is_instance_valid(heli):
			continue
		var hpos: Vector3 = (heli as Node3D).global_position
		var dx := hpos.x - ppos.x
		var dz := hpos.z - ppos.z
		if dx * dx + dz * dz > view_sq:
			continue
		var mp := _world_to_minimap(hpos, ppos, yaw)
		if not _in_circle(mp):
			continue
		# Circle with two crossed lines (rotor blades)
		draw_circle(mp, 4.0, HELI_COLOR)
		var blade_len := 6.0
		draw_line(
			mp + Vector2(-blade_len, 0.0),
			mp + Vector2(blade_len, 0.0),
			HELI_COLOR,
			1.5,
		)
		draw_line(
			mp + Vector2(0.0, -blade_len),
			mp + Vector2(0.0, blade_len),
			HELI_COLOR,
			1.5,
		)


func _draw_helipad_icons(ppos: Vector3, yaw: float) -> void:
	var pads := get_tree().get_nodes_in_group("helipad")
	var view_sq := (_map_radius / _scale) * (_map_radius / _scale)
	for pad in pads:
		if not is_instance_valid(pad):
			continue
		var hpos: Vector3 = (pad as Node3D).get_meta(
			"helipad_center", (pad as Node3D).global_position
		)
		var dx := hpos.x - ppos.x
		var dz := hpos.z - ppos.z
		if dx * dx + dz * dz > view_sq:
			continue
		var mp := _world_to_minimap(hpos, ppos, yaw)
		if not _in_circle(mp):
			continue
		# Background circle so "H" is readable over terrain
		draw_circle(mp, 7.0, Color(0.0, 0.0, 0.0, 0.55))
		draw_string(
			ThemeDB.fallback_font,
			mp - Vector2(4.5, 5.0),
			"H",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			11,
			HELIPAD_COLOR,
		)


func _draw_player_arrow(_yaw: float) -> void:
	var center := Vector2(_map_center, _map_center)
	# Arrow points up (north) then rotated by negative yaw
	var points: PackedVector2Array = [
		Vector2(0, -8),
		Vector2(5, 6),
		Vector2(0, 3),
		Vector2(-5, 6),
	]
	# No rotation needed — arrow always points up,
	# world rotates around player
	for i in range(points.size()):
		points[i] += center
	draw_colored_polygon(points, PLAYER_COLOR)


func _draw_compass(yaw: float) -> void:
	var center := Vector2(_map_center, _map_center)
	var dirs := [
		["N", Vector2(0, -1)],
		["S", Vector2(0, 1)],
		["E", Vector2(1, 0)],
		["W", Vector2(-1, 0)],
	]
	for d in dirs:
		var label: String = d[0]
		var dir: Vector2 = d[1]
		# Rotate direction by yaw
		var rot_x := dir.x * cos(yaw) - dir.y * sin(yaw)
		var rot_y := dir.x * sin(yaw) + dir.y * cos(yaw)
		var pos := center + Vector2(rot_x, rot_y) * (_map_radius - 12.0)
		draw_string(
			ThemeDB.fallback_font,
			pos,
			label,
			HORIZONTAL_ALIGNMENT_CENTER,
			-1,
			12,
			Color(0.9, 0.9, 0.9, 0.7),
		)


func _draw_diamond(
	pos: Vector2,
	size: float,
	color: Color,
) -> void:
	var pts: PackedVector2Array = [
		Vector2(pos.x, pos.y - size),
		Vector2(pos.x + size, pos.y),
		Vector2(pos.x, pos.y + size),
		Vector2(pos.x - size, pos.y),
	]
	draw_colored_polygon(pts, color)


func _height_to_minimap_color(h: float) -> Color:
	var col: Color
	if h < SEA_LEVEL:
		col = Color(0.15, 0.35, 0.65)
	elif h < 0.0:
		var t := clampf((h - SEA_LEVEL) / -SEA_LEVEL, 0.0, 1.0)
		col = Color(0.76, 0.70, 0.50).lerp(Color(0.22, 0.45, 0.18), t)
	elif h < 30.0:
		var t := clampf(h / 30.0, 0.0, 1.0)  # grass→rock over full 0..30 range
		col = Color(0.22, 0.45, 0.18).lerp(Color(0.45, 0.42, 0.38), t)
	elif h < 50.0:
		var t := clampf((h - 30.0) / 20.0, 0.0, 1.0)  # rock→snow over 30..50
		col = Color(0.45, 0.42, 0.38).lerp(Color(0.90, 0.90, 0.92), t)
	else:
		col = Color(0.90, 0.90, 0.92)
	col.a = 0.5
	return col


func _draw_clipped_line(
	a: Vector2,
	b: Vector2,
	color: Color,
	width: float,
) -> void:
	# Only draw if at least one endpoint is in circle
	if _in_circle(a) or _in_circle(b):
		draw_line(a, b, color, width)


func _world_to_minimap(
	world_pos: Vector3,
	player_pos: Vector3,
	yaw: float,
) -> Vector2:
	var dx := world_pos.x - player_pos.x
	var dz := world_pos.z - player_pos.z
	var rx := dx * cos(yaw) - dz * sin(yaw)
	var ry := dx * sin(yaw) + dz * cos(yaw)
	return Vector2(_map_center + rx * _scale, _map_center + ry * _scale)


func _in_circle(p: Vector2) -> bool:
	if _fullscreen:
		return p.x >= 0 and p.x <= size.x and p.y >= 0 and p.y <= size.y
	var dx := p.x - _map_center
	var dy := p.y - _map_center
	return dx * dx + dy * dy <= _map_radius * _map_radius


func _get_tracking_position() -> Vector3:
	var vehicle = _player.get("current_vehicle")
	if vehicle and vehicle is Node3D:
		return (vehicle as Node3D).global_position
	return _player.global_position


func _get_heading_yaw() -> float:
	var vehicle = _player.get("current_vehicle")
	if vehicle and vehicle is Node3D:
		var bz: Vector3 = (vehicle as Node3D).global_transform.basis.z
		return atan2(bz.x, bz.z)
	var cam := get_viewport().get_camera_3d()
	if cam:
		return cam.global_rotation.y
	return 0.0


func _biome_to_color(biome: String, has_water: bool) -> Color:
	var colors: Dictionary = {
		"forest": FOREST_COLOR,
		"mountain": MOUNTAIN_COLOR,
		"farmland": FARMLAND_COLOR,
		"village": VILLAGE_COLOR,
		"ocean": OCEAN_COLOR,
		"suburb": SUBURB_COLOR,
	}
	if colors.has(biome):
		return colors[biome]
	if has_water:
		return WATER_COLOR
	return TERRAIN_COLOR
