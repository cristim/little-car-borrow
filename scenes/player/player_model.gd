extends "res://src/character_model_base.gd"
## Procedural walk/run/swim animation for the articulated player model.
## Reads velocity from the parent CharacterBody3D to drive limb swing.
## Shared walk/run constants and _animate_gait/_decay_gait live in the base class.

const SWIM_DECAY_SPEED := 16.0  # faster decay leaving water so pose snaps out
const SWIM_FREQUENCY := 3.0
const SWIM_ARM_AMPLITUDE := 1.2
const SWIM_LEG_AMPLITUDE := 0.3
const SWIM_ELBOW_MIN := 0.4  # slightly bent at catch
const SWIM_ELBOW_MAX := 1.5  # ~85° peak pull bend
const SWIM_ELBOW_RECOVERY := 1.4  # bent elbow during recovery (forearm dangles)
const SWIM_ELBOW_Y_AMP := 0.5  # forearm sweeps inward during catch/pull
const SWIM_BODY_PITCH := 1.45  # ~83° from vertical, ~7° from horizontal
const SWIM_BODY_ROLL := 0.45  # ~26° each side
const SWIM_ARM_Y_AMPLITUDE := 0.4
const SWIM_ARM_Z_RECOVERY := 1.0  # high elbow during recovery (above water)
const SWIM_ARM_Z_PULL := 0.1  # arm stays low during pull (underwater)
const SWIM_ARM_OFFSET := PI  # standard opposition timing
const SWIM_KICK_RATIO := 3.0  # 6-beat kick (3x arm frequency)
const ELBOW_RATIO := 0.5
const KNEE_RATIO := 0.7
const KNEE_STANCE_FLEX := 0.12  # slight constant knee bend (~7°)
const RUN_ELBOW_BASE := -1.5  # ~86° bent arms while running
const WALK_ELBOW_BASE := -0.5  # noticeable bend while walking (~29°)
const RUN_KNEE_LIFT := 0.5  # extra knee bend on forward swing
const ELBOW_Y_ANGLE := 0.15  # forearms angle slightly inward
const FLASH_ELBOW_UP := -0.3  # slight bend when looking up
const FLASH_ELBOW_DOWN := -1.0  # deep bend when looking down
const PITCH_UP := 0.8  # camera max pitch
const PITCH_DOWN := -1.2  # camera min pitch
const DEFAULT_GUN_ELBOW := -0.05  # fallback if weapon data unavailable
const LERP_SNAP_EPSILON := 0.0001  # snap lerp to zero below this threshold

var _was_swimming := false

# Cached per-process nodes — populated in _ready to avoid per-frame lookups
var _player_weapon: Node = null
var _flashlight: Node = null
var _cached_camera: Camera3D = null

# Cached face/hand materials — built once in _ready, shared across parts
var _mat_eye: StandardMaterial3D
var _mat_eyebrow: StandardMaterial3D
var _mat_nose: StandardMaterial3D
var _mat_mouth: StandardMaterial3D
var _mat_ear: StandardMaterial3D
var _mat_hair: StandardMaterial3D
var _mat_flashlight_body: StandardMaterial3D

# Player-specific pivots (elbows and knees are not in the base class)
@onready var _left_elbow: Node3D = $LeftShoulderPivot/LeftElbowPivot
@onready var _right_elbow: Node3D = $RightShoulderPivot/RightElbowPivot
@onready var _left_knee: Node3D = $LeftHipPivot/LeftKneePivot
@onready var _right_knee: Node3D = $RightHipPivot/RightKneePivot


func _ready() -> void:
	# Assign base-class pivot vars (cannot use @onready to shadow parent vars)
	_left_shoulder = get_node("LeftShoulderPivot")
	_right_shoulder = get_node("RightShoulderPivot")
	_left_hip = get_node("LeftHipPivot")
	_right_hip = get_node("RightHipPivot")
	_head = get_node_or_null("Head")
	_neck = get_node_or_null("Neck")

	_build_face_materials()
	_build_face_details()
	_build_hands()

	# Cache sibling nodes used every _process frame
	_player_weapon = owner.get_node_or_null("PlayerWeapon")
	if _left_elbow:
		_flashlight = _left_elbow.get_node_or_null("Forearm/Flashlight")


