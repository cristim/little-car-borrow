extends RefCounted
## Builds merged building meshes grouped by material palette index.
## Up to 12 MeshInstance3D + 1 compound StaticBody3D per chunk.

const DOOR_WIDTH := 1.2
const DOOR_HEIGHT := 2.2
const INTERIOR_HEIGHT := 3.0
const INTERIOR_FLOOR_Y := 0.05
const INTERIOR_INSET := 0.15
const WALL_THICKNESS := 0.25
const PITCHED_ROOF_THRESHOLD := 8.0  # buildings under this height get pitched roofs

var _grid: RefCounted
var _building_mats: Array[StandardMaterial3D] = []
var _window_mats: Array[StandardMaterial3D] = []
var _interior_mat: StandardMaterial3D
var _roof_mats: Array[StandardMaterial3D] = []
var _city_script: GDScript = preload("res://scenes/world/city.gd")
var _door_script: GDScript = preload("res://scenes/world/building_door.gd")


func init(
	grid: RefCounted,
	building_mats: Array[StandardMaterial3D],
	window_mats: Array[StandardMaterial3D],
	interior_mat: StandardMaterial3D,
	roof_mats: Array[StandardMaterial3D] = [],
) -> void:
	_grid = grid
	_building_mats = building_mats
	_window_mats = window_mats
	_interior_mat = interior_mat
	_roof_mats = roof_mats


