extends GutTest
## Tests for EventBus autoload — signal declarations and emission.

const EventBusScript = preload("res://src/autoloads/event_bus.gd")

var _bus: Node


func before_each() -> void:
	_bus = EventBusScript.new()
	_bus.name = "EventBus"
	add_child_autofree(_bus)


# ================================================================
# Signal existence
# ================================================================


func test_player_signals_exist() -> void:
	assert_true(
		_bus.has_signal("player_health_changed"),
		"Should have player_health_changed signal",
	)
	assert_true(
		_bus.has_signal("player_died"),
		"Should have player_died signal",
	)
	assert_true(
		_bus.has_signal("player_respawned"),
		"Should have player_respawned signal",
	)
	assert_true(
		_bus.has_signal("player_money_changed"),
		"Should have player_money_changed signal",
	)


func test_vehicle_signals_exist() -> void:
	assert_true(
		_bus.has_signal("vehicle_entered"),
		"Should have vehicle_entered signal",
	)
	assert_true(
		_bus.has_signal("vehicle_exited"),
		"Should have vehicle_exited signal",
	)
	assert_true(
		_bus.has_signal("vehicle_speed_changed"),
		"Should have vehicle_speed_changed signal",
	)
	assert_true(
		_bus.has_signal("vehicle_damaged"),
		"Should have vehicle_damaged signal",
	)
	assert_true(
		_bus.has_signal("vehicle_destroyed"),
		"Should have vehicle_destroyed signal",
	)
	assert_true(
		_bus.has_signal("force_exit_vehicle"),
		"Should have force_exit_vehicle signal",
	)


func test_wanted_signals_exist() -> void:
	assert_true(
		_bus.has_signal("crime_committed"),
		"Should have crime_committed signal",
	)
	assert_true(
		_bus.has_signal("wanted_level_changed"),
		"Should have wanted_level_changed signal",
	)
	assert_true(
		_bus.has_signal("police_search_started"),
		"Should have police_search_started signal",
	)
	assert_true(
		_bus.has_signal("police_search_ended"),
		"Should have police_search_ended signal",
	)


func test_mission_signals_exist() -> void:
	assert_true(
		_bus.has_signal("mission_available"),
		"Should have mission_available signal",
	)
	assert_true(
		_bus.has_signal("mission_started"),
		"Should have mission_started signal",
	)
	assert_true(
		_bus.has_signal("mission_completed"),
		"Should have mission_completed signal",
	)
	assert_true(
		_bus.has_signal("mission_failed"),
		"Should have mission_failed signal",
	)
	assert_true(
		_bus.has_signal("mission_objective_updated"),
		"Should have mission_objective_updated signal",
	)
	assert_true(
		_bus.has_signal("mission_marker_reached"),
		"Should have mission_marker_reached signal",
	)
	assert_true(
		_bus.has_signal("missions_refreshed"),
		"Should have missions_refreshed signal",
	)
	assert_true(
		_bus.has_signal("mission_timer_updated"),
		"Should have mission_timer_updated signal",
	)


func test_ui_signals_exist() -> void:
	assert_true(
		_bus.has_signal("show_notification"),
		"Should have show_notification signal",
	)
	assert_true(
		_bus.has_signal("show_interaction_prompt"),
		"Should have show_interaction_prompt signal",
	)
	assert_true(
		_bus.has_signal("hide_interaction_prompt"),
		"Should have hide_interaction_prompt signal",
	)


func test_pedestrian_signals_exist() -> void:
	assert_true(
		_bus.has_signal("pedestrian_killed"),
		"Should have pedestrian_killed signal",
	)


func test_water_signals_exist() -> void:
	assert_true(
		_bus.has_signal("player_entered_water"),
		"Should have player_entered_water signal",
	)
	assert_true(
		_bus.has_signal("player_exited_water"),
		"Should have player_exited_water signal",
	)
	assert_true(
		_bus.has_signal("vehicle_entered_water"),
		"Should have vehicle_entered_water signal",
	)


func test_world_signals_exist() -> void:
	assert_true(
		_bus.has_signal("time_of_day_changed"),
		"Should have time_of_day_changed signal",
	)


func test_weapon_signals_exist() -> void:
	assert_true(
		_bus.has_signal("weapon_switched"),
		"Should have weapon_switched signal",
	)
	assert_true(
		_bus.has_signal("weapon_unlocked"),
		"Should have weapon_unlocked signal",
	)


# ================================================================
# Signal emission
# ================================================================


func test_player_health_changed_emits_with_args() -> void:
	var received := []
	_bus.player_health_changed.connect(
		func(cur: float, mx: float) -> void: received.append([cur, mx])
	)
	_bus.player_health_changed.emit(50.0, 100.0)
	assert_eq(received, [[50.0, 100.0]], "Should receive health args")


func test_crime_committed_emits_with_args() -> void:
	var received := []
	_bus.crime_committed.connect(func(ct: String, hp: int) -> void: received.append([ct, hp]))
	_bus.crime_committed.emit("theft", 25)
	assert_eq(received, [["theft", 25]], "Should receive crime args")


func test_mission_started_emits_with_id() -> void:
	var received := []
	_bus.mission_started.connect(func(mid: String) -> void: received.append(mid))
	_bus.mission_started.emit("delivery_123")
	assert_eq(received, ["delivery_123"], "Should receive mission id")


func test_vehicle_entered_emits_with_node() -> void:
	var v := Node.new()
	v.name = "TestVehicle"
	add_child_autofree(v)
	var received := []
	_bus.vehicle_entered.connect(func(vehicle: Node) -> void: received.append(vehicle))
	_bus.vehicle_entered.emit(v)
	assert_eq(received.size(), 1, "Should receive one emission")
	assert_eq(received[0], v, "Should receive the vehicle node")


func test_show_notification_emits_with_args() -> void:
	var received := []
	_bus.show_notification.connect(
		func(text: String, dur: float) -> void: received.append([text, dur])
	)
	_bus.show_notification.emit("Hello", 3.0)
	assert_eq(received, [["Hello", 3.0]], "Should receive notification args")
