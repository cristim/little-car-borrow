extends "res://src/state_machine/state.gd"
## Player is driving a vehicle. Hides player, activates vehicle camera.

var _vehicle: Node = null
var _original_collision_layer := 0
var _boat_seat_vel_y := 0.0  # vertical velocity for gravity-based bench settling


func enter(msg: Dictionary = {}) -> void:
	_vehicle = msg.get("vehicle")
	owner.current_vehicle = _vehicle

	# Switch vehicle to PlayerVehicle collision layer
	_original_collision_layer = _vehicle.collision_layer
	_vehicle.collision_layer = 8

	# Detect vehicle type
	var is_boat: bool = _vehicle.get_node_or_null("BoatController") != null
	var is_heli: bool = _vehicle.get_node_or_null("HelicopterController") != null

	# Hide player for cars; keep visible for boats and helicopters (shown riding)
	if not is_boat and not is_heli:
		owner.visible = false
	else:
		owner.visible = true
		var player_model: Node3D = owner.get_node_or_null("PlayerModel")
		if player_model:
			# Stop walk/idle animation so it doesn't override seated pose
			player_model.set_process(false)
			# Reset any residual walk/run transform (lean, bounce, sway)
			player_model.rotation = Vector3.ZERO
			player_model.position = Vector3(
				player_model.position.x,
				0.0,
				player_model.position.z,
			)
			# Reset all joints to neutral first, then apply seated pose
			for path in [
				"LeftShoulderPivot",
				"RightShoulderPivot",
				"LeftHipPivot",
				"RightHipPivot",
				"LeftShoulderPivot/LeftElbowPivot",
				"RightShoulderPivot/RightElbowPivot",
				"LeftHipPivot/LeftKneePivot",
				"RightHipPivot/RightKneePivot",
			]:
				var joint: Node3D = player_model.get_node_or_null(path)
				if joint:
					joint.rotation = Vector3.ZERO
			# Seated pose: bend hips and knees
			var lh: Node3D = player_model.get_node_or_null("LeftHipPivot")
			var rh: Node3D = player_model.get_node_or_null("RightHipPivot")
			var lk: Node3D = player_model.get_node_or_null("LeftHipPivot/LeftKneePivot")
			var rk: Node3D = player_model.get_node_or_null("RightHipPivot/RightKneePivot")
			if lh:
				lh.rotation.x = -1.4
			if rh:
				rh.rotation.x = -1.4
			if lk:
				lk.rotation.x = 1.4
			if rk:
				rk.rotation.x = 1.4
			var ls: Node3D = player_model.get_node_or_null("LeftShoulderPivot")
			var rs: Node3D = player_model.get_node_or_null("RightShoulderPivot")
			var le: Node3D = player_model.get_node_or_null("LeftShoulderPivot/LeftElbowPivot")
			var re: Node3D = player_model.get_node_or_null("RightShoulderPivot/RightElbowPivot")
			if is_heli:
				# Both arms forward on flight controls
				if ls:
					ls.rotation.x = 0.5
				if rs:
					rs.rotation.x = 0.5
				if le:
					le.rotation.x = -0.3
				if re:
					re.rotation.x = -0.3
			else:
				# Boat: right arm reaches back toward engine tiller
				if rs:
					rs.rotation.x = -0.8
				if re:
					re.rotation.x = 0.6
	owner.set_physics_process(false)
	owner.collision_layer = 0
	owner.collision_mask = 0

	# Activate player's vehicle controller (car, boat, or helicopter)
	var vc := _vehicle.get_node_or_null("VehicleController")
	if vc:
		vc.active = true
	var bc := _vehicle.get_node_or_null("BoatController")
	if bc:
		bc.active = true
		bc.set_passenger(75.0)  # player mass added to Archimedes displacement
		# Seat top is at local y=0.30; hip pivot is 0.80 above player origin,
		# so the player origin must be at seat_top - hip_offset = 0.30 - 0.80 = -0.50.
		# Start 0.40 m above the final seat position so gravity drops them in.
		_boat_seat_vel_y = 0.0
		var sz_enter: float = _vehicle.get_meta("stern_z", 2.5)
		var above_seat: Vector3 = (_vehicle as Node3D).to_global(
			Vector3(-0.4, -0.10, sz_enter - 0.5)
		)
		owner.global_position = above_seat
	var hc := _vehicle.get_node_or_null("HelicopterController")
	if hc:
		hc.active = true
		# Reparent helicopter to city root so it survives suburb chunk unloading
		var city: Node = owner.get_tree().get_first_node_in_group("city_manager")
		if city and _vehicle.get_parent() != city:
			var old_parent: Node = _vehicle.get_parent()
			if old_parent:
				old_parent.remove_child(_vehicle)
			city.add_child(_vehicle)

	# Switch to vehicle context and camera
	InputManager.set_context(InputManager.Context.VEHICLE)
	var vcam := _vehicle.get_node_or_null("VehicleCamera")
	if not vcam:
		# Boats don't have a camera at build time — create one now
		var CamScene: PackedScene = preload("res://scenes/vehicles/vehicle_camera.tscn")
		vcam = CamScene.instantiate()
		vcam.set("target_path", NodePath(".."))
		_vehicle.add_child(vcam)
	# Pull camera back for boats/helicopters so player and vehicle are visible
	if is_boat:
		vcam.set("min_distance", 8.0)
		vcam.set("max_distance", 12.0)
		vcam.set("min_height", 3.0)
		vcam.set("max_height", 5.0)
	elif is_heli:
		vcam.set("min_distance", 12.0)
		vcam.set("max_distance", 20.0)
		vcam.set("min_height", 4.0)
		vcam.set("max_height", 10.0)
	vcam.make_active()

	# Listen for forced ejection (vehicle destroyed, mission completion, etc.)
	if not EventBus.force_exit_vehicle.is_connected(_on_force_exit):
		EventBus.force_exit_vehicle.connect(_on_force_exit)

	# Stealing an NPC vehicle is a crime
	if _vehicle.get_node_or_null("NPCVehicleController"):
		EventBus.crime_committed.emit("vehicle_theft", 30)

	# Skip lights and water detector for boats and helicopters
	if not is_boat and not is_heli:
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
		# Zero GEVP properties (only present on car vehicles, not boats)
		if "steering_input" in _vehicle:
			_vehicle.steering_input = 0.0
			_vehicle.throttle_input = 0.0
			_vehicle.brake_input = 1.0
			_vehicle.handbrake_input = 1.0
		var boat_ctrl := _vehicle.get_node_or_null("BoatController")
		if boat_ctrl:
			boat_ctrl.active = false
			boat_ctrl.set_passenger(0.0)  # remove player weight from buoyancy
		var heli_ctrl := _vehicle.get_node_or_null("HelicopterController")
		if heli_ctrl:
			heli_ctrl.active = false
		# Boats and helicopters disable the walk animation and apply a seated
		# pose on entry — re-enable processing and reset all joints on exit.
		if boat_ctrl or heli_ctrl:
			var player_model: Node3D = owner.get_node_or_null("PlayerModel")
			if player_model:
				player_model.set_process(true)
				for path in ["LeftHipPivot", "RightHipPivot"]:
					var hip: Node3D = player_model.get_node_or_null(path)
					if hip:
						hip.rotation.x = 0.0
				for path_k in [
					"LeftHipPivot/LeftKneePivot",
					"RightHipPivot/RightKneePivot",
				]:
					var knee: Node3D = player_model.get_node_or_null(path_k)
					if knee:
						knee.rotation.x = 0.0
				var rs: Node3D = player_model.get_node_or_null("RightShoulderPivot")
				if rs:
					rs.rotation.x = 0.0
					rs.rotation.y = 0.0
				var re: Node3D = player_model.get_node_or_null("RightShoulderPivot/RightElbowPivot")
				if re:
					re.rotation.x = 0.0
		var lights_node := _vehicle.get_node_or_null("Body/VehicleLights")
		if lights_node:
			lights_node.set_player_driving(false)

	# Restore player visibility and physics (safety net)
	owner.visible = true
	owner.set_physics_process(true)
	owner.collision_layer = 4
	owner.collision_mask = 115

	_vehicle = null
	owner.current_vehicle = null


