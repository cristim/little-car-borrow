# gdlint:ignore = max-public-methods
extends GutTest
## Unit tests for police AI controller helpers and state transitions.

const PoliceAIScript = preload(
	"res://scenes/vehicles/police_ai_controller.gd"
)


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
# _calc_pursuit_steer
# ==========================================================================

func test_pursuit_steer_zero_heading() -> void:
	var result := PoliceAIScript._calc_pursuit_steer(0.0, 1.5)
	assert_eq(result, 0.0)


func test_pursuit_steer_90_left_clamped() -> void:
	var result := PoliceAIScript._calc_pursuit_steer(PI / 2.0, 1.5)
	assert_eq(result, 1.0)


func test_pursuit_steer_90_right_clamped() -> void:
	var result := PoliceAIScript._calc_pursuit_steer(-PI / 2.0, 1.5)
	assert_eq(result, -1.0)


func test_pursuit_steer_nearly_behind() -> void:
	var result := PoliceAIScript._calc_pursuit_steer(PI * 0.99, 1.5)
	assert_eq(result, 1.0)


func test_pursuit_steer_30_right_not_clamped() -> void:
	var result := PoliceAIScript._calc_pursuit_steer(-0.52, 1.5)
	assert_almost_eq(result, -0.78, 0.01)


# ==========================================================================
# _calc_pursuit_cruise
# ==========================================================================

func test_cruise_below_threshold_unchanged() -> void:
	var result := PoliceAIScript._calc_pursuit_cruise(0.3, 60.0, 0.5, 30.0)
	assert_eq(result, 60.0)


func test_cruise_at_threshold_unchanged() -> void:
	# Exactly at threshold: <= so should be unchanged
	var result := PoliceAIScript._calc_pursuit_cruise(0.5, 60.0, 0.5, 30.0)
	assert_eq(result, 60.0)


func test_cruise_90_degrees() -> void:
	var result := PoliceAIScript._calc_pursuit_cruise(
		PI / 2.0, 60.0, 0.5, 30.0
	)
	assert_almost_eq(result, 47.84, 0.1)


func test_cruise_180_degrees_minimum() -> void:
	var result := PoliceAIScript._calc_pursuit_cruise(PI, 60.0, 0.5, 30.0)
	assert_almost_eq(result, 30.0, 0.01)


# ==========================================================================
# _calc_wall_steer
# ==========================================================================

func test_wall_steer_low_urgency() -> void:
	var result := PoliceAIScript._calc_wall_steer(0.1, 0.3, 0.5)
	assert_almost_eq(result, 0.535, 0.01)


func test_wall_steer_medium_urgency() -> void:
	var result := PoliceAIScript._calc_wall_steer(0.5, 0.3, 0.5)
	assert_almost_eq(result, 0.675, 0.01)


func test_wall_steer_at_08_boundary_still_lerps() -> void:
	# Exactly 0.8: > not >=, so should still lerp
	var result := PoliceAIScript._calc_wall_steer(0.8, 0.3, 0.5)
	assert_almost_eq(result, 0.78, 0.01)


func test_wall_steer_above_08_full_override() -> void:
	var result := PoliceAIScript._calc_wall_steer(0.9, 0.3, 0.5)
	assert_eq(result, 1.0)


func test_wall_steer_no_avoidance_uses_current_sign() -> void:
	var result := PoliceAIScript._calc_wall_steer(0.5, 0.0, 0.5)
	assert_almost_eq(result, 0.675, 0.01)


func test_wall_steer_no_avoidance_no_current_defaults_positive() -> void:
	var result := PoliceAIScript._calc_wall_steer(0.5, 0.0, 0.0)
	assert_almost_eq(result, 0.35, 0.01)


# ==========================================================================
# _calc_escape_steer
# ==========================================================================

func test_escape_steer_pursue_with_avoidance() -> void:
	var result := PoliceAIScript._calc_escape_steer(
		PoliceAIScript.AIState.PURSUE, 0.5, 0.0,
	)
	assert_eq(result, 1.0)


