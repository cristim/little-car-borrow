extends RefCounted
## Builds farmland overlay: field patches, fences, and occasional farmhouses.

const FIELD_COLORS: Array[Color] = [
	Color(0.35, 0.50, 0.15),  # green crop
	Color(0.70, 0.60, 0.25),  # golden wheat
	Color(0.45, 0.35, 0.20),  # brown plowed
	Color(0.30, 0.55, 0.20),  # dark green
]
const FENCE_HEIGHT := 1.2
const FENCE_THICKNESS := 0.08

var _grid: RefCounted
var _boundary: RefCounted
var _fence_mat: StandardMaterial3D
var _field_mat: StandardMaterial3D
var _city_script: GDScript = preload("res://scenes/world/city.gd")


func init(
	grid: RefCounted,
	boundary: RefCounted,
) -> void:
	_grid = grid
	_boundary = boundary
	_fence_mat = StandardMaterial3D.new()
	_fence_mat.albedo_color = Color(0.40, 0.28, 0.15)
	_field_mat = StandardMaterial3D.new()
	_field_mat.vertex_color_use_as_albedo = true
	_field_mat.cull_mode = BaseMaterial3D.CULL_DISABLED


func build(
	chunk: Node3D,
	tile: Vector2i,
	ox: float,
	oz: float,
) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(tile) ^ 0xFA12
	var span: float = _grid.get_grid_span()

	# Field patches as colored ground quads
	var field_st := SurfaceTool.new()
	field_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var has_fields := false

	# Fence geometry + collision body
	var fence_st := SurfaceTool.new()
	fence_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var has_fences := false
	var fence_body := StaticBody3D.new()
	fence_body.name = "Fences"
	fence_body.collision_layer = 2  # Static
	fence_body.collision_mask = 0

	var field_count := rng.randi_range(3, 7)
	for _f in range(field_count):
		var fx: float = ox + rng.randf_range(-span * 0.4, span * 0.4)
		var fz: float = oz + rng.randf_range(-span * 0.4, span * 0.4)
		var fw: float = rng.randf_range(30.0, 80.0)
		var fd: float = rng.randf_range(30.0, 80.0)
		var h: float = _boundary.get_ground_height(fx, fz)

		if h < 0.5:
			continue

		var color: Color = FIELD_COLORS[rng.randi() % FIELD_COLORS.size()]
		var y: float = h + 0.1

		# Field quad
		field_st.set_color(color)
		var v0 := Vector3(fx - fw * 0.5, y, fz - fd * 0.5)
		var v1 := Vector3(fx + fw * 0.5, y, fz - fd * 0.5)
		var v2 := Vector3(fx + fw * 0.5, y, fz + fd * 0.5)
		var v3 := Vector3(fx - fw * 0.5, y, fz + fd * 0.5)
		field_st.add_vertex(v0)
		field_st.add_vertex(v3)
		field_st.add_vertex(v1)
		field_st.add_vertex(v1)
		field_st.add_vertex(v3)
		field_st.add_vertex(v2)
		has_fields = true

		# Fence along field borders (mesh + collision)
		if rng.randf() < 0.6:
			var fy: float = y + FENCE_HEIGHT * 0.5
			# North fence
			var n_center := Vector3(fx, fy, fz - fd * 0.5)
			var n_size := Vector3(fw, FENCE_HEIGHT, FENCE_THICKNESS)
			_city_script.st_add_box(fence_st, n_center, n_size)
			_city_script.add_box_collision(fence_body, n_center, n_size)
			# South fence
			var s_center := Vector3(fx, fy, fz + fd * 0.5)
			var s_size := Vector3(fw, FENCE_HEIGHT, FENCE_THICKNESS)
			_city_script.st_add_box(fence_st, s_center, s_size)
			_city_script.add_box_collision(fence_body, s_center, s_size)
			# West fence
			var w_center := Vector3(fx - fw * 0.5, fy, fz)
			var w_size := Vector3(FENCE_THICKNESS, FENCE_HEIGHT, fd)
			_city_script.st_add_box(fence_st, w_center, w_size)
			_city_script.add_box_collision(fence_body, w_center, w_size)
			# East fence
			var e_center := Vector3(fx + fw * 0.5, fy, fz)
			var e_size := Vector3(FENCE_THICKNESS, FENCE_HEIGHT, fd)
			_city_script.st_add_box(fence_st, e_center, e_size)
			_city_script.add_box_collision(fence_body, e_center, e_size)
			has_fences = true

	if has_fields:
		field_st.generate_normals()
		var mesh := field_st.commit()
		var inst := MeshInstance3D.new()
		inst.name = "Fields"
		inst.mesh = mesh
		inst.material_override = _field_mat
		chunk.add_child(inst)

	if has_fences:
		fence_st.generate_normals()
		var mesh := fence_st.commit()
		var fence_inst := MeshInstance3D.new()
		fence_inst.name = "FenceMesh"
		fence_inst.mesh = mesh
		fence_inst.material_override = _fence_mat
		fence_body.add_child(fence_inst)
		chunk.add_child(fence_body)
