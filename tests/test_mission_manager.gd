extends GutTest
## Tests for MissionManager autoload — mission lifecycle, marker handling,
## accept/complete/fail, variant identification.
## Uses real autoloads since MissionManager references them by global name.

const MissionScript = preload("res://src/autoloads/mission_manager.gd")

# Saved state for restoration in after_each
var _saved_money: int
var _saved_missions: int
var _saved_earnings: int
var _saved_health: float
var _saved_is_dead: bool
var _saved_context: int
var _saved_wanted: int
var _saved_heat: float


func before_each() -> void:
	# Save global state
	_saved_money = GameManager.money
	_saved_missions = GameManager.missions_completed
	_saved_earnings = GameManager.total_earnings
	_saved_health = GameManager.health
	_saved_is_dead = GameManager.is_dead
	_saved_context = InputManager.current_context
	_saved_wanted = WantedLevelManager.wanted_level
	_saved_heat = WantedLevelManager.heat

	# Reset state for clean tests
	GameManager.money = 0
	GameManager.missions_completed = 0
	GameManager.total_earnings = 0
	GameManager.health = 100.0
	GameManager.is_dead = false
	MissionManager._available_missions.clear()
	MissionManager._active_mission = {}
	MissionManager._refresh_timer = 0.0
	MissionManager._mission_timer = 0.0


func after_each() -> void:
	# Restore global state
	GameManager.money = _saved_money
	GameManager.missions_completed = _saved_missions
	GameManager.total_earnings = _saved_earnings
	GameManager.health = _saved_health
	GameManager.is_dead = _saved_is_dead
	InputManager.current_context = _saved_context
	WantedLevelManager.wanted_level = _saved_wanted
	WantedLevelManager.heat = _saved_heat
	MissionManager._available_missions.clear()
	MissionManager._active_mission = {}
	MissionManager._refresh_timer = 0.0
	MissionManager._mission_timer = 0.0


# ================================================================
# Constants
# ================================================================


func test_refresh_interval() -> void:
	assert_eq(
		MissionScript.REFRESH_INTERVAL,
		20.0,
		"REFRESH_INTERVAL should be 20 seconds",
	)


func test_max_available() -> void:
	assert_eq(
		MissionScript.MAX_AVAILABLE,
		8,
		"MAX_AVAILABLE should be 8",
	)


func test_sidewalk_offset() -> void:
	assert_almost_eq(
		MissionScript.SIDEWALK_OFFSET,
		1.5,
		0.01,
		"SIDEWALK_OFFSET should be 1.5",
	)


# ================================================================
# Helpers
# ================================================================


func _make_delivery_mission(mid: String = "delivery_1") -> Dictionary:
	return {
		"id": mid,
		"type": "delivery",
		"title": "Express Delivery",
		"objective": "Pick up the package",
		"reward": 500,
		"time_limit": 90.0,
		"state": "available",
		"start_pos": Vector3(10, 0, 10),
		"pickup_pos": Vector3(50, 0, 50),
		"dropoff_pos": Vector3(100, 0, 100),
		"vehicle_variant": "",
	}


func _make_taxi_mission(mid: String = "taxi_1") -> Dictionary:
	return {
		"id": mid,
		"type": "taxi",
		"title": "Taxi Fare",
		"objective": "Pick up the passenger",
		"reward": 300,
		"time_limit": 60.0,
		"state": "available",
		"start_pos": Vector3(20, 0, 20),
		"pickup_pos": Vector3(20, 0, 20),
		"dropoff_pos": Vector3(80, 0, 80),
		"vehicle_variant": "",
	}


func _make_theft_mission(mid: String = "theft_1") -> Dictionary:
	return {
		"id": mid,
		"type": "theft",
		"title": "Vehicle Theft",
		"objective": "Steal a sedan and deliver it",
		"reward": 1000,
		"time_limit": 0.0,
		"state": "available",
		"start_pos": Vector3(30, 0, 30),
		"pickup_pos": Vector3.ZERO,
		"dropoff_pos": Vector3(200, 0, 200),
		"vehicle_variant": "sedan",
	}


# ================================================================
# Initial state
# ================================================================


func test_initial_active_mission_empty() -> void:
	assert_true(
		MissionManager.get_active_mission().is_empty(),
		"Active mission should be empty initially",
	)


func test_initial_available_missions_empty() -> void:
	assert_true(
		MissionManager._available_missions.is_empty(),
		"Available missions should be empty initially",
	)


