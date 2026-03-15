extends Node
## Custom boat physics controller using buoyancy forces on a RigidBody3D.
## Buoyancy always runs (boat floats even when undriven).
## Thrust and steering only active when player is driving.

const SEA_LEVEL := -2.0
const BUOYANCY_STRENGTH := 4000.0
const THRUST_FORCE := 800.0
const STEER_TORQUE := 200.0
const WAVE_AMPLITUDE := 0.15
const WAVE_FREQUENCY := 1.2

# 4-point buoyancy hull sample offsets (local space)
const HULL_POINTS := [
	Vector3(0.0, -0.3, -2.5),   # bow
	Vector3(0.0, -0.3, 2.5),    # stern
	Vector3(-0.8, -0.3, 0.0),   # port
	Vector3(0.8, -0.3, 0.0),    # starboard
]

var active := false
var _body: RigidBody3D = null


func _ready() -> void:
	_body = get_parent() as RigidBody3D
	if _body:
		_body.linear_damp = 1.5
		_body.angular_damp = 3.0


func _physics_process(_delta: float) -> void:
	if not _body:
		return

	# Buoyancy always runs so the boat floats
	_apply_buoyancy()

	if not active:
		return

	# Thrust and steering
	var throttle: float = (
		Input.get_action_strength("move_forward")
		- Input.get_action_strength("move_backward")
	)
	var steer: float = (
		Input.get_action_strength("move_left")
		- Input.get_action_strength("move_right")
	)

	# Only apply thrust when hull is in water
	if _is_hull_submerged():
		var forward := -_body.basis.z
		_body.apply_central_force(forward * throttle * THRUST_FORCE)

		# Steering torque scales with speed so you can't spin in place
		var speed: float = _body.linear_velocity.length()
		var speed_factor := clampf(speed / 5.0, 0.0, 1.0)
		_body.apply_torque(
			Vector3(0.0, steer * STEER_TORQUE * speed_factor, 0.0)
		)

	# Emit speed for HUD
	var speed_kmh: float = _body.linear_velocity.length() * 3.6
	EventBus.vehicle_speed_changed.emit(speed_kmh)


func _apply_buoyancy() -> void:
	for offset in HULL_POINTS:
		var world_point: Vector3 = _body.to_global(offset)
		var wave_y: float = _get_wave_height(world_point)
		var depth: float = wave_y - world_point.y
		if depth > 0.0:
			var force_mag: float = BUOYANCY_STRENGTH * depth
			_body.apply_force(
				Vector3(0.0, force_mag, 0.0),
				_body.to_local(world_point),
			)


func _get_wave_height(pos: Vector3) -> float:
	var t: float = Time.get_ticks_msec() * 0.001
	return SEA_LEVEL + WAVE_AMPLITUDE * sin(
		t * WAVE_FREQUENCY + pos.x * 0.5 + pos.z * 0.3
	)


func _is_hull_submerged() -> bool:
	var center: Vector3 = _body.to_global(Vector3.ZERO)
	return center.y < _get_wave_height(center) + 0.5
