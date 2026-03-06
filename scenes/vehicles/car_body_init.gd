extends Node3D
## Generates default sedan body + window meshes at _ready() if CarBody has no mesh.
## Traffic manager overwrites these with variant-specific meshes for NPC vehicles.

const GLASS_COLOR := Color(0.6, 0.75, 0.85, 0.4)
const BODY_COLOR := Color(0.8, 0.2, 0.2, 1)
const INTERIOR_COLOR := Color(0.12, 0.12, 0.12, 1)

var _builder = preload("res://scenes/vehicles/car_body_builder.gd").new()


func _ready() -> void:
	var car_body := get_node_or_null("CarBody") as MeshInstance3D
	if not car_body or car_body.mesh:
		return

	# Generate sedan body mesh
	car_body.mesh = _builder.build_body("sedan")

	# Apply default body material
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = BODY_COLOR
	car_body.material_override = body_mat

	# Generate and assign window meshes
	var glass_mat := StandardMaterial3D.new()
	glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	glass_mat.albedo_color = GLASS_COLOR

	var windows: Dictionary = _builder.build_windows("sedan")
	for window_name in windows:
		var node := get_node_or_null(window_name) as MeshInstance3D
		if node:
			node.mesh = windows[window_name]
			node.material_override = glass_mat

	# Generate and assign interior mesh
	var interior_mesh: ArrayMesh = _builder.build_interior("sedan")
	if interior_mesh.get_surface_count() > 0:
		var interior := MeshInstance3D.new()
		interior.name = "Interior"
		interior.mesh = interior_mesh
		var int_mat := StandardMaterial3D.new()
		int_mat.albedo_color = INTERIOR_COLOR
		int_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		interior.material_override = int_mat
		car_body.add_child(interior)

	# Generate and assign detail mesh (grille, license plates)
	var detail_mesh: ArrayMesh = _builder.build_details("sedan")
	if detail_mesh.get_surface_count() > 0:
		var details := MeshInstance3D.new()
		details.name = "Details"
		details.mesh = detail_mesh
		var det_mat := StandardMaterial3D.new()
		det_mat.albedo_color = Color(0.15, 0.15, 0.15, 1.0)
		det_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		details.material_override = det_mat
		car_body.add_child(details)

	# Generate and assign undercarriage floor
	var floor_mesh: ArrayMesh = _builder.build_floor("sedan")
	if floor_mesh.get_surface_count() > 0:
		var floor_node := MeshInstance3D.new()
		floor_node.name = "Floor"
		floor_node.mesh = floor_mesh
		floor_node.material_override = body_mat
		car_body.add_child(floor_node)

	# Generate and assign door meshes to pivots
	var int_mat := StandardMaterial3D.new()
	int_mat.albedo_color = INTERIOR_COLOR
	var doors: Dictionary = _builder.build_doors("sedan")
	if doors.size() > 0:
		_setup_door_pivot(
			"LeftDoorPivot", doors, "LeftDoor", "LeftDoorInner",
			"LeftDoorWindow", "left_pivot", body_mat, int_mat, glass_mat,
		)
		_setup_door_pivot(
			"RightDoorPivot", doors, "RightDoor", "RightDoorInner",
			"RightDoorWindow", "right_pivot", body_mat, int_mat, glass_mat,
		)


func _setup_door_pivot(
	pivot_name: String,
	doors: Dictionary,
	body_key: String,
	inner_key: String,
	window_key: String,
	pivot_key: String,
	body_mat: StandardMaterial3D,
	inner_mat: StandardMaterial3D,
	glass_mat: StandardMaterial3D,
) -> void:
	var pivot := get_node_or_null(pivot_name) as Node3D
	if not pivot:
		return
	pivot.position = doors[pivot_key]
	var door_mi := MeshInstance3D.new()
	door_mi.name = body_key
	door_mi.mesh = doors[body_key]
	door_mi.material_override = body_mat
	pivot.add_child(door_mi)
	var inner_mi := MeshInstance3D.new()
	inner_mi.name = inner_key
	inner_mi.mesh = doors[inner_key]
	inner_mi.material_override = inner_mat
	pivot.add_child(inner_mi)
	var win_mi := MeshInstance3D.new()
	win_mi.name = window_key
	win_mi.mesh = doors[window_key]
	win_mi.material_override = glass_mat
	pivot.add_child(win_mi)
