extends GutTest
## Tests for player_camera.gd — orbit camera yaw/pitch, inspect mode.

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
		_cam_root.mouse_sensitivity,
		0.002,
		0.0001,
		"Default mouse sensitivity",
	)


func test_default_min_pitch() -> void:
	assert_almost_eq(_cam_root.min_pitch, -1.2, 0.01, "Default min pitch")


func test_default_max_pitch() -> void:
	assert_almost_eq(_cam_root.max_pitch, 0.8, 0.01, "Default max pitch")


func test_default_height_offset() -> void:
	assert_almost_eq(
		_cam_root.height_offset,
		1.5,
		0.01,
		"Default height offset",
	)


func test_default_spring_length() -> void:
	assert_almost_eq(
		_cam_root.spring_length,
		3.5,
		0.01,
		"Default spring length",
	)


func test_inspect_spring_shorter_than_normal() -> void:
	assert_lt(
		PlayerCameraScript.INSPECT_SPRING,
		_cam_root.spring_length,
		"Inspect arm should be shorter than default for a close-up view",
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
		_cam_root.get_yaw(),
		0.0,
		0.001,
		"Initial yaw should be 0",
	)


func test_get_yaw_returns_updated_value() -> void:
	_cam_root._yaw = 2.5
	assert_almost_eq(
		_cam_root.get_yaw(),
		2.5,
		0.001,
		"get_yaw should return current _yaw",
	)


# ==========================================================================
# get_aim_direction
# ==========================================================================


func test_get_aim_direction_ignores_inspect_yaw() -> void:
	_cam_root._yaw = 0.0
	_cam_root._pitch = 0.0
	_cam_root._inspect_yaw = PI * 0.5  # 90° inspect orbit
	var dir: Vector3 = _cam_root.get_aim_direction()
	# With yaw=0 pitch=0 the aim must point along -Z regardless of inspect offset
	assert_almost_eq(dir.x, 0.0, 0.01, "aim X should be 0 when yaw=0")
	assert_almost_eq(dir.z, -1.0, 0.01, "aim Z should be -1 when yaw=0")


func test_get_aim_direction_ignores_inspect_pitch() -> void:
	_cam_root._yaw = 0.0
	_cam_root._pitch = 0.0
	_cam_root._inspect_pitch = 0.8  # large inspect pitch
	var dir: Vector3 = _cam_root.get_aim_direction()
	assert_almost_eq(dir.z, -1.0, 0.01, "aim Z must not be affected by inspect pitch")


func test_get_aim_direction_uses_persistent_yaw() -> void:
	# Camera convention: _yaw -= mouse_x, so yaw=-PI/2 means "looking right" (+X).
	_cam_root._yaw = -PI * 0.5  # 90° right
	_cam_root._pitch = 0.0
	_cam_root._inspect_yaw = 0.0
	var dir: Vector3 = _cam_root.get_aim_direction()
	assert_almost_eq(dir.x, 1.0, 0.01, "aim X should be +1 when yaw=-PI/2")
	assert_almost_eq(dir.z, 0.0, 0.01, "aim Z should be 0 when yaw=-PI/2")


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
# Normal mouse orbit (V not held)
# ==========================================================================


func _make_mouse_motion(rel: Vector2) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.relative = rel
	return event


func test_mouse_motion_updates_yaw() -> void:
	var initial_yaw: float = _cam_root._yaw
	_cam_root._unhandled_input(_make_mouse_motion(Vector2(100.0, 0.0)))
	var expected: float = initial_yaw - 100.0 * _cam_root.mouse_sensitivity
	assert_almost_eq(
		_cam_root._yaw,
		expected,
		0.001,
		"Yaw should decrease with rightward mouse motion",
	)


func test_mouse_motion_updates_pitch() -> void:
	var initial_pitch: float = _cam_root._pitch
	_cam_root._unhandled_input(_make_mouse_motion(Vector2(0.0, 50.0)))
	var expected: float = initial_pitch - 50.0 * _cam_root.mouse_sensitivity
	assert_almost_eq(
		_cam_root._pitch,
		expected,
		0.001,
		"Pitch should decrease with downward mouse motion",
	)


func test_pitch_clamped_to_min() -> void:
	_cam_root._pitch = _cam_root.min_pitch
	_cam_root._unhandled_input(_make_mouse_motion(Vector2(0.0, 1000.0)))
	assert_gte(
		_cam_root._pitch,
		_cam_root.min_pitch,
		"Pitch should not go below min_pitch",
	)


func test_pitch_clamped_to_max() -> void:
	_cam_root._pitch = _cam_root.max_pitch
	_cam_root._unhandled_input(_make_mouse_motion(Vector2(0.0, -1000.0)))
	assert_lte(
		_cam_root._pitch,
		_cam_root.max_pitch,
		"Pitch should not go above max_pitch",
	)


func test_mouse_input_ignored_in_vehicle_mode() -> void:
	InputManager.current_context = InputManager.Context.VEHICLE
	var initial_yaw: float = _cam_root._yaw
	_cam_root._unhandled_input(_make_mouse_motion(Vector2(100.0, 50.0)))
	assert_almost_eq(
		_cam_root._yaw,
		initial_yaw,
		0.001,
		"Yaw should not change in VEHICLE context",
	)


func test_non_mouse_input_ignored() -> void:
	var initial_yaw: float = _cam_root._yaw
	var event := InputEventKey.new()
	_cam_root._unhandled_input(event)
	assert_almost_eq(
		_cam_root._yaw,
		initial_yaw,
		0.001,
		"Yaw should not change for non-mouse events",
	)


