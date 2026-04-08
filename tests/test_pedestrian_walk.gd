extends GutTest
## Tests for PedestrianWalk state (scenes/pedestrians/states/pedestrian_walk.gd).

const WalkScript = preload("res://scenes/pedestrians/states/pedestrian_walk.gd")

# ---------------------------------------------------------------------------
# Mock state machine
# ---------------------------------------------------------------------------


class MockStateMachine:
	extends Node
	var last_target := ""
	var last_msg: Dictionary = {}

	func transition_to(target: String, msg: Dictionary = {}) -> void:
		last_target = target
		last_msg = msg


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


func _make_walk_state() -> Node:
	var ped := CharacterBody3D.new()
	add_child_autofree(ped)
	ped.global_position = Vector3(10.0, 0.0, 10.0)

	var state := Node.new()
	state.set_script(WalkScript)
	state.name = "PedestrianWalk"

	var sm := MockStateMachine.new()
	sm.name = "StateMachine"
	state.state_machine = sm

	ped.add_child(state)
	state.owner = ped
	ped.add_child(sm)
	return state


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------


func test_walk_speed_constant() -> void:
	assert_eq(WalkScript.WALK_SPEED, 1.4)


func test_turn_chance_constant() -> void:
	assert_eq(WalkScript.TURN_CHANCE, 0.3)


# ---------------------------------------------------------------------------
# enter
# ---------------------------------------------------------------------------


func test_enter_resets_walk_timer() -> void:
	var state := _make_walk_state()
	await get_tree().process_frame

	state._walk_timer = 99.0
	state.enter()

	assert_eq(state._walk_timer, 0.0)


func test_enter_sets_idle_interval_in_range() -> void:
	var state := _make_walk_state()
	await get_tree().process_frame

	state.enter()

	assert_gte(state._idle_interval, 8.0)
	assert_lte(state._idle_interval, 20.0)


func test_enter_uses_passed_direction() -> void:
	var state := _make_walk_state()
	await get_tree().process_frame

	var dir := Vector3(0.0, 0.0, -1.0)
	state.enter({"direction": dir})

	assert_eq(state._direction, dir)


func test_enter_without_direction_keeps_default() -> void:
	var state := _make_walk_state()
	await get_tree().process_frame

	# Default _direction is Vector3.FORWARD
	state.enter({})

	assert_eq(state._direction, Vector3.FORWARD)


func test_enter_randomizes_idle_interval() -> void:
	var state := _make_walk_state()
	await get_tree().process_frame

	var intervals := {}
	for i in range(20):
		state.enter()
		intervals[state._idle_interval] = true

	assert_gt(intervals.size(), 1, "Idle interval should vary across calls")


# ---------------------------------------------------------------------------
# physics_update — movement
# ---------------------------------------------------------------------------


func test_physics_update_sets_velocity_from_direction() -> void:
	var state := _make_walk_state()
	await get_tree().process_frame

	state.enter({"direction": Vector3.RIGHT})
	state.physics_update(0.016)

	var ped := state.owner as CharacterBody3D
	assert_almost_eq(ped.velocity.x, WalkScript.WALK_SPEED, 0.01)
	assert_almost_eq(ped.velocity.z, 0.0, 0.01)


func test_physics_update_forward_direction() -> void:
	var state := _make_walk_state()
	await get_tree().process_frame

	state.enter({"direction": Vector3.FORWARD})
	state.physics_update(0.016)

	var ped := state.owner as CharacterBody3D
	# FORWARD = (0, 0, -1)
	assert_almost_eq(ped.velocity.x, 0.0, 0.01)
	assert_almost_eq(ped.velocity.z, -WalkScript.WALK_SPEED, 0.01)


func test_physics_update_applies_gravity() -> void:
	var state := _make_walk_state()
	await get_tree().process_frame

	state.enter()
	state.owner.velocity.y = 0.0
	state.physics_update(0.1)

	assert_lt(state.owner.velocity.y, 0.0, "Gravity should pull Y down")


func test_physics_update_gravity_amount() -> void:
	var state := _make_walk_state()
	await get_tree().process_frame

	state.enter()
	state.owner.velocity.y = 0.0
	state.physics_update(1.0)

	assert_almost_eq(state.owner.velocity.y, -9.8, 0.01)


func test_physics_update_increments_walk_timer() -> void:
	var state := _make_walk_state()
	await get_tree().process_frame

	state.enter()
	state.physics_update(0.5)

	assert_almost_eq(state._walk_timer, 0.5, 0.001)


func test_physics_update_accumulates_walk_timer() -> void:
	var state := _make_walk_state()
	await get_tree().process_frame

	state.enter()
	state.physics_update(0.3)
	state.physics_update(0.4)

	assert_almost_eq(state._walk_timer, 0.7, 0.001)


# ---------------------------------------------------------------------------
# physics_update — transition to idle
# ---------------------------------------------------------------------------


func test_transitions_to_idle_after_interval() -> void:
	var state := _make_walk_state()
	await get_tree().process_frame

	state.enter()
	state._idle_interval = 2.0
	state._walk_timer = 1.9
	state.physics_update(0.2)

	assert_eq(state.state_machine.last_target, "PedestrianIdle")


func test_does_not_transition_before_interval() -> void:
	var state := _make_walk_state()
	await get_tree().process_frame

	state.enter()
	state._idle_interval = 10.0
	state._walk_timer = 0.0
	state.physics_update(0.5)

	assert_eq(state.state_machine.last_target, "", "Should not transition yet")


func test_transition_at_exact_interval() -> void:
	var state := _make_walk_state()
	await get_tree().process_frame

	state.enter()
	state._idle_interval = 5.0
	state._walk_timer = 5.0
	# After increment, timer > interval
	state.physics_update(0.016)

	assert_eq(state.state_machine.last_target, "PedestrianIdle")


func test_idle_transition_no_message() -> void:
	var state := _make_walk_state()
	await get_tree().process_frame

	state.enter()
	state._idle_interval = 0.1
	state._walk_timer = 0.0
	state.physics_update(0.2)

	# Idle transition is called without extra data
	assert_eq(state.state_machine.last_msg, {})


# ---------------------------------------------------------------------------
# Direction with zero magnitude does not crash look_at
# ---------------------------------------------------------------------------


func test_zero_direction_does_not_crash() -> void:
	var state := _make_walk_state()
	await get_tree().process_frame

	state._direction = Vector3.ZERO
	state.enter({"direction": Vector3.ZERO})
	state.physics_update(0.016)

	# The guard `if _direction.length_squared() > 0.01` should prevent look_at
	pass_test("Zero direction did not crash")


# ---------------------------------------------------------------------------
# Diagonal direction
# ---------------------------------------------------------------------------


func test_diagonal_direction_speed() -> void:
	var state := _make_walk_state()
	await get_tree().process_frame

	var dir := Vector3(1.0, 0.0, 1.0).normalized()
	state.enter({"direction": dir})
	state.physics_update(0.016)

	var ped := state.owner as CharacterBody3D
	var horiz_speed := Vector2(ped.velocity.x, ped.velocity.z).length()
	# Speed = direction.length() * WALK_SPEED; normalized dir has length 1
	assert_almost_eq(horiz_speed, WalkScript.WALK_SPEED, 0.01)