# ================================================================
# accept_mission
# ================================================================


func test_accept_delivery_sets_active() -> void:
	MissionManager._available_missions.append(_make_delivery_mission())
	MissionManager.accept_mission("delivery_1")
	assert_false(
		MissionManager.get_active_mission().is_empty(),
		"Active mission should be set after accept",
	)


func test_accept_delivery_sets_pickup_state() -> void:
	MissionManager._available_missions.append(_make_delivery_mission())
	MissionManager.accept_mission("delivery_1")
	assert_eq(
		MissionManager.get_active_mission().get("state"),
		"pickup",
		"Delivery should start in pickup state",
	)


func test_accept_delivery_clears_available() -> void:
	MissionManager._available_missions.append(_make_delivery_mission())
	MissionManager._available_missions.append(_make_taxi_mission())
	MissionManager.accept_mission("delivery_1")
	assert_true(
		MissionManager._available_missions.is_empty(),
		"Available missions should be cleared on accept",
	)


func test_accept_delivery_emits_started() -> void:
	MissionManager._available_missions.append(_make_delivery_mission())
	var received := []
	var cb := func(mid: String) -> void: received.append(mid)
	EventBus.mission_started.connect(cb)
	MissionManager.accept_mission("delivery_1")
	EventBus.mission_started.disconnect(cb)
	assert_eq(received, ["delivery_1"], "Should emit mission_started")


func test_accept_delivery_emits_objective() -> void:
	MissionManager._available_missions.append(_make_delivery_mission())
	var received := []
	var cb := func(text: String) -> void: received.append(text)
	EventBus.mission_objective_updated.connect(cb)
	MissionManager.accept_mission("delivery_1")
	EventBus.mission_objective_updated.disconnect(cb)
	assert_eq(
		received,
		["Go to the pickup location"],
		"Delivery accept should emit pickup objective",
	)


func test_accept_nonexistent_mission_does_nothing() -> void:
	MissionManager.accept_mission("nonexistent")
	assert_true(
		MissionManager.get_active_mission().is_empty(),
		"Accepting nonexistent mission should not set active",
	)


func test_accept_taxi_requires_vehicle_context() -> void:
	MissionManager._available_missions.append(_make_taxi_mission())
	InputManager.current_context = InputManager.Context.FOOT
	MissionManager.accept_mission("taxi_1")
	assert_true(
		MissionManager.get_active_mission().is_empty(),
		"Taxi mission should not accept when on foot",
	)


func test_accept_taxi_in_vehicle_succeeds() -> void:
	MissionManager._available_missions.append(_make_taxi_mission())
	InputManager.current_context = InputManager.Context.VEHICLE
	MissionManager.accept_mission("taxi_1")
	assert_false(
		MissionManager.get_active_mission().is_empty(),
		"Taxi mission should accept when in vehicle",
	)


func test_accept_taxi_sets_active_state() -> void:
	MissionManager._available_missions.append(_make_taxi_mission())
	InputManager.current_context = InputManager.Context.VEHICLE
	MissionManager.accept_mission("taxi_1")
	assert_eq(
		MissionManager.get_active_mission().get("state"),
		"active",
		"Taxi should skip to active state",
	)


func test_accept_taxi_sets_timer() -> void:
	MissionManager._available_missions.append(_make_taxi_mission())
	InputManager.current_context = InputManager.Context.VEHICLE
	MissionManager.accept_mission("taxi_1")
	assert_almost_eq(
		MissionManager._mission_timer,
		60.0,
		0.01,
		"Taxi timer should be set from time_limit",
	)


func test_accept_theft_sets_pickup_state() -> void:
	MissionManager._available_missions.append(_make_theft_mission())
	MissionManager.accept_mission("theft_1")
	assert_eq(
		MissionManager.get_active_mission().get("state"),
		"pickup",
		"Theft should start in pickup state",
	)


# ================================================================
# complete_mission
# ================================================================


func test_complete_mission_adds_reward() -> void:
	MissionManager._available_missions.append(_make_delivery_mission())
	MissionManager.accept_mission("delivery_1")
	MissionManager._active_mission["state"] = "active"
	MissionManager.complete_mission()
	assert_eq(GameManager.money, 500, "Reward should be added to money")


