extends GutTest
## Unit tests for player_flashlight.gd — verify automatic on/off behavior.

var _flashlight: SpotLight3D
var _saved_hour: float


func before_each() -> void:
	_saved_hour = DayNightManager.current_hour
	_flashlight = SpotLight3D.new()
	_flashlight.set_script(preload("res://scenes/player/player_flashlight.gd"))
	# Set daytime before adding to tree so _ready() sees daytime
	DayNightManager.current_hour = 8.0
	add_child_autofree(_flashlight)


func after_each() -> void:
	DayNightManager.current_hour = _saved_hour


# ==========================================================================
# Initial state
# ==========================================================================


func test_hidden_at_daytime_8am() -> void:
	assert_false(
		_flashlight.visible,
		"Flashlight should be hidden at 8 AM (daytime)",
	)


func test_hidden_at_noon() -> void:
	DayNightManager.current_hour = 12.0
	_flashlight._update_visibility()
	assert_false(
		_flashlight.visible,
		"Flashlight should be hidden at noon",
	)


# ==========================================================================
# Night visibility
# ==========================================================================


func test_visible_at_night_22h() -> void:
	DayNightManager.current_hour = 22.0
	_flashlight._update_visibility()
	assert_true(
		_flashlight.visible,
		"Flashlight should be visible at 22:00 (night)",
	)


func test_visible_at_night_2am() -> void:
	DayNightManager.current_hour = 2.0
	_flashlight._update_visibility()
	assert_true(
		_flashlight.visible,
		"Flashlight should be visible at 2 AM (night)",
	)


# ==========================================================================
# Dusk / dawn visibility
# ==========================================================================


func test_visible_at_dawn_6am() -> void:
	DayNightManager.current_hour = 6.0
	_flashlight._update_visibility()
	assert_true(
		_flashlight.visible,
		"Flashlight should be visible at 6 AM (dawn)",
	)


func test_visible_at_dusk_18h() -> void:
	DayNightManager.current_hour = 18.0
	_flashlight._update_visibility()
	assert_true(
		_flashlight.visible,
		"Flashlight should be visible at 18:00 (dusk)",
	)


func test_hidden_after_dawn_8am() -> void:
	# 8 AM is outside dusk/dawn range (5-7) and not night
	DayNightManager.current_hour = 8.0
	_flashlight._update_visibility()
	assert_false(
		_flashlight.visible,
		"Flashlight should be hidden at 8 AM (after dawn)",
	)


# ==========================================================================
# Signal response
# ==========================================================================


func test_responds_to_time_of_day_signal() -> void:
	DayNightManager.current_hour = 22.0
	EventBus.time_of_day_changed.emit(22.0)
	assert_true(
		_flashlight.visible,
		"Flashlight should turn on when signal fires at night",
	)


func test_turns_off_when_signal_fires_at_day() -> void:
	# First turn it on
	DayNightManager.current_hour = 22.0
	_flashlight._update_visibility()
	assert_true(_flashlight.visible)
	# Then switch to daytime
	DayNightManager.current_hour = 10.0
	EventBus.time_of_day_changed.emit(10.0)
	assert_false(
		_flashlight.visible,
		"Flashlight should turn off when signal fires at daytime",
	)


# ==========================================================================
# Boundary cases
# ==========================================================================


func test_boundary_night_start_just_after_20() -> void:
	DayNightManager.current_hour = 20.5
	_flashlight._update_visibility()
	assert_true(
		_flashlight.visible,
		"Flashlight should be on at 20:30 (night)",
	)


func test_boundary_dawn_end_at_7() -> void:
	# 7.0 is still within dusk_or_dawn range (5-7)
	DayNightManager.current_hour = 7.0
	_flashlight._update_visibility()
	assert_true(
		_flashlight.visible,
		"Flashlight should be on at 7:00 (dawn boundary)",
	)


func test_boundary_just_after_7() -> void:
	DayNightManager.current_hour = 7.5
	_flashlight._update_visibility()
	assert_false(
		_flashlight.visible,
		"Flashlight should be off at 7:30 (past dawn)",
	)


# ==========================================================================
# look_at degeneration guard (M2 fix)
# ==========================================================================


func test_look_at_source_has_length_squared_guard() -> void:
	var src: String = (_flashlight.get_script() as GDScript).source_code
	assert_true(
		src.contains("length_squared()"),
		"_process should guard look_at with length_squared() check to avoid degenerate case",
	)


func test_look_at_source_has_up_vector_fallback() -> void:
	var src: String = (_flashlight.get_script() as GDScript).source_code
	assert_true(
		src.contains("Vector3.FORWARD"),
		"look_at should fall back to Vector3.FORWARD when pointing straight up/down",
	)


# ==========================================================================
# Driving context guard (M3 fix)
# ==========================================================================


func test_toggle_source_checks_is_foot() -> void:
	var src: String = (_flashlight.get_script() as GDScript).source_code
	assert_true(
		src.contains("InputManager.is_foot()"),
		"toggle_flashlight input should only respond when InputManager.is_foot() is true",
	)


func test_toggle_blocked_when_in_vehicle() -> void:
	# Set night so flashlight would otherwise be on
	DayNightManager.current_hour = 22.0
	_flashlight._update_visibility()
	assert_true(_flashlight.visible, "Precondition: flashlight on at night")
	# Switch to vehicle context
	var saved_ctx := InputManager.current_context
	InputManager.set_context(InputManager.Context.VEHICLE)
	# Simulate toggle
	var ev := InputEventAction.new()
	ev.action = "toggle_flashlight"
	ev.pressed = true
	_flashlight._unhandled_input(ev)
	assert_true(
		_flashlight.visible,
		"Toggle should be ignored while in vehicle context",
	)
	InputManager.set_context(saved_ctx)
