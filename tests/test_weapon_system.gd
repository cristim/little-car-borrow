extends GutTest
## Tests for WEAPONS const structure and weapon properties.

const WeaponScript = preload("res://scenes/player/player_weapon.gd")


func test_weapons_count() -> void:
	assert_eq(WeaponScript.WEAPONS.size(), 4, "Should have 4 weapon types")


func test_weapon_has_required_keys() -> void:
	var required := [
		"name",
		"range",
		"damage",
		"cooldown",
		"auto",
		"spread",
		"pellets",
		"crime_mult",
		"body",
		"muzzle_z",
		"snap_dur",
		"body_dur",
		"tail_decay",
		"base_freq",
		"end_freq",
	]
	for i in range(WeaponScript.WEAPONS.size()):
		var w: Dictionary = WeaponScript.WEAPONS[i]
		for key in required:
			assert_true(
				w.has(key),
				"Weapon %d (%s) missing key: %s" % [i, w.get("name", "?"), key],
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
	assert_eq(w["range"], max_range, "Rifle should have longest range")


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
			per_pellet,
			0.0,
			"%s per-pellet damage should be > 0" % w["name"],
		)
