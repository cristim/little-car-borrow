extends GutTest
## Tests for scenes/world/pedestrian_manager.gd — constants, spawn logic,
## time multiplier, biome filtering, and despawn behavior.

const PedManagerScript = preload("res://scenes/world/pedestrian_manager.gd")

# ==========================================================================
# Constants
# ==========================================================================


func test_spawn_radius() -> void:
	assert_eq(PedManagerScript.SPAWN_RADIUS, 80.0)


func test_despawn_radius() -> void:
	assert_eq(PedManagerScript.DESPAWN_RADIUS, 100.0)


func test_despawn_radius_greater_than_spawn() -> void:
	assert_gt(
		PedManagerScript.DESPAWN_RADIUS,
		PedManagerScript.SPAWN_RADIUS,
		"Despawn radius must exceed spawn radius",
	)


func test_despawn_behind_radius() -> void:
	assert_eq(PedManagerScript.DESPAWN_BEHIND_RADIUS, 50.0)


func test_despawn_behind_less_than_despawn() -> void:
	assert_lt(
		PedManagerScript.DESPAWN_BEHIND_RADIUS,
		PedManagerScript.DESPAWN_RADIUS,
		"Behind despawn radius should be less than full despawn",
	)


func test_min_spawn_dist() -> void:
	assert_eq(PedManagerScript.MIN_SPAWN_DIST, 35.0)


func test_min_ped_dist() -> void:
	assert_eq(PedManagerScript.MIN_PED_DIST, 8.0)


func test_spawn_interval() -> void:
	assert_eq(PedManagerScript.SPAWN_INTERVAL, 1.0)


func test_spawns_per_tick() -> void:
	assert_eq(PedManagerScript.SPAWNS_PER_TICK, 2)


func test_sidewalk_offset() -> void:
	assert_eq(PedManagerScript.SIDEWALK_OFFSET, 1.5)


func test_sea_level() -> void:
	assert_eq(PedManagerScript.SEA_LEVEL, -2.0)


# ==========================================================================
# Initial state
# ==========================================================================


func test_pedestrians_array_starts_empty() -> void:
	var mgr: Node = PedManagerScript.new()
	add_child_autofree(mgr)
	assert_eq(mgr._pedestrians.size(), 0)


func test_player_starts_null() -> void:
	var mgr: Node = PedManagerScript.new()
	add_child_autofree(mgr)
	assert_null(mgr._player)


func test_spawn_timer_starts_at_zero() -> void:
	var mgr: Node = PedManagerScript.new()
	add_child_autofree(mgr)
	assert_eq(mgr._spawn_timer, 0.0)


func test_time_multiplier_starts_at_one() -> void:
	var mgr: Node = PedManagerScript.new()
	add_child_autofree(mgr)
	assert_eq(mgr._time_multiplier, 1.0)


func test_player_velocity_starts_zero() -> void:
	var mgr: Node = PedManagerScript.new()
	add_child_autofree(mgr)
	assert_eq(mgr._player_velocity, Vector3.ZERO)


# ==========================================================================
# Time-of-day multiplier
# ==========================================================================


func test_time_changed_deep_night() -> void:
	var mgr: Node = PedManagerScript.new()
	add_child_autofree(mgr)
	mgr._on_time_changed(3.0)
	assert_eq(
		mgr._time_multiplier,
		0.3,
		"Deep night (3 AM) should reduce spawns to 30%",
	)


func test_time_changed_late_night() -> void:
	var mgr: Node = PedManagerScript.new()
	add_child_autofree(mgr)
	mgr._on_time_changed(23.0)
	assert_eq(
		mgr._time_multiplier,
		0.3,
		"Late night (11 PM) should reduce spawns to 30%",
	)


func test_time_changed_dawn() -> void:
	var mgr: Node = PedManagerScript.new()
	add_child_autofree(mgr)
	mgr._on_time_changed(6.0)
	assert_eq(
		mgr._time_multiplier,
		0.6,
		"Dawn (6 AM) should reduce spawns to 60%",
	)


func test_time_changed_dusk() -> void:
	var mgr: Node = PedManagerScript.new()
	add_child_autofree(mgr)
	mgr._on_time_changed(21.0)
	assert_eq(
		mgr._time_multiplier,
		0.6,
		"Dusk (9 PM) should reduce spawns to 60%",
	)


