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


# ================================================================
# _process — direct state manipulation
# ================================================================


func test_process_decays_heat_when_cooldown_zero() -> void:
	WantedLevelManager.heat = 50.0
	WantedLevelManager._decay_cooldown = 0.0
	WantedLevelManager._process(1.0)
	var expected: float = 50.0 - WantedScript.HEAT_DECAY_RATE * 1.0
	assert_almost_eq(
		WantedLevelManager.heat,
		expected,
		0.5,
		"heat should decrease by HEAT_DECAY_RATE per second when cooldown is zero",
	)


func test_process_decrements_cooldown_when_active() -> void:
	WantedLevelManager.heat = 50.0
	WantedLevelManager._decay_cooldown = 2.0
	WantedLevelManager._process(1.0)
	assert_almost_eq(
		WantedLevelManager.heat,
		50.0,
		0.01,
		"heat should be unchanged while cooldown is active",
	)
	assert_almost_eq(
		WantedLevelManager._decay_cooldown,
		1.0,
		0.01,
		"cooldown should decrement by delta",
	)


func test_process_zero_heat_early_return() -> void:
	WantedLevelManager.heat = 0.0
	WantedLevelManager._decay_cooldown = 0.0
	WantedLevelManager.wanted_level = 0
	WantedLevelManager._process(1.0)
	assert_eq(WantedLevelManager.heat, 0.0, "heat should remain zero")
	assert_eq(WantedLevelManager.wanted_level, 0, "wanted_level should remain zero")


# ================================================================
# _update_level — called directly
# ================================================================


func test_update_level_sets_level_1_at_threshold() -> void:
	WantedLevelManager.heat = 20.0
	WantedLevelManager._update_level()
	assert_eq(WantedLevelManager.wanted_level, 1, "heat=20 should yield level 1")


func test_update_level_sets_level_5_at_threshold() -> void:
	WantedLevelManager.heat = 260.0
	WantedLevelManager._update_level()
	assert_eq(WantedLevelManager.wanted_level, 5, "heat=260 should yield level 5")


func test_update_level_emits_signal_on_change() -> void:
	WantedLevelManager.wanted_level = 0
	WantedLevelManager.heat = 20.0
	var received := []
	var cb := func(level: int) -> void: received.append(level)
	EventBus.wanted_level_changed.connect(cb)
	WantedLevelManager._update_level()
	EventBus.wanted_level_changed.disconnect(cb)
	assert_true(received.has(1), "should emit wanted_level_changed(1) on level transition")


func test_update_level_no_signal_when_unchanged() -> void:
	WantedLevelManager.heat = 20.0
	WantedLevelManager._update_level()
	assert_eq(WantedLevelManager.wanted_level, 1, "precondition: level is 1")
	var received := []
	var cb := func(level: int) -> void: received.append(level)
	EventBus.wanted_level_changed.connect(cb)
	WantedLevelManager._update_level()
	EventBus.wanted_level_changed.disconnect(cb)
	assert_eq(received.size(), 0, "no signal when level stays the same")


# ================================================================
# clear — combined reset assertion
# ================================================================


func test_clear_resets_all_fields() -> void:
	WantedLevelManager.heat = 100.0
	WantedLevelManager.wanted_level = 2
	WantedLevelManager._decay_cooldown = 3.0
	WantedLevelManager.clear()
	assert_eq(WantedLevelManager.heat, 0.0, "clear should zero heat")
	assert_eq(WantedLevelManager.wanted_level, 0, "clear should zero wanted_level")
	assert_eq(WantedLevelManager._decay_cooldown, 0.0, "clear should zero decay_cooldown")


func test_clear_emits_wanted_level_zero() -> void:
	WantedLevelManager.heat = 100.0
	WantedLevelManager.wanted_level = 2
	var received := []
	var cb := func(level: int) -> void: received.append(level)
	EventBus.wanted_level_changed.connect(cb)
	WantedLevelManager.clear()
	EventBus.wanted_level_changed.disconnect(cb)
	assert_true(received.has(0), "clear should emit wanted_level_changed(0)")


# ================================================================
# Instance-based tests (fresh .new() instances for coverage)
# ================================================================


func test_instance_process_heat_decay() -> void:
	var wlm: Node = WantedScript.new()
	add_child_autofree(wlm)
	wlm.heat = 50.0
	wlm._decay_cooldown = 0.0
	wlm.wanted_level = 0
	wlm._process(1.0)
	assert_lt(wlm.heat, 50.0, "Heat should decay when cooldown is 0")


func test_instance_process_cooldown_decrements() -> void:
	var wlm: Node = WantedScript.new()
	add_child_autofree(wlm)
	wlm.heat = 50.0
	wlm._decay_cooldown = 3.0
	wlm._process(1.0)
	assert_almost_eq(wlm._decay_cooldown, 2.0, 0.01, "Cooldown should decrement")
	assert_almost_eq(wlm.heat, 50.0, 0.01, "Heat should not decay during cooldown")


func test_instance_update_level_thresholds() -> void:
	var wlm: Node = WantedScript.new()
	add_child_autofree(wlm)
	wlm.heat = 20.0
	wlm.wanted_level = 0
	wlm._update_level()
	assert_eq(wlm.wanted_level, 1, "20 heat should give level 1")


func test_instance_clear() -> void:
	var wlm: Node = WantedScript.new()
	add_child_autofree(wlm)
	wlm.heat = 100.0
	wlm.wanted_level = 2
	wlm._decay_cooldown = 3.0
	wlm.clear()
	assert_eq(wlm.heat, 0.0, "heat should be 0 after clear")
	assert_eq(wlm.wanted_level, 0, "level should be 0 after clear")


# ================================================================
# H1 — _try_unlock_rifle fires at most once
# XH2 — _try_unlock_rifle safe with freed player node
# ================================================================


func test_rifle_unlocked_flag_set_after_valid_player() -> void:
	var wlm: Node = WantedScript.new()
	add_child_autofree(wlm)
	var p := Node.new()
	p.add_to_group("player")
	add_child_autofree(p)
	wlm._try_unlock_rifle()
	assert_true(wlm._rifle_unlocked, "Flag must be set after first unlock attempt with valid player")


func test_rifle_unlock_idempotent() -> void:
	var wlm: Node = WantedScript.new()
	add_child_autofree(wlm)
	var p := Node.new()
	p.add_to_group("player")
	add_child_autofree(p)
	wlm._try_unlock_rifle()
	var flag_after_first: bool = wlm._rifle_unlocked
	wlm._try_unlock_rifle()
	assert_true(flag_after_first, "Flag set on first call")
	assert_true(wlm._rifle_unlocked, "Flag stays set on second call")


func test_rifle_unlock_safe_with_freed_player() -> void:
	var wlm: Node = WantedScript.new()
	add_child_autofree(wlm)
	var p := Node.new()
	p.add_to_group("player")
	add_child(p)
	p.free()
	wlm._try_unlock_rifle()
	pass_test("_try_unlock_rifle with freed player must not crash")