## Create shared materials for face parts (called once).
func _build_face_materials() -> void:
	_mat_eye = StandardMaterial3D.new()
	_mat_eye.albedo_color = Color(0.12, 0.08, 0.05)

	_mat_eyebrow = StandardMaterial3D.new()
	_mat_eyebrow.albedo_color = Color(0.18, 0.12, 0.07)

	_mat_nose = StandardMaterial3D.new()
	_mat_nose.albedo_color = Color(0.80, 0.64, 0.54)

	_mat_mouth = StandardMaterial3D.new()
	_mat_mouth.albedo_color = Color(0.65, 0.30, 0.28)

	_mat_ear = StandardMaterial3D.new()
	_mat_ear.albedo_color = Color(0.82, 0.66, 0.56)

	_mat_hair = StandardMaterial3D.new()
	_mat_hair.albedo_color = Color(0.16, 0.10, 0.06)

	_mat_flashlight_body = StandardMaterial3D.new()
	_mat_flashlight_body.albedo_color = Color(0.12, 0.12, 0.14)
	_mat_flashlight_body.metallic = 0.7
	_mat_flashlight_body.roughness = 0.35


## Add face detail meshes as children of the Head node.
## Head box half-extents: ±0.11 X, ±0.135 Y, ±0.095 Z (front face at Z = +0.095).
## Player faces +Z (rotation.y = camera_yaw + PI), so front features use positive Z.
func _build_face_details() -> void:
	if not _head:
		return

	# --- Eyes (iris + pupil combined as dark ovals on the front face) ---
	_add_box(_head, "EyeLeft", _mat_eye, Vector3(0.050, 0.028, 0.010), Vector3(0.054, 0.030, 0.102))
	_add_box(
		_head, "EyeRight", _mat_eye, Vector3(0.050, 0.028, 0.010), Vector3(-0.054, 0.030, 0.102)
	)

	# --- Eyebrows (thin dark strips above eyes) ---
	_add_box(
		_head, "BrowLeft", _mat_eyebrow, Vector3(0.055, 0.012, 0.008), Vector3(0.053, 0.067, 0.100)
	)
	_add_box(
		_head,
		"BrowRight",
		_mat_eyebrow,
		Vector3(0.055, 0.012, 0.008),
		Vector3(-0.053, 0.067, 0.100)
	)

	# --- Nose (small box protruding from mid-face) ---
	_add_box(_head, "Nose", _mat_nose, Vector3(0.030, 0.040, 0.025), Vector3(0.0, -0.010, 0.108))

	# --- Mouth (thin dark strip below nose) ---
	_add_box(_head, "Mouth", _mat_mouth, Vector3(0.065, 0.014, 0.008), Vector3(0.0, -0.063, 0.100))

	# --- Ears (small boxes on the sides of the head) ---
	_add_box(_head, "EarLeft", _mat_ear, Vector3(0.020, 0.060, 0.040), Vector3(0.118, 0.000, 0.005))
	_add_box(
		_head, "EarRight", _mat_ear, Vector3(0.020, 0.060, 0.040), Vector3(-0.118, 0.000, 0.005)
	)

	# --- Hair cap (wider/deeper than head, sits on top) ---
	_add_box(_head, "HairTop", _mat_hair, Vector3(0.240, 0.055, 0.210), Vector3(0.0, 0.152, 0.002))
	# Side panels keep hair flush with head sides
	_add_box(
		_head, "HairSideLeft", _mat_hair, Vector3(0.028, 0.110, 0.185), Vector3(0.124, 0.090, 0.003)
	)
	_add_box(
		_head,
		"HairSideRight",
		_mat_hair,
		Vector3(0.028, 0.110, 0.185),
		Vector3(-0.124, 0.090, 0.003)
	)
	# Back panel (behind head, negative Z)
	_add_box(
		_head, "HairBack", _mat_hair, Vector3(0.210, 0.070, 0.028), Vector3(0.0, 0.082, -0.105)
	)


