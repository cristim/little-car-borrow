extends GutTest
## Unit tests for vehicle_ai_base.gd — Direction enum, heading helpers,
## get_reverse, find_next_road_coord, pick_best_direction, and deactivate.

const VehicleAIBase = preload("res://src/vehicle_ai_base.gd")
const _BASE_PATH := "res://src/vehicle_ai_base.gd"

var _ai: Node


func before_each() -> void:
	_ai = VehicleAIBase.new()
	add_child_autofree(_ai)


# ==========================================================================
# Direction enum values
# ==========================================================================


func test_direction_north_is_zero() -> void:
	assert_eq(VehicleAIBase.Direction.NORTH, 0)


func test_direction_south_is_one() -> void:
	assert_eq(VehicleAIBase.Direction.SOUTH, 1)


func test_direction_east_is_two() -> void:
	assert_eq(VehicleAIBase.Direction.EAST, 2)


func test_direction_west_is_three() -> void:
	assert_eq(VehicleAIBase.Direction.WEST, 3)


# ==========================================================================
# Shared constants
# ==========================================================================


func test_arrival_dist() -> void:
	assert_eq(VehicleAIBase.ARRIVAL_DIST, 6.0)


func test_lod_freeze_dist_greater_than_far() -> void:
	assert_true(VehicleAIBase.LOD_FREEZE_DIST > VehicleAIBase.LOD_FAR_DIST)


func test_lod_far_dist_greater_than_mid() -> void:
	assert_true(VehicleAIBase.LOD_FAR_DIST > VehicleAIBase.LOD_MID_DIST)


func test_hard_brake_dist_less_than_soft() -> void:
	assert_true(VehicleAIBase.HARD_BRAKE_DIST < VehicleAIBase.SOFT_BRAKE_DIST)


func test_stuck_timeout_value() -> void:
	assert_eq(VehicleAIBase.STUCK_TIMEOUT, 0.8)


func test_max_escape_attempts_value() -> void:
	assert_eq(VehicleAIBase.MAX_ESCAPE_ATTEMPTS, 3)


# ==========================================================================
# Default instance state
# ==========================================================================


func test_default_active_true() -> void:
	assert_true(_ai.active)


func test_default_spawn_grace_zero() -> void:
	assert_eq(_ai._spawn_grace, 0.0)


func test_default_direction_north() -> void:
	assert_eq(_ai._direction, VehicleAIBase.Direction.NORTH)


func test_default_dist_to_ahead_negative() -> void:
	assert_eq(_ai._dist_to_ahead, -1.0)


func test_default_escape_attempts_zero() -> void:
	assert_eq(_ai._escape_attempts, 0)


# ==========================================================================
# _dir_to_heading
# ==========================================================================


func test_dir_to_heading_north() -> void:
	assert_eq(
		_ai._dir_to_heading(VehicleAIBase.Direction.NORTH),
		Vector3(0, 0, -1),
	)


func test_dir_to_heading_south() -> void:
	assert_eq(
		_ai._dir_to_heading(VehicleAIBase.Direction.SOUTH),
		Vector3(0, 0, 1),
	)


func test_dir_to_heading_east() -> void:
	assert_eq(
		_ai._dir_to_heading(VehicleAIBase.Direction.EAST),
		Vector3(1, 0, 0),
	)


func test_dir_to_heading_west() -> void:
	assert_eq(
		_ai._dir_to_heading(VehicleAIBase.Direction.WEST),
		Vector3(-1, 0, 0),
	)


func test_dir_to_heading_invalid_defaults_north() -> void:
	assert_eq(_ai._dir_to_heading(99), Vector3(0, 0, -1))


# ==========================================================================
# _get_reverse
# ==========================================================================


func test_reverse_north_gives_south() -> void:
	assert_eq(
		_ai._get_reverse(VehicleAIBase.Direction.NORTH),
		VehicleAIBase.Direction.SOUTH,
	)


func test_reverse_south_gives_north() -> void:
	assert_eq(
		_ai._get_reverse(VehicleAIBase.Direction.SOUTH),
		VehicleAIBase.Direction.NORTH,
	)


func test_reverse_east_gives_west() -> void:
	assert_eq(
		_ai._get_reverse(VehicleAIBase.Direction.EAST),
		VehicleAIBase.Direction.WEST,
	)


func test_reverse_west_gives_east() -> void:
	assert_eq(
		_ai._get_reverse(VehicleAIBase.Direction.WEST),
		VehicleAIBase.Direction.EAST,
	)


func test_reverse_invalid_defaults_north() -> void:
	assert_eq(
		_ai._get_reverse(99),
		VehicleAIBase.Direction.NORTH,
	)


# ==========================================================================
# _find_next_road_coord
# ==========================================================================


func test_find_next_road_coord_positive_direction_returns_ahead() -> void:
	# With sign_dir=1 (southward), result should be > current
	var result := _ai._find_next_road_coord(0.0, 1)
	assert_true(result > 0.0, "Positive sign_dir should return a coordinate ahead")


func test_find_next_road_coord_negative_direction_returns_behind() -> void:
	# With sign_dir=-1 (northward), result should be < current
	var result := _ai._find_next_road_coord(0.0, -1)
	assert_true(result < 0.0, "Negative sign_dir should return a coordinate behind")


func test_find_next_road_coord_respects_min_ahead() -> void:
	# Minimum look-ahead is 15 units
	var result := _ai._find_next_road_coord(0.0, 1)
	assert_true(result >= 15.0, "Should not return a coord less than 15 units ahead")


# ==========================================================================
# deactivate
# ==========================================================================


func test_deactivate_sets_active_false() -> void:
	_ai.active = true
	_ai.deactivate()
	assert_false(_ai.active)


func test_deactivate_without_vehicle_does_not_crash() -> void:
	_ai._vehicle = null
	_ai.deactivate()
	assert_false(_ai.active)


func test_deactivate_source_zeroes_controls() -> void:
	var src: String = (load(_BASE_PATH) as GDScript).source_code
	assert_true(src.contains("_vehicle.steering_input = 0.0"))
	assert_true(src.contains("_vehicle.throttle_input = 0.0"))
	assert_true(src.contains("_vehicle.brake_input = 1.0"))
	assert_true(src.contains("_vehicle.handbrake_input = 1.0"))