func test_multiple_mouse_motions_accumulate_yaw() -> void:
	_cam_root._yaw = 0.0
	_cam_root._unhandled_input(_make_mouse_motion(Vector2(50.0, 0.0)))
	_cam_root._unhandled_input(_make_mouse_motion(Vector2(50.0, 0.0)))
	var expected: float = -100.0 * _cam_root.mouse_sensitivity
	assert_almost_eq(
		_cam_root._yaw,
		expected,
		0.001,
		"Two mouse motions should accumulate",
	)


# ==========================================================================
# Physics process: position and rotation
# ==========================================================================


func test_follows_parent_position_with_offset() -> void:
	_parent.global_position = Vector3(10.0, 5.0, 20.0)
	_cam_root._physics_process(0.016)
	assert_almost_eq(
		_cam_root.global_position.x,
		10.0,
		0.01,
		"X follows parent",
	)
	assert_almost_eq(
		_cam_root.global_position.y,
		5.0 + _cam_root.height_offset,
		0.01,
		"Y follows parent + offset",
	)
	assert_almost_eq(
		_cam_root.global_position.z,
		20.0,
		0.01,
		"Z follows parent",
	)


func test_rotation_set_from_pitch_and_yaw() -> void:
	_cam_root._yaw = 1.0
	_cam_root._pitch = -0.5
	_cam_root._physics_process(0.016)
	assert_almost_eq(
		_cam_root.rotation.x,
		-0.5,
		0.001,
		"Rotation X = pitch",
	)
	assert_almost_eq(
		_cam_root.rotation.y,
		1.0,
		0.001,
		"Rotation Y = yaw",
	)
	assert_almost_eq(
		_cam_root.rotation.z,
		0.0,
		0.001,
		"Rotation Z = 0",
	)


func test_physics_process_ignored_in_vehicle_mode() -> void:
	InputManager.current_context = InputManager.Context.VEHICLE
	_cam_root.global_position = Vector3.ZERO
	_parent.global_position = Vector3(99.0, 99.0, 99.0)
	_cam_root._physics_process(0.016)
	assert_almost_eq(
		_cam_root.global_position.x,
		0.0,
		0.01,
		"Position should not change in VEHICLE context",
	)


func test_physics_process_no_parent_no_crash() -> void:
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
	orphan._physics_process(0.016)
	assert_true(true, "No crash when parent is not Node3D")


# ==========================================================================
# Inspect mode (hold V)
# ==========================================================================


func test_inspect_yaw_starts_zero() -> void:
	assert_almost_eq(
		_cam_root._inspect_yaw,
		0.0,
		0.001,
		"Inspect yaw should start at zero",
	)


func test_inspect_pitch_starts_zero() -> void:
	assert_almost_eq(
		_cam_root._inspect_pitch,
		0.0,
		0.001,
		"Inspect pitch should start at zero",
	)


func test_mouse_in_inspect_mode_updates_inspect_yaw_not_yaw() -> void:
	_cam_root._v_held = true
	_cam_root._yaw = 0.0
	_cam_root._unhandled_input(_make_mouse_motion(Vector2(100.0, 0.0)))
	# Normal _yaw must NOT change
	assert_almost_eq(
		_cam_root._yaw,
		0.0,
		0.001,
		"_yaw should not change while V is held",
	)
	# Inspect yaw SHOULD change
	assert_lt(
		_cam_root._inspect_yaw,
		0.0,
		"_inspect_yaw should decrease with rightward mouse while V held",
	)


func test_inspect_offset_decays_when_v_released() -> void:
	_cam_root._inspect_yaw = 1.5
	_cam_root._inspect_pitch = 0.5
	# Use realistic physics delta; large deltas cause lerpf to overshoot with INSPECT_LERP=8
	_cam_root._physics_process(0.016)
	assert_lt(
		absf(_cam_root._inspect_yaw),
		1.5,
		"_inspect_yaw should decay toward zero on release",
	)
	assert_lt(
		absf(_cam_root._inspect_pitch),
		0.5,
		"_inspect_pitch should decay toward zero on release",
	)


func test_inspect_yaw_applied_to_rotation() -> void:
	_cam_root._yaw = 1.0
	_cam_root._inspect_yaw = 0.5
	_cam_root._physics_process(0.0)
	assert_almost_eq(
		_cam_root.rotation.y,
		1.5,
		0.01,
		"rotation.y should be _yaw + _inspect_yaw",
	)


func test_spring_shortens_during_inspect() -> void:
	# _physics_process reads _v_held from Input, so simulate the action press.
	Input.action_press("camera_view")
	_cam_root._face_cam_t = 0.0
	_cam_root._physics_process(0.016)
	Input.action_release("camera_view")
	assert_lt(
		_cam_root._blend_spring,
		_cam_root.spring_length,
		"Spring should shorten toward INSPECT_SPRING while V is held",
	)


func test_spring_restores_after_release() -> void:
	_cam_root._blend_spring = PlayerCameraScript.INSPECT_SPRING
	_cam_root._face_cam_t = 1.0
	_cam_root._v_held = false
	_cam_root._physics_process(0.5)
	assert_gt(
		_cam_root._blend_spring,
		PlayerCameraScript.INSPECT_SPRING,
		"Spring should grow back toward spring_length after V release",
	)
