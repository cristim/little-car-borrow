extends GutTest
## Tests for scenes/world/traffic_manager.gd — constants, variant weights,
## biome filtering, time multiplier, material init, and despawn logic.

const TrafficManagerScript = preload("res://scenes/world/traffic_manager.gd")

# ==========================================================================
# Constants
# ==========================================================================


func test_spawn_radius() -> void:
	assert_eq(TrafficManagerScript.SPAWN_RADIUS, 150.0)


func test_despawn_radius() -> void:
	assert_eq(TrafficManagerScript.DESPAWN_RADIUS, 180.0)


func test_despawn_radius_greater_than_spawn() -> void:
	assert_gt(
		TrafficManagerScript.DESPAWN_RADIUS,
		TrafficManagerScript.SPAWN_RADIUS,
		"Despawn radius must exceed spawn radius",
	)


func test_despawn_behind_radius() -> void:
	assert_eq(TrafficManagerScript.DESPAWN_BEHIND_RADIUS, 70.0)


func test_min_spawn_dist() -> void:
	assert_eq(TrafficManagerScript.MIN_SPAWN_DIST, 80.0)


func test_min_vehicle_dist() -> void:
	assert_eq(TrafficManagerScript.MIN_VEHICLE_DIST, 18.0)


func test_spawn_interval() -> void:
	assert_eq(TrafficManagerScript.SPAWN_INTERVAL, 1.0)


func test_spawns_per_tick() -> void:
	assert_eq(TrafficManagerScript.SPAWNS_PER_TICK, 2)


func test_lod_freeze_dist() -> void:
	assert_eq(TrafficManagerScript.LOD_FREEZE_DIST, 140.0)


func test_sea_level() -> void:
	assert_eq(TrafficManagerScript.SEA_LEVEL, -2.0)


func test_glass_color() -> void:
	assert_eq(
		TrafficManagerScript.GLASS_COLOR,
		Color(0.6, 0.75, 0.85, 0.4),
	)


func test_interior_color() -> void:
	assert_eq(
		TrafficManagerScript.INTERIOR_COLOR,
		Color(0.12, 0.12, 0.12, 1),
	)


func test_highway_indices() -> void:
	assert_eq(
		TrafficManagerScript.HIGHWAY_INDICES,
		[0, 5],
		"Highway indices should be [0, 5]",
	)


# ==========================================================================
# Vehicle variants
# ==========================================================================


func test_six_variants_defined() -> void:
	assert_eq(
		TrafficManagerScript.VARIANTS.size(),
		6,
		"Should have 6 body variants",
	)


func test_variant_names() -> void:
	var names: Array[String] = []
	for v in TrafficManagerScript.VARIANTS:
		names.append(v.name)
	assert_has(names, "sedan")
	assert_has(names, "sports")
	assert_has(names, "suv")
	assert_has(names, "hatchback")
	assert_has(names, "van")
	assert_has(names, "pickup")


func test_all_variants_have_positive_weight() -> void:
	for v in TrafficManagerScript.VARIANTS:
		assert_gt(
			v.weight,
			0,
			"Variant %s should have positive weight" % v.name,
		)


func test_all_variants_have_positive_mass_mult() -> void:
	for v in TrafficManagerScript.VARIANTS:
		assert_gt(
			v.mass_mult,
			0.0,
			"Variant %s should have positive mass multiplier" % v.name,
		)


func test_sedan_has_highest_weight() -> void:
	var sedan_weight := 0
	for v in TrafficManagerScript.VARIANTS:
		if v.name == "sedan":
			sedan_weight = v.weight
	var max_weight := 0
	for v in TrafficManagerScript.VARIANTS:
		if v.weight > max_weight:
			max_weight = v.weight
	assert_eq(
		sedan_weight,
		max_weight,
		"Sedan should have the highest spawn weight",
	)


func test_total_weight_is_sum_of_all() -> void:
	var expected := 0
	for v in TrafficManagerScript.VARIANTS:
		expected += v.weight
	assert_eq(expected, 11, "Total variant weight should be 11")


# ==========================================================================
# Initial state
# ==========================================================================


func test_vehicles_array_starts_empty() -> void:
	var mgr: Node = TrafficManagerScript.new()
	add_child_autofree(mgr)
	assert_eq(mgr._vehicles.size(), 0)


func test_player_starts_null() -> void:
	var mgr: Node = TrafficManagerScript.new()
	add_child_autofree(mgr)
	assert_null(mgr._player)


