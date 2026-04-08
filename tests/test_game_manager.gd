extends GutTest
## Tests for GameManager autoload — money, health, damage, save/load.
## Uses real autoloads since GameManager references EventBus by global name.

const GameManagerScript = preload("res://src/autoloads/game_manager.gd")

# Saved state for restoration
var _saved_money: int
var _saved_missions: int
var _saved_earnings: int
var _saved_health: float
var _saved_is_dead: bool


func before_each() -> void:
	_saved_money = GameManager.money
	_saved_missions = GameManager.missions_completed
	_saved_earnings = GameManager.total_earnings
	_saved_health = GameManager.health
	_saved_is_dead = GameManager.is_dead

	GameManager.money = 0
	GameManager.missions_completed = 0
	GameManager.total_earnings = 0
	GameManager.health = GameManagerScript.MAX_HEALTH
	GameManager.is_dead = false


func after_each() -> void:
	GameManager.money = _saved_money
	GameManager.missions_completed = _saved_missions
	GameManager.total_earnings = _saved_earnings
	GameManager.health = _saved_health
	GameManager.is_dead = _saved_is_dead


# ================================================================
# Constants
# ================================================================


func test_max_health() -> void:
	assert_eq(
		GameManagerScript.MAX_HEALTH,
		100.0,
		"MAX_HEALTH should be 100.0",
	)


# ================================================================
# add_money
# ================================================================


func test_add_money_increases_balance() -> void:
	GameManager.add_money(100)
	assert_eq(GameManager.money, 100, "Money should increase by 100")


func test_add_money_tracks_total_earnings() -> void:
	GameManager.add_money(200)
	assert_eq(
		GameManager.total_earnings,
		200,
		"total_earnings should track positive",
	)


func test_add_negative_does_not_track_earnings() -> void:
	GameManager.add_money(100)
	var earnings_before: int = GameManager.total_earnings
	GameManager.add_money(-50)
	assert_eq(
		GameManager.total_earnings,
		earnings_before,
		"Negative amounts should not add to total_earnings",
	)


func test_add_money_emits_signal() -> void:
	var received := []
	var cb := func(amount: int) -> void: received.append(amount)
	EventBus.player_money_changed.connect(cb)
	GameManager.add_money(50)
	EventBus.player_money_changed.disconnect(cb)
	assert_eq(
		received,
		[50],
		"Should emit player_money_changed with new total",
	)


func test_add_money_accumulates() -> void:
	GameManager.add_money(100)
	GameManager.add_money(200)
	assert_eq(GameManager.money, 300, "Money should accumulate")


# ================================================================
# deduct_money
# ================================================================


func test_deduct_money_success() -> void:
	GameManager.money = 100
	var result: bool = GameManager.deduct_money(50)
	assert_true(result, "Deducting available money should return true")
	assert_eq(GameManager.money, 50, "Money should be reduced")


func test_deduct_money_exact_balance() -> void:
	GameManager.money = 100
	var result: bool = GameManager.deduct_money(100)
	assert_true(result, "Deducting exact balance should succeed")
	assert_eq(GameManager.money, 0, "Money should be zero")


func test_deduct_money_insufficient() -> void:
	GameManager.money = 50
	var result: bool = GameManager.deduct_money(100)
	assert_false(result, "Deducting more than balance should return false")
	assert_eq(
		GameManager.money,
		50,
		"Money should not change on failure",
	)


func test_deduct_money_emits_signal_on_success() -> void:
	GameManager.money = 100
	var received := []
	var cb := func(amount: int) -> void: received.append(amount)
	EventBus.player_money_changed.connect(cb)
	GameManager.deduct_money(30)
	EventBus.player_money_changed.disconnect(cb)
	assert_eq(
		received,
		[70],
		"Should emit with new balance after deduction",
	)


func test_deduct_money_no_signal_on_failure() -> void:
	GameManager.money = 10
	var received := []
	var cb := func(amount: int) -> void: received.append(amount)
	EventBus.player_money_changed.connect(cb)
	GameManager.deduct_money(100)
	EventBus.player_money_changed.disconnect(cb)
	assert_eq(
		received.size(),
		0,
		"Should not emit signal on failed deduction",
	)


