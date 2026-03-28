extends Node3D
## Third-person orbit camera for the player character.
##
## Normal play: mouse orbits the camera freely (persistent yaw/pitch).
## Hold V (camera_view): enters inspect mode — mouse orbits freely around
## the player with a shorter arm so features like weapons and flashlight
## are clearly visible.  Releasing V smoothly returns the camera to the
## default behind-player position.

const INSPECT_SPRING := 2.0   # arm length while inspecting
const INSPECT_LERP := 8.0     # how fast the extra orbit decays on release

const FACE_CAM_SPRING := 1.8  # kept for test compatibility
const FACE_CAM_PITCH := -0.05

@export var mouse_sensitivity := 0.002
@export var min_pitch := -1.2
@export var max_pitch := 0.8
@export var height_offset := 1.5
@export var spring_length := 3.5

var _yaw := 0.0
var _pitch := -0.3

## Extra yaw/pitch accumulated while V is held.
## Lerp back to zero when the key is released.
var _inspect_yaw := 0.0
var _inspect_pitch := 0.0

# Blend state
var _face_cam_t := 0.0    # 0 = normal spring, 1 = inspect spring
var _blend_spring := 3.5  # current arm length

var _v_held := false

@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D


func _ready() -> void:
	set_as_top_level(true)
	_blend_spring = spring_length


func _unhandled_input(event: InputEvent) -> void:
	if not InputManager.is_foot():
		return
	if not event is InputEventMouseMotion:
		return
	if _v_held:
		# Inspect mode: mouse accumulates the temporary orbit offset.
		_inspect_yaw -= event.relative.x * mouse_sensitivity
		_inspect_pitch -= event.relative.y * mouse_sensitivity
		_inspect_pitch = clampf(
			_inspect_pitch, min_pitch - _pitch, max_pitch - _pitch
		)
	else:
		# Normal orbit: mouse moves the persistent camera yaw/pitch.
		_yaw -= event.relative.x * mouse_sensitivity
		_pitch -= event.relative.y * mouse_sensitivity
		_pitch = clampf(_pitch, min_pitch, max_pitch)


func _physics_process(delta: float) -> void:
	if not InputManager.is_foot():
		return
	var parent := get_parent() as Node3D
	if not parent:
		return

	_v_held = Input.is_action_pressed("camera_view")

	if not _v_held:
		# Smoothly return to the default behind-player position.
		_inspect_yaw = lerpf(_inspect_yaw, 0.0, delta * INSPECT_LERP)
		_inspect_pitch = lerpf(_inspect_pitch, 0.0, delta * INSPECT_LERP)

	var target_face_t: float = 1.0 if _v_held else 0.0
	_face_cam_t = lerpf(_face_cam_t, target_face_t, delta * INSPECT_LERP)
	_blend_spring = lerpf(
		_blend_spring,
		lerpf(spring_length, INSPECT_SPRING, _face_cam_t),
		delta * INSPECT_LERP,
	)

	spring_arm.spring_length = _blend_spring
	spring_arm.position.x = 0.0

	global_position = parent.global_position + Vector3(0.0, height_offset, 0.0)
	rotation = Vector3(
		_pitch + _inspect_pitch,
		_yaw + _inspect_yaw,
		0.0,
	)


func make_active() -> void:
	camera.make_current()


func get_yaw() -> float:
	return _yaw
