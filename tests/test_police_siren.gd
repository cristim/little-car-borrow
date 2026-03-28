# gdlint:ignore = max-public-methods
extends GutTest
## Unit tests for police_siren.gd — audio generator setup, siren constants,
## mode switching logic, and phase management.

const _SCRIPT_PATH := "res://scenes/vehicles/police_siren.gd"
const SirenScript = preload(_SCRIPT_PATH)


# ==========================================================================
# Constants — frequency and timing
# ==========================================================================

func test_sample_rate() -> void:
	assert_eq(SirenScript.SAMPLE_RATE, 22050.0)


func test_wail_low_frequency() -> void:
	assert_eq(SirenScript.WAIL_LOW, 570.0)


func test_wail_high_frequency() -> void:
	assert_eq(SirenScript.WAIL_HIGH, 850.0)


func test_wail_speed() -> void:
	assert_eq(SirenScript.WAIL_SPEED, 1.8)


func test_yelp_low_frequency() -> void:
	assert_eq(SirenScript.YELP_LOW, 650.0)


func test_yelp_high_frequency() -> void:
	assert_eq(SirenScript.YELP_HIGH, 1600.0)


func test_yelp_speed() -> void:
	assert_eq(SirenScript.YELP_SPEED, 12.0)


func test_yelp_duration() -> void:
	assert_eq(SirenScript.YELP_DURATION, 2.0)


func test_yelp_interval() -> void:
	assert_eq(SirenScript.YELP_INTERVAL, 8.0)


func test_yelp_speed_much_faster_than_wail() -> void:
	assert_true(
		SirenScript.YELP_SPEED > SirenScript.WAIL_SPEED * 3.0,
		"Yelp sweep should be significantly faster than wail",
	)


func test_yelp_duration_less_than_interval() -> void:
	assert_true(
		SirenScript.YELP_DURATION < SirenScript.YELP_INTERVAL,
		"Yelp duration should be shorter than interval between yelps",
	)


# ==========================================================================
# Default state
# ==========================================================================

func test_default_siren_inactive() -> void:
	var siren: AudioStreamPlayer3D = SirenScript.new()
	add_child_autofree(siren)
	assert_false(siren.siren_active)


func test_default_phase_zero() -> void:
	var siren: AudioStreamPlayer3D = SirenScript.new()
	add_child_autofree(siren)
	assert_eq(siren._phase, 0.0)


func test_default_phase_overtone_zero() -> void:
	var siren: AudioStreamPlayer3D = SirenScript.new()
	add_child_autofree(siren)
	assert_eq(siren._phase_overtone, 0.0)


func test_default_wail_phase_zero() -> void:
	var siren: AudioStreamPlayer3D = SirenScript.new()
	add_child_autofree(siren)
	assert_eq(siren._wail_phase, 0.0)


func test_default_mode_timer_zero() -> void:
	var siren: AudioStreamPlayer3D = SirenScript.new()
	add_child_autofree(siren)
	assert_eq(siren._mode_timer, 0.0)


func test_default_is_yelp_false() -> void:
	var siren: AudioStreamPlayer3D = SirenScript.new()
	add_child_autofree(siren)
	assert_false(siren._is_yelp)


func test_default_am_phase_zero() -> void:
	var siren: AudioStreamPlayer3D = SirenScript.new()
	add_child_autofree(siren)
	assert_eq(siren._am_phase, 0.0)


# ==========================================================================
# _ready — audio generator setup
# ==========================================================================

func test_ready_creates_generator_stream() -> void:
	var siren: AudioStreamPlayer3D = SirenScript.new()
	add_child_autofree(siren)
	assert_true(
		siren.stream is AudioStreamGenerator,
		"Stream should be AudioStreamGenerator",
	)


func test_ready_sets_mix_rate() -> void:
	var siren: AudioStreamPlayer3D = SirenScript.new()
	add_child_autofree(siren)
	var gen := siren.stream as AudioStreamGenerator
	assert_eq(gen.mix_rate, SirenScript.SAMPLE_RATE)


