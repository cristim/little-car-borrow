extends GutTest
## Tests for the StateMachine and State base classes.

const StateScript = preload("res://src/state_machine/state.gd")
const StateMachineScript = preload("res://src/state_machine/state_machine.gd")


class MockState:
	extends "res://src/state_machine/state.gd"
	var entered := false
	var exited := false
	var last_msg: Dictionary = {}

	func enter(msg: Dictionary = {}) -> void:
		entered = true
		last_msg = msg

	func exit() -> void:
		exited = true


func test_transition_calls_exit_and_enter() -> void:
	var sm := StateMachineScript.new()
	var state_a := MockState.new()
	state_a.name = "StateA"
	var state_b := MockState.new()
	state_b.name = "StateB"
	sm.add_child(state_a)
	sm.add_child(state_b)
	sm.initial_state = state_a
	add_child_autofree(sm)

	# Wait one frame for _ready
	await get_tree().process_frame

	assert_true(state_a.entered, "Initial state should be entered")

	sm.transition_to("StateB", {"reason": "test"})
	assert_true(state_a.exited, "Previous state should be exited")
	assert_true(state_b.entered, "Target state should be entered")
	assert_eq(state_b.last_msg, {"reason": "test"}, "Message should be passed")


func test_transition_to_invalid_state_does_not_crash() -> void:
	var sm := StateMachineScript.new()
	var state_a := MockState.new()
	state_a.name = "StateA"
	sm.add_child(state_a)
	sm.initial_state = state_a
	add_child_autofree(sm)
	await get_tree().process_frame

	# Should log error but not crash
	sm.transition_to("NonExistent")
	assert_eq(sm.current_state, state_a, "Should remain in current state")
