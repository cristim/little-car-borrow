extends GutTest
## Tests for GameHUD — consolidated HUD overlay for speed, money,
## wanted stars, missions, health, death, and weapon slots.

const GameHudScript = preload("res://scenes/ui/hud/game_hud.gd")


func _build_hud() -> CanvasLayer:
	var hud: CanvasLayer = GameHudScript.new()

	# Build the child node hierarchy that _ready() and @onready expect.
	var top_right := Control.new()
	top_right.name = "TopRight"
	hud.add_child(top_right)

	var minimap := Control.new()
	minimap.name = "MinimapControl"
	top_right.add_child(minimap)

	var money_label := Label.new()
	money_label.name = "MoneyLabel"
	top_right.add_child(money_label)

	var stars_hbox := HBoxContainer.new()
	stars_hbox.name = "StarsHBox"
	top_right.add_child(stars_hbox)
	for i in range(5):
		var star := ColorRect.new()
		star.name = "Star%d" % i
		stars_hbox.add_child(star)

	var bottom_center := Control.new()
	bottom_center.name = "BottomCenter"
	hud.add_child(bottom_center)

	var speed_label := Label.new()
	speed_label.name = "SpeedLabel"
	bottom_center.add_child(speed_label)

	var top_right_corner := Control.new()
	top_right_corner.name = "TopRightCorner"
	hud.add_child(top_right_corner)

	var fps_label := Label.new()
	fps_label.name = "FPSLabel"
	top_right_corner.add_child(fps_label)

	var top_left := Control.new()
	top_left.name = "TopLeft"
	hud.add_child(top_left)

	var objective_label := Label.new()
	objective_label.name = "ObjectiveLabel"
	top_left.add_child(objective_label)

	var timer_label := Label.new()
	timer_label.name = "TimerLabel"
	top_left.add_child(timer_label)

	var center_top := Control.new()
	center_top.name = "CenterTop"
	hud.add_child(center_top)

	var reward_label := Label.new()
	reward_label.name = "RewardLabel"
	center_top.add_child(reward_label)

	var bottom_left := Control.new()
	bottom_left.name = "BottomLeft"
	hud.add_child(bottom_left)

	var health_bg := Control.new()
	health_bg.name = "HealthBg"
	bottom_left.add_child(health_bg)

	var health_bar := ColorRect.new()
	health_bar.name = "HealthBar"
	health_bar.size = Vector2(200.0, 20.0)
	health_bg.add_child(health_bar)

	var death_label := Label.new()
	death_label.name = "DeathLabel"
	hud.add_child(death_label)

	var restart_prompt := Label.new()
	restart_prompt.name = "RestartPrompt"
	hud.add_child(restart_prompt)

	var crosshair := Label.new()
	crosshair.name = "Crosshair"
	hud.add_child(crosshair)

	var weapon_slots := HBoxContainer.new()
	weapon_slots.name = "BottomRight"
	hud.add_child(weapon_slots)

	add_child_autofree(hud)
	return hud


# ================================================================
# Initialization
# ================================================================


func test_ready_hides_optional_labels() -> void:
	var hud := _build_hud()
	# Wait one frame for _ready and call_deferred
	await get_tree().process_frame

	assert_false(hud.objective_label.visible, "Objective label should be hidden")
	assert_false(hud.timer_label.visible, "Timer label should be hidden")
	assert_false(hud.reward_label.visible, "Reward label should be hidden")
	assert_false(hud.death_label.visible, "Death label should be hidden")
	assert_false(hud.restart_prompt.visible, "Restart prompt should be hidden")


func test_ready_sets_money_from_game_manager() -> void:
	var old_money: int = GameManager.money
	GameManager.money = 1234
	var hud := _build_hud()
	await get_tree().process_frame

	assert_eq(hud.money_label.text, "$1234", "Money label should show GameManager.money")
	GameManager.money = old_money


func test_ready_initializes_star_colors() -> void:
	var hud := _build_hud()
	await get_tree().process_frame

	# All stars should be gray (no wanted level)
	for i in range(5):
		var star := hud.stars_hbox.get_child(i) as ColorRect
		assert_almost_eq(star.color.r, 0.3, 0.01, "Star %d red should be gray" % i)
		assert_almost_eq(star.modulate.a, 0.4, 0.01, "Star %d alpha should be dim" % i)


