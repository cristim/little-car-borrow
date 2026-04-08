# gdlint:ignore = max-public-methods
extends GutTest
## Unit tests for vehicle_camera.gd — exported defaults, follow logic setup,
## speed-based distance/height, and make_active behavior.

const _SCRIPT_PATH := "res://scenes/vehicles/vehicle_camera.gd"
const CameraScript = preload(_SCRIPT_PATH)


## Build a VehicleCamera with the required SpringArm3D/Camera3D children
## so @onready vars resolve correctly.
func _make_camera() -> Node3D:
	var cam: Node3D = CameraScript.new()
	var arm := SpringArm3D.new()
	arm.name = "SpringArm3D"
	cam.add_child(arm)
	var camera := Camera3D.new()
	camera.name = "Camera3D"
	arm.add_child(camera)
	return cam


# ==========================================================================
# Exported default values (pre-_ready, no tree needed)
# ==========================================================================


func test_default_min_distance() -> void:
	var cam: Node3D = _make_camera()
	add_child_autofree(cam)
	assert_eq(cam.min_distance, 5.0)


func test_default_max_distance() -> void:
	var cam: Node3D = _make_camera()
	add_child_autofree(cam)
	assert_eq(cam.max_distance, 8.0)


func test_default_min_height() -> void:
	var cam: Node3D = _make_camera()
	add_child_autofree(cam)
	assert_eq(cam.min_height, 2.0)


func test_default_max_height() -> void:
	var cam: Node3D = _make_camera()
	add_child_autofree(cam)
	assert_eq(cam.max_height, 3.5)


func test_default_follow_speed() -> void:
	var cam: Node3D = _make_camera()
	add_child_autofree(cam)
	assert_eq(cam.follow_speed, 5.0)


func test_default_rotation_speed() -> void:
	var cam: Node3D = _make_camera()
	add_child_autofree(cam)
	assert_eq(cam.rotation_speed, 4.0)


func test_default_look_ahead_strength() -> void:
	var cam: Node3D = _make_camera()
	add_child_autofree(cam)
	assert_almost_eq(cam.look_ahead_strength, 0.3, 0.001)


func test_default_speed_for_max_distance() -> void:
	var cam: Node3D = _make_camera()
	add_child_autofree(cam)
	assert_eq(cam.speed_for_max_distance, 150.0)


# ==========================================================================
# Internal state defaults
# ==========================================================================


func test_default_current_velocity_zero() -> void:
	var cam: Node3D = _make_camera()
	add_child_autofree(cam)
	assert_eq(cam._current_velocity, Vector3.ZERO)


func test_default_target_null() -> void:
	var cam: Node3D = _make_camera()
	add_child_autofree(cam)
	assert_null(cam._target)


# ==========================================================================
# Relationship constraints
# ==========================================================================


func test_max_distance_greater_than_min() -> void:
	var cam: Node3D = _make_camera()
	add_child_autofree(cam)
	assert_true(cam.max_distance > cam.min_distance)


func test_max_height_greater_than_min() -> void:
	var cam: Node3D = _make_camera()
	add_child_autofree(cam)
	assert_true(cam.max_height > cam.min_height)


# ==========================================================================
# @onready resolves correctly
# ==========================================================================


func test_spring_arm_resolved() -> void:
	var cam: Node3D = _make_camera()
	add_child_autofree(cam)
	assert_not_null(cam.spring_arm, "spring_arm @onready should resolve")


func test_camera_resolved() -> void:
	var cam: Node3D = _make_camera()
	add_child_autofree(cam)
	assert_not_null(cam.camera, "camera @onready should resolve")


func test_spring_arm_is_spring_arm3d() -> void:
	var cam: Node3D = _make_camera()
	add_child_autofree(cam)
	assert_true(cam.spring_arm is SpringArm3D)


func test_camera_is_camera3d() -> void:
	var cam: Node3D = _make_camera()
	add_child_autofree(cam)
	assert_true(cam.camera is Camera3D)


# ==========================================================================
# _ready — top level (verified via state after add_child)
# ==========================================================================


func test_ready_sets_top_level() -> void:
	var cam: Node3D = _make_camera()
	add_child_autofree(cam)
	assert_true(
		cam.is_set_as_top_level(),
		"Camera should be set as top level after _ready",
	)


# ==========================================================================
# _ready — source verification
# ==========================================================================


func test_ready_resolves_target_path() -> void:
	var src: String = (load(_SCRIPT_PATH) as GDScript).source_code
	assert_true(
		src.contains("_target = get_node(target_path)"),
		"_ready should resolve target_path to _target",
	)


func test_ready_snaps_to_target_position() -> void:
	var src: String = (load(_SCRIPT_PATH) as GDScript).source_code
	assert_true(
		src.contains("global_position = _target.global_position"),
		"Should snap to target position on ready",
	)


