extends "res://src/state_machine/state.gd"
## Player idle state: applies gravity, waits for movement or interaction input.


func physics_update(delta: float) -> void:
	var player := owner as CharacterBody3D
	player.velocity.x = move_toward(player.velocity.x, 0.0, player.walk_speed)
	player.velocity.z = move_toward(player.velocity.z, 0.0, player.walk_speed)
	if not player.is_on_floor():
		player.velocity.y -= player.gravity * delta
	player.move_and_slide()

	var move_input := _get_move_input()
	if move_input.length() > 0.1:
		if Input.is_action_pressed("sprint"):
			state_machine.transition_to("Running")
		else:
			state_machine.transition_to("Walking")


func enter(_msg: Dictionary = {}) -> void:
	if owner.nearest_vehicle:
		EventBus.show_interaction_prompt.emit("Hold F to steal")
	else:
		EventBus.hide_interaction_prompt.emit()


func exit() -> void:
	EventBus.hide_interaction_prompt.emit()


func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and owner.nearest_vehicle:
		state_machine.transition_to("EnteringVehicle", {"vehicle": owner.nearest_vehicle})


func _get_move_input() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
