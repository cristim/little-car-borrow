extends Node3D
## Greybox pedestrian visual: multi-part humanoid with random color.

const CLOTHING_COLORS: Array[Color] = [
	Color(0.3, 0.5, 0.7),
	Color(0.7, 0.3, 0.3),
	Color(0.3, 0.7, 0.4),
	Color(0.6, 0.5, 0.2),
	Color(0.5, 0.3, 0.6),
	Color(0.8, 0.6, 0.3),
	Color(0.2, 0.6, 0.6),
	Color(0.7, 0.7, 0.3),
]

const SKIN_COLORS: Array[Color] = [
	Color(0.87, 0.72, 0.58),
	Color(0.72, 0.55, 0.40),
	Color(0.55, 0.38, 0.26),
	Color(0.40, 0.28, 0.18),
]

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	var clothing := CLOTHING_COLORS[_rng.randi() % CLOTHING_COLORS.size()]
	var skin := SKIN_COLORS[_rng.randi() % SKIN_COLORS.size()]

	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = clothing

	var skin_mat := StandardMaterial3D.new()
	skin_mat.albedo_color = skin

	# Torso (0.35 x 0.5 x 0.2) — center at y=1.0 (legs end at 0.75, torso spans 0.75-1.25)
	var torso_mesh := BoxMesh.new()
	torso_mesh.size = Vector3(0.35, 0.5, 0.2)
	var torso := MeshInstance3D.new()
	torso.mesh = torso_mesh
	torso.material_override = body_mat
	torso.position = Vector3(0.0, 1.0, 0.0)
	add_child(torso)

	# Head (0.22 x 0.22 x 0.22) — sits on top of torso
	var head_mesh := BoxMesh.new()
	head_mesh.size = Vector3(0.22, 0.22, 0.22)
	var head := MeshInstance3D.new()
	head.mesh = head_mesh
	head.material_override = skin_mat
	head.position = Vector3(0.0, 1.36, 0.0)
	add_child(head)

	# Left leg (cylinder radius 0.08, height 0.75) — center at y=0.375
	var leg_mesh := CylinderMesh.new()
	leg_mesh.top_radius = 0.08
	leg_mesh.bottom_radius = 0.08
	leg_mesh.height = 0.75
	var left_leg := MeshInstance3D.new()
	left_leg.mesh = leg_mesh
	left_leg.material_override = body_mat
	left_leg.position = Vector3(-0.1, 0.375, 0.0)
	add_child(left_leg)

	# Right leg
	var right_leg := MeshInstance3D.new()
	right_leg.mesh = leg_mesh
	right_leg.material_override = body_mat
	right_leg.position = Vector3(0.1, 0.375, 0.0)
	add_child(right_leg)

	# Left arm (cylinder radius 0.06, height 0.55) — hangs from shoulder
	var arm_mesh := CylinderMesh.new()
	arm_mesh.top_radius = 0.06
	arm_mesh.bottom_radius = 0.06
	arm_mesh.height = 0.55
	var left_arm := MeshInstance3D.new()
	left_arm.mesh = arm_mesh
	left_arm.material_override = skin_mat
	left_arm.position = Vector3(-0.24, 0.97, 0.0)
	add_child(left_arm)

	# Right arm
	var right_arm := MeshInstance3D.new()
	right_arm.mesh = arm_mesh
	right_arm.material_override = skin_mat
	right_arm.position = Vector3(0.24, 0.97, 0.0)
	add_child(right_arm)
