# gdlint:ignore = max-public-methods
extends GutTest
## Unit tests for tire_screech_audio.gd — audio generator setup, constants,
## slip intensity calculation, envelope behavior, and distance culling.

const _SCRIPT_PATH := "res://scenes/vehicles/tire_screech_audio.gd"
const ScreechScript = preload(_SCRIPT_PATH)

# ==========================================================================
# Constants
# ==========================================================================


func test_sample_rate() -> void:
	assert_eq(ScreechScript.SAMPLE_RATE, 22050.0)


func test_slip_speed_threshold() -> void:
	assert_eq(ScreechScript.SLIP_SPEED_THRESHOLD, 20.0)


func test_lateral_threshold() -> void:
	assert_eq(ScreechScript.LATERAL_THRESHOLD, 0.3)


func test_cull_distance() -> void:
	assert_eq(ScreechScript.CULL_DISTANCE, 50.0)


func test_res_freq_low() -> void:
	assert_eq(ScreechScript.RES_FREQ_LOW, 600.0)


func test_res_freq_high() -> void:
	assert_eq(ScreechScript.RES_FREQ_HIGH, 1800.0)


func test_attack_speed() -> void:
	assert_eq(ScreechScript.ATTACK_SPEED, 8.0)


func test_release_speed() -> void:
	assert_eq(ScreechScript.RELEASE_SPEED, 4.0)


func test_attack_faster_than_release() -> void:
	assert_true(
		ScreechScript.ATTACK_SPEED > ScreechScript.RELEASE_SPEED,
		"Attack should be faster than release for realistic screech onset",
	)


func test_res_freq_high_above_low() -> void:
	assert_true(ScreechScript.RES_FREQ_HIGH > ScreechScript.RES_FREQ_LOW)


# ==========================================================================
# Default state
# ==========================================================================


func test_default_phase_zero() -> void:
	var screech: AudioStreamPlayer3D = ScreechScript.new()
	add_child_autofree(screech)
	assert_eq(screech._phase, 0.0)


func test_default_phase2_zero() -> void:
	var screech: AudioStreamPlayer3D = ScreechScript.new()
	add_child_autofree(screech)
	assert_eq(screech._phase2, 0.0)


func test_default_envelope_zero() -> void:
	var screech: AudioStreamPlayer3D = ScreechScript.new()
	add_child_autofree(screech)
	assert_eq(screech._envelope, 0.0)


func test_default_filter_state_zero() -> void:
	var screech: AudioStreamPlayer3D = ScreechScript.new()
	add_child_autofree(screech)
	assert_eq(screech._filter_state, 0.0)


func test_default_filter_state2_zero() -> void:
	var screech: AudioStreamPlayer3D = ScreechScript.new()
	add_child_autofree(screech)
	assert_eq(screech._filter_state2, 0.0)


# ==========================================================================
# _ready — audio generator setup
# ==========================================================================


func test_ready_creates_generator_stream() -> void:
	var screech: AudioStreamPlayer3D = ScreechScript.new()
	add_child_autofree(screech)
	assert_true(
		screech.stream is AudioStreamGenerator,
		"Stream should be AudioStreamGenerator",
	)


func test_ready_sets_mix_rate() -> void:
	var screech: AudioStreamPlayer3D = ScreechScript.new()
	add_child_autofree(screech)
	var gen := screech.stream as AudioStreamGenerator
	assert_eq(gen.mix_rate, ScreechScript.SAMPLE_RATE)


func test_ready_sets_buffer_length() -> void:
	var screech: AudioStreamPlayer3D = ScreechScript.new()
	add_child_autofree(screech)
	var gen := screech.stream as AudioStreamGenerator
	assert_almost_eq(gen.buffer_length, 0.1, 0.001)


func test_ready_sets_sfx_bus() -> void:
	var screech: AudioStreamPlayer3D = ScreechScript.new()
	add_child_autofree(screech)
	assert_eq(screech.bus, &"SFX")


func test_ready_sets_max_distance() -> void:
	var screech: AudioStreamPlayer3D = ScreechScript.new()
	add_child_autofree(screech)
	assert_eq(screech.max_distance, 60.0)


func test_ready_sets_attenuation_model() -> void:
	var screech: AudioStreamPlayer3D = ScreechScript.new()
	add_child_autofree(screech)
	assert_eq(
		screech.attenuation_model,
		AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE,
	)


func test_ready_starts_playing() -> void:
	var screech: AudioStreamPlayer3D = ScreechScript.new()
	add_child_autofree(screech)
	assert_true(screech.playing, "Screech should start playing immediately")


