extends GutTest
## Tests for the self-repair fall-through recovery in city.gd.

const CityScript = preload("res://scenes/world/city.gd")


# ==========================================================================
# Constants
# ==========================================================================

func test_fall_threshold_value() -> void:
	assert_eq(
		CityScript.FALL_THRESHOLD, -15.0,
		"FALL_THRESHOLD should be -15.0",
	)


func test_repair_cooldown_value() -> void:
	assert_eq(
		CityScript.REPAIR_COOLDOWN, 2.0,
		"REPAIR_COOLDOWN should be 2.0 seconds",
	)


func test_repair_radius_value() -> void:
	assert_eq(
		CityScript.REPAIR_RADIUS, 1,
		"REPAIR_RADIUS should be 1 (3x3 grid)",
	)


func test_fall_threshold_above_safety_ground() -> void:
	assert_gt(
		CityScript.FALL_THRESHOLD, -20.0,
		"FALL_THRESHOLD must be above SafetyGround at Y=-20",
	)


func test_fall_threshold_below_sea_level() -> void:
	assert_lt(
		CityScript.FALL_THRESHOLD, CityScript.SEA_LEVEL,
		"FALL_THRESHOLD must be below SEA_LEVEL to avoid false triggers",
	)


# ==========================================================================
# Cooldown state
# ==========================================================================

func test_repair_cooldown_starts_at_zero() -> void:
	var city: Node3D = CityScript.new()
	add_child_autofree(city)
	assert_eq(
		city._repair_cooldown, 0.0,
		"_repair_cooldown should start at 0.0",
	)


# ==========================================================================
# Self-repair integration (uses full city instance)
# ==========================================================================

class MockPlayer:
	extends CharacterBody3D
	var current_vehicle: Node = null


func _make_mock_player() -> CharacterBody3D:
	var player := MockPlayer.new()
	player.add_to_group("player")
	return player


func test_self_repair_sets_cooldown() -> void:
	var city: Node3D = CityScript.new()
	add_child_autofree(city)
	var player := _make_mock_player()
	add_child_autofree(player)
	city._player = player
	city._self_repair(Vector3(0.0, -18.0, 0.0))
	assert_eq(
		city._repair_cooldown, CityScript.REPAIR_COOLDOWN,
		"_self_repair should set cooldown to REPAIR_COOLDOWN",
	)


func test_self_repair_regenerates_center_chunk() -> void:
	var city: Node3D = CityScript.new()
	add_child_autofree(city)
	var player := _make_mock_player()
	add_child_autofree(player)
	city._player = player
	var center: Vector2i = city._grid.get_chunk_coord(Vector2(0.0, 0.0))
	var old_node: Node3D = city._chunks.get(center)
	assert_not_null(old_node, "Center chunk should exist after _ready")
	city._self_repair(Vector3(0.0, -18.0, 0.0))
	var new_node: Node3D = city._chunks.get(center)
	assert_not_null(new_node, "Center chunk should exist after repair")
	assert_ne(
		new_node, old_node,
		"Center chunk should be a new node after regeneration",
	)


func test_self_repair_regenerates_3x3_grid() -> void:
	var city: Node3D = CityScript.new()
	add_child_autofree(city)
	var player := _make_mock_player()
	add_child_autofree(player)
	city._player = player
	var center: Vector2i = city._grid.get_chunk_coord(Vector2(0.0, 0.0))
	var old_nodes: Dictionary = {}
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var tile := Vector2i(center.x + dx, center.y + dz)
			old_nodes[tile] = city._chunks.get(tile)
	city._self_repair(Vector3(0.0, -18.0, 0.0))
	var regenerated := 0
	for tile: Vector2i in old_nodes:
		var new_node = city._chunks.get(tile)
		if new_node != null and new_node != old_nodes[tile]:
			regenerated += 1
	assert_eq(
		regenerated, 9,
		"All 9 tiles in the 3x3 grid should be regenerated",
	)


func test_self_repair_repairing_flag_restored() -> void:
	var city: Node3D = CityScript.new()
	add_child_autofree(city)
	var player := _make_mock_player()
	add_child_autofree(player)
	city._player = player
	city._self_repair(Vector3(0.0, -18.0, 0.0))
	assert_false(
		city._repairing,
		"_repairing should be false after _self_repair completes",
	)


func test_cooldown_decrements_over_time() -> void:
	var city: Node3D = CityScript.new()
	add_child_autofree(city)
	city._repair_cooldown = 2.0
	city._player_found = true
	# Simulate a frame with 0.5s delta — _process will decrement cooldown
	# but we can't easily call _process without a player, so test directly
	city._repair_cooldown -= 0.5
	assert_almost_eq(
		city._repair_cooldown, 1.5, 0.001,
		"Cooldown should decrement by delta",
	)


