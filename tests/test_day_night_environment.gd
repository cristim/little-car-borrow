extends GutTest
## Tests for scenes/world/day_night_environment.gd — keyframe sampling,
## mat_active state, and sun/sky curve data integrity.

const DayNightEnvScript = preload(
	"res://scenes/world/day_night_environment.gd"
)


# ==========================================================================
# Static _sample helper — piecewise-linear curve interpolation
# ==========================================================================

func test_sample_empty_curve_returns_zero() -> void:
	assert_eq(
		DayNightEnvScript._sample([], 12.0), 0.0,
		"Empty curve should return 0.0",
	)


func test_sample_before_first_keyframe() -> void:
	var curve := [[5.0, 10.0], [10.0, 20.0]]
	assert_eq(
		DayNightEnvScript._sample(curve, 2.0), 10.0,
		"Before first keyframe should return first value",
	)


func test_sample_at_first_keyframe() -> void:
	var curve := [[5.0, 10.0], [10.0, 20.0]]
	assert_eq(
		DayNightEnvScript._sample(curve, 5.0), 10.0,
		"At first keyframe should return exact value",
	)


func test_sample_at_last_keyframe() -> void:
	var curve := [[5.0, 10.0], [10.0, 20.0]]
	assert_eq(
		DayNightEnvScript._sample(curve, 10.0), 20.0,
		"At last keyframe should return exact value",
	)


func test_sample_after_last_keyframe() -> void:
	var curve := [[5.0, 10.0], [10.0, 20.0]]
	assert_eq(
		DayNightEnvScript._sample(curve, 15.0), 20.0,
		"After last keyframe should return last value",
	)


func test_sample_midpoint_interpolation() -> void:
	var curve := [[0.0, 0.0], [10.0, 100.0]]
	assert_almost_eq(
		DayNightEnvScript._sample(curve, 5.0), 50.0, 0.01,
		"Midpoint should interpolate to 50%",
	)


func test_sample_quarter_interpolation() -> void:
	var curve := [[0.0, 0.0], [10.0, 100.0]]
	assert_almost_eq(
		DayNightEnvScript._sample(curve, 2.5), 25.0, 0.01,
		"Quarter should interpolate to 25%",
	)


func test_sample_multi_segment() -> void:
	var curve := [[0.0, 0.0], [5.0, 50.0], [10.0, 100.0]]
	assert_almost_eq(
		DayNightEnvScript._sample(curve, 7.5), 75.0, 0.01,
		"Should interpolate correctly between second segment",
	)


# ==========================================================================
# Sun pitch curve values
# ==========================================================================

func test_sun_pitch_midnight_is_negative() -> void:
	var pitch := DayNightEnvScript._sample(
		DayNightEnvScript.SUN_PITCH, 0.0
	)
	assert_lt(pitch, 0.0, "Sun should be below horizon at midnight")


func test_sun_pitch_noon_is_positive() -> void:
	var pitch := DayNightEnvScript._sample(
		DayNightEnvScript.SUN_PITCH, 12.0
	)
	assert_gt(pitch, 0.0, "Sun should be above horizon at noon")


func test_sun_pitch_noon_is_highest() -> void:
	var noon := DayNightEnvScript._sample(
		DayNightEnvScript.SUN_PITCH, 12.0
	)
	var morning := DayNightEnvScript._sample(
		DayNightEnvScript.SUN_PITCH, 7.0
	)
	var evening := DayNightEnvScript._sample(
		DayNightEnvScript.SUN_PITCH, 17.0
	)
	assert_gt(noon, morning, "Noon pitch should be higher than morning")
	assert_gt(noon, evening, "Noon pitch should be higher than evening")


# ==========================================================================
# Sun energy curve values
# ==========================================================================

func test_sun_energy_zero_at_midnight() -> void:
	var energy := DayNightEnvScript._sample(
		DayNightEnvScript.SUN_ENERGY, 0.0
	)
	assert_eq(energy, 0.0, "Sun energy should be 0 at midnight")


func test_sun_energy_one_at_midday() -> void:
	var energy := DayNightEnvScript._sample(
		DayNightEnvScript.SUN_ENERGY, 12.0
	)
	assert_eq(energy, 1.0, "Sun energy should be 1.0 at midday")


func test_sun_energy_zero_at_night() -> void:
	var energy := DayNightEnvScript._sample(
		DayNightEnvScript.SUN_ENERGY, 22.0
	)
	assert_eq(energy, 0.0, "Sun energy should be 0 at night")


# ==========================================================================
# Ambient energy curve values
# ==========================================================================

func test_ambient_energy_low_at_night() -> void:
	var energy := DayNightEnvScript._sample(
		DayNightEnvScript.AMBIENT_ENERGY, 0.0
	)
	assert_eq(energy, 0.05, "Ambient energy should be minimal at night")


