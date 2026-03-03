extends Node
## Manages input context switching between foot and vehicle modes.

enum Context { FOOT, VEHICLE, MENU }

var current_context: Context = Context.FOOT


func set_context(ctx: Context) -> void:
	current_context = ctx
	match ctx:
		Context.MENU:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_fullscreen"):
		_toggle_fullscreen()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.pressed:
		if current_context != Context.MENU and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _toggle_fullscreen() -> void:
	var mode := DisplayServer.window_get_mode()
	if mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	SettingsManager.save()


func is_foot() -> bool:
	return current_context == Context.FOOT


func is_vehicle() -> bool:
	return current_context == Context.VEHICLE