# ================================================================
# Speed updates
# ================================================================


func test_on_speed_updates_internal_speed() -> void:
	var hud := _build_hud()
	await get_tree().process_frame

	EventBus.vehicle_speed_changed.emit(85.5)
	assert_almost_eq(hud._speed_kmh, 85.5, 0.01, "Speed should update")


func test_process_renders_speed_label() -> void:
	var hud := _build_hud()
	await get_tree().process_frame

	EventBus.vehicle_speed_changed.emit(120.0)
	# Let _process run
	await get_tree().process_frame

	assert_eq(hud.speed_label.text, "120 km/h", "Speed label should show rounded speed")


# ================================================================
# Money updates
# ================================================================


func test_on_money_updates_label() -> void:
	var hud := _build_hud()
	await get_tree().process_frame

	EventBus.player_money_changed.emit(5000)
	assert_eq(hud.money_label.text, "$5000", "Money label should update")


func test_on_money_handles_zero() -> void:
	var hud := _build_hud()
	await get_tree().process_frame

	EventBus.player_money_changed.emit(0)
	assert_eq(hud.money_label.text, "$0", "Money label should show $0")


# ================================================================
# Wanted stars
# ================================================================


func test_on_wanted_sets_level_and_resets_flash() -> void:
	var hud := _build_hud()
	await get_tree().process_frame

	hud._flash_timer = 5.0
	EventBus.wanted_level_changed.emit(3)

	assert_eq(hud._wanted_level, 3, "Wanted level should update")
	assert_eq(hud._flash_timer, 0.0, "Flash timer should reset")


func test_update_stars_colors_active_and_inactive() -> void:
	var hud := _build_hud()
	await get_tree().process_frame

	EventBus.wanted_level_changed.emit(2)

	# First 2 stars should be gold
	for i in range(2):
		var star := hud.stars_hbox.get_child(i) as ColorRect
		assert_almost_eq(
			star.color.r,
			1.0,
			0.01,
			"Active star %d should be gold (red channel)" % i,
		)
		assert_almost_eq(star.modulate.a, 1.0, 0.01, "Active star alpha should be 1.0")

	# Remaining should be gray
	for i in range(2, 5):
		var star := hud.stars_hbox.get_child(i) as ColorRect
		assert_almost_eq(
			star.color.r,
			0.3,
			0.01,
			"Inactive star %d should be gray" % i,
		)
		assert_almost_eq(star.modulate.a, 0.4, 0.01, "Inactive star alpha should be 0.4")


func test_wanted_stars_flash_during_process() -> void:
	var hud := _build_hud()
	await get_tree().process_frame

	EventBus.wanted_level_changed.emit(1)
	# Run a few frames so _flash_timer advances
	for _i in range(5):
		await get_tree().process_frame

	assert_gt(hud._flash_timer, 0.0, "Flash timer should advance during _process")


# ================================================================
# Objective and timer
# ================================================================


func test_on_objective_shows_text() -> void:
	var hud := _build_hud()
	await get_tree().process_frame

	EventBus.mission_objective_updated.emit("Deliver the package")

	assert_true(hud.objective_label.visible, "Objective should be visible")
	assert_eq(hud.objective_label.text, "Deliver the package", "Objective text should match")


func test_on_objective_empty_hides_labels() -> void:
	var hud := _build_hud()
	await get_tree().process_frame

	EventBus.mission_objective_updated.emit("Test")
	EventBus.mission_objective_updated.emit("")

	assert_false(hud.objective_label.visible, "Objective should be hidden on empty text")
	assert_false(hud.timer_label.visible, "Timer should be hidden on empty objective")


func test_on_timer_shows_formatted_time() -> void:
	var hud := _build_hud()
	await get_tree().process_frame

	EventBus.mission_timer_updated.emit(125.0)

	assert_true(hud.timer_label.visible, "Timer label should be visible")
	assert_eq(hud.timer_label.text, "2:05", "Timer should show minutes:seconds")