func test_ambient_energy_higher_at_day() -> void:
	var energy := DayNightEnvScript._sample(
		DayNightEnvScript.AMBIENT_ENERGY, 12.0
	)
	assert_gt(
		energy, 0.1,
		"Ambient energy should be higher during day",
	)


# ==========================================================================
# Sky color curves — basic sanity
# ==========================================================================

func test_sky_top_blue_higher_during_day() -> void:
	var night_b := DayNightEnvScript._sample(
		DayNightEnvScript.SKY_TOP_B, 0.0
	)
	var day_b := DayNightEnvScript._sample(
		DayNightEnvScript.SKY_TOP_B, 12.0
	)
	assert_gt(
		day_b, night_b,
		"Sky top blue should be more blue during day",
	)


func test_sky_horizon_red_peaks_at_sunset() -> void:
	var sunset := DayNightEnvScript._sample(
		DayNightEnvScript.SKY_HOR_R, 18.0
	)
	var midday := DayNightEnvScript._sample(
		DayNightEnvScript.SKY_HOR_R, 12.0
	)
	assert_gt(
		sunset, midday,
		"Horizon red should peak at sunset",
	)


# ==========================================================================
# mat_active state
# ==========================================================================

func test_mat_active_starts_empty() -> void:
	var env: Node = DayNightEnvScript.new()
	add_child_autofree(env)
	assert_eq(
		env._mat_active.size(), 0,
		"mat_active should start empty — sized dynamically on first night",
	)


func test_mat_active_fill_resets_after_resize() -> void:
	var env: Node = DayNightEnvScript.new()
	add_child_autofree(env)
	env._mat_active.resize(8)
	env._mat_active[0] = false
	env._mat_active[3] = false
	env._mat_active.fill(true)
	for i in env._mat_active.size():
		assert_true(
			env._mat_active[i],
			"All groups should be active after reset",
		)


func test_sun_pitch_at_noon_is_positive() -> void:
	# SUN_PITCH stores the angle magnitude; when applied to the light,
	# it's negated so rotation.x is negative (tilts light downward).
	# The curve value itself should be positive at noon.
	var noon_pitch: float = DayNightEnvScript._sample(
		DayNightEnvScript.SUN_PITCH, 12.0
	)
	assert_gt(noon_pitch, 0.0, "SUN_PITCH at noon should be positive")


func test_sun_rotation_applied_negative() -> void:
	# Verify that the source code applies pitch as negative rotation
	# so the light tilts downward (toward ground), not upward.
	var src: String = DayNightEnvScript.source_code
	assert_true(
		src.contains("deg_to_rad(-_sample(SUN_PITCH"),
		"Sun pitch must be negated when applied to light rotation",
	)


func test_window_toggle_timer_interval_range() -> void:
	# Timer wait_time is set randomly in range [5.0, 12.0] seconds.
	var src: String = DayNightEnvScript.source_code
	assert_true(
		src.contains("randf_range(5.0, 12.0)"),
		"Window toggle timer should use 5-12s interval",
	)


# ==========================================================================
# Initial node references (before scene tree wiring)
# ==========================================================================

func test_initial_light_is_null() -> void:
	var env: Node = DayNightEnvScript.new()
	add_child_autofree(env)
	# light_path is empty, so _light should be null after _ready
	assert_null(env._light, "_light should be null without valid path")


func test_initial_env_is_null() -> void:
	var env: Node = DayNightEnvScript.new()
	add_child_autofree(env)
	assert_null(env._env, "_env should be null without valid path")


func test_initial_city_is_null() -> void:
	var env: Node = DayNightEnvScript.new()
	add_child_autofree(env)
	assert_null(env._city, "_city should be null without valid path")


func test_last_lights_visible_starts_false() -> void:
	var env: Node = DayNightEnvScript.new()
	add_child_autofree(env)
	assert_false(env._last_lights_visible)


func test_last_window_night_starts_false() -> void:
	var env: Node = DayNightEnvScript.new()
	add_child_autofree(env)
	assert_false(env._last_window_night)


# ==========================================================================
# Curve data integrity — all curves should span 0..24
# ==========================================================================

func _assert_curve_spans_24(curve: Array, curve_name: String) -> void:
	assert_false(curve.is_empty(), "%s should not be empty" % curve_name)
	assert_eq(
		curve[0][0], 0.0,
		"%s should start at hour 0" % curve_name,
	)
	assert_eq(
		curve[curve.size() - 1][0], 24.0,
		"%s should end at hour 24" % curve_name,
	)


func test_sun_pitch_spans_24() -> void:
	_assert_curve_spans_24(DayNightEnvScript.SUN_PITCH, "SUN_PITCH")


