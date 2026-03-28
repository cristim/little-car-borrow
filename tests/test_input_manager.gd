extends GutTest
## Tests for InputManager autoload — context switching, state queries.
## Note: Mouse capture tests are skipped in headless mode since
## Input.mouse_mode cannot be changed without a display.

const InputManagerScript = preload("res://src/autoloads/input_manager.gd")

var _im: Node


func before_each() -> void:
	_im = InputManagerScript.new()
	_im.name = "TestInputManager"
	add_child_autofree(_im)


# ================================================================
# Initial state
# ================================================================

func test_initial_context_is_foot() -> void:
	assert_eq(
		_im.current_context, _im.Context.FOOT,
		"Initial context should be FOOT",
	)


# ================================================================
# Context enum values
# ================================================================

func test_context_enum_foot() -> void:
	assert_eq(_im.Context.FOOT, 0, "FOOT should be 0")


func test_context_enum_vehicle() -> void:
	assert_eq(_im.Context.VEHICLE, 1, "VEHICLE should be 1")


func test_context_enum_menu() -> void:
	assert_eq(_im.Context.MENU, 2, "MENU should be 2")


# ================================================================
# set_context
# ================================================================

func test_set_context_to_vehicle() -> void:
	_im.set_context(_im.Context.VEHICLE)
	assert_eq(
		_im.current_context, _im.Context.VEHICLE,
		"set_context should update to VEHICLE",
	)


func test_set_context_to_menu() -> void:
	_im.set_context(_im.Context.MENU)
	assert_eq(
		_im.current_context, _im.Context.MENU,
		"set_context should update to MENU",
	)


func test_set_context_to_foot() -> void:
	_im.set_context(_im.Context.VEHICLE)
	_im.set_context(_im.Context.FOOT)
	assert_eq(
		_im.current_context, _im.Context.FOOT,
		"set_context should update back to FOOT",
	)


# ================================================================
# is_foot / is_vehicle
# ================================================================

func test_is_foot_when_foot() -> void:
	_im.current_context = _im.Context.FOOT
	assert_true(_im.is_foot(), "is_foot should return true in FOOT context")


func test_is_foot_when_vehicle() -> void:
	_im.current_context = _im.Context.VEHICLE
	assert_false(
		_im.is_foot(), "is_foot should return false in VEHICLE context"
	)


func test_is_foot_when_menu() -> void:
	_im.current_context = _im.Context.MENU
	assert_false(
		_im.is_foot(), "is_foot should return false in MENU context"
	)


func test_is_vehicle_when_vehicle() -> void:
	_im.current_context = _im.Context.VEHICLE
	assert_true(
		_im.is_vehicle(), "is_vehicle should return true in VEHICLE context"
	)


func test_is_vehicle_when_foot() -> void:
	_im.current_context = _im.Context.FOOT
	assert_false(
		_im.is_vehicle(), "is_vehicle should return false in FOOT context"
	)


func test_is_vehicle_when_menu() -> void:
	_im.current_context = _im.Context.MENU
	assert_false(
		_im.is_vehicle(), "is_vehicle should return false in MENU context"
	)


# ================================================================
# is_touch
# ================================================================

func test_is_touch_returns_bool() -> void:
	var result: bool = _im.is_touch()
	assert_typeof(result, TYPE_BOOL, "is_touch should return a bool")


# ================================================================
# Touch mode overrides
# ================================================================

func test_touch_mode_context_foot() -> void:
	_im._is_touch = true
	_im.set_context(_im.Context.FOOT)
	assert_eq(
		_im.current_context, _im.Context.FOOT,
		"Touch mode should still set context to FOOT",
	)


func test_touch_mode_context_vehicle() -> void:
	_im._is_touch = true
	_im.set_context(_im.Context.VEHICLE)
	assert_eq(
		_im.current_context, _im.Context.VEHICLE,
		"Touch mode should still set context to VEHICLE",
	)


# ================================================================
# Context round-trips
# ================================================================

func test_context_cycles_correctly() -> void:
	_im.set_context(_im.Context.FOOT)
	assert_true(_im.is_foot(), "Should be FOOT")
	assert_false(_im.is_vehicle(), "Should not be VEHICLE")

	_im.set_context(_im.Context.VEHICLE)
	assert_false(_im.is_foot(), "Should not be FOOT")
	assert_true(_im.is_vehicle(), "Should be VEHICLE")

	_im.set_context(_im.Context.MENU)
	assert_false(_im.is_foot(), "Should not be FOOT in MENU")
	assert_false(_im.is_vehicle(), "Should not be VEHICLE in MENU")
