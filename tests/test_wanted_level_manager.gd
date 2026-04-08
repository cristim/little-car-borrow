extends GutTest
## Tests for WantedLevelManager — heat accumulation, level thresholds, decay.
## Uses real autoloads since WantedLevelManager references EventBus globally.

const WantedScript = preload("res://src/autoloads/wanted_level_manager.gd")

# Saved state
var _saved_level: int
var _saved_heat: float
var _saved_cooldown: float


func before_each() -> void:
	_saved_level = WantedLevelManager.wanted_level
	_saved_heat = WantedLevelManager.heat
	_saved_cooldown = WantedLevelManager._decay_cooldown

	WantedLevelManager.wanted_level = 0
	WantedLevelManager.heat = 0.0
	WantedLevelManager._decay_cooldown = 0.0


func after_each() -> void:
	WantedLevelManager.wanted_level = _saved_level
	WantedLevelManager.heat = _saved_heat
	WantedLevelManager._decay_cooldown = _saved_cooldown


# ================================================================
# Constants
# ================================================================


func test_heat_thresholds() -> void:
	assert_eq(
		WantedScript.HEAT_THRESHOLDS.size(),
		6,
		"Should have 6 heat thresholds (0-5 stars)",
	)
	assert_eq(
		WantedScript.HEAT_THRESHOLDS[0],
		0.0,
		"First threshold should be 0",
	)


func test_heat_decay_rate() -> void:
	assert_eq(
		WantedScript.HEAT_DECAY_RATE,
		3.0,
		"HEAT_DECAY_RATE should be 3.0",
	)


func test_heat_decay_delay() -> void:
	assert_eq(
		WantedScript.HEAT_DECAY_DELAY,
		5.0,
		"HEAT_DECAY_DELAY should be 5.0",
	)


# ================================================================
# Initial state
# ================================================================


func test_initial_wanted_level() -> void:
	assert_eq(
		WantedLevelManager.wanted_level,
		0,
		"Should start at wanted level 0",
	)


func test_initial_heat() -> void:
	assert_eq(WantedLevelManager.heat, 0.0, "Should start with 0 heat")


# ================================================================
# Crime committed — heat accumulation
# ================================================================


func test_crime_adds_heat() -> void:
	WantedLevelManager._on_crime_committed("theft", 30)
	assert_almost_eq(
		WantedLevelManager.heat,
		30.0,
		0.01,
		"Crime should add heat points",
	)


func test_multiple_crimes_accumulate() -> void:
	WantedLevelManager._on_crime_committed("hit", 10)
	WantedLevelManager._on_crime_committed("hit", 10)
	WantedLevelManager._on_crime_committed("hit", 10)
	assert_almost_eq(
		WantedLevelManager.heat,
		30.0,
		0.01,
		"Multiple crimes should accumulate heat",
	)


func test_heat_caps_at_max_plus_40() -> void:
	var max_threshold: float = WantedScript.HEAT_THRESHOLDS[-1]
	var cap: float = max_threshold + 40.0
	WantedLevelManager._on_crime_committed("rampage", 999)
	assert_almost_eq(
		WantedLevelManager.heat,
		cap,
		0.01,
		"Heat should cap at last threshold + 40",
	)


func test_crime_resets_decay_cooldown() -> void:
	WantedLevelManager._on_crime_committed("hit", 10)
	assert_almost_eq(
		WantedLevelManager._decay_cooldown,
		WantedScript.HEAT_DECAY_DELAY,
		0.01,
		"Crime should reset decay cooldown",
	)


# ================================================================
# Wanted level transitions
# ================================================================


func test_level_1_threshold() -> void:
	WantedLevelManager._on_crime_committed("hit", 20)
	assert_eq(WantedLevelManager.wanted_level, 1, "20 heat -> level 1")


func test_level_2_threshold() -> void:
	WantedLevelManager._on_crime_committed("hit", 50)
	assert_eq(WantedLevelManager.wanted_level, 2, "50 heat -> level 2")


func test_level_3_threshold() -> void:
	WantedLevelManager._on_crime_committed("hit", 100)
	assert_eq(WantedLevelManager.wanted_level, 3, "100 heat -> level 3")


func test_level_4_threshold() -> void:
	WantedLevelManager._on_crime_committed("hit", 170)
	assert_eq(WantedLevelManager.wanted_level, 4, "170 heat -> level 4")


func test_level_5_threshold() -> void:
	WantedLevelManager._on_crime_committed("hit", 260)
	assert_eq(WantedLevelManager.wanted_level, 5, "260 heat -> level 5")


func test_below_level_1_stays_zero() -> void:
	WantedLevelManager._on_crime_committed("hit", 19)
	assert_eq(
		WantedLevelManager.wanted_level,
		0,
		"19 heat should stay at level 0",
	)


