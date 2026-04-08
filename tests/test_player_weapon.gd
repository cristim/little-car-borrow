extends GutTest
## Tests for player_weapon.gd — draw/holster, cooldown, decal management,
## and weapon state. Extends the switching/spread tests in test_weapon_switching.gd.

const WeaponScript = preload("res://scenes/player/player_weapon.gd")

var _pw: Node
var _owner: CharacterBody3D
var _weapon_signals: Array[int]
var _saved_is_dead: bool


func before_each() -> void:
	_saved_is_dead = GameManager.is_dead
	GameManager.is_dead = false
	_weapon_signals = []

	_owner = CharacterBody3D.new()
	_owner.name = "Player"

	# PlayerModel stub with RightShoulderPivot/RightElbowPivot
	var model := Node3D.new()
	model.name = "PlayerModel"
	var rs := Node3D.new()
	rs.name = "RightShoulderPivot"
	var re := Node3D.new()
	re.name = "RightElbowPivot"
	rs.add_child(re)
	model.add_child(rs)
	_owner.add_child(model)

	_pw = Node.new()
	_pw.set_script(WeaponScript)
	_pw.name = "PlayerWeapon"
	_owner.add_child(_pw)
	# Set owner so _ready can find PlayerModel
	_pw.owner = _owner

	add_child_autofree(_owner)
	await get_tree().process_frame

	# Track weapon_switched signals
	EventBus.weapon_switched.connect(_on_weapon_switched)


func after_each() -> void:
	GameManager.is_dead = _saved_is_dead
	if EventBus.weapon_switched.is_connected(_on_weapon_switched):
		EventBus.weapon_switched.disconnect(_on_weapon_switched)


func _on_weapon_switched(idx: int) -> void:
	_weapon_signals.append(idx)


# ==========================================================================
# Initial state
# ==========================================================================


func test_initial_not_armed() -> void:
	assert_false(_pw._armed, "Should start unarmed")


func test_initial_weapon_index_zero() -> void:
	assert_eq(_pw._current_idx, 0, "Should start on weapon 0")


func test_initial_all_unlocked() -> void:
	for i in range(_pw._unlocked.size()):
		assert_true(_pw._unlocked[i], "Weapon %d should be unlocked" % i)


func test_initial_cooldown_zero() -> void:
	assert_almost_eq(_pw._cooldown, 0.0, 0.001, "Cooldown starts at 0")


func test_ready_finds_elbow() -> void:
	assert_not_null(_pw._elbow, "Should find RightElbowPivot in _ready")


func test_ready_finds_player_model() -> void:
	assert_not_null(_pw._player_model, "Should find PlayerModel in _ready")


# ==========================================================================
# Draw weapon
# ==========================================================================


func test_draw_weapon_sets_armed() -> void:
	_pw._draw_weapon(0)
	assert_true(_pw._armed, "Should be armed after draw")


func test_draw_weapon_sets_index() -> void:
	_pw._draw_weapon(2)
	assert_eq(_pw._current_idx, 2, "Should switch to weapon 2")


func test_draw_weapon_emits_signal() -> void:
	_pw._draw_weapon(1)
	assert_has(_weapon_signals, 1, "Should emit weapon_switched(1)")


func test_draw_weapon_rejects_negative_index() -> void:
	_pw._draw_weapon(-1)
	assert_false(_pw._armed, "Should not arm with negative index")


func test_draw_weapon_rejects_out_of_bounds() -> void:
	_pw._draw_weapon(99)
	assert_false(_pw._armed, "Should not arm with OOB index")


func test_draw_weapon_rejects_locked() -> void:
	_pw._unlocked[2] = false
	_pw._draw_weapon(2)
	assert_false(_pw._armed, "Should not arm locked weapon")
	assert_eq(_pw._current_idx, 0, "Index should not change")


func test_draw_weapon_creates_gun_mesh() -> void:
	_pw._draw_weapon(0)
	assert_not_null(_pw._gun_mesh, "Gun mesh should be created")


func test_draw_weapon_creates_muzzle_flash() -> void:
	_pw._draw_weapon(0)
	assert_not_null(_pw._muzzle_flash, "Muzzle flash should be created")


func test_draw_weapon_muzzle_flash_hidden() -> void:
	_pw._draw_weapon(0)
	assert_false(
		_pw._muzzle_flash.visible,
		"Muzzle flash should start hidden",
	)


# ==========================================================================
# Holster
# ==========================================================================


