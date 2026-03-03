extends Node3D
## Procedural walk animation for the articulated player model.
## Reads velocity from the parent CharacterBody3D to drive limb swing.

const WALK_AMPLITUDE := 0.35
const RUN_AMPLITUDE := 0.65
const FREQUENCY := 8.0
const DECAY_SPEED := 8.0
const RUN_THRESHOLD := 6.0  # m/s — above this, use run amplitude
const ELBOW_RATIO := 0.5
const KNEE_RATIO := 0.7
const AIM_SHOULDER_X := -PI / 2.0

var _phase := 0.0
var _aim_timer := 0.0

@onready var _left_shoulder: Node3D = $LeftShoulderPivot
@onready var _right_shoulder: Node3D = $RightShoulderPivot
@onready var _left_hip: Node3D = $LeftHipPivot
@onready var _right_hip: Node3D = $RightHipPivot
@onready var _left_elbow: Node3D = $LeftShoulderPivot/LeftElbowPivot
@onready var _right_elbow: Node3D = $RightShoulderPivot/RightElbowPivot
@onready var _left_knee: Node3D = $LeftHipPivot/LeftKneePivot
@onready var _right_knee: Node3D = $RightHipPivot/RightKneePivot


func set_aiming(duration: float) -> void:
	_aim_timer = duration


func _process(delta: float) -> void:
	if _aim_timer > 0.0:
		_aim_timer -= delta

	var parent := get_parent()
	if not parent:
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

	# Override right arm to aim pose when shooting
	if _aim_timer > 0.0:
		_right_shoulder.rotation.x = AIM_SHOULDER_X
		_right_elbow.rotation.x = 0.0
