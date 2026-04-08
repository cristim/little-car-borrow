extends SpotLight3D
## Player flashlight held in left hand. Auto-on at night, toggle with L key.
## Aims toward the camera/gun sight direction each frame.

var _manual_off := false
var _camera: Camera3D = null


func _ready() -> void:
	EventBus.time_of_day_changed.connect(_on_time_changed)
	_update_visibility()


func _process(_delta: float) -> void:
	if not visible:
		return
	if not _camera or not is_instance_valid(_camera):
		_camera = get_viewport().get_camera_3d()
		if not _camera:
			return
	# Aim flashlight toward where the camera is looking
	var target := _camera.global_position - _camera.global_transform.basis.z * 50.0
	var forward := target - global_position
	if forward.length_squared() > 0.0001:
		var up := (
			Vector3.FORWARD
			if absf(forward.normalized().dot(Vector3.UP)) > 0.99
			else Vector3.UP
		)
		look_at(target, up)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_flashlight") and InputManager.is_foot():
		_manual_off = not _manual_off
		_update_visibility()


func _on_time_changed(_hour: float) -> void:
	_update_visibility()


func _update_visibility() -> void:
	var should_be_on: bool = DayNightManager.is_night() or DayNightManager.is_dusk_or_dawn()
	if _manual_off:
		visible = false
	else:
		visible = should_be_on
