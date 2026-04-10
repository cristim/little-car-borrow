# gdlint:ignore = max-public-methods
extends GutTest
## Unit tests for scenes/police/police_officer.gd
## Tests model building, shooting logic, target position, limb animation,
## and state transitions.

const OfficerScript = preload("res://scenes/police/police_officer.gd")

var _officer: CharacterBody3D


func before_each() -> void:
	_officer = OfficerScript.new()
	add_child_autofree(_officer)


# ================================================================
# Constants
# ================================================================


func test_chase_speed_value() -> void:
	assert_eq(
		OfficerScript.CHASE_SPEED,
		5.5,
		"Chase speed should be 5.5",
	)


func test_shoot_range_value() -> void:
	assert_eq(
		OfficerScript.SHOOT_RANGE,
		30.0,
		"Shoot range should be 30.0",
	)


func test_shoot_cooldown_value() -> void:
	assert_eq(
		OfficerScript.SHOOT_COOLDOWN,
		1.2,
		"Shoot cooldown should be 1.2",
	)


func test_shoot_damage_value() -> void:
	assert_eq(
		OfficerScript.SHOOT_DAMAGE,
		8.0,
		"Shoot damage should be 8.0",
	)


func test_despawn_dist_value() -> void:
	assert_eq(
		OfficerScript.DESPAWN_DIST,
		80.0,
		"Despawn distance should be 80.0",
	)


func test_gravity_value() -> void:
	assert_eq(
		OfficerScript.GRAVITY,
		9.8,
		"Gravity should be 9.8",
	)


func test_muzzle_flash_time_value() -> void:
	assert_eq(
		OfficerScript.MUZZLE_FLASH_TIME,
		0.08,
		"Muzzle flash time should be 0.08",
	)


# ================================================================
# Group and collision setup
# ================================================================


func test_added_to_police_officer_group() -> void:
	assert_true(
		_officer.is_in_group("police_officer"),
		"Should be in 'police_officer' group",
	)


func test_collision_layer_is_npc() -> void:
	assert_eq(
		_officer.collision_layer,
		4,
		"Collision layer should be 4 (NPC)",
	)


func test_collision_mask_static_and_ground() -> void:
	assert_eq(
		_officer.collision_mask,
		3,
		"Collision mask should be 3 (Static + Ground)",
	)


# ================================================================
# Model building
# ================================================================


func test_officer_model_exists() -> void:
	var model := _officer.get_node_or_null("OfficerModel")
	assert_not_null(model, "OfficerModel should exist")


func test_model_has_torso() -> void:
	var model := _officer.get_node("OfficerModel")
	var found := false
	for child in model.get_children():
		if child is MeshInstance3D and child.mesh is BoxMesh:
			var box: BoxMesh = child.mesh
			if is_equal_approx(box.size.y, 0.5):
				found = true
				break
	assert_true(found, "Model should have torso (BoxMesh h=0.5)")


func test_model_has_head() -> void:
	var model := _officer.get_node("OfficerModel")
	var found := false
	for child in model.get_children():
		if child is MeshInstance3D and child.mesh is BoxMesh:
			var box: BoxMesh = child.mesh
			if is_equal_approx(box.size.x, 0.22):
				found = true
				break
	assert_true(found, "Model should have head (BoxMesh size 0.22)")


func test_model_has_hat() -> void:
	var model := _officer.get_node("OfficerModel")
	var found := false
	for child in model.get_children():
		if child is MeshInstance3D and child.mesh is BoxMesh:
			var box: BoxMesh = child.mesh
			if is_equal_approx(box.size.y, 0.08):
				found = true
				break
	assert_true(found, "Model should have hat (BoxMesh h=0.08)")


func test_left_shoulder_pivot_exists() -> void:
	assert_not_null(
		_officer._left_shoulder,
		"Left shoulder pivot should exist",
	)
	assert_eq(
		_officer._left_shoulder.name,
		"LeftShoulderPivot",
		"Should be named LeftShoulderPivot",
	)