func test_sun_energy_spans_24() -> void:
	_assert_curve_spans_24(DayNightEnvScript.SUN_ENERGY, "SUN_ENERGY")


func test_ambient_energy_spans_24() -> void:
	_assert_curve_spans_24(
		DayNightEnvScript.AMBIENT_ENERGY, "AMBIENT_ENERGY",
	)


func test_sky_top_r_spans_24() -> void:
	_assert_curve_spans_24(DayNightEnvScript.SKY_TOP_R, "SKY_TOP_R")


func test_sky_top_g_spans_24() -> void:
	_assert_curve_spans_24(DayNightEnvScript.SKY_TOP_G, "SKY_TOP_G")


func test_sky_top_b_spans_24() -> void:
	_assert_curve_spans_24(DayNightEnvScript.SKY_TOP_B, "SKY_TOP_B")


func test_sun_col_r_spans_24() -> void:
	_assert_curve_spans_24(DayNightEnvScript.SUN_COL_R, "SUN_COL_R")


func test_sun_col_g_spans_24() -> void:
	_assert_curve_spans_24(DayNightEnvScript.SUN_COL_G, "SUN_COL_G")


func test_sun_col_b_spans_24() -> void:
	_assert_curve_spans_24(DayNightEnvScript.SUN_COL_B, "SUN_COL_B")


# ==========================================================================
# Window toggle timer creation
# ==========================================================================

func test_window_toggle_timer_created() -> void:
	var env: Node = DayNightEnvScript.new()
	add_child_autofree(env)
	await get_tree().process_frame
	assert_not_null(
		env._window_toggle_timer,
		"Window toggle timer should be created in _ready",
	)
	assert_true(
		env._window_toggle_timer.one_shot,
		"Timer should be one-shot",
	)


# ==========================================================================
# _night_factor — star/moon visibility blend
# ==========================================================================

func test_night_factor_zero_at_noon() -> void:
	var env: Node = DayNightEnvScript.new()
	add_child_autofree(env)
	assert_almost_eq(
		env._night_factor(12.0), 0.0, 0.001,
		"_night_factor should be 0 at solar noon (full sun energy)",
	)


func test_night_factor_one_at_midnight() -> void:
	var env: Node = DayNightEnvScript.new()
	add_child_autofree(env)
	assert_almost_eq(
		env._night_factor(0.0), 1.0, 0.001,
		"_night_factor should be 1.0 at midnight (no sun)",
	)


func test_night_factor_clamped_above_zero() -> void:
	var env: Node = DayNightEnvScript.new()
	add_child_autofree(env)
	for h in [5.0, 6.0, 7.0, 12.0, 17.0, 18.0, 20.0]:
		var f := env._night_factor(float(h))
		assert_gte(f, 0.0, "_night_factor must not go negative at h=%s" % h)
		assert_lte(f, 1.0, "_night_factor must not exceed 1.0 at h=%s" % h)


# ==========================================================================
# Weather constants
# ==========================================================================

func test_weather_fog_has_three_entries() -> void:
	assert_eq(
		DayNightEnvScript.WEATHER_FOG.size(), 3,
		"WEATHER_FOG should have 3 entries (clear/cloudy/overcast)",
	)


func test_weather_cloud_a_has_three_entries() -> void:
	assert_eq(
		DayNightEnvScript.WEATHER_CLOUD_A.size(), 3,
		"WEATHER_CLOUD_A should have 3 entries",
	)


func test_weather_cloud_g_has_three_entries() -> void:
	assert_eq(
		DayNightEnvScript.WEATHER_CLOUD_G.size(), 3,
		"WEATHER_CLOUD_G should have 3 entries",
	)


func test_weather_fog_values_positive_and_ascending() -> void:
	var fog: Array = DayNightEnvScript.WEATHER_FOG
	for v in fog:
		assert_gt(float(v), 0.0, "All fog densities should be positive")
	assert_lt(
		float(fog[0]), float(fog[1]),
		"Clear fog density should be less than cloudy",
	)
	assert_lt(
		float(fog[1]), float(fog[2]),
		"Cloudy fog density should be less than overcast",
	)


func test_weather_cloud_a_ascending() -> void:
	var a: Array = DayNightEnvScript.WEATHER_CLOUD_A
	assert_lt(
		float(a[0]), float(a[1]),
		"Clear cloud alpha should be less than cloudy",
	)
	assert_lt(
		float(a[1]), float(a[2]),
		"Cloudy cloud alpha should be less than overcast",
	)


func test_cloud_count_is_eight() -> void:
	assert_eq(DayNightEnvScript.CLOUD_COUNT, 8, "CLOUD_COUNT should be 8")


# ==========================================================================
# Fog day-suppression
# ==========================================================================

func test_fog_suppression_in_source() -> void:
	var src: String = DayNightEnvScript.source_code
	assert_true(
		src.contains("day_suppress"),
		"Fog update should compute day_suppress to reduce fog in sunlight",
	)


