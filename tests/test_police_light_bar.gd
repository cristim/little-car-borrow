# gdlint:ignore = max-public-methods
extends GutTest
## Unit tests for police_light_bar.gd — flash timing, light creation,
## and active/inactive toggling.

const LightBarScript = preload("res://scenes/vehicles/police_light_bar.gd")

# ==========================================================================
# Constants
# ==========================================================================


func test_flash_interval_constant() -> void:
	assert_eq(LightBarScript.FLASH_INTERVAL, 0.15)


# ==========================================================================
# Initialization (_ready)
# ==========================================================================


func test_ready_creates_red_light() -> void:
	var bar: Node3D = LightBarScript.new()
	add_child_autofree(bar)
	assert_not_null(bar._red_light, "Red light should be created in _ready")


func test_ready_creates_blue_light() -> void:
	var bar: Node3D = LightBarScript.new()
	add_child_autofree(bar)
	assert_not_null(bar._blue_light, "Blue light should be created in _ready")


func test_red_light_is_omni() -> void:
	var bar: Node3D = LightBarScript.new()
	add_child_autofree(bar)
	assert_true(bar._red_light is OmniLight3D)


func test_blue_light_is_omni() -> void:
	var bar: Node3D = LightBarScript.new()
	add_child_autofree(bar)
	assert_true(bar._blue_light is OmniLight3D)


func test_red_light_color() -> void:
	var bar: Node3D = LightBarScript.new()
	add_child_autofree(bar)
	assert_eq(bar._red_light.light_color, Color(1.0, 0.1, 0.1))


func test_blue_light_color() -> void:
	var bar: Node3D = LightBarScript.new()
	add_child_autofree(bar)
	assert_eq(bar._blue_light.light_color, Color(0.1, 0.2, 1.0))


func test_red_light_energy() -> void:
	var bar: Node3D = LightBarScript.new()
	add_child_autofree(bar)
	assert_eq(bar._red_light.light_energy, 3.0)


func test_blue_light_energy() -> void:
	var bar: Node3D = LightBarScript.new()
	add_child_autofree(bar)
	assert_eq(bar._blue_light.light_energy, 3.0)


func test_red_light_range() -> void:
	var bar: Node3D = LightBarScript.new()
	add_child_autofree(bar)
	assert_eq(bar._red_light.omni_range, 15.0)


func test_blue_light_range() -> void:
	var bar: Node3D = LightBarScript.new()
	add_child_autofree(bar)
	assert_eq(bar._blue_light.omni_range, 15.0)


func test_red_light_position_left() -> void:
	var bar: Node3D = LightBarScript.new()
	add_child_autofree(bar)
	assert_eq(bar._red_light.position, Vector3(-0.4, 0.0, 0.0))


func test_blue_light_position_right() -> void:
	var bar: Node3D = LightBarScript.new()
	add_child_autofree(bar)
	assert_eq(bar._blue_light.position, Vector3(0.4, 0.0, 0.0))


func test_lights_off_after_ready() -> void:
	var bar: Node3D = LightBarScript.new()
	add_child_autofree(bar)
	assert_false(bar._red_light.visible, "Red should be off after _ready")
	assert_false(bar._blue_light.visible, "Blue should be off after _ready")


func test_lights_added_as_children() -> void:
	var bar: Node3D = LightBarScript.new()
	add_child_autofree(bar)
	assert_eq(bar.get_child_count(), 2, "Should have 2 light children")


# ==========================================================================
# Default state
# ==========================================================================


func test_default_lights_active_false() -> void:
	var bar: Node3D = LightBarScript.new()
	add_child_autofree(bar)
	assert_false(bar.lights_active)


func test_default_timer_zero() -> void:
	var bar: Node3D = LightBarScript.new()
	add_child_autofree(bar)
	assert_eq(bar._timer, 0.0)