func test_holster_clears_armed() -> void:
	_pw._draw_weapon(0)
	_pw._holster()
	assert_false(_pw._armed, "Should not be armed after holster")


func test_holster_emits_negative_one() -> void:
	_pw._draw_weapon(0)
	_weapon_signals.clear()
	_pw._holster()
	assert_has(
		_weapon_signals,
		-1,
		"Should emit weapon_switched(-1) on holster",
	)


func test_holster_clears_gun_mesh() -> void:
	_pw._draw_weapon(0)
	_pw._holster()
	# gun_mesh is queue_freed, so it becomes null reference
	assert_null(_pw._gun_mesh, "Gun mesh ref should be null after holster")


func test_holster_clears_muzzle_flash() -> void:
	_pw._draw_weapon(0)
	_pw._holster()
	assert_null(
		_pw._muzzle_flash,
		"Muzzle flash ref should be null after holster",
	)


func test_holster_when_already_holstered() -> void:
	_pw._holster()
	assert_false(_pw._armed, "Double holster should not crash")


# ==========================================================================
# Switch weapon (no-op if same + armed)
# ==========================================================================


func test_switch_weapon_noop_when_same_and_armed() -> void:
	_pw._draw_weapon(1)
	_weapon_signals.clear()
	_pw._switch_weapon(1)
	assert_eq(
		_weapon_signals.size(),
		0,
		"Switching to same armed weapon should be a no-op",
	)


func test_switch_weapon_draws_if_different() -> void:
	_pw._draw_weapon(0)
	_weapon_signals.clear()
	_pw._switch_weapon(2)
	assert_eq(_pw._current_idx, 2, "Should switch to weapon 2")
	assert_true(_pw._armed, "Should still be armed")


# ==========================================================================
# Cycle weapon
# ==========================================================================


func test_cycle_forward_from_zero() -> void:
	_pw._cycle_weapon(1)
	assert_eq(_pw._current_idx, 1, "Should advance to 1")


func test_cycle_backward_wraps_to_last() -> void:
	_pw._cycle_weapon(-1)
	assert_eq(_pw._current_idx, 3, "Should wrap to last weapon")


func test_cycle_skips_locked_weapons() -> void:
	_pw._unlocked[1] = false
	_pw._unlocked[2] = false
	_pw._cycle_weapon(1)
	assert_eq(_pw._current_idx, 3, "Should skip to first unlocked")


func test_cycle_stays_if_all_others_locked() -> void:
	_pw._unlocked[1] = false
	_pw._unlocked[2] = false
	_pw._unlocked[3] = false
	_pw._cycle_weapon(1)
	assert_eq(_pw._current_idx, 0, "Should stay on 0 if others locked")


# ==========================================================================
# Unlock weapon
# ==========================================================================


func test_unlock_weapon_sets_flag() -> void:
	_pw._unlocked[2] = false
	_pw.unlock_weapon(2)
	assert_true(_pw._unlocked[2], "Weapon 2 should be unlocked")


func test_unlock_weapon_emits_signal() -> void:
	_pw._unlocked[3] = false
	var captured := []
	var on_unlock := func(idx: int) -> void: captured.append(idx)
	EventBus.weapon_unlocked.connect(on_unlock)
	_pw.unlock_weapon(3)
	EventBus.weapon_unlocked.disconnect(on_unlock)
	assert_eq(captured.size(), 1, "Should emit once")
	if captured.size() > 0:
		assert_eq(captured[0], 3, "Should emit weapon_unlocked(3)")


func test_unlock_weapon_shows_notification() -> void:
	_pw._unlocked[1] = false
	var captured := []
	var on_notif := func(text: String, _dur: float) -> void: captured.append(text)
	EventBus.show_notification.connect(on_notif)
	_pw.unlock_weapon(1)
	EventBus.show_notification.disconnect(on_notif)
	assert_eq(captured.size(), 1, "Should emit notification")
	if captured.size() > 0:
		assert_true(
			captured[0].contains("SMG"),
			"Notification should mention weapon name",
		)


func test_unlock_already_unlocked_is_noop() -> void:
	var signal_count := 0
	var on_unlock := func(_idx: int) -> void: signal_count += 1
	EventBus.weapon_unlocked.connect(on_unlock)
	_pw.unlock_weapon(0)  # Already unlocked
	EventBus.weapon_unlocked.disconnect(on_unlock)
	assert_eq(signal_count, 0, "Should not emit for already unlocked weapon")


