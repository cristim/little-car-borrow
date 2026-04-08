extends GutTest
## Unit tests for scenes/vehicles/helicopter_controller.gd

const ControllerScript: GDScript = preload(
	"res://scenes/vehicles/helicopter_controller.gd"
)

var _src: String


func before_all() -> void:
	_src = ControllerScript.source_code


func _make_ctrl() -> Node:
	var ctrl: Node = Node.new()
	ctrl.set_script(ControllerScript)
	add_child_autofree(ctrl)
	return ctrl


# ==========================================================================
# Constants
# ==========================================================================


func test_ascend_force_constant() -> void:
	assert_almost_eq(
		ControllerScript.ASCEND_FORCE,
		24.0,
		0.001,
		"ASCEND_FORCE should be 24.0",
	)


func test_descend_force_constant() -> void:
	assert_almost_eq(
		ControllerScript.DESCEND_FORCE,
		8.0,
		0.001,
		"DESCEND_FORCE should be 8.0",
	)


func test_hover_sink_constant() -> void:
	assert_almost_eq(
		ControllerScript.HOVER_SINK,
		1.5,
		0.001,
		"HOVER_SINK should be 1.5",
	)


func test_forward_speed_constant() -> void:
	assert_almost_eq(
		ControllerScript.FORWARD_SPEED,
		42.0,
		0.001,
		"FORWARD_SPEED should be 42.0",
	)


func test_back_speed_constant() -> void:
	assert_almost_eq(
		ControllerScript.BACK_SPEED,
		15.0,
		0.001,
		"BACK_SPEED should be 15.0",
	)


func test_yaw_speed_constant() -> void:
	assert_almost_eq(
		ControllerScript.YAW_SPEED,
		1.8,
		0.001,
		"YAW_SPEED should be 1.8",
	)


func test_tilt_max_constant() -> void:
	assert_almost_eq(
		ControllerScript.TILT_MAX,
		0.22,
		0.001,
		"TILT_MAX should be 0.22",
	)


func test_tilt_rate_constant() -> void:
	assert_almost_eq(
		ControllerScript.TILT_RATE,
		4.0,
		0.001,
		"TILT_RATE should be 4.0",
	)


func test_rotor_spin_constant() -> void:
	assert_almost_eq(
		ControllerScript.ROTOR_SPIN,
		20.0,
		0.001,
		"ROTOR_SPIN should be 20.0",
	)


func test_tail_rotor_spin_constant() -> void:
	assert_almost_eq(
		ControllerScript.TAIL_ROTOR_SPIN,
		32.0,
		0.001,
		"TAIL_ROTOR_SPIN should be 32.0",
	)


# ==========================================================================
# Initial state
# ==========================================================================


func test_active_starts_false() -> void:
	var ctrl: Node = _make_ctrl()
	assert_false(ctrl.active, "active should be false by default")


func test_fwd_input_starts_zero() -> void:
	var ctrl: Node = _make_ctrl()
	assert_almost_eq(ctrl._fwd_input, 0.0, 0.001, "_fwd_input should start at 0.0")


func test_yaw_input_starts_zero() -> void:
	var ctrl: Node = _make_ctrl()
	assert_almost_eq(ctrl._yaw_input, 0.0, 0.001, "_yaw_input should start at 0.0")


func test_asc_input_starts_zero() -> void:
	var ctrl: Node = _make_ctrl()
	assert_almost_eq(ctrl._asc_input, 0.0, 0.001, "_asc_input should start at 0.0")


func test_rotor_angle_starts_zero() -> void:
	var ctrl: Node = _make_ctrl()
	assert_almost_eq(ctrl._rotor_angle, 0.0, 0.001, "_rotor_angle should start at 0.0")


func test_vis_pitch_starts_zero() -> void:
	var ctrl: Node = _make_ctrl()
	assert_almost_eq(ctrl._vis_pitch, 0.0, 0.001, "_vis_pitch should start at 0.0")


func test_vis_roll_starts_zero() -> void:
	var ctrl: Node = _make_ctrl()
	assert_almost_eq(ctrl._vis_roll, 0.0, 0.001, "_vis_roll should start at 0.0")


# ==========================================================================
# active setter behaviour
# ==========================================================================


func test_set_active_true_makes_it_true() -> void:
	var ctrl: Node = _make_ctrl()
	ctrl.active = true
	assert_true(ctrl.active, "active should be true after setting to true")


func test_set_active_false_after_true_makes_it_false() -> void:
	var ctrl: Node = _make_ctrl()
	ctrl.active = true
	ctrl.active = false
	assert_false(ctrl.active, "active should be false after deactivating")


func test_deactivate_clears_fwd_input() -> void:
	var ctrl: Node = _make_ctrl()
	ctrl.active = true
	ctrl._fwd_input = 1.0
	ctrl.active = false
	assert_almost_eq(ctrl._fwd_input, 0.0, 0.001, "_fwd_input should be 0 after deactivation")