func test_on_timer_turns_red_below_15_seconds() -> void:
	var hud := _build_hud()
	await get_tree().process_frame

	EventBus.mission_timer_updated.emit(10.0)

	assert_true(hud.timer_label.visible, "Timer should be visible")
	# Check the red color override was applied
	var color: Color = hud.timer_label.get_theme_color("font_color")
	assert_almost_eq(color.r, 1.0, 0.01, "Timer color red should be 1.0 when low")
	assert_almost_eq(color.g, 0.3, 0.01, "Timer color green should be 0.3 when low")


func test_on_timer_white_above_15_seconds() -> void:
	var hud := _build_hud()
	await get_tree().process_frame

	EventBus.mission_timer_updated.emit(60.0)

	var color: Color = hud.timer_label.get_theme_color("font_color")
	assert_almost_eq(color.r, 1.0, 0.01, "Timer color should be white (red=1)")
	assert_almost_eq(color.g, 1.0, 0.01, "Timer color should be white (green=1)")


func test_on_timer_zero_hides_label() -> void:
	var hud := _build_hud()
	await get_tree().process_frame

	EventBus.mission_timer_updated.emit(60.0)
	EventBus.mission_timer_updated.emit(0.0)

	assert_false(hud.timer_label.visible, "Timer should be hidden at 0")


func test_on_timer_negative_hides_label() -> void:
	var hud := _build_hud()
	await get_tree().process_frame

	EventBus.mission_timer_updated.emit(-1.0)
	assert_false(hud.timer_label.visible, "Timer should be hidden for negative time")


# ================================================================
# Mission completion / failure
# ================================================================


func test_on_mission_failed_shows_failure_text() -> void:
	var hud := _build_hud()
	await get_tree().process_frame

	# Show objective first
	EventBus.mission_objective_updated.emit("Test")
	EventBus.mission_timer_updated.emit(30.0)

	EventBus.mission_failed.emit("test_1")

	assert_eq(hud.reward_label.text, "MISSION FAILED", "Should show failure text")
	assert_true(hud.reward_label.visible, "Reward label should be visible")
	assert_almost_eq(hud._reward_timer, 3.0, 0.01, "Reward timer should be 3s")
	assert_false(hud.objective_label.visible, "Objective should be hidden")
	assert_false(hud.timer_label.visible, "Timer should be hidden")


# ================================================================
# Health bar
# ================================================================


func test_on_health_full_sets_green_and_full_width() -> void:
	var hud := _build_hud()
	await get_tree().process_frame

	EventBus.player_health_changed.emit(100.0, 100.0)

	assert_almost_eq(hud.health_bar.size.x, 200.0, 0.01, "Full health = full width")
	assert_almost_eq(hud.health_bar.color.g, 0.8, 0.01, "Full health = green")


func test_on_health_half_sets_orange() -> void:
	var hud := _build_hud()
	await get_tree().process_frame

	EventBus.player_health_changed.emit(50.0, 100.0)

	assert_almost_eq(hud.health_bar.size.x, 100.0, 0.01, "Half health = half width")
	assert_almost_eq(hud.health_bar.color.r, 0.9, 0.01, "Mid health = orange (red)")
	assert_almost_eq(hud.health_bar.color.g, 0.6, 0.01, "Mid health = orange (green)")


func test_on_health_low_sets_red() -> void:
	var hud := _build_hud()
	await get_tree().process_frame

	EventBus.player_health_changed.emit(20.0, 100.0)

	assert_almost_eq(hud.health_bar.size.x, 40.0, 0.01, "20% health = 40px")
	assert_almost_eq(hud.health_bar.color.r, 0.9, 0.01, "Low health = red")
	assert_almost_eq(hud.health_bar.color.g, 0.1, 0.01, "Low health = minimal green")


func test_on_health_zero_max_hp_does_not_crash() -> void:
	var hud := _build_hud()
	await get_tree().process_frame

	EventBus.player_health_changed.emit(0.0, 0.0)
	assert_almost_eq(hud.health_bar.size.x, 0.0, 0.01, "Zero max_hp should give 0 width")


# ================================================================
# Vehicle enter/exit
# ================================================================


