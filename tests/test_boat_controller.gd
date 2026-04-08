extends GutTest
## Unit tests for boat_controller.gd — buoyancy physics and boat steering.

var _script: GDScript
var _src: String


func before_all() -> void:
	_script = load("res://scenes/vehicles/boat_controller.gd")
	_src = _script.source_code


# ==========================================================================
# Constants
# ==========================================================================


func test_sea_level_is_negative_2() -> void:
	assert_true(_src.contains("SEA_LEVEL := -2.0"))


func test_rho_water_is_1000() -> void:
	assert_true(_src.contains("RHO_WATER := 1000.0"), "Should use seawater density")


func test_thrust_force_is_6000() -> void:
	assert_true(_src.contains("THRUST_FORCE := 6000.0"))


func test_max_steer_angle_is_05() -> void:
	assert_true(_src.contains("MAX_STEER_ANGLE := 0.5"))


func test_wave_amplitude_is_015() -> void:
	assert_true(_src.contains("WAVE_AMPLITUDE := 0.15"))


func test_wave_frequency_is_12() -> void:
	assert_true(_src.contains("WAVE_FREQUENCY := 1.2"))


func test_hull_has_8_buoyancy_points() -> void:
	assert_true(
		_src.contains("Vector3(-1.2, -0.3, -2.0)"),
		"Should have port bow point",
	)
	assert_true(
		_src.contains("Vector3(1.2, -0.3, -2.0)"),
		"Should have starboard bow point",
	)
	assert_true(
		_src.contains("Vector3(0.0, -0.3, -2.5)"),
		"Should have keel bow point",
	)
	assert_true(
		_src.contains("Vector3(0.0, -0.3, 2.5)"),
		"Should have keel stern point",
	)


func test_hull_point_area_is_05() -> void:
	assert_true(
		_src.contains("HULL_POINT_AREA := 0.5"),
		"Should define 0.5 m² per hull sample point",
	)


func test_set_passenger_adjusts_mass() -> void:
	var body := RigidBody3D.new()
	body.mass = 800.0
	var ctrl: Node = Node.new()
	ctrl.set_script(_script)
	body.add_child(ctrl)
	add_child_autofree(body)
	ctrl.set_passenger(75.0)
	assert_almost_eq(
		body.mass,
		875.0,
		0.01,
		"Boat mass should be base + passenger (800 + 75 = 875)",
	)
	ctrl.set_passenger(0.0)
	assert_almost_eq(
		body.mass,
		800.0,
		0.01,
		"Boat mass should return to base when passenger removed",
	)


# ==========================================================================
# Initial state
# ==========================================================================


func test_active_defaults_false() -> void:
	var ctrl: Node = Node.new()
	ctrl.set_script(_script)
	add_child_autofree(ctrl)
	assert_false(ctrl.active, "Controller should be inactive by default")


func test_body_is_null_without_rigidbody_parent() -> void:
	var ctrl: Node = Node.new()
	ctrl.set_script(_script)
	add_child_autofree(ctrl)
	assert_null(ctrl._body, "Should be null when parent is not RigidBody3D")


func test_body_set_with_rigidbody_parent() -> void:
	var body := RigidBody3D.new()
	var ctrl: Node = Node.new()
	ctrl.set_script(_script)
	body.add_child(ctrl)
	add_child_autofree(body)
	assert_not_null(ctrl._body, "Should reference parent RigidBody3D")
	assert_eq(ctrl._body, body)


# ==========================================================================
# _ready() body configuration
# ==========================================================================


func test_ready_sets_linear_damp() -> void:
	var body := RigidBody3D.new()
	var ctrl: Node = Node.new()
	ctrl.set_script(_script)
	body.add_child(ctrl)
	add_child_autofree(body)
	assert_almost_eq(body.linear_damp, 0.8, 0.01, "Linear damp should be 0.8")


func test_ready_sets_angular_damp() -> void:
	var body := RigidBody3D.new()
	var ctrl: Node = Node.new()
	ctrl.set_script(_script)
	body.add_child(ctrl)
	add_child_autofree(body)
	assert_eq(body.angular_damp, 6.0, "Angular damp should be 6.0")


