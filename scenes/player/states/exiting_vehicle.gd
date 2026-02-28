extends "res://src/state_machine/state.gd"
## Teleports player to vehicle door and returns to foot mode.

var _done := false


func enter(msg: Dictionary = {}) -> void:
	_done = false
	var vehicle: Node = msg.get("vehicle")
	var player := owner as CharacterBody3D

	# Teleport to door marker or fallback offset
	var door_marker := vehicle.get_node_or_null("DoorMarker") as Marker3D
	if door_marker:
		player.global_position = door_marker.global_position
	else:
		player.global_position = vehicle.global_position + Vector3(-2.0, 0.5, 0.0)

	player.velocity = Vector3.ZERO

	# Switch back to foot context and player camera
	InputManager.set_context(InputManager.Context.FOOT)
	player.player_camera.make_active()

	EventBus.vehicle_exited.emit(vehicle)
	_done = true


func physics_update(_delta: float) -> void:
	if _done:
		state_machine.transition_to("Idle")