# ==========================================================================
# _physics_process — follow logic (source verification)
# ==========================================================================


func test_velocity_smoothing() -> void:
	var src: String = (load(_SCRIPT_PATH) as GDScript).source_code
	assert_true(
		src.contains("_current_velocity = _current_velocity.lerp(target_vel, delta * 3.0)"),
		"Should smooth velocity with lerp",
	)


func test_speed_ratio_clamped() -> void:
	var src: String = (load(_SCRIPT_PATH) as GDScript).source_code
	assert_true(
		src.contains("clampf(speed_kmh / speed_for_max_distance, 0.0, 1.0)"),
		"Speed ratio should be clamped to [0, 1]",
	)


func test_distance_interpolated_by_speed() -> void:
	var src: String = (load(_SCRIPT_PATH) as GDScript).source_code
	assert_true(
		src.contains("lerpf(min_distance, max_distance, speed_ratio)"),
		"Distance should lerp between min and max based on speed",
	)


func test_height_interpolated_by_speed() -> void:
	var src: String = (load(_SCRIPT_PATH) as GDScript).source_code
	assert_true(
		src.contains("lerpf(min_height, max_height, speed_ratio)"),
		"Height should lerp between min and max based on speed",
	)


func test_spring_arm_length_updated() -> void:
	var src: String = (load(_SCRIPT_PATH) as GDScript).source_code
	assert_true(
		src.contains("spring_arm.spring_length = distance"),
		"Spring arm length should follow computed distance",
	)


func test_spring_arm_height_updated() -> void:
	var src: String = (load(_SCRIPT_PATH) as GDScript).source_code
	assert_true(
		src.contains("spring_arm.position.y = height"),
		"Spring arm Y should follow computed height",
	)


func test_look_ahead_applied() -> void:
	var src: String = (load(_SCRIPT_PATH) as GDScript).source_code
	assert_true(
		src.contains("_current_velocity * look_ahead_strength"),
		"Should offset target by velocity for look-ahead",
	)


func test_look_ahead_flattens_y() -> void:
	var src: String = (load(_SCRIPT_PATH) as GDScript).source_code
	assert_true(
		src.contains("look_ahead.y = 0.0"),
		"Look-ahead should zero Y component",
	)


func test_position_lerped() -> void:
	var src: String = (load(_SCRIPT_PATH) as GDScript).source_code
	assert_true(
		src.contains("global_position.lerp(target_pos, delta * follow_speed)"),
		"Position should smooth-follow target",
	)


func test_rotation_follows_velocity_direction() -> void:
	var src: String = (load(_SCRIPT_PATH) as GDScript).source_code
	assert_true(
		src.contains("atan2(flat_vel.x, flat_vel.z)"),
		"Should compute target angle from velocity direction",
	)


func test_rotation_uses_lerp_angle() -> void:
	var src: String = (load(_SCRIPT_PATH) as GDScript).source_code
	assert_true(
		src.contains("lerp_angle(current_angle, target_angle + PI, delta * rotation_speed)"),
		"Rotation should use lerp_angle for smooth interpolation",
	)


func test_stopped_follows_vehicle_rotation() -> void:
	var src: String = (load(_SCRIPT_PATH) as GDScript).source_code
	assert_true(
		src.contains("_target.rotation.y"),
		"When stopped, camera should follow vehicle rotation",
	)


# ==========================================================================
# _physics_process — target fallback (source verification)
# ==========================================================================


func test_retries_target_resolution() -> void:
	var src: String = (load(_SCRIPT_PATH) as GDScript).source_code
	assert_true(
		src.contains("get_node_or_null(target_path)"),
		"Should retry resolving target if initially null",
	)


func test_rigidbody_velocity_check() -> void:
	var src: String = (load(_SCRIPT_PATH) as GDScript).source_code
	assert_true(
		src.contains("_target is RigidBody3D"),
		"Should check if target is RigidBody3D for velocity",
	)


# ==========================================================================
# make_active() — source verification
# ==========================================================================


func test_make_active_source_snaps_position() -> void:
	var src: String = (load(_SCRIPT_PATH) as GDScript).source_code
	assert_true(
		src.contains("global_position = _target.global_position"),
		"make_active should snap position to target",
	)


func test_make_active_source_snaps_rotation() -> void:
	var src: String = (load(_SCRIPT_PATH) as GDScript).source_code
	assert_true(
		src.contains("_auto_yaw = _target.rotation.y"),
		"make_active should snap _auto_yaw to target rotation",
	)


func test_make_active_source_makes_camera_current() -> void:
	var src: String = (load(_SCRIPT_PATH) as GDScript).source_code
	assert_true(
		src.contains("camera.make_current()"),
		"make_active should make the camera current",
	)


