extends Node
## Helicopter flight controller. Reads player input and updates helicopter physics.
## Mirrors the active/inactive interface of VehicleController and BoatController.
##
## Controls (flight-sim style):
##   W / S           — pitch forward / back (translate forward / reverse)
##   A / D           — yaw left / right (tail rotor)
##   Space (jump)    — collective up (ascend)
##   Shift (run)     — collective down (descend)

const ASCEND_FORCE := 8.0    # m/s vertical when ascending
const DESCEND_FORCE := 6.0   # m/s vertical when descending
const HOVER_SINK := 3.0      # gentle sink rate when no vertical input
const FORWARD_SPEED := 14.0  # m/s forward
const BACK_SPEED := 5.0      # m/s reverse
const YAW_SPEED := 1.8       # rad/s yaw
const TILT_MAX := 0.22        # max visual tilt (radians)
const TILT_RATE := 4.0        # visual tilt animation speed
const ROTOR_SPIN := 6.0       # rotor animation speed (rad/s)

var active := false:
	set(value):
		active = value
		if not active:
			_fwd_input = 0.0
			_yaw_input = 0.0
			_asc_input = 0.0

var _fwd_input := 0.0
var _yaw_input := 0.0
var _asc_input := 0.0
var _rotor_angle := 0.0
var _vis_pitch := 0.0
var _vis_roll := 0.0


func physics_update(delta: float, heli: CharacterBody3D) -> void:
	if not active:
		return

	_fwd_input = (
		Input.get_action_strength("move_forward")
		- Input.get_action_strength("move_backward")
	)
	_yaw_input = (
		Input.get_action_strength("move_left")
		- Input.get_action_strength("move_right")
	)
	_asc_input = (
		Input.get_action_strength("jump")
		- Input.get_action_strength("run")
	)

	# Yaw
	heli.rotation.y += _yaw_input * YAW_SPEED * delta

	# Horizontal movement along helicopter forward axis
	var forward: Vector3 = -heli.global_transform.basis.z
	var fwd_spd: float = _fwd_input * (
		FORWARD_SPEED if _fwd_input > 0.0 else BACK_SPEED
	)

	# Vertical
	var vert_vel: float
	if _asc_input > 0.0:
		vert_vel = _asc_input * ASCEND_FORCE
	elif _asc_input < 0.0:
		vert_vel = _asc_input * DESCEND_FORCE
	else:
		vert_vel = -HOVER_SINK

	heli.velocity = forward * fwd_spd + Vector3(0.0, vert_vel, 0.0)
	heli.move_and_slide()

	# Rotor spin animation
	_rotor_angle += ROTOR_SPIN * delta
	var rotor: Node3D = heli.get_node_or_null("Rotor") as Node3D
	if rotor:
		rotor.rotation.y = _rotor_angle

	# Visual body tilt based on movement
	var target_pitch := -_fwd_input * TILT_MAX
	var target_roll := -_yaw_input * TILT_MAX * 0.5
	_vis_pitch = lerpf(_vis_pitch, target_pitch, TILT_RATE * delta)
	_vis_roll = lerpf(_vis_roll, target_roll, TILT_RATE * delta)
	var body: Node3D = heli.get_node_or_null("Body") as Node3D
	if body:
		body.rotation.x = _vis_pitch
		body.rotation.z = _vis_roll