func physics_update(delta: float) -> void:
	# Keep player position synced so managers spawn entities near the vehicle
	if _vehicle and is_instance_valid(_vehicle):
		owner.global_position = (_vehicle as Node3D).global_position
		# If in helicopter, place player in cockpit seat facing nose
		if _vehicle.get_node_or_null("HelicopterController"):
			# Seat cushion top at y=-0.95; player head ends up at ~y=+0.55 (below cabin top 1.1)
			var seat_offset := Vector3(0.0, -0.95, -0.7)
			owner.global_position = (_vehicle as Node3D).to_global(seat_offset)
			# Player model faces +Z; helicopter nose is -Z — flip PI to face forward
			owner.global_rotation = Vector3(
				0.0,
				(_vehicle as Node3D).global_rotation.y + PI,
				0.0,
			)
		# If in boat, gravity-settle player onto bench then track the boat
		elif _vehicle.get_node_or_null("BoatController"):
			var sz: float = _vehicle.get_meta("stern_z", 2.5)
			# Player origin is at feet; hip pivot is 0.80 m above origin.
			# Seat top (local y=0.30) must align with hips: origin_y = 0.30 - 0.80 = -0.50
			var seat_world: Vector3 = (_vehicle as Node3D).to_global(Vector3(-0.4, -0.50, sz - 0.5))
			# Apply gravity until player reaches seat surface
			if owner.global_position.y > seat_world.y + 0.005:
				_boat_seat_vel_y -= 9.8 * delta
				var new_y: float = owner.global_position.y + _boat_seat_vel_y * delta
				if new_y <= seat_world.y:
					new_y = seat_world.y
					_boat_seat_vel_y = 0.0
				owner.global_position = Vector3(seat_world.x, new_y, seat_world.z)
			else:
				_boat_seat_vel_y = 0.0
				owner.global_position = seat_world
			# Player model faces +Z, boat forward is -Z — add PI to face bow
			owner.global_rotation = Vector3(
				0.0,
				(_vehicle as Node3D).global_rotation.y + PI,
				0.0,
			)
			# Animate right arm with steering (tiller control)
			var steer: float = (
				Input.get_action_strength("move_left") - Input.get_action_strength("move_right")
			)
			var pm: Node3D = owner.get_node_or_null("PlayerModel")
			if pm:
				var rs: Node3D = pm.get_node_or_null("RightShoulderPivot")
				if rs:
					# Arm swings left/right with steering (inverted for PI flip)
					rs.rotation.y = -steer * 0.4


func handle_input(event: InputEvent) -> void:
	if not is_instance_valid(_vehicle):
		return
	if event.is_action_pressed("interact"):
		state_machine.transition_to("ExitingVehicle", {"vehicle": _vehicle})
	elif event.is_action_pressed("toggle_flashlight"):
		var lights_node := _vehicle.get_node_or_null("Body/VehicleLights")
		if lights_node:
			lights_node.toggle_lights()


func _on_force_exit(vehicle: Node) -> void:
	if vehicle == _vehicle:
		state_machine.transition_to("ExitingVehicle", {"vehicle": _vehicle})
