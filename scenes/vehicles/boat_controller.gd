extends Node
## Custom boat physics controller using buoyancy forces on a RigidBody3D.
## Buoyancy always runs (boat floats even when undriven).
## Thrust and steering only active when player is driving.

const SEA_LEVEL := -2.0
const BUOYANCY_STRENGTH := 3000.0
const THRUST_FORCE := 6000.0
const MAX_STEER_ANGLE := 0.5
const WAVE_AMPLITUDE := 0.15
const WAVE_FREQUENCY := 1.2

# 4-point buoyancy hull sample offsets (local space)
# Wide lateral spread prevents roll oscillation
const HULL_POINTS := [
	Vector3(0.0, -0.3, -2.5),   # bow
	Vector3(0.0, -0.3, 2.5),    # stern
	Vector3(-1.5, -0.3, 0.0),   # port (wide)
	Vector3(1.5, -0.3, 0.0),    # starboard (wide)
]

var active := false
var _body: RigidBody3D = null


func _ready() -> void:
	_body = get_parent() as RigidBody3D
	if _body:
		_body.linear_damp = 0.8
		_body.angular_damp = 6.0
		# Low center of mass keeps the boat stable (heavy hull/engine below)
		_body.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
		_body.center_of_mass = Vector3(0.0, -0.8, 0.0)


func _physics_process(delta: float) -> void:
	if not _body:
		return

	# Buoyancy always runs so the boat floats
	_apply_buoyancy()
	# Keep the boat upright — resist roll and pitch
	_stabilize(delta)

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
		# Outboard motor: thrust applied at stern, rotated by steer input
		var forward := -_body.basis.z
		var speed: float = _body.linear_velocity.length()
		var speed_factor := clampf(speed / 3.0, 0.5, 1.0)
		var steer_angle: float = -steer * MAX_STEER_ANGLE * speed_factor
		# Rotate thrust direction around local Y
		var motor_dir: Vector3 = forward.rotated(Vector3.UP, steer_angle)
		var stern_offset := Vector3(0.0, -0.3, 2.5)
		_body.apply_force(
			motor_dir * throttle * THRUST_FORCE,
			_body.basis * stern_offset,
		)

	# Rotate the visual engine pivot to match steering
	var engine_pivot: Node3D = _body.get_node_or_null("EnginePivot")
	if engine_pivot:
		var target_angle: float = steer * MAX_STEER_ANGLE
		engine_pivot.rotation.y = lerpf(
			engine_pivot.rotation.y, target_angle, 0.15,
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
			# Clamp depth to prevent explosive forces when deeply submerged
			depth = minf(depth, 1.5)
			var force_mag: float = BUOYANCY_STRENGTH * depth
			_body.apply_force(
				Vector3(0.0, force_mag, 0.0),
				_body.to_local(world_point),
			)


## Anti-roll stabilization: applies corrective torque to keep the boat
## level on the X (pitch) and Z (roll) axes. Acts like a heavy keel.
func _stabilize(_delta: float) -> void:
	var up: Vector3 = _body.basis.y
	var target := Vector3.UP
	# Cross product gives the rotation axis and magnitude of tilt
	var correction: Vector3 = up.cross(target)
	# Strong restoring torque — acts like a weighted keel
	var stabilize_strength := 800.0
	_body.apply_torque(correction * stabilize_strength)


func _get_wave_height(pos: Vector3) -> float:
	var t: float = Time.get_ticks_msec() * 0.001
	return SEA_LEVEL + WAVE_AMPLITUDE * sin(
		t * WAVE_FREQUENCY + pos.x * 0.5 + pos.z * 0.3
	)


func _is_hull_submerged() -> bool:
	var center: Vector3 = _body.to_global(Vector3.ZERO)
	return center.y < _get_wave_height(center) + 0.5
