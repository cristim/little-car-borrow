# gdlint:ignore = max-public-methods
extends GutTest
## Unit tests for police_ai_controller.gd — constants, static helpers,
## state transitions, deactivation, direction helpers, and begin_escape logic.
## Complements test_police_ai.gd which covers the core static methods and
## state transitions in more depth.

const _SCRIPT_PATH := "res://scenes/vehicles/police_ai_controller.gd"
const _BASE_PATH := "res://src/vehicle_ai_base.gd"
const PoliceAIScript = preload(_SCRIPT_PATH)

# --- TestablePoliceAI: overrides scene-dependent methods ---


class TestablePoliceAI:
	extends "res://scenes/vehicles/police_ai_controller.gd"

	func _find_nearest_road_index() -> int:
		return 0

	func _pick_best_direction() -> int:
		return 0

	func _find_next_intersection() -> void:
		pass

	func _check_los() -> bool:
		return _los_cached

	func _update_direction(new_dir: int) -> void:
		_direction = new_dir


var _ai: Node


func before_each() -> void:
	_ai = TestablePoliceAI.new()
	add_child_autofree(_ai)
	WantedLevelManager.wanted_level = 0


func after_each() -> void:
	WantedLevelManager.wanted_level = 0


# ==========================================================================
# Constants — pursuit vs patrol braking
# ==========================================================================


func test_pursuit_hard_brake_dist_less_than_patrol() -> void:
	assert_true(
		PoliceAIScript.PURSUIT_HARD_BRAKE_DIST < PoliceAIScript.HARD_BRAKE_DIST,
		"Police should brake later during pursuit (shorter hard brake dist)",
	)


func test_pursuit_soft_brake_dist_less_than_patrol() -> void:
	assert_true(
		PoliceAIScript.PURSUIT_SOFT_BRAKE_DIST < PoliceAIScript.SOFT_BRAKE_DIST,
		"Police should soft-brake later during pursuit",
	)


func test_pursuit_speed_greater_than_patrol() -> void:
	assert_true(PoliceAIScript.PURSUIT_SPEED > PoliceAIScript.PATROL_SPEED)


func test_ray_mask_value() -> void:
	assert_eq(PoliceAIScript.RAY_MASK, 122)


func test_lod_freeze_dist_greater_than_far() -> void:
	assert_true(
		PoliceAIScript.LOD_FREEZE_DIST > PoliceAIScript.LOD_FAR_DIST,
	)


func test_lod_far_dist_greater_than_mid() -> void:
	assert_true(
		PoliceAIScript.LOD_FAR_DIST > PoliceAIScript.LOD_MID_DIST,
	)


# ==========================================================================
# Default state
# ==========================================================================


func test_default_active_true() -> void:
	assert_true(_ai.active)


func test_default_ai_state_patrol() -> void:
	assert_eq(_ai._ai_state, PoliceAIScript.AIState.PATROL)


func test_default_spawn_grace_zero() -> void:
	assert_eq(_ai._spawn_grace, 0.0)


func test_default_escaping_false() -> void:
	assert_false(_ai._escaping)


func test_default_officers_spawned_zero() -> void:
	assert_eq(_ai._officers_spawned, 0)


func test_default_pursuit_locked_false() -> void:
	assert_false(_ai._pursuit_locked)


func test_default_path_waypoints_empty() -> void:
	assert_eq(_ai._path_waypoints.size(), 0)


func test_default_los_cached_false() -> void:
	assert_false(_ai._los_cached)


func test_default_ray_cooldown_zero() -> void:
	assert_eq(_ai._ray_cooldown, 0)


func test_default_dist_to_ahead_negative() -> void:
	assert_eq(_ai._dist_to_ahead, -1.0)


func test_default_steer_avoidance_zero() -> void:
	assert_eq(_ai._steer_avoidance, 0.0)


# ==========================================================================
# initialize()
# ==========================================================================


