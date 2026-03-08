extends SpotLight3D
## Automatic flashlight that turns on at night/dusk/dawn.
## Attached to a SpotLight3D child of PlayerCamera.


func _ready() -> void:
	EventBus.time_of_day_changed.connect(_on_time_changed)
	# Set initial state based on current time (game starts at 8 AM = off)
	_update_visibility()


func _on_time_changed(_hour: float) -> void:
	_update_visibility()


func _update_visibility() -> void:
	visible = DayNightManager.is_night() or DayNightManager.is_dusk_or_dawn()
