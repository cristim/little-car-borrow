extends "res://src/state_machine/state.gd"
## Teleports player to vehicle door and returns to foot mode.
## Opens the driver door during exit and closes it after.

const DOOR_OPEN_ANGLE := -1.2
const DOOR_ANIM_DURATION := 0.3
const SEA_LEVEL := -2.0

var _done := false


func enter(msg: Dictionary = {}) -> void:
	_done = false
	var vehicle: Node = msg.get("vehicle")
	var player := owner as CharacterBody3D

	# Open the door
	var door_pivot := vehicle.get_node_or_null("Body/LeftDoorPivot")
	if door_pivot:
		door_pivot.rotation.y = DOOR_OPEN_ANGLE

	# Teleport to door marker or fallback offset
	var door_marker := vehicle.get_node_or_null("DoorMarker") as Marker3D
	if door_marker:
		player.global_position = door_marker.global_position
	else:
		player.global_position = vehicle.global_position + Vector3(-2.0, 0.5, 0.0)

	# Place player at water surface if ejected underwater
	if player.global_position.y < SEA_LEVEL:
		player.global_position.y = SEA_LEVEL

	player.velocity = Vector3.ZERO

	# Deactivate vehicle controller (car or boat)
	var vc := vehicle.get_node_or_null("VehicleController")
	if vc:
		vc.active = false
	var bc := vehicle.get_node_or_null("BoatController")
	if bc:
		bc.active = false

	# Switch back to foot context and player camera
	InputManager.set_context(InputManager.Context.FOOT)
	player.player_camera.make_active()

	# Close the door after a brief delay
	if door_pivot:
		var tween := door_pivot.create_tween()
		tween.tween_property(
			door_pivot, "rotation:y", 0.0, DOOR_ANIM_DURATION
		).set_delay(0.2)

	EventBus.vehicle_exited.emit(vehicle)
	_done = true


func physics_update(_delta: float) -> void:
	if _done:
		state_machine.transition_to("Idle")
