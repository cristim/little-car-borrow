extends Control
## Minimap drawn via _draw() — roads, vehicles, markers, compass.
## Custom minimum size 300x300, call queue_redraw() every frame.

const MAP_SIZE := 300.0
const MAP_CENTER := 150.0
const MAP_RADIUS := 140.0
const SCALE := 0.5  # 1px = 2m, 140px radius = 280m view range
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
const TERRAIN_COLOR := Color(0.22, 0.45, 0.18, 0.5)
const WATER_COLOR := Color(0.15, 0.35, 0.65, 0.5)
const VILLAGE_COLOR := Color(0.55, 0.40, 0.25, 0.8)
const CITY_BOUNDARY_COLOR := Color(0.25, 0.25, 0.35, 0.25)
const CITY_BOUNDARY_LINE_COLOR := Color(0.6, 0.6, 0.7, 0.5)
const BOUNDARY_SEGMENTS := 72

var _grid = preload("res://src/road_grid.gd").new()
var _player: Node3D = null
var _frame_count := 0
var _boundary_polygon := PackedVector2Array()
var _boundary_cached := false


func _ready() -> void:
	custom_minimum_size = Vector2(MAP_SIZE, MAP_SIZE)


func _process(_delta: float) -> void:
	if not _player:
		_player = (
			get_tree().get_first_node_in_group("player")
			as Node3D
		)
	_frame_count += 1
	if _frame_count % 5 == 0:
		queue_redraw()


func _draw() -> void:
	if not _player:
		return

	var player_pos := _get_tracking_position()
	var yaw := _get_heading_yaw()

	# Background circle
	var center := Vector2(MAP_CENTER, MAP_CENTER)
	draw_circle(center, MAP_RADIUS, BG_COLOR)

	# City boundary outline
	_draw_city_boundary(player_pos, yaw)

	# Terrain under roads
	_draw_terrain(player_pos, yaw)

	# Roads
	_draw_roads(player_pos, yaw)

	# NPC vehicles (gray dots)
	_draw_group_dots("npc_vehicle", player_pos, yaw, NPC_COLOR, 2.0)

	# Police vehicles (red dots)
	_draw_group_dots(
		"police_vehicle", player_pos, yaw, POLICE_COLOR, 3.0
	)

	# Police helicopter (distinct icon)
	_draw_heli_icons(player_pos, yaw)

	# Mission markers (colored diamonds)
	_draw_mission_markers(player_pos, yaw)

	# Player arrow at center
	_draw_player_arrow(yaw)

	# Compass letters
	_draw_compass(yaw)

	# Border ring
	draw_arc(
		center, MAP_RADIUS, 0.0, TAU, 64,
		BORDER_COLOR, 2.0
	)


func _draw_city_boundary(ppos: Vector3, yaw: float) -> void:
	if not _boundary_cached:
		var city_node := get_tree().get_first_node_in_group(
			"city_manager"
		)
		if not city_node or not city_node.has_meta("city_boundary"):
			return
		var boundary: RefCounted = city_node.get_meta(
			"city_boundary"
		)
		_boundary_polygon = boundary.get_boundary_polygon(
			BOUNDARY_SEGMENTS
		)
		_boundary_cached = true

	if _boundary_polygon.is_empty():
		return

	# Transform world XZ polygon to minimap space
	var map_pts := PackedVector2Array()
	map_pts.resize(_boundary_polygon.size())
	for i in range(_boundary_polygon.size()):
		var wp := _boundary_polygon[i]
		map_pts[i] = _world_to_minimap(
			Vector3(wp.x, 0.0, wp.y), ppos, yaw
		)

	draw_colored_polygon(map_pts, CITY_BOUNDARY_COLOR)

	# Close the polyline by appending the first point
	var line_pts := PackedVector2Array()
	line_pts.resize(map_pts.size() + 1)
	for i in range(map_pts.size()):
		line_pts[i] = map_pts[i]
	line_pts[map_pts.size()] = map_pts[0]
	draw_polyline(line_pts, CITY_BOUNDARY_LINE_COLOR, 1.5)


func _draw_roads(ppos: Vector3, yaw: float) -> void:
	var view_range := MAP_RADIUS / SCALE
	# Draw nearby road segments as lines
	for ri in range(_grid.GRID_SIZE + 1):
		# N-S roads (along Z axis)
		var rx: float = _grid.get_road_center_near(
			ri, ppos.x
		)
		var top := _world_to_minimap(
			Vector3(rx, 0.0, ppos.z - view_range), ppos, yaw
		)
		var bot := _world_to_minimap(
			Vector3(rx, 0.0, ppos.z + view_range), ppos, yaw
		)
		_draw_clipped_line(top, bot, ROAD_COLOR, 1.5)

		# E-W roads (along X axis)
		var rz: float = _grid.get_road_center_near(
			ri, ppos.z
		)
		var left := _world_to_minimap(
			Vector3(ppos.x - view_range, 0.0, rz), ppos, yaw
		)
		var right := _world_to_minimap(
			Vector3(ppos.x + view_range, 0.0, rz), ppos, yaw
		)
		_draw_clipped_line(left, right, ROAD_COLOR, 1.5)


