extends Node3D
## Third-person mouse-look orbit camera for the player character.
##
## Pressing V cycles through four view modes:
##   0 normal      – behind the player (default)
##   1 left        – left-shoulder offset, still facing forward
##   2 front       – camera swings in front of the player to see the face
##   3 right       – right-shoulder offset, still facing forward

const VIEW_NORMAL := 0
const VIEW_LEFT := 1
const VIEW_FRONT := 2
const VIEW_RIGHT := 3

const SHOULDER_X := 0.6      # lateral camera offset for shoulder views
const FACE_CAM_SPRING := 1.8 # spring length in front view
const FACE_CAM_PITCH := -0.05  # slight downward pitch to see the face
const FACE_CAM_LERP := 6.0   # transition speed (shared for all blends)

@export var mouse_sensitivity := 0.002
@export var min_pitch := -1.2
@export var max_pitch := 0.8
@export var height_offset := 1.5
@export var spring_length := 3.5

var _yaw := 0.0
var _pitch := -0.3
var _view_mode := VIEW_NORMAL

# Blend state — lerp toward target values each frame.
var _face_cam_t := 0.0        # 0 = facing back (normal), 1 = facing front
var _blend_x := 0.0           # camera local x offset (left/right shoulder)
var _blend_spring := 3.5      # current spring length
var _prev_face_cam := false   # rising-edge detector for toggle

@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D


func _ready() -> void:
	set_as_top_level(true)
	_blend_spring = spring_length


func _unhandled_input(event: InputEvent) -> void:
	if not InputManager.is_foot():
		return
	# Mouse look is disabled while facing forward so the orbit stays sensible.
	if event is InputEventMouseMotion and _view_mode != VIEW_FRONT:
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

	# Detect rising edge via is_action_pressed — the same polling approach
	# the original face-cam hold used, so it is known to be reliable here.
	var face_cam_down: bool = Input.is_action_pressed("camera_view")
	if face_cam_down and not _prev_face_cam:
		_view_mode = (_view_mode + 1) % 4
	_prev_face_cam = face_cam_down

	# Determine targets based on the active view mode.
	var target_face_t: float = 1.0 if _view_mode == VIEW_FRONT else 0.0
	var target_x: float = 0.0
	if _view_mode == VIEW_LEFT:
		target_x = -SHOULDER_X
	elif _view_mode == VIEW_RIGHT:
		target_x = SHOULDER_X

	# Blend all three parameters smoothly.
	_face_cam_t = lerpf(_face_cam_t, target_face_t, delta * FACE_CAM_LERP)
	_blend_x = lerpf(_blend_x, target_x, delta * FACE_CAM_LERP)
	_blend_spring = lerpf(
		_blend_spring,
		lerpf(spring_length, FACE_CAM_SPRING, target_face_t),
		delta * FACE_CAM_LERP,
	)

	var cur_yaw: float = lerpf(_yaw, _yaw + PI, _face_cam_t)
	var cur_pitch: float = lerpf(_pitch, FACE_CAM_PITCH, _face_cam_t)
	spring_arm.spring_length = _blend_spring

	# Shoulder offset: shift the whole rig sideways so the spring arm pivot
	# (and the collision ray) moves with it.  SpringArm3D manages its children
	# along its own Z axis, so setting camera.position.x would be overridden.
	# Camera right in world space = (cos(yaw), 0, sin(yaw)).
	var right := Vector3(cos(_yaw), 0.0, sin(_yaw))
	global_position = (
		parent.global_position + Vector3(0.0, height_offset, 0.0) + right * _blend_x
	)
	rotation = Vector3(cur_pitch, cur_yaw, 0)


func make_active() -> void:
	camera.make_current()


func get_yaw() -> float:
	return _yaw