## Add hand meshes to both elbow pivots so the wrists end in visible hands.
## Wrist end of each forearm is at Y = -0.25 from the elbow pivot.
## Left hand also carries a flashlight housing aligned with the SpotLight3D.
## Right hand is positioned to grip the gun (grip sits at ~Y=-0.16 in elbow space).
func _build_hands() -> void:
	var mat_skin: StandardMaterial3D = _mat_ear  # same skin tone as ears/neck

	# --- Left hand (holds flashlight) ---
	# Mirror of the right hand: palm overlaps the forearm end so the wrist looks
	# connected. Z is flipped to the front-facing side (+Z = world-up when aimed).
	# The flashlight tube runs through the grip; its lower end protrudes past the fist.
	_add_box(
		_left_elbow,
		"HandLeft_Palm",
		mat_skin,
		Vector3(0.076, 0.056, 0.068),
		Vector3(0.000, -0.255, 0.032)
	)
	_add_box(
		_left_elbow,
		"HandLeft_Fingers",
		mat_skin,
		Vector3(0.070, 0.010, 0.028),
		Vector3(0.000, -0.275, 0.052)
	)
	_add_box(
		_left_elbow,
		"HandLeft_Thumb",
		mat_skin,
		Vector3(0.028, 0.048, 0.028),
		Vector3(0.048, -0.245, 0.015)
	)
	# Tube mostly hidden inside fist; lower end protrudes ~3 cm past the palm.
	_add_box(
		_left_elbow,
		"FlashlightBody",
		_mat_flashlight_body,
		Vector3(0.020, 0.080, 0.020),
		Vector3(0.000, -0.275, 0.032)
	)

	# --- Right hand (grips gun) ---
	# Same approach: one solid fist block + thin knuckle ridge + thumb.
	_add_box(
		_right_elbow,
		"HandRight_Palm",
		mat_skin,
		Vector3(0.076, 0.056, 0.068),
		Vector3(0.000, -0.255, -0.032)
	)
	_add_box(
		_right_elbow,
		"HandRight_Fingers",
		mat_skin,
		Vector3(0.070, 0.010, 0.028),
		Vector3(0.000, -0.275, -0.052)
	)
	_add_box(
		_right_elbow,
		"HandRight_Thumb",
		mat_skin,
		Vector3(0.028, 0.048, 0.028),
		Vector3(-0.048, -0.245, -0.015)
	)


## Helper: create a MeshInstance3D with a BoxMesh, attach to parent node.
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


