extends CanvasLayer
## Pause menu overlay. Toggled with the "pause" input action (Esc).
## Pauses the scene tree and shows Resume / Quit buttons.

var _previous_context: int = InputManager.Context.FOOT


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	$Overlay.visible = false
	$Panel.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if get_tree().paused:
			_resume()
		else:
			_pause()
		get_viewport().set_input_as_handled()


func _pause() -> void:
	_previous_context = InputManager.current_context
	InputManager.set_context(InputManager.Context.MENU)
	get_tree().paused = true
	visible = true
	$Overlay.visible = true
	$Panel.visible = true


func _resume() -> void:
	get_tree().paused = false
	visible = false
	$Overlay.visible = false
	$Panel.visible = false
	InputManager.set_context(_previous_context)


func _on_resume_pressed() -> void:
	_resume()


func _on_quit_pressed() -> void:
	get_tree().quit()