func test_ready_sets_custom_center_of_mass() -> void:
	var body := RigidBody3D.new()
	var ctrl: Node = Node.new()
	ctrl.set_script(_script)
	body.add_child(ctrl)
	add_child_autofree(body)
	assert_eq(
		body.center_of_mass_mode,
		RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM,
		"Should use custom center of mass mode",
	)
	assert_eq(
		body.center_of_mass,
		Vector3(0.0, -0.8, 0.0),
		"Center of mass should be low for stability",
	)


# ==========================================================================
# Physics behavior — source verification
# ==========================================================================


func test_buoyancy_runs_before_active_check() -> void:
	var buoyancy_idx: int = _src.find("_apply_buoyancy()")
	var active_check_idx: int = _src.find("if not active:", buoyancy_idx)
	assert_true(
		buoyancy_idx < active_check_idx,
		"_apply_buoyancy should run before the active check",
	)


func test_stabilize_runs_before_active_check() -> void:
	var stabilize_idx: int = _src.find("_stabilize(delta)")
	var active_check_idx: int = _src.find("if not active:", stabilize_idx)
	assert_true(
		stabilize_idx < active_check_idx,
		"_stabilize should run before the active check",
	)


func test_thrust_only_when_active() -> void:
	assert_true(
		_src.contains("if not active:\n\t\treturn"),
		"Thrust/steering should only run when active",
	)


func test_thrust_requires_hull_submerged() -> void:
	assert_true(
		_src.contains("if _is_hull_submerged()"),
		"Thrust should only apply when hull is in water",
	)


func test_emits_vehicle_speed_changed() -> void:
	assert_true(
		_src.contains("EventBus.vehicle_speed_changed.emit"),
		"Should emit vehicle_speed_changed via EventBus",
	)


func test_buoyancy_clamps_depth() -> void:
	assert_true(
		_src.contains("clampf(depth, 0.0, MAX_DEPTH_CLAMP)"),
		"Buoyancy should clamp depth to prevent explosive forces",
	)


func test_stabilize_uses_cross_product() -> void:
	assert_true(
		_src.contains("up.cross(target)"),
		"Stabilization should use cross product",
	)


func test_engine_pivot_visual_steering() -> void:
	assert_true(
		_src.contains('"EnginePivot"'),
		"Should rotate EnginePivot for visual steering",
	)


func test_engine_pivot_sign_matches_thrust_angle() -> void:
	# Both steer_angle (thrust) and engine pivot target_angle must use
	# the same sign (-steer) so the visual pivot agrees with boat turn direction.
	assert_true(
		_src.contains("steer_angle: float = -steer * MAX_STEER_ANGLE"),
		"Thrust steer_angle should be -steer * MAX_STEER_ANGLE",
	)
	assert_true(
		_src.contains("target_angle: float = -steer * MAX_STEER_ANGLE"),
		"Engine pivot target_angle must match thrust sign (-steer)",
	)


func test_wave_height_uses_sin() -> void:
	assert_true(
		_src.contains("WAVE_AMPLITUDE * sin("),
		"Wave height should use sine function",
	)


func test_hull_submerged_check_has_offset() -> void:
	assert_true(
		_src.contains("_get_wave_height(center) + 0.5"),
		"Submerged check should have 0.5 offset",
	)


func test_stabilize_strength_is_800() -> void:
	assert_true(
		_src.contains("stabilize_strength := 800.0"),
		"Stabilization strength should be 800",
	)


func test_stern_offset_for_thrust() -> void:
	assert_true(
		_src.contains("stern_offset := Vector3(0.0, -0.3, 2.5)"),
		"Thrust applied at stern offset",
	)


func test_speed_factor_clamp() -> void:
	assert_true(
		_src.contains("clampf(speed / 3.0, 0.5, 1.0)"),
		"Speed factor should clamp between 0.5 and 1.0",
	)


# ==========================================================================
# Buoyancy CoM offset (C3 fix)
# ==========================================================================


func test_buoyancy_subtracts_center_of_mass() -> void:
	assert_true(
		_src.contains("- _body.center_of_mass"),
		"apply_force offset must subtract center_of_mass for correct torque arm",
	)


func test_buoyancy_uses_local_pt_variable() -> void:
	assert_true(
		_src.contains("var local_pt"),
		"_apply_buoyancy should store the adjusted offset in a local_pt variable",
	)
