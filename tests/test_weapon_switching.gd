extends GutTest
## Tests for weapon switching, cycling, unlock, and spread calculation.

const WeaponScript = preload("res://scenes/player/player_weapon.gd")


# ==========================================================================
# Spread calculation
# ==========================================================================

func test_apply_spread_with_zero_returns_original() -> void:
	var pw := Node.new()
	pw.set_script(WeaponScript)
	pw._rng.randomize()
	var dir := Vector3(0.0, 0.0, -1.0)
	var result: Vector3 = pw._apply_spread(dir, 0.0)
	assert_almost_eq(result.x, dir.x, 0.001)
	assert_almost_eq(result.y, dir.y, 0.001)
	assert_almost_eq(result.z, dir.z, 0.001)
	pw.free()


func test_apply_spread_returns_normalized() -> void:
	var pw := Node.new()
	pw.set_script(WeaponScript)
	pw._rng.randomize()
	var dir := Vector3(0.0, 0.0, -1.0)
	for _i in range(10):
		var result: Vector3 = pw._apply_spread(dir, 0.1)
		assert_almost_eq(
			result.length(), 1.0, 0.001,
			"Spread result should be unit length",
		)
	pw.free()


func test_apply_spread_stays_within_cone() -> void:
	var pw := Node.new()
	pw.set_script(WeaponScript)
	pw._rng.randomize()
	var dir := Vector3(0.0, 0.0, -1.0)
	var spread := 0.08
	for _i in range(50):
		var result: Vector3 = pw._apply_spread(dir, spread)
		var angle := dir.angle_to(result)
		assert_lt(angle, 0.2, "Spread angle should be small")
	pw.free()


# ==========================================================================
# Weapon switching
# ==========================================================================

func test_initial_state_is_pistol() -> void:
	var pw := Node.new()
	pw.set_script(WeaponScript)
	assert_eq(pw._current_idx, 0, "Should start on Pistol")
	for i in range(pw._unlocked.size()):
		assert_true(pw._unlocked[i], "Weapon %d should be unlocked" % i)
	pw.free()


func test_switch_weapon_rejects_locked() -> void:
	var pw := Node.new()
	pw.set_script(WeaponScript)
	pw._unlocked[1] = false
	pw._switch_weapon(1)
	assert_eq(pw._current_idx, 0, "Should stay on Pistol")
	pw.free()


func test_switch_weapon_accepts_unlocked() -> void:
	var pw := Node.new()
	pw.set_script(WeaponScript)
	pw._switch_weapon(2)
	assert_eq(pw._current_idx, 2, "Should switch to Shotgun")
	pw.free()


func test_switch_weapon_rejects_out_of_bounds() -> void:
	var pw := Node.new()
	pw.set_script(WeaponScript)
	pw._switch_weapon(-1)
	assert_eq(pw._current_idx, 0)
	pw._switch_weapon(99)
	assert_eq(pw._current_idx, 0)
	pw.free()


func test_cycle_weapon_forward() -> void:
	var pw := Node.new()
	pw.set_script(WeaponScript)
	pw._cycle_weapon(1)
	assert_eq(pw._current_idx, 1, "Should cycle to SMG")
	pw.free()


func test_cycle_weapon_forward_skips_locked() -> void:
	var pw := Node.new()
	pw.set_script(WeaponScript)
	pw._unlocked[1] = false
	pw._unlocked[2] = false
	pw._cycle_weapon(1)
	assert_eq(pw._current_idx, 3, "Should skip to Rifle")
	pw.free()


func test_cycle_weapon_backward_wraps() -> void:
	var pw := Node.new()
	pw.set_script(WeaponScript)
	pw._cycle_weapon(-1)
	assert_eq(pw._current_idx, 3, "Should wrap to Rifle")
	pw.free()


func test_cycle_weapon_no_other_unlocked_stays() -> void:
	var pw := Node.new()
	pw.set_script(WeaponScript)
	pw._unlocked[1] = false
	pw._unlocked[2] = false
	pw._unlocked[3] = false
	pw._cycle_weapon(1)
	assert_eq(pw._current_idx, 0, "Should stay on Pistol")
	pw.free()


# ==========================================================================
# Unlock
# ==========================================================================

func test_unlock_weapon_idempotent() -> void:
	var pw := Node.new()
	pw.set_script(WeaponScript)
	pw.unlock_weapon(1)
	pw.unlock_weapon(1)
	assert_true(pw._unlocked[1], "Double unlock should not crash")
	pw.free()


func test_unlock_weapon_rejects_invalid() -> void:
	var pw := Node.new()
	pw.set_script(WeaponScript)
	pw.unlock_weapon(-1)
	pw.unlock_weapon(99)
	assert_true(true)
	pw.free()