# ================================================================
# take_damage
# ================================================================


func test_take_damage_reduces_health() -> void:
	GameManager.take_damage(30.0)
	assert_almost_eq(
		GameManager.health,
		70.0,
		0.01,
		"Health should be reduced by damage",
	)


func test_take_damage_emits_health_signal() -> void:
	var received := []
	var cb := func(cur: float, mx: float) -> void: received.append([cur, mx])
	EventBus.player_health_changed.connect(cb)
	GameManager.take_damage(25.0)
	EventBus.player_health_changed.disconnect(cb)
	assert_eq(received.size(), 1, "Should emit health_changed once")
	assert_almost_eq(received[0][0], 75.0, 0.01, "Current health should be 75")
	assert_almost_eq(received[0][1], 100.0, 0.01, "Max health should be 100")


func test_take_damage_does_not_go_negative() -> void:
	GameManager.take_damage(150.0)
	assert_almost_eq(
		GameManager.health,
		0.0,
		0.01,
		"Health should not go below 0",
	)


func test_take_damage_triggers_death_at_zero() -> void:
	var died := []
	var cb := func() -> void: died.append(true)
	EventBus.player_died.connect(cb)
	GameManager.take_damage(100.0)
	EventBus.player_died.disconnect(cb)
	assert_true(GameManager.is_dead, "Should be dead at 0 health")
	assert_eq(died.size(), 1, "Should emit player_died")


func test_take_damage_ignored_when_dead() -> void:
	GameManager.is_dead = true
	GameManager.health = 0.0
	GameManager.take_damage(50.0)
	assert_almost_eq(
		GameManager.health,
		0.0,
		0.01,
		"Damage should be ignored when dead",
	)


func test_multiple_damage_accumulates() -> void:
	GameManager.take_damage(30.0)
	GameManager.take_damage(20.0)
	assert_almost_eq(
		GameManager.health,
		50.0,
		0.01,
		"Damage should accumulate",
	)


# ================================================================
# heal
# ================================================================


func test_heal_increases_health() -> void:
	GameManager.health = 50.0
	GameManager.heal(30.0)
	assert_almost_eq(
		GameManager.health,
		80.0,
		0.01,
		"Heal should increase health",
	)


func test_heal_does_not_exceed_max() -> void:
	GameManager.health = 90.0
	GameManager.heal(50.0)
	assert_almost_eq(
		GameManager.health,
		GameManagerScript.MAX_HEALTH,
		0.01,
		"Health should not exceed MAX_HEALTH",
	)


func test_heal_emits_health_signal() -> void:
	GameManager.health = 50.0
	var received := []
	var cb := func(cur: float, mx: float) -> void: received.append([cur, mx])
	EventBus.player_health_changed.connect(cb)
	GameManager.heal(10.0)
	EventBus.player_health_changed.disconnect(cb)
	assert_eq(received.size(), 1, "Should emit health_changed on heal")
	assert_almost_eq(received[0][0], 60.0, 0.01, "Health should be 60")


func test_heal_ignored_when_dead() -> void:
	GameManager.is_dead = true
	GameManager.health = 0.0
	GameManager.heal(50.0)
	assert_almost_eq(
		GameManager.health,
		0.0,
		0.01,
		"Heal should be ignored when dead",
	)


# ================================================================
# _on_mission_completed
# ================================================================


func test_mission_completed_increments_count() -> void:
	var before: int = GameManager.missions_completed
	GameManager._on_mission_completed("test_mission")
	assert_eq(
		GameManager.missions_completed,
		before + 1,
		"Should increment missions_completed",
	)


func test_mission_completed_signal_triggers_handler() -> void:
	var before: int = GameManager.missions_completed
	EventBus.mission_completed.emit("some_mission")
	assert_eq(
		GameManager.missions_completed,
		before + 1,
		"EventBus signal should trigger mission counter",
	)