func test_complete_mission_emits_completed() -> void:
	MissionManager._available_missions.append(_make_delivery_mission())
	MissionManager.accept_mission("delivery_1")
	MissionManager._active_mission["state"] = "active"
	var received := []
	var cb := func(mid: String) -> void: received.append(mid)
	EventBus.mission_completed.connect(cb)
	MissionManager.complete_mission()
	EventBus.mission_completed.disconnect(cb)
	assert_eq(received, ["delivery_1"], "Should emit mission_completed")


func test_complete_mission_clears_active() -> void:
	MissionManager._available_missions.append(_make_delivery_mission())
	MissionManager.accept_mission("delivery_1")
	MissionManager.complete_mission()
	assert_true(
		MissionManager.get_active_mission().is_empty(),
		"Active mission should be cleared after completion",
	)


func test_complete_mission_resets_refresh_timer() -> void:
	MissionManager._refresh_timer = 15.0
	MissionManager._available_missions.append(_make_delivery_mission())
	MissionManager.accept_mission("delivery_1")
	MissionManager.complete_mission()
	assert_eq(
		MissionManager._refresh_timer,
		0.0,
		"Refresh timer should reset after completion",
	)


func test_complete_when_no_active_does_nothing() -> void:
	MissionManager.complete_mission()
	assert_eq(
		GameManager.money,
		0,
		"Completing with no active mission should not change money",
	)


func test_complete_clears_objective() -> void:
	MissionManager._available_missions.append(_make_delivery_mission())
	MissionManager.accept_mission("delivery_1")
	var received := []
	var cb := func(text: String) -> void: received.append(text)
	EventBus.mission_objective_updated.connect(cb)
	MissionManager.complete_mission()
	EventBus.mission_objective_updated.disconnect(cb)
	assert_true(
		received.has(""),
		"Completing should emit empty objective text",
	)


# ================================================================
# fail_mission
# ================================================================


func test_fail_mission_emits_failed() -> void:
	MissionManager._available_missions.append(_make_delivery_mission())
	MissionManager.accept_mission("delivery_1")
	var received := []
	var cb := func(mid: String) -> void: received.append(mid)
	EventBus.mission_failed.connect(cb)
	MissionManager.fail_mission("timeout")
	EventBus.mission_failed.disconnect(cb)
	assert_eq(received, ["delivery_1"], "Should emit mission_failed")


func test_fail_mission_clears_active() -> void:
	MissionManager._available_missions.append(_make_delivery_mission())
	MissionManager.accept_mission("delivery_1")
	MissionManager.fail_mission("timeout")
	assert_true(
		MissionManager.get_active_mission().is_empty(),
		"Active mission should be cleared after failure",
	)


func test_fail_mission_resets_refresh_timer() -> void:
	MissionManager._refresh_timer = 10.0
	MissionManager._available_missions.append(_make_delivery_mission())
	MissionManager.accept_mission("delivery_1")
	MissionManager.fail_mission("restart")
	assert_eq(
		MissionManager._refresh_timer,
		0.0,
		"Refresh timer should reset after failure",
	)


func test_fail_when_no_active_does_nothing() -> void:
	var received := []
	var cb := func(mid: String) -> void: received.append(mid)
	EventBus.mission_failed.connect(cb)
	MissionManager.fail_mission("test")
	EventBus.mission_failed.disconnect(cb)
	assert_eq(
		received.size(),
		0,
		"Failing with no active mission should not emit signal",
	)


func test_fail_clears_objective() -> void:
	MissionManager._available_missions.append(_make_delivery_mission())
	MissionManager.accept_mission("delivery_1")
	var received := []
	var cb := func(text: String) -> void: received.append(text)
	EventBus.mission_objective_updated.connect(cb)
	MissionManager.fail_mission("test")
	EventBus.mission_objective_updated.disconnect(cb)
	assert_true(
		received.has(""),
		"Failing should emit empty objective text",
	)


# ================================================================
# Mission timer (via _process)
# ================================================================


func test_timer_decrements_during_active() -> void:
	MissionManager._available_missions.append(_make_delivery_mission())
	MissionManager.accept_mission("delivery_1")
	MissionManager._active_mission["state"] = "active"
	MissionManager._mission_timer = 90.0
	var player := Node3D.new()
	player.name = "Player"
	player.add_to_group("player")
	add_child_autofree(player)
	MissionManager._player = player

	MissionManager._process(1.0)
	assert_almost_eq(
		MissionManager._mission_timer,
		89.0,
		0.01,
		"Timer should decrement by delta",
	)


