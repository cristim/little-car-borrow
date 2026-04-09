extends GutTest
## Unit tests for vehicle_controller.gd — input-to-GEVP mapping.

var _script: GDScript
var _src: String

# Actions that may be pressed during a test — released in after_each.
var _pressed_actions: Array = []


func before_all() -> void:
	_script = load("res://scenes/vehicles/vehicle_controller.gd")
	_src = _script.source_code


func after_each() -> void:
	for action in _pressed_actions:
		Input.action_release(action)
	_pressed_actions.clear()


# --------------------------------------------------------------------------
# Helper: make a plain Node that mimics the GEVP Vehicle properties
# --------------------------------------------------------------------------

func _make_mock_vehicle() -> Node:
	var n := Node.new()
	var scr := GDScript.new()
	scr.source_code = """extends Node
var steering_input: float = 0.0
var throttle_input: float = 0.0
var brake_input: float = 0.0
var handbrake_input: float = 0.0
var current_gear: int = 1
var linear_velocity: Vector3 = Vector3.ZERO
"""
	scr.reload()
	n.set_script(scr)
	add_child_autofree(n)
	return n


func _make_controller() -> Node:
	var ctrl: Node = Node.new()
	ctrl.set_script(_script)
	add_child_autofree(ctrl)
	return ctrl


func _press(action: String) -> void:
	Input.action_press(action)
	_pressed_actions.append(action)


# ==========================================================================
# Initial state
# ==========================================================================


func test_active_defaults_false() -> void:
	var ctrl: Node = _make_controller()
	assert_false(ctrl.active, "Controller should be inactive by default")


func test_vehicle_defaults_null() -> void:
	var ctrl: Node = _make_controller()
	assert_null(ctrl.vehicle, "Vehicle should be null by default")


# ==========================================================================
# Early return when no vehicle
# ==========================================================================


func test_returns_early_without_vehicle() -> void:
	var ctrl: Node = _make_controller()
	ctrl.active = true
	# Must not crash — no vehicle assigned
	ctrl._physics_process(0.016)
	pass_test("No crash when vehicle is null")


# ==========================================================================
# Inactive state: does not touch vehicle inputs
# ==========================================================================


func test_inactive_returns_without_touching_inputs() -> void:
	var ctrl: Node = _make_controller()
	var mock: Node = _make_mock_vehicle()
	ctrl.vehicle = mock
	ctrl.active = false
	# Pre-set known sentinel values
	mock.steering_input = 99.0
	mock.throttle_input = 99.0
	mock.brake_input = 99.0
	mock.handbrake_input = 99.0
	ctrl._physics_process(0.016)
	assert_eq(mock.steering_input, 99.0, "Inactive: steering_input must be untouched")
	assert_eq(mock.throttle_input, 99.0, "Inactive: throttle_input must be untouched")
	assert_eq(mock.brake_input, 99.0, "Inactive: brake_input must be untouched")
	assert_eq(mock.handbrake_input, 99.0, "Inactive: handbrake_input must be untouched")


# ==========================================================================
# Action mapping: actions exist in InputMap
# ==========================================================================


func test_steering_uses_left_and_right() -> void:
	assert_true(InputMap.has_action("move_left"), "InputMap must have move_left")
	assert_true(InputMap.has_action("move_right"), "InputMap must have move_right")


func test_throttle_uses_move_forward() -> void:
	assert_true(InputMap.has_action("move_forward"), "InputMap must have move_forward")


func test_brake_uses_move_backward() -> void:
	assert_true(InputMap.has_action("move_backward"), "InputMap must have move_backward")


func test_handbrake_uses_handbrake_action() -> void:
	assert_true(InputMap.has_action("handbrake"), "InputMap must have handbrake")


# ==========================================================================
# Steering assigned directly from move_left
# ==========================================================================


func test_steering_assigned_directly() -> void:
	var ctrl: Node = _make_controller()
	var mock: Node = _make_mock_vehicle()
	ctrl.vehicle = mock
	ctrl.active = true
	_press("move_left")
	ctrl._physics_process(0.016)
	assert_almost_eq(
		mock.steering_input, 1.0, 0.001,
		"Pressing move_left should give steering_input approx 1.0"
	)


# ==========================================================================
# Handbrake is binary (1.0 pressed / 0.0 released)
# ==========================================================================


func test_handbrake_is_binary() -> void:
	var ctrl: Node = _make_controller()
	var mock: Node = _make_mock_vehicle()
	ctrl.vehicle = mock
	ctrl.active = true

	_press("handbrake")
	ctrl._physics_process(0.016)
	assert_eq(mock.handbrake_input, 1.0, "Handbrake pressed should give handbrake_input == 1.0")

	Input.action_release("handbrake")
	_pressed_actions.erase("handbrake")
	ctrl._physics_process(0.016)
	assert_eq(mock.handbrake_input, 0.0, "Handbrake released should give handbrake_input == 0.0")


# ==========================================================================
# Reverse gear: throttle/brake swapped
# ==========================================================================


func test_reverse_swaps_inputs() -> void:
	var ctrl: Node = _make_controller()
	var mock: Node = _make_mock_vehicle()
	ctrl.vehicle = mock
	ctrl.active = true
	mock.current_gear = -1

	# Press move_forward (throttle axis) while in reverse — brake_input must get the value
	_press("move_forward")
	ctrl._physics_process(0.016)

	assert_almost_eq(
		mock.brake_input, 1.0, 0.001,
		"In reverse, move_forward should drive brake_input"
	)
	assert_almost_eq(
		mock.throttle_input, 0.0, 0.001,
		"In reverse with no move_backward pressed, throttle_input should be 0.0"
	)


# ==========================================================================
# Speed signal: EventBus.vehicle_speed_changed emitted with correct value
# ==========================================================================


func test_emits_vehicle_speed_changed() -> void:
	var ctrl: Node = _make_controller()
	var mock: Node = _make_mock_vehicle()
	ctrl.vehicle = mock
	ctrl.active = true
	# 27.778 m/s ≈ 100 km/h
	mock.linear_velocity = Vector3(27.778, 0.0, 0.0)
	watch_signals(EventBus)
	ctrl._physics_process(0.016)
	assert_signal_emitted(EventBus, "vehicle_speed_changed")


func test_speed_calculated_from_linear_velocity() -> void:
	var ctrl: Node = _make_controller()
	var mock: Node = _make_mock_vehicle()
	ctrl.vehicle = mock
	ctrl.active = true
	mock.linear_velocity = Vector3(27.778, 0.0, 0.0)
	watch_signals(EventBus)
	ctrl._physics_process(0.016)
	var args: Array = get_signal_parameters(EventBus, "vehicle_speed_changed")
	assert_gt(args.size(), 0, "Signal must carry speed argument")
	var speed_kmh: float = args[0]
	assert_almost_eq(speed_kmh, 100.0, 0.5, "Speed should be ≈ 100 km/h for 27.778 m/s input")


# ==========================================================================
# KEPT as source-inspection (structural / metadata checks)
# ==========================================================================


func test_uses_physics_process() -> void:
	assert_true(
		_src.contains("func _physics_process"),
		"Should use _physics_process for deterministic input"
	)


func test_does_not_use_regular_process() -> void:
	assert_false(
		_src.contains("func _process("),
		"Should NOT use _process"
	)


func test_throttle_squared_for_response_curve() -> void:
	assert_true(
		_src.contains("pow(throttle, 2.0)"),
		"Throttle should be squared for progressive response"
	)


func test_vehicle_is_exported() -> void:
	assert_true(
		_src.contains("@export var vehicle"),
		"Vehicle should be an @export var"
	)
