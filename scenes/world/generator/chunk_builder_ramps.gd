extends RefCounted
## Builds a stunt park area with ramps in a fenced-off block.
## Only placed in ~10% of suburb tiles, occupying one city block.

const FENCE_HEIGHT := 1.5
const FENCE_THICKNESS := 0.15
const RAMP_HEIGHT := 0.8

var _grid: RefCounted
var _ramp_mat: StandardMaterial3D
var _fence_mat: StandardMaterial3D
var _city_script: GDScript = preload("res://scenes/world/city.gd")


func init(grid: RefCounted, ramp_mat: StandardMaterial3D) -> void:
	_grid = grid
	_ramp_mat = ramp_mat
	_fence_mat = StandardMaterial3D.new()
	_fence_mat.albedo_color = Color(0.5, 0.5, 0.5)


func build(chunk: Node3D, tile: Vector2i, ox: float, oz: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(tile) ^ 0xA44F

	# Only ~10% of calls produce a stunt park
	if rng.randf() > 0.1:
		return

	# Pick a random block (not on boundary roads)
	var block_x: int = rng.randi_range(1, _grid.GRID_SIZE - 2)
	var block_z: int = rng.randi_range(1, _grid.GRID_SIZE - 2)

	# Block center from road edges
	var rx0: float = _grid.get_road_center_local(block_x)
	var rx1: float = _grid.get_road_center_local(block_x + 1)
	var rz0: float = _grid.get_road_center_local(block_z)
	var rz1: float = _grid.get_road_center_local(block_z + 1)
	var rw0x: float = _grid.get_road_width(block_x) * 0.5
	var rw1x: float = _grid.get_road_width(block_x + 1) * 0.5
	var rw0z: float = _grid.get_road_width(block_z) * 0.5
	var rw1z: float = _grid.get_road_width(block_z + 1) * 0.5

	var x0: float = rx0 + rw0x + ox
	var x1: float = rx1 - rw1x + ox
	var z0: float = rz0 + rw0z + oz
	var z1: float = rz1 - rw1z + oz
	var cx: float = (x0 + x1) * 0.5
	var cz: float = (z0 + z1) * 0.5
	var bw: float = x1 - x0
	var bd: float = z1 - z0

	# Fence around the block
	var fence_body := StaticBody3D.new()
	fence_body.name = "StuntParkFence"
	fence_body.collision_layer = 2  # Static
	fence_body.collision_mask = 0

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var fence_y: float = FENCE_HEIGHT * 0.5

	# North fence
	var n_center := Vector3(cx, fence_y, z0)
	var n_size := Vector3(bw, FENCE_HEIGHT, FENCE_THICKNESS)
	_city_script.st_add_box(st, n_center, n_size)
	_city_script.add_box_collision(fence_body, n_center, n_size)
	# South fence
	var s_center := Vector3(cx, fence_y, z1)
	var s_size := Vector3(bw, FENCE_HEIGHT, FENCE_THICKNESS)
	_city_script.st_add_box(st, s_center, s_size)
	_city_script.add_box_collision(fence_body, s_center, s_size)
	# West fence
	var w_center := Vector3(x0, fence_y, cz)
	var w_size := Vector3(FENCE_THICKNESS, FENCE_HEIGHT, bd)
	_city_script.st_add_box(st, w_center, w_size)
	_city_script.add_box_collision(fence_body, w_center, w_size)

	# East fence (gap for entrance)
	var half_d: float = bd * 0.5 - 4.0
	if half_d > 1.0:
		var e_top_center := Vector3(x1, fence_y, z0 + half_d * 0.5)
		var e_bot_center := Vector3(x1, fence_y, z1 - half_d * 0.5)
		var e_size := Vector3(FENCE_THICKNESS, FENCE_HEIGHT, half_d)
		_city_script.st_add_box(st, e_top_center, e_size)
		_city_script.add_box_collision(fence_body, e_top_center, e_size)
		_city_script.st_add_box(st, e_bot_center, e_size)
		_city_script.add_box_collision(fence_body, e_bot_center, e_size)

	st.generate_normals()
	var fence_mesh := st.commit()
	var fence_inst := MeshInstance3D.new()
	fence_inst.name = "FenceMesh"
	fence_inst.mesh = fence_mesh
	fence_inst.material_override = _fence_mat
	fence_body.add_child(fence_inst)
	chunk.add_child(fence_body)

	# Ramps inside the block
	var margin := 4.0
	var inner_x0: float = x0 + margin
	var inner_x1: float = x1 - margin
	var inner_z0: float = z0 + margin
	var inner_z1: float = z1 - margin

	var ramp_count: int = rng.randi_range(3, 6)
	for i in range(ramp_count):
		var rx: float = rng.randf_range(inner_x0, inner_x1)
		var rz: float = rng.randf_range(inner_z0, inner_z1)
		var rot_y: float = rng.randf_range(0.0, TAU)
		var ramp_w: float = rng.randf_range(3.0, 5.0)
		var ramp_d: float = rng.randf_range(5.0, 8.0)
		var ramp_h: float = rng.randf_range(0.4, RAMP_HEIGHT)

		var body := StaticBody3D.new()
		body.name = "Ramp_%d" % i
		body.position = Vector3(rx, ramp_h * 0.5, rz)
		body.rotation.y = rot_y
		body.collision_layer = 1
		body.collision_mask = 0
		body.add_to_group("Road")

		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(ramp_w, ramp_h, ramp_d)
		col.shape = shape
		col.rotation.x = deg_to_rad(-15.0)
		body.add_child(col)

		var mesh_inst := MeshInstance3D.new()
		var box_mesh := BoxMesh.new()
		box_mesh.size = Vector3(ramp_w, ramp_h, ramp_d)
		box_mesh.material = _ramp_mat
		mesh_inst.rotation.x = deg_to_rad(-15.0)
		mesh_inst.mesh = box_mesh
		body.add_child(mesh_inst)

		chunk.add_child(body)

	chunk.set_meta("has_stunt_park", true)
	(
		chunk
		. set_meta(
			"stunt_park_center",
			Vector2(cx, cz),
		)
	)
