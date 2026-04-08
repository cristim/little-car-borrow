extends "res://src/character_model_base.gd"
## Greybox pedestrian visual: multi-part humanoid with randomized appearance,
## face details, and a walk animation driven by the shared character model base.

# ---- Appearance palettes ----

const SHIRT_COLORS: Array[Color] = [
	Color(0.3, 0.5, 0.7),
	Color(0.7, 0.3, 0.3),
	Color(0.3, 0.7, 0.4),
	Color(0.6, 0.5, 0.2),
	Color(0.5, 0.3, 0.6),
	Color(0.8, 0.6, 0.3),
	Color(0.2, 0.6, 0.6),
	Color(0.7, 0.7, 0.3),
	Color(0.85, 0.85, 0.85),
	Color(0.15, 0.15, 0.15),
]

const PANT_COLORS: Array[Color] = [
	Color(0.15, 0.20, 0.35),
	Color(0.35, 0.30, 0.22),
	Color(0.12, 0.12, 0.12),
	Color(0.45, 0.35, 0.25),
	Color(0.50, 0.50, 0.50),
	Color(0.30, 0.45, 0.25),
]

const SKIN_COLORS: Array[Color] = [
	Color(0.87, 0.72, 0.58),
	Color(0.72, 0.55, 0.40),
	Color(0.55, 0.38, 0.26),
	Color(0.40, 0.28, 0.18),
]

const HAIR_COLORS: Array[Color] = [
	Color(0.10, 0.07, 0.04),
	Color(0.22, 0.14, 0.07),
	Color(0.45, 0.28, 0.12),
	Color(0.65, 0.45, 0.18),
	Color(0.80, 0.65, 0.30),
	Color(0.55, 0.20, 0.08),
	Color(0.65, 0.65, 0.65),
	Color(0.90, 0.90, 0.90),
]

const EYE_COLORS: Array[Color] = [
	Color(0.12, 0.08, 0.05),
	Color(0.22, 0.18, 0.08),
	Color(0.15, 0.22, 0.18),
	Color(0.18, 0.22, 0.30),
]

const WALK_ELBOW_BASE := -0.5  # base elbow fold when walking (~29°)
const WALK_ELBOW_DYN := 0.15  # extra fold on forward shoulder swing

var _rng := RandomNumberGenerator.new()
var _left_elbow: Node3D
var _right_elbow: Node3D


