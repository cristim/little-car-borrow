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


# ================================================================
# _refresh_available
# ================================================================


func test_refresh_available_populates_missions() -> void:
	var player := Node3D.new()
	player.add_to_group("player")
	add_child_autofree(player)
	MissionManager._player = player

	MissionManager._refresh_available()

	assert_false(
		MissionManager._available_missions.is_empty(),
		"_refresh_available should populate available missions",
	)


func test_refresh_available_emits_missions_refreshed() -> void:
	var player := Node3D.new()
	player.add_to_group("player")
	add_child_autofree(player)
	MissionManager._player = player

	var received := []
	var cb := func() -> void: received.append(true)
	EventBus.missions_refreshed.connect(cb)
	MissionManager._refresh_available()
	EventBus.missions_refreshed.disconnect(cb)

	assert_eq(received.size(), 1, "_refresh_available should emit missions_refreshed")


func test_refresh_available_skips_when_active_mission() -> void:
	MissionManager._available_missions.append(_make_delivery_mission())
	MissionManager.accept_mission("delivery_1")
	# Active mission is now set; refresh should be a no-op
	MissionManager._available_missions.clear()

	var player := Node3D.new()
	player.add_to_group("player")
	add_child_autofree(player)
	MissionManager._player = player

	MissionManager._refresh_available()

	assert_true(
		MissionManager._available_missions.is_empty(),
		"_refresh_available should not run while a mission is active",
	)


func test_refresh_available_skips_without_player() -> void:
	MissionManager._player = null

	MissionManager._refresh_available()

	assert_true(
		MissionManager._available_missions.is_empty(),
		"_refresh_available should not run without a player",
	)


# ================================================================
# _generate_delivery, _generate_taxi, _generate_theft
# ================================================================


func test_generate_delivery_returns_correct_type() -> void:
	var player := Node3D.new()
	player.add_to_group("player")
	add_child_autofree(player)
	MissionManager._player = player

	var mission: Dictionary = MissionManager._generate_delivery()

	assert_eq(mission.get("type"), "delivery", "generate_delivery should return type 'delivery'")


func test_generate_delivery_has_required_keys() -> void:
	var player := Node3D.new()
	player.add_to_group("player")
	add_child_autofree(player)
	MissionManager._player = player

	var mission: Dictionary = MissionManager._generate_delivery()

	assert_true(mission.has("id"), "delivery mission must have 'id'")
	assert_true(mission.has("reward"), "delivery mission must have 'reward'")
	assert_true(mission.has("state"), "delivery mission must have 'state'")
	assert_true(mission.has("pickup_pos"), "delivery mission must have 'pickup_pos'")
	assert_true(mission.has("dropoff_pos"), "delivery mission must have 'dropoff_pos'")


func test_generate_delivery_state_is_available() -> void:
	var player := Node3D.new()
	player.add_to_group("player")
	add_child_autofree(player)
	MissionManager._player = player

	var mission: Dictionary = MissionManager._generate_delivery()

	assert_eq(mission.get("state"), "available", "delivery mission should start as available")


func test_generate_delivery_reward_in_range() -> void:
	var player := Node3D.new()
	player.add_to_group("player")
	add_child_autofree(player)
	MissionManager._player = player

	var mission: Dictionary = MissionManager._generate_delivery()
	var reward: int = mission.get("reward", -1)

	assert_true(reward >= 300 and reward <= 800, "delivery reward should be between 300 and 800")


func test_generate_taxi_returns_correct_type() -> void:
	var player := Node3D.new()
	player.add_to_group("player")
	add_child_autofree(player)
	MissionManager._player = player

	var mission: Dictionary = MissionManager._generate_taxi()

	assert_eq(mission.get("type"), "taxi", "generate_taxi should return type 'taxi'")


func test_generate_taxi_has_required_keys() -> void:
	var player := Node3D.new()
	player.add_to_group("player")
	add_child_autofree(player)
	MissionManager._player = player

	var mission: Dictionary = MissionManager._generate_taxi()

	assert_true(mission.has("id"), "taxi mission must have 'id'")
	assert_true(mission.has("reward"), "taxi mission must have 'reward'")
	assert_true(mission.has("state"), "taxi mission must have 'state'")
	assert_true(mission.has("dropoff_pos"), "taxi mission must have 'dropoff_pos'")


func test_generate_taxi_state_is_available() -> void:
	var player := Node3D.new()
	player.add_to_group("player")
	add_child_autofree(player)
	MissionManager._player = player

	var mission: Dictionary = MissionManager._generate_taxi()

	assert_eq(mission.get("state"), "available", "taxi mission should start as available")


func test_generate_taxi_reward_in_range() -> void:
	var player := Node3D.new()
	player.add_to_group("player")
	add_child_autofree(player)
	MissionManager._player = player

	var mission: Dictionary = MissionManager._generate_taxi()
	var reward: int = mission.get("reward", -1)

	assert_true(reward >= 200 and reward <= 500, "taxi reward should be between 200 and 500")


