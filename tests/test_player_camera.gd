extends GutTest
## Tests for player_camera.gd — orbit camera yaw/pitch, positioning, input.

const PlayerCameraScript = preload("res://scenes/player/player_camera.gd")

var _cam_root: Node3D
var _parent: Node3D
var _spring_arm: SpringArm3D
var _camera: Camera3D
var _saved_context: int


func before_each() -> void:
	_saved_context = InputManager.current_context
	InputManager.current_context = InputManager.Context.FOOT

	_parent = Node3D.new()
	_parent.global_position = Vector3(10, 0, 5)

	_cam_root = Node3D.new()
	_cam_root.set_script(PlayerCameraScript)

	_spring_arm = SpringArm3D.new()
	_spring_arm.name = "SpringArm3D"
	_camera = Camera3D.new()
	_camera.name = "Camera3D"
	_spring_arm.add_child(_camera)
	_cam_root.add_child(_spring_arm)

	_parent.add_child(_cam_root)
	add_child_autofree(_parent)
	await get_tree().process_frame


func after_each() -> void:
	InputManager.current_context = _saved_context


# ==========================================================================
# Exported defaults
# ==========================================================================

func test_default_mouse_sensitivity() -> void:
	assert_almost_eq(
		_cam_root.mouse_sensitivity, 0.002, 0.0001,
		"Default mouse sensitivity",
	)


func test_default_min_pitch() -> void:
	assert_almost_eq(_cam_root.min_pitch, -1.2, 0.01, "Default min pitch")


func test_default_max_pitch() -> void:
	assert_almost_eq(_cam_root.max_pitch, 0.8, 0.01, "Default max pitch")


func test_default_height_offset() -> void:
	assert_almost_eq(
		_cam_root.height_offset, 1.5, 0.01, "Default height offset",
	)


func test_default_spring_length() -> void:
	assert_almost_eq(
		_cam_root.spring_length, 3.5, 0.01, "Default spring length",
	)


# ==========================================================================
# Ready
# ==========================================================================

func test_is_top_level_after_ready() -> void:
	assert_true(
		_cam_root.is_set_as_top_level(),
		"Camera root should be set as top level in _ready",
	)


# ==========================================================================
# get_yaw
# ==========================================================================

func test_get_yaw_returns_initial_zero() -> void:
	assert_almost_eq(
		_cam_root.get_yaw(), 0.0, 0.001,
		"Initial yaw should be 0",
	)


func test_get_yaw_returns_updated_value() -> void:
	_cam_root._yaw = 2.5
	assert_almost_eq(
		_cam_root.get_yaw(), 2.5, 0.001,
		"get_yaw should return current _yaw",
	)


# ==========================================================================
# make_active
# ==========================================================================

func test_make_active_sets_camera_current() -> void:
	_cam_root.make_active()
	assert_true(
		_camera.is_current(),
		"Camera should become current after make_active()",
	)


# ==========================================================================
# Mouse input: yaw and pitch
# ==========================================================================

func _make_mouse_motion(rel: Vector2) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.relative = rel
	return event


func test_mouse_motion_updates_yaw() -> void:
	var initial_yaw: float = _cam_root._yaw
	var event := _make_mouse_motion(Vector2(100.0, 0.0))
	_cam_root._unhandled_input(event)
	var expected: float = initial_yaw - 100.0 * _cam_root.mouse_sensitivity
	assert_almost_eq(
		_cam_root._yaw, expected, 0.001,
		"Yaw should decrease with rightward mouse motion",
	)


func test_mouse_motion_updates_pitch() -> void:
	var initial_pitch: float = _cam_root._pitch
	var event := _make_mouse_motion(Vector2(0.0, 50.0))
	_cam_root._unhandled_input(event)
	var expected: float = initial_pitch - 50.0 * _cam_root.mouse_sensitivity
	assert_almost_eq(
		_cam_root._pitch, expected, 0.001,
		"Pitch should decrease with downward mouse motion",
	)


func test_pitch_clamped_to_min() -> void:
	_cam_root._pitch = _cam_root.min_pitch
	var event := _make_mouse_motion(Vector2(0.0, 1000.0))
	_cam_root._unhandled_input(event)
	assert_gte(
		_cam_root._pitch, _cam_root.min_pitch,
		"Pitch should not go below min_pitch",
	)


func test_pitch_clamped_to_max() -> void:
	_cam_root._pitch = _cam_root.max_pitch
	var event := _make_mouse_motion(Vector2(0.0, -1000.0))
	_cam_root._unhandled_input(event)
	assert_lte(
		_cam_root._pitch, _cam_root.max_pitch,
		"Pitch should not go above max_pitch",
	)


func test_mouse_input_ignored_in_vehicle_mode() -> void:
	InputManager.current_context = InputManager.Context.VEHICLE
	var initial_yaw: float = _cam_root._yaw
	var event := _make_mouse_motion(Vector2(100.0, 50.0))
	_cam_root._unhandled_input(event)
	assert_almost_eq(
		_cam_root._yaw, initial_yaw, 0.001,
		"Yaw should not change in VEHICLE context",
	)


