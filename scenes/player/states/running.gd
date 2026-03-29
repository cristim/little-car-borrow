extends "res://src/state_machine/state.gd"
## Player running state: same as walking but at run_speed.

const SEA_LEVEL := -2.0


func physics_update(delta: float) -> void:
	var player := owner as CharacterBody3D
	var move_input := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")

	if move_input.length() < 0.1:
		state_machine.transition_to("Idle")
		return

	if not Input.is_action_pressed("sprint"):
		state_machine.transition_to("Walking")
		return

	var direction := _get_camera_relative_direction(move_input)
	player.velocity.x = direction.x * player.run_speed
	player.velocity.z = direction.z * player.run_speed
	if player.is_on_floor():
		if Input.is_action_just_pressed("jump"):
			player.velocity.y = player.jump_speed
	else:
		player.velocity.y -= player.gravity * delta
	player.move_and_slide()

	# Water entry check
	if player.global_position.y < SEA_LEVEL - 0.25 and _is_over_water(player.global_position):
		state_machine.transition_to("Swimming")
		return


func enter(_msg: Dictionary = {}) -> void:
	_update_prompt()


func exit() -> void:
	pass


func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and owner.nearest_vehicle:
		state_machine.transition_to("EnteringVehicle", {"vehicle": owner.nearest_vehicle})


func _get_camera_relative_direction(input: Vector2) -> Vector3:
	var cam_yaw: float = owner.player_camera.get_yaw()
	var forward := Vector3(-sin(cam_yaw), 0, -cos(cam_yaw))
	var right := Vector3(-forward.z, 0, forward.x)
	var direction := (forward * -input.y + right * input.x).normalized()
	return direction


func _update_prompt() -> void:
	if owner.nearest_vehicle:
		var is_boat: bool = owner.nearest_vehicle.get_node_or_null(
			"BoatController"
		) != null
		var prompt := "Hold F to board" if is_boat else "Hold F to steal"
		EventBus.show_interaction_prompt.emit(prompt)


func _is_over_water(pos: Vector3) -> bool:
	var city_nodes := owner.get_tree().get_nodes_in_group("city_manager")
	if city_nodes.is_empty():
		return false
	var boundary: RefCounted = city_nodes[0].get_meta("city_boundary")
	if not boundary:
		return false
	var ground_h: float = boundary.get_ground_height(pos.x, pos.z)
	return ground_h < SEA_LEVEL
