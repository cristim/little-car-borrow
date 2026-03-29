extends Node
## Maps our game input actions to GEVP Vehicle properties.

@export var vehicle: Node
var active := false


func _physics_process(_delta: float) -> void:
	if not vehicle:
		return

	if not active:
		return

	var steer: float = Input.get_action_strength("move_left") - Input.get_action_strength("move_right")
	var throttle: float = Input.get_action_strength("move_forward")
	var brake: float = Input.get_action_strength("move_backward")
	var handbrake: float = 1.0 if Input.is_action_pressed("handbrake") else 0.0

	vehicle.steering_input = steer
	vehicle.throttle_input = pow(throttle, 2.0)
	vehicle.brake_input = brake
	vehicle.handbrake_input = handbrake

	# Reverse gear logic: when in reverse gear, swap throttle and brake
	if vehicle.current_gear == -1:
		vehicle.brake_input = pow(throttle, 2.0)
		vehicle.throttle_input = brake

	# Emit speed for HUD
	var speed_kmh: float = vehicle.linear_velocity.length() * 3.6
	EventBus.vehicle_speed_changed.emit(speed_kmh)
