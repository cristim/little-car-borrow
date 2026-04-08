extends GutTest
## Unit tests for engine_audio.gd — procedural car engine sound.

var _script: GDScript
var _src: String


func before_all() -> void:
	_script = load("res://scenes/vehicles/engine_audio.gd")
	_src = _script.source_code


# ==========================================================================
# Constants
# ==========================================================================


func test_sample_rate_is_22050() -> void:
	assert_true(_src.contains("SAMPLE_RATE := 22050.0"))


func test_base_freq_min_is_60() -> void:
	assert_true(_src.contains("BASE_FREQ_MIN := 60.0"))


func test_base_freq_max_is_280() -> void:
	assert_true(_src.contains("BASE_FREQ_MAX := 280.0"))


func test_idle_wobble_freq() -> void:
	assert_true(_src.contains("IDLE_WOBBLE_FREQ := 3.5"))


func test_idle_wobble_depth() -> void:
	assert_true(_src.contains("IDLE_WOBBLE_DEPTH := 10.0"))


func test_cull_distance_is_60() -> void:
	assert_true(_src.contains("CULL_DISTANCE := 60.0"))


func test_h2_amp() -> void:
	assert_true(_src.contains("H2_AMP := 0.35"))


func test_h3_amp() -> void:
	assert_true(_src.contains("H3_AMP := 0.18"))


func test_h4_amp() -> void:
	assert_true(_src.contains("H4_AMP := 0.08"))


func test_h5_amp() -> void:
	assert_true(_src.contains("H5_AMP := 0.04"))


func test_sub_amp() -> void:
	assert_true(_src.contains("SUB_AMP := 0.2"))


# ==========================================================================
# Initial state
# ==========================================================================


func test_initial_smooth_volume() -> void:
	assert_true(_src.contains("_smooth_volume := 0.15"))


func test_initial_crackle_timer() -> void:
	assert_true(_src.contains("_crackle_timer := 0.0"))


func test_initial_crackle_amp() -> void:
	assert_true(_src.contains("_crackle_amp := 0.0"))


func test_initial_prev_throttle() -> void:
	assert_true(_src.contains("_prev_throttle := 0.0"))


func test_initial_phases_are_zero() -> void:
	assert_true(_src.contains("_phase := 0.0"))
	assert_true(_src.contains("_phase2 := 0.0"))
	assert_true(_src.contains("_phase3 := 0.0"))
	assert_true(_src.contains("_phase4 := 0.0"))
	assert_true(_src.contains("_phase5 := 0.0"))
	assert_true(_src.contains("_phase_sub := 0.0"))
	assert_true(_src.contains("_wobble_phase := 0.0"))


# ==========================================================================
# _ready() setup
# ==========================================================================


func test_ready_randomizes_rng() -> void:
	assert_true(
		_src.contains("_rng.randomize()"),
		"Must randomize RNG instance",
	)


func test_ready_sets_sfx_bus() -> void:
	assert_true(
		_src.contains('bus = "SFX"'),
		"Should set audio bus to SFX",
	)


func test_ready_sets_max_distance() -> void:
	assert_true(
		_src.contains("max_distance = 80.0"),
		"Should set max_distance to 80",
	)


func test_ready_sets_attenuation_model() -> void:
	assert_true(
		_src.contains("ATTENUATION_INVERSE_DISTANCE"),
		"Should use inverse distance attenuation",
	)


func test_ready_sets_buffer_length() -> void:
	assert_true(
		_src.contains("buffer_length = 0.1"),
		"Buffer length should be 0.1s",
	)


func test_ready_creates_generator() -> void:
	assert_true(
		_src.contains("AudioStreamGenerator.new()"),
		"Should create AudioStreamGenerator",
	)


func test_ready_calls_play() -> void:
	assert_true(
		_src.contains("\tplay()"),
		"Should start playback in _ready",
	)


# ==========================================================================
# _process() logic
# ==========================================================================


func test_process_guards_on_playback_and_vehicle() -> void:
	assert_true(
		_src.contains("not _playback or not _vehicle"),
		"Should guard on _playback and _vehicle",
	)


func test_speed_from_linear_velocity() -> void:
	assert_true(
		_src.contains('"linear_velocity" in _vehicle'),
		"Should check for linear_velocity property",
	)


func test_throttle_from_throttle_input() -> void:
	assert_true(
		_src.contains('"throttle_input" in _vehicle'),
		"Should check for throttle_input property",
	)


func test_speed_ratio_normalized_to_120_kmh() -> void:
	assert_true(
		_src.contains("speed_kmh / 120.0"),
		"Speed ratio should normalize against 120 km/h",
	)


func test_idle_wobble_below_5_kmh() -> void:
	assert_true(
		_src.contains("speed_kmh < 5.0"),
		"Idle wobble should activate below 5 km/h",
	)


func test_exhaust_crackle_on_throttle_liftoff() -> void:
	assert_true(
		_src.contains("_prev_throttle > 0.3 and throttle < 0.1"),
		"Crackle should trigger on throttle lift-off",
	)


func test_crackle_requires_speed_above_30() -> void:
	assert_true(
		_src.contains("speed_kmh > 30.0"),
		"Crackle should require speed above 30 km/h",
	)


func test_crackle_timer_set_to_03() -> void:
	assert_true(
		_src.contains("_crackle_timer = 0.3"),
		"Crackle should last 0.3 seconds",
	)


func test_crackle_amp_decays() -> void:
	assert_true(
		_src.contains("_crackle_amp *= 0.92"),
		"Crackle amplitude should decay by 0.92",
	)


func test_distance_culling() -> void:
	assert_true(
		_src.contains("dist > CULL_DISTANCE"),
		"Should cull audio beyond CULL_DISTANCE",
	)


func test_phase_wrapping() -> void:
	assert_true(_src.contains("if _phase > 1.0"), "Fundamental phase wraps")
	assert_true(_src.contains("if _phase5 > 1.0"), "5th harmonic phase wraps")
	assert_true(_src.contains("if _phase_sub > 1.0"), "Sub-bass phase wraps")


func test_waveshaping_for_growl() -> void:
	assert_true(
		_src.contains("0.8 + 0.2 * absf(fund)"),
		"Should waveshape fundamental for engine growl",
	)


func test_smooth_volume_transition() -> void:
	assert_true(
		_src.contains("delta * 8.0"),
		"Volume smoothing rate should be delta * 8.0",
	)


func test_pushes_stereo_frames() -> void:
	assert_true(
		_src.contains("push_frame(Vector2(sample, sample))"),
		"Should push mono as stereo Vector2",
	)


func test_idle_wobble_has_secondary_harmonic() -> void:
	assert_true(
		_src.contains("_wobble_phase * TAU * 2.3"),
		"Idle wobble should have secondary harmonic at 2.3x",
	)


func test_crackle_initial_amp_is_012() -> void:
	assert_true(
		_src.contains("_crackle_amp = 0.12"),
		"Crackle initial amplitude should be 0.12",
	)
