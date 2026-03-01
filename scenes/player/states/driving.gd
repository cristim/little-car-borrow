extends "res://src/state_machine/state.gd"
## Player is driving a vehicle. Hides player, activates vehicle camera.

var _vehicle: Node = null


func enter(msg: Dictionary = {}) -> void:
	_vehicle = msg.get("vehicle")
	owner.current_vehicle = _vehicle

	# Hide player
	owner.visible = false
	owner.set_physics_process(false)
	owner.collision_layer = 0
	owner.collision_mask = 0

	# Activate player's vehicle controller
	var vc := _vehicle.get_node_or_null("VehicleController")
	if vc:
		vc.active = true

	# Switch to vehicle context and camera
	InputManager.set_context(InputManager.Context.VEHICLE)
	var vcam := _vehicle.get_node_or_null("VehicleCamera")
	if vcam:
		vcam.make_active()

	EventBus.vehicle_entered.emit(_vehicle)


func exit() -> void:
	if _vehicle:
		_vehicle.steering_input = 0.0
		_vehicle.throttle_input = 0.0
		_vehicle.brake_input = 0.0
		_vehicle.handbrake_input = 0.0

	# Restore player visibility and physics (safety net)
	owner.visible = true
	owner.set_physics_process(true)
	owner.collision_layer = 4
	owner.collision_mask = 3

	_vehicle = null
	owner.current_vehicle = null


func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		state_machine.transition_to("ExitingVehicle", {"vehicle": _vehicle})