func test_unlock_rejects_negative() -> void:
	_pw.unlock_weapon(-1)
	assert_true(true, "Should not crash on negative index")


func test_unlock_rejects_out_of_bounds() -> void:
	_pw.unlock_weapon(99)
	assert_true(true, "Should not crash on OOB index")


# ==========================================================================
# Cooldown
# ==========================================================================


func test_cooldown_decreases_over_time() -> void:
	_pw._cooldown = 1.0
	_pw._process(0.1)
	assert_almost_eq(
		_pw._cooldown,
		0.9,
		0.01,
		"Cooldown should decrease by delta",
	)


func test_cooldown_can_go_negative() -> void:
	_pw._cooldown = 0.05
	_pw._process(0.1)
	assert_lt(_pw._cooldown, 0.0, "Cooldown can go below 0")


# ==========================================================================
# Muzzle flash timer
# ==========================================================================


func test_flash_timer_decreases() -> void:
	_pw._draw_weapon(0)
	_pw._muzzle_flash.visible = true
	_pw._flash_timer = 0.06
	_pw._process(0.03)
	assert_almost_eq(
		_pw._flash_timer,
		0.03,
		0.01,
		"Flash timer should decrease",
	)
	assert_true(
		_pw._muzzle_flash.visible,
		"Flash should still be visible mid-timer",
	)


func test_flash_timer_hides_muzzle_flash() -> void:
	_pw._draw_weapon(0)
	_pw._muzzle_flash.visible = true
	_pw._flash_timer = 0.02
	_pw._process(0.05)
	assert_false(
		_pw._muzzle_flash.visible,
		"Flash should be hidden when timer expires",
	)


# ==========================================================================
# Weapon constants
# ==========================================================================


func test_weapons_array_size() -> void:
	assert_eq(WeaponScript.WEAPONS.size(), 4, "Should have 4 weapons")


func test_weapon_ranges() -> void:
	assert_almost_eq(
		float(WeaponScript.WEAPONS[0]["range"]),
		80.0,
		0.01,
		"Pistol range 80 m",
	)
	assert_almost_eq(
		float(WeaponScript.WEAPONS[1]["range"]),
		70.0,
		0.01,
		"SMG range 70 m",
	)
	assert_almost_eq(
		float(WeaponScript.WEAPONS[2]["range"]),
		40.0,
		0.01,
		"Shotgun range 40 m",
	)
	assert_almost_eq(
		float(WeaponScript.WEAPONS[3]["range"]),
		200.0,
		0.01,
		"Rifle range 200 m",
	)


func test_vehicle_impulse_positive() -> void:
	assert_gt(
		WeaponScript.VEHICLE_IMPULSE,
		0.0,
		"VEHICLE_IMPULSE should be positive",
	)


func test_max_world_decals_positive() -> void:
	assert_gt(
		WeaponScript.MAX_WORLD_DECALS,
		0,
		"MAX_WORLD_DECALS should be positive",
	)


func test_max_blood_decals_positive() -> void:
	assert_gt(
		WeaponScript.MAX_BLOOD_DECALS,
		0,
		"MAX_BLOOD_DECALS should be positive",
	)


func test_muzzle_flash_time_positive() -> void:
	assert_gt(
		WeaponScript.MUZZLE_FLASH_TIME,
		0.0,
		"MUZZLE_FLASH_TIME should be positive",
	)


# ==========================================================================
# Apply spread
# ==========================================================================


func test_apply_spread_zero_returns_same_direction() -> void:
	var dir := Vector3(0.0, 0.0, -1.0)
	var result: Vector3 = _pw._apply_spread(dir, 0.0)
	assert_almost_eq(result.x, dir.x, 0.001)
	assert_almost_eq(result.y, dir.y, 0.001)
	assert_almost_eq(result.z, dir.z, 0.001)


func test_apply_spread_result_is_normalized() -> void:
	var dir := Vector3(0.0, 0.0, -1.0)
	for _i in range(20):
		var result: Vector3 = _pw._apply_spread(dir, 0.1)
		assert_almost_eq(result.length(), 1.0, 0.001)


func test_apply_spread_nonzero_changes_direction() -> void:
	var dir := Vector3(0.0, 0.0, -1.0)
	var different := false
	for _i in range(20):
		var result: Vector3 = _pw._apply_spread(dir, 0.1)
		if result.distance_to(dir) > 0.001:
			different = true
	assert_true(different, "Spread should deviate from original direction")


# ==========================================================================
# Decal pool management
# ==========================================================================


