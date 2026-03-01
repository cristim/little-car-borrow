extends RefCounted
## Builds merged building meshes grouped by material palette index.
## Up to 12 MeshInstance3D + 1 compound StaticBody3D per chunk.

var _grid: RefCounted
var _building_mats: Array[StandardMaterial3D] = []
var _window_mat: StandardMaterial3D
var _city_script: GDScript = preload("res://scenes/world/city.gd")


func init(
	grid: RefCounted,
	building_mats: Array[StandardMaterial3D],
	window_mat: StandardMaterial3D,
) -> void:
	_grid = grid
	_building_mats = building_mats
	_window_mat = window_mat


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

	# Separate SurfaceTool for all window quads
	var win_st := SurfaceTool.new()
	win_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var has_windows := false

	# Single compound collision body for all buildings
	var body := StaticBody3D.new()
	body.name = "Buildings"
	body.collision_layer = 2
	body.collision_mask = 0
	body.add_to_group("Static")

	for bx in range(_grid.GRID_SIZE):
		for bz in range(_grid.GRID_SIZE):
			var block_center := _get_block_center_local(bx, bz)
			var count := rng.randi_range(1, 4)
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
				var max_off_x := maxf((block_size - bw) * 0.5 - margin, 0.0)
				var max_off_z := maxf((block_size - bd) * 0.5 - margin, 0.0)
				var bx_off := rng.randf_range(-max_off_x, max_off_x)
				var bz_off := rng.randf_range(-max_off_z, max_off_z)

				var mat_idx := rng.randi() % mat_count
				var center := Vector3(
					block_center.x + bx_off + ox,
					bh * 0.5,
					block_center.y + bz_off + oz,
				)
				var size := Vector3(bw, bh, bd)

				# No bottom face — sits on ground without z-fighting
				_city_script.st_add_box_no_bottom(sts[mat_idx], center, size)
				st_used[mat_idx] = true
				_city_script.add_box_collision(body, center, size)

				# Add windows on buildings taller than 6m
				if bh > 6.0:
					has_windows = true
					_add_building_windows(win_st, center, size, rng)

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

	# Single MeshInstance3D for all window quads
	if has_windows:
		win_st.generate_normals()
		var win_mesh := win_st.commit()
		var win_inst := MeshInstance3D.new()
		win_inst.name = "Windows"
		win_inst.mesh = win_mesh
		win_inst.material_override = _window_mat
		body.add_child(win_inst)

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
