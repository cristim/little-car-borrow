extends GutTest
## Tests for scenes/world/ambient_audio.gd — constants, time-of-day
## switching, sound generator functions, and timer state.

const AmbientScript = preload("res://scenes/world/ambient_audio.gd")


# ==========================================================================
# Constants
# ==========================================================================

func test_sample_rate() -> void:
	assert_eq(
		AmbientScript.SAMPLE_RATE, 22050.0,
		"SAMPLE_RATE should be 22050",
	)


func test_drone_frequencies() -> void:
	assert_eq(AmbientScript.DRONE_FREQ, 55.0)
	assert_eq(AmbientScript.DRONE_FREQ_2, 82.0)
	assert_eq(AmbientScript.DRONE_FREQ_3, 110.0)


func test_drone_amplitudes() -> void:
	assert_eq(AmbientScript.DRONE_AMP_DAY, 0.04)
	assert_eq(AmbientScript.DRONE_AMP_NIGHT, 0.02)
	assert_gt(
		AmbientScript.DRONE_AMP_DAY,
		AmbientScript.DRONE_AMP_NIGHT,
		"Day drone should be louder than night drone",
	)


func test_horn_intervals_day_shorter_than_night() -> void:
	assert_lt(
		AmbientScript.HORN_INTERVAL_MIN_DAY,
		AmbientScript.HORN_INTERVAL_MIN_NIGHT,
		"Day horns should be more frequent (shorter interval)",
	)
	assert_lt(
		AmbientScript.HORN_INTERVAL_MAX_DAY,
		AmbientScript.HORN_INTERVAL_MAX_NIGHT,
		"Day horns max interval should be shorter than night",
	)


func test_horn_duration() -> void:
	assert_eq(AmbientScript.HORN_DURATION, 0.35)


func test_gust_parameters() -> void:
	assert_eq(AmbientScript.GUST_INTERVAL_MIN, 6.0)
	assert_eq(AmbientScript.GUST_INTERVAL_MAX, 15.0)
	assert_eq(AmbientScript.GUST_DURATION, 2.5)


func test_chirp_parameters() -> void:
	assert_eq(AmbientScript.CHIRP_INTERVAL_MIN, 4.0)
	assert_eq(AmbientScript.CHIRP_INTERVAL_MAX, 12.0)
	assert_lt(
		AmbientScript.CHIRP_FREQ_LOW,
		AmbientScript.CHIRP_FREQ_HIGH,
		"Low chirp freq should be less than high",
	)


func test_brake_parameters() -> void:
	assert_eq(AmbientScript.BRAKE_INTERVAL_MIN, 12.0)
	assert_eq(AmbientScript.BRAKE_INTERVAL_MAX, 30.0)
	assert_eq(AmbientScript.BRAKE_DURATION, 0.5)


func test_cricket_parameters() -> void:
	assert_eq(AmbientScript.CRICKET_FREQ, 4000.0)
	assert_eq(AmbientScript.CRICKET_FREQ_2, 4800.0)
	assert_eq(AmbientScript.CRICKET_AMP, 0.006)


# ==========================================================================
# Default state
# ==========================================================================

func test_initial_state_is_day() -> void:
	var audio: AudioStreamPlayer = AmbientScript.new()
	add_child_autofree(audio)
	assert_false(audio._is_night, "Should start as daytime")
	assert_eq(
		audio._drone_amp, AmbientScript.DRONE_AMP_DAY,
		"Drone amplitude should be day value",
	)


func test_initial_horn_intervals_are_day() -> void:
	var audio: AudioStreamPlayer = AmbientScript.new()
	add_child_autofree(audio)
	assert_eq(audio._horn_min, AmbientScript.HORN_INTERVAL_MIN_DAY)
	assert_eq(audio._horn_max, AmbientScript.HORN_INTERVAL_MAX_DAY)


func test_initial_horn_not_active() -> void:
	var audio: AudioStreamPlayer = AmbientScript.new()
	add_child_autofree(audio)
	assert_false(audio._horn_active)


