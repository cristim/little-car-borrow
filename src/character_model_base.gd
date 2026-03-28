extends Node3D
## Shared walk/run gait constants, pivot state, and animation helpers for
## humanoid character models.  Subclasses call _animate_gait / _decay_gait
## and add their own character-specific logic on top.

const WALK_AMPLITUDE := 0.22
const RUN_AMPLITUDE := 0.45
const FREQUENCY := 8.0
const DECAY_SPEED := 8.0
const RUN_THRESHOLD := 6.0
const WALK_LEAN := 0.03
const RUN_LEAN := 0.15
const WALK_BOUNCE := 0.015
const RUN_BOUNCE := 0.05
const WALK_HIP_SWAY := 0.02
const RUN_HIP_SWAY := 0.01
const PELVIS_TILT := 0.04
const TORSO_TWIST := 0.04
const RUN_TORSO_TWIST := 0.1
const WALK_ARM_INWARD := 0.06
const RUN_ARM_INWARD := 0.15
const ARM_Z_SWAY := 0.08
const RUN_ARM_Z_SWAY := 0.12

var _phase := 0.0
var _left_shoulder: Node3D
var _right_shoulder: Node3D
var _left_hip: Node3D
var _right_hip: Node3D
## Optional head node — rotated for stabilization; set by subclass in _ready.
var _head: Node3D
## Optional neck node — rotated for stabilization; set by subclass in _ready.
var _neck: Node3D


## Drive all shared pivots for one walk/run frame.
## h_speed: horizontal speed in m/s.
## t: walk→run blend in [0, 1]; pass 0.0 for pure walk.
func _animate_gait(delta: float, h_speed: float, t: float) -> void:
	_phase += delta * h_speed * FREQUENCY
	var warped_phase := _phase + 0.25 * sin(_phase)
	var amp := lerpf(WALK_AMPLITUDE, RUN_AMPLITUDE, t)
	var swing := sin(warped_phase) * amp

	# Forward lean
	rotation.x = lerpf(rotation.x, lerpf(WALK_LEAN, RUN_LEAN, t), delta * DECAY_SPEED)

	# Vertical bounce (inverted-pendulum walk, spring-mass run)
	var bounce_amp := lerpf(WALK_BOUNCE, RUN_BOUNCE, t)
	var walk_bounce := (0.5 + 0.5 * cos(warped_phase * 2.0)) * bounce_amp
	var run_bounce := (0.5 - 0.5 * cos(warped_phase * 2.0)) * bounce_amp
	position.y = lerpf(walk_bounce, run_bounce, t)

	# Lateral hip sway — weight shifts toward stance leg
	position.x = -sin(warped_phase) * lerpf(WALK_HIP_SWAY, RUN_HIP_SWAY, t)

	# Pelvis tilt and torso counter-rotation
	var tilt := -sin(warped_phase) * lerpf(PELVIS_TILT, PELVIS_TILT * 0.5, t)
	rotation.z = tilt
	var twist := sin(warped_phase) * lerpf(TORSO_TWIST, RUN_TORSO_TWIST, t)
	rotation.y = twist

	# Head and neck stabilization
	if _head:
		_head.rotation.y = -twist * 0.6
		_head.rotation.z = -tilt * 0.7
	if _neck:
		_neck.rotation.y = -twist * 0.3
		_neck.rotation.z = -tilt * 0.3

	# Arms: forward/back + cross-body + Z sway
	var arm_bias := t * 0.1
	_left_shoulder.rotation.x = swing + arm_bias
	_right_shoulder.rotation.x = -swing + arm_bias

	var inward_amp := lerpf(WALK_ARM_INWARD, RUN_ARM_INWARD, t)
	var l_inward := cos(warped_phase) * inward_amp
	_left_shoulder.rotation.y = l_inward
	_right_shoulder.rotation.y = -l_inward

	var z_sway := lerpf(ARM_Z_SWAY, RUN_ARM_Z_SWAY, t)
	_left_shoulder.rotation.z = -sin(warped_phase) * z_sway
	_right_shoulder.rotation.z = sin(warped_phase) * z_sway

	# Legs: sharpened at run speed to create visual flight phase
	var raw_leg := sin(warped_phase)
	var sharp_leg: float = sign(raw_leg) * pow(absf(raw_leg), lerpf(1.0, 0.6, t))
	var leg_swing: float = sharp_leg * amp * 0.85
	var hip_bias := t * -0.1
	_left_hip.rotation.x = -leg_swing + hip_bias
	_right_hip.rotation.x = leg_swing + hip_bias


## Decay all shared pivots smoothly back to rest pose at DECAY_SPEED.
func _decay_gait(delta: float) -> void:
	rotation.x = lerpf(rotation.x, 0.0, delta * DECAY_SPEED)
	rotation.y = lerpf(rotation.y, 0.0, delta * DECAY_SPEED)
	rotation.z = lerpf(rotation.z, 0.0, delta * DECAY_SPEED)
	position.y = lerpf(position.y, 0.0, delta * DECAY_SPEED)
	position.x = lerpf(position.x, 0.0, delta * DECAY_SPEED)
	_left_shoulder.rotation.x = lerpf(
		_left_shoulder.rotation.x, 0.0, delta * DECAY_SPEED)
	_left_shoulder.rotation.y = lerpf(
		_left_shoulder.rotation.y, 0.0, delta * DECAY_SPEED)
	_left_shoulder.rotation.z = lerpf(
		_left_shoulder.rotation.z, 0.0, delta * DECAY_SPEED)
	_right_shoulder.rotation.x = lerpf(
		_right_shoulder.rotation.x, 0.0, delta * DECAY_SPEED)
	_right_shoulder.rotation.y = lerpf(
		_right_shoulder.rotation.y, 0.0, delta * DECAY_SPEED)
	_right_shoulder.rotation.z = lerpf(
		_right_shoulder.rotation.z, 0.0, delta * DECAY_SPEED)
	_left_hip.rotation.x = lerpf(
		_left_hip.rotation.x, 0.0, delta * DECAY_SPEED)
	_right_hip.rotation.x = lerpf(
		_right_hip.rotation.x, 0.0, delta * DECAY_SPEED)
	if _head:
		_head.rotation.y = lerpf(_head.rotation.y, 0.0, delta * DECAY_SPEED)
		_head.rotation.z = lerpf(_head.rotation.z, 0.0, delta * DECAY_SPEED)
	if _neck:
		_neck.rotation.y = lerpf(_neck.rotation.y, 0.0, delta * DECAY_SPEED)
		_neck.rotation.z = lerpf(_neck.rotation.z, 0.0, delta * DECAY_SPEED)
