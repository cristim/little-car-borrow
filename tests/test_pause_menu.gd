extends GutTest
## Tests for PauseMenu — pause/resume, panel visibility, context switching.

const PauseMenuScript = preload("res://scenes/ui/menus/pause_menu.gd")


func _build_menu() -> CanvasLayer:
	var menu: CanvasLayer = PauseMenuScript.new()

	var overlay := ColorRect.new()
	overlay.name = "Overlay"
	menu.add_child(overlay)

	var panel := PanelContainer.new()
	panel.name = "Panel"
	menu.add_child(panel)

	var controls_panel := PanelContainer.new()
	controls_panel.name = "ControlsPanel"
	menu.add_child(controls_panel)

	# AudioPanel needs a refresh_sliders method
	var audio_panel := PanelContainer.new()
	audio_panel.name = "AudioPanel"
	audio_panel.set_script(_audio_panel_stub())
	menu.add_child(audio_panel)

	add_child_autofree(menu)
	return menu


func _audio_panel_stub() -> GDScript:
	# Minimal stub with refresh_sliders method
	var script := GDScript.new()
	script.source_code = "extends PanelContainer\nfunc refresh_sliders() -> void:\n\tpass\n"
	script.reload()
	return script


func after_each() -> void:
	# Ensure tree is unpaused after each test
	get_tree().paused = false


# ================================================================
# Initialization
# ================================================================


func test_ready_hides_everything() -> void:
	var menu := _build_menu()
	await get_tree().process_frame

	assert_false(menu.visible, "Menu should be hidden")
	assert_false(menu.get_node("Overlay").visible, "Overlay should be hidden")
	assert_false(menu.get_node("Panel").visible, "Panel should be hidden")


func test_ready_sets_process_mode_always() -> void:
	var menu := _build_menu()
	await get_tree().process_frame

	assert_eq(
		menu.process_mode,
		Node.PROCESS_MODE_ALWAYS,
		"Process mode should be ALWAYS to work when paused",
	)


# ================================================================
# Pause
# ================================================================


func test_pause_shows_overlay_and_panel() -> void:
	var menu := _build_menu()
	await get_tree().process_frame

	menu._pause()

	assert_true(menu.visible, "Menu should be visible when paused")
	assert_true(menu.get_node("Overlay").visible, "Overlay should be visible")
	assert_true(menu.get_node("Panel").visible, "Panel should be visible")


func test_pause_hides_sub_panels() -> void:
	var menu := _build_menu()
	await get_tree().process_frame

	menu._pause()

	assert_false(
		menu.get_node("ControlsPanel").visible,
		"Controls panel should be hidden on pause",
	)
	assert_false(
		menu.get_node("AudioPanel").visible,
		"Audio panel should be hidden on pause",
	)


func test_pause_pauses_tree() -> void:
	var menu := _build_menu()
	await get_tree().process_frame

	menu._pause()

	assert_true(get_tree().paused, "Scene tree should be paused")


func test_pause_sets_menu_context() -> void:
	var menu := _build_menu()
	await get_tree().process_frame

	var old_ctx: int = InputManager.current_context
	menu._pause()

	assert_eq(
		InputManager.current_context,
		InputManager.Context.MENU,
		"Context should be MENU when paused",
	)

	# Clean up
	menu._resume()
	InputManager.set_context(old_ctx)


func test_pause_saves_previous_context() -> void:
	var menu := _build_menu()
	await get_tree().process_frame

	var old_ctx: int = InputManager.current_context
	InputManager.set_context(InputManager.Context.VEHICLE)
	menu._pause()

	assert_eq(
		menu._previous_context,
		InputManager.Context.VEHICLE,
		"Should save previous context",
	)

	# Clean up
	menu._resume()
	InputManager.set_context(old_ctx)


# ================================================================
# Resume
# ================================================================


func test_resume_hides_everything() -> void:
	var menu := _build_menu()
	await get_tree().process_frame

	menu._pause()
	menu._resume()

	assert_false(menu.visible, "Menu should be hidden after resume")
	assert_false(menu.get_node("Overlay").visible, "Overlay hidden")
	assert_false(menu.get_node("Panel").visible, "Panel hidden")
	assert_false(menu.get_node("ControlsPanel").visible, "Controls hidden")
	assert_false(menu.get_node("AudioPanel").visible, "Audio hidden")


func test_resume_unpauses_tree() -> void:
	var menu := _build_menu()
	await get_tree().process_frame

	menu._pause()
	menu._resume()

	assert_false(get_tree().paused, "Tree should be unpaused after resume")


func test_resume_restores_previous_context() -> void:
	var menu := _build_menu()
	await get_tree().process_frame

	var old_ctx: int = InputManager.current_context
	InputManager.set_context(InputManager.Context.VEHICLE)
	menu._pause()
	menu._resume()

	assert_eq(
		InputManager.current_context,
		InputManager.Context.VEHICLE,
		"Context should be restored to VEHICLE",
	)

	InputManager.set_context(old_ctx)


func test_resume_restores_foot_context() -> void:
	var menu := _build_menu()
	await get_tree().process_frame

	var old_ctx: int = InputManager.current_context
	InputManager.set_context(InputManager.Context.FOOT)
	menu._pause()
	menu._resume()

	assert_eq(
		InputManager.current_context,
		InputManager.Context.FOOT,
		"Context should be restored to FOOT",
	)

	InputManager.set_context(old_ctx)


# ================================================================
# Resume button
# ================================================================


func test_on_resume_pressed_calls_resume() -> void:
	var menu := _build_menu()
	await get_tree().process_frame

	menu._pause()
	menu._on_resume_pressed()

	assert_false(get_tree().paused, "Resume button should unpause")
	assert_false(menu.visible, "Resume button should hide menu")


# ================================================================
# Controls sub-panel
# ================================================================


func test_on_controls_pressed_shows_controls_panel() -> void:
	var menu := _build_menu()
	await get_tree().process_frame

	menu._pause()
	menu._on_controls_pressed()

	assert_false(menu.get_node("Panel").visible, "Main panel hidden")
	assert_true(menu.get_node("ControlsPanel").visible, "Controls panel visible")


# ================================================================
# Audio sub-panel
# ================================================================


func test_on_audio_pressed_shows_audio_panel() -> void:
	var menu := _build_menu()
	await get_tree().process_frame

	menu._pause()
	menu._on_audio_pressed()

	assert_false(menu.get_node("Panel").visible, "Main panel hidden")
	assert_true(menu.get_node("AudioPanel").visible, "Audio panel visible")


# ================================================================
# Pause/resume cycle
# ================================================================


func test_pause_resume_pause_cycle() -> void:
	var menu := _build_menu()
	await get_tree().process_frame

	menu._pause()
	assert_true(get_tree().paused, "Paused first time")

	menu._resume()
	assert_false(get_tree().paused, "Resumed")

	menu._pause()
	assert_true(get_tree().paused, "Paused second time")
	assert_true(menu.visible, "Menu visible on second pause")

	menu._resume()
	assert_false(get_tree().paused, "Resumed again")


# ================================================================
# Initial previous context default
# ================================================================


func test_default_previous_context_is_foot() -> void:
	var menu := _build_menu()
	assert_eq(
		menu._previous_context,
		InputManager.Context.FOOT,
		"Default previous context should be FOOT",
	)