func test_timer_timeout_fails_mission() -> void:
	MissionManager._available_missions.append(_make_delivery_mission())
	MissionManager.accept_mission("delivery_1")
	MissionManager._active_mission["state"] = "active"
	MissionManager._mission_timer = 0.5

	var player := Node3D.new()
	player.name = "Player"
	player.add_to_group("player")
	add_child_autofree(player)
	MissionManager._player = player

	var received := []
	var cb := func(mid: String) -> void: received.append(mid)
	EventBus.mission_failed.connect(cb)
	MissionManager._process(1.0)
	EventBus.mission_failed.disconnect(cb)
	assert_eq(
		received.size(),
		1,
		"Timer reaching 0 should fail the mission",
	)


func test_no_timer_when_time_limit_zero() -> void:
	MissionManager._available_missions.append(_make_theft_mission())
	MissionManager.accept_mission("theft_1")
	MissionManager._active_mission["state"] = "active"

	var player := Node3D.new()
	player.name = "Player"
	player.add_to_group("player")
	add_child_autofree(player)
	MissionManager._player = player

	var received := []
	var cb := func(mid: String) -> void: received.append(mid)
	EventBus.mission_failed.connect(cb)
	MissionManager._process(999.0)
	EventBus.mission_failed.disconnect(cb)
	assert_eq(
		received.size(),
		0,
		"Mission with time_limit=0 should not time out",
	)


# ================================================================
# _on_marker_reached
# ================================================================


func test_start_marker_accepts_mission() -> void:
	MissionManager._available_missions.append(_make_delivery_mission())
	MissionManager._on_marker_reached("delivery_1", "start")
	assert_false(
		MissionManager.get_active_mission().is_empty(),
		"Start marker should accept the mission",
	)


func test_pickup_marker_transitions_to_active() -> void:
	MissionManager._available_missions.append(_make_delivery_mission())
	MissionManager.accept_mission("delivery_1")
	assert_eq(MissionManager.get_active_mission().get("state"), "pickup")
	MissionManager._on_marker_reached("delivery_1", "pickup")
	assert_eq(
		MissionManager.get_active_mission().get("state"),
		"active",
		"Pickup marker should transition to active",
	)


func test_dropoff_marker_completes_active_mission() -> void:
	MissionManager._available_missions.append(_make_delivery_mission())
	MissionManager.accept_mission("delivery_1")
	MissionManager._active_mission["state"] = "active"
	MissionManager._on_marker_reached("delivery_1", "dropoff")
	assert_true(
		MissionManager.get_active_mission().is_empty(),
		"Dropoff marker should complete mission",
	)


func test_dropoff_marker_ignored_when_not_active() -> void:
	MissionManager._available_missions.append(_make_delivery_mission())
	MissionManager.accept_mission("delivery_1")
	# State is "pickup", not "active"
	MissionManager._on_marker_reached("delivery_1", "dropoff")
	assert_false(
		MissionManager.get_active_mission().is_empty(),
		"Dropoff should be ignored when state is pickup",
	)


func test_marker_for_wrong_mission_ignored() -> void:
	MissionManager._available_missions.append(_make_delivery_mission())
	MissionManager.accept_mission("delivery_1")
	MissionManager._active_mission["state"] = "active"
	MissionManager._on_marker_reached("wrong_mission", "dropoff")
	assert_false(
		MissionManager.get_active_mission().is_empty(),
		"Marker for wrong mission should be ignored",
	)


# ================================================================
# _on_vehicle_entered (theft mission)
# ================================================================


func test_vehicle_entered_matches_theft_variant() -> void:
	MissionManager._available_missions.append(_make_theft_mission())
	MissionManager.accept_mission("theft_1")
	var vehicle := Node.new()
	vehicle.name = "TestVehicle"
	var body := Node3D.new()
	body.name = "Body"
	body.scale = Vector3(1.0, 1.0, 1.0)  # sedan scale
	vehicle.add_child(body)
	add_child_autofree(vehicle)

	MissionManager._on_vehicle_entered(vehicle)
	assert_eq(
		MissionManager.get_active_mission().get("state"),
		"active",
		"Entering matching vehicle should transition to active",
	)