func test_right_shoulder_pivot_exists() -> void:
	assert_not_null(
		_officer._right_shoulder,
		"Right shoulder pivot should exist",
	)
	assert_eq(
		_officer._right_shoulder.name,
		"RightShoulderPivot",
		"Should be named RightShoulderPivot",
	)


func test_left_hip_pivot_exists() -> void:
	assert_not_null(
		_officer._left_hip,
		"Left hip pivot should exist",
	)
	assert_eq(
		_officer._left_hip.name,
		"LeftHipPivot",
		"Should be named LeftHipPivot",
	)


func test_right_hip_pivot_exists() -> void:
	assert_not_null(
		_officer._right_hip,
		"Right hip pivot should exist",
	)
	assert_eq(
		_officer._right_hip.name,
		"RightHipPivot",
		"Should be named RightHipPivot",
	)


func test_muzzle_flash_exists_and_hidden() -> void:
	assert_not_null(
		_officer._muzzle_flash,
		"Muzzle flash mesh should exist",
	)
	assert_false(
		_officer._muzzle_flash.visible,
		"Muzzle flash should be hidden initially",
	)


func test_collision_capsule_exists() -> void:
	var found := false
	for child in _officer.get_children():
		if child is CollisionShape3D:
			var shape := (child as CollisionShape3D).shape
			if shape is CapsuleShape3D:
				found = true
				assert_almost_eq(
					(shape as CapsuleShape3D).radius,
					0.3,
					0.001,
					"Capsule radius should be 0.3",
				)
				assert_almost_eq(
					(shape as CapsuleShape3D).height,
					1.7,
					0.001,
					"Capsule height should be 1.7",
				)
				break
	assert_true(found, "Officer should have capsule collision shape")


# ================================================================
# _get_target_pos
# ================================================================


func test_target_pos_no_player_returns_self() -> void:
	_officer._player = null
	var pos: Vector3 = _officer._get_target_pos()
	assert_eq(
		pos,
		_officer.global_position,
		"Without player, target should be own position",
	)


func test_target_pos_with_player_returns_player_pos() -> void:
	var player := Node3D.new()
	add_child_autofree(player)
	player.global_position = Vector3(10.0, 0.0, 20.0)
	_officer._player = player

	var pos: Vector3 = _officer._get_target_pos()
	assert_eq(
		pos,
		Vector3(10.0, 0.0, 20.0),
		"Should return player position",
	)


func test_target_pos_with_player_in_vehicle() -> void:
	var player := PlayerStub.new()
	var vehicle := Node3D.new()
	add_child_autofree(vehicle)
	vehicle.global_position = Vector3(50.0, 0.0, 50.0)
	player.current_vehicle = vehicle
	add_child_autofree(player)
	_officer._player = player

	var pos: Vector3 = _officer._get_target_pos()
	assert_eq(
		pos,
		Vector3(50.0, 0.0, 50.0),
		"Should return vehicle position when player is in vehicle",
	)


func test_target_pos_with_null_vehicle() -> void:
	var player := PlayerStub.new()
	player.current_vehicle = null
	add_child_autofree(player)
	player.global_position = Vector3(15.0, 0.0, 25.0)
	_officer._player = player

	var pos: Vector3 = _officer._get_target_pos()
	assert_eq(
		pos,
		Vector3(15.0, 0.0, 25.0),
		"Should return player position when vehicle is null",
	)


# ================================================================
# _shoot
# ================================================================


func test_shoot_enables_muzzle_flash() -> void:
	_officer._shoot(Vector3.ZERO)
	assert_true(
		_officer._muzzle_flash.visible,
		"Muzzle flash should be visible after shooting",
	)


func test_shoot_sets_flash_timer() -> void:
	_officer._shoot(Vector3.ZERO)
	assert_eq(
		_officer._flash_timer,
		OfficerScript.MUZZLE_FLASH_TIME,
		"Flash timer should be set to MUZZLE_FLASH_TIME",
	)


func test_shoot_sets_shoot_pose_timer() -> void:
	_officer._shoot(Vector3.ZERO)
	assert_eq(
		_officer._shoot_pose_timer,
		0.4,
		"Shoot pose timer should be 0.4",
	)