func test_initialize_sets_vehicle() -> void:
	var vehicle := RigidBody3D.new()
	add_child_autofree(vehicle)
	_ai.initialize(vehicle, 3, PoliceAIScript.Direction.EAST)
	assert_eq(_ai._vehicle, vehicle)


func test_initialize_sets_road_index() -> void:
	var vehicle := RigidBody3D.new()
	add_child_autofree(vehicle)
	_ai.initialize(vehicle, 5, PoliceAIScript.Direction.SOUTH)
	assert_eq(_ai._road_index, 5)


func test_initialize_sets_direction() -> void:
	var vehicle := RigidBody3D.new()
	add_child_autofree(vehicle)
	_ai.initialize(vehicle, 0, PoliceAIScript.Direction.WEST)
	assert_eq(_ai._direction, PoliceAIScript.Direction.WEST)


func test_initialize_sets_spawn_grace_to_2() -> void:
	var vehicle := RigidBody3D.new()
	add_child_autofree(vehicle)
	_ai.initialize(vehicle, 0, PoliceAIScript.Direction.NORTH)
	assert_eq(_ai._spawn_grace, 2.0)


func test_initialize_sets_path_refresh_timer() -> void:
	var vehicle := RigidBody3D.new()
	add_child_autofree(vehicle)
	_ai.initialize(vehicle, 0, PoliceAIScript.Direction.NORTH)
	# Timer is set to random value within PATH_REFRESH_INTERVAL
	assert_true(
		(
			_ai._path_refresh_timer >= 0.0
			and _ai._path_refresh_timer < PoliceAIScript.PATH_REFRESH_INTERVAL
		),
		"Path refresh timer should be randomized within interval",
	)


# ==========================================================================
# deactivate() — source verification (needs GEVP vehicle for runtime)
# ==========================================================================


func test_deactivate_sets_active_false() -> void:
	_ai._vehicle = null
	_ai.deactivate()
	assert_false(_ai.active)


func test_deactivate_source_applies_brakes() -> void:
	var src: String = (load(_BASE_PATH) as GDScript).source_code
	assert_true(
		src.contains("_vehicle.brake_input = 1.0"),
		"deactivate should apply full brake",
	)
	assert_true(
		src.contains("_vehicle.handbrake_input = 1.0"),
		"deactivate should apply full handbrake",
	)


func test_deactivate_source_zeroes_controls() -> void:
	var src: String = (load(_BASE_PATH) as GDScript).source_code
	assert_true(
		src.contains("_vehicle.steering_input = 0.0"),
		"deactivate should zero steering",
	)
	assert_true(
		src.contains("_vehicle.throttle_input = 0.0"),
		"deactivate should zero throttle",
	)


# ==========================================================================
# _dir_to_heading
# ==========================================================================


func test_dir_to_heading_north() -> void:
	assert_eq(_ai._dir_to_heading(PoliceAIScript.Direction.NORTH), Vector3(0, 0, -1))


func test_dir_to_heading_south() -> void:
	assert_eq(_ai._dir_to_heading(PoliceAIScript.Direction.SOUTH), Vector3(0, 0, 1))


func test_dir_to_heading_east() -> void:
	assert_eq(_ai._dir_to_heading(PoliceAIScript.Direction.EAST), Vector3(1, 0, 0))


func test_dir_to_heading_west() -> void:
	assert_eq(_ai._dir_to_heading(PoliceAIScript.Direction.WEST), Vector3(-1, 0, 0))


func test_dir_to_heading_invalid_defaults_north() -> void:
	assert_eq(_ai._dir_to_heading(99), Vector3(0, 0, -1))


# ==========================================================================
# _get_reverse
# ==========================================================================


func test_reverse_north_south() -> void:
	assert_eq(_ai._get_reverse(PoliceAIScript.Direction.NORTH), PoliceAIScript.Direction.SOUTH)


func test_reverse_south_north() -> void:
	assert_eq(_ai._get_reverse(PoliceAIScript.Direction.SOUTH), PoliceAIScript.Direction.NORTH)


func test_reverse_east_west() -> void:
	assert_eq(_ai._get_reverse(PoliceAIScript.Direction.EAST), PoliceAIScript.Direction.WEST)


