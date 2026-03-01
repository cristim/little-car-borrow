extends "res://src/state_machine/state.gd"
## Hold-F-to-steal state: fills progress bar over steal_duration seconds.
## Opens the driver door during the steal and closes it on completion.

const STEAL_DURATION := 1.5
const DOOR_OPEN_ANGLE := -1.2
const DOOR_ANIM_DURATION := 0.3

var _vehicle: Node = null
var _timer := 0.0
var _progress_bar: ProgressBar = null
var _door_pivot: Node3D = null


func enter(msg: Dictionary = {}) -> void:
	_vehicle = msg.get("vehicle")
	_timer = 0.0
	var player := owner as CharacterBody3D
	player.velocity = Vector3.ZERO

	_progress_bar = owner.get_node("PlayerUI/StealProgressBar")
	if _progress_bar:
		_progress_bar.show_progress()

	# Open the driver door
	_door_pivot = _vehicle.get_node_or_null("Body/LeftDoorPivot")
	if _door_pivot:
		var tween := _door_pivot.create_tween()
		tween.tween_property(
			_door_pivot, "rotation:y", DOOR_OPEN_ANGLE, DOOR_ANIM_DURATION
		)

	EventBus.hide_interaction_prompt.emit()


func exit() -> void:
	if _progress_bar:
		_progress_bar.hide_progress()
	# Close the door
	if _door_pivot and is_instance_valid(_door_pivot):
		var tween := _door_pivot.create_tween()
		tween.tween_property(
			_door_pivot, "rotation:y", 0.0, DOOR_ANIM_DURATION
		)
	_door_pivot = null
	_vehicle = null
	_timer = 0.0


func update(delta: float) -> void:
	if not Input.is_action_pressed("interact"):
		state_machine.transition_to("Idle")
		return

	_timer += delta
	if _progress_bar:
		_progress_bar.update_progress(_timer / STEAL_DURATION)

	if _timer >= STEAL_DURATION:
		state_machine.transition_to("Driving", {"vehicle": _vehicle})


func physics_update(delta: float) -> void:
	# Keep gravity applied while stealing
	var player := owner as CharacterBody3D
	player.velocity.y -= player.gravity * delta
	player.move_and_slide()