func _draw_terrain(ppos: Vector3, yaw: float) -> void:
	var city_node := get_tree().get_first_node_in_group(
		"city_manager"
	)
	if not city_node:
		return

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
		var world_dist: float = sqrt(
			world_dx * world_dx + world_dz * world_dz
		)
		if world_dist > MAP_RADIUS / SCALE + hs * 1.42:
			continue

		var corners: Array[Vector3] = [
			Vector3(chunk_ox - hs, 0.0, chunk_oz - hs),
			Vector3(chunk_ox + hs, 0.0, chunk_oz - hs),
			Vector3(chunk_ox + hs, 0.0, chunk_oz + hs),
			Vector3(chunk_ox - hs, 0.0, chunk_oz + hs),
		]

		var map_pts: PackedVector2Array = []
		for c in corners:
			var mp := _world_to_minimap(c, ppos, yaw)
			map_pts.append(mp)

		var has_water: bool = chunk_node.get_meta(
			"has_water", false
		)
		var base_color := TERRAIN_COLOR
		if has_water:
			base_color = WATER_COLOR
		draw_colored_polygon(map_pts, base_color)

		var has_village: bool = chunk_node.get_meta(
			"has_village", false
		)
		if has_village:
			var vc: Vector2 = chunk_node.get_meta(
				"village_center",
				Vector2(chunk_ox, chunk_oz),
			)
			var vpos := Vector3(vc.x, 0.0, vc.y)
			var vmp := _world_to_minimap(vpos, ppos, yaw)
			if _in_circle(vmp):
				draw_rect(
					Rect2(
						vmp - Vector2(3, 3),
						Vector2(6, 6),
					),
					VILLAGE_COLOR,
				)


func _draw_group_dots(
	group_name: String, ppos: Vector3, yaw: float,
	color: Color, radius: float,
) -> void:
	var nodes := get_tree().get_nodes_in_group(group_name)
	var view_sq := (MAP_RADIUS / SCALE) * (MAP_RADIUS / SCALE)
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
	var markers := get_tree().get_nodes_in_group(
		"mission_marker"
	)
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
	var helis := get_tree().get_nodes_in_group(
		"police_helicopter"
	)
	var view_sq := (MAP_RADIUS / SCALE) * (MAP_RADIUS / SCALE)
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
			HELI_COLOR, 1.5,
		)
		draw_line(
			mp + Vector2(0.0, -blade_len),
			mp + Vector2(0.0, blade_len),
			HELI_COLOR, 1.5,
		)


func _draw_player_arrow(_yaw: float) -> void:
	var center := Vector2(MAP_CENTER, MAP_CENTER)
	# Arrow points up (north) then rotated by negative yaw
	var points: PackedVector2Array = [
		Vector2(0, -8), Vector2(5, 6), Vector2(0, 3),
		Vector2(-5, 6),
	]
	# No rotation needed — arrow always points up,
	# world rotates around player
	for i in range(points.size()):
		points[i] += center
	draw_colored_polygon(points, PLAYER_COLOR)


func _draw_compass(yaw: float) -> void:
	var center := Vector2(MAP_CENTER, MAP_CENTER)
	var dirs := [
		["N", Vector2(0, -1)], ["S", Vector2(0, 1)],
		["E", Vector2(1, 0)], ["W", Vector2(-1, 0)],
	]
	for d in dirs:
		var label: String = d[0]
		var dir: Vector2 = d[1]
		# Rotate direction by yaw
		var rot_x := dir.x * cos(yaw) - dir.y * sin(yaw)
		var rot_y := dir.x * sin(yaw) + dir.y * cos(yaw)
		var pos := center + Vector2(rot_x, rot_y) * (
			MAP_RADIUS - 12.0
		)
		draw_string(
			ThemeDB.fallback_font, pos, label,
			HORIZONTAL_ALIGNMENT_CENTER, -1, 12,
			Color(0.9, 0.9, 0.9, 0.7),
		)


func _draw_diamond(
	pos: Vector2, size: float, color: Color,
) -> void:
	var pts: PackedVector2Array = [
		Vector2(pos.x, pos.y - size),
		Vector2(pos.x + size, pos.y),
		Vector2(pos.x, pos.y + size),
		Vector2(pos.x - size, pos.y),
	]
	draw_colored_polygon(pts, color)


func _draw_clipped_line(
	a: Vector2, b: Vector2, color: Color, width: float,
) -> void:
	# Only draw if at least one endpoint is in circle
	if _in_circle(a) or _in_circle(b):
		draw_line(a, b, color, width)


func _world_to_minimap(
	world_pos: Vector3, player_pos: Vector3, yaw: float,
) -> Vector2:
	var dx := world_pos.x - player_pos.x
	var dz := world_pos.z - player_pos.z
	var rx := dx * cos(yaw) - dz * sin(yaw)
	var ry := dx * sin(yaw) + dz * cos(yaw)
	return Vector2(MAP_CENTER + rx * SCALE, MAP_CENTER + ry * SCALE)


func _in_circle(p: Vector2) -> bool:
	var dx := p.x - MAP_CENTER
	var dy := p.y - MAP_CENTER
	return dx * dx + dy * dy <= MAP_RADIUS * MAP_RADIUS


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