func build(chunk: Node3D, tile: Vector2i, ox: float, oz: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(tile)

	var mat_count := _building_mats.size()
	# One SurfaceTool per palette color
	var sts: Array[SurfaceTool] = []
	var st_used: Array[bool] = []
	for _i in range(mat_count):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		sts.append(st)
		st_used.append(false)

	# One SurfaceTool per window material group
	var win_count := _window_mats.size()
	var win_sts: Array[SurfaceTool] = []
	var win_st_has_data: Array[bool] = []
	for _i in range(win_count):
		win_sts.append(SurfaceTool.new())
		win_st_has_data.append(false)

	# Per-chunk window materials — fresh copies of the template so each chunk
	# toggles independently from every other chunk in the city.
	var local_win_mats: Array[StandardMaterial3D] = []
	for i in win_count:
		var m := StandardMaterial3D.new()
		m.albedo_color = _window_mats[i].albedo_color
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		local_win_mats.append(m)

	# Single compound collision body for all buildings
	var body := StaticBody3D.new()
	body.name = "Buildings"
	body.collision_layer = 2
	body.collision_mask = 0
	body.add_to_group("Static")

	# Roof SurfaceTool (one per roof material)
	var roof_count := _roof_mats.size()
	var roof_sts: Array[SurfaceTool] = []
	var roof_st_used: Array[bool] = []
	for _i in range(roof_count):
		var rst := SurfaceTool.new()
		rst.begin(Mesh.PRIMITIVE_TRIANGLES)
		roof_sts.append(rst)
		roof_st_used.append(false)

	# Interior SurfaceTool (single material for all interiors)
	var int_st := SurfaceTool.new()
	int_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var has_interiors := false

	# Deferred door spawns: [center, size, door_face] — added after body
	var door_infos: Array[Array] = []

	for bx in range(_grid.GRID_SIZE):
		for bz in range(_grid.GRID_SIZE):
			var block_center := _get_block_center_local(bx, bz)
			var count := rng.randi_range(1, 4)

			# Collect building data for this block
			var block_buildings: Array[Dictionary] = []
			for _b in range(count):
				var bw := rng.randf_range(6.0, 22.0)
				var bd := rng.randf_range(6.0, 22.0)
				var bh: float
				if rng.randf() < 0.15:
					bh = rng.randf_range(25.0, 45.0)
				elif rng.randf() < 0.3:
					bh = rng.randf_range(3.0, 6.0)
				else:
					bh = rng.randf_range(7.0, 20.0)
				var margin := 2.0
				var block_size: float = _grid.BLOCK_SIZE
				var max_off_x := maxf(
					(block_size - bw) * 0.5 - margin, 0.0,
				)
				var max_off_z := maxf(
					(block_size - bd) * 0.5 - margin, 0.0,
				)
				var bx_off := rng.randf_range(-max_off_x, max_off_x)
				var bz_off := rng.randf_range(-max_off_z, max_off_z)
				var mat_idx := rng.randi() % mat_count
				var center := Vector3(
					block_center.x + bx_off + ox,
					bh * 0.5 - 0.01,
					block_center.y + bz_off + oz,
				)
				# Extend 2 cm underground so building walls never visually gap
				# from the block-ground surface.
				var size := Vector3(bw, bh + 0.02, bd)
				block_buildings.append({
					"center": center,
					"size": size,
					"mat_idx": mat_idx,
				})

			# Pick first eligible building for a door
			var door_bldg_idx := -1
			for i in range(block_buildings.size()):
				var b: Dictionary = block_buildings[i]
				var s: Vector3 = b["size"]
				if s.y > 6.0 and minf(s.x, s.z) >= 3.0:
					door_bldg_idx = i
					break

			# Emit geometry for each building
			for i in range(block_buildings.size()):
				var b: Dictionary = block_buildings[i]
				var c: Vector3 = b["center"]
				var s: Vector3 = b["size"]
				var mi: int = b["mat_idx"]

				if i == door_bldg_idx:
					var door_face := rng.randi_range(0, 3)
					var face_w: float = (
						s.x if door_face <= 1 else s.z
					)
					if face_w >= DOOR_WIDTH + 0.5:
						has_interiors = true
						_add_building_with_door(
							sts[mi], int_st, c, s, door_face,
						)
						_add_building_collision_with_door(
							body, c, s, door_face,
						)
						door_infos.append([c, s, door_face])
					else:
						_city_script.st_add_box_no_bottom(
							sts[mi], c, s,
						)
						_city_script.add_box_collision(body, c, s)
				else:
					_city_script.st_add_box_no_bottom(
						sts[mi], c, s,
					)
					_city_script.add_box_collision(body, c, s)
				st_used[mi] = true

				# Add windows on buildings taller than 6m.
				# Each window quad gets an independently chosen material group
				# so individual windows on the same wall can toggle on/off
				# at different times throughout the night.
				if s.y > 6.0:
					var hx := s.x * 0.5
					var hz := s.z * 0.5
					var win_faces: Array[Array] = [
						[c + Vector3(0, 0, -hz), s.x,
							Vector3(0, 0, -1), Vector3(1, 0, 0)],
						[c + Vector3(0, 0, hz), s.x,
							Vector3(0, 0, 1), Vector3(-1, 0, 0)],
						[c + Vector3(-hx, 0, 0), s.z,
							Vector3(-1, 0, 0), Vector3(0, 0, -1)],
						[c + Vector3(hx, 0, 0), s.z,
							Vector3(1, 0, 0), Vector3(0, 0, 1)],
					]
					for wf: Array in win_faces:
						_city_script.st_add_windows_on_face_indep(
							win_sts, win_count, win_st_has_data,
							wf[0] as Vector3, wf[1] as float,
							s.y,
							wf[2] as Vector3, wf[3] as Vector3,
							rng,
						)

				# Add pitched roof to short buildings
				if (
					s.y < PITCHED_ROOF_THRESHOLD
					and roof_count > 0
				):
					var ri := rng.randi() % roof_count
					_st_add_pitched_roof(
						roof_sts[ri], c, s, rng,
					)
					roof_st_used[ri] = true

	# Create one MeshInstance3D per used palette color
	for i in range(mat_count):
		if not st_used[i]:
			continue
		sts[i].generate_normals()
		var mesh := sts[i].commit()
		var mesh_inst := MeshInstance3D.new()
		mesh_inst.name = "BuildingsMat_%d" % i
		mesh_inst.mesh = mesh
		mesh_inst.material_override = _building_mats[i]
		body.add_child(mesh_inst)

	# One MeshInstance3D per used window material group
	for i in range(win_count):
		if not win_st_has_data[i]:
			continue
		win_sts[i].generate_normals()
		var win_mesh := win_sts[i].commit()
		var win_inst := MeshInstance3D.new()
		win_inst.name = "Windows_%d" % i
		win_inst.mesh = win_mesh
		win_inst.material_override = local_win_mats[i]
		body.add_child(win_inst)

	# Roof meshes
	for i in range(roof_count):
		if not roof_st_used[i]:
			continue
		roof_sts[i].generate_normals()
		var roof_mesh := roof_sts[i].commit()
		var roof_inst := MeshInstance3D.new()
		roof_inst.name = "Roofs_%d" % i
		roof_inst.mesh = roof_mesh
		roof_inst.material_override = _roof_mats[i]
		body.add_child(roof_inst)

	# Interior mesh (single draw call for all interiors in chunk)
	if has_interiors:
		int_st.generate_normals()
		var int_mesh := int_st.commit()
		var int_inst := MeshInstance3D.new()
		int_inst.name = "Interiors"
		int_inst.mesh = int_mesh
		int_inst.material_override = _interior_mat
		body.add_child(int_inst)

	# Register chunk for independent per-chunk night toggling
	if win_st_has_data.has(true):
		var win_active: Array[bool] = []
		win_active.resize(win_count)
		win_active.fill(true)
		body.set_meta("window_mats", local_win_mats)
		body.set_meta("window_active", win_active)
		body.add_to_group("building_chunk")

	chunk.add_child(body)

	for di: Array in door_infos:
		_create_door_node(chunk, di[0] as Vector3, di[1] as Vector3, di[2] as int)


func _add_building_with_door(
	ext_st: SurfaceTool,
	int_st: SurfaceTool,
	center: Vector3,
	size: Vector3,
	door_face: int,
) -> void:
	var hx := size.x * 0.5
	var hz := size.z * 0.5

	# Face definitions: [face_center_offset, face_width, normal, right]
	var faces: Array[Array] = [
		# 0: Front (-Z)
		[Vector3(0, 0, -hz), size.x,
			Vector3(0, 0, -1), Vector3(1, 0, 0)],
		# 1: Back (+Z)
		[Vector3(0, 0, hz), size.x,
			Vector3(0, 0, 1), Vector3(-1, 0, 0)],
		# 2: Left (-X)
		[Vector3(-hx, 0, 0), size.z,
			Vector3(-1, 0, 0), Vector3(0, 0, -1)],
		# 3: Right (+X)
		[Vector3(hx, 0, 0), size.z,
			Vector3(1, 0, 0), Vector3(0, 0, 1)],
	]

	# Emit 4 exterior faces (3 solid + 1 with door hole)
	for i in range(4):
		var face_offset: Vector3 = faces[i][0]
		var face_width: float = faces[i][1]
		var face_normal: Vector3 = faces[i][2]
		var face_right: Vector3 = faces[i][3]
		var face_center := center + face_offset

		if i == door_face:
			_city_script.st_add_face_with_door(
				ext_st, face_center,
				face_width, size.y,
				face_normal, face_right,
				DOOR_WIDTH, DOOR_HEIGHT,
			)
		else:
			_st_add_solid_face(
				ext_st, face_center, face_width, size.y,
				face_right,
			)

	# Top face (+Y) -- always solid
	_st_add_top_face(ext_st, center, size)

	# Interior room
	_add_interior_room(int_st, center, size, door_face)


func _st_add_solid_face(
	st: SurfaceTool,
	face_center: Vector3,
	face_width: float, face_height: float,
	right: Vector3,
) -> void:
	var up := Vector3.UP
	var hw := face_width * 0.5
	var hh := face_height * 0.5
	var bl := face_center - right * hw - up * hh
	var br := face_center + right * hw - up * hh
	var tr := face_center + right * hw + up * hh
	var tl := face_center - right * hw + up * hh
	_city_script.st_add_quad(st, bl, br, tr, tl)


func _st_add_top_face(
	st: SurfaceTool, center: Vector3, size: Vector3,
) -> void:
	var hx := size.x * 0.5
	var hz := size.z * 0.5
	var ty := center.y + size.y * 0.5
	var cx := center.x
	var cz := center.z
	# Top (+Y): CCW when viewed from above
	var v0 := Vector3(cx - hx, ty, cz - hz)
	var v1 := Vector3(cx + hx, ty, cz - hz)
	var v2 := Vector3(cx + hx, ty, cz + hz)
	var v3 := Vector3(cx - hx, ty, cz + hz)
	st.add_vertex(v0); st.add_vertex(v3); st.add_vertex(v1)
	st.add_vertex(v1); st.add_vertex(v3); st.add_vertex(v2)


func _add_interior_room(
	int_st: SurfaceTool,
	center: Vector3,
	size: Vector3,
	door_face: int,
) -> void:
	var by := center.y - size.y * 0.5  # building bottom Y
	var inset := INTERIOR_INSET
	var room_w := size.x - inset * 2.0
	var room_d := size.z - inset * 2.0
	var floor_y := by + INTERIOR_FLOOR_Y
	var ceil_y := by + INTERIOR_FLOOR_Y + INTERIOR_HEIGHT

	var room_center := Vector3(
		center.x, (floor_y + ceil_y) * 0.5, center.z,
	)
	var room_hx := room_w * 0.5
	var room_hz := room_d * 0.5

	# Floor quad (facing +Y)
	var f0 := Vector3(center.x - room_hx, floor_y, center.z - room_hz)
	var f1 := Vector3(center.x + room_hx, floor_y, center.z - room_hz)
	var f2 := Vector3(center.x + room_hx, floor_y, center.z + room_hz)
	var f3 := Vector3(center.x - room_hx, floor_y, center.z + room_hz)
	int_st.add_vertex(f0); int_st.add_vertex(f3); int_st.add_vertex(f1)
	int_st.add_vertex(f1); int_st.add_vertex(f3); int_st.add_vertex(f2)

	# Ceiling quad (facing -Y)
	var c0 := Vector3(center.x - room_hx, ceil_y, center.z - room_hz)
	var c1 := Vector3(center.x + room_hx, ceil_y, center.z - room_hz)
	var c2 := Vector3(center.x + room_hx, ceil_y, center.z + room_hz)
	var c3 := Vector3(center.x - room_hx, ceil_y, center.z + room_hz)
	int_st.add_vertex(c0); int_st.add_vertex(c1); int_st.add_vertex(c3)
	int_st.add_vertex(c1); int_st.add_vertex(c2); int_st.add_vertex(c3)

	# Interior walls -- normals point INWARD
	var int_faces: Array[Array] = [
		# 0: Front wall (at -Z side), inward normal = +Z
		[Vector3(0, 0, -room_hz), room_w,
			Vector3(0, 0, 1), Vector3(-1, 0, 0)],
		# 1: Back wall (at +Z side), inward normal = -Z
		[Vector3(0, 0, room_hz), room_w,
			Vector3(0, 0, -1), Vector3(1, 0, 0)],
		# 2: Left wall (at -X side), inward normal = +X
		[Vector3(-room_hx, 0, 0), room_d,
			Vector3(1, 0, 0), Vector3(0, 0, 1)],
		# 3: Right wall (at +X side), inward normal = -X
		[Vector3(room_hx, 0, 0), room_d,
			Vector3(-1, 0, 0), Vector3(0, 0, -1)],
	]

	var wall_height := ceil_y - floor_y
	for i in range(4):
		var wall_offset: Vector3 = int_faces[i][0]
		var wall_width: float = int_faces[i][1]
		var wall_normal: Vector3 = int_faces[i][2]
		var wall_right: Vector3 = int_faces[i][3]
		var wall_center := room_center + wall_offset

		if i == door_face:
			_city_script.st_add_face_with_door(
				int_st, wall_center,
				wall_width, wall_height,
				wall_normal, wall_right,
				DOOR_WIDTH, DOOR_HEIGHT,
			)
		else:
			var hw := wall_width * 0.5
			var hh := wall_height * 0.5
			_city_script.st_add_quad(
				int_st,
				wall_center - wall_right * hw - Vector3.UP * hh,
				wall_center + wall_right * hw - Vector3.UP * hh,
				wall_center + wall_right * hw + Vector3.UP * hh,
				wall_center - wall_right * hw + Vector3.UP * hh,
			)


func _add_building_collision_with_door(
	body: StaticBody3D,
	center: Vector3,
	size: Vector3,
	door_face: int,
) -> void:
	var hx := size.x * 0.5
	var hz := size.z * 0.5
	var wt := WALL_THICKNESS

	# Ceiling collision (thin box at top)
	var ceil_center := Vector3(
		center.x,
		center.y + size.y * 0.5 - wt * 0.5,
		center.z,
	)
	_city_script.add_box_collision(
		body, ceil_center, Vector3(size.x, wt, size.z),
	)

	# Wall collision shapes -- 3 solid walls + 1 split wall
	var walls: Array[Array] = [
		# 0: Front (-Z)
		[Vector3(0, 0, -hz + wt * 0.5),
			Vector3(size.x, size.y, wt)],
		# 1: Back (+Z)
		[Vector3(0, 0, hz - wt * 0.5),
			Vector3(size.x, size.y, wt)],
		# 2: Left (-X)
		[Vector3(-hx + wt * 0.5, 0, 0),
			Vector3(wt, size.y, size.z)],
		# 3: Right (+X)
		[Vector3(hx - wt * 0.5, 0, 0),
			Vector3(wt, size.y, size.z)],
	]

	for i in range(4):
		var wall_offset: Vector3 = walls[i][0]
		var wall_size: Vector3 = walls[i][1]
		var wall_center := center + wall_offset
		if i == door_face:
			_add_door_wall_collision(
				body, wall_center, wall_size, i,
			)
		else:
			_city_script.add_box_collision(
				body, wall_center, wall_size,
			)

	# Interior floor collision
	var floor_y := (
		center.y - size.y * 0.5 + INTERIOR_FLOOR_Y - 0.05
	)
	var floor_center := Vector3(center.x, floor_y, center.z)
	_city_script.add_box_collision(
		body, floor_center,
		Vector3(size.x - wt * 2.0, 0.1, size.z - wt * 2.0),
	)


func _add_door_wall_collision(
	body: StaticBody3D,
	wall_center: Vector3,
	wall_size: Vector3,
	face_idx: int,
) -> void:
	var is_x_wall: bool = face_idx <= 1
	var wall_span: float = wall_size.x if is_x_wall else wall_size.z
	var hw := wall_span * 0.5
	var hdw := DOOR_WIDTH * 0.5
	var hy := wall_size.y * 0.5

	# Left segment: from wall left edge to door left edge
	var left_width := hw - hdw
	if left_width > 0.01:
		var left_offset := -(hw - left_width * 0.5)
		var left_size := wall_size
		var left_center := wall_center
		if is_x_wall:
			left_size.x = left_width
			left_center.x += left_offset
		else:
			left_size.z = left_width
			left_center.z += left_offset
		_city_script.add_box_collision(body, left_center, left_size)

	# Right segment: from door right edge to wall right edge
	var right_width := hw - hdw
	if right_width > 0.01:
		var right_offset := hw - right_width * 0.5
		var right_size := wall_size
		var right_center := wall_center
		if is_x_wall:
			right_size.x = right_width
			right_center.x += right_offset
		else:
			right_size.z = right_width
			right_center.z += right_offset
		_city_script.add_box_collision(
			body, right_center, right_size,
		)

	# Above-door segment
	var above_height := wall_size.y - DOOR_HEIGHT
	if above_height > 0.01:
		var above_center := wall_center
		above_center.y += hy - above_height * 0.5
		var above_size := wall_size
		if is_x_wall:
			above_size.x = DOOR_WIDTH
		else:
			above_size.z = DOOR_WIDTH
		above_size.y = above_height
		_city_script.add_box_collision(
			body, above_center, above_size,
		)


## Add a pitched roof (gable or hip) on top of a building.
## center/size = building box center and size (roof sits on top face).
func _st_add_pitched_roof(
	st: SurfaceTool, center: Vector3, size: Vector3,
	rng: RandomNumberGenerator,
) -> void:
	var hx := size.x * 0.5
	var hz := size.z * 0.5
	var top_y := center.y + size.y * 0.5
	var cx := center.x
	var cz := center.z
	# Roof height proportional to shorter dimension
	var roof_h: float = minf(size.x, size.z) * rng.randf_range(0.3, 0.5)

	var style := rng.randi_range(0, 1)  # 0=gable, 1=hip
	if style == 0:
		_st_add_gable_roof(st, cx, cz, top_y, hx, hz, roof_h)
	else:
		_st_add_hip_roof(st, cx, cz, top_y, hx, hz, roof_h)


## Gable roof: ridge along longer axis, two sloped faces + two triangular gable ends.
func _st_add_gable_roof(
	st: SurfaceTool,
	cx: float, cz: float, top_y: float,
	hx: float, hz: float, roof_h: float,
) -> void:
	var ridge_y := top_y + roof_h
	# Ridge runs along X if building is wider, else along Z
	if hx >= hz:
		# Ridge along X axis
		var r0 := Vector3(cx - hx, ridge_y, cz)
		var r1 := Vector3(cx + hx, ridge_y, cz)
		var e0 := Vector3(cx - hx, top_y, cz - hz)
		var e1 := Vector3(cx + hx, top_y, cz - hz)
		var e2 := Vector3(cx + hx, top_y, cz + hz)
		var e3 := Vector3(cx - hx, top_y, cz + hz)
		# Front slope (-Z side)
		_city_script.st_add_quad(st, e0, e1, r1, r0)
		# Back slope (+Z side)
		_city_script.st_add_quad(st, e2, e3, r0, r1)
		# Gable ends (triangles) — winding: outward normal = -X (left) and +X (right)
		st.add_vertex(e0); st.add_vertex(e3); st.add_vertex(r0)
		st.add_vertex(e1); st.add_vertex(r1); st.add_vertex(e2)
	else:
		# Ridge along Z axis
		var r0 := Vector3(cx, ridge_y, cz - hz)
		var r1 := Vector3(cx, ridge_y, cz + hz)
		var e0 := Vector3(cx - hx, top_y, cz - hz)
		var e1 := Vector3(cx + hx, top_y, cz - hz)
		var e2 := Vector3(cx + hx, top_y, cz + hz)
		var e3 := Vector3(cx - hx, top_y, cz + hz)
		# Left slope (-X side)
		_city_script.st_add_quad(st, e3, e0, r0, r1)
		# Right slope (+X side)
		_city_script.st_add_quad(st, e1, e2, r1, r0)
		# Gable ends (triangles) — winding: outward normal = -Z (front) and +Z (back)
		st.add_vertex(e0); st.add_vertex(r0); st.add_vertex(e1)
		st.add_vertex(e2); st.add_vertex(r1); st.add_vertex(e3)


## Hip roof: ridge shorter than building, all 4 sides slope.
func _st_add_hip_roof(
	st: SurfaceTool,
	cx: float, cz: float, top_y: float,
	hx: float, hz: float, roof_h: float,
) -> void:
	var ridge_y := top_y + roof_h
	# Ridge inset from edges
	var inset: float = minf(hx, hz) * 0.6
	var e0 := Vector3(cx - hx, top_y, cz - hz)
	var e1 := Vector3(cx + hx, top_y, cz - hz)
	var e2 := Vector3(cx + hx, top_y, cz + hz)
	var e3 := Vector3(cx - hx, top_y, cz + hz)

	if hx >= hz:
		# Ridge along X, inset from X ends
		var r0 := Vector3(cx - hx + inset, ridge_y, cz)
		var r1 := Vector3(cx + hx - inset, ridge_y, cz)
		# Front slope (-Z)
		_city_script.st_add_quad(st, e0, e1, r1, r0)
		# Back slope (+Z)
		_city_script.st_add_quad(st, e2, e3, r0, r1)
		# Left hip triangle — outward normal = -X
		st.add_vertex(e0); st.add_vertex(e3); st.add_vertex(r0)
		# Right hip triangle — outward normal = +X
		st.add_vertex(e1); st.add_vertex(r1); st.add_vertex(e2)
	else:
		# Ridge along Z, inset from Z ends
		var r0 := Vector3(cx, ridge_y, cz - hz + inset)
		var r1 := Vector3(cx, ridge_y, cz + hz - inset)
		# Left slope (-X)
		_city_script.st_add_quad(st, e3, e0, r0, r1)
		# Right slope (+X)
		_city_script.st_add_quad(st, e1, e2, r1, r0)
		# Front hip triangle — outward normal = -Z
		st.add_vertex(e0); st.add_vertex(r0); st.add_vertex(e1)
		# Back hip triangle — outward normal = +Z
		st.add_vertex(e2); st.add_vertex(r1); st.add_vertex(e3)


## Spawn an interactive door node at the correct hinge position for a building.
## door_face: 0=front(-Z), 1=back(+Z), 2=left(-X), 3=right(+X)
func _create_door_node(
	chunk: Node3D,
	center: Vector3,
	size: Vector3,
	door_face: int,
) -> void:
	var hx := size.x * 0.5
	var hz := size.z * 0.5
	var ground_y := center.y - size.y * 0.5

	# Face data: [xz_offset, normal, right, door_rot_y]
	# door_rot_y sets basis so local +X = face_right and local -Z = face_normal.
	var face_data: Array[Array] = [
		[Vector3(0, 0, -hz), Vector3(0, 0, -1), Vector3(1, 0, 0), 0.0],
		[Vector3(0, 0, hz),  Vector3(0, 0, 1),  Vector3(-1, 0, 0), PI],
		[Vector3(-hx, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, -1), PI / 2.0],
		[Vector3(hx, 0, 0),  Vector3(1, 0, 0),  Vector3(0, 0, 1), -PI / 2.0],
	]

	var fd: Array = face_data[door_face]
	var face_offset: Vector3 = fd[0]
	var face_normal: Vector3 = fd[1]
	var face_right: Vector3 = fd[2]
	var door_rot_y: float = fd[3]

	# Hinge at right edge of door opening, flush with outer face
	var hinge_pos := Vector3(
		center.x + face_offset.x + face_right.x * DOOR_WIDTH * 0.5 + face_normal.x * 0.03,
		ground_y,
		center.z + face_offset.z + face_right.z * DOOR_WIDTH * 0.5 + face_normal.z * 0.03,
	)

	var door_node := Node3D.new()
	door_node.name = "Door"
	door_node.set_script(_door_script)
	door_node.position = hinge_pos
	door_node.rotation.y = door_rot_y

	# Door panel mesh — local X is face_right, so mesh spans -DOOR_WIDTH/2 from hinge
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.name = "DoorMesh"
	var box := BoxMesh.new()
	box.size = Vector3(DOOR_WIDTH - 0.04, DOOR_HEIGHT - 0.04, 0.06)
	mesh_inst.mesh = box
	mesh_inst.position = Vector3(-DOOR_WIDTH * 0.5, DOOR_HEIGHT * 0.5, 0.0)
	if _building_mats.size() > 0:
		mesh_inst.material_override = _building_mats[0]
	door_node.add_child(mesh_inst)

	# Interaction zone — in local space, local -Z points outward (face normal direction)
	var area := Area3D.new()
	area.name = "InteractionZone"
	area.collision_layer = 0
	area.collision_mask = 4  # Player layer

	var col_shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 2.5
	col_shape.shape = sphere
	col_shape.position = Vector3(0.0, DOOR_HEIGHT * 0.5, -2.5)
	area.add_child(col_shape)
	door_node.add_child(area)

	chunk.add_child(door_node)


func _get_block_center_local(bx: int, bz: int) -> Vector2:
	var cx: float = (
		_grid.get_road_center_local(bx) + _grid.get_road_width(bx) * 0.5
		+ _grid.get_road_center_local(bx + 1) - _grid.get_road_width(bx + 1) * 0.5
	) * 0.5
	var cz: float = (
		_grid.get_road_center_local(bz) + _grid.get_road_width(bz) * 0.5
		+ _grid.get_road_center_local(bz + 1) - _grid.get_road_width(bz + 1) * 0.5
	) * 0.5
	return Vector2(cx, cz)
