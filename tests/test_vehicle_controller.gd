extends GutTest
## Unit tests for vehicle_controller.gd — input-to-GEVP mapping.

var _script: GDScript
var _src: String


func before_all() -> void:
	_script = load("res://scenes/vehicles/vehicle_controller.gd")
	_src = _script.source_code


# ==========================================================================
# Initial state
# ==========================================================================

func test_active_defaults_false() -> void:
	var ctrl: Node = Node.new()
	ctrl.set_script(_script)
	add_child_autofree(ctrl)
	assert_false(ctrl.active, "Controller should be inactive by default")


func test_vehicle_defaults_null() -> void:
	var ctrl: Node = Node.new()
	ctrl.set_script(_script)
	add_child_autofree(ctrl)
	assert_null(ctrl.vehicle, "Vehicle should be null by default")


# ==========================================================================
# Inactive state zeros all inputs
# ==========================================================================

func test_inactive_returns_without_touching_inputs() -> void:
	# When inactive, the controller must return early so it does NOT
	# override brake/handbrake values that were set by driving.gd on exit.
	assert_true(
		_src.contains("if not active:") and _src.contains("return"),
		"Inactive state should return early without modifying inputs",
	)


# ==========================================================================
# Active state input mapping
# ==========================================================================

func test_steering_uses_left_and_right() -> void:
	assert_true(_src.contains('"move_left"'), "Should use move_left action")
	assert_true(_src.contains('"move_right"'), "Should use move_right action")


func test_throttle_uses_move_forward() -> void:
	assert_true(
		_src.contains('"move_forward"'),
		"Throttle should use move_forward action",
	)


func test_brake_uses_move_backward() -> void:
	assert_true(
		_src.contains('"move_backward"'),
		"Brake should use move_backward action",
	)


func test_handbrake_uses_handbrake_action() -> void:
	assert_true(
		_src.contains('"handbrake"'),
		"Handbrake should use handbrake action",
	)


func test_throttle_squared_for_response_curve() -> void:
	assert_true(
		_src.contains("pow(throttle, 2.0)"),
		"Throttle should be squared for progressive response",
	)


# ==========================================================================
# Reverse gear logic
# ==========================================================================

func test_reverse_gear_check() -> void:
	assert_true(
		_src.contains("current_gear == -1"),
		"Should check for reverse gear (-1)",
	)


func test_reverse_swaps_throttle_to_brake() -> void:
	assert_true(
		_src.contains("vehicle.throttle_input = brake"),
		"In reverse, throttle mapped from brake input",
	)


func test_reverse_swaps_brake_to_throttle() -> void:
	assert_true(
		_src.contains("vehicle.brake_input = pow(throttle, 2.0)"),
		"In reverse, brake mapped from throttle input",
	)


# ==========================================================================
# Speed emission
# ==========================================================================

func test_emits_vehicle_speed_changed() -> void:
	assert_true(
		_src.contains("EventBus.vehicle_speed_changed.emit"),
		"Should emit vehicle speed via EventBus",
	)


func test_speed_calculated_from_linear_velocity() -> void:
	assert_true(
		_src.contains("vehicle.linear_velocity.length() * 3.6"),
		"Should convert linear velocity to km/h",
	)


# ==========================================================================
# Early return when no vehicle
# ==========================================================================

func test_returns_early_without_vehicle() -> void:
	assert_true(
		_src.contains("if not vehicle:\n\t\treturn"),
		"Should return early when vehicle is null",
	)


# ==========================================================================
# Uses physics process
# ==========================================================================

func test_uses_physics_process() -> void:
	assert_true(
		_src.contains("func _physics_process"),
		"Should use _physics_process for deterministic input",
	)


func test_does_not_use_regular_process() -> void:
	assert_false(
		_src.contains("func _process("),
		"Should NOT use _process",
	)


# ==========================================================================
# Handbrake is binary
# ==========================================================================

func test_handbrake_is_binary() -> void:
	assert_true(
		_src.contains('1.0 if Input.is_action_pressed("handbrake") else 0.0'),
		"Handbrake should be binary (1.0 or 0.0)",
	)


# ==========================================================================
# Steering is direct (not squared)
# ==========================================================================

func test_steering_assigned_directly() -> void:
	assert_true(
		_src.contains("vehicle.steering_input = steer"),
		"Steering should be assigned directly",
	)


# ==========================================================================
# Vehicle export var
# ==========================================================================

func test_vehicle_is_exported() -> void:
	assert_true(
		_src.contains("@export var vehicle"),
		"Vehicle should be an @export var",
	)