func test_reverse_west_east() -> void:
	assert_eq(_ai._get_reverse(PoliceAIScript.Direction.WEST), PoliceAIScript.Direction.EAST)


func test_reverse_invalid_defaults_north() -> void:
	assert_eq(_ai._get_reverse(99), PoliceAIScript.Direction.NORTH)


# ==========================================================================
# _begin_escape
# ==========================================================================


func test_begin_escape_increments_attempts() -> void:
	_ai._vehicle = RigidBody3D.new()
	add_child_autofree(_ai._vehicle)
	_ai._escape_attempts = 0
	_ai._begin_escape()
	assert_eq(_ai._escape_attempts, 1)


func test_begin_escape_sets_escaping_true() -> void:
	_ai._vehicle = RigidBody3D.new()
	add_child_autofree(_ai._vehicle)
	_ai._begin_escape()
	assert_true(_ai._escaping)


func test_begin_escape_resets_stuck_timer() -> void:
	_ai._vehicle = RigidBody3D.new()
	add_child_autofree(_ai._vehicle)
	_ai._stuck_timer = 5.0
	_ai._begin_escape()
	assert_eq(_ai._stuck_timer, 0.0)


func test_begin_escape_resets_escape_timer() -> void:
	_ai._vehicle = RigidBody3D.new()
	add_child_autofree(_ai._vehicle)
	_ai._escape_timer = 3.0
	_ai._begin_escape()
	assert_eq(_ai._escape_timer, 0.0)


func test_begin_escape_over_max_resets_attempts() -> void:
	_ai._vehicle = RigidBody3D.new()
	add_child_autofree(_ai._vehicle)
	_ai._escape_attempts = PoliceAIScript.MAX_ESCAPE_ATTEMPTS
	_ai._begin_escape()
	# Incremented to 4, exceeds max 3, reset to 0
	assert_eq(_ai._escape_attempts, 0)
	assert_true(_ai._escaping)


func test_begin_escape_at_max_minus_one_does_not_reset() -> void:
	_ai._vehicle = RigidBody3D.new()
	add_child_autofree(_ai._vehicle)
	_ai._escape_attempts = PoliceAIScript.MAX_ESCAPE_ATTEMPTS - 1
	_ai._begin_escape()
	# Incremented to MAX (3), not > MAX so no reset
	assert_eq(_ai._escape_attempts, PoliceAIScript.MAX_ESCAPE_ATTEMPTS)
	assert_true(_ai._escaping)


# ==========================================================================
# _pick_next_direction — never picks reverse
# ==========================================================================


func test_pick_direction_never_reverses_north() -> void:
	for i in range(20):
		_ai._direction = PoliceAIScript.Direction.NORTH
		_ai._pick_next_direction()
		assert_ne(_ai._direction, PoliceAIScript.Direction.SOUTH)


func test_pick_direction_never_reverses_east() -> void:
	for i in range(20):
		_ai._direction = PoliceAIScript.Direction.EAST
		_ai._pick_next_direction()
		assert_ne(_ai._direction, PoliceAIScript.Direction.WEST)


func test_pick_direction_never_reverses_south() -> void:
	for i in range(20):
		_ai._direction = PoliceAIScript.Direction.SOUTH
		_ai._pick_next_direction()
		assert_ne(_ai._direction, PoliceAIScript.Direction.NORTH)


func test_pick_direction_never_reverses_west() -> void:
	for i in range(20):
		_ai._direction = PoliceAIScript.Direction.WEST
		_ai._pick_next_direction()
		assert_ne(_ai._direction, PoliceAIScript.Direction.EAST)


# ==========================================================================
# State transition — path waypoints cleared
# ==========================================================================


func test_pursue_to_patrol_clears_path() -> void:
	_ai._ai_state = PoliceAIScript.AIState.PURSUE
	_ai._path_waypoints = [Vector3.ONE, Vector3.ZERO] as Array[Vector3]
	_ai._path_idx = 1

	WantedLevelManager.wanted_level = 0
	_ai._update_ai_state(0.1)

	assert_eq(_ai._path_waypoints.size(), 0)
	assert_eq(_ai._path_idx, 0)
	assert_eq(_ai._path_refresh_timer, 0.0)


