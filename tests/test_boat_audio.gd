extends GutTest
## Unit tests for boat_audio.gd — procedural outboard motor sound.

var _script: GDScript
var _src: String


func before_all() -> void:
	_script = load("res://scenes/vehicles/boat_audio.gd")
	_src = _script.source_code


# ==========================================================================
# Constants
# ==========================================================================


func test_sample_rate_is_22050() -> void:
	assert_true(_src.contains("SAMPLE_RATE := 22050.0"))


func test_base_freq_min_is_35() -> void:
	assert_true(_src.contains("BASE_FREQ_MIN := 35.0"))


func test_base_freq_max_is_140() -> void:
	assert_true(_src.contains("BASE_FREQ_MAX := 140.0"))


func test_idle_burble_freq_is_2() -> void:
	assert_true(_src.contains("IDLE_BURBLE_FREQ := 2.0"))


func test_idle_burble_depth_is_8() -> void:
	assert_true(_src.contains("IDLE_BURBLE_DEPTH := 8.0"))


func test_cull_distance_is_60() -> void:
	assert_true(_src.contains("CULL_DISTANCE := 60.0"))


func test_h2_amp_is_050() -> void:
	assert_true(_src.contains("H2_AMP := 0.50"))


func test_h3_amp_is_015() -> void:
	assert_true(_src.contains("H3_AMP := 0.15"))


func test_h4_amp_is_006() -> void:
	assert_true(_src.contains("H4_AMP := 0.06"))


func test_sub_amp_is_025() -> void:
	assert_true(_src.contains("SUB_AMP := 0.25"))


# ==========================================================================
# _ready() setup
# ==========================================================================


func test_ready_looks_for_boat_controller() -> void:
	assert_true(
		_src.contains("BoatController"),
		"_ready should look for BoatController child on parent",
	)


func test_ready_sets_sfx_bus() -> void:
	assert_true(
		_src.contains('bus = "SFX"'),
		"Should set audio bus to SFX",
	)


func test_ready_sets_max_distance_80() -> void:
	assert_true(
		_src.contains("max_distance = 80.0"),
		"Should set max_distance to 80",
	)


func test_ready_uses_inverse_distance_attenuation() -> void:
	assert_true(
		_src.contains("ATTENUATION_INVERSE_DISTANCE"),
		"Should use inverse distance attenuation model",
	)


func test_ready_randomizes_rng() -> void:
	assert_true(
		_src.contains("_rng.randomize()"),
		"Must randomize RNG instance for random behavior",
	)


func test_ready_sets_buffer_length() -> void:
	assert_true(
		_src.contains("buffer_length = 0.1"),
		"Buffer length should be 0.1s",
	)


func test_ready_creates_audio_stream_generator() -> void:
	assert_true(
		_src.contains("AudioStreamGenerator.new()"),
		"Should create AudioStreamGenerator",
	)


func test_ready_calls_play() -> void:
	assert_true(
		_src.contains("\tplay()"),
		"Should start playback in _ready",
	)


func test_ready_gets_stream_playback() -> void:
	assert_true(
		_src.contains("get_stream_playback()"),
		"Should get stream playback after play()",
	)


# ==========================================================================
# _process() logic
# ==========================================================================


func test_process_returns_early_without_playback() -> void:
	assert_true(
		_src.contains("not _playback or not _vehicle"),
		"_process should guard on _playback and _vehicle",
	)


func test_speed_calculated_from_linear_velocity() -> void:
	assert_true(
		_src.contains("linear_velocity"),
		"Should derive speed from parent linear_velocity",
	)


func test_speed_to_kmh_conversion() -> void:
	assert_true(
		_src.contains("* 3.6"),
		"Should convert m/s to km/h with * 3.6",
	)


func test_speed_ratio_clamped_to_80_kmh() -> void:
	assert_true(
		_src.contains("speed_kmh / 80.0"),
		"Speed ratio should normalize against 80 km/h",
	)


func test_idle_burble_below_5_kmh() -> void:
	assert_true(
		_src.contains("speed_kmh < 5.0"),
		"Idle burble should activate below 5 km/h",
	)


func test_hull_slap_above_15_kmh() -> void:
	assert_true(
		_src.contains("speed_kmh > 15.0"),
		"Hull slap should activate above 15 km/h",
	)


func test_water_gurgle_always_present() -> void:
	assert_true(
		_src.contains("gurgle_amp"),
		"Water gurgle amplitude should always be present",
	)


func test_distance_culling_stops_playback() -> void:
	assert_true(
		_src.contains("dist > CULL_DISTANCE"),
		"Should stop playback when beyond cull distance",
	)


func test_phase_wrapping() -> void:
	assert_true(
		_src.contains("if _phase > 1.0"),
		"Fundamental phase should wrap at 1.0",
	)
	assert_true(
		_src.contains("if _phase_sub > 1.0"),
		"Sub-bass phase should wrap at 1.0",
	)


func test_smooth_volume_transition() -> void:
	assert_true(
		_src.contains("delta * 6.0"),
		"Volume smoothing should use delta * 6.0 rate",
	)


func test_throttle_checks_controller_active() -> void:
	assert_true(
		_src.contains("_controller.active"),
		"Throttle should only read input when controller is active",
	)


func test_pushes_stereo_frames() -> void:
	assert_true(
		_src.contains("push_frame(Vector2(sample, sample))"),
		"Should push mono samples as stereo Vector2",
	)


func test_initial_smooth_volume_is_012() -> void:
	assert_true(
		_src.contains("_smooth_volume := 0.12"),
		"Initial smooth volume should be 0.12",
	)


func test_hull_slap_clamped() -> void:
	assert_true(
		_src.contains("clampf((speed_kmh - 15.0) / 40.0, 0.0, 0.15)"),
		"Hull slap amplitude should be clamped to 0.15",
	)
