extends RefCounted
## Builds merged road, block-ground, and sidewalk meshes for a chunk.
## One MeshInstance3D + one compound StaticBody3D per category.

var _grid: RefCounted
var _road_mat: StandardMaterial3D
var _sidewalk_mat: StandardMaterial3D
var _ground_mat: StandardMaterial3D

var _city_script: GDScript = preload("res://scenes/world/city.gd")


func init(
	grid: RefCounted,
	road_mat: StandardMaterial3D,
	sidewalk_mat: StandardMaterial3D,
	ground_mat: StandardMaterial3D,
) -> void:
	_grid = grid
	_road_mat = road_mat
	_sidewalk_mat = sidewalk_mat
	_ground_mat = ground_mat


func build(chunk: Node3D, ox: float, oz: float, span: float) -> void:
	_build_roads(chunk, ox, oz, span)
	_build_block_ground(chunk, ox, oz)
	_build_sidewalks(chunk, ox, oz)


# --- Roads: 22 segments -> 1 merged mesh + 1 compound body ---


func _build_roads(chunk: Node3D, ox: float, oz: float, span: float) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var body := StaticBody3D.new()
	body.name = "Roads"
	body.collision_layer = 1
	body.collision_mask = 0
	body.add_to_group("Road")

	var rt: float = _grid.ROAD_THICKNESS

	# E-W roads (full span — drawn first, serve as intersection surface)
	for j in range(_grid.GRID_SIZE + 1):
		var w: float = _grid.get_road_width(j)
		var cz: float = _grid.get_road_center_local(j) + oz
		var center := Vector3(ox, -rt * 0.5, cz)
		var size := Vector3(span, rt, w)
		_city_script.st_add_box(st, center, size)
		_city_script.add_box_collision(body, center, size)

	# N-S roads (segmented between E-W roads — no intersection overlap)
	for i in range(_grid.GRID_SIZE + 1):
		var w: float = _grid.get_road_width(i)
		var cx: float = _grid.get_road_center_local(i) + ox
		for j in range(_grid.GRID_SIZE):
			var z0: float = _grid.get_road_center_local(j) + _grid.get_road_width(j) * 0.5
			var z1: float = _grid.get_road_center_local(j + 1) - _grid.get_road_width(j + 1) * 0.5
			var seg_len := z1 - z0
			if seg_len <= 0.0:
				continue
			var seg_cz := (z0 + z1) * 0.5 + oz
			var center := Vector3(cx, -rt * 0.5, seg_cz)
			var size := Vector3(w, rt, seg_len)
			_city_script.st_add_box(st, center, size)
			_city_script.add_box_collision(body, center, size)

	st.generate_normals()
	var mesh := st.commit()

	var mesh_inst := MeshInstance3D.new()
	mesh_inst.name = "RoadsMesh"
	mesh_inst.mesh = mesh
	mesh_inst.material_override = _road_mat
	body.add_child(mesh_inst)

	chunk.add_child(body)


# --- Block ground: 100 blocks -> 1 merged mesh + 1 compound body ---


func _build_block_ground(chunk: Node3D, ox: float, oz: float) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var body := StaticBody3D.new()
	body.name = "BlockGround"
	body.collision_layer = 1
	body.collision_mask = 0
	body.add_to_group("Road")

	var rt: float = _grid.ROAD_THICKNESS

	for bx in range(_grid.GRID_SIZE):
		for bz in range(_grid.GRID_SIZE):
			var x_start: float = _grid.get_road_center_local(bx) + _grid.get_road_width(bx) * 0.5
			var x_end: float = (
				_grid.get_road_center_local(bx + 1) - _grid.get_road_width(bx + 1) * 0.5
			)
			var z_start: float = _grid.get_road_center_local(bz) + _grid.get_road_width(bz) * 0.5
			var z_end: float = (
				_grid.get_road_center_local(bz + 1) - _grid.get_road_width(bz + 1) * 0.5
			)
			var bw := x_end - x_start
			var bd := z_end - z_start
			var gcx := (x_start + x_end) * 0.5 + ox
			var gcz := (z_start + z_end) * 0.5 + oz
			var center := Vector3(gcx, -rt * 0.5, gcz)
			var size := Vector3(bw, rt, bd)
			_city_script.st_add_box(st, center, size)
			_city_script.add_box_collision(body, center, size)

	st.generate_normals()
	var mesh := st.commit()

	var mesh_inst := MeshInstance3D.new()
	mesh_inst.name = "BlockGroundMesh"
	mesh_inst.mesh = mesh
	mesh_inst.material_override = _ground_mat
	body.add_child(mesh_inst)

	chunk.add_child(body)


