extends GutTest
## Tests for src/state_machine/player_state.gd, scenes/player/player_model.gd,
## and scenes/player/player_weapon.gd — L1, L5, L6 low-severity fixes.

const PlayerStateScript = preload("res://src/state_machine/player_state.gd")
const PlayerModelScript = preload("res://scenes/player/player_model.gd")
const PlayerWeaponScript = preload("res://scenes/player/player_weapon.gd")


# ==========================================================================
# L1 — nearest_vehicle guarded with is_instance_valid (player_state.gd)
# ==========================================================================


func test_update_prompt_uses_is_instance_valid() -> void:
	var src: String = (PlayerStateScript as GDScript).source_code
	assert_true(
		src.contains("is_instance_valid(owner.nearest_vehicle)"),
		"_update_prompt must guard nearest_vehicle with is_instance_valid",
	)


# ==========================================================================
# L5 — get_current_weapon() exposes current weapon without accessing private _current_idx
# ==========================================================================


func test_get_current_weapon_method_in_source() -> void:
	var src: String = (PlayerWeaponScript as GDScript).source_code
	assert_true(
		src.contains("func get_current_weapon()"),
		"PlayerWeapon must declare public get_current_weapon() method",
	)


func test_get_current_weapon_returns_weapons_at_current_idx() -> void:
	var src: String = (PlayerWeaponScript as GDScript).source_code
	var idx: int = src.find("func get_current_weapon()")
	var body: String = src.substr(idx, 80)
	assert_true(
		body.contains("WEAPONS[_current_idx]"),
		"get_current_weapon() must return WEAPONS[_current_idx]",
	)


func test_player_model_uses_get_current_weapon() -> void:
	var src: String = (PlayerModelScript as GDScript).source_code
	assert_true(
		src.contains(".get_current_weapon()"),
		"player_model must call get_current_weapon() instead of accessing _current_idx directly",
	)
	assert_false(
		src.contains("_player_weapon._current_idx"),
		"player_model must not access private _current_idx directly",
	)


# ==========================================================================
# L6 — arm-aim guard uses InputManager.is_foot() not parent.visible
# ==========================================================================


func test_arm_aim_uses_inputmanager_not_visible() -> void:
	var src: String = (PlayerModelScript as GDScript).source_code
	assert_true(
		src.contains("InputManager.is_foot()"),
		"Arm aim guard must use InputManager.is_foot()",
	)
	assert_false(
		src.contains("parent as Node3D).visible"),
		"Arm aim guard must not use parent.visible",
	)
