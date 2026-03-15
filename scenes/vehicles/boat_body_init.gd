extends Node3D
## Initializes boat body meshes on _ready() if Hull child has no mesh.
## Applies hull and cabin materials.

var variant := "speedboat"

var _hull_mat: StandardMaterial3D
var _cabin_mat: StandardMaterial3D
var _glass_mat: StandardMaterial3D


func _ready() -> void:
	_init_materials()

	var hull := get_node_or_null("Hull") as MeshInstance3D
	if hull and not hull.mesh:
		var builder = preload(
			"res://scenes/vehicles/boat_body_builder.gd"
		).new()
		var result: Dictionary = builder.build(variant)
		hull.mesh = result["hull"]
		hull.material_override = _hull_mat

		var cabin := get_node_or_null("Cabin") as MeshInstance3D
		if cabin:
			cabin.mesh = result["cabin"]
			cabin.material_override = _cabin_mat

		var windshield := get_node_or_null("Windshield") as MeshInstance3D
		if windshield:
			windshield.mesh = result["windshield"]
			windshield.material_override = _glass_mat


func _init_materials() -> void:
	_hull_mat = StandardMaterial3D.new()
	_hull_mat.albedo_color = Color(0.90, 0.92, 0.95)
	_hull_mat.roughness = 0.4

	_cabin_mat = StandardMaterial3D.new()
	_cabin_mat.albedo_color = Color(0.85, 0.87, 0.90)
	_cabin_mat.roughness = 0.5

	_glass_mat = StandardMaterial3D.new()
	_glass_mat.albedo_color = Color(0.2, 0.3, 0.4, 0.4)
	_glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glass_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
