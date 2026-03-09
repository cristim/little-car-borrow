extends Node3D
## Procedural walk animation for the articulated player model.
## Reads velocity from the parent CharacterBody3D to drive limb swing.

const WALK_AMPLITUDE := 0.35
const RUN_AMPLITUDE := 0.65
const FREQUENCY := 8.0
const DECAY_SPEED := 8.0
const RUN_THRESHOLD := 6.0  # m/s — above this, use run amplitude
const SWIM_FREQUENCY := 3.0
const SWIM_ARM_AMPLITUDE := 1.2
const SWIM_LEG_AMPLITUDE := 0.4
const SWIM_ELBOW_MIN := 0.3
const SWIM_ELBOW_MAX := 1.5
const ELBOW_RATIO := 0.5
const KNEE_RATIO := 0.7
const FLASH_ELBOW_UP := -0.3       # slight bend when looking up
const FLASH_ELBOW_DOWN := -1.0     # deep bend when looking down
const PITCH_UP := 0.8              # camera max pitch
const PITCH_DOWN := -1.2           # camera min pitch
const DEFAULT_GUN_ELBOW := -0.05   # fallback if weapon data unavailable

var _phase := 0.0

@onready var _left_shoulder: Node3D = $LeftShoulderPivot
@onready var _right_shoulder: Node3D = $RightShoulderPivot
@onready var _left_hip: Node3D = $LeftHipPivot
@onready var _right_hip: Node3D = $RightHipPivot
@onready var _left_elbow: Node3D = $LeftShoulderPivot/LeftElbowPivot
@onready var _right_elbow: Node3D = $RightShoulderPivot/RightElbowPivot
@onready var _left_knee: Node3D = $LeftHipPivot/LeftKneePivot
@onready var _right_knee: Node3D = $RightHipPivot/RightKneePivot


func _process(delta: float) -> void:
	var parent := get_parent()
	if not parent:
		return

	# Swimming animation override
	if "is_swimming" in parent and parent.is_swimming:
		_animate_swimming(delta)
		return

	var vel: Vector3 = parent.velocity if "velocity" in parent else Vector3.ZERO
	var h_speed := Vector2(vel.x, vel.z).length()

	if h_speed > 0.5:
		_phase += delta * h_speed * FREQUENCY
		var t := clampf(
			(h_speed - 0.5) / (RUN_THRESHOLD - 0.5), 0.0, 1.0
		)
		var amp := lerpf(WALK_AMPLITUDE, RUN_AMPLITUDE, t)
		var swing := sin(_phase) * amp
		_left_shoulder.rotation.x = swing
		_right_shoulder.rotation.x = -swing
		_left_hip.rotation.x = -swing
		_right_hip.rotation.x = swing

		# Elbows bend when arm swings backward
		_left_elbow.rotation.x = maxf(0.0, -_left_shoulder.rotation.x) * ELBOW_RATIO
		_right_elbow.rotation.x = maxf(0.0, -_right_shoulder.rotation.x) * ELBOW_RATIO

		# Knees bend when leg swings backward
		_left_knee.rotation.x = maxf(0.0, -_left_hip.rotation.x) * KNEE_RATIO
		_right_knee.rotation.x = maxf(0.0, -_right_hip.rotation.x) * KNEE_RATIO
	else:
		_left_shoulder.rotation.x = lerpf(
			_left_shoulder.rotation.x, 0.0, delta * DECAY_SPEED
		)
		_right_shoulder.rotation.x = lerpf(
			_right_shoulder.rotation.x, 0.0, delta * DECAY_SPEED
		)
		_left_hip.rotation.x = lerpf(
			_left_hip.rotation.x, 0.0, delta * DECAY_SPEED
		)
		_right_hip.rotation.x = lerpf(
			_right_hip.rotation.x, 0.0, delta * DECAY_SPEED
		)
		_left_elbow.rotation.x = lerpf(
			_left_elbow.rotation.x, 0.0, delta * DECAY_SPEED
		)
		_right_elbow.rotation.x = lerpf(
			_right_elbow.rotation.x, 0.0, delta * DECAY_SPEED
		)
		_left_knee.rotation.x = lerpf(
			_left_knee.rotation.x, 0.0, delta * DECAY_SPEED
		)
		_right_knee.rotation.x = lerpf(
			_right_knee.rotation.x, 0.0, delta * DECAY_SPEED
		)
		_phase = 0.0

	# Aim arms at crosshair using camera pitch (skip when hidden, e.g. driving)
	if (parent as Node3D).visible:
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
	var t: float = clampf(
		(pitch - PITCH_UP) / (PITCH_DOWN - PITCH_UP), 0.0, 1.0
	)
	var elbow: float = lerpf(FLASH_ELBOW_UP, FLASH_ELBOW_DOWN, t)
	var total: float = -(PI / 2.0 + pitch)
	_left_shoulder.rotation.x = total - elbow
	_left_elbow.rotation.x = elbow


func _get_gun_elbow_angle() -> float:
	var pw := get_parent().get_node_or_null("PlayerWeapon")
	if pw == null:
		return DEFAULT_GUN_ELBOW
	var w: Dictionary = pw.WEAPONS[pw._current_idx]
	var angle: float = w.get("elbow", DEFAULT_GUN_ELBOW)
	return angle


func _get_camera_pitch() -> float:
	var camera := get_viewport().get_camera_3d()
	if not camera:
		return 0.0
	var fwd: Vector3 = -camera.global_transform.basis.z
	return asin(clampf(fwd.y, -1.0, 1.0))


func _is_armed() -> bool:
	var pw := get_parent().get_node_or_null("PlayerWeapon")
	return pw != null and pw._armed


func _is_flashlight_on() -> bool:
	var fl := _left_elbow.get_node_or_null("Forearm/Flashlight")
	return fl != null and fl.visible


func _animate_swimming(delta: float) -> void:
	_phase += delta * SWIM_FREQUENCY * TAU

	# Front crawl arms
	var left_swing := sin(_phase) * SWIM_ARM_AMPLITUDE
	_left_shoulder.rotation.x = -PI * 0.3 + left_swing
	_right_shoulder.rotation.x = -PI * 0.3 - left_swing

	# Elbow: nearly straight when reaching forward, deeply bent during pull
	var left_pull_t := clampf(
		-left_swing / SWIM_ARM_AMPLITUDE, 0.0, 1.0
	)
	var right_pull_t := clampf(
		left_swing / SWIM_ARM_AMPLITUDE, 0.0, 1.0
	)
	_left_elbow.rotation.x = lerpf(
		SWIM_ELBOW_MIN, SWIM_ELBOW_MAX, left_pull_t
	)
	_right_elbow.rotation.x = lerpf(
		SWIM_ELBOW_MIN, SWIM_ELBOW_MAX, right_pull_t
	)

	# Flutter kick (alternating, not frog)
	var kick := sin(_phase) * SWIM_LEG_AMPLITUDE
	_left_hip.rotation.x = kick
	_right_hip.rotation.x = -kick

	_left_knee.rotation.x = maxf(0.0, -kick) * 0.5
	_right_knee.rotation.x = maxf(0.0, kick) * 0.5
