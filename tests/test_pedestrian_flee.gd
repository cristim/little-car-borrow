extends GutTest
## Tests for PedestrianFlee state (scenes/pedestrians/states/pedestrian_flee.gd).

const FleeScript = preload("res://scenes/pedestrians/states/pedestrian_flee.gd")
const StateScript = preload("res://src/state_machine/state.gd")


# ---------------------------------------------------------------------------
# Mock state machine that records transitions
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

func _make_flee_state() -> Node:
	var ped := CharacterBody3D.new()
	add_child_autofree(ped)
	ped.global_position = Vector3(10.0, 0.0, 10.0)

	var state := Node.new()
	state.set_script(FleeScript)
	state.name = "PedestrianFlee"

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

func test_flee_speed_constant() -> void:
	assert_eq(FleeScript.FLEE_SPEED, 4.0)


func test_flee_duration_constant() -> void:
	assert_eq(FleeScript.FLEE_DURATION, 5.0)


func test_safe_distance_constant() -> void:
	assert_eq(FleeScript.SAFE_DISTANCE, 20.0)


# ---------------------------------------------------------------------------
# enter
# ---------------------------------------------------------------------------

func test_enter_resets_timer() -> void:
	var state := _make_flee_state()
	await get_tree().process_frame

	state._timer = 99.0
	state.enter({"threat_pos": Vector3.ZERO})

	assert_eq(state._timer, 0.0)


func test_enter_sets_threat_pos() -> void:
	var state := _make_flee_state()
	await get_tree().process_frame

	var threat := Vector3(5.0, 0.0, 5.0)
	state.enter({"threat_pos": threat})

	assert_eq(state._threat_pos, threat)


func test_enter_calculates_flee_direction_away_from_threat() -> void:
	var state := _make_flee_state()
	await get_tree().process_frame

	# Owner is at (10, 0, 10), threat at (5, 0, 5)
	# Away direction should be roughly (1, 0, 1).normalized()
	state.enter({"threat_pos": Vector3(5.0, 0.0, 5.0)})

	assert_gt(state._flee_direction.x, 0.0, "Should flee in +x")
	assert_gt(state._flee_direction.z, 0.0, "Should flee in +z")
	assert_almost_eq(state._flee_direction.y, 0.0, 0.001, "Y should be zeroed")
	assert_almost_eq(
		state._flee_direction.length(), 1.0, 0.01,
		"Direction should be normalized",
	)


func test_enter_defaults_direction_when_threat_overlaps() -> void:
	var state := _make_flee_state()
	await get_tree().process_frame

	# Threat at same position as owner
	state.enter({"threat_pos": state.owner.global_position})

	assert_eq(state._flee_direction, Vector3.FORWARD)


func test_enter_defaults_threat_pos_when_missing() -> void:
	var state := _make_flee_state()
	await get_tree().process_frame

	state.enter({})

	# Default threat_pos is owner.global_position, so direction defaults to FORWARD
	assert_eq(state._flee_direction, Vector3.FORWARD)


func test_enter_zeroes_y_in_direction() -> void:
	var state := _make_flee_state()
	await get_tree().process_frame

	# Threat below the pedestrian — Y difference should not affect flee direction
	state.enter({"threat_pos": Vector3(5.0, -10.0, 5.0)})

	assert_almost_eq(state._flee_direction.y, 0.0, 0.001)


# ---------------------------------------------------------------------------
# physics_update — movement
# ---------------------------------------------------------------------------

func test_physics_update_sets_horizontal_velocity() -> void:
	var state := _make_flee_state()
	await get_tree().process_frame

	state.enter({"threat_pos": Vector3(5.0, 0.0, 5.0)})
	state.physics_update(0.016)

	var ped := state.owner as CharacterBody3D
	var horiz_speed := Vector2(ped.velocity.x, ped.velocity.z).length()
	assert_almost_eq(horiz_speed, FleeScript.FLEE_SPEED, 0.01)


func test_physics_update_applies_gravity() -> void:
	var state := _make_flee_state()
	await get_tree().process_frame

	state.enter({"threat_pos": Vector3.ZERO})
	state.owner.velocity.y = 0.0
	state.physics_update(0.1)

	assert_lt(state.owner.velocity.y, 0.0, "Gravity should pull Y down")


func test_physics_update_increments_timer() -> void:
	var state := _make_flee_state()
	await get_tree().process_frame

	state.enter({"threat_pos": Vector3.ZERO})
	state.physics_update(0.5)

	assert_almost_eq(state._timer, 0.5, 0.001)


# ---------------------------------------------------------------------------
# physics_update — transition to walk
# ---------------------------------------------------------------------------

func test_transitions_to_walk_after_duration() -> void:
	var state := _make_flee_state()
	await get_tree().process_frame

	state.enter({"threat_pos": Vector3.ZERO})

	# Accumulate time past FLEE_DURATION
	state._timer = FleeScript.FLEE_DURATION - 0.1
	state.physics_update(0.2)

	assert_eq(state.state_machine.last_target, "PedestrianWalk")
	assert_true(
		state.state_machine.last_msg.has("direction"),
		"Should pass direction to walk state",
	)


func test_transitions_to_walk_when_safe_distance_reached() -> void:
	var state := _make_flee_state()
	await get_tree().process_frame

	# Set threat very far away so distance > SAFE_DISTANCE
	state.enter({"threat_pos": Vector3(-100.0, 0.0, -100.0)})
	state.physics_update(0.016)

	assert_eq(state.state_machine.last_target, "PedestrianWalk")


func test_does_not_transition_before_duration_and_within_distance() -> void:
	var state := _make_flee_state()
	await get_tree().process_frame

	# Threat close to pedestrian, short time elapsed
	state.enter({"threat_pos": Vector3(9.0, 0.0, 9.0)})
	state.physics_update(0.1)

	assert_eq(
		state.state_machine.last_target, "",
		"Should not transition yet",
	)


func test_walk_transition_passes_flee_direction() -> void:
	var state := _make_flee_state()
	await get_tree().process_frame

	state.enter({"threat_pos": Vector3.ZERO})
	state._timer = FleeScript.FLEE_DURATION
	state.physics_update(0.1)

	var dir: Vector3 = state.state_machine.last_msg.get("direction", Vector3.ZERO)
	assert_almost_eq(dir.length(), 1.0, 0.1, "Direction should be roughly normalized")


func test_transition_at_exact_duration() -> void:
	var state := _make_flee_state()
	await get_tree().process_frame

	# Timer already at exactly FLEE_DURATION before the update
	state.enter({"threat_pos": Vector3(9.0, 0.0, 9.0)})
	state._timer = FleeScript.FLEE_DURATION
	state.physics_update(0.016)

	# _timer will be FLEE_DURATION + 0.016 >= FLEE_DURATION -> should transition
	assert_eq(state.state_machine.last_target, "PedestrianWalk")


func test_transition_at_exact_safe_distance() -> void:
	var state := _make_flee_state()
	await get_tree().process_frame

	# Place threat exactly SAFE_DISTANCE away
	var ped_pos: Vector3 = state.owner.global_position
	var threat := ped_pos + Vector3(FleeScript.SAFE_DISTANCE, 0.0, 0.0)
	state.enter({"threat_pos": threat})
	# dist >= SAFE_DISTANCE should trigger transition
	state.physics_update(0.016)

	assert_eq(state.state_machine.last_target, "PedestrianWalk")
