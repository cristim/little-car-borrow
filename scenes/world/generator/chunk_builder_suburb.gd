extends RefCounted
## Builds suburb chunks: road grid with lower density buildings, yards,
## and more green space. Uses same road grid as city but fewer/shorter buildings.

const MAX_BUILDINGS_PER_BLOCK := 2
const MIN_HEIGHT := 3.0
const MAX_HEIGHT := 8.0

var _grid: RefCounted
var _building_mats: Array[StandardMaterial3D] = []
var _roof_mats: Array[StandardMaterial3D] = []
var _bld_builder: RefCounted  # chunk_builder_buildings.gd for roof helpers
var _city_script: GDScript = preload("res://scenes/world/city.gd")


func init(
	grid: RefCounted,
	building_mats: Array[StandardMaterial3D],
	roof_mats: Array[StandardMaterial3D],
	bld_builder: RefCounted,
) -> void:
	_grid = grid
	_building_mats = building_mats
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

	var roof_count := _roof_mats.size()
	var roof_sts: Array[SurfaceTool] = []
	var roof_st_used: Array[bool] = []
	for _i in range(roof_count):
		var rst := SurfaceTool.new()
		rst.begin(Mesh.PRIMITIVE_TRIANGLES)
		roof_sts.append(rst)
		roof_st_used.append(false)

	var body := StaticBody3D.new()
	body.name = "SuburbBuildings"
	body.collision_layer = 2
	body.collision_mask = 0
	body.add_to_group("Static")

	var any_placed := false

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

				_city_script.st_add_box_no_bottom(
					sts[mi], center, size,
				)
				st_used[mi] = true
				_city_script.add_box_collision(body, center, size)
				any_placed = true

				# All suburb buildings get pitched roofs
				if roof_count > 0 and _bld_builder:
					var ri := rng.randi() % roof_count
					_bld_builder._st_add_pitched_roof(
						roof_sts[ri], center, size, rng,
					)
					roof_st_used[ri] = true

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

	chunk.add_child(body)


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