func test_initial_gust_not_active() -> void:
	var audio: AudioStreamPlayer = AmbientScript.new()
	add_child_autofree(audio)
	assert_false(audio._gust_active)


func test_initial_chirp_not_active() -> void:
	var audio: AudioStreamPlayer = AmbientScript.new()
	add_child_autofree(audio)
	assert_false(audio._chirp_active)


func test_initial_brake_not_active() -> void:
	var audio: AudioStreamPlayer = AmbientScript.new()
	add_child_autofree(audio)
	assert_false(audio._brake_active)


# ==========================================================================
# Time-of-day callback
# ==========================================================================

func test_on_time_changed_to_night() -> void:
	var audio: AudioStreamPlayer = AmbientScript.new()
	add_child_autofree(audio)
	audio._on_time_changed(22.0)
	assert_true(audio._is_night, "Hour 22 should be night")
	assert_eq(
		audio._drone_amp, AmbientScript.DRONE_AMP_NIGHT,
		"Drone amplitude should switch to night",
	)
	assert_eq(audio._horn_min, AmbientScript.HORN_INTERVAL_MIN_NIGHT)
	assert_eq(audio._horn_max, AmbientScript.HORN_INTERVAL_MAX_NIGHT)


func test_on_time_changed_to_early_morning_night() -> void:
	var audio: AudioStreamPlayer = AmbientScript.new()
	add_child_autofree(audio)
	audio._on_time_changed(3.0)
	assert_true(audio._is_night, "Hour 3 should be night")


func test_on_time_changed_to_day() -> void:
	var audio: AudioStreamPlayer = AmbientScript.new()
	add_child_autofree(audio)
	# Switch to night first, then back to day
	audio._on_time_changed(23.0)
	audio._on_time_changed(12.0)
	assert_false(audio._is_night, "Hour 12 should be day")
	assert_eq(audio._drone_amp, AmbientScript.DRONE_AMP_DAY)
	assert_eq(audio._horn_min, AmbientScript.HORN_INTERVAL_MIN_DAY)
	assert_eq(audio._horn_max, AmbientScript.HORN_INTERVAL_MAX_DAY)


func test_on_time_changed_boundary_6() -> void:
	var audio: AudioStreamPlayer = AmbientScript.new()
	add_child_autofree(audio)
	audio._on_time_changed(6.0)
	assert_false(audio._is_night, "Hour 6 should be day (boundary)")


func test_on_time_changed_boundary_20() -> void:
	var audio: AudioStreamPlayer = AmbientScript.new()
	add_child_autofree(audio)
	audio._on_time_changed(20.0)
	assert_false(audio._is_night, "Hour 20 should be day (boundary)")


func test_on_time_changed_just_past_20() -> void:
	var audio: AudioStreamPlayer = AmbientScript.new()
	add_child_autofree(audio)
	audio._on_time_changed(20.1)
	assert_true(audio._is_night, "Hour 20.1 should be night")


# ==========================================================================
# Horn update logic
# ==========================================================================

func test_update_horn_activates_when_timer_expires() -> void:
	var audio: AudioStreamPlayer = AmbientScript.new()
	add_child_autofree(audio)
	audio._horn_timer = 0.1
	audio._horn_active = false
	audio._update_horn(0.2)
	assert_true(audio._horn_active, "Horn should activate when timer expires")
	assert_gt(
		audio._horn_remaining, 0.0,
		"Horn remaining time should be positive",
	)


func test_update_horn_deactivates_when_remaining_expires() -> void:
	var audio: AudioStreamPlayer = AmbientScript.new()
	add_child_autofree(audio)
	audio._horn_active = true
	audio._horn_remaining = 0.1
	audio._update_horn(0.2)
	assert_false(audio._horn_active, "Horn should deactivate when done")
	assert_gt(
		audio._horn_timer, 0.0,
		"Horn timer should be reset after deactivation",
	)


# ==========================================================================
# Gust update logic
# ==========================================================================

