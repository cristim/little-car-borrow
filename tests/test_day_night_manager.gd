extends GutTest
## Tests for DayNightManager — time progression, day/night queries, signal emission.
## Uses real autoloads since DayNightManager references EventBus globally.

const DayNightScript = preload("res://src/autoloads/day_night_manager.gd")

# Saved state
var _saved_hour: float
var _saved_speed: float
var _saved_last_emitted: float


func before_each() -> void:
	_saved_hour = DayNightManager.current_hour
	_saved_speed = DayNightManager.time_speed
	_saved_last_emitted = DayNightManager._last_emitted_hour

	DayNightManager.current_hour = 18.0
	DayNightManager.time_speed = 1.0


func after_each() -> void:
	DayNightManager.current_hour = _saved_hour
	DayNightManager.time_speed = _saved_speed
	DayNightManager._last_emitted_hour = _saved_last_emitted


# ================================================================
# Constants
# ================================================================

func test_cycle_duration() -> void:
	assert_eq(
		DayNightScript.CYCLE_DURATION, 1200.0,
		"Cycle should be 1200 seconds",
	)


func test_hours_per_second() -> void:
	assert_almost_eq(
		DayNightScript.HOURS_PER_SECOND, 24.0 / 1200.0, 0.0001,
		"HOURS_PER_SECOND should be 24/1200",
	)


func test_emit_interval() -> void:
	assert_eq(
		DayNightScript.EMIT_INTERVAL, 0.5,
		"EMIT_INTERVAL should be 0.5 game-hours",
	)


# ================================================================
# Initial state
# ================================================================

func test_initial_hour() -> void:
	assert_eq(
		DayNightManager.current_hour, 18.0,
		"Should start at 18.0 (6 PM)",
	)


func test_initial_time_speed() -> void:
	assert_eq(
		DayNightManager.time_speed, 1.0,
		"Default time_speed should be 1.0",
	)


# ================================================================
# is_night
# ================================================================

func test_is_night_at_midnight() -> void:
	DayNightManager.current_hour = 0.0
	assert_true(DayNightManager.is_night(), "Midnight should be night")


func test_is_night_at_3am() -> void:
	DayNightManager.current_hour = 3.0
	assert_true(DayNightManager.is_night(), "3 AM should be night")


func test_is_night_at_5_59am() -> void:
	DayNightManager.current_hour = 5.99
	assert_true(DayNightManager.is_night(), "5:59 AM should be night")


func test_is_not_night_at_6am() -> void:
	DayNightManager.current_hour = 6.0
	assert_false(
		DayNightManager.is_night(),
		"6 AM should not be night (boundary)",
	)


func test_is_not_night_at_noon() -> void:
	DayNightManager.current_hour = 12.0
	assert_false(DayNightManager.is_night(), "Noon should not be night")


func test_is_not_night_at_20() -> void:
	DayNightManager.current_hour = 20.0
	assert_false(
		DayNightManager.is_night(),
		"8 PM exactly should not be night (boundary)",
	)


func test_is_night_at_21() -> void:
	DayNightManager.current_hour = 21.0
	assert_true(DayNightManager.is_night(), "9 PM should be night")


func test_is_night_at_23() -> void:
	DayNightManager.current_hour = 23.0
	assert_true(DayNightManager.is_night(), "11 PM should be night")


# ================================================================
# is_dusk_or_dawn
# ================================================================

func test_dawn_at_5am() -> void:
	DayNightManager.current_hour = 5.0
	assert_true(DayNightManager.is_dusk_or_dawn(), "5 AM should be dawn")


func test_dawn_at_6am() -> void:
	DayNightManager.current_hour = 6.0
	assert_true(DayNightManager.is_dusk_or_dawn(), "6 AM should be dawn")


func test_dawn_at_7am() -> void:
	DayNightManager.current_hour = 7.0
	assert_true(DayNightManager.is_dusk_or_dawn(), "7 AM should be dawn")


func test_not_dawn_at_8am() -> void:
	DayNightManager.current_hour = 8.0
	assert_false(
		DayNightManager.is_dusk_or_dawn(),
		"8 AM should not be dawn/dusk",
	)


func test_dusk_at_17() -> void:
	DayNightManager.current_hour = 17.0
	assert_true(DayNightManager.is_dusk_or_dawn(), "5 PM should be dusk")


func test_dusk_at_19() -> void:
	DayNightManager.current_hour = 19.0
	assert_true(DayNightManager.is_dusk_or_dawn(), "7 PM should be dusk")


func test_dusk_at_20() -> void:
	DayNightManager.current_hour = 20.0
	assert_true(DayNightManager.is_dusk_or_dawn(), "8 PM should be dusk")


func test_not_dusk_at_21() -> void:
	DayNightManager.current_hour = 21.0
	assert_false(
		DayNightManager.is_dusk_or_dawn(),
		"9 PM should not be dusk",
	)


func test_not_dusk_or_dawn_at_noon() -> void:
	DayNightManager.current_hour = 12.0
	assert_false(
		DayNightManager.is_dusk_or_dawn(),
		"Noon should not be dusk/dawn",
	)


func test_not_dusk_or_dawn_at_3am() -> void:
	DayNightManager.current_hour = 3.0
	assert_false(
		DayNightManager.is_dusk_or_dawn(),
		"3 AM should not be dusk/dawn",
	)


# ================================================================
# get_sun_progress
# ================================================================

func test_sun_progress_at_midnight() -> void:
	DayNightManager.current_hour = 0.0
	assert_almost_eq(
		DayNightManager.get_sun_progress(), 0.0, 0.001,
		"Sun progress at midnight should be 0.0",
	)


func test_sun_progress_at_noon() -> void:
	DayNightManager.current_hour = 12.0
	assert_almost_eq(
		DayNightManager.get_sun_progress(), 0.5, 0.001,
		"Sun progress at noon should be 0.5",
	)


func test_sun_progress_at_6pm() -> void:
	DayNightManager.current_hour = 18.0
	assert_almost_eq(
		DayNightManager.get_sun_progress(), 0.75, 0.001,
		"Sun progress at 6 PM should be 0.75",
	)


# ================================================================
# _process — time advancement
# ================================================================

func test_process_advances_time() -> void:
	var start: float = DayNightManager.current_hour
	DayNightManager._process(1.0)
	var expected: float = start + DayNightScript.HOURS_PER_SECOND * 1.0
	assert_almost_eq(
		DayNightManager.current_hour, fmod(expected, 24.0), 0.001,
		"_process should advance current_hour",
	)


func test_process_wraps_at_24() -> void:
	DayNightManager.current_hour = 23.99
	DayNightManager._process(10.0)
	assert_lt(
		DayNightManager.current_hour, 24.0,
		"current_hour should wrap via fmod and stay < 24",
	)


func test_time_speed_multiplier() -> void:
	DayNightManager.current_hour = 12.0
	DayNightManager.time_speed = 2.0
	DayNightManager._process(1.0)
	var expected: float = 12.0 + DayNightScript.HOURS_PER_SECOND * 2.0
	assert_almost_eq(
		DayNightManager.current_hour, expected, 0.001,
		"time_speed=2 should double advancement rate",
	)


func test_zero_time_speed_freezes_time() -> void:
	DayNightManager.current_hour = 12.0
	DayNightManager.time_speed = 0.0
	DayNightManager._process(100.0)
	assert_almost_eq(
		DayNightManager.current_hour, 12.0, 0.001,
		"time_speed=0 should freeze time",
	)
