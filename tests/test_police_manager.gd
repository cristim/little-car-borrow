extends GutTest
## Tests for scenes/world/police_manager.gd — constants, wanted level
## scaling, despawn logic, helicopter management, and max police caps.

const PoliceManagerScript = preload("res://scenes/world/police_manager.gd")

# ==========================================================================
# Constants
# ==========================================================================


func test_spawn_radius() -> void:
	assert_eq(PoliceManagerScript.SPAWN_RADIUS, 180.0)


func test_despawn_radius() -> void:
	assert_eq(PoliceManagerScript.DESPAWN_RADIUS, 250.0)


func test_despawn_radius_greater_than_spawn() -> void:
	assert_gt(
		PoliceManagerScript.DESPAWN_RADIUS,
		PoliceManagerScript.SPAWN_RADIUS,
		"Despawn radius must exceed spawn radius",
	)


func test_min_spawn_dist() -> void:
	assert_eq(PoliceManagerScript.MIN_SPAWN_DIST, 40.0)


func test_min_vehicle_dist() -> void:
	assert_eq(PoliceManagerScript.MIN_VEHICLE_DIST, 20.0)


func test_spawn_interval() -> void:
	assert_eq(PoliceManagerScript.SPAWN_INTERVAL, 1.0)


func test_despawn_fade_time() -> void:
	assert_eq(PoliceManagerScript.DESPAWN_FADE_TIME, 10.0)


func test_lod_freeze_dist() -> void:
	assert_eq(PoliceManagerScript.LOD_FREEZE_DIST, 140.0)


func test_sea_level() -> void:
	assert_eq(PoliceManagerScript.SEA_LEVEL, -2.0)


# ==========================================================================
# Initial state
# ==========================================================================


func test_police_array_starts_empty() -> void:
	var mgr: Node = PoliceManagerScript.new()
	add_child_autofree(mgr)
	assert_eq(mgr._police.size(), 0)


func test_player_starts_null() -> void:
	var mgr: Node = PoliceManagerScript.new()
	add_child_autofree(mgr)
	assert_null(mgr._player)


func test_spawn_timer_starts_at_zero() -> void:
	var mgr: Node = PoliceManagerScript.new()
	add_child_autofree(mgr)
	assert_eq(mgr._spawn_timer, 0.0)


func test_despawning_starts_false() -> void:
	var mgr: Node = PoliceManagerScript.new()
	add_child_autofree(mgr)
	assert_false(mgr._despawning)


func test_helicopter_starts_null() -> void:
	var mgr: Node = PoliceManagerScript.new()
	add_child_autofree(mgr)
	assert_null(mgr._helicopter)


# ==========================================================================
# _get_max_police — wanted level scaling
# ==========================================================================


func test_max_police_level_0() -> void:
	var mgr: Node = PoliceManagerScript.new()
	add_child_autofree(mgr)
	var saved := WantedLevelManager.wanted_level
	WantedLevelManager.wanted_level = 0
	assert_eq(
		mgr._get_max_police(),
		0,
		"Level 0 should have 0 police",
	)
	WantedLevelManager.wanted_level = saved


func test_max_police_level_1() -> void:
	var mgr: Node = PoliceManagerScript.new()
	add_child_autofree(mgr)
	var saved := WantedLevelManager.wanted_level
	WantedLevelManager.wanted_level = 1
	assert_eq(mgr._get_max_police(), 3)
	WantedLevelManager.wanted_level = saved


func test_max_police_level_2() -> void:
	var mgr: Node = PoliceManagerScript.new()
	add_child_autofree(mgr)
	var saved := WantedLevelManager.wanted_level
	WantedLevelManager.wanted_level = 2
	assert_eq(mgr._get_max_police(), 5)
	WantedLevelManager.wanted_level = saved


func test_max_police_level_3() -> void:
	var mgr: Node = PoliceManagerScript.new()
	add_child_autofree(mgr)
	var saved := WantedLevelManager.wanted_level
	WantedLevelManager.wanted_level = 3
	assert_eq(mgr._get_max_police(), 8)
	WantedLevelManager.wanted_level = saved


func test_max_police_level_4() -> void:
	var mgr: Node = PoliceManagerScript.new()
	add_child_autofree(mgr)
	var saved := WantedLevelManager.wanted_level
	WantedLevelManager.wanted_level = 4
	assert_eq(mgr._get_max_police(), 12)
	WantedLevelManager.wanted_level = saved


func test_max_police_level_5() -> void:
	var mgr: Node = PoliceManagerScript.new()
	add_child_autofree(mgr)
	var saved := WantedLevelManager.wanted_level
	WantedLevelManager.wanted_level = 5
	assert_eq(mgr._get_max_police(), 16)
	WantedLevelManager.wanted_level = saved


func test_max_police_increases_monotonically() -> void:
	var mgr: Node = PoliceManagerScript.new()
	add_child_autofree(mgr)
	var saved := WantedLevelManager.wanted_level
	var prev := 0
	for level in range(6):
		WantedLevelManager.wanted_level = level
		var current: int = mgr._get_max_police()
		assert_true(
			current >= prev,
			"Max police should not decrease at higher levels",
		)
		prev = current
	WantedLevelManager.wanted_level = saved