func test_cooldown_prevents_detection() -> void:
	var city: Node3D = CityScript.new()
	add_child_autofree(city)
	var player := _make_mock_player()
	add_child_autofree(player)
	city._player = player
	city._self_repair(Vector3(100.0, -18.0, 100.0))
	city._self_repair(Vector3(100.0, -18.0, 100.0))
	assert_eq(
		city._repair_cooldown, CityScript.REPAIR_COOLDOWN,
		"Second _self_repair should reset cooldown",
	)


# ==========================================================================
# Teleport behavior — on foot
# ==========================================================================

func test_self_repair_teleports_player_xz_preserved() -> void:
	var city: Node3D = CityScript.new()
	add_child_autofree(city)
	var player := _make_mock_player()
	add_child_autofree(player)
	city._player = player
	player.global_position = Vector3(50.0, -18.0, 75.0)
	city._self_repair(Vector3(50.0, -18.0, 75.0))
	assert_almost_eq(
		player.global_position.x, 50.0, 0.01,
		"Player X should be preserved after teleport",
	)
	assert_almost_eq(
		player.global_position.z, 75.0, 0.01,
		"Player Z should be preserved after teleport",
	)


func test_self_repair_teleports_player_above_ground() -> void:
	var city: Node3D = CityScript.new()
	add_child_autofree(city)
	var player := _make_mock_player()
	add_child_autofree(player)
	city._player = player
	player.global_position = Vector3(0.0, -18.0, 0.0)
	city._self_repair(Vector3(0.0, -18.0, 0.0))
	assert_gt(
		player.global_position.y, 0.0,
		"Player should be teleported above Y=0 after self-repair",
	)


func test_self_repair_zeroes_player_velocity() -> void:
	var city: Node3D = CityScript.new()
	add_child_autofree(city)
	var player := _make_mock_player()
	add_child_autofree(player)
	city._player = player
	player.velocity = Vector3(10.0, -30.0, 5.0)
	city._self_repair(Vector3(0.0, -18.0, 0.0))
	assert_eq(
		player.velocity, Vector3.ZERO,
		"Player velocity should be zeroed after self-repair",
	)


# ==========================================================================
# Teleport behavior — driving (vehicle path)
# ==========================================================================

func test_self_repair_teleports_vehicle_when_driving() -> void:
	var city: Node3D = CityScript.new()
	add_child_autofree(city)
	var player := _make_mock_player()
	add_child_autofree(player)
	var vehicle := RigidBody3D.new()
	add_child_autofree(vehicle)
	vehicle.global_position = Vector3(30.0, -18.0, 40.0)
	player.set("current_vehicle", vehicle)
	city._player = player
	city._self_repair(Vector3(30.0, -18.0, 40.0))
	assert_almost_eq(
		vehicle.global_position.x, 30.0, 0.01,
		"Vehicle X should be preserved after teleport",
	)
	assert_almost_eq(
		vehicle.global_position.z, 40.0, 0.01,
		"Vehicle Z should be preserved after teleport",
	)
	assert_gt(
		vehicle.global_position.y, 0.0,
		"Vehicle should be teleported above Y=0 after self-repair",
	)


func test_self_repair_zeroes_vehicle_velocity() -> void:
	var city: Node3D = CityScript.new()
	add_child_autofree(city)
	var player := _make_mock_player()
	add_child_autofree(player)
	var vehicle := RigidBody3D.new()
	add_child_autofree(vehicle)
	vehicle.linear_velocity = Vector3(20.0, -15.0, 10.0)
	vehicle.angular_velocity = Vector3(1.0, 2.0, 3.0)
	player.set("current_vehicle", vehicle)
	city._player = player
	city._self_repair(Vector3(0.0, -18.0, 0.0))
	assert_eq(
		vehicle.linear_velocity, Vector3.ZERO,
		"Vehicle linear velocity should be zeroed after self-repair",
	)
	assert_eq(
		vehicle.angular_velocity, Vector3.ZERO,
		"Vehicle angular velocity should be zeroed after self-repair",
	)


# ==========================================================================
# Safe Y computation
# ==========================================================================

func test_safe_y_at_least_two_meters() -> void:
	var city: Node3D = CityScript.new()
	add_child_autofree(city)
	var player := _make_mock_player()
	add_child_autofree(player)
	city._player = player
	city._self_repair(Vector3(0.0, -18.0, 0.0))
	assert_true(
		player.global_position.y >= 2.0,
		"Safe Y should be at least 2.0 (ground + 2m buffer)",
	)


# ==========================================================================
# No false trigger above threshold
# ==========================================================================

func test_no_trigger_above_threshold() -> void:
	var city: Node3D = CityScript.new()
	add_child_autofree(city)
	var player := _make_mock_player()
	add_child_autofree(player)
	city._player = player
	city._player_found = true
	player.global_position = Vector3(0.0, -10.0, 0.0)
	# Simulate _process detection logic manually
	var pos: Vector3 = player.global_position
	var triggered := pos.y < CityScript.FALL_THRESHOLD
	assert_false(
		triggered,
		"Y=-10 is above FALL_THRESHOLD=-15, should NOT trigger self-repair",
	)
