extends GutTest
## Unit tests for NPC vehicle controller spawn grace, airborne guard,
## and reduced escape force.

const _BASE_PATH := "res://src/vehicle_ai_base.gd"
var _npc_script: GDScript

# ==========================================================================
# Spawn grace
# ==========================================================================


func before_all() -> void:
	_npc_script = load("res://scenes/vehicles/npc_vehicle_controller.gd")


func test_spawn_grace_default_zero() -> void:
	var ai: Node = _npc_script.new()
	add_child_autofree(ai)
	assert_eq(ai._spawn_grace, 0.0)


func test_spawn_grace_set_in_initialize() -> void:
	var ai: Node = _npc_script.new()
	add_child_autofree(ai)
	var vehicle := RigidBody3D.new()
	add_child_autofree(vehicle)
	ai.initialize(vehicle, 0, 0)
	assert_eq(ai._spawn_grace, 4.0, "initialize() should set _spawn_grace to 4.0")


func test_spawn_grace_source_decremented_in_physics() -> void:
	var src: String = _npc_script.source_code
	assert_true(
		src.contains("_spawn_grace -= delta"),
		"_physics_process should decrement _spawn_grace",
	)


# ==========================================================================
# Escape force magnitude — source code verification
# ==========================================================================


func test_escape_force_is_2000_not_6000() -> void:
	var src: String = _npc_script.source_code
	assert_true(
		src.contains("back_dir * 2000.0"),
		"Escape reverse force should be 2000 N",
	)
	assert_false(
		src.contains("back_dir * 6000.0"),
		"Old 6000 N force should be removed",
	)


# ==========================================================================
# Airborne guard — source code verification
# ==========================================================================


func test_airborne_guard_in_escape_force() -> void:
	var src: String = _npc_script.source_code
	assert_true(
		src.contains("absf(_vehicle.linear_velocity.y) <= 2.0"),
		"Escape force should be guarded by airborne check (y <= 2.0)",
	)


func test_airborne_guard_in_stuck_detection() -> void:
	var src: String = _npc_script.source_code
	assert_true(
		src.contains("absf(_vehicle.linear_velocity.y) > 2.0"),
		"Stuck detection should check airborne state (y > 2.0)",
	)


func test_spawn_grace_guards_stuck_detection() -> void:
	var src: String = _npc_script.source_code
	assert_true(
		src.contains("_spawn_grace <= 0.0"),
		"Stuck detection should check spawn grace",
	)


# ==========================================================================
# Horizontal force flattening — source code verification
# ==========================================================================


func test_escape_force_zeroes_y_component() -> void:
	var src: String = _npc_script.source_code
	assert_true(
		src.contains("back_dir.y = 0.0"),
		"Escape force should zero Y component to prevent vertical launch",
	)


func test_escape_force_has_length_guard() -> void:
	var src: String = _npc_script.source_code
	assert_true(
		src.contains("back_dir.length_squared() > 0.001"),
		"Escape force should guard against near-zero length after flattening",
	)


func test_escape_force_renormalizes_after_flattening() -> void:
	var src: String = _npc_script.source_code
	assert_true(
		src.contains("back_dir = back_dir.normalized()"),
		"Escape force should re-normalize after zeroing Y",
	)


# ==========================================================================
# deactivate() — functional test
# ==========================================================================


func test_deactivate_sets_active_false() -> void:
	var ai: Node = _npc_script.new()
	add_child_autofree(ai)
	ai.active = true
	ai.deactivate()
	assert_false(ai.active, "deactivate should set active to false")


func test_deactivate_without_vehicle_does_not_crash() -> void:
	var ai: Node = _npc_script.new()
	add_child_autofree(ai)
	ai.active = true
	ai._vehicle = null
	ai.deactivate()
	assert_false(ai.active, "Should handle null _vehicle gracefully")


func test_deactivate_source_applies_brakes() -> void:
	var src: String = (load(_BASE_PATH) as GDScript).source_code
	assert_true(
		src.contains("brake_input = 1.0"),
		"deactivate should apply full brakes",
	)
	assert_true(
		src.contains("handbrake_input = 1.0"),
		"deactivate should apply full handbrake",
	)


func test_deactivate_source_zeroes_steering_and_throttle() -> void:
	var src: String = (load(_BASE_PATH) as GDScript).source_code
	assert_true(
		src.contains("steering_input = 0.0"),
		"deactivate should zero steering",
	)
	assert_true(
		src.contains("throttle_input = 0.0"),
		"deactivate should zero throttle",
	)