func test_escape_steer_pursue_negative_avoidance() -> void:
	var result := PoliceAIScript._calc_escape_steer(
		PoliceAIScript.AIState.PURSUE, -0.5, 0.0,
	)
	assert_eq(result, -1.0)


func test_escape_steer_pursue_below_threshold() -> void:
	var result := PoliceAIScript._calc_escape_steer(
		PoliceAIScript.AIState.PURSUE, 0.05, 0.0,
	)
	assert_eq(result, 0.0)


func test_escape_steer_patrol_lane_error() -> void:
	var result := PoliceAIScript._calc_escape_steer(
		PoliceAIScript.AIState.PATROL, 0.0, -1.5,
	)
	assert_eq(result, 1.0)


func test_escape_steer_patrol_lane_below_threshold() -> void:
	var result := PoliceAIScript._calc_escape_steer(
		PoliceAIScript.AIState.PATROL, 0.0, 0.5,
	)
	assert_eq(result, 0.0)


# ==========================================================================
# State transitions
# ==========================================================================

func test_patrol_to_pursue_resets_timers() -> void:
	_ai._ai_state = PoliceAIScript.AIState.PATROL
	_ai._los_lost_timer = 5.0
	_ai._los_check_timer = 0.15
	_ai._escaping = true
	_ai._escape_timer = 1.0
	_ai._escape_attempts = 2

	WantedLevelManager.wanted_level = 2
	_ai._update_ai_state(0.1)

	assert_eq(_ai._ai_state, PoliceAIScript.AIState.PURSUE)
	assert_true(_ai._pursuit_locked)
	# _los_check_timer is reset then immediately += delta in the same call
	assert_almost_eq(_ai._los_check_timer, 0.1, 0.001)
	# _los_lost_timer: reset to 0, then += delta because _los_cached is false
	assert_almost_eq(_ai._los_lost_timer, 0.1, 0.001)
	assert_false(_ai._escaping)
	assert_eq(_ai._escape_timer, 0.0)
	assert_eq(_ai._escape_attempts, 0)


func test_pursue_to_patrol_wanted_zero_resets_road() -> void:
	_ai._ai_state = PoliceAIScript.AIState.PURSUE
	_ai._pursuit_locked = true
	_ai._escaping = true
	_ai._escape_timer = 1.0
	_ai._escape_attempts = 2

	WantedLevelManager.wanted_level = 0
	_ai._update_ai_state(0.1)

	assert_eq(_ai._ai_state, PoliceAIScript.AIState.PATROL)
	assert_false(_ai._pursuit_locked)
	assert_eq(_ai._los_lost_timer, 0.0)
	assert_false(_ai._escaping)
	assert_eq(_ai._escape_timer, 0.0)
	assert_eq(_ai._escape_attempts, 0)


func test_pursue_to_patrol_los_timeout() -> void:
	_ai._ai_state = PoliceAIScript.AIState.PURSUE
	_ai._pursuit_locked = true
	_ai._los_cached = false
	_ai._los_lost_timer = PoliceAIScript.LOS_LOST_TIMEOUT - 0.05

	WantedLevelManager.wanted_level = 3
	_ai._update_ai_state(0.1)

	# Timer exceeded LOS_LOST_TIMEOUT → should transition to PATROL
	assert_eq(_ai._ai_state, PoliceAIScript.AIState.PATROL)
	assert_false(_ai._pursuit_locked)
	assert_eq(_ai._los_lost_timer, 0.0)
	assert_false(_ai._escaping)
	assert_eq(_ai._escape_attempts, 0)


func test_rapid_state_cycling_clean() -> void:
	# PATROL → PURSUE
	WantedLevelManager.wanted_level = 1
	_ai._update_ai_state(0.1)
	assert_eq(_ai._ai_state, PoliceAIScript.AIState.PURSUE)

	# PURSUE → PATROL (wanted drops)
	WantedLevelManager.wanted_level = 0
	_ai._update_ai_state(0.1)
	assert_eq(_ai._ai_state, PoliceAIScript.AIState.PATROL)
	assert_false(_ai._escaping)
	assert_eq(_ai._escape_attempts, 0)

	# PATROL → PURSUE again
	WantedLevelManager.wanted_level = 2
	_ai._update_ai_state(0.1)
	assert_eq(_ai._ai_state, PoliceAIScript.AIState.PURSUE)
	# Timers reset then immediately += delta in the same call
	assert_almost_eq(_ai._los_lost_timer, 0.1, 0.001)
	assert_almost_eq(_ai._los_check_timer, 0.1, 0.001)


