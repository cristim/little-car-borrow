extends RefCounted
## Builds merged building meshes grouped by material palette index.
## Up to 12 MeshInstance3D + 1 compound StaticBody3D per chunk.

const DOOR_WIDTH := 1.2
const DOOR_HEIGHT := 2.2
const INTERIOR_HEIGHT := 3.0
const INTERIOR_FLOOR_Y := 0.05
const INTERIOR_INSET := 0.15
const WALL_THICKNESS := 0.25

var _grid: RefCounted
var _building_mats: Array[StandardMaterial3D] = []
var _window_mats: Array[StandardMaterial3D] = []
var _interior_mat: StandardMaterial3D
var _city_script: GDScript = preload("res://scenes/world/city.gd")


func init(
	grid: RefCounted,
	building_mats: Array[StandardMaterial3D],
	window_mats: Array[StandardMaterial3D],
	interior_mat: StandardMaterial3D,
) -> void:
	_grid = grid
	_building_mats = building_mats
	_window_mats = window_mats
	_interior_mat = interior_mat


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

	# Single compound collision body for all buildings
	var body := StaticBody3D.new()
	body.name = "Buildings"
	body.collision_layer = 2
	body.collision_mask = 0
	body.add_to_group("Static")

	# Interior SurfaceTool (single material for all interiors)
	var int_st := SurfaceTool.new()
	int_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var has_interiors := false

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
					bh * 0.5,
					block_center.y + bz_off + oz,
				)
				var size := Vector3(bw, bh, bd)
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

				# Add windows on buildings taller than 6m
				if s.y > 6.0:
					var win_idx := rng.randi() % win_count
					if not win_st_has_data[win_idx]:
						win_sts[win_idx].begin(
							Mesh.PRIMITIVE_TRIANGLES,
						)
						win_st_has_data[win_idx] = true
					_add_building_windows(
						win_sts[win_idx], c, s, rng,
					)

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
		win_inst.material_override = _window_mats[i]
		body.add_child(win_inst)

	# Interior mesh (single draw call for all interiors in chunk)
	if has_interiors:
		int_st.generate_normals()
		var int_mesh := int_st.commit()
		var int_inst := MeshInstance3D.new()
		int_inst.name = "Interiors"
		int_inst.mesh = int_mesh
		int_inst.material_override = _interior_mat
		body.add_child(int_inst)

	chunk.add_child(body)


func _add_building_windows(
	win_st: SurfaceTool,
	center: Vector3,
	size: Vector3,
	rng: RandomNumberGenerator,
) -> void:
	var hx := size.x * 0.5
	var hz := size.z * 0.5
	# Front (-Z): normal=(0,0,-1), right=(1,0,0)
	_city_script.st_add_windows_on_face(
		win_st,
		center + Vector3(0, 0, -hz),
		size.x, size.y,
		Vector3(0, 0, -1), Vector3(1, 0, 0),
		rng,
	)
	# Back (+Z): normal=(0,0,1), right=(-1,0,0)
	_city_script.st_add_windows_on_face(
		win_st,
		center + Vector3(0, 0, hz),
		size.x, size.y,
		Vector3(0, 0, 1), Vector3(-1, 0, 0),
		rng,
	)
	# Left (-X): normal=(-1,0,0), right=(0,0,-1)
	_city_script.st_add_windows_on_face(
		win_st,
		center + Vector3(-hx, 0, 0),
		size.z, size.y,
		Vector3(-1, 0, 0), Vector3(0, 0, -1),
		rng,
	)
	# Right (+X): normal=(1,0,0), right=(0,0,1)
	_city_script.st_add_windows_on_face(
		win_st,
		center + Vector3(hx, 0, 0),
		size.z, size.y,
		Vector3(1, 0, 0), Vector3(0, 0, 1),
		rng,
	)


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
	_door_face: int,
) -> void:
	# Stub: use single box collision until decomposition is implemented
	_city_script.add_box_collision(body, center, size)


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