# ==========================================================================
# Inspect mode (hold V)
# ==========================================================================


func _make_mouse_motion(rel: Vector2) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.relative = rel
	return event


func test_default_mouse_sensitivity() -> void:
	var cam: Node3D = _make_camera()
	add_child_autofree(cam)
	assert_almost_eq(cam.mouse_sensitivity, 0.002, 0.0001)


func test_inspect_yaw_starts_zero() -> void:
	var cam: Node3D = _make_camera()
	add_child_autofree(cam)
	assert_almost_eq(cam._inspect_yaw, 0.0, 0.001)


func test_inspect_pitch_starts_zero() -> void:
	var cam: Node3D = _make_camera()
	add_child_autofree(cam)
	assert_almost_eq(cam._inspect_pitch, 0.0, 0.001)


func test_auto_yaw_starts_zero() -> void:
	var cam: Node3D = _make_camera()
	add_child_autofree(cam)
	assert_almost_eq(cam._auto_yaw, 0.0, 0.001)


func test_mouse_in_inspect_mode_updates_inspect_yaw() -> void:
	var cam: Node3D = _make_camera()
	add_child_autofree(cam)
	var saved: int = InputManager.current_context
	InputManager.current_context = InputManager.Context.VEHICLE
	cam._v_held = true
	cam._inspect_yaw = 0.0
	cam._unhandled_input(_make_mouse_motion(Vector2(100.0, 0.0)))
	assert_lt(
		cam._inspect_yaw,
		0.0,
		"_inspect_yaw should decrease with rightward mouse while V held",
	)
	InputManager.current_context = saved


func test_mouse_in_inspect_mode_does_not_change_auto_yaw() -> void:
	var cam: Node3D = _make_camera()
	add_child_autofree(cam)
	var saved: int = InputManager.current_context
	InputManager.current_context = InputManager.Context.VEHICLE
	cam._v_held = true
	cam._auto_yaw = 0.0
	cam._unhandled_input(_make_mouse_motion(Vector2(100.0, 0.0)))
	assert_almost_eq(
		cam._auto_yaw,
		0.0,
		0.001,
		"_auto_yaw should not change in inspect mode",
	)
	InputManager.current_context = saved


func test_mouse_ignored_outside_vehicle_context() -> void:
	var cam: Node3D = _make_camera()
	add_child_autofree(cam)
	var saved: int = InputManager.current_context
	InputManager.current_context = InputManager.Context.FOOT
	cam._v_held = true
	cam._unhandled_input(_make_mouse_motion(Vector2(100.0, 50.0)))
	assert_almost_eq(
		cam._inspect_yaw,
		0.0,
		0.001,
		"Input ignored outside VEHICLE context",
	)
	InputManager.current_context = saved


func test_non_mouse_input_ignored() -> void:
	var cam: Node3D = _make_camera()
	add_child_autofree(cam)
	var saved: int = InputManager.current_context
	InputManager.current_context = InputManager.Context.VEHICLE
	cam._v_held = true
	var event := InputEventKey.new()
	cam._unhandled_input(event)
	assert_almost_eq(
		cam._inspect_yaw,
		0.0,
		0.001,
		"Key events should not affect _inspect_yaw",
	)
	InputManager.current_context = saved


func test_inspect_offsets_decay_when_v_released() -> void:
	var cam: Node3D = _make_camera()
	var target := Node3D.new()
	add_child_autofree(target)
	add_child_autofree(cam)
	await get_tree().process_frame
	cam._target = target
	cam._inspect_yaw = 1.5
	cam._inspect_pitch = 0.5
	# Use realistic physics delta; large deltas cause lerpf to overshoot with INSPECT_LERP=8
	cam._physics_process(0.016)
	assert_lt(
		absf(cam._inspect_yaw),
		1.5,
		"_inspect_yaw should decay toward zero on release",
	)
	assert_lt(
		absf(cam._inspect_pitch),
		0.5,
		"_inspect_pitch should decay toward zero on release",
	)


func test_inspect_yaw_applied_to_rotation() -> void:
	var cam: Node3D = _make_camera()
	var target := Node3D.new()
	add_child_autofree(target)
	add_child_autofree(cam)
	await get_tree().process_frame
	cam._target = target
	cam._auto_yaw = 1.0
	cam._inspect_yaw = 0.5
	# delta=0 → no lerp movement, rotation = (_inspect_pitch, _auto_yaw + _inspect_yaw, 0)
	cam._physics_process(0.0)
	assert_almost_eq(
		cam.rotation.y,
		1.5,
		0.01,
		"rotation.y should be _auto_yaw + _inspect_yaw",
	)