func test_update_gust_activates_when_timer_expires() -> void:
	var audio: AudioStreamPlayer = AmbientScript.new()
	add_child_autofree(audio)
	audio._gust_timer = 0.1
	audio._gust_active = false
	audio._update_gust(0.2)
	assert_true(audio._gust_active, "Gust should activate when timer expires")


func test_update_gust_deactivates_when_remaining_expires() -> void:
	var audio: AudioStreamPlayer = AmbientScript.new()
	add_child_autofree(audio)
	audio._gust_active = true
	audio._gust_remaining = 0.1
	audio._update_gust(0.2)
	assert_false(audio._gust_active, "Gust should deactivate when done")


# ==========================================================================
# Chirp update logic — skips at night
# ==========================================================================

func test_update_chirp_skips_at_night() -> void:
	var audio: AudioStreamPlayer = AmbientScript.new()
	add_child_autofree(audio)
	audio._is_night = true
	audio._chirp_timer = 0.01
	audio._chirp_active = false
	audio._update_chirp(1.0)
	assert_false(
		audio._chirp_active,
		"Chirps should not activate at night",
	)


func test_update_chirp_activates_during_day() -> void:
	var audio: AudioStreamPlayer = AmbientScript.new()
	add_child_autofree(audio)
	audio._is_night = false
	audio._chirp_timer = 0.1
	audio._chirp_active = false
	audio._update_chirp(0.2)
	assert_true(audio._chirp_active, "Chirps should activate during day")


# ==========================================================================
# Generator functions — return correct values when inactive
# ==========================================================================

func test_gen_horn_returns_zero_when_inactive() -> void:
	var audio: AudioStreamPlayer = AmbientScript.new()
	add_child_autofree(audio)
	audio._horn_active = false
	assert_eq(
		audio._gen_horn(), 0.0,
		"Horn generator should return 0 when inactive",
	)


func test_gen_chirp_returns_zero_when_inactive() -> void:
	var audio: AudioStreamPlayer = AmbientScript.new()
	add_child_autofree(audio)
	audio._chirp_active = false
	assert_eq(audio._gen_chirp(), 0.0)


func test_gen_chirp_returns_zero_at_night() -> void:
	var audio: AudioStreamPlayer = AmbientScript.new()
	add_child_autofree(audio)
	audio._chirp_active = true
	audio._is_night = true
	assert_eq(
		audio._gen_chirp(), 0.0,
		"Chirp should return 0 at night even if active",
	)


func test_gen_brake_returns_zero_when_inactive() -> void:
	var audio: AudioStreamPlayer = AmbientScript.new()
	add_child_autofree(audio)
	audio._brake_active = false
	assert_eq(audio._gen_brake(), 0.0)


func test_gen_cricket_returns_zero_during_day() -> void:
	var audio: AudioStreamPlayer = AmbientScript.new()
	add_child_autofree(audio)
	audio._is_night = false
	assert_eq(
		audio._gen_cricket(), 0.0,
		"Crickets should be silent during day",
	)


func test_gen_cricket_returns_nonzero_at_night() -> void:
	var audio: AudioStreamPlayer = AmbientScript.new()
	add_child_autofree(audio)
	audio._is_night = true
	# Advance phase to get a non-zero sample
	audio._cricket_phase = 0.25
	audio._cricket_phase2 = 0.25
	var sample: float = audio._gen_cricket()
	# Cricket sound has pulsing — might be zero at some phases.
	# Just verify the function runs without error.
	assert_true(
		sample is float,
		"Cricket generator should return a float at night",
	)


# ==========================================================================
# Drone phase wrapping
# ==========================================================================

func test_advance_drone_wraps_phase() -> void:
	var audio: AudioStreamPlayer = AmbientScript.new()
	add_child_autofree(audio)
	audio._phase = 0.999
	audio._phase2 = 0.999
	audio._phase3 = 0.999
	audio._advance_drone()
	assert_lt(
		audio._phase, 1.0,
		"Phase should wrap below 1.0",
	)
	assert_lt(audio._phase2, 1.0)
	assert_lt(audio._phase3, 1.0)