func test_ready_sets_vehicle_from_parent() -> void:
	var parent := Node3D.new()
	add_child_autofree(parent)
	var screech: AudioStreamPlayer3D = ScreechScript.new()
	parent.add_child(screech)
	assert_eq(screech._vehicle, parent)


func test_ready_rng_randomized() -> void:
	# Verify RNG is randomized (not default seed 0)
	var src: String = (load(_SCRIPT_PATH) as GDScript).source_code
	assert_true(
		src.contains("_rng.randomize()"),
		"RNG should be randomized for non-deterministic noise",
	)


# ==========================================================================
# _get_slip_intensity — source verification and logic
# ==========================================================================


func test_slip_returns_zero_without_linear_velocity() -> void:
	var src: String = (load(_SCRIPT_PATH) as GDScript).source_code
	assert_true(
		src.contains('not "linear_velocity" in _vehicle'),
		"Should check for linear_velocity property on vehicle",
	)


func test_slip_returns_zero_below_speed_threshold() -> void:
	var src: String = (load(_SCRIPT_PATH) as GDScript).source_code
	assert_true(
		src.contains("speed_kmh < SLIP_SPEED_THRESHOLD"),
		"Should return 0 below speed threshold",
	)


func test_slip_checks_lateral_threshold() -> void:
	var src: String = (load(_SCRIPT_PATH) as GDScript).source_code
	assert_true(
		src.contains("lateral > LATERAL_THRESHOLD"),
		"Should check lateral movement against threshold",
	)


func test_slip_checks_handbrake() -> void:
	var src: String = (load(_SCRIPT_PATH) as GDScript).source_code
	assert_true(
		src.contains("handbrake > 0.5"),
		"Should detect handbrake for skid",
	)


func test_slip_handbrake_requires_speed() -> void:
	var src: String = (load(_SCRIPT_PATH) as GDScript).source_code
	assert_true(
		src.contains("speed_kmh > 30.0"),
		"Handbrake screech should require minimum speed",
	)


func test_slip_clamps_to_zero_one() -> void:
	var src: String = (load(_SCRIPT_PATH) as GDScript).source_code
	assert_true(
		src.contains("clampf((lateral - LATERAL_THRESHOLD) * 2.0, 0.0, 1.0)"),
		"Lateral slip should be clamped to [0, 1]",
	)


func test_slip_handbrake_minimum_intensity() -> void:
	var src: String = (load(_SCRIPT_PATH) as GDScript).source_code
	assert_true(
		src.contains("maxf(slip, 0.6)"),
		"Handbrake should guarantee at least 0.6 slip intensity",
	)


# ==========================================================================
# Audio generation — source verification
# ==========================================================================


func test_uses_dual_filter_bands() -> void:
	var src: String = (load(_SCRIPT_PATH) as GDScript).source_code
	assert_true(
		src.contains("_filter_state") and src.contains("_filter_state2"),
		"Should use dual resonant filter bands",
	)


func test_second_resonance_band_offset() -> void:
	var src: String = (load(_SCRIPT_PATH) as GDScript).source_code
	assert_true(
		src.contains("res_freq * 1.5"),
		"Second resonance band should be 1.5x the primary",
	)


func test_tonal_component_added() -> void:
	var src: String = (load(_SCRIPT_PATH) as GDScript).source_code
	assert_true(
		src.contains("sin(_phase * TAU)"),
		"Should add tonal sine component",
	)
	assert_true(
		src.contains("sin(_phase2 * TAU)"),
		"Should add second tonal component",
	)


func test_envelope_attack_and_release() -> void:
	var src: String = (load(_SCRIPT_PATH) as GDScript).source_code
	assert_true(
		src.contains("ATTACK_SPEED * dt"),
		"Should use ATTACK_SPEED for envelope rise",
	)
	assert_true(
		src.contains("RELEASE_SPEED * dt"),
		"Should use RELEASE_SPEED for envelope decay",
	)


func test_silence_below_envelope_threshold() -> void:
	var src: String = (load(_SCRIPT_PATH) as GDScript).source_code
	assert_true(
		src.contains("_envelope < 0.005"),
		"Should push silence when envelope is near zero",
	)


# ==========================================================================
# Distance culling — source verification
# ==========================================================================


func test_cull_distance_stops_playback() -> void:
	var src: String = (load(_SCRIPT_PATH) as GDScript).source_code
	assert_true(
		src.contains("dist > CULL_DISTANCE"),
		"Should stop playback beyond cull distance",
	)


func test_cull_restarts_playback_when_close() -> void:
	var src: String = (load(_SCRIPT_PATH) as GDScript).source_code
	assert_true(
		src.contains("if not playing"),
		"Should restart playback when camera comes back in range",
	)