func test_spawn_timer_starts_at_zero() -> void:
	var mgr: Node = TrafficManagerScript.new()
	add_child_autofree(mgr)
	assert_eq(mgr._spawn_timer, 0.0)


func test_time_multiplier_starts_at_one() -> void:
	var mgr: Node = TrafficManagerScript.new()
	add_child_autofree(mgr)
	assert_eq(mgr._time_multiplier, 1.0)


func test_player_velocity_starts_zero() -> void:
	var mgr: Node = TrafficManagerScript.new()
	add_child_autofree(mgr)
	assert_eq(mgr._player_velocity, Vector3.ZERO)


# ==========================================================================
# _is_road_grid_biome static helper
# ==========================================================================


func test_is_road_grid_biome_city_center() -> void:
	assert_true(
		TrafficManagerScript._is_road_grid_biome("city_center"),
	)


func test_is_road_grid_biome_residential() -> void:
	assert_true(
		TrafficManagerScript._is_road_grid_biome("residential"),
	)


func test_is_road_grid_biome_suburb() -> void:
	assert_true(
		TrafficManagerScript._is_road_grid_biome("suburb"),
	)


func test_is_road_grid_biome_farmland_false() -> void:
	assert_false(
		TrafficManagerScript._is_road_grid_biome("farmland"),
	)


func test_is_road_grid_biome_forest_false() -> void:
	assert_false(
		TrafficManagerScript._is_road_grid_biome("forest"),
	)


func test_is_road_grid_biome_village_false() -> void:
	assert_false(
		TrafficManagerScript._is_road_grid_biome("village"),
	)


func test_is_road_grid_biome_ocean_false() -> void:
	assert_false(
		TrafficManagerScript._is_road_grid_biome("ocean"),
	)


func test_is_road_grid_biome_mountain_false() -> void:
	assert_false(
		TrafficManagerScript._is_road_grid_biome("mountain"),
	)


func test_is_road_grid_biome_empty_false() -> void:
	assert_false(
		TrafficManagerScript._is_road_grid_biome(""),
	)


# ==========================================================================
# Time-of-day multiplier
# ==========================================================================


func test_time_changed_deep_night() -> void:
	var mgr: Node = TrafficManagerScript.new()
	add_child_autofree(mgr)
	mgr._on_time_changed(2.0)
	assert_eq(mgr._time_multiplier, 0.5)


func test_time_changed_late_night() -> void:
	var mgr: Node = TrafficManagerScript.new()
	add_child_autofree(mgr)
	mgr._on_time_changed(23.0)
	assert_eq(mgr._time_multiplier, 0.5)


func test_time_changed_dawn() -> void:
	var mgr: Node = TrafficManagerScript.new()
	add_child_autofree(mgr)
	mgr._on_time_changed(6.0)
	assert_eq(mgr._time_multiplier, 0.7)


func test_time_changed_dusk() -> void:
	var mgr: Node = TrafficManagerScript.new()
	add_child_autofree(mgr)
	mgr._on_time_changed(21.0)
	assert_eq(mgr._time_multiplier, 0.7)


func test_time_changed_daytime() -> void:
	var mgr: Node = TrafficManagerScript.new()
	add_child_autofree(mgr)
	mgr._on_time_changed(12.0)
	assert_eq(mgr._time_multiplier, 1.0)


func test_time_changed_boundary_5am() -> void:
	var mgr: Node = TrafficManagerScript.new()
	add_child_autofree(mgr)
	mgr._on_time_changed(5.0)
	assert_eq(
		mgr._time_multiplier,
		0.7,
		"Exactly 5 AM is dawn (between 5 and 7)",
	)


func test_time_changed_boundary_7am() -> void:
	var mgr: Node = TrafficManagerScript.new()
	add_child_autofree(mgr)
	mgr._on_time_changed(7.0)
	assert_eq(mgr._time_multiplier, 1.0)


# ==========================================================================
# _on_vehicle_stolen callback
# ==========================================================================


func test_on_vehicle_stolen_removes_from_list() -> void:
	var mgr: Node = TrafficManagerScript.new()
	add_child_autofree(mgr)
	var fake := Node3D.new()
	add_child_autofree(fake)
	mgr._vehicles.append(fake)
	mgr._on_vehicle_stolen(fake)
	assert_eq(
		mgr._vehicles.size(),
		0,
		"Stolen vehicle should be removed from tracking",
	)


