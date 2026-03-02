extends Node3D
## Greybox pedestrian visual: capsule body + box head with random color.

const SKIN_COLORS: Array[Color] = [
	Color(0.3, 0.5, 0.7),
	Color(0.7, 0.3, 0.3),
	Color(0.3, 0.7, 0.4),
	Color(0.6, 0.5, 0.2),
	Color(0.5, 0.3, 0.6),
	Color(0.8, 0.6, 0.3),
	Color(0.2, 0.6, 0.6),
	Color(0.7, 0.7, 0.3),
]

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	var color := SKIN_COLORS[_rng.randi() % SKIN_COLORS.size()]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color

	# Capsule body (height ~1.4m, radius 0.2m)
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.2
	body_mesh.height = 1.4
	var body_inst := MeshInstance3D.new()
	body_inst.mesh = body_mesh
	body_inst.material_override = mat
	body_inst.position = Vector3(0.0, 0.7, 0.0)
	add_child(body_inst)

	# Box head (0.25m cube)
	var head_mesh := BoxMesh.new()
	head_mesh.size = Vector3(0.25, 0.25, 0.25)
	var head_inst := MeshInstance3D.new()
	head_inst.mesh = head_mesh
	head_inst.material_override = mat
	head_inst.position = Vector3(0.0, 1.525, 0.0)
	add_child(head_inst)
