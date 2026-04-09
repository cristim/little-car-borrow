extends GutTest
## Unit tests for engine_audio.gd — procedural car engine sound.

const EngineAudioScript = preload("res://scenes/vehicles/engine_audio.gd")

var _src: String


func before_all() -> void:
	_src = (EngineAudioScript as GDScript).source_code


# ==========================================================================
# Constants
# ==========================================================================


func test_sample_rate_is_22050() -> void:
	assert_eq(EngineAudioScript.SAMPLE_RATE, 22050.0)


func test_base_freq_min_is_60() -> void:
	assert_eq(EngineAudioScript.BASE_FREQ_MIN, 60.0)


func test_base_freq_max_is_280() -> void:
	assert_eq(EngineAudioScript.BASE_FREQ_MAX, 280.0)


func test_idle_wobble_freq() -> void:
	assert_eq(EngineAudioScript.IDLE_WOBBLE_FREQ, 3.5)


func test_idle_wobble_depth() -> void:
	assert_eq(EngineAudioScript.IDLE_WOBBLE_DEPTH, 10.0)


func test_cull_distance_is_60() -> void:
	assert_eq(EngineAudioScript.CULL_DISTANCE, 60.0)


func test_h2_amp() -> void:
	assert_eq(EngineAudioScript.H2_AMP, 0.35)


func test_h3_amp() -> void:
	assert_eq(EngineAudioScript.H3_AMP, 0.18)


func test_h4_amp() -> void:
	assert_eq(EngineAudioScript.H4_AMP, 0.08)


func test_h5_amp() -> void:
	assert_eq(EngineAudioScript.H5_AMP, 0.04)


func test_sub_amp() -> void:
	assert_eq(EngineAudioScript.SUB_AMP, 0.2)


# ==========================================================================
# Initial state
# ==========================================================================


func test_initial_smooth_volume() -> void:
	var inst: AudioStreamPlayer3D = EngineAudioScript.new()
	add_child_autofree(inst)
	assert_eq(inst._smooth_volume, 0.15)


func test_initial_crackle_timer() -> void:
	var inst: AudioStreamPlayer3D = EngineAudioScript.new()
	add_child_autofree(inst)
	assert_eq(inst._crackle_timer, 0.0)


func test_initial_crackle_amp() -> void:
	var inst: AudioStreamPlayer3D = EngineAudioScript.new()
	add_child_autofree(inst)
	assert_eq(inst._crackle_amp, 0.0)


func test_initial_prev_throttle() -> void:
	var inst: AudioStreamPlayer3D = EngineAudioScript.new()
	add_child_autofree(inst)
	assert_eq(inst._prev_throttle, 0.0)


func test_initial_phases_are_zero() -> void:
	var inst: AudioStreamPlayer3D = EngineAudioScript.new()
	add_child_autofree(inst)
	assert_eq(inst._phase, 0.0)
	assert_eq(inst._phase2, 0.0)
	assert_eq(inst._phase3, 0.0)
	assert_eq(inst._phase4, 0.0)
	assert_eq(inst._phase5, 0.0)
	assert_eq(inst._phase_sub, 0.0)
	assert_eq(inst._wobble_phase, 0.0)


# ==========================================================================
# _ready() setup
# ==========================================================================


func test_ready_randomizes_rng() -> void:
	assert_true(
		_src.contains("_rng.randomize()"),
		"Must randomize RNG instance",
	)


func test_ready_sets_sfx_bus() -> void:
	assert_eq(EngineAudioScript.BUS_NAME, "SFX")


func test_ready_sets_max_distance() -> void:
	assert_eq(EngineAudioScript.MAX_DISTANCE, 80.0)


func test_ready_sets_attenuation_model() -> void:
	assert_true(
		_src.contains("ATTENUATION_INVERSE_DISTANCE"),
		"Should use inverse distance attenuation",
	)


func test_ready_sets_buffer_length() -> void:
	assert_eq(EngineAudioScript.BUFFER_LENGTH, 0.1)


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
	assert_eq(EngineAudioScript.SPEED_NORMALIZATION, 120.0)


func test_idle_wobble_below_5_kmh() -> void:
	assert_eq(EngineAudioScript.IDLE_SPEED_THRESHOLD, 5.0)


func test_exhaust_crackle_on_throttle_liftoff() -> void:
	assert_eq(EngineAudioScript.CRACKLE_THROTTLE_HIGH, 0.3)
	assert_eq(EngineAudioScript.CRACKLE_THROTTLE_LOW, 0.1)


func test_crackle_requires_speed_above_30() -> void:
	assert_eq(EngineAudioScript.CRACKLE_SPEED_MIN, 30.0)


func test_crackle_timer_set_to_03() -> void:
	assert_eq(EngineAudioScript.CRACKLE_DURATION, 0.3)


func test_crackle_amp_decays() -> void:
	assert_eq(EngineAudioScript.CRACKLE_DECAY, 0.92)


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
	assert_eq(EngineAudioScript.WAVE_CLIP_MIN, 0.8)
	assert_eq(EngineAudioScript.WAVE_CLIP_RANGE, 0.2)


func test_smooth_volume_transition() -> void:
	assert_eq(EngineAudioScript.VOLUME_SMOOTH_RATE, 8.0)


func test_pushes_stereo_frames() -> void:
	assert_true(
		_src.contains("push_frame(Vector2(sample, sample))"),
		"Should push mono as stereo Vector2",
	)


func test_idle_wobble_has_secondary_harmonic() -> void:
	assert_eq(EngineAudioScript.WOBBLE_SECONDARY, 2.3)


func test_crackle_initial_amp_is_012() -> void:
	assert_eq(EngineAudioScript.CRACKLE_AMP_INIT, 0.12)


# ==========================================================================
# Wobble phase updated per sample not per frame (vehicles/I7)
# ==========================================================================


func test_wobble_phase_incremented_inside_sample_loop() -> void:
	# I7: same bug as boat_audio — idle wobble phase must be incremented per
	# sample, not once per frame, to produce correct 3.5 Hz wobble.
	assert_true(
		_src.contains("sample_freq"),
		"Wobble must use per-sample local frequency variable",
	)
	var loop_start: int = _src.find("for _i in range(frames_available)")
	var wobble_pos: int = _src.find("_wobble_phase += IDLE_WOBBLE_FREQ")
	assert_true(wobble_pos > loop_start, "_wobble_phase increment must be inside sample loop")