func test_on_vehicle_stolen_ignores_unknown() -> void:
	var mgr: Node = TrafficManagerScript.new()
	add_child_autofree(mgr)
	var tracked := Node3D.new()
	var unknown := Node3D.new()
	add_child_autofree(tracked)
	add_child_autofree(unknown)
	mgr._vehicles.append(tracked)
	mgr._on_vehicle_stolen(unknown)
	assert_eq(
		mgr._vehicles.size(),
		1,
		"Unknown vehicle should not affect tracked list",
	)


# ==========================================================================
# _pick_weighted_variant
# ==========================================================================


func test_pick_weighted_variant_returns_valid_index() -> void:
	var mgr: Node = TrafficManagerScript.new()
	add_child_autofree(mgr)
	# Compute total weight
	for v in TrafficManagerScript.VARIANTS:
		mgr._total_weight += v.weight
	for _i in 50:
		var idx: int = mgr._pick_weighted_variant()
		assert_gte(idx, 0)
		assert_lt(idx, TrafficManagerScript.VARIANTS.size())


# ==========================================================================
# _despawn_far with invalid nodes
# ==========================================================================


func test_despawn_far_removes_distant_vehicles() -> void:
	var mgr: Node = TrafficManagerScript.new()
	add_child_autofree(mgr)

	var player := Node3D.new()
	player.add_to_group("player")
	add_child_autofree(player)
	mgr._player = player

	# Place a vehicle far beyond DESPAWN_RADIUS
	var v := Node3D.new()
	v.position = Vector3(500.0, 0.0, 0.0)
	add_child_autofree(v)
	mgr._vehicles.append(v)

	mgr._despawn_far()
	assert_eq(
		mgr._vehicles.size(),
		0,
		"Distant vehicles should be despawned",
	)


# ==========================================================================
# _make_terrain_noise static helper
# ==========================================================================


func test_make_terrain_noise() -> void:
	var noise: FastNoiseLite = TrafficManagerScript._make_terrain_noise()
	assert_not_null(noise)
	assert_eq(noise.noise_type, FastNoiseLite.TYPE_SIMPLEX_SMOOTH)
	assert_eq(noise.seed, 42)
	assert_almost_eq(noise.frequency, 0.003, 0.0001)


# ==========================================================================
# Car colors
# ==========================================================================


func test_ten_car_colors_defined() -> void:
	var mgr: Node = TrafficManagerScript.new()
	add_child_autofree(mgr)
	assert_eq(
		mgr._car_colors.size(),
		10,
		"Should have 10 car color options",
	)


# ==========================================================================
# Spawn view-cone rejection (vehicles must not pop into player's view)
# ==========================================================================


func test_spawn_rejects_forward_hemisphere() -> void:
	var src: String = TrafficManagerScript.source_code
	assert_true(
		src.contains("h_vel.normalized().dot(offset.normalized()) > 0.0"),
		"Forward hemisphere spawns must be rejected (dot > 0.0)",
	)


func test_spawn_forward_rejection_is_unconditional() -> void:
	# The old code had a probabilistic rejection (70% chance).
	# The fix must always reject — no randf() chance mixed in.
	var src: String = TrafficManagerScript.source_code
	var dot_idx: int = (
		src
		. find(
			"h_vel.normalized().dot(offset.normalized()) > 0.0",
		)
	)
	assert_gte(dot_idx, 0, "Forward dot check must exist")
	# The continue immediately follows — no randf() in between
	var snippet: String = src.substr(dot_idx, 80)
	assert_false(
		snippet.contains("randf()"),
		"Forward rejection must be unconditional (no randf chance)",
	)


# ==========================================================================
# Spawn altitude fix (vehicles must not fall from the sky)
# ==========================================================================


func test_spawn_uses_signed_distance_for_city_check() -> void:
	var src: String = TrafficManagerScript.source_code
	assert_true(
		src.contains("get_signed_distance(spawn_pos.x, spawn_pos.z)"),
		"Spawn must check signed_distance to detect city boundary",
	)


func test_spawn_uses_flat_ground_inside_city() -> void:
	var src: String = TrafficManagerScript.source_code
	assert_true(
		src.contains("sd < 0.0"),
		"Inside city (sd < 0) must use flat ground height",
	)


func test_spawn_rejects_steep_terrain_outside_city() -> void:
	var src: String = TrafficManagerScript.source_code
	assert_true(
		src.contains("ground_y > 6.0"),
		"Steep terrain (ground_y > 6 m) must be rejected to prevent sky-falls",
	)
