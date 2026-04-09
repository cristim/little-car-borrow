# gdlint:ignore = max-public-methods
extends GutTest
## Unit tests for tire_screech_audio.gd — audio generator setup, constants,
## slip intensity calculation, envelope behavior, and distance culling.

const _SCRIPT_PATH := "res://scenes/vehicles/tire_screech_audio.gd"
const ScreechScript = preload(_SCRIPT_PATH)


class MockVehicle:
	extends Node3D
	var linear_velocity := Vector3.ZERO
	var handbrake_input := 0.0


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


func test_bus_name() -> void:
	assert_eq(ScreechScript.BUS_NAME, "SFX")


func test_max_distance() -> void:
	assert_eq(ScreechScript.MAX_DISTANCE, 60.0)


func test_buffer_length() -> void:
	assert_almost_eq(ScreechScript.BUFFER_LENGTH, 0.1, 0.001)


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
	assert_almost_eq(gen.buffer_length, ScreechScript.BUFFER_LENGTH, 0.001)


func test_ready_sets_sfx_bus() -> void:
	var screech: AudioStreamPlayer3D = ScreechScript.new()
	add_child_autofree(screech)
	assert_eq(screech.bus, &"SFX")


func test_ready_sets_max_distance() -> void:
	var screech: AudioStreamPlayer3D = ScreechScript.new()
	add_child_autofree(screech)
	assert_eq(screech.max_distance, ScreechScript.MAX_DISTANCE)


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
# _get_slip_intensity — behavioral tests
# ==========================================================================


func test_slip_zero_without_linear_velocity_property() -> void:
	var screech: AudioStreamPlayer3D = ScreechScript.new()
	add_child_autofree(screech)
	var mock_vehicle := Node.new()  # plain Node has no linear_velocity
	add_child_autofree(mock_vehicle)
	screech._vehicle = mock_vehicle
	assert_eq(screech._get_slip_intensity(), 0.0)


func test_slip_zero_below_speed_threshold() -> void:
	var screech: AudioStreamPlayer3D = ScreechScript.new()
	add_child_autofree(screech)
	var mock := MockVehicle.new()
	add_child_autofree(mock)
	# Speed = 5 km/h (below 20 km/h threshold)
	mock.linear_velocity = Vector3(0.0, 0.0, -5.0 / 3.6)
	screech._vehicle = mock
	assert_eq(screech._get_slip_intensity(), 0.0)


func test_slip_zero_when_moving_straight() -> void:
	var screech: AudioStreamPlayer3D = ScreechScript.new()
	add_child_autofree(screech)
	var mock := MockVehicle.new()
	add_child_autofree(mock)
	# Moving forward at 80 km/h (22.2 m/s), no lateral component
	mock.linear_velocity = Vector3(0.0, 0.0, -22.22)
	screech._vehicle = mock
	# lateral cross should be 0 (moving straight)
	assert_almost_eq(screech._get_slip_intensity(), 0.0, 0.01)


func test_slip_nonzero_above_lateral_threshold() -> void:
	var screech: AudioStreamPlayer3D = ScreechScript.new()
	add_child_autofree(screech)
	var mock := MockVehicle.new()
	add_child_autofree(mock)
	# Moving fast enough (80 km/h) with large lateral component (perpendicular)
	mock.linear_velocity = Vector3(22.22, 0.0, 0.0)  # pure lateral at 80 km/h
	screech._vehicle = mock
	var slip := screech._get_slip_intensity()
	assert_true(slip > 0.0, "Full lateral slip should produce non-zero intensity")


func test_slip_handbrake_at_low_speed_no_screech() -> void:
	var screech: AudioStreamPlayer3D = ScreechScript.new()
	add_child_autofree(screech)
	var mock := MockVehicle.new()
	add_child_autofree(mock)
	# Handbrake engaged but slow (15 km/h < 30 km/h threshold)
	mock.linear_velocity = Vector3(0.0, 0.0, -4.17)  # 15 km/h straight ahead
	mock.handbrake_input = 1.0
	screech._vehicle = mock
	# Speed below threshold → 0
	assert_eq(screech._get_slip_intensity(), 0.0)


func test_slip_handbrake_min_intensity() -> void:
	var screech: AudioStreamPlayer3D = ScreechScript.new()
	add_child_autofree(screech)
	var mock := MockVehicle.new()
	add_child_autofree(mock)
	# Handbrake at high speed going straight → should give HANDBRAKE_SLIP_MIN
	mock.linear_velocity = Vector3(0.0, 0.0, -15.0)  # 54 km/h
	mock.handbrake_input = 1.0
	screech._vehicle = mock
	var slip := screech._get_slip_intensity()
	assert_almost_eq(slip, ScreechScript.HANDBRAKE_SLIP_MIN, 0.01)


func test_slip_const_handbrake_threshold() -> void:
	assert_eq(ScreechScript.HANDBRAKE_THRESHOLD, 0.5)


func test_slip_const_handbrake_speed_min() -> void:
	assert_eq(ScreechScript.HANDBRAKE_SPEED_MIN, 30.0)


func test_slip_const_handbrake_slip_min() -> void:
	assert_eq(ScreechScript.HANDBRAKE_SLIP_MIN, 0.6)


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