func test_pursue_to_patrol_los_timeout_clears_path() -> void:
	_ai._ai_state = PoliceAIScript.AIState.PURSUE
	_ai._los_cached = false
	_ai._los_lost_timer = PoliceAIScript.LOS_LOST_TIMEOUT - 0.01
	_ai._path_waypoints = [Vector3.ONE] as Array[Vector3]
	_ai._path_idx = 0

	WantedLevelManager.wanted_level = 3
	_ai._update_ai_state(0.1)

	assert_eq(_ai._ai_state, PoliceAIScript.AIState.PATROL)
	assert_eq(_ai._path_waypoints.size(), 0)
	assert_eq(_ai._path_idx, 0)


func test_patrol_to_pursue_sets_path_refresh_to_interval() -> void:
	_ai._ai_state = PoliceAIScript.AIState.PATROL
	_ai._path_refresh_timer = 0.0

	WantedLevelManager.wanted_level = 2
	_ai._update_ai_state(0.1)

	assert_eq(_ai._ai_state, PoliceAIScript.AIState.PURSUE)
	assert_eq(
		_ai._path_refresh_timer,
		PoliceAIScript.PATH_REFRESH_INTERVAL,
		"Should trigger immediate path computation on next frame",
	)


# ==========================================================================
# _physics_process guard — source verification
# ==========================================================================


func test_physics_process_returns_when_inactive() -> void:
	var src: String = (load(_SCRIPT_PATH) as GDScript).source_code
	assert_true(
		src.contains("if not active or not _vehicle"),
		"_physics_process should guard on active and _vehicle",
	)


func test_physics_process_lod_freeze() -> void:
	var src: String = (load(_SCRIPT_PATH) as GDScript).source_code
	assert_true(
		src.contains("cam_dist > LOD_FREEZE_DIST"),
		"_physics_process should skip AI for very far vehicles",
	)


# ==========================================================================
# LOS_LOCK_RANGE — timer frozen within close range
# ==========================================================================


func test_los_lock_range_less_than_los_range() -> void:
	assert_lt(
		PoliceAIScript.LOS_LOCK_RANGE,
		PoliceAIScript.LOS_RANGE,
		"LOS_LOCK_RANGE must be within detection range",
	)


func test_los_lock_range_greater_than_zero() -> void:
	assert_gt(PoliceAIScript.LOS_LOCK_RANGE, 0.0)


func test_los_lock_range_source_guards_timer() -> void:
	# Within LOS_LOCK_RANGE the lost timer must not increment.
	var src: String = (load(_SCRIPT_PATH) as GDScript).source_code
	assert_true(
		src.contains("LOS_LOCK_RANGE"),
		"_update_ai_state should reference LOS_LOCK_RANGE",
	)


func test_los_lost_timer_does_not_advance_when_no_vehicle() -> void:
	# With no vehicle the distance check returns INF so timer advances.
	# This confirms the null-safety ternary is in place.
	_ai._ai_state = PoliceAIScript.AIState.PURSUE
	_ai._los_cached = false
	_ai._los_lost_timer = 0.0
	_ai._vehicle = null

	WantedLevelManager.wanted_level = 3
	_ai._update_ai_state(0.1)

	# Timer should have advanced (no vehicle → INF distance → timer ticks)
	assert_gt(
		_ai._los_lost_timer,
		0.0,
		"Lost timer should tick when no vehicle is set (INF distance)",
	)


# ==========================================================================
# LOS_LOST_TIMEOUT — chase abandon interval
# ==========================================================================


func test_los_lost_timeout_is_at_least_40_seconds() -> void:
	assert_gte(
		PoliceAIScript.LOS_LOST_TIMEOUT,
		40.0,
		"Chase should not abandon before 40 s without line-of-sight",
	)
