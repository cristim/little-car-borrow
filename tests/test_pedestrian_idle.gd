extends GutTest
## Tests for PedestrianIdle state (scenes/pedestrians/states/pedestrian_idle.gd).

const IdleScript = preload("res://scenes/pedestrians/states/pedestrian_idle.gd")


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

func _make_idle_state() -> Node:
	var ped := CharacterBody3D.new()
	add_child_autofree(ped)

	var state := Node.new()
	state.set_script(IdleScript)
	state.name = "PedestrianIdle"

	var sm := MockStateMachine.new()
	sm.name = "StateMachine"
	state.state_machine = sm

	ped.add_child(state)
	state.owner = ped
	ped.add_child(sm)
	return state


# ---------------------------------------------------------------------------
# enter
# ---------------------------------------------------------------------------

func test_enter_resets_timer() -> void:
	var state := _make_idle_state()
	await get_tree().process_frame

	state._timer = 99.0
	state.enter()

	assert_eq(state._timer, 0.0)


func test_enter_sets_duration_in_range() -> void:
	var state := _make_idle_state()
	await get_tree().process_frame

	state.enter()

	assert_gte(state._duration, 2.0, "Duration should be at least 2.0")
	assert_lte(state._duration, 8.0, "Duration should be at most 8.0")


func test_enter_randomizes_rng() -> void:
	# Verify enter() calls randomize() so durations vary
	var durations := {}
	var state := _make_idle_state()
	await get_tree().process_frame

	for i in range(20):
		state.enter()
		durations[state._duration] = true

	assert_gt(durations.size(), 1, "Repeated enter() should produce varied durations")


# ---------------------------------------------------------------------------
# physics_update — stops horizontal movement
# ---------------------------------------------------------------------------

func test_physics_update_zeroes_horizontal_velocity() -> void:
	var state := _make_idle_state()
	await get_tree().process_frame

	state.enter()

	var ped := state.owner as CharacterBody3D
	ped.velocity = Vector3(5.0, 0.0, 5.0)
	state.physics_update(0.016)

	assert_eq(ped.velocity.x, 0.0, "Should zero X velocity")
	assert_eq(ped.velocity.z, 0.0, "Should zero Z velocity")


func test_physics_update_applies_gravity() -> void:
	var state := _make_idle_state()
	await get_tree().process_frame

	state.enter()

	var ped := state.owner as CharacterBody3D
	ped.velocity.y = 0.0
	state.physics_update(0.1)

	assert_lt(ped.velocity.y, 0.0, "Gravity should pull Y down")


func test_physics_update_gravity_amount() -> void:
	var state := _make_idle_state()
	await get_tree().process_frame

	state.enter()

	var ped := state.owner as CharacterBody3D
	ped.velocity.y = 0.0
	state.physics_update(1.0)

	assert_almost_eq(ped.velocity.y, -9.8, 0.01)


func test_physics_update_increments_timer() -> void:
	var state := _make_idle_state()
	await get_tree().process_frame

	state.enter()
	state.physics_update(0.5)

	assert_almost_eq(state._timer, 0.5, 0.001)


# ---------------------------------------------------------------------------
# physics_update — transition to walk
# ---------------------------------------------------------------------------

func test_transitions_to_walk_after_duration() -> void:
	var state := _make_idle_state()
	await get_tree().process_frame

	state.enter()
	# Force a short duration
	state._duration = 1.0
	state._timer = 0.9
	state.physics_update(0.2)

	assert_eq(state.state_machine.last_target, "PedestrianWalk")


func test_does_not_transition_before_duration() -> void:
	var state := _make_idle_state()
	await get_tree().process_frame

	state.enter()
	state._duration = 5.0
	state._timer = 0.0
	state.physics_update(0.5)

	assert_eq(state.state_machine.last_target, "", "Should not transition yet")


func test_walk_transition_passes_direction() -> void:
	var state := _make_idle_state()
	await get_tree().process_frame

	state.enter()
	state._duration = 0.1
	state._timer = 0.0
	state.physics_update(0.2)

	assert_true(
		state.state_machine.last_msg.has("direction"),
		"Should pass direction to walk state",
	)


func test_walk_direction_is_cardinal() -> void:
	var state := _make_idle_state()
	await get_tree().process_frame

	var cardinal_dirs: Array[Vector3] = [
		Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT,
	]

	# Run several times to test randomness
	for i in range(10):
		state.enter()
		state._duration = 0.1
		state._timer = 0.0
		state.physics_update(0.2)

		var dir: Vector3 = state.state_machine.last_msg.get("direction", Vector3.ZERO)
		assert_true(
			cardinal_dirs.has(dir),
			"Direction should be cardinal, got %s (iteration %d)" % [dir, i],
		)
		state.state_machine.last_target = ""
		state.state_machine.last_msg = {}


func test_walk_direction_varies_over_many_runs() -> void:
	var state := _make_idle_state()
	await get_tree().process_frame

	var dirs_seen := {}
	for i in range(50):
		state.enter()
		state._duration = 0.1
		state._timer = 0.0
		state.physics_update(0.2)

		var dir: Vector3 = state.state_machine.last_msg.get("direction", Vector3.ZERO)
		dirs_seen[dir] = true
		state.state_machine.last_target = ""
		state.state_machine.last_msg = {}

	assert_gt(dirs_seen.size(), 1, "Should pick varied directions over many runs")


func test_transition_at_exact_duration() -> void:
	var state := _make_idle_state()
	await get_tree().process_frame

	state.enter()
	state._duration = 3.0
	state._timer = 3.0
	# timer (3.0) + delta → timer >= _duration after increment
	state.physics_update(0.016)

	assert_eq(state.state_machine.last_target, "PedestrianWalk")