func _ready() -> void:
	_rng.randomize()

	var shirt_col := SHIRT_COLORS[_rng.randi() % SHIRT_COLORS.size()]
	var pant_col := PANT_COLORS[_rng.randi() % PANT_COLORS.size()]
	var skin_col := SKIN_COLORS[_rng.randi() % SKIN_COLORS.size()]
	var hair_col := HAIR_COLORS[_rng.randi() % HAIR_COLORS.size()]
	var eye_col := EYE_COLORS[_rng.randi() % EYE_COLORS.size()]

	# Uniform scale: 87%–113% for height/build variation
	var s: float = _rng.randf_range(0.87, 1.13)
	scale = Vector3(s, s, s)

	var shirt_mat := StandardMaterial3D.new()
	shirt_mat.albedo_color = shirt_col

	var pant_mat := StandardMaterial3D.new()
	pant_mat.albedo_color = pant_col

	var skin_mat := StandardMaterial3D.new()
	skin_mat.albedo_color = skin_col

	var hair_mat := StandardMaterial3D.new()
	hair_mat.albedo_color = hair_col

	var eye_mat := StandardMaterial3D.new()
	eye_mat.albedo_color = eye_col

	var brow_mat := StandardMaterial3D.new()
	brow_mat.albedo_color = hair_col.darkened(0.15)

	var mouth_mat := StandardMaterial3D.new()
	mouth_mat.albedo_color = Color(0.60, 0.28, 0.26)

	# --- Torso (child 0) ---
	var torso_mesh := BoxMesh.new()
	torso_mesh.size = Vector3(0.35, 0.5, 0.2)
	var torso := MeshInstance3D.new()
	torso.mesh = torso_mesh
	torso.material_override = shirt_mat
	torso.position = Vector3(0.0, 1.0, 0.0)
	add_child(torso)

	# --- Head pivot (child 1): Node3D hosting head mesh + face detail boxes ---
	# Head half-extents: ±0.11 X, ±0.11 Y, ±0.11 Z; front face at Z = +0.11
	var head_pivot := Node3D.new()
	head_pivot.name = "HeadPivot"
	head_pivot.position = Vector3(0.0, 1.36, 0.0)
	add_child(head_pivot)
	_head = head_pivot  # base class var — used for walk stabilization
	var head_mesh := BoxMesh.new()
	head_mesh.size = Vector3(0.22, 0.22, 0.22)
	var head_mi := MeshInstance3D.new()
	head_mi.name = "HeadBase"
	head_mi.mesh = head_mesh
	head_mi.material_override = skin_mat
	head_pivot.add_child(head_mi)
	_build_face(head_pivot, eye_mat, brow_mat, skin_mat, mouth_mat, hair_mat)

	# --- Hip pivots / legs (children 2, 3) ---
	# Pivot at hip level (y=0.75); leg hangs to ground (centre at y=-0.375)
	var leg_mesh := CylinderMesh.new()
	leg_mesh.top_radius = 0.08
	leg_mesh.bottom_radius = 0.08
	leg_mesh.height = 0.75

	var left_hip := Node3D.new()
	left_hip.name = "LeftHipPivot"
	left_hip.position = Vector3(-0.10, 0.75, 0.0)
	add_child(left_hip)
	_left_hip = left_hip  # base class var
	var left_leg := MeshInstance3D.new()
	left_leg.name = "LeftLeg"
	left_leg.mesh = leg_mesh
	left_leg.material_override = pant_mat
	left_leg.position = Vector3(0.0, -0.375, 0.0)
	left_hip.add_child(left_leg)

	var right_hip := Node3D.new()
	right_hip.name = "RightHipPivot"
	right_hip.position = Vector3(0.10, 0.75, 0.0)
	add_child(right_hip)
	_right_hip = right_hip  # base class var
	var right_leg := MeshInstance3D.new()
	right_leg.name = "RightLeg"
	right_leg.mesh = leg_mesh
	right_leg.material_override = pant_mat
	right_leg.position = Vector3(0.0, -0.375, 0.0)
	right_hip.add_child(right_leg)

	# --- Shoulder pivots / arms (children 4, 5) ---
	# Each arm is split: upper arm (shoulder→elbow) + ElbowPivot + forearm.
	# Total reach: 0.27 (upper) + 0.28 (forearm) = 0.55 m, same as before.
	var upper_arm_mesh := CylinderMesh.new()
	upper_arm_mesh.top_radius = 0.06
	upper_arm_mesh.bottom_radius = 0.055
	upper_arm_mesh.height = 0.27

	var forearm_mesh := CylinderMesh.new()
	forearm_mesh.top_radius = 0.055
	forearm_mesh.bottom_radius = 0.05
	forearm_mesh.height = 0.28

	var left_shoulder := Node3D.new()
	left_shoulder.name = "LeftShoulderPivot"
	left_shoulder.position = Vector3(-0.24, 1.25, 0.0)
	add_child(left_shoulder)
	_left_shoulder = left_shoulder  # base class var
	var left_upper_arm := MeshInstance3D.new()
	left_upper_arm.name = "LeftArm"
	left_upper_arm.mesh = upper_arm_mesh
	left_upper_arm.material_override = shirt_mat
	left_upper_arm.position = Vector3(0.0, -0.135, 0.0)
	left_shoulder.add_child(left_upper_arm)
	var left_elbow_pivot := Node3D.new()
	left_elbow_pivot.name = "LeftElbowPivot"
	left_elbow_pivot.position = Vector3(0.0, -0.27, 0.0)
	left_shoulder.add_child(left_elbow_pivot)
	_left_elbow = left_elbow_pivot
	var left_forearm := MeshInstance3D.new()
	left_forearm.name = "LeftForearm"
	left_forearm.mesh = forearm_mesh
	left_forearm.material_override = shirt_mat
	left_forearm.position = Vector3(0.0, -0.14, 0.0)
	left_elbow_pivot.add_child(left_forearm)

	var right_shoulder := Node3D.new()
	right_shoulder.name = "RightShoulderPivot"
	right_shoulder.position = Vector3(0.24, 1.25, 0.0)
	add_child(right_shoulder)
	_right_shoulder = right_shoulder  # base class var
	var right_upper_arm := MeshInstance3D.new()
	right_upper_arm.name = "RightArm"
	right_upper_arm.mesh = upper_arm_mesh
	right_upper_arm.material_override = shirt_mat
	right_upper_arm.position = Vector3(0.0, -0.135, 0.0)
	right_shoulder.add_child(right_upper_arm)
	var right_elbow_pivot := Node3D.new()
	right_elbow_pivot.name = "RightElbowPivot"
	right_elbow_pivot.position = Vector3(0.0, -0.27, 0.0)
	right_shoulder.add_child(right_elbow_pivot)
	_right_elbow = right_elbow_pivot
	var right_forearm := MeshInstance3D.new()
	right_forearm.name = "RightForearm"
	right_forearm.mesh = forearm_mesh
	right_forearm.material_override = shirt_mat
	right_forearm.position = Vector3(0.0, -0.14, 0.0)
	right_elbow_pivot.add_child(right_forearm)


