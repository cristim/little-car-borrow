extends "res://src/state_machine/player_state.gd"
## Player walking state: camera-relative WASD movement at walk_speed.


func physics_update(delta: float) -> void:
	var player := owner as CharacterBody3D
	var move_input := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")

	if move_input.length() < 0.1:
		state_machine.transition_to("Idle")
		return

	if Input.is_action_pressed("sprint"):
		state_machine.transition_to("Running")
		return

	var direction := _get_camera_relative_direction(move_input)
	player.velocity.x = direction.x * player.walk_speed
	player.velocity.z = direction.z * player.walk_speed
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