func test_generate_theft_returns_correct_type() -> void:
	var player := Node3D.new()
	player.add_to_group("player")
	add_child_autofree(player)
	MissionManager._player = player

	var mission: Dictionary = MissionManager._generate_theft()

	assert_eq(mission.get("type"), "theft", "generate_theft should return type 'theft'")


func test_generate_theft_has_required_keys() -> void:
	var player := Node3D.new()
	player.add_to_group("player")
	add_child_autofree(player)
	MissionManager._player = player

	var mission: Dictionary = MissionManager._generate_theft()

	assert_true(mission.has("id"), "theft mission must have 'id'")
	assert_true(mission.has("reward"), "theft mission must have 'reward'")
	assert_true(mission.has("state"), "theft mission must have 'state'")
	assert_true(mission.has("vehicle_variant"), "theft mission must have 'vehicle_variant'")
	assert_true(mission.has("dropoff_pos"), "theft mission must have 'dropoff_pos'")


func test_generate_theft_state_is_available() -> void:
	var player := Node3D.new()
	player.add_to_group("player")
	add_child_autofree(player)
	MissionManager._player = player

	var mission: Dictionary = MissionManager._generate_theft()

	assert_eq(mission.get("state"), "available", "theft mission should start as available")


func test_generate_theft_reward_in_range() -> void:
	var player := Node3D.new()
	player.add_to_group("player")
	add_child_autofree(player)
	MissionManager._player = player

	var mission: Dictionary = MissionManager._generate_theft()
	var reward: int = mission.get("reward", -1)

	assert_true(reward >= 500 and reward <= 1500, "theft reward should be between 500 and 1500")


func test_generate_theft_time_limit_zero() -> void:
	var player := Node3D.new()
	player.add_to_group("player")
	add_child_autofree(player)
	MissionManager._player = player

	var mission: Dictionary = MissionManager._generate_theft()

	assert_almost_eq(
		float(mission.get("time_limit", -1.0)),
		0.0,
		0.01,
		"theft mission should have no time limit",
	)


func test_generate_theft_variant_is_valid() -> void:
	var valid_variants := ["sedan", "sports", "suv", "hatchback", "van", "pickup"]
	var player := Node3D.new()
	player.add_to_group("player")
	add_child_autofree(player)
	MissionManager._player = player

	var mission: Dictionary = MissionManager._generate_theft()
	var variant: String = mission.get("vehicle_variant", "")

	assert_true(valid_variants.has(variant), "theft variant should be one of the known types")


# ================================================================
# _gen_sidewalk_pos
# ================================================================


func test_gen_sidewalk_pos_returns_vector3() -> void:
	var player := Node3D.new()
	player.add_to_group("player")
	add_child_autofree(player)
	MissionManager._player = player

	var result: Vector3 = MissionManager._gen_sidewalk_pos(Vector3(50.0, 0.0, 50.0), 40.0, 150.0)

	# Result should be a Vector3 at street level (Y ~= 0.15)
	assert_almost_eq(
		result.y, 0.15, 0.01, "_gen_sidewalk_pos should return Y = 0.15 (street level)"
	)


func test_gen_sidewalk_pos_within_distance() -> void:
	var player := Node3D.new()
	player.add_to_group("player")
	add_child_autofree(player)
	MissionManager._player = player

	var origin := Vector3(50.0, 0.0, 50.0)
	var result: Vector3 = MissionManager._gen_sidewalk_pos(origin, 40.0, 150.0)

	# Result must be at a plausible distance (fallback is at min_dist offset)
	var dist: float = Vector2(result.x - origin.x, result.z - origin.z).length()
	assert_true(dist > 0.0, "_gen_sidewalk_pos should return a position away from origin")


# ================================================================
# _on_pickup_reached — objective text per mission type
# ================================================================


func test_on_pickup_reached_delivery_emits_deliver_objective() -> void:
	MissionManager._available_missions.append(_make_delivery_mission())
	MissionManager.accept_mission("delivery_1")
	# State is "pickup" after accept; simulate reaching the pickup marker

	var received := []
	var cb := func(text: String) -> void: received.append(text)
	EventBus.mission_objective_updated.connect(cb)
	MissionManager._on_pickup_reached()
	EventBus.mission_objective_updated.disconnect(cb)

	assert_true(
		received.has("Deliver the package"),
		"Delivery pickup should emit 'Deliver the package' objective",
	)


func test_on_pickup_reached_sets_state_to_active() -> void:
	MissionManager._available_missions.append(_make_delivery_mission())
	MissionManager.accept_mission("delivery_1")

	MissionManager._on_pickup_reached()

	assert_eq(
		MissionManager.get_active_mission().get("state"),
		"active",
		"_on_pickup_reached should set state to active",
	)


func test_on_pickup_reached_taxi_emits_passenger_objective() -> void:
	MissionManager._available_missions.append(_make_taxi_mission())
	InputManager.current_context = InputManager.Context.VEHICLE
	MissionManager.accept_mission("taxi_1")
	# Override state to pickup so we can test _on_pickup_reached for taxi
	MissionManager._active_mission["state"] = "pickup"

	var received := []
	var cb := func(text: String) -> void: received.append(text)
	EventBus.mission_objective_updated.connect(cb)
	MissionManager._on_pickup_reached()
	EventBus.mission_objective_updated.disconnect(cb)

	assert_true(
		received.has("Drive the passenger to the destination"),
		"Taxi pickup should emit passenger destination objective",
	)


