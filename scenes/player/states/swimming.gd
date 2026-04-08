extends "res://src/state_machine/player_state.gd"
## Player swimming state: buoyancy at water surface, WASD movement.

const SWIM_SPEED := 2.5
const SPRINT_SWIM_SPEED := 4.0
const BUOYANCY_FORCE := 12.0
const SURFACE_OFFSET := 0.3  # how far above SEA_LEVEL to float (capsule center)


func enter(_msg: Dictionary = {}) -> void:
	owner.is_swimming = true
	EventBus.player_entered_water.emit()
	_update_prompt()


func exit() -> void:
	owner.is_swimming = false
	EventBus.player_exited_water.emit()


func physics_update(delta: float) -> void:
	var player := owner as CharacterBody3D

	# Buoyancy: push player toward water surface
	var target_y: float = SEA_LEVEL + SURFACE_OFFSET
	if player.global_position.y < target_y:
		player.velocity.y = BUOYANCY_FORCE * delta * 60.0
		if player.global_position.y + player.velocity.y * delta > target_y:
			player.velocity.y = (target_y - player.global_position.y) / delta
	else:
		# Gentle pull down if above surface
		player.velocity.y = lerpf(player.velocity.y, 0.0, delta * 5.0)

	# Horizontal movement
	var move_input := Input.get_vector(
		"move_left", "move_right", "move_forward", "move_backward"
	)
	var speed: float = SPRINT_SWIM_SPEED if Input.is_action_pressed("sprint") else SWIM_SPEED

	if move_input.length() > 0.1:
		var direction := _get_camera_relative_direction(move_input)
		player.velocity.x = direction.x * speed
		player.velocity.z = direction.z * speed
	else:
		player.velocity.x = lerpf(player.velocity.x, 0.0, delta * 5.0)
		player.velocity.z = lerpf(player.velocity.z, 0.0, delta * 5.0)

	player.move_and_slide()

	# Exit: on floor and above water line
	if player.is_on_floor() and player.global_position.y > SEA_LEVEL + 0.5:
		state_machine.transition_to("Idle")
		return

	# Exit if ground below is above water — use ground height directly
	# instead of requiring is_on_floor(), since buoyancy can keep the
	# player floating above the rising shore
	var ground_h := _get_ground_height(player.global_position)
	if ground_h > SEA_LEVEL and player.global_position.y > ground_h - 0.5:
		state_machine.transition_to("Idle")
		return


func handle_input(event: InputEvent) -> void:
	# Allow boarding boats from water (not cars)
	if event.is_action_pressed("interact") and owner.nearest_vehicle:
		if owner.nearest_vehicle.get_node_or_null("BoatController"):
			state_machine.transition_to(
				"EnteringVehicle", {"vehicle": owner.nearest_vehicle}
			)


func _update_prompt() -> void:
	if owner.nearest_vehicle and owner.nearest_vehicle.get_node_or_null("BoatController"):
		EventBus.show_interaction_prompt.emit("Hold F to board")
	else:
		EventBus.hide_interaction_prompt.emit()
