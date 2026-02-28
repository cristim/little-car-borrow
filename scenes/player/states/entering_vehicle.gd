extends "res://src/state_machine/state.gd"
## Hold-F-to-steal state: fills progress bar over steal_duration seconds.

const STEAL_DURATION := 1.5

var _vehicle: Node = null
var _timer := 0.0
var _progress_bar: ProgressBar = null


func enter(msg: Dictionary = {}) -> void:
	_vehicle = msg.get("vehicle")
	_timer = 0.0
	var player := owner as CharacterBody3D
	player.velocity = Vector3.ZERO

	_progress_bar = owner.get_node("PlayerUI/StealProgressBar")
	if _progress_bar:
		_progress_bar.show_progress()

	EventBus.hide_interaction_prompt.emit()


func exit() -> void:
	if _progress_bar:
		_progress_bar.hide_progress()
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