func test_non_mouse_input_ignored() -> void:
	var initial_yaw: float = _cam_root._yaw
	var event := InputEventKey.new()
	_cam_root._unhandled_input(event)
	assert_almost_eq(
		_cam_root._yaw, initial_yaw, 0.001,
		"Yaw should not change for non-mouse events",
	)


# ==========================================================================
# Physics process: position tracking
# ==========================================================================

func test_follows_parent_position_with_offset() -> void:
	_parent.global_position = Vector3(10.0, 5.0, 20.0)
	_cam_root._physics_process(0.016)
	assert_almost_eq(
		_cam_root.global_position.x, 10.0, 0.01, "X follows parent",
	)
	assert_almost_eq(
		_cam_root.global_position.y, 5.0 + _cam_root.height_offset, 0.01,
		"Y follows parent + offset",
	)
	assert_almost_eq(
		_cam_root.global_position.z, 20.0, 0.01, "Z follows parent",
	)


func test_rotation_set_from_pitch_and_yaw() -> void:
	_cam_root._yaw = 1.0
	_cam_root._pitch = -0.5
	_cam_root._physics_process(0.016)
	assert_almost_eq(
		_cam_root.rotation.x, -0.5, 0.001, "Rotation X = pitch",
	)
	assert_almost_eq(
		_cam_root.rotation.y, 1.0, 0.001, "Rotation Y = yaw",
	)
	assert_almost_eq(
		_cam_root.rotation.z, 0.0, 0.001, "Rotation Z = 0",
	)


func test_physics_process_ignored_in_vehicle_mode() -> void:
	InputManager.current_context = InputManager.Context.VEHICLE
	_cam_root.global_position = Vector3.ZERO
	_parent.global_position = Vector3(99.0, 99.0, 99.0)
	_cam_root._physics_process(0.016)
	assert_almost_eq(
		_cam_root.global_position.x, 0.0, 0.01,
		"Position should not change in VEHICLE context",
	)


func test_physics_process_no_parent_no_crash() -> void:
	# Detach from parent and re-add directly to scene tree
	var orphan := Node3D.new()
	orphan.set_script(PlayerCameraScript)
	var sa := SpringArm3D.new()
	sa.name = "SpringArm3D"
	var cam := Camera3D.new()
	cam.name = "Camera3D"
	sa.add_child(cam)
	orphan.add_child(sa)
	add_child_autofree(orphan)
	await get_tree().process_frame
	# Parent is the test itself, not a Node3D — get_parent() as Node3D fails
	# Should not crash
	orphan._physics_process(0.016)
	assert_true(true, "No crash when parent is not Node3D")


# ==========================================================================
# Multiple mouse motions accumulate
# ==========================================================================

func test_multiple_mouse_motions_accumulate_yaw() -> void:
	_cam_root._yaw = 0.0
	_cam_root._unhandled_input(_make_mouse_motion(Vector2(50.0, 0.0)))
	_cam_root._unhandled_input(_make_mouse_motion(Vector2(50.0, 0.0)))
	var expected: float = -100.0 * _cam_root.mouse_sensitivity
	assert_almost_eq(
		_cam_root._yaw, expected, 0.001,
		"Two mouse motions should accumulate",
	)


# ==========================================================================
# View mode constants
# ==========================================================================

func test_face_cam_spring_shorter_than_normal() -> void:
	assert_lt(
		PlayerCameraScript.FACE_CAM_SPRING,
		_cam_root.spring_length,
		"Face-cam spring should be shorter than default for a close-up view",
	)


func test_face_cam_t_starts_at_zero() -> void:
	assert_almost_eq(
		_cam_root._face_cam_t, 0.0, 0.001,
		"Face cam blend should start at 0 (normal view)",
	)


func test_view_mode_starts_at_normal() -> void:
	assert_eq(
		_cam_root._view_mode, PlayerCameraScript.VIEW_NORMAL,
		"View mode should start at normal",
	)


func test_shoulder_x_positive() -> void:
	assert_gt(
		PlayerCameraScript.SHOULDER_X, 0.0,
		"SHOULDER_X should be a positive offset",
	)


# ==========================================================================
# V key cycles through view modes
# (toggle is checked via Input.is_action_just_pressed inside _physics_process)
# ==========================================================================

func _press_camera_view() -> void:
	Input.action_press("camera_view")
	_cam_root._physics_process(0.016)
	Input.action_release("camera_view")


func test_view_cycles_normal_to_left() -> void:
	_cam_root._view_mode = PlayerCameraScript.VIEW_NORMAL
	_press_camera_view()
	assert_eq(
		_cam_root._view_mode, PlayerCameraScript.VIEW_LEFT,
		"First V press should move to left-shoulder view",
	)