func _process(delta: float) -> void:
	var parent := get_parent()
	if not parent:
		return

	# Swimming animation override
	if "is_swimming" in parent and parent.is_swimming:
		_was_swimming = true
		_animate_swimming(delta)
		return

	# Use faster decay when transitioning out of swimming
	var decay: float = SWIM_DECAY_SPEED if _was_swimming else DECAY_SPEED
	if _was_swimming:
		# Check if body rotation has decayed enough to switch to normal speed
		if absf(rotation.x) < 0.1 and absf(rotation.z) < 0.1:
			_was_swimming = false

	# Smoothly reset body tilt/roll/twist/bounce (handles swim-exit at faster rate)
	var rot_nonzero := (
		absf(rotation.x) > LERP_SNAP_EPSILON
		or absf(rotation.y) > LERP_SNAP_EPSILON
		or absf(rotation.z) > LERP_SNAP_EPSILON
	)
	if rot_nonzero:
		rotation.x = lerpf(rotation.x, 0.0, delta * decay)
		rotation.y = lerpf(rotation.y, 0.0, delta * decay)
		rotation.z = lerpf(rotation.z, 0.0, delta * decay)
	elif rotation != Vector3.ZERO:
		rotation = Vector3.ZERO
	if absf(position.y) > LERP_SNAP_EPSILON:
		position.y = lerpf(position.y, 0.0, delta * decay)
	else:
		position.y = 0.0
	if absf(position.x) > LERP_SNAP_EPSILON:
		position.x = lerpf(position.x, 0.0, delta * decay)
	else:
		position.x = 0.0
	# Reset head/neck counter-rotation from swimming
	if _head and absf(_head.rotation.z) > LERP_SNAP_EPSILON:
		_head.rotation.z = lerpf(_head.rotation.z, 0.0, delta * decay)
	elif _head:
		_head.rotation.z = 0.0
	if _head and absf(_head.rotation.y) > LERP_SNAP_EPSILON:
		_head.rotation.y = lerpf(_head.rotation.y, 0.0, delta * decay)
	elif _head:
		_head.rotation.y = 0.0
	if _neck and absf(_neck.rotation.z) > LERP_SNAP_EPSILON:
		_neck.rotation.z = lerpf(_neck.rotation.z, 0.0, delta * decay)
	elif _neck:
		_neck.rotation.z = 0.0
	if _neck and absf(_neck.rotation.y) > LERP_SNAP_EPSILON:
		_neck.rotation.y = lerpf(_neck.rotation.y, 0.0, delta * decay)
	elif _neck:
		_neck.rotation.y = 0.0

	var vel: Vector3 = parent.velocity if "velocity" in parent else Vector3.ZERO
	var h_speed := Vector2(vel.x, vel.z).length()

	if h_speed > 0.5:
		var t := clampf((h_speed - 0.5) / (RUN_THRESHOLD - 0.5), 0.0, 1.0)
		_animate_gait(delta, h_speed, t)

		# Elbows: natural bend (walk) to pumped ~70° (run)
		var amp := lerpf(WALK_AMPLITUDE, RUN_AMPLITUDE, t)
		var elbow_base := lerpf(WALK_ELBOW_BASE, RUN_ELBOW_BASE, t)
		var elbow_dyn := lerpf(0.15, ELBOW_RATIO, t)
		var back_ext := lerpf(0.0, 0.15, t)
		_left_elbow.rotation.x = (
			elbow_base
			+ maxf(0.0, _left_shoulder.rotation.x) * elbow_dyn
			+ minf(0.0, _left_shoulder.rotation.x) * back_ext
		)
		_right_elbow.rotation.x = (
			elbow_base
			+ maxf(0.0, _right_shoulder.rotation.x) * elbow_dyn
			+ minf(0.0, _right_shoulder.rotation.x) * back_ext
		)

		# Forearms angle slightly inward (natural arm hang)
		var elbow_y := lerpf(ELBOW_Y_ANGLE * 0.5, ELBOW_Y_ANGLE, t)
		_left_elbow.rotation.y = elbow_y
		_right_elbow.rotation.y = -elbow_y

		# Knees: stance flexion + swing-phase lift + terminal extension before strike
		var knee_lift := lerpf(0.0, RUN_KNEE_LIFT, t)
		var leg_amp := amp * 0.85
		var l_swing_t := clampf(-_left_hip.rotation.x / leg_amp, 0.0, 1.0)
		var r_swing_t := clampf(-_right_hip.rotation.x / leg_amp, 0.0, 1.0)
		_left_knee.rotation.x = KNEE_STANCE_FLEX + sin(l_swing_t * PI) * knee_lift
		_right_knee.rotation.x = KNEE_STANCE_FLEX + sin(r_swing_t * PI) * knee_lift
	else:
		_decay_gait(delta)
		_left_elbow.rotation.x = lerpf(_left_elbow.rotation.x, 0.0, delta * DECAY_SPEED)
		_left_elbow.rotation.y = lerpf(_left_elbow.rotation.y, 0.0, delta * DECAY_SPEED)
		_right_elbow.rotation.x = lerpf(_right_elbow.rotation.x, 0.0, delta * DECAY_SPEED)
		_right_elbow.rotation.y = lerpf(_right_elbow.rotation.y, 0.0, delta * DECAY_SPEED)
		_left_knee.rotation.x = lerpf(_left_knee.rotation.x, 0.0, delta * DECAY_SPEED)
		_right_knee.rotation.x = lerpf(_right_knee.rotation.x, 0.0, delta * DECAY_SPEED)

	# Aim arms at crosshair using camera pitch (skip when not on foot, e.g. driving)
	if InputManager.is_foot():
		var pitch := _get_camera_pitch()

		if _is_armed():
			_aim_gun_arm(pitch)

		if _is_flashlight_on():
			_aim_flashlight_arm(pitch)


