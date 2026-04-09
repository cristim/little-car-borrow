extends GutTest
## gdlint:ignore = max-public-methods
## Unit tests for NPC vehicle controller spawn grace, airborne guard,
## reduced escape force, and behavioral tests for pure functions.

const _BASE_PATH := "res://src/vehicle_ai_base.gd"
var _npc_script: GDScript


# ---------------------------------------------------------------------------
# Mock helpers used by behavioral tests
# ---------------------------------------------------------------------------

class MockVehicleSimple:
	extends RigidBody3D
	# Inherits global_position from Node3D; no extra code needed


class MockGrid:
	extends RefCounted

	func get_nearest_road_index(_coord: float) -> int:
		return 0

	func get_road_center_near(_road_idx: int, _coord: float) -> float:
		return 0.0

	func get_road_width(_road_idx: int) -> float:
		return 8.0

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


# ==========================================================================
# Const value tests
# ==========================================================================


func test_cruise_speed() -> void:
	assert_eq(_npc_script.CRUISE_SPEED, 40.0)


func test_max_yield_time() -> void:
	assert_eq(_npc_script.MAX_YIELD_TIME, 2.0)


func test_reverse_timeout() -> void:
	assert_eq(_npc_script.REVERSE_TIMEOUT, 1.5)


func test_escape_reverse_duration() -> void:
	assert_eq(_npc_script.ESCAPE_REVERSE_DURATION, 1.5)


func test_on_lane_threshold() -> void:
	assert_eq(_npc_script.ON_LANE_THRESHOLD, 3.0)


func test_heading_align_dot() -> void:
	assert_eq(_npc_script.HEADING_ALIGN_DOT, 0.85)


func test_recovery_arrival_dist() -> void:
	assert_eq(_npc_script.RECOVERY_ARRIVAL_DIST, 4.0)


func test_recovery_min_speed() -> void:
	assert_eq(_npc_script.RECOVERY_MIN_SPEED, 5.0)


# ==========================================================================
# _get_desired_heading() — behavioral
# ==========================================================================


func test_get_desired_heading_north() -> void:
	var ai: Node = _npc_script.new()
	add_child_autofree(ai)
	ai._direction = 0  # Direction.NORTH
	assert_eq(ai._get_desired_heading(), Vector3(0, 0, -1))


func test_get_desired_heading_south() -> void:
	var ai: Node = _npc_script.new()
	add_child_autofree(ai)
	ai._direction = 1  # Direction.SOUTH
	assert_eq(ai._get_desired_heading(), Vector3(0, 0, 1))


func test_get_desired_heading_east() -> void:
	var ai: Node = _npc_script.new()
	add_child_autofree(ai)
	ai._direction = 2  # Direction.EAST
	assert_eq(ai._get_desired_heading(), Vector3(1, 0, 0))


func test_get_desired_heading_west() -> void:
	var ai: Node = _npc_script.new()
	add_child_autofree(ai)
	ai._direction = 3  # Direction.WEST
	assert_eq(ai._get_desired_heading(), Vector3(-1, 0, 0))


# ==========================================================================
# _pick_next_direction() — never reverses
# ==========================================================================


func _make_ai_with_mock_vehicle() -> Node:
	var ai: Node = _npc_script.new()
	add_child_autofree(ai)
	ai._grid = MockGrid.new()
	var vehicle: RigidBody3D = MockVehicleSimple.new()
	add_child_autofree(vehicle)
	ai._vehicle = vehicle
	# Null city_manager forces _is_in_city() to return true (city branch)
	ai._city_manager = null
	return ai


func test_pick_direction_never_reverses_from_north() -> void:
	var ai: Node = _make_ai_with_mock_vehicle()
	for _i in range(20):
		ai._direction = 0  # NORTH
		ai._pick_next_direction()
		assert_ne(ai._direction, 1, "Should never pick SOUTH when travelling NORTH")


func test_pick_direction_never_reverses_from_south() -> void:
	var ai: Node = _make_ai_with_mock_vehicle()
	for _i in range(20):
		ai._direction = 1  # SOUTH
		ai._pick_next_direction()
		assert_ne(ai._direction, 0, "Should never pick NORTH when travelling SOUTH")


func test_pick_direction_never_reverses_from_east() -> void:
	var ai: Node = _make_ai_with_mock_vehicle()
	for _i in range(20):
		ai._direction = 2  # EAST
		ai._pick_next_direction()
		assert_ne(ai._direction, 3, "Should never pick WEST when travelling EAST")


func test_pick_direction_never_reverses_from_west() -> void:
	var ai: Node = _make_ai_with_mock_vehicle()
	for _i in range(20):
		ai._direction = 3  # WEST
		ai._pick_next_direction()
		assert_ne(ai._direction, 2, "Should never pick EAST when travelling WEST")


func test_pick_direction_result_is_valid_direction() -> void:
	var ai: Node = _make_ai_with_mock_vehicle()
	ai._direction = 0  # NORTH
	for _i in range(10):
		ai._direction = 0
		ai._pick_next_direction()
		assert_true(
			ai._direction >= 0 and ai._direction <= 3,
			"Resulting direction must be a valid Direction enum value",
		)


# ==========================================================================
# _check_recovery_complete() — behavioral
# ==========================================================================


func test_recovery_not_complete_when_slow() -> void:
	var ai: Node = _npc_script.new()
	add_child_autofree(ai)
	ai._grid = MockGrid.new()
	var vehicle: RigidBody3D = MockVehicleSimple.new()
	add_child_autofree(vehicle)
	ai._vehicle = vehicle
	ai._recovery_active = true
	ai._recovery_direction = 0  # NORTH
	ai._recovery_road_index = 0
	# Vehicle is stationary — speed 0.0 < RECOVERY_MIN_SPEED (5.0)
	assert_false(
		ai._check_recovery_complete(),
		"Recovery should not complete when vehicle speed is zero",
	)


func test_recovery_not_complete_when_perpendicular_error_large() -> void:
	# Place vehicle far from the road center so lane error > RECOVERY_ARRIVAL_DIST (4.0)
	var ai: Node = _npc_script.new()
	add_child_autofree(ai)
	ai._grid = MockGrid.new()
	var vehicle: RigidBody3D = MockVehicleSimple.new()
	add_child_autofree(vehicle)
	# Road center = 0 (MockGrid), lane_offset = road_width/4 = 2.0
	# NORTH lane target = road_center + lane_offset = 0 + 2 = 2
	# Place vehicle at x=20 so |20 - 2| = 18 > RECOVERY_ARRIVAL_DIST
	vehicle.global_position = Vector3(20.0, 0.0, 0.0)
	ai._vehicle = vehicle
	ai._recovery_active = true
	ai._recovery_direction = 0  # NORTH
	ai._recovery_road_index = 0
	assert_false(
		ai._check_recovery_complete(),
		"Recovery should not complete when perpendicular distance exceeds threshold",
	)
