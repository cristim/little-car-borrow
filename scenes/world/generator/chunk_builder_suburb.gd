extends RefCounted
## Builds suburb chunks: road grid with lower density buildings, yards,
## and more green space. Uses same road grid as city but fewer/shorter buildings.
## Each house has a door, residential-scale windows, and a visible interior room.

const MAX_BUILDINGS_PER_BLOCK := 2
const MIN_HEIGHT := 3.0
const MAX_HEIGHT := 8.0
const DOOR_WIDTH := 1.2
const DOOR_HEIGHT := 2.0
## House window dimensions — smaller than commercial buildings
const HOUSE_WIN_W := 0.7
const HOUSE_WIN_H := 0.8
const HOUSE_WIN_GAP_X := 0.5
const HOUSE_WIN_MARGIN_X := 0.6
const HOUSE_WIN_MARGIN_BOT := 0.8
const HOUSE_WIN_MARGIN_TOP := 0.5

var _grid: RefCounted
var _building_mats: Array[StandardMaterial3D] = []
var _window_mats: Array[StandardMaterial3D] = []
var _interior_mat: StandardMaterial3D
var _roof_mats: Array[StandardMaterial3D] = []
var _bld_builder: RefCounted  # chunk_builder_buildings.gd for door/interior helpers
var _city_script: GDScript = preload("res://scenes/world/city.gd")


func init(
	grid: RefCounted,
	building_mats: Array[StandardMaterial3D],
	window_mats: Array[StandardMaterial3D],
	interior_mat: StandardMaterial3D,
	roof_mats: Array[StandardMaterial3D],
	bld_builder: RefCounted,
) -> void:
	_grid = grid
	_building_mats = building_mats
	_window_mats = window_mats
	_interior_mat = interior_mat
	_roof_mats = roof_mats
	_bld_builder = bld_builder


