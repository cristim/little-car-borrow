extends GutTest
## Tests for StealProgressBar — steal/hotwire progress indicator.

const BarScript = preload("res://scenes/ui/hud/steal_progress_bar.gd")


func _build_bar() -> ProgressBar:
	var bar: ProgressBar = BarScript.new()
	add_child_autofree(bar)
	return bar


# ================================================================
# Initialization
# ================================================================


func test_ready_hides_bar() -> void:
	var bar := _build_bar()
	await get_tree().process_frame

	assert_false(bar.visible, "Bar should be hidden on ready")


func test_ready_sets_min_max_value() -> void:
	var bar := _build_bar()
	await get_tree().process_frame

	assert_eq(bar.min_value, 0.0, "Min value should be 0")
	assert_eq(bar.max_value, 1.0, "Max value should be 1")
	assert_eq(bar.value, 0.0, "Value should start at 0")


# ================================================================
# show_progress
# ================================================================


func test_show_progress_makes_visible() -> void:
	var bar := _build_bar()
	await get_tree().process_frame

	bar.show_progress()

	assert_true(bar.visible, "Bar should be visible after show_progress")


func test_show_progress_resets_value() -> void:
	var bar := _build_bar()
	await get_tree().process_frame

	bar.value = 0.75
	bar.show_progress()

	assert_eq(bar.value, 0.0, "Value should reset to 0 on show_progress")


func test_show_progress_when_already_visible() -> void:
	var bar := _build_bar()
	await get_tree().process_frame

	bar.show_progress()
	bar.value = 0.5
	bar.show_progress()

	assert_true(bar.visible, "Bar should remain visible")
	assert_eq(bar.value, 0.0, "Value should reset to 0 even when re-showing")


# ================================================================
# update_progress
# ================================================================


func test_update_progress_sets_value() -> void:
	var bar := _build_bar()
	await get_tree().process_frame

	bar.show_progress()
	bar.update_progress(0.5)

	assert_eq(bar.value, 0.5, "Value should update to 0.5")


func test_update_progress_full() -> void:
	var bar := _build_bar()
	await get_tree().process_frame

	bar.show_progress()
	bar.update_progress(1.0)

	assert_eq(bar.value, 1.0, "Value should be 1.0 at full progress")


func test_update_progress_zero() -> void:
	var bar := _build_bar()
	await get_tree().process_frame

	bar.show_progress()
	bar.update_progress(0.7)
	bar.update_progress(0.0)

	assert_eq(bar.value, 0.0, "Value should return to 0")


func test_update_progress_incremental() -> void:
	var bar := _build_bar()
	await get_tree().process_frame

	bar.show_progress()
	bar.update_progress(0.25)
	assert_eq(bar.value, 0.25, "First increment")

	bar.update_progress(0.50)
	assert_eq(bar.value, 0.50, "Second increment")

	bar.update_progress(0.75)
	assert_eq(bar.value, 0.75, "Third increment")


# ================================================================
# hide_progress
# ================================================================


func test_hide_progress_hides_bar() -> void:
	var bar := _build_bar()
	await get_tree().process_frame

	bar.show_progress()
	bar.hide_progress()

	assert_false(bar.visible, "Bar should be hidden after hide_progress")


func test_hide_progress_resets_value() -> void:
	var bar := _build_bar()
	await get_tree().process_frame

	bar.show_progress()
	bar.update_progress(0.8)
	bar.hide_progress()

	assert_eq(bar.value, 0.0, "Value should reset to 0 on hide_progress")


func test_hide_progress_when_already_hidden() -> void:
	var bar := _build_bar()
	await get_tree().process_frame

	# Already hidden from _ready
	bar.hide_progress()

	assert_false(bar.visible, "Should remain hidden")
	assert_eq(bar.value, 0.0, "Value should be 0")


# ================================================================
# Full lifecycle
# ================================================================


func test_full_show_update_hide_cycle() -> void:
	var bar := _build_bar()
	await get_tree().process_frame

	bar.show_progress()
	assert_true(bar.visible, "Visible after show")
	assert_eq(bar.value, 0.0, "Value 0 after show")

	bar.update_progress(0.33)
	assert_eq(bar.value, 0.33, "Value updated")

	bar.update_progress(0.66)
	assert_eq(bar.value, 0.66, "Value updated again")

	bar.update_progress(1.0)
	assert_eq(bar.value, 1.0, "Value at max")

	bar.hide_progress()
	assert_false(bar.visible, "Hidden after hide")
	assert_eq(bar.value, 0.0, "Value reset after hide")


func test_show_after_hide_restarts_cleanly() -> void:
	var bar := _build_bar()
	await get_tree().process_frame

	bar.show_progress()
	bar.update_progress(0.9)
	bar.hide_progress()

	bar.show_progress()
	assert_true(bar.visible, "Visible on second show")
	assert_eq(bar.value, 0.0, "Value reset on second show")
