extends "res://src/state_machine/state.gd"
## Player is driving a vehicle. Hides player, activates vehicle camera.

var _vehicle: Node = null
var _original_collision_layer := 0


func enter(msg: Dictionary = {}) -> void:
	_vehicle = msg.get("vehicle")
	owner.current_vehicle = _vehicle

	# Switch vehicle to PlayerVehicle collision layer
	_original_collision_layer = _vehicle.collision_layer
	_vehicle.collision_layer = 8

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

	# Listen for forced ejection (vehicle destroyed, mission completion, etc.)
	EventBus.force_exit_vehicle.connect(_on_force_exit)

	# Stealing an NPC vehicle is a crime
	if _vehicle.get_node_or_null("NPCVehicleController"):
		EventBus.crime_committed.emit("vehicle_theft", 30)

	# Ensure vehicle has lights (starting vehicle doesn't get them from a spawner)
	var body := _vehicle.get_node_or_null("Body")
	if body and not body.get_node_or_null("VehicleLights"):
		var LightsScript: GDScript = preload("res://scenes/vehicles/vehicle_lights.gd")
		var lights: Node3D = LightsScript.new()
		lights.name = "VehicleLights"
		body.add_child(lights)
		lights.initialize(_vehicle)

	# Ensure vehicle has water detector (NPC vehicles get it from traffic_manager)
	if not _vehicle.get_node_or_null("VehicleWaterDetector"):
		var WDScript: GDScript = preload("res://scenes/vehicles/vehicle_water_detector.gd")
		var wd: Node = WDScript.new()
		wd.name = "VehicleWaterDetector"
		_vehicle.add_child(wd)

	# Enable player light control on the vehicle
	var lights_node := _vehicle.get_node_or_null("Body/VehicleLights")
	if lights_node:
		lights_node.set_player_driving(true)

	EventBus.vehicle_entered.emit(_vehicle)


func exit() -> void:
	if EventBus.force_exit_vehicle.is_connected(_on_force_exit):
		EventBus.force_exit_vehicle.disconnect(_on_force_exit)

	if _vehicle:
		_vehicle.collision_layer = _original_collision_layer
		_vehicle.steering_input = 0.0
		_vehicle.throttle_input = 0.0
		_vehicle.brake_input = 0.0
		_vehicle.handbrake_input = 0.0
		var lights_node := _vehicle.get_node_or_null("Body/VehicleLights")
		if lights_node:
			lights_node.set_player_driving(false)

	# Restore player visibility and physics (safety net)
	owner.visible = true
	owner.set_physics_process(true)
	owner.collision_layer = 4
	owner.collision_mask = 3

	_vehicle = null
	owner.current_vehicle = null


func physics_update(_delta: float) -> void:
	# Keep player position synced so managers spawn entities near the vehicle
	if _vehicle and is_instance_valid(_vehicle):
		owner.global_position = (_vehicle as Node3D).global_position


func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		state_machine.transition_to("ExitingVehicle", {"vehicle": _vehicle})
	elif event.is_action_pressed("toggle_flashlight"):
		var lights_node := _vehicle.get_node_or_null("Body/VehicleLights")
		if lights_node:
			lights_node.toggle_lights()


func _on_force_exit(vehicle: Node) -> void:
	if vehicle == _vehicle:
		state_machine.transition_to("ExitingVehicle", {"vehicle": _vehicle})
