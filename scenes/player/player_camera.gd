extends Node3D
## Third-person mouse-look orbit camera for the player character.

@export var mouse_sensitivity := 0.002
@export var min_pitch := -1.2
@export var max_pitch := 0.8
@export var height_offset := 1.5
@export var spring_length := 3.5

var _yaw := 0.0
var _pitch := -0.3

@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D


func _ready() -> void:
	set_as_top_level(true)


func _unhandled_input(event: InputEvent) -> void:
	if not InputManager.is_foot():
		return
	if event is InputEventMouseMotion:
		_yaw -= event.relative.x * mouse_sensitivity
		_pitch -= event.relative.y * mouse_sensitivity
		_pitch = clampf(_pitch, min_pitch, max_pitch)


func _physics_process(_delta: float) -> void:
	if not InputManager.is_foot():
		return
	var parent := get_parent() as Node3D
	if not parent:
		return
	global_position = parent.global_position + Vector3(0, height_offset, 0)
	rotation = Vector3(_pitch, _yaw, 0)


func make_active() -> void:
	camera.make_current()


func get_yaw() -> float:
	return _yaw
