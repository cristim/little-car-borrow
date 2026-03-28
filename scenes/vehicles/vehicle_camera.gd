extends Node3D
## Smooth chase camera for vehicles with speed-based distance and look-ahead.
##
## Hold V (camera_view): inspect mode — mouse orbits freely around the vehicle.
## Releasing V smoothly returns the camera to the auto-tracking position.

const INSPECT_LERP := 8.0

@export var mouse_sensitivity := 0.002
@export var target_path: NodePath
@export var min_distance := 5.0
@export var max_distance := 8.0
@export var min_height := 2.0
@export var max_height := 3.5
@export var follow_speed := 5.0
@export var rotation_speed := 4.0
@export var look_ahead_strength := 0.3
@export var speed_for_max_distance := 150.0

var _current_velocity := Vector3.ZERO
var _target: Node3D
var _auto_yaw := 0.0
var _inspect_yaw := 0.0
var _inspect_pitch := 0.0
var _v_held := false

@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D


func _ready() -> void:
	set_as_top_level(true)
	if target_path:
		_target = get_node(target_path)
	if _target:
		global_position = _target.global_position


func _unhandled_input(event: InputEvent) -> void:
	if not InputManager.is_vehicle():
		return
	if not event is InputEventMouseMotion:
		return
	if _v_held:
		_inspect_yaw -= event.relative.x * mouse_sensitivity
		_inspect_pitch -= event.relative.y * mouse_sensitivity
		_inspect_pitch = clampf(_inspect_pitch, -1.2, 0.8)


func _physics_process(delta: float) -> void:
	if not _target:
		if target_path and is_inside_tree():
			_target = get_node_or_null(target_path)
			if _target:
				global_position = _target.global_position
		return

	_v_held = Input.is_action_pressed("camera_view")
	if not _v_held:
		_inspect_yaw = lerpf(_inspect_yaw, 0.0, delta * INSPECT_LERP)
		_inspect_pitch = lerpf(_inspect_pitch, 0.0, delta * INSPECT_LERP)

	var target_vel := Vector3.ZERO
	if _target is RigidBody3D:
		target_vel = _target.linear_velocity
	_current_velocity = _current_velocity.lerp(target_vel, delta * 3.0)

	var speed_kmh := _current_velocity.length() * 3.6
	var speed_ratio := clampf(speed_kmh / speed_for_max_distance, 0.0, 1.0)

	# Distance and height increase with speed
	var distance := lerpf(min_distance, max_distance, speed_ratio)
	var height := lerpf(min_height, max_height, speed_ratio)
	spring_arm.spring_length = distance
	spring_arm.position.y = height

	# Look-ahead: offset target position by velocity direction
	var look_ahead := _current_velocity * look_ahead_strength
	look_ahead.y = 0.0
	var target_pos := _target.global_position + look_ahead

	# Smooth position follow
	global_position = global_position.lerp(target_pos, delta * follow_speed)

	# Smooth rotation to face the vehicle's forward direction
	if _current_velocity.length() > 1.0:
		var flat_vel := _current_velocity
		flat_vel.y = 0.0
		if flat_vel.length() > 0.5:
			var target_angle := atan2(flat_vel.x, flat_vel.z)
			var current_angle := _auto_yaw
			_auto_yaw = lerp_angle(current_angle, target_angle + PI, delta * rotation_speed)
	else:
		# When stopped, follow vehicle rotation
		var target_angle := _target.rotation.y
		_auto_yaw = lerp_angle(_auto_yaw, target_angle, delta * rotation_speed)

	rotation = Vector3(_inspect_pitch, _auto_yaw + _inspect_yaw, 0.0)


func make_active() -> void:
	if _target:
		global_position = _target.global_position
		_auto_yaw = _target.rotation.y
		rotation.y = _auto_yaw
	camera.make_current()
