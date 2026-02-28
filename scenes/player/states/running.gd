extends "res://src/state_machine/state.gd"
## Player running state: same as walking but at run_speed.


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
	if not player.is_on_floor():
		player.velocity.y -= player.gravity * delta
	player.move_and_slide()

	_rotate_toward_direction(player, direction, delta)


func enter(_msg: Dictionary = {}) -> void:
	_update_prompt()


func exit() -> void:
	EventBus.hide_interaction_prompt.emit()


func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and owner.nearest_vehicle:
		state_machine.transition_to("EnteringVehicle", {"vehicle": owner.nearest_vehicle})


func _get_camera_relative_direction(input: Vector2) -> Vector3:
	var cam_yaw: float = owner.player_camera.get_yaw()
	var forward := Vector3(-sin(cam_yaw), 0, -cos(cam_yaw))
	var right := Vector3(-forward.z, 0, forward.x)
	var direction := (forward * -input.y + right * input.x).normalized()
	return direction


func _rotate_toward_direction(player: CharacterBody3D, direction: Vector3, delta: float) -> void:
	var target_angle := atan2(direction.x, direction.z)
	player.rotation.y = lerp_angle(player.rotation.y, target_angle, player.rotation_speed * delta)


func _update_prompt() -> void:
	if owner.nearest_vehicle:
		EventBus.show_interaction_prompt.emit("Hold F to steal")
	else:
		EventBus.hide_interaction_prompt.emit()
