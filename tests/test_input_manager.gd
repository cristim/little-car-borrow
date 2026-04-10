extends GutTest
## Tests for InputManager autoload — context switching, state queries.
## Note: Mouse capture tests are skipped in headless mode since
## Input.mouse_mode cannot be changed without a display.

const InputManagerScript = preload("res://src/autoloads/input_manager.gd")

var _im: Node
var _saved_context: int = 0


func before_all() -> void:
	_saved_context = InputManager.current_context


func after_all() -> void:
	InputManager.current_context = _saved_context


func before_each() -> void:
	_im = InputManagerScript.new()
	_im.name = "TestInputManager"
	add_child_autofree(_im)


# ================================================================
# Initial state
# ================================================================


func test_initial_context_is_foot() -> void:
	assert_eq(
		_im.current_context,
		_im.Context.FOOT,
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
		_im.current_context,
		_im.Context.VEHICLE,
		"set_context should update to VEHICLE",
	)


func test_set_context_to_menu() -> void:
	_im.set_context(_im.Context.MENU)
	assert_eq(
		_im.current_context,
		_im.Context.MENU,
		"set_context should update to MENU",
	)


func test_set_context_to_foot() -> void:
	_im.set_context(_im.Context.VEHICLE)
	_im.set_context(_im.Context.FOOT)
	assert_eq(
		_im.current_context,
		_im.Context.FOOT,
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
	assert_false(_im.is_foot(), "is_foot should return false in VEHICLE context")


func test_is_foot_when_menu() -> void:
	_im.current_context = _im.Context.MENU
	assert_false(_im.is_foot(), "is_foot should return false in MENU context")


func test_is_vehicle_when_vehicle() -> void:
	_im.current_context = _im.Context.VEHICLE
	assert_true(_im.is_vehicle(), "is_vehicle should return true in VEHICLE context")


func test_is_vehicle_when_foot() -> void:
	_im.current_context = _im.Context.FOOT
	assert_false(_im.is_vehicle(), "is_vehicle should return false in FOOT context")


func test_is_vehicle_when_menu() -> void:
	_im.current_context = _im.Context.MENU
	assert_false(_im.is_vehicle(), "is_vehicle should return false in MENU context")


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
		_im.current_context,
		_im.Context.FOOT,
		"Touch mode should still set context to FOOT",
	)


func test_touch_mode_context_vehicle() -> void:
	_im._is_touch = true
	_im.set_context(_im.Context.VEHICLE)
	assert_eq(
		_im.current_context,
		_im.Context.VEHICLE,
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


# ================================================================
# _toggle_fullscreen — source code inspection (avoids display side-effects)
# ================================================================


func test_toggle_fullscreen_source_inspection() -> void:
	var src: String = (InputManagerScript as GDScript).source_code
	assert_true(
		src.contains("WINDOW_MODE_FULLSCREEN"),
		"_toggle_fullscreen should reference WINDOW_MODE_FULLSCREEN",
	)
	assert_true(
		src.contains("WINDOW_MODE_WINDOWED"),
		"_toggle_fullscreen should set WINDOW_MODE_WINDOWED when leaving fullscreen",
	)
	assert_true(
		src.contains("SettingsManager.save()"),
		"_toggle_fullscreen should call SettingsManager.save()",
	)
	assert_true(
		src.contains("DisplayServer.window_get_mode()"),
		"_toggle_fullscreen should query current window mode via DisplayServer",
	)


# ================================================================
# _input handler — source code inspection
# ================================================================


func test_input_handler_source_inspection() -> void:
	var src: String = (InputManagerScript as GDScript).source_code
	assert_true(
		src.contains("toggle_fullscreen"),
		"_input should handle toggle_fullscreen action",
	)
	assert_true(
		src.contains("MOUSE_MODE_CAPTURED"),
		"_input should set MOUSE_MODE_CAPTURED when clicking outside MENU context",
	)
	assert_true(
		src.contains("if _is_touch:"),
		"_input should early-return in touch mode",
	)


# ================================================================
# Singleton context switching via InputManager autoload
# ================================================================


func test_singleton_is_foot_returns_bool() -> void:
	InputManager.set_context(InputManager.Context.FOOT)
	assert_typeof(InputManager.is_foot(), TYPE_BOOL, "is_foot on singleton should return bool")


func test_singleton_is_vehicle_returns_bool() -> void:
	InputManager.set_context(InputManager.Context.VEHICLE)
	assert_typeof(
		InputManager.is_vehicle(), TYPE_BOOL, "is_vehicle on singleton should return bool"
	)


func test_singleton_set_context_menu() -> void:
	InputManager.set_context(InputManager.Context.MENU)
	assert_eq(
		InputManager.current_context,
		InputManager.Context.MENU,
		"Singleton context should be MENU",
	)


func test_singleton_set_context_foot() -> void:
	InputManager.set_context(InputManager.Context.MENU)
	InputManager.set_context(InputManager.Context.FOOT)
	assert_eq(
		InputManager.current_context,
		InputManager.Context.FOOT,
		"Singleton context should switch back to FOOT",
	)


func test_singleton_is_touch_returns_bool() -> void:
	var result: bool = InputManager.is_touch()
	assert_typeof(result, TYPE_BOOL, "Singleton is_touch should return bool")


# ================================================================
# Instance-based tests (fresh .new() instances for coverage)
# ================================================================


func test_instance_is_foot_default() -> void:
	var im: Node = InputManagerScript.new()
	add_child_autofree(im)
	assert_true(im.is_foot(), "Default context should be FOOT")


func test_instance_set_context_vehicle() -> void:
	var im: Node = InputManagerScript.new()
	add_child_autofree(im)
	im.set_context(im.Context.VEHICLE)
	assert_true(im.is_vehicle(), "Context VEHICLE should make is_vehicle() true")
	assert_false(im.is_foot(), "Context VEHICLE should make is_foot() false")


func test_instance_set_context_menu() -> void:
	var im: Node = InputManagerScript.new()
	add_child_autofree(im)
	im.set_context(im.Context.MENU)
	assert_eq(im.current_context, im.Context.MENU, "Context should be MENU")