func test_deactivate_clears_yaw_input() -> void:
	var ctrl: Node = _make_ctrl()
	ctrl.active = true
	ctrl._yaw_input = 0.7
	ctrl.active = false
	assert_almost_eq(ctrl._yaw_input, 0.0, 0.001, "_yaw_input should be 0 after deactivation")


func test_deactivate_clears_asc_input() -> void:
	var ctrl: Node = _make_ctrl()
	ctrl.active = true
	ctrl._asc_input = -1.0
	ctrl.active = false
	assert_almost_eq(ctrl._asc_input, 0.0, 0.001, "_asc_input should be 0 after deactivation")


func test_activate_does_not_clear_inputs() -> void:
	# Setter only clears when deactivating; activating must leave inputs untouched
	# (they will be overwritten by physics_update anyway, but the setter itself
	# must not zero them on the true branch).
	var ctrl: Node = _make_ctrl()
	ctrl._fwd_input = 0.5
	ctrl._yaw_input = 0.3
	ctrl._asc_input = -0.2
	ctrl.active = true
	assert_almost_eq(
		ctrl._fwd_input, 0.5, 0.001, "Activating should not clear _fwd_input"
	)
	assert_almost_eq(
		ctrl._yaw_input, 0.3, 0.001, "Activating should not clear _yaw_input"
	)
	assert_almost_eq(
		ctrl._asc_input, -0.2, 0.001, "Activating should not clear _asc_input"
	)


# ==========================================================================
# physics_update with inactive controller (no-op)
# ==========================================================================


func test_inactive_physics_update_leaves_velocity_unchanged() -> void:
	var ctrl: Node = _make_ctrl()
	var heli: CharacterBody3D = CharacterBody3D.new()
	add_child_autofree(heli)
	# Give heli a non-zero velocity so we can verify it stays unchanged
	heli.velocity = Vector3(3.0, 5.0, -2.0)
	ctrl.physics_update(0.016, heli)
	assert_almost_eq(
		heli.velocity.x, 3.0, 0.001, "velocity.x should be unchanged when inactive"
	)
	assert_almost_eq(
		heli.velocity.y, 5.0, 0.001, "velocity.y should be unchanged when inactive"
	)
	assert_almost_eq(
		heli.velocity.z, -2.0, 0.001, "velocity.z should be unchanged when inactive"
	)


# ==========================================================================
# physics_update with active controller (all inputs zero in headless mode)
# ==========================================================================


func test_active_physics_update_applies_hover_sink() -> void:
	var ctrl: Node = _make_ctrl()
	var heli: CharacterBody3D = CharacterBody3D.new()
	add_child_autofree(heli)
	ctrl.active = true
	# In headless mode Input returns 0 for all actions, so:
	#   fwd_spd = 0, vert_vel = -HOVER_SINK  =>  velocity = Vector3(0, -HOVER_SINK, 0)
	ctrl.physics_update(0.016, heli)
	assert_almost_eq(
		heli.velocity.y,
		-ControllerScript.HOVER_SINK,
		0.001,
		"velocity.y should equal -HOVER_SINK when all inputs are zero",
	)


func test_active_physics_update_zero_horizontal_velocity() -> void:
	var ctrl: Node = _make_ctrl()
	var heli: CharacterBody3D = CharacterBody3D.new()
	add_child_autofree(heli)
	ctrl.active = true
	ctrl.physics_update(0.016, heli)
	assert_almost_eq(
		heli.velocity.x, 0.0, 0.001, "velocity.x should be 0 with no forward input"
	)
	assert_almost_eq(
		heli.velocity.z, 0.0, 0.001, "velocity.z should be 0 with no forward input"
	)


func test_active_physics_update_advances_rotor_angle() -> void:
	var ctrl: Node = _make_ctrl()
	var heli: CharacterBody3D = CharacterBody3D.new()
	add_child_autofree(heli)
	ctrl.active = true
	var before: float = ctrl._rotor_angle
	ctrl.physics_update(0.016, heli)
	assert_gt(
		ctrl._rotor_angle,
		before,
		"_rotor_angle should increase after an active physics_update",
	)


# ==========================================================================
# Source-code inspection
# ==========================================================================


func test_source_contains_ascend_force() -> void:
	assert_true(_src.contains("ASCEND_FORCE"), "Source should reference ASCEND_FORCE")


func test_source_contains_move_and_slide() -> void:
	assert_true(_src.contains("move_and_slide"), "Source should call move_and_slide")


func test_source_contains_hover_sink() -> void:
	assert_true(_src.contains("HOVER_SINK"), "Source should reference HOVER_SINK")


func test_source_contains_tilt_rate() -> void:
	assert_true(_src.contains("TILT_RATE"), "Source should reference TILT_RATE")


func test_source_contains_tail_rotor() -> void:
	assert_true(_src.contains("tail_rotor"), "Source should reference tail_rotor")


func test_source_setter_clears_on_deactivate() -> void:
	assert_true(
		_src.contains("if not active:"),
		"Setter should use 'if not active:' pattern to clear inputs on deactivation",
	)