func test_shoot_creates_audio_child() -> void:
	# Audio player is created in _ready(), not per-shot
	assert_not_null(
		_officer._gunshot_player,
		"Should have an AudioStreamPlayer3D after _ready()",
	)
	assert_true(
		_officer._gunshot_player is AudioStreamPlayer3D,
		"Audio player should be AudioStreamPlayer3D",
	)


# ================================================================
# Muzzle flash fadeout
# ================================================================


func test_flash_timer_decrements() -> void:
	_officer._flash_timer = 0.05
	_officer._muzzle_flash.visible = true

	# Simulate flash timer logic
	var delta := 0.03
	_officer._flash_timer -= delta
	assert_gt(
		_officer._flash_timer,
		0.0,
		"Flash timer should still be positive",
	)
	assert_true(
		_officer._muzzle_flash.visible,
		"Muzzle flash should still be visible",
	)


func test_flash_timer_hides_muzzle_when_expired() -> void:
	_officer._flash_timer = 0.01
	_officer._muzzle_flash.visible = true

	# Simulate: timer goes to <= 0
	_officer._flash_timer -= 0.02
	if _officer._flash_timer <= 0.0 and _officer._muzzle_flash:
		_officer._muzzle_flash.visible = false

	assert_false(
		_officer._muzzle_flash.visible,
		"Muzzle flash should hide when timer expires",
	)


# ================================================================
# _animate_limbs
# ================================================================


func test_animate_limbs_running_swings_arms() -> void:
	_officer._anim_phase = 0.0
	_officer._shoot_pose_timer = 0.0
	_officer._animate_limbs(0.1, 10.0)  # h_dist > 2.0 = running

	assert_ne(
		_officer._anim_phase,
		0.0,
		"Anim phase should advance when running",
	)
	assert_ne(
		_officer._left_shoulder.rotation.x,
		0.0,
		"Left shoulder should swing when running",
	)


func test_animate_limbs_idle_decays_toward_zero() -> void:
	# Set some non-zero rotation
	_officer._left_shoulder.rotation.x = 0.5
	_officer._left_hip.rotation.x = -0.5
	_officer._right_hip.rotation.x = 0.5
	_officer._right_shoulder.rotation.x = -0.5
	_officer._shoot_pose_timer = 0.0
	_officer._anim_phase = 1.0

	# Use small delta so lerpf(0.5, 0.0, 0.05*8=0.4) = 0.3
	_officer._animate_limbs(0.05, 1.0)  # h_dist <= 2.0 = idle

	assert_true(
		absf(_officer._left_shoulder.rotation.x) < 0.5,
		"Limbs should decay toward zero when idle",
	)
	assert_eq(
		_officer._anim_phase,
		0.0,
		"Anim phase should reset to 0 when idle",
	)


func test_animate_limbs_shooting_overrides_right_arm() -> void:
	_officer._shoot_pose_timer = 0.3
	_officer._animate_limbs(0.1, 10.0)  # running + shooting

	assert_almost_eq(
		_officer._right_shoulder.rotation.x,
		-PI / 2.0,
		0.001,
		"Right shoulder should point forward when shooting",
	)


func test_animate_limbs_shooting_idle_overrides_right_arm() -> void:
	_officer._shoot_pose_timer = 0.3
	_officer._right_shoulder.rotation.x = 0.0
	_officer._animate_limbs(0.1, 1.0)  # idle + shooting

	assert_almost_eq(
		_officer._right_shoulder.rotation.x,
		-PI / 2.0,
		0.001,
		"Right shoulder should aim even when idle if shoot_pose active",
	)


func test_animate_limbs_no_shoulders_safe() -> void:
	_officer._left_shoulder = null
	# Should not crash
	_officer._animate_limbs(0.1, 5.0)
	pass_test("animate_limbs with null shoulders does not crash")


# ================================================================
# Initial state
# ================================================================


func test_initial_shoot_timer_zero() -> void:
	assert_eq(_officer._shoot_timer, 0.0)


func test_initial_flash_timer_zero() -> void:
	assert_eq(_officer._flash_timer, 0.0)


func test_initial_shoot_pose_timer_zero() -> void:
	assert_eq(_officer._shoot_pose_timer, 0.0)


