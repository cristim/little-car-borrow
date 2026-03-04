extends Node3D
## Generates default sedan body + window meshes at _ready() if CarBody has no mesh.
## Traffic manager overwrites these with variant-specific meshes for NPC vehicles.

const GLASS_COLOR := Color(0.6, 0.75, 0.85, 0.4)
const BODY_COLOR := Color(0.8, 0.2, 0.2, 1)

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
	glass_mat.albedo_color = GLASS_COLOR

	var windows: Dictionary = _builder.build_windows("sedan")
	for window_name in windows:
		var node := get_node_or_null(window_name) as MeshInstance3D
		if node:
			node.mesh = windows[window_name]
			node.material_override = glass_mat