func test_view_cycles_left_to_front() -> void:
	_cam_root._view_mode = PlayerCameraScript.VIEW_LEFT
	_press_camera_view()
	assert_eq(
		_cam_root._view_mode, PlayerCameraScript.VIEW_FRONT,
		"Second V press should move to front view",
	)


func test_view_cycles_front_to_right() -> void:
	_cam_root._view_mode = PlayerCameraScript.VIEW_FRONT
	_press_camera_view()
	assert_eq(
		_cam_root._view_mode, PlayerCameraScript.VIEW_RIGHT,
		"Third V press should move to right-shoulder view",
	)


func test_view_cycles_right_to_normal() -> void:
	_cam_root._view_mode = PlayerCameraScript.VIEW_RIGHT
	_press_camera_view()
	assert_eq(
		_cam_root._view_mode, PlayerCameraScript.VIEW_NORMAL,
		"Fourth V press should wrap back to normal view",
	)


# ==========================================================================
# Front-view (face-cam) blending
# ==========================================================================

func test_face_cam_spring_blends_toward_face_value() -> void:
	_cam_root._view_mode = PlayerCameraScript.VIEW_FRONT
	_cam_root._physics_process(0.5)
	assert_lt(
		_cam_root.spring_arm.spring_length,
		_cam_root.spring_length,
		"Spring length should shorten toward FACE_CAM_SPRING in front view",
	)


func test_face_cam_spring_restores_on_normal() -> void:
	_cam_root._face_cam_t = 1.0
	_cam_root._blend_spring = PlayerCameraScript.FACE_CAM_SPRING
	_cam_root._view_mode = PlayerCameraScript.VIEW_NORMAL
	_cam_root._physics_process(0.0)
	# With t=1 -> target_face_t=0, spring immediately set via lerpf(..., 0)
	# No delta so no actual lerp, but with t=1 the spring_arm is set to blend_spring
	_cam_root._face_cam_t = 0.0
	_cam_root._blend_spring = _cam_root.spring_length
	_cam_root._physics_process(0.0)
	assert_almost_eq(
		_cam_root.spring_arm.spring_length,
		_cam_root.spring_length,
		0.01,
		"Spring should restore to spring_length when face_cam_t = 0",
	)


func test_face_cam_yaw_offset_at_full_blend() -> void:
	# At t=1 the camera yaw should be _yaw + PI (facing the front)
	_cam_root._yaw = 0.5
	_cam_root._face_cam_t = 1.0
	_cam_root._physics_process(0.0)
	var expected_yaw: float = 0.5 + PI
	assert_almost_eq(
		_cam_root.rotation.y, expected_yaw, 0.01,
		"At full face-cam blend, yaw should be _yaw + PI",
	)


func test_mouse_input_blocked_in_front_view() -> void:
	_cam_root._view_mode = PlayerCameraScript.VIEW_FRONT
	_cam_root._yaw = 1.0
	_cam_root._unhandled_input(_make_mouse_motion(Vector2(200.0, 0.0)))
	assert_almost_eq(
		_cam_root._yaw, 1.0, 0.001,
		"Mouse input should be blocked in front view mode",
	)


func test_mouse_input_allowed_in_shoulder_views() -> void:
	for mode: int in [PlayerCameraScript.VIEW_LEFT, PlayerCameraScript.VIEW_RIGHT]:
		_cam_root._view_mode = mode
		_cam_root._yaw = 0.0
		_cam_root._unhandled_input(_make_mouse_motion(Vector2(100.0, 0.0)))
		assert_lt(
			_cam_root._yaw, 0.0,
			"Mouse input should still update yaw in shoulder views",
		)
		_cam_root._yaw = 0.0


# ==========================================================================
# Shoulder offset blend (_blend_x drives spring_arm.position.x)
# ==========================================================================

func test_left_view_blends_x_negative() -> void:
	_cam_root._view_mode = PlayerCameraScript.VIEW_LEFT
	_cam_root._physics_process(0.5)
	assert_lt(
		_cam_root._blend_x, 0.0,
		"Left shoulder view should blend _blend_x negative",
	)
	assert_lt(
		_spring_arm.position.x, 0.0,
		"Left shoulder should shift spring_arm.position.x negative",
	)


func test_right_view_blends_x_positive() -> void:
	_cam_root._view_mode = PlayerCameraScript.VIEW_RIGHT
	_cam_root._physics_process(0.5)
	assert_gt(
		_cam_root._blend_x, 0.0,
		"Right shoulder view should blend _blend_x positive",
	)
	assert_gt(
		_spring_arm.position.x, 0.0,
		"Right shoulder should shift spring_arm.position.x positive",
	)


func test_normal_view_x_returns_to_zero() -> void:
	_cam_root._blend_x = 0.6
	_cam_root._view_mode = PlayerCameraScript.VIEW_NORMAL
	_cam_root._physics_process(0.5)
	assert_lt(
		absf(_cam_root._blend_x), 0.6,
		"Normal view should blend _blend_x back toward zero",
	)
