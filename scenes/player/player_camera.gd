extends Node3D
## Third-person mouse-look orbit camera for the player character.

## Face-cam: hold V to swing camera in front of the player to inspect face.
const FACE_CAM_SPRING := 1.8
const FACE_CAM_PITCH := -0.05   # slightly below horizontal to see the face
const FACE_CAM_LERP := 6.0      # transition speed

@export var mouse_sensitivity := 0.002
@export var min_pitch := -1.2
@export var max_pitch := 0.8
@export var height_offset := 1.5
@export var spring_length := 3.5

var _yaw := 0.0
var _pitch := -0.3
var _face_cam_t := 0.0          # 0 = normal view, 1 = face view

@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D


func _ready() -> void:
	set_as_top_level(true)


func _unhandled_input(event: InputEvent) -> void:
	if not InputManager.is_foot():
		return
	if event is InputEventMouseMotion and _face_cam_t < 0.5:
		_yaw -= event.relative.x * mouse_sensitivity
		_pitch -= event.relative.y * mouse_sensitivity
		_pitch = clampf(_pitch, min_pitch, max_pitch)


func _physics_process(delta: float) -> void:
	if not InputManager.is_foot():
		return
	var parent := get_parent() as Node3D
	if not parent:
		return
	global_position = parent.global_position + Vector3(0, height_offset, 0)

	var face_active: bool = Input.is_action_pressed("face_cam")
	_face_cam_t = lerpf(_face_cam_t, 1.0 if face_active else 0.0, delta * FACE_CAM_LERP)

	var cur_yaw: float = lerpf(_yaw, _yaw + PI, _face_cam_t)
	var cur_pitch: float = lerpf(_pitch, FACE_CAM_PITCH, _face_cam_t)
	spring_arm.spring_length = lerpf(spring_length, FACE_CAM_SPRING, _face_cam_t)
	rotation = Vector3(cur_pitch, cur_yaw, 0)


func make_active() -> void:
	camera.make_current()


func get_yaw() -> float:
	return _yaw