# ==========================================================================
# Moon setup
# ==========================================================================

func test_moon_phase_in_range_after_ready() -> void:
	var env: Node = DayNightEnvScript.new()
	add_child_autofree(env)
	assert_gte(env._moon_phase, 0.0, "Moon phase should be >= 0.0")
	assert_lte(env._moon_phase, 1.0, "Moon phase should be <= 1.0")


func test_moon_mesh_created() -> void:
	var env: Node = DayNightEnvScript.new()
	add_child_autofree(env)
	assert_not_null(env._moon, "Moon MeshInstance3D should be created in _ready")
	assert_true(env._moon is MeshInstance3D, "Moon should be MeshInstance3D")


func test_moon_hidden_initially() -> void:
	var env: Node = DayNightEnvScript.new()
	add_child_autofree(env)
	assert_false(env._moon.visible, "Moon should start hidden")


func test_moon_shader_has_phase_uniform() -> void:
	var src: String = DayNightEnvScript.source_code
	assert_true(
		src.contains("\"phase\""),
		"Moon shader should use a 'phase' uniform",
	)


func test_moon_shader_has_brightness_uniform() -> void:
	var src: String = DayNightEnvScript.source_code
	assert_true(
		src.contains("\"brightness\""),
		"Moon shader should use a 'brightness' uniform",
	)


# ==========================================================================
# Star sphere setup
# ==========================================================================

func test_star_sphere_created() -> void:
	var env: Node = DayNightEnvScript.new()
	add_child_autofree(env)
	assert_not_null(env._star_sphere, "Star sphere should be created in _ready")
	assert_true(env._star_sphere is MeshInstance3D, "Star sphere should be MeshInstance3D")


func test_star_sphere_radius_constant() -> void:
	assert_almost_eq(
		DayNightEnvScript.STAR_SPHERE_R, 4800.0, 0.1,
		"STAR_SPHERE_R should be 4800.0",
	)


func test_star_shader_three_grid_layers() -> void:
	var src: String = DayNightEnvScript.source_code
	assert_true(
		src.contains("UV * 96"),
		"Star shader should have background layer at UV * 96",
	)
	assert_true(
		src.contains("UV * 30"),
		"Star shader should have constellation anchor layer at UV * 30",
	)
	assert_true(
		src.contains("UV * 12"),
		"Star shader should have prominent star layer at UV * 12",
	)


func test_star_shader_far_plane_trick() -> void:
	# Stars must render at the far plane so geometry occludes them.
	# In Godot 4 Vulkan reverse-Z, far plane = z=0, achieved via
	# POSITION = vec4(clip.xy, 0.0, clip.w).
	var src: String = DayNightEnvScript.source_code
	assert_true(
		src.contains("0.0, clip.w"),
		"Star vertex shader must push stars to z=0 (far plane in reverse-Z)",
	)


# ==========================================================================
# Cloud setup
# ==========================================================================

func test_clouds_array_has_cloud_count_entries() -> void:
	var env: Node = DayNightEnvScript.new()
	add_child_autofree(env)
	assert_eq(
		env._clouds.size(), DayNightEnvScript.CLOUD_COUNT,
		"_clouds array should have CLOUD_COUNT entries after ready",
	)


func test_cloud_mats_array_has_cloud_count_entries() -> void:
	var env: Node = DayNightEnvScript.new()
	add_child_autofree(env)
	assert_eq(
		env._cloud_mats.size(), DayNightEnvScript.CLOUD_COUNT,
		"_cloud_mats array should have CLOUD_COUNT entries",
	)


func test_each_cloud_is_node3d_cluster() -> void:
	var env: Node = DayNightEnvScript.new()
	add_child_autofree(env)
	for i in env._clouds.size():
		assert_true(
			env._clouds[i] is Node3D,
			"Cloud %d should be a Node3D cluster" % i,
		)


func test_each_cloud_cluster_has_puffs() -> void:
	var env: Node = DayNightEnvScript.new()
	add_child_autofree(env)
	for i in env._clouds.size():
		var cluster: Node3D = env._clouds[i]
		assert_gte(
			cluster.get_child_count(), 4,
			"Cloud cluster %d should have at least 4 puffs" % i,
		)
		assert_lte(
			cluster.get_child_count(), 7,
			"Cloud cluster %d should have at most 7 puffs" % i,
		)


# ==========================================================================
# Weather timer
# ==========================================================================

func test_weather_timer_created() -> void:
	var env: Node = DayNightEnvScript.new()
	add_child_autofree(env)
	assert_not_null(env._weather_timer, "Weather timer should be created in _ready")
	assert_true(env._weather_timer.one_shot, "Weather timer should be one-shot")