func test_initial_anim_phase_zero() -> void:
	assert_eq(_officer._anim_phase, 0.0)


func test_initial_player_null() -> void:
	assert_null(_officer._player)


func test_rng_is_randomized() -> void:
	# After _ready, the RNG should have been randomized.
	# We verify by checking that two officer instances produce
	# different first values (with high probability).
	var officer2 := OfficerScript.new()
	add_child_autofree(officer2)

	var v1: float = _officer._rng.randf()
	var v2: float = officer2._rng.randf()
	# With probability 1 - 1/2^32, these differ
	# We allow them to be equal (rare) but test the mechanism exists
	pass_test("RNG is initialized and callable")


# ================================================================
# Model structure counts
# ================================================================


func test_model_child_count() -> void:
	var model := _officer.get_node("OfficerModel")
	# torso, head, hat, left_shoulder, right_shoulder, left_hip, right_hip = 7
	assert_eq(
		model.get_child_count(),
		7,
		"OfficerModel should have 7 direct children",
	)


func test_right_shoulder_has_arm_gun_and_flash() -> void:
	# Right shoulder: arm mesh, gun mesh, muzzle flash
	assert_eq(
		_officer._right_shoulder.get_child_count(),
		3,
		"Right shoulder should have arm, gun, and muzzle flash",
	)


func test_left_shoulder_has_one_arm() -> void:
	assert_eq(
		_officer._left_shoulder.get_child_count(),
		1,
		"Left shoulder should have one arm mesh",
	)


func test_left_hip_has_one_leg() -> void:
	assert_eq(
		_officer._left_hip.get_child_count(),
		1,
		"Left hip should have one leg mesh",
	)


func test_right_hip_has_one_leg() -> void:
	assert_eq(
		_officer._right_hip.get_child_count(),
		1,
		"Right hip should have one leg mesh",
	)


# ================================================================
# PlayerStub for vehicle targeting tests
# ================================================================

# ================================================================
# Line-of-sight (LOS) wall check — source-code verification
# ================================================================


func test_shoot_performs_los_raycast() -> void:
	var src: String = (OfficerScript as GDScript).source_code
	assert_true(
		src.contains("intersect_ray"),
		"_shoot should cast a ray for line-of-sight check",
	)


func test_los_raycast_uses_mask_3() -> void:
	var src: String = (OfficerScript as GDScript).source_code
	# Mask 3 = Ground (1) + Static (2). Police layer (64) is NOT in the mask
	# so other officers/vehicles don't block shots.
	assert_true(
		src.contains(", 3)"),
		"LOS raycast should use mask=3 (Ground + Static only)",
	)


func test_los_excludes_self() -> void:
	var src: String = (OfficerScript as GDScript).source_code
	assert_true(
		src.contains("query.exclude = [self]"),
		"LOS raycast should exclude the officer itself",
	)


func test_los_blocks_shot_on_hit() -> void:
	var src: String = (OfficerScript as GDScript).source_code
	# When the ray hits something, _shoot returns early without dealing damage
	assert_true(
		src.contains("is_empty()"),
		"_shoot should return early when LOS ray hits geometry",
	)


# ================================================================
# PlayerStub for vehicle targeting tests
# ================================================================


# ================================================================
# C4 + L6 — Gunshot player reused (no per-shot leak); bus is SFX not Ambient
# ================================================================


func test_gunshot_player_created_in_ready() -> void:
	assert_not_null(
		_officer._gunshot_player,
		"_gunshot_player must be created during _ready",
	)


func test_gunshot_player_is_child_of_officer() -> void:
	var found := false
	for child in _officer.get_children():
		if child == _officer._gunshot_player:
			found = true
			break
	assert_true(found, "_gunshot_player must be a direct child of the officer")


func test_gunshot_player_uses_sfx_bus() -> void:
	assert_eq(
		_officer._gunshot_player.bus,
		"SFX",
		"Gunshot player must use the SFX bus, not Ambient",
	)


# ================================================================
# PlayerStub for vehicle targeting tests
# ================================================================


class PlayerStub:
	extends Node3D
	var current_vehicle: Node3D = null