## Add face detail boxes as children of head_pivot.
## Coordinates are relative to the head centre (half-extents ±0.11).
func _build_face(
	head: Node3D,
	eye_mat: StandardMaterial3D,
	brow_mat: StandardMaterial3D,
	skin_mat: StandardMaterial3D,
	mouth_mat: StandardMaterial3D,
	hair_mat: StandardMaterial3D,
) -> void:
	# Eyes
	_add_box(head, "EyeLeft", eye_mat, Vector3(0.040, 0.022, 0.008), Vector3(0.044, 0.024, 0.113))
	_add_box(head, "EyeRight", eye_mat, Vector3(0.040, 0.022, 0.008), Vector3(-0.044, 0.024, 0.113))
	# Eyebrows
	_add_box(head, "BrowLeft", brow_mat, Vector3(0.045, 0.010, 0.006), Vector3(0.043, 0.055, 0.111))
	_add_box(
		head, "BrowRight", brow_mat, Vector3(0.045, 0.010, 0.006), Vector3(-0.043, 0.055, 0.111)
	)
	# Nose (protrudes from mid-face)
	_add_box(head, "Nose", skin_mat, Vector3(0.024, 0.033, 0.020), Vector3(0.0, -0.008, 0.119))
	# Mouth
	_add_box(head, "Mouth", mouth_mat, Vector3(0.052, 0.011, 0.006), Vector3(0.0, -0.051, 0.111))
	# Ears
	_add_box(head, "EarLeft", skin_mat, Vector3(0.016, 0.049, 0.033), Vector3(0.118, 0.000, 0.004))
	_add_box(
		head, "EarRight", skin_mat, Vector3(0.016, 0.049, 0.033), Vector3(-0.118, 0.000, 0.004)
	)
	# Hair cap
	_add_box(head, "HairTop", hair_mat, Vector3(0.230, 0.045, 0.200), Vector3(0.0, 0.124, 0.002))
	_add_box(
		head, "HairSideLeft", hair_mat, Vector3(0.024, 0.090, 0.175), Vector3(0.122, 0.073, 0.003)
	)
	_add_box(
		head, "HairSideRight", hair_mat, Vector3(0.024, 0.090, 0.175), Vector3(-0.122, 0.073, 0.003)
	)
	_add_box(head, "HairBack", hair_mat, Vector3(0.200, 0.057, 0.026), Vector3(0.0, 0.067, -0.115))


## Helper: create a MeshInstance3D with a BoxMesh attached to parent.
func _add_box(
	parent: Node3D,
	part_name: String,
	mat: StandardMaterial3D,
	size: Vector3,
	pos: Vector3,
) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.name = part_name
	mi.mesh = mesh
	mi.position = pos
	parent.add_child(mi)
	return mi


## Walk animation — driven by parent CharacterBody3D velocity each frame.
## Uses pure walk blend (t = 0) from the shared character_model_base gait.
func _process(delta: float) -> void:
	if not _left_shoulder:
		return
	var parent := get_parent()
	if not parent:
		return

	var vel: Vector3 = parent.velocity if "velocity" in parent else Vector3.ZERO
	var h_speed := Vector2(vel.x, vel.z).length()

	if h_speed > 0.5:
		_animate_gait(delta, h_speed, 0.0)
		# Elbow bend: base fold + extra when arm swings forward
		_left_elbow.rotation.x = (
			WALK_ELBOW_BASE + maxf(0.0, _left_shoulder.rotation.x) * WALK_ELBOW_DYN
		)
		_right_elbow.rotation.x = (
			WALK_ELBOW_BASE + maxf(0.0, _right_shoulder.rotation.x) * WALK_ELBOW_DYN
		)
	else:
		_decay_gait(delta)
		_left_elbow.rotation.x = lerpf(_left_elbow.rotation.x, 0.0, delta * DECAY_SPEED)
		_right_elbow.rotation.x = lerpf(_right_elbow.rotation.x, 0.0, delta * DECAY_SPEED)
