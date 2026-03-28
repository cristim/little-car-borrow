extends Node3D
## Interactive building door that opens/closes when the player presses F.
## Automatically closes after AUTO_CLOSE_DELAY seconds if left open.
## Created procedurally by chunk_builder_buildings._create_door_node().

const OPEN_ANGLE := -1.2
const ANIM_DURATION := 0.3
const AUTO_CLOSE_DELAY := 10.0

var _is_open := false
var _player_near := false
var _base_rot_y: float = 0.0
var _auto_close_timer: Timer = null


func _ready() -> void:
	_base_rot_y = rotation.y

	_auto_close_timer = Timer.new()
	_auto_close_timer.name = "AutoCloseTimer"
	_auto_close_timer.wait_time = AUTO_CLOSE_DELAY
	_auto_close_timer.one_shot = true
	_auto_close_timer.timeout.connect(_auto_close)
	add_child(_auto_close_timer)

	var zone: Area3D = get_node_or_null("InteractionZone") as Area3D
	if zone == null:
		return
	zone.body_entered.connect(_on_body_entered)
	zone.body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	_player_near = true
	var prompt: String = "[F] Close" if _is_open else "[F] Open"
	EventBus.show_interaction_prompt.emit(prompt)


func _on_body_exited(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	_player_near = false
	EventBus.hide_interaction_prompt.emit()


func _unhandled_input(event: InputEvent) -> void:
	if _player_near and event.is_action_pressed("interact"):
		_toggle()
		get_viewport().set_input_as_handled()


func _toggle() -> void:
	_is_open = not _is_open
	var target_y: float = _base_rot_y + (OPEN_ANGLE if _is_open else 0.0)
	var tween: Tween = create_tween()
	tween.tween_property(self, "rotation:y", target_y, ANIM_DURATION)
	var prompt: String = "[F] Close" if _is_open else "[F] Open"
	EventBus.show_interaction_prompt.emit(prompt)

	if _is_open:
		_auto_close_timer.start()
	else:
		_auto_close_timer.stop()


func _auto_close() -> void:
	if _is_open:
		_toggle()