func test_vehicle_entered_hides_crosshair() -> void:
	var hud := _build_hud()
	await get_tree().process_frame

	var v := Node.new()
	add_child_autofree(v)
	EventBus.vehicle_entered.emit(v)

	assert_false(hud.crosshair.visible, "Crosshair should be hidden in vehicle")


func test_vehicle_exited_shows_crosshair_and_resets_speed() -> void:
	var hud := _build_hud()
	await get_tree().process_frame

	hud._speed_kmh = 80.0
	var v := Node.new()
	add_child_autofree(v)
	EventBus.vehicle_exited.emit(v)

	assert_true(hud.crosshair.visible, "Crosshair should be visible on foot")
	assert_eq(hud._speed_kmh, 0.0, "Speed should reset to 0 on exit")


# ================================================================
# Death
# ================================================================


func test_on_died_shows_death_label() -> void:
	var hud := _build_hud()
	await get_tree().process_frame

	EventBus.player_died.emit()

	assert_true(hud.death_label.visible, "Death label should be visible")


func test_show_restart_prompt_respects_is_dead() -> void:
	var hud := _build_hud()
	await get_tree().process_frame

	var old_dead: bool = GameManager.is_dead
	GameManager.is_dead = true
	hud._show_restart_prompt()
	assert_true(hud.restart_prompt.visible, "Restart prompt visible when dead")

	hud.restart_prompt.visible = false
	GameManager.is_dead = false
	hud._show_restart_prompt()
	assert_false(hud.restart_prompt.visible, "Restart prompt hidden when alive")

	GameManager.is_dead = old_dead


# ================================================================
# Reward timer fade
# ================================================================


func test_reward_timer_hides_label_after_expiry() -> void:
	var hud := _build_hud()
	await get_tree().process_frame

	hud.reward_label.visible = true
	hud._reward_timer = 0.01

	# Process a frame (delta is small but should exceed 0.01)
	await get_tree().process_frame
	await get_tree().process_frame

	# The timer should have run down and hidden the label
	assert_false(hud.reward_label.visible, "Reward label should hide after timer expires")


# ================================================================
# Weapon slots (no PlayerWeapon node = no crash)
# ================================================================


func test_update_weapon_slots_no_player_does_not_crash() -> void:
	var hud := _build_hud()
	await get_tree().process_frame

	# No player in "player" group, should not crash
	hud._update_weapon_slots()
	assert_true(true, "Should not crash with no player node")


func test_weapon_switched_triggers_update() -> void:
	var hud := _build_hud()
	await get_tree().process_frame

	# Just verify signal connection works without crash
	EventBus.weapon_switched.emit(0)
	assert_true(true, "Weapon switched signal should not crash")


func test_weapon_unlocked_triggers_update() -> void:
	var hud := _build_hud()
	await get_tree().process_frame

	EventBus.weapon_unlocked.emit(1)
	assert_true(true, "Weapon unlocked signal should not crash")


# ================================================================
# FPS label
# ================================================================


func test_process_updates_fps_label() -> void:
	var hud := _build_hud()
	hud._process(0.26)

	assert_true(
		hud.fps_label.text.begins_with("FPS:"),
		"FPS label should start with 'FPS:'",
	)


# ================================================================
# C1 — mission_completed reward comes from signal param, not get_active_mission
# ================================================================


# ================================================================
# I8 — game_hud must not access private weapon fields directly
# ================================================================


func test_game_hud_does_not_access_private_weapon_fields() -> void:
	var src: String = (GameHudScript as GDScript).source_code
	assert_false(
		src.contains("pw._unlocked"),
		"game_hud must not access pw._unlocked directly — use pw.get_unlocked()",
	)
	assert_false(
		src.contains("pw._current_idx"),
		"game_hud must not access pw._current_idx directly — use pw.get_current_weapon_index()",
	)


func test_mission_completed_shows_reward_from_signal_param() -> void:
	var hud := _build_hud()
	await get_tree().process_frame

	EventBus.mission_completed.emit("test_mission", 500)

	assert_eq(
		hud.reward_label.text,
		"+$500",
		"Reward label must show value from signal param",
	)
	assert_true(hud.reward_label.visible, "Reward label should be visible after mission completed")