func _aim_gun_arm(pitch: float) -> void:
	var elbow_angle := _get_gun_elbow_angle()
	var total: float = -(PI / 2.0 + pitch)
	_right_shoulder.rotation.x = total - elbow_angle
	_right_elbow.rotation.x = elbow_angle


func _aim_flashlight_arm(pitch: float) -> void:
	var t: float = clampf((pitch - PITCH_UP) / (PITCH_DOWN - PITCH_UP), 0.0, 1.0)
	var elbow: float = lerpf(FLASH_ELBOW_UP, FLASH_ELBOW_DOWN, t)
	var total: float = -(PI / 2.0 + pitch)
	_left_shoulder.rotation.x = total - elbow
	_left_elbow.rotation.x = elbow


func _get_gun_elbow_angle() -> float:
	if _player_weapon == null:
		return DEFAULT_GUN_ELBOW
	var w: Dictionary = _player_weapon.get_current_weapon()
	var angle: float = w.get("elbow", DEFAULT_GUN_ELBOW)
	return angle


func _get_camera_pitch() -> float:
	if not _cached_camera or not is_instance_valid(_cached_camera):
		_cached_camera = get_viewport().get_camera_3d()
	if not _cached_camera:
		return 0.0
	var fwd: Vector3 = -_cached_camera.global_transform.basis.z
	return asin(clampf(fwd.y, -1.0, 1.0))


func _is_armed() -> bool:
	return _player_weapon != null and _player_weapon._armed


func _is_flashlight_on() -> bool:
	return _flashlight != null and _flashlight.visible


func _animate_swimming(delta: float) -> void:
	_phase += delta * SWIM_FREQUENCY * TAU

	# Body tilt nearly horizontal
	rotation.x = lerpf(rotation.x, SWIM_BODY_PITCH, delta * 4.0)

	# Per-arm phase with opposition timing
	var l_phase := _phase
	var r_phase := _phase + SWIM_ARM_OFFSET

	# Stroke shaping: phase distortion so pull is slower, recovery is faster
	var l_raw := _stroke_shape(l_phase)
	var r_raw := _stroke_shape(r_phase)

	# Body roll driven by both arms: rolls toward the recovering arm
	var roll_target := (sin(l_phase) - sin(r_phase)) * 0.5 * SWIM_BODY_ROLL
	rotation.z = lerpf(rotation.z, roll_target, delta * 6.0)

	# Counter-rotate head and neck to keep them stable
	if _head:
		_head.rotation.z = -rotation.z * 0.8
		# Breathing turn: head rotates to one side every 3rd stroke
		var breath_cycle := fmod(_phase / TAU, 3.0)
		var breath_t := clampf(1.0 - breath_cycle * 3.0, 0.0, 1.0)
		_head.rotation.y = breath_t * 0.5 * sign(rotation.z)
	if _neck:
		_neck.rotation.z = -rotation.z * 0.5
		# Distribute breathing turn through neck too
		if _head:
			_neck.rotation.y = _head.rotation.y * 0.4

	# -- Arm stroke (per arm) --
	_apply_arm_stroke(_left_shoulder, _left_elbow, l_raw, 1.0)
	_apply_arm_stroke(_right_shoulder, _right_elbow, r_raw, -1.0)

	# -- 6-beat flutter kick (3x arm stroke frequency) --
	var kick_phase := _phase * SWIM_KICK_RATIO
	# Amplitude modulation: every 3rd kick (synced with arm entry) is stronger
	var major_beat := 0.5 + 0.5 * cos(kick_phase * (2.0 / SWIM_KICK_RATIO))
	var kick_amp := SWIM_LEG_AMPLITUDE * (0.6 + 0.4 * major_beat)
	var kick := sin(kick_phase) * kick_amp
	# Modulate kick amplitude by body roll: leg on rolling-toward side kicks harder
	var roll_mod := clampf(rotation.z / SWIM_BODY_ROLL, -1.0, 1.0)
	_left_hip.rotation.x = kick * (1.0 + roll_mod * 0.3)
	_right_hip.rotation.x = -kick * (1.0 - roll_mod * 0.3)
	# Knees bend on downkick (power phase), straight on upkick
	_left_knee.rotation.x = maxf(0.0, -kick) * 0.5
	_right_knee.rotation.x = maxf(0.0, kick) * 0.5