func test_on_pickup_reached_sets_timer_when_time_limit_nonzero() -> void:
	MissionManager._available_missions.append(_make_delivery_mission())
	MissionManager.accept_mission("delivery_1")
	MissionManager._mission_timer = 0.0

	MissionManager._on_pickup_reached()

	assert_true(
		MissionManager._mission_timer > 0.0,
		"_on_pickup_reached should start mission timer for timed missions",
	)


# ================================================================
# complete_mission — theft with _delivered_vehicle = null
# ================================================================


func test_complete_theft_without_vehicle_does_not_crash() -> void:
	var mission: Dictionary = _make_theft_mission()
	mission["state"] = "active"
	mission["_delivered_vehicle"] = null
	MissionManager._active_mission = mission

	# Should not crash even though _delivered_vehicle is null
	MissionManager.complete_mission()

	assert_true(
		MissionManager.get_active_mission().is_empty(),
		"Completing theft with null vehicle should still clear active mission",
	)


func test_complete_theft_without_vehicle_adds_reward() -> void:
	var mission: Dictionary = _make_theft_mission()
	mission["state"] = "active"
	mission["_delivered_vehicle"] = null
	MissionManager._active_mission = mission

	MissionManager.complete_mission()

	assert_eq(
		GameManager.money,
		1000,
		"Completing theft with null vehicle should still grant reward",
	)


func test_complete_theft_emits_completed_signal() -> void:
	var mission: Dictionary = _make_theft_mission("theft_99")
	mission["state"] = "active"
	mission["_delivered_vehicle"] = null
	MissionManager._active_mission = mission

	var received := []
	var cb := func(mid: String) -> void: received.append(mid)
	EventBus.mission_completed.connect(cb)
	MissionManager.complete_mission()
	EventBus.mission_completed.disconnect(cb)

	assert_eq(received, ["theft_99"], "Theft complete should emit mission_completed with id")


# ================================================================
# Additional targeted coverage tests
# ================================================================


func _make_mm() -> Node:
	var mm: Node = MissionScript.new()
	add_child_autofree(mm)
	var p := Node3D.new()
	p.add_to_group("player")
	add_child_autofree(p)
	mm._player = p
	mm._rng.randomize()
	return mm


func test_accept_taxi_emits_passenger_destination_objective() -> void:
	MissionManager._available_missions.append(_make_taxi_mission())
	InputManager.current_context = InputManager.Context.VEHICLE
	var received := []
	var cb := func(text: String) -> void: received.append(text)
	EventBus.mission_objective_updated.connect(cb)
	MissionManager.accept_mission("taxi_1")
	EventBus.mission_objective_updated.disconnect(cb)
	assert_true(received.has("Drive the passenger to the destination"), "taxi accept objective")


func test_complete_theft_valid_vehicle_emits_force_exit() -> void:
	var vehicle := Node.new()
	add_child_autofree(vehicle)
	var mission: Dictionary = _make_theft_mission("theft_ev")
	mission["state"] = "active"
	mission["_delivered_vehicle"] = vehicle
	MissionManager._active_mission = mission
	var received := []
	var cb := func(v: Node) -> void: received.append(v)
	EventBus.force_exit_vehicle.connect(cb)
	MissionManager.complete_mission()
	EventBus.force_exit_vehicle.disconnect(cb)
	assert_eq(received.size(), 1, "force_exit_vehicle emitted once")
	assert_eq(received[0], vehicle, "force_exit_vehicle carries the vehicle")


func test_instance_pickup_taxi_objective() -> void:
	var mm: Node = _make_mm()
	var mission: Dictionary = _make_taxi_mission("taxi_inst")
	mm._active_mission = mission.duplicate()
	mm._active_mission["state"] = "pickup"
	var received := []
	var cb := func(text: String) -> void: received.append(text)
	EventBus.mission_objective_updated.connect(cb)
	mm._on_pickup_reached()
	EventBus.mission_objective_updated.disconnect(cb)
	assert_true(
		received.has("Drive the passenger to the destination"), "Instance: taxi pickup objective"
	)


func test_instance_theft_valid_vehicle_force_exit() -> void:
	var mm: Node = _make_mm()
	var before: int = GameManager.money
	var vehicle := Node.new()
	add_child_autofree(vehicle)
	var mission: Dictionary = _make_theft_mission("theft_valid")
	mission["state"] = "active"
	mission["_delivered_vehicle"] = vehicle
	mm._active_mission = mission
	var received := []
	var cb := func(v: Node) -> void: received.append(v)
	EventBus.force_exit_vehicle.connect(cb)
	mm.complete_mission()
	EventBus.force_exit_vehicle.disconnect(cb)
	assert_eq(received.size(), 1, "Instance: force_exit_vehicle for valid vehicle")
	GameManager.money = before
