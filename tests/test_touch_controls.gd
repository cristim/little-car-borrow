extends GutTest
## Tests for touch controls input injection and state management.

const TouchControlsScript = preload("res://scenes/ui/touch_controls.gd")


func _create_touch_controls() -> Control:
	var tc: Control = TouchControlsScript.new()
	# Force-enable even on desktop for testing by skipping _ready's
	# touchscreen check. We add it to tree then manually init layout.
	tc.set_process(true)
	tc.set_process_input(true)
	tc.visible = true
	add_child_autofree(tc)
	# Manually call layout update since _ready disables on desktop
	tc._update_layout()
	return tc


func test_joystick_injects_joypad_motion() -> void:
	var tc: Control = _create_touch_controls()

	# Inject a joystick direction
	tc._inject_joystick(Vector2(0.5, -0.8))

	# Wait a frame for input to propagate
	await get_tree().process_frame

	# Verify movement actions are active
	var right_strength := Input.get_action_strength("move_right")
	var forward_strength := Input.get_action_strength("move_forward")
	assert_gt(right_strength, 0.0, "move_right should be active after joystick X=0.5")
	assert_gt(forward_strength, 0.0, "move_forward should be active after joystick Y=-0.8")

	# Reset
	tc._inject_joystick(Vector2.ZERO)
	await get_tree().process_frame


func test_joystick_zero_clears_movement() -> void:
	var tc: Control = _create_touch_controls()

	tc._inject_joystick(Vector2(1.0, -1.0))
	await get_tree().process_frame

	tc._inject_joystick(Vector2.ZERO)
	await get_tree().process_frame

	var right_strength := Input.get_action_strength("move_right")
	var forward_strength := Input.get_action_strength("move_forward")
	assert_eq(right_strength, 0.0, "move_right should be zero after joystick reset")
	assert_eq(forward_strength, 0.0, "move_forward should be zero after joystick reset")


func test_auto_sprint_at_high_magnitude() -> void:
	var tc: Control = _create_touch_controls()

	# Push joystick beyond 80% threshold
	tc._inject_joystick(Vector2(0.0, -0.9))
	await get_tree().process_frame

	assert_true(
		Input.is_action_pressed("sprint"), "sprint should be active when joystick magnitude > 0.8"
	)

	# Pull back below threshold
	tc._inject_joystick(Vector2(0.0, -0.3))
	await get_tree().process_frame

	assert_false(
		Input.is_action_pressed("sprint"),
		"sprint should be released when joystick magnitude <= 0.8"
	)

	# Clean up
	tc._inject_joystick(Vector2.ZERO)
	await get_tree().process_frame


func test_release_all_fingers_clears_state() -> void:
	var tc: Control = _create_touch_controls()

	# Simulate active joystick
	tc._joystick_finger = 0
	tc._joystick_direction = Vector2(0.5, -0.5)

	# Simulate active button
	tc._button_fingers["shoot"] = 1

	# Simulate active camera
	tc._camera_finger = 2

	tc._release_all_fingers()
	await get_tree().process_frame

	assert_eq(tc._joystick_finger, -1, "joystick finger should be cleared")
	assert_eq(tc._camera_finger, -1, "camera finger should be cleared")
	assert_eq(tc._button_fingers.size(), 0, "button fingers should be cleared")
	assert_eq(tc._joystick_direction, Vector2.ZERO, "joystick direction should be zero")


func test_button_positions_computed_on_layout() -> void:
	var tc: Control = _create_touch_controls()

	assert_eq(tc._button_positions.size(), 6, "Should have 6 button positions after layout")

	# Pause button should be near top-right
	var pause_btn: Dictionary = tc._button_positions[5]
	assert_eq(pause_btn["name"], "pause", "Last button should be pause")
	assert_gt(
		pause_btn["center"].x, tc._viewport_size.x * 0.5, "Pause button should be on right half"
	)


func test_touch_start_assigns_joystick_finger() -> void:
	var tc: Control = _create_touch_controls()

	# Touch left side, below top 20%
	var touch_pos := Vector2(100, tc._viewport_size.y * 0.5)
	tc._on_touch_start(0, touch_pos)

	assert_eq(tc._joystick_finger, 0, "Finger 0 should be assigned to joystick")
	assert_eq(tc._joystick_center, touch_pos, "Joystick center should be at touch pos")

	# Clean up
	tc._on_touch_end(0)


func test_touch_start_assigns_camera_finger() -> void:
	var tc: Control = _create_touch_controls()

	# Touch right side (camera zone)
	var touch_pos := Vector2(tc._viewport_size.x * 0.8, tc._viewport_size.y * 0.5)
	tc._on_touch_start(0, touch_pos)

	assert_eq(tc._camera_finger, 0, "Finger 0 should be assigned to camera")

	# Clean up
	tc._on_touch_end(0)


func test_multi_touch_joystick_and_camera() -> void:
	var tc: Control = _create_touch_controls()

	# Finger 0 on joystick (left side)
	tc._on_touch_start(0, Vector2(100, tc._viewport_size.y * 0.5))
	# Finger 1 on camera (right side)
	tc._on_touch_start(1, Vector2(tc._viewport_size.x * 0.8, tc._viewport_size.y * 0.5))

	assert_eq(tc._joystick_finger, 0, "Finger 0 should be joystick")
	assert_eq(tc._camera_finger, 1, "Finger 1 should be camera")

	# Release joystick only
	tc._on_touch_end(0)
	assert_eq(tc._joystick_finger, -1, "Joystick finger should be cleared")
	assert_eq(tc._camera_finger, 1, "Camera finger should still be active")

	# Clean up
	tc._on_touch_end(1)


func test_joystick_drag_clamps_to_radius() -> void:
	var tc: Control = _create_touch_controls()

	# Start joystick
	var start_pos := Vector2(200, tc._viewport_size.y * 0.5)
	tc._on_touch_start(0, start_pos)

	# Drag far beyond radius
	var drag_event := InputEventScreenDrag.new()
	drag_event.index = 0
	drag_event.position = start_pos + Vector2(500, 0)  # Way beyond 80px radius
	drag_event.relative = Vector2(500, 0)
	tc._handle_screen_drag(drag_event)

	# Thumb should be clamped to radius distance from center
	var dist: float = tc._joystick_thumb.distance_to(tc._joystick_center)
	assert_almost_eq(dist, tc.JOY_RADIUS, 0.1, "Thumb should be clamped to JOY_RADIUS")

	# Direction should be normalized to ~1.0 on X
	assert_almost_eq(
		tc._joystick_direction.x, 1.0, 0.01, "Direction X should be ~1.0 when dragged far right"
	)

	tc._on_touch_end(0)