func test_default_red_on_true() -> void:
	var bar: Node3D = LightBarScript.new()
	add_child_autofree(bar)
	assert_true(bar._red_on)


# ==========================================================================
# _set_lights direct calls
# ==========================================================================


func test_set_lights_red_on_blue_off() -> void:
	var bar: Node3D = LightBarScript.new()
	add_child_autofree(bar)
	bar._set_lights(true, false)
	assert_true(bar._red_light.visible)
	assert_false(bar._blue_light.visible)


func test_set_lights_red_off_blue_on() -> void:
	var bar: Node3D = LightBarScript.new()
	add_child_autofree(bar)
	bar._set_lights(false, true)
	assert_false(bar._red_light.visible)
	assert_true(bar._blue_light.visible)


func test_set_lights_both_on() -> void:
	var bar: Node3D = LightBarScript.new()
	add_child_autofree(bar)
	bar._set_lights(true, true)
	assert_true(bar._red_light.visible)
	assert_true(bar._blue_light.visible)


func test_set_lights_both_off() -> void:
	var bar: Node3D = LightBarScript.new()
	add_child_autofree(bar)
	bar._set_lights(false, false)
	assert_false(bar._red_light.visible)
	assert_false(bar._blue_light.visible)


# ==========================================================================
# _process behavior — inactive
# ==========================================================================


func test_process_inactive_turns_lights_off() -> void:
	var bar: Node3D = LightBarScript.new()
	add_child_autofree(bar)
	# First activate so _lights_were_active is set
	bar.lights_active = true
	bar._process(0.01)
	# Now deactivate — next _process should call _set_lights(false, false)
	bar.lights_active = false
	bar._process(0.05)
	assert_false(bar._red_light.visible)
	assert_false(bar._blue_light.visible)


# ==========================================================================
# _process behavior — active flash toggling
# ==========================================================================


func test_process_active_initial_state_red_on_blue_off() -> void:
	var bar: Node3D = LightBarScript.new()
	add_child_autofree(bar)
	bar.lights_active = true
	# Small delta, timer won't exceed interval
	bar._process(0.01)
	# _red_on starts true, so red visible, blue not
	assert_true(bar._red_light.visible)
	assert_false(bar._blue_light.visible)


func test_process_active_flash_toggles_after_interval() -> void:
	var bar: Node3D = LightBarScript.new()
	add_child_autofree(bar)
	bar.lights_active = true
	# Process with delta exceeding FLASH_INTERVAL
	bar._process(LightBarScript.FLASH_INTERVAL + 0.01)
	# Timer resets, _red_on toggles to false
	assert_false(bar._red_light.visible, "Red should toggle off")
	assert_true(bar._blue_light.visible, "Blue should toggle on")


func test_process_active_double_flash_returns_to_red() -> void:
	var bar: Node3D = LightBarScript.new()
	add_child_autofree(bar)
	bar.lights_active = true
	# First flash: red_on toggles to false
	bar._process(LightBarScript.FLASH_INTERVAL + 0.01)
	assert_false(bar._red_on)
	# Second flash: red_on toggles back to true
	bar._process(LightBarScript.FLASH_INTERVAL + 0.01)
	assert_true(bar._red_on)
	assert_true(bar._red_light.visible)
	assert_false(bar._blue_light.visible)


func test_process_active_timer_resets_on_toggle() -> void:
	var bar: Node3D = LightBarScript.new()
	add_child_autofree(bar)
	bar.lights_active = true
	bar._process(LightBarScript.FLASH_INTERVAL + 0.05)
	assert_eq(bar._timer, 0.0, "Timer should reset after toggle")


func test_process_active_timer_accumulates_under_interval() -> void:
	var bar: Node3D = LightBarScript.new()
	add_child_autofree(bar)
	bar.lights_active = true
	bar._process(0.05)
	assert_almost_eq(bar._timer, 0.05, 0.001)
	bar._process(0.05)
	assert_almost_eq(bar._timer, 0.10, 0.001)