# ================================================================
# save/load progress
# ================================================================


func test_save_and_load_roundtrip() -> void:
	GameManager.money = 999
	GameManager.missions_completed = 5
	GameManager.total_earnings = 1500
	GameManager.save_progress()

	GameManager.money = 0
	GameManager.missions_completed = 0
	GameManager.total_earnings = 0
	GameManager.load_progress()

	assert_eq(GameManager.money, 999, "Money should persist")
	assert_eq(
		GameManager.missions_completed,
		5,
		"Missions completed should persist",
	)
	assert_eq(
		GameManager.total_earnings,
		1500,
		"Total earnings should persist",
	)


func test_load_emits_money_signal() -> void:
	GameManager.money = 42
	GameManager.save_progress()

	var received := []
	var cb := func(amount: int) -> void: received.append(amount)
	EventBus.player_money_changed.connect(cb)
	GameManager.load_progress()
	EventBus.player_money_changed.disconnect(cb)
	assert_eq(received, [42], "load_progress should emit money signal")


# ================================================================
# Death
# ================================================================


func test_die_sets_is_dead() -> void:
	GameManager._die()
	assert_true(GameManager.is_dead, "_die should set is_dead")


func test_die_emits_player_died() -> void:
	var received := []
	var cb := func() -> void: received.append(true)
	EventBus.player_died.connect(cb)
	GameManager._die()
	EventBus.player_died.disconnect(cb)
	assert_eq(received.size(), 1, "_die should emit player_died")


func test_lethal_damage_emits_died_only_once() -> void:
	var received := []
	var cb := func() -> void: received.append(true)
	EventBus.player_died.connect(cb)
	GameManager.take_damage(200.0)
	GameManager.take_damage(50.0)  # should be ignored (is_dead)
	EventBus.player_died.disconnect(cb)
	assert_eq(
		received.size(),
		1,
		"player_died should only emit once",
	)


# ================================================================
# Instance-based tests (fresh .new() instances for coverage)
# ================================================================


func test_instance_add_money() -> void:
	var gm: Node = GameManagerScript.new()
	add_child_autofree(gm)
	gm.money = 0
	gm.is_dead = false
	gm.add_money(100)
	assert_eq(gm.money, 100, "Instance add_money should work")


func test_instance_take_damage() -> void:
	var gm: Node = GameManagerScript.new()
	add_child_autofree(gm)
	gm.health = 100.0
	gm.is_dead = false
	gm.take_damage(40.0)
	assert_almost_eq(gm.health, 60.0, 0.01, "Instance take_damage should reduce health")


func test_instance_heal() -> void:
	var gm: Node = GameManagerScript.new()
	add_child_autofree(gm)
	gm.health = 50.0
	gm.is_dead = false
	gm.heal(30.0)
	assert_almost_eq(gm.health, 80.0, 0.01, "Instance heal should increase health")


func test_instance_deduct_money_success() -> void:
	var gm: Node = GameManagerScript.new()
	add_child_autofree(gm)
	gm.money = 100
	var ok: bool = gm.deduct_money(50)
	assert_true(ok, "deduct_money should return true when sufficient")
	assert_eq(gm.money, 50, "money should be reduced")


func test_instance_deduct_money_fail() -> void:
	var gm: Node = GameManagerScript.new()
	add_child_autofree(gm)
	gm.money = 10
	var ok: bool = gm.deduct_money(50)
	assert_false(ok, "deduct_money should return false when insufficient")


func test_instance_die() -> void:
	var gm: Node = GameManagerScript.new()
	add_child_autofree(gm)
	gm.health = 5.0
	gm.is_dead = false
	gm.take_damage(10.0)
	assert_true(gm.is_dead, "Player should die when health reaches 0")


func test_instance_on_mission_completed() -> void:
	var gm: Node = GameManagerScript.new()
	add_child_autofree(gm)
	gm.missions_completed = 0
	gm._on_mission_completed("test")
	assert_eq(gm.missions_completed, 1, "_on_mission_completed should increment counter")
