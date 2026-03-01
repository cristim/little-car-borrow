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
	if event is InputEventMouseButton and event.pressed:
		if current_context != Context.MENU and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func is_foot() -> bool:
	return current_context == Context.FOOT


func is_vehicle() -> bool:
	return current_context == Context.VEHICLE