func build(chunk: Node3D, tile: Vector2i, ox: float, oz: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(tile) ^ 0x50BB

	var mat_count := _building_mats.size()
	var sts: Array[SurfaceTool] = []
	var st_used: Array[bool] = []
	for _i in range(mat_count):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		sts.append(st)
		st_used.append(false)

	var win_count := _window_mats.size()
	var win_sts: Array[SurfaceTool] = []
	var win_st_has_data: Array[bool] = []
	for _i in win_count:
		win_sts.append(SurfaceTool.new())
		win_st_has_data.append(false)

	# Per-chunk window materials — fresh copies so this chunk toggles
	# independently from every other chunk.
	var local_win_mats: Array[StandardMaterial3D] = []
	for i in win_count:
		var m := StandardMaterial3D.new()
		m.albedo_color = _window_mats[i].albedo_color
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		local_win_mats.append(m)

	var roof_count := _roof_mats.size()
	var roof_sts: Array[SurfaceTool] = []
	var roof_st_used: Array[bool] = []
	for _i in range(roof_count):
		var rst := SurfaceTool.new()
		rst.begin(Mesh.PRIMITIVE_TRIANGLES)
		roof_sts.append(rst)
		roof_st_used.append(false)

	var int_st := SurfaceTool.new()
	int_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var has_interiors := false

	var body := StaticBody3D.new()
	body.name = "SuburbBuildings"
	body.collision_layer = 2
	body.collision_mask = 0
	body.add_to_group("Static")

	var any_placed := false
	var door_infos: Array[Array] = []

	for bx in range(_grid.GRID_SIZE):
		for bz in range(_grid.GRID_SIZE):
			# ~50% of blocks have buildings (sparse suburb)
			if rng.randf() > 0.5:
				continue

			var block_center := _get_block_center(bx, bz)
			var count := rng.randi_range(1, MAX_BUILDINGS_PER_BLOCK)

			for _b in range(count):
				var bw := rng.randf_range(6.0, 14.0)
				var bd := rng.randf_range(6.0, 14.0)
				var bh := rng.randf_range(MIN_HEIGHT, MAX_HEIGHT)
				var block_size: float = _grid.BLOCK_SIZE
				var margin := 4.0  # wider margins for yards
				var max_off := maxf(
					(block_size - maxf(bw, bd)) * 0.5 - margin,
					0.0,
				)
				var off_x := rng.randf_range(-max_off, max_off)
				var off_z := rng.randf_range(-max_off, max_off)

				var mi := rng.randi() % mat_count
				var center := Vector3(
					block_center.x + off_x + ox,
					bh * 0.5,
					block_center.y + off_z + oz,
				)
				var size := Vector3(bw, bh, bd)

				# Pick a door face and check it's wide enough
				var door_face := rng.randi_range(0, 3)
				var face_w: float = size.x if door_face <= 1 else size.z
				var has_door := (
					face_w >= DOOR_WIDTH + 0.5
					and _bld_builder != null
				)

				if has_door:
					_bld_builder._add_building_with_door(
						sts[mi], int_st, center, size, door_face,
					)
					_bld_builder._add_building_collision_with_door(
						body, center, size, door_face,
					)
					door_infos.append([center, size, door_face])
					has_interiors = true
				else:
					_city_script.st_add_box_no_bottom(sts[mi], center, size)
					_city_script.add_box_collision(body, center, size)
				st_used[mi] = true

				# Windows on all faces except the door face
				_add_house_windows(
					win_sts, win_count, win_st_has_data,
					center, size, door_face if has_door else -1, rng,
				)

				# Pitched roof on all suburb houses
				if roof_count > 0 and _bld_builder:
					var ri := rng.randi() % roof_count
					_bld_builder._st_add_pitched_roof(
						roof_sts[ri], center, size, rng,
					)
					roof_st_used[ri] = true

				any_placed = true

	if not any_placed:
		body.queue_free()
		return

	for i in range(mat_count):
		if not st_used[i]:
			continue
		sts[i].generate_normals()
		var mesh := sts[i].commit()
		var mesh_inst := MeshInstance3D.new()
		mesh_inst.name = "SuburbMat_%d" % i
		mesh_inst.mesh = mesh
		mesh_inst.material_override = _building_mats[i]
		body.add_child(mesh_inst)

	for i in range(win_count):
		if not win_st_has_data[i]:
			continue
		win_sts[i].generate_normals()
		var win_mesh := win_sts[i].commit()
		var win_inst := MeshInstance3D.new()
		win_inst.name = "SuburbWindows_%d" % i
		win_inst.mesh = win_mesh
		win_inst.material_override = local_win_mats[i]
		body.add_child(win_inst)

	for i in range(roof_count):
		if not roof_st_used[i]:
			continue
		roof_sts[i].generate_normals()
		var roof_mesh := roof_sts[i].commit()
		var roof_inst := MeshInstance3D.new()
		roof_inst.name = "SuburbRoofs_%d" % i
		roof_inst.mesh = roof_mesh
		roof_inst.material_override = _roof_mats[i]
		body.add_child(roof_inst)

	if has_interiors and _interior_mat:
		int_st.generate_normals()
		var int_mesh := int_st.commit()
		var int_inst := MeshInstance3D.new()
		int_inst.name = "SuburbInteriors"
		int_inst.mesh = int_mesh
		int_inst.material_override = _interior_mat
		body.add_child(int_inst)

	if win_st_has_data.has(true):
		var win_active: Array[bool] = []
		win_active.resize(win_count)
		win_active.fill(true)
		body.set_meta("window_mats", local_win_mats)
		body.set_meta("window_active", win_active)
		body.add_to_group("building_chunk")

	chunk.add_child(body)

	for di: Array in door_infos:
		_bld_builder._create_door_node(
			chunk, di[0] as Vector3, di[1] as Vector3, di[2] as int,
		)


## Add residential-scale windows on all faces except the door face.
func _add_house_windows(
	win_sts: Array,
	win_count: int,
	win_st_has_data: Array,
	center: Vector3,
	size: Vector3,
	door_face: int,
	rng: RandomNumberGenerator,
) -> void:
	var hx := size.x * 0.5
	var hz := size.z * 0.5
	var faces: Array[Array] = [
		[center + Vector3(0, 0, -hz), size.x,
			Vector3(0, 0, -1), Vector3(1, 0, 0)],
		[center + Vector3(0, 0, hz), size.x,
			Vector3(0, 0, 1), Vector3(-1, 0, 0)],
		[center + Vector3(-hx, 0, 0), size.z,
			Vector3(-1, 0, 0), Vector3(0, 0, -1)],
		[center + Vector3(hx, 0, 0), size.z,
			Vector3(1, 0, 0), Vector3(0, 0, 1)],
	]
	for i in range(4):
		if i == door_face:
			continue
		_add_house_windows_on_face(
			win_sts, win_count, win_st_has_data,
			faces[i][0] as Vector3, faces[i][1] as float, size.y,
			faces[i][2] as Vector3, faces[i][3] as Vector3,
			rng,
		)


## Place one row of residential windows on a single face.
func _add_house_windows_on_face(
	win_sts: Array,
	win_count: int,
	win_st_has_data: Array,
	face_center: Vector3,
	face_width: float,
	face_height: float,
	normal: Vector3,
	right: Vector3,
	rng: RandomNumberGenerator,
) -> void:
	var avail_w := face_width - HOUSE_WIN_MARGIN_X * 2.0
	var avail_h := face_height - HOUSE_WIN_MARGIN_BOT - HOUSE_WIN_MARGIN_TOP
	if avail_w < HOUSE_WIN_W or avail_h < HOUSE_WIN_H:
		return

	var cols := int(
		(avail_w + HOUSE_WIN_GAP_X) / (HOUSE_WIN_W + HOUSE_WIN_GAP_X)
	)
	if cols <= 0:
		return

	var offset := normal * 0.02
	var row_y := (
		face_center.y - face_height * 0.5
		+ HOUSE_WIN_MARGIN_BOT + HOUSE_WIN_H * 0.5
	)
	var total_w := cols * HOUSE_WIN_W + (cols - 1) * HOUSE_WIN_GAP_X
	var start_x := -total_w * 0.5 + HOUSE_WIN_W * 0.5
	var up := Vector3.UP

	for col in range(cols):
		var cx: float = start_x + col * (HOUSE_WIN_W + HOUSE_WIN_GAP_X)
		var wc := face_center + right * cx + offset
		wc.y = row_y
		var hw := HOUSE_WIN_W * 0.5
		var hh := HOUSE_WIN_H * 0.5
		var bl := wc - right * hw - up * hh
		var br := wc + right * hw - up * hh
		var tr := wc + right * hw + up * hh
		var tl := wc - right * hw + up * hh
		var wi: int = rng.randi() % win_count
		if not win_st_has_data[wi]:
			(win_sts[wi] as SurfaceTool).begin(Mesh.PRIMITIVE_TRIANGLES)
			win_st_has_data[wi] = true
		_city_script.st_add_quad(win_sts[wi], bl, br, tr, tl)


func _get_block_center(bx: int, bz: int) -> Vector2:
	var cx: float = (
		_grid.get_road_center_local(bx) + _grid.get_road_width(bx) * 0.5
		+ _grid.get_road_center_local(bx + 1)
		- _grid.get_road_width(bx + 1) * 0.5
	) * 0.5
	var cz: float = (
		_grid.get_road_center_local(bz) + _grid.get_road_width(bz) * 0.5
		+ _grid.get_road_center_local(bz + 1)
		- _grid.get_road_width(bz + 1) * 0.5
	) * 0.5
	return Vector2(cx, cz)