func test_vehicle_entered_wrong_variant_stays_pickup() -> void:
	MissionManager._available_missions.append(_make_theft_mission())
	MissionManager.accept_mission("theft_1")
	var vehicle := Node.new()
	vehicle.name = "TestVehicle"
	var body := Node3D.new()
	body.name = "Body"
	body.scale = Vector3(1.1, 1.15, 1.05)  # suv scale
	vehicle.add_child(body)
	add_child_autofree(vehicle)

	MissionManager._on_vehicle_entered(vehicle)
	assert_eq(
		MissionManager.get_active_mission().get("state"),
		"pickup",
		"Wrong variant should stay in pickup state",
	)


func test_vehicle_entered_no_body_does_nothing() -> void:
	MissionManager._available_missions.append(_make_theft_mission())
	MissionManager.accept_mission("theft_1")
	var vehicle := Node.new()
	vehicle.name = "TestVehicle"
	add_child_autofree(vehicle)

	MissionManager._on_vehicle_entered(vehicle)
	assert_eq(
		MissionManager.get_active_mission().get("state"),
		"pickup",
		"Vehicle without Body node should stay in pickup",
	)


func test_vehicle_entered_ignored_for_non_theft() -> void:
	MissionManager._available_missions.append(_make_delivery_mission())
	MissionManager.accept_mission("delivery_1")
	var vehicle := Node.new()
	vehicle.name = "TestVehicle"
	add_child_autofree(vehicle)

	MissionManager._on_vehicle_entered(vehicle)
	assert_eq(
		MissionManager.get_active_mission().get("state"),
		"pickup",
		"Vehicle entered should be ignored for delivery missions",
	)


func test_vehicle_entered_ignored_when_no_active_mission() -> void:
	var vehicle := Node.new()
	vehicle.name = "TestVehicle"
	add_child_autofree(vehicle)
	MissionManager._on_vehicle_entered(vehicle)
	assert_true(
		MissionManager.get_active_mission().is_empty(),
		"Should do nothing with no active mission",
	)


# ================================================================
# _identify_variant
# ================================================================


func test_identify_sedan() -> void:
	assert_eq(
		MissionManager._identify_variant(Vector3(1.0, 1.0, 1.0)),
		"sedan",
		"Should identify sedan scale",
	)


func test_identify_sports() -> void:
	assert_eq(
		MissionManager._identify_variant(Vector3(1.05, 0.85, 1.05)),
		"sports",
		"Should identify sports scale",
	)


func test_identify_suv() -> void:
	assert_eq(
		MissionManager._identify_variant(Vector3(1.1, 1.15, 1.05)),
		"suv",
		"Should identify suv scale",
	)


func test_identify_hatchback() -> void:
	assert_eq(
		MissionManager._identify_variant(Vector3(0.95, 1.0, 0.88)),
		"hatchback",
		"Should identify hatchback scale",
	)


func test_identify_van() -> void:
	assert_eq(
		MissionManager._identify_variant(Vector3(1.05, 1.3, 1.15)),
		"van",
		"Should identify van scale",
	)


func test_identify_pickup() -> void:
	assert_eq(
		MissionManager._identify_variant(Vector3(1.1, 1.1, 1.2)),
		"pickup",
		"Should identify pickup scale",
	)


func test_identify_closest_match() -> void:
	var result: String = MissionManager._identify_variant(Vector3(1.01, 0.99, 1.02))
	assert_eq(result, "sedan", "Near-sedan scale should match sedan")


# ================================================================
# _find_available
# ================================================================


func test_find_available_returns_match() -> void:
	MissionManager._available_missions.append(_make_delivery_mission("d1"))
	MissionManager._available_missions.append(_make_taxi_mission("t1"))
	var found: Dictionary = MissionManager._find_available("t1")
	assert_eq(found.get("id"), "t1", "Should find the matching mission")


func test_find_available_returns_empty_on_miss() -> void:
	MissionManager._available_missions.append(_make_delivery_mission("d1"))
	var found: Dictionary = MissionManager._find_available("nonexistent")
	assert_true(found.is_empty(), "Should return empty dict on miss")


# ================================================================
# _gen_sidewalk_pos fallback — street-level Y
# ================================================================


func test_sidewalk_fallback_uses_fixed_street_y() -> void:
	# The fallback position when no valid sidewalk is found must use a
	# fixed Y of 0.15 (street level), never the player's own Y which can
	# be elevated on rooftops or slopes.
	var src: String = MissionScript.source_code
	assert_true(
		src.contains("0.15"),
		"Fallback position in _gen_sidewalk_pos should use Y = 0.15 (street level)",
	)