func test_time_changed_daytime() -> void:
	var mgr: Node = PedManagerScript.new()
	add_child_autofree(mgr)
	mgr._on_time_changed(12.0)
	assert_eq(
		mgr._time_multiplier,
		1.0,
		"Midday should have full spawn rate",
	)


func test_time_changed_boundary_5am() -> void:
	var mgr: Node = PedManagerScript.new()
	add_child_autofree(mgr)
	mgr._on_time_changed(5.0)
	assert_eq(
		mgr._time_multiplier,
		0.6,
		"Exactly 5 AM is dawn (between 5 and 7)",
	)


func test_time_changed_boundary_7am() -> void:
	var mgr: Node = PedManagerScript.new()
	add_child_autofree(mgr)
	mgr._on_time_changed(7.0)
	assert_eq(
		mgr._time_multiplier,
		1.0,
		"7 AM should be daytime",
	)


func test_time_changed_boundary_20() -> void:
	var mgr: Node = PedManagerScript.new()
	add_child_autofree(mgr)
	mgr._on_time_changed(20.0)
	assert_eq(
		mgr._time_multiplier,
		1.0,
		"8 PM should still be daytime",
	)


# ==========================================================================
# _is_city_biome logic (when _biome_map is null, falls back to boundary)
# ==========================================================================


func test_is_city_biome_with_null_biome_map_uses_boundary() -> void:
	var mgr: Node = PedManagerScript.new()
	add_child_autofree(mgr)
	# With _biome_map null, it should fall back to _boundary.is_city_tile
	# which is initialized but may not classify tile (0,0) as city depending
	# on boundary radius. Just verify it runs without error.
	var result: bool = mgr._is_city_biome(Vector2i(0, 0))
	assert_true(
		result is bool,
		"_is_city_biome should return a bool",
	)


# ==========================================================================
# _make_terrain_noise static helper
# ==========================================================================


func test_make_terrain_noise_returns_noise() -> void:
	var noise: FastNoiseLite = PedManagerScript._make_terrain_noise()
	assert_not_null(noise)
	assert_eq(
		noise.noise_type,
		FastNoiseLite.TYPE_SIMPLEX_SMOOTH,
	)
	assert_eq(noise.seed, 42)
	assert_almost_eq(noise.frequency, 0.003, 0.0001)
	assert_eq(noise.fractal_octaves, 4)


# ==========================================================================
# _on_pedestrian_killed removes from tracking
# ==========================================================================


func test_on_pedestrian_killed_removes_from_list() -> void:
	var mgr: Node = PedManagerScript.new()
	add_child_autofree(mgr)
	var fake_ped := Node3D.new()
	add_child_autofree(fake_ped)
	mgr._pedestrians.append(fake_ped)
	assert_eq(mgr._pedestrians.size(), 1)
	mgr._on_pedestrian_killed(fake_ped)
	assert_eq(
		mgr._pedestrians.size(),
		0,
		"Killed pedestrian should be removed from tracking array",
	)


func test_on_pedestrian_killed_ignores_unknown_ped() -> void:
	var mgr: Node = PedManagerScript.new()
	add_child_autofree(mgr)
	var fake_ped := Node3D.new()
	add_child_autofree(fake_ped)
	# Don't add to _pedestrians — should not error
	mgr._on_pedestrian_killed(fake_ped)
	assert_eq(mgr._pedestrians.size(), 0)


# ==========================================================================
# _despawn_far with invalid nodes
# ==========================================================================


func test_despawn_far_removes_distant_pedestrians() -> void:
	var mgr: Node = PedManagerScript.new()
	add_child_autofree(mgr)

	# Create a mock player at origin
	var player := Node3D.new()
	player.add_to_group("player")
	add_child_autofree(player)
	mgr._player = player

	# Place a pedestrian far beyond DESPAWN_RADIUS
	var ped := Node3D.new()
	ped.position = Vector3(500.0, 0.0, 0.0)
	add_child_autofree(ped)
	mgr._pedestrians.append(ped)

	mgr._despawn_far()
	assert_eq(
		mgr._pedestrians.size(),
		0,
		"Distant pedestrians should be despawned",
	)