# --- Sidewalks: ~440 segments -> 1 merged mesh + 1 compound body ---


func _build_sidewalks(chunk: Node3D, ox: float, oz: float) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var body := StaticBody3D.new()
	body.name = "Sidewalks"
	body.collision_layer = 1
	body.collision_mask = 0
	body.add_to_group("Road")

	var sw: float = _grid.SIDEWALK_WIDTH
	var sh: float = _grid.SIDEWALK_HEIGHT
	var rr: float = _grid.CURB_RAMP_RUN
	# Raise sidewalks slightly above road surface to prevent z-fighting
	var y_offset := 0.005

	# N-S road sidewalks
	for i in range(_grid.GRID_SIZE + 1):
		var rw: float = _grid.get_road_width(i)
		var cx: float = _grid.get_road_center_local(i) + ox
		for j in range(_grid.GRID_SIZE):
			var z_start: float = _grid.get_road_center_local(j) + _grid.get_road_width(j) * 0.5
			var z_end: float = (
				_grid.get_road_center_local(j + 1) - _grid.get_road_width(j + 1) * 0.5
			)
			var seg_len := z_end - z_start
			var seg_cz := (z_start + z_end) * 0.5 + oz
			var cy := sh * 0.5 + y_offset

			# Left sidewalk
			var lc := Vector3(cx - rw * 0.5 - sw * 0.5, cy, seg_cz)
			_city_script.st_add_box(st, lc, Vector3(sw, sh, seg_len))
			_city_script.add_sidewalk_collision(body, lc, sw, seg_len, sh, rr, "z")

			# Right sidewalk
			var rc := Vector3(cx + rw * 0.5 + sw * 0.5, cy, seg_cz)
			_city_script.st_add_box(st, rc, Vector3(sw, sh, seg_len))
			_city_script.add_sidewalk_collision(body, rc, sw, seg_len, sh, rr, "z")

	# E-W road sidewalks — trimmed by sw at each end to avoid corner overlap
	for j in range(_grid.GRID_SIZE + 1):
		var rw: float = _grid.get_road_width(j)
		var cz: float = _grid.get_road_center_local(j) + oz
		for i in range(_grid.GRID_SIZE):
			# inset past N-S sidewalk
			var x_start: float = (
				_grid.get_road_center_local(i) + _grid.get_road_width(i) * 0.5 + sw
			)
			var x_end: float = (
				_grid.get_road_center_local(i + 1) - _grid.get_road_width(i + 1) * 0.5 - sw
			)  # inset past N-S sidewalk
			var seg_len := x_end - x_start
			if seg_len <= 0.0:
				continue
			var seg_cx := (x_start + x_end) * 0.5 + ox
			var cy := sh * 0.5 + y_offset

			# Top sidewalk
			var tc := Vector3(seg_cx, cy, cz - rw * 0.5 - sw * 0.5)
			_city_script.st_add_box(st, tc, Vector3(seg_len, sh, sw))
			_city_script.add_sidewalk_collision(body, tc, sw, seg_len, sh, rr, "x")

			# Bottom sidewalk
			var bc := Vector3(seg_cx, cy, cz + rw * 0.5 + sw * 0.5)
			_city_script.st_add_box(st, bc, Vector3(seg_len, sh, sw))
			_city_script.add_sidewalk_collision(body, bc, sw, seg_len, sh, rr, "x")

	st.generate_normals()
	var mesh := st.commit()

	var mesh_inst := MeshInstance3D.new()
	mesh_inst.name = "SidewalksMesh"
	mesh_inst.mesh = mesh
	mesh_inst.material_override = _sidewalk_mat
	body.add_child(mesh_inst)

	chunk.add_child(body)