## Asymmetric stroke: second harmonic breaks half-cycle symmetry so pull is
## slower/longer and recovery is faster/snappier (real catch-up timing).
static func _stroke_shape(phase: float) -> float:
	var warped := phase + 0.3 * sin(phase) + 0.15 * sin(2.0 * phase)
	return sin(warped)


## Apply a single arm's freestyle stroke to shoulder and elbow.
## sign_f is 1.0 for left arm, -1.0 for right arm (mirrors Y and Z).
func _apply_arm_stroke(
	shoulder: Node3D,
	elbow: Node3D,
	stroke: float,
	sign_f: float,
) -> void:
	var swing := stroke * SWIM_ARM_AMPLITUDE

	# Pull factor: 0 at recovery, 1 at max pull
	var pull_t := clampf(-stroke, 0.0, 1.0)
	# Recovery factor: 0 during pull, 1 at max recovery
	var recovery_t := clampf(stroke, 0.0, 1.0)
	# Entry moment: peaks at the transition from recovery to pull
	var entry_t := recovery_t * (1.0 - recovery_t) * 4.0

	# X: forward/back with more overhead reach and entry dip (fingertip-first)
	shoulder.rotation.x = -PI * 0.4 + swing - entry_t * 0.25

	# Y: arm reaches outward during recovery, sweeps inward during pull
	shoulder.rotation.y = (
		sign_f * (recovery_t * SWIM_ARM_Y_AMPLITUDE - pull_t * SWIM_ARM_Y_AMPLITUDE * 0.3)
	)

	# Z: high elbow during recovery (above water), low during pull (underwater)
	var z_lift := recovery_t * SWIM_ARM_Z_RECOVERY - pull_t * SWIM_ARM_Z_PULL
	shoulder.rotation.z = -sign_f * z_lift

	# Elbow X: bent during recovery, extends at catch, bends during pull.
	var elbow_bend: float
	if recovery_t > pull_t:
		# Recovery phase: starts bent (forearm dangles at hip exit) → extends to catch
		elbow_bend = lerpf(SWIM_ELBOW_RECOVERY, SWIM_ELBOW_MIN, recovery_t)
	else:
		# Pull phase: starts extended at catch, bends progressively
		elbow_bend = lerpf(SWIM_ELBOW_MIN, SWIM_ELBOW_MAX, pull_t)
	elbow.rotation.x = clampf(elbow_bend, SWIM_ELBOW_MIN, SWIM_ELBOW_MAX)

	# Elbow Y: forearm sweeps inward during catch (S-curve pull path)
	var s_curve := sin(pull_t * PI)
	elbow.rotation.y = sign_f * s_curve * SWIM_ELBOW_Y_AMP