func test_max_police_negative_level() -> void:
	var mgr: Node = PoliceManagerScript.new()
	add_child_autofree(mgr)
	var saved := WantedLevelManager.wanted_level
	WantedLevelManager.wanted_level = -1
	assert_eq(
		mgr._get_max_police(),
		0,
		"Negative level should return 0 police",
	)
	WantedLevelManager.wanted_level = saved


func test_max_police_out_of_range_level() -> void:
	var mgr: Node = PoliceManagerScript.new()
	add_child_autofree(mgr)
	var saved := WantedLevelManager.wanted_level
	WantedLevelManager.wanted_level = 99
	assert_eq(
		mgr._get_max_police(),
		0,
		"Out-of-range level should return 0 police",
	)
	WantedLevelManager.wanted_level = saved


# ==========================================================================
# _on_wanted_level_changed callback
# ==========================================================================


func test_wanted_level_zero_starts_despawning() -> void:
	var mgr: Node = PoliceManagerScript.new()
	add_child_autofree(mgr)
	# Add a fake police vehicle to make the list non-empty
	var fake := Node3D.new()
	add_child_autofree(fake)
	mgr._police.append(fake)
	mgr._on_wanted_level_changed(0)
	assert_true(
		mgr._despawning,
		"Level 0 with active police should start despawning",
	)
	assert_eq(mgr._despawn_timer, 0.0)


func test_wanted_level_zero_empty_list_no_despawning() -> void:
	var mgr: Node = PoliceManagerScript.new()
	add_child_autofree(mgr)
	mgr._on_wanted_level_changed(0)
	# Level <= 0 with empty list: condition is `level <= 0 and not _police.is_empty()`
	# Empty list means it won't start despawning
	assert_false(
		mgr._despawning,
		"Level 0 with empty list should not start despawning",
	)


func test_wanted_level_positive_stops_despawning() -> void:
	var mgr: Node = PoliceManagerScript.new()
	add_child_autofree(mgr)
	mgr._despawning = true
	mgr._on_wanted_level_changed(2)
	assert_false(
		mgr._despawning,
		"Positive wanted level should stop despawning",
	)


# ==========================================================================
# _despawn_one
# ==========================================================================


func test_despawn_one_removes_last_vehicle() -> void:
	var mgr: Node = PoliceManagerScript.new()
	add_child_autofree(mgr)
	var v1 := Node3D.new()
	var v2 := Node3D.new()
	add_child_autofree(v1)
	add_child_autofree(v2)
	mgr._police.append(v1)
	mgr._police.append(v2)
	mgr._despawn_one()
	assert_eq(
		mgr._police.size(),
		1,
		"Should remove one vehicle",
	)


func test_despawn_one_on_empty_does_nothing() -> void:
	var mgr: Node = PoliceManagerScript.new()
	add_child_autofree(mgr)
	mgr._despawn_one()
	assert_eq(mgr._police.size(), 0)


# ==========================================================================
# _despawn_far with invalid nodes
# ==========================================================================


func test_despawn_far_removes_distant_vehicles() -> void:
	var mgr: Node = PoliceManagerScript.new()
	add_child_autofree(mgr)

	var player := Node3D.new()
	player.add_to_group("player")
	add_child_autofree(player)
	mgr._player = player

	# Place a police vehicle far beyond DESPAWN_RADIUS
	var v := Node3D.new()
	v.position = Vector3(500.0, 0.0, 0.0)
	add_child_autofree(v)
	mgr._police.append(v)

	mgr._despawn_far()
	assert_eq(
		mgr._police.size(),
		0,
		"Distant vehicles should be despawned",
	)


# ==========================================================================
# _make_terrain_noise static helper
# ==========================================================================


func test_make_terrain_noise_matches_city() -> void:
	var noise: FastNoiseLite = PoliceManagerScript._make_terrain_noise()
	assert_not_null(noise)
	assert_eq(noise.noise_type, FastNoiseLite.TYPE_SIMPLEX_SMOOTH)
	assert_eq(noise.seed, 42)
	assert_almost_eq(noise.frequency, 0.003, 0.0001)
	assert_eq(noise.fractal_octaves, 4)
	assert_almost_eq(noise.fractal_lacunarity, 2.0, 0.01)
	assert_almost_eq(noise.fractal_gain, 0.5, 0.01)


# ==========================================================================
# Helicopter despawn with null/invalid reference
# ==========================================================================


func test_despawn_helicopter_null_clears_ref() -> void:
	var mgr: Node = PoliceManagerScript.new()
	add_child_autofree(mgr)
	mgr._helicopter = null
	mgr._despawn_helicopter()
	assert_null(mgr._helicopter)


func test_despawn_helicopter_invalid_ref_clears() -> void:
	var mgr: Node = PoliceManagerScript.new()
	add_child_autofree(mgr)
	var heli := CharacterBody3D.new()
	mgr._helicopter = heli
	heli.free()
	mgr._despawn_helicopter()
	assert_null(
		mgr._helicopter,
		"Invalid helicopter ref should be cleared",
	)
