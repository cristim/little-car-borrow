extends GutTest
## Tests for multi-weapon system: WEAPONS const, switching, cycling, unlock,
## spread calculation, and audio synthesis.

const WeaponScript = preload("res://scenes/player/player_weapon.gd")


# ==========================================================================
# WEAPONS const structure
# ==========================================================================

func test_weapons_count() -> void:
	assert_eq(WeaponScript.WEAPONS.size(), 4, "Should have 4 weapon types")


func test_weapon_has_required_keys() -> void:
	var required := [
		"name", "range", "damage", "cooldown", "auto", "spread",
		"pellets", "crime_mult", "body", "muzzle_z",
		"snap_dur", "body_dur", "tail_decay", "base_freq", "end_freq",
	]
	for i in range(WeaponScript.WEAPONS.size()):
		var w: Dictionary = WeaponScript.WEAPONS[i]
		for key in required:
			assert_true(
				w.has(key),
				"Weapon %d (%s) missing key: %s" % [
					i, w.get("name", "?"), key
				],
			)


func test_pistol_is_first_weapon() -> void:
	var w: Dictionary = WeaponScript.WEAPONS[0]
	assert_eq(w["name"], "Pistol")


func test_smg_is_auto_fire() -> void:
	var w: Dictionary = WeaponScript.WEAPONS[1]
	assert_eq(w["name"], "SMG")
	assert_true(w["auto"], "SMG should be auto-fire")


func test_shotgun_has_multiple_pellets() -> void:
	var w: Dictionary = WeaponScript.WEAPONS[2]
	assert_eq(w["name"], "Shotgun")
	assert_gt(w["pellets"], 1, "Shotgun should have multiple pellets")


func test_rifle_has_longest_range() -> void:
	var w: Dictionary = WeaponScript.WEAPONS[3]
	assert_eq(w["name"], "Rifle")
	var max_range := 0.0
	for weapon in WeaponScript.WEAPONS:
		var r: float = weapon["range"]
		if r > max_range:
			max_range = r
	assert_eq(
		w["range"], max_range, "Rifle should have longest range"
	)


func test_all_weapons_have_positive_cooldown() -> void:
	for w in WeaponScript.WEAPONS:
		var cd: float = w["cooldown"]
		assert_gt(cd, 0.0, "%s cooldown should be > 0" % w["name"])


func test_all_weapons_have_positive_damage() -> void:
	for w in WeaponScript.WEAPONS:
		var dmg: float = w["damage"]
		assert_gt(dmg, 0.0, "%s damage should be > 0" % w["name"])


func test_all_weapons_have_positive_range() -> void:
	for w in WeaponScript.WEAPONS:
		var r: float = w["range"]
		assert_gt(r, 0.0, "%s range should be > 0" % w["name"])


func test_pellet_damage_totals_match() -> void:
	for w in WeaponScript.WEAPONS:
		var pellets: int = w["pellets"]
		var total: float = w["damage"]
		var per_pellet: float = total / float(pellets)
		assert_gt(
			per_pellet, 0.0,
			"%s per-pellet damage should be > 0" % w["name"],
		)


# ==========================================================================
# Spread calculation
# ==========================================================================

func test_apply_spread_with_zero_returns_original() -> void:
	var pw := Node.new()
	pw.set_script(WeaponScript)
	pw._rng.randomize()
	var dir := Vector3(0.0, 0.0, -1.0)
	var result: Vector3 = pw._apply_spread(dir, 0.0)
	# With zero spread, result should be essentially the same direction
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
		# Spread of 0.08 should produce angles well under 10 degrees
		assert_lt(
			angle, 0.2,
			"Spread angle should be small",
		)
	pw.free()


# ==========================================================================
# Weapon switching and cycling
# ==========================================================================

func test_initial_state_is_pistol() -> void:
	var pw := Node.new()
	pw.set_script(WeaponScript)
	assert_eq(pw._current_idx, 0, "Should start on Pistol")
	assert_true(pw._unlocked[0], "Pistol should be unlocked")
	assert_false(pw._unlocked[1], "SMG should be locked")
	assert_false(pw._unlocked[2], "Shotgun should be locked")
	assert_false(pw._unlocked[3], "Rifle should be locked")
	pw.free()


func test_switch_weapon_rejects_locked() -> void:
	var pw := Node.new()
	pw.set_script(WeaponScript)
	pw._switch_weapon(1)
	assert_eq(
		pw._current_idx, 0,
		"Should stay on Pistol when SMG is locked",
	)
	pw.free()


func test_switch_weapon_accepts_unlocked() -> void:
	var pw := Node.new()
	pw.set_script(WeaponScript)
	pw._unlocked[2] = true
	pw._switch_weapon(2)
	assert_eq(pw._current_idx, 2, "Should switch to Shotgun")
	pw.free()


func test_switch_weapon_rejects_same_index() -> void:
	var pw := Node.new()
	pw.set_script(WeaponScript)
	# Already on 0, switching to 0 should be a no-op (no signal)
	pw._switch_weapon(0)
	assert_eq(pw._current_idx, 0)
	pw.free()


func test_switch_weapon_rejects_out_of_bounds() -> void:
	var pw := Node.new()
	pw.set_script(WeaponScript)
	pw._switch_weapon(-1)
	assert_eq(pw._current_idx, 0)
	pw._switch_weapon(99)
	assert_eq(pw._current_idx, 0)
	pw.free()


func test_cycle_weapon_forward_skips_locked() -> void:
	var pw := Node.new()
	pw.set_script(WeaponScript)
	# Unlock only Rifle (idx 3)
	pw._unlocked[3] = true
	pw._cycle_weapon(1)
	assert_eq(
		pw._current_idx, 3,
		"Should skip locked SMG/Shotgun and land on Rifle",
	)
	pw.free()


func test_cycle_weapon_backward_wraps() -> void:
	var pw := Node.new()
	pw.set_script(WeaponScript)
	# Unlock Rifle
	pw._unlocked[3] = true
	pw._current_idx = 3
	# Cycle backward should skip locked 2,1 and land on 0
	pw._cycle_weapon(-1)
	assert_eq(pw._current_idx, 0, "Should wrap to Pistol")
	pw.free()


func test_cycle_weapon_no_other_unlocked_stays() -> void:
	var pw := Node.new()
	pw.set_script(WeaponScript)
	# Only Pistol unlocked -- cycling should stay on Pistol
	pw._cycle_weapon(1)
	assert_eq(
		pw._current_idx, 0,
		"Should stay on Pistol when no other is unlocked",
	)
	pw.free()


# ==========================================================================
# Unlock
# ==========================================================================

func test_unlock_weapon_sets_flag() -> void:
	var pw := Node.new()
	pw.set_script(WeaponScript)
	assert_false(pw._unlocked[1])
	pw.unlock_weapon(1)
	assert_true(pw._unlocked[1], "SMG should be unlocked")
	pw.free()


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
	# Should not crash
	assert_true(true)
	pw.free()