func test_ready_sets_buffer_length() -> void:
	var siren: AudioStreamPlayer3D = SirenScript.new()
	add_child_autofree(siren)
	var gen := siren.stream as AudioStreamGenerator
	assert_almost_eq(gen.buffer_length, 0.1, 0.001)


func test_ready_sets_sfx_bus() -> void:
	var siren: AudioStreamPlayer3D = SirenScript.new()
	add_child_autofree(siren)
	assert_eq(siren.bus, &"SFX")


func test_ready_sets_max_distance() -> void:
	var siren: AudioStreamPlayer3D = SirenScript.new()
	add_child_autofree(siren)
	assert_eq(siren.max_distance, 120.0)


func test_ready_sets_attenuation_model() -> void:
	var siren: AudioStreamPlayer3D = SirenScript.new()
	add_child_autofree(siren)
	assert_eq(
		siren.attenuation_model,
		AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE,
	)


func test_ready_starts_playing() -> void:
	var siren: AudioStreamPlayer3D = SirenScript.new()
	add_child_autofree(siren)
	assert_true(siren.playing, "Siren should start playing immediately")


# ==========================================================================
# Mode switching — source verification
# ==========================================================================

func test_wail_to_yelp_transition_source() -> void:
	var src: String = (load(_SCRIPT_PATH) as GDScript).source_code
	assert_true(
		src.contains("_mode_timer >= YELP_INTERVAL"),
		"Should transition to yelp after YELP_INTERVAL",
	)


func test_yelp_to_wail_transition_source() -> void:
	var src: String = (load(_SCRIPT_PATH) as GDScript).source_code
	assert_true(
		src.contains("_mode_timer >= YELP_DURATION"),
		"Should transition back to wail after YELP_DURATION",
	)


func test_mode_timer_resets_on_transition() -> void:
	var src: String = (load(_SCRIPT_PATH) as GDScript).source_code
	# The mode_timer = 0.0 reset appears in both transition branches
	var count := src.count("_mode_timer = 0.0")
	assert_true(
		count >= 2,
		"Mode timer should reset on both wail->yelp and yelp->wail transitions",
	)


# ==========================================================================
# Audio generation — source verification
# ==========================================================================

func test_pushes_silence_when_inactive() -> void:
	var src: String = (load(_SCRIPT_PATH) as GDScript).source_code
	assert_true(
		src.contains("playback.push_frame(Vector2.ZERO)"),
		"Should push silence when siren not active",
	)


func test_uses_overtone_for_richness() -> void:
	var src: String = (load(_SCRIPT_PATH) as GDScript).source_code
	assert_true(
		src.contains("freq * 3.0"),
		"Should use 3rd harmonic overtone",
	)


func test_has_amplitude_modulation() -> void:
	var src: String = (load(_SCRIPT_PATH) as GDScript).source_code
	assert_true(
		src.contains("_am_phase"),
		"Should use amplitude modulation for pulsing effect",
	)


func test_clamps_waveform_for_square_character() -> void:
	var src: String = (load(_SCRIPT_PATH) as GDScript).source_code
	assert_true(
		src.contains("clampf(primary * 1.3, -1.0, 1.0)"),
		"Should clip primary waveform for square-ish character",
	)


func test_phase_wraps_around() -> void:
	var src: String = (load(_SCRIPT_PATH) as GDScript).source_code
	assert_true(
		src.contains("if _phase > 1.0"),
		"Phase should wrap around at 1.0",
	)
	assert_true(
		src.contains("_phase -= 1.0"),
		"Phase should wrap by subtracting 1.0",
	)


func test_wail_phase_wraps_around() -> void:
	var src: String = (load(_SCRIPT_PATH) as GDScript).source_code
	assert_true(
		src.contains("if _wail_phase > 1.0"),
		"Wail phase should wrap around at 1.0",
	)
