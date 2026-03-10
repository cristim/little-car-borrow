extends RefCounted
## Builds mountain overlay: rock formations on steep/high terrain areas.

var _grid: RefCounted
var _boundary: RefCounted
var _rock_mat: StandardMaterial3D
var _city_script: GDScript = preload("res://scenes/world/city.gd")


func init(grid: RefCounted, boundary: RefCounted) -> void:
	_grid = grid
	_boundary = boundary
	_rock_mat = StandardMaterial3D.new()
	_rock_mat.albedo_color = Color(0.50, 0.48, 0.44)
	_rock_mat.roughness = 0.95


func build(
	chunk: Node3D, tile: Vector2i, ox: float, oz: float,
) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(tile) ^ 0x12CC
	var span: float = _grid.get_grid_span()

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var has_rocks := false

	var count := rng.randi_range(5, 15)
	for _r in range(count):
		var rx: float = ox + rng.randf_range(-span * 0.45, span * 0.45)
		var rz: float = oz + rng.randf_range(-span * 0.45, span * 0.45)
		var h: float = _boundary.get_ground_height(rx, rz)

		# Only place rocks on elevated terrain
		if h < 15.0:
			continue

		var rw: float = rng.randf_range(2.0, 8.0)
		var rh: float = rng.randf_range(1.5, 6.0)
		var rd: float = rng.randf_range(2.0, 8.0)

		var center := Vector3(rx, h + rh * 0.5, rz)
		# Slight random rotation by skewing the box
		_city_script.st_add_box(
			st, center, Vector3(rw, rh, rd),
		)
		has_rocks = true

	if not has_rocks:
		return

	st.generate_normals()
	var mesh := st.commit()
	var inst := MeshInstance3D.new()
	inst.name = "Rocks"
	inst.mesh = mesh
	inst.material_override = _rock_mat
	chunk.add_child(inst)

	# Collision for rocks
	var body := StaticBody3D.new()
	body.name = "RockBodies"
	body.collision_layer = 2
	body.collision_mask = 0
	body.add_to_group("Static")

	# Re-seed for deterministic collision placement
	rng.seed = hash(tile) ^ 0x12CC
	for _r in range(count):
		var rx: float = ox + rng.randf_range(-span * 0.45, span * 0.45)
		var rz: float = oz + rng.randf_range(-span * 0.45, span * 0.45)
		var h: float = _boundary.get_ground_height(rx, rz)
		if h < 15.0:
			rng.randf_range(2.0, 8.0)
			rng.randf_range(1.5, 6.0)
			rng.randf_range(2.0, 8.0)
			continue
		var rw: float = rng.randf_range(2.0, 8.0)
		var rh: float = rng.randf_range(1.5, 6.0)
		var rd: float = rng.randf_range(2.0, 8.0)
		var center := Vector3(rx, h + rh * 0.5, rz)
		_city_script.add_box_collision(
			body, center, Vector3(rw, rh, rd),
		)

	chunk.add_child(body)