func test_world_decals_start_empty() -> void:
	assert_eq(
		_pw._world_decals.size(),
		0,
		"World decals should start empty",
	)


func test_blood_decals_start_empty() -> void:
	assert_eq(
		_pw._blood_decals.size(),
		0,
		"Blood decals should start empty",
	)


# ==========================================================================
# Dead state blocks weapon logic
# ==========================================================================


func test_process_returns_early_when_dead() -> void:
	GameManager.is_dead = true
	_pw._armed = true
	_pw._current_idx = 0
	_pw._cooldown = 0.0
	# Process should return early after cooldown/flash update, before input
	# This tests that no crash occurs and cooldown still ticks
	_pw._cooldown = 1.0
	_pw._process(0.1)
	assert_almost_eq(
		_pw._cooldown,
		0.9,
		0.01,
		"Cooldown should still tick when dead",
	)


# ==========================================================================
# Draw then switch replaces mesh
# ==========================================================================


func test_draw_then_switch_replaces_gun_mesh() -> void:
	_pw._draw_weapon(0)
	var first_mesh: Node3D = _pw._gun_mesh
	assert_not_null(first_mesh, "First mesh should exist")
	_pw._draw_weapon(2)
	# Old mesh is queue_freed, new mesh is different
	assert_not_null(_pw._gun_mesh, "New mesh should exist")


# ==========================================================================
# Setup gun mesh without elbow (edge case)
# ==========================================================================


func test_setup_gun_mesh_noop_without_elbow() -> void:
	_pw._elbow = null
	_pw._draw_weapon(0)
	# _setup_gun_mesh should return early
	assert_null(
		_pw._gun_mesh,
		"Gun mesh should be null when _elbow is null",
	)


# ==========================================================================
# Ray origin and blood position (source-level verification)
# ==========================================================================


func test_shoot_uses_player_camera_pivot_as_ray_origin() -> void:
	var script: GDScript = WeaponScript as GDScript
	var src: String = script.source_code
	assert_true(
		src.contains("pcam is Node3D") and src.contains("(pcam as Node3D).global_position"),
		"_shoot() must use PlayerCamera pivot global_position as ray origin",
	)


func test_shoot_direction_uses_project_ray_normal_at_crosshair() -> void:
	var script: GDScript = WeaponScript as GDScript
	var src: String = script.source_code
	assert_true(
		src.contains("project_ray_normal(crosshair_screen)"),
		"_shoot() must use project_ray_normal(crosshair_screen) for aim direction",
	)


func test_spawn_blood_uses_target_floor_y() -> void:
	var script: GDScript = WeaponScript as GDScript
	var src: String = script.source_code
	assert_true(
		src.contains("target.global_position.y"),
		"_spawn_blood() must use target.global_position.y for floor level",
	)


# ==========================================================================
# Holster on death (H4 fix)
# ==========================================================================


func test_holster_called_on_death_when_armed() -> void:
	_pw._draw_weapon(0)
	assert_true(_pw._armed, "Precondition: weapon should be drawn")
	GameManager.is_dead = true
	_pw._process(0.016)
	assert_false(
		_pw._armed,
		"Weapon should be holstered when GameManager.is_dead is true",
	)


func test_no_error_on_death_when_unarmed() -> void:
	assert_false(_pw._armed, "Precondition: weapon should be holstered")
	GameManager.is_dead = true
	_pw._process(0.016)  # must not crash
	assert_false(_pw._armed, "Weapon remains holstered after dead-check while unarmed")


# ==========================================================================
# Ragdoll lifetime timer (M7 fix)
# ==========================================================================


func test_ragdoll_lifetime_constant_defined() -> void:
	assert_true(
		WeaponScript.get_script_constant_map().has("RAGDOLL_LIFETIME"),
		"RAGDOLL_LIFETIME const should be defined",
	)


func test_ragdoll_lifetime_at_least_5_seconds() -> void:
	assert_gte(
		WeaponScript.RAGDOLL_LIFETIME,
		5.0,
		"RAGDOLL_LIFETIME should be at least 5 seconds",
	)


func test_ragdoll_source_has_lifetime_timer() -> void:
	var src: String = (WeaponScript as GDScript).source_code
	assert_true(
		src.contains("RAGDOLL_LIFETIME"),
		"_spawn_ragdoll should reference RAGDOLL_LIFETIME for cleanup timer",
	)
	assert_true(
		src.contains("is_instance_valid(ragdoll)"),
		"Ragdoll timer lambda should guard with is_instance_valid",
	)