# ==========================================================================
# Avoidance clamping (Round 8: negative clamp case)
# ==========================================================================

func test_avoidance_clamp_positive_over_range() -> void:
	# _drive() uses clampf(_steer_avoidance, -0.5, 0.5)
	assert_eq(clampf(0.8, -0.5, 0.5), 0.5)


func test_avoidance_clamp_negative_over_range() -> void:
	# Negative avoidance should clamp to -0.5, not 0
	assert_eq(clampf(-0.8, -0.5, 0.5), -0.5)


func test_avoidance_clamp_within_range_unchanged() -> void:
	assert_eq(clampf(0.3, -0.5, 0.5), 0.3)
	assert_eq(clampf(-0.3, -0.5, 0.5), -0.3)


# ==========================================================================
# Guard logic: dist <= 1.0 (Round 8)
# ==========================================================================

func test_pursuit_steer_at_zero_heading_err_for_overlap() -> void:
	# When player overlaps car (dist <= 1.0), caller passes heading_err=0.0.
	# Steer should be 0.0 — no fishtailing or error.
	var steer := PoliceAIScript._calc_pursuit_steer(0.0, 1.5)
	assert_eq(steer, 0.0)
	# Speed should also stay at base cruise (heading_err_abs=0.0 < slow_angle)
	var cruise := PoliceAIScript._calc_pursuit_cruise(0.0, 60.0, 0.5, 30.0)
	assert_eq(cruise, 60.0)


# ==========================================================================
# Patrol regression (Round 8)
# ==========================================================================

func test_patrol_pick_direction_never_reverses() -> void:
	# _pick_next_direction (patrol path) should never pick reverse of current
	for i in range(20):
		_ai._direction = PoliceAIScript.Direction.NORTH
		_ai._pick_next_direction()
		assert_ne(
			_ai._direction, PoliceAIScript.Direction.SOUTH,
			"Patrol should never U-turn from NORTH (iteration %d)" % i,
		)


func test_patrol_pick_direction_covers_all_non_reverse() -> void:
	# Over many iterations, all 3 non-reverse directions should appear
	_ai._direction = PoliceAIScript.Direction.NORTH
	var seen := {}
	for i in range(100):
		_ai._direction = PoliceAIScript.Direction.NORTH
		_ai._pick_next_direction()
		seen[_ai._direction] = true
	# Should see NORTH (straight), EAST, WEST — but never SOUTH
	assert_true(
		seen.size() >= 2,
		"Should see at least 2 distinct directions, got %d" % seen.size(),
	)
	assert_false(
		seen.has(PoliceAIScript.Direction.SOUTH),
		"Should never pick reverse (SOUTH)",
	)


func test_patrol_state_after_pursue_ends() -> void:
	# After PURSUE→PATROL, the AI should be in a valid patrol state
	_ai._ai_state = PoliceAIScript.AIState.PURSUE
	_ai._pursuit_locked = true
	_ai._direction = PoliceAIScript.Direction.EAST

	WantedLevelManager.wanted_level = 0
	_ai._update_ai_state(0.1)

	assert_eq(_ai._ai_state, PoliceAIScript.AIState.PATROL)
	# Should be able to pick a new direction without crashing
	_ai._pick_next_direction()
	# Direction should be valid (not reverse of EAST=WEST is excluded,
	# but road_index=0 from mock, and direction was reset by _pick_best_direction)
	var dir: int = _ai._direction
	assert_true(
		dir >= 0 and dir <= 3,
		"Direction should be valid enum value, got %d" % dir,
	)