func test_level_change_emits_signal() -> void:
	var received := []
	var cb := func(level: int) -> void: received.append(level)
	EventBus.wanted_level_changed.connect(cb)
	WantedLevelManager._on_crime_committed("hit", 50)
	EventBus.wanted_level_changed.disconnect(cb)
	assert_true(
		received.has(2),
		"Should emit wanted_level_changed with level 2",
	)


func test_no_signal_when_level_unchanged() -> void:
	WantedLevelManager._on_crime_committed("hit", 20)
	var received := []
	var cb := func(level: int) -> void: received.append(level)
	EventBus.wanted_level_changed.connect(cb)
	WantedLevelManager._on_crime_committed("hit", 5)
	EventBus.wanted_level_changed.disconnect(cb)
	assert_eq(
		received.size(),
		0,
		"Should not emit signal when level stays the same",
	)


# ================================================================
# Heat decay
# ================================================================


func test_no_decay_during_cooldown() -> void:
	WantedLevelManager._on_crime_committed("hit", 30)
	var heat_before: float = WantedLevelManager.heat
	WantedLevelManager._process(1.0)  # still within 5s cooldown
	assert_almost_eq(
		WantedLevelManager.heat,
		heat_before,
		0.01,
		"Heat should not decay during cooldown",
	)


func test_decay_after_cooldown_expires() -> void:
	WantedLevelManager._on_crime_committed("hit", 30)
	# Consume the cooldown
	WantedLevelManager._process(5.0)
	assert_almost_eq(
		WantedLevelManager.heat,
		30.0,
		0.01,
		"Heat should not decay while cooldown is draining",
	)
	# Now decay should happen
	WantedLevelManager._process(1.0)
	var expected: float = 30.0 - WantedScript.HEAT_DECAY_RATE * 1.0
	assert_almost_eq(
		WantedLevelManager.heat,
		expected,
		0.01,
		"Heat should decay at HEAT_DECAY_RATE after cooldown",
	)


func test_heat_does_not_go_negative() -> void:
	WantedLevelManager.heat = 1.0
	WantedLevelManager._decay_cooldown = 0.0
	WantedLevelManager._process(100.0)
	assert_almost_eq(
		WantedLevelManager.heat,
		0.0,
		0.01,
		"Heat should not go below 0",
	)


func test_no_processing_when_heat_zero() -> void:
	WantedLevelManager.heat = 0.0
	WantedLevelManager.wanted_level = 0
	WantedLevelManager._process(1.0)
	assert_eq(
		WantedLevelManager.heat,
		0.0,
		"Zero heat should remain zero",
	)


func test_decay_reduces_wanted_level() -> void:
	WantedLevelManager._on_crime_committed("hit", 25)
	assert_eq(WantedLevelManager.wanted_level, 1, "Should be level 1")

	WantedLevelManager._decay_cooldown = 0.0
	var delta_needed: float = 6.0 / WantedScript.HEAT_DECAY_RATE
	WantedLevelManager._process(delta_needed + 0.1)
	assert_eq(
		WantedLevelManager.wanted_level,
		0,
		"Decayed heat should reduce wanted level",
	)


# ================================================================
# clear
# ================================================================


func test_clear_resets_heat() -> void:
	WantedLevelManager._on_crime_committed("hit", 100)
	WantedLevelManager.clear()
	assert_eq(WantedLevelManager.heat, 0.0, "clear should reset heat")


func test_clear_resets_wanted_level() -> void:
	WantedLevelManager._on_crime_committed("hit", 100)
	WantedLevelManager.clear()
	assert_eq(
		WantedLevelManager.wanted_level,
		0,
		"clear should reset wanted_level",
	)


func test_clear_resets_decay_cooldown() -> void:
	WantedLevelManager._on_crime_committed("hit", 100)
	WantedLevelManager.clear()
	assert_eq(
		WantedLevelManager._decay_cooldown,
		0.0,
		"clear should reset decay cooldown",
	)


func test_clear_emits_level_zero() -> void:
	WantedLevelManager._on_crime_committed("hit", 100)
	var received := []
	var cb := func(level: int) -> void: received.append(level)
	EventBus.wanted_level_changed.connect(cb)
	WantedLevelManager.clear()
	EventBus.wanted_level_changed.disconnect(cb)
	assert_true(
		received.has(0),
		"clear should emit wanted_level_changed(0)",
	)


func test_clear_when_already_zero() -> void:
	WantedLevelManager.clear()
	assert_eq(WantedLevelManager.wanted_level, 0, "Should stay zero")
	assert_eq(WantedLevelManager.heat, 0.0, "Should stay zero heat")
