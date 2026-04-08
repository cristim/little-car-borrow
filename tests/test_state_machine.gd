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
	assert_push_error_count(1, "Should emit exactly one push_error for missing state")
	assert_eq(sm.current_state, state_a, "Should remain in current state")


func test_ready_populates_states_dict() -> void:
	var sm := StateMachineScript.new()
	var state_a := MockState.new()
	state_a.name = "Alpha"
	var state_b := MockState.new()
	state_b.name = "Beta"
	sm.add_child(state_a)
	sm.add_child(state_b)
	add_child_autofree(sm)
	await get_tree().process_frame

	assert_true(sm.states.has("alpha"), "states dict should contain 'alpha' (lowercased)")
	assert_true(sm.states.has("beta"), "states dict should contain 'beta' (lowercased)")
	assert_eq(sm.states["alpha"], state_a, "states['alpha'] should reference state_a")
	assert_eq(sm.states["beta"], state_b, "states['beta'] should reference state_b")


func test_ready_assigns_state_machine_ref_to_children() -> void:
	var sm := StateMachineScript.new()
	var state_a := MockState.new()
	state_a.name = "StateA"
	sm.add_child(state_a)
	add_child_autofree(sm)
	await get_tree().process_frame

	assert_eq(state_a.state_machine, sm, "state_machine ref should point back to sm")


func test_no_initial_state_leaves_current_state_null() -> void:
	var sm := StateMachineScript.new()
	var state_a := MockState.new()
	state_a.name = "StateA"
	sm.add_child(state_a)
	# intentionally do NOT set sm.initial_state
	add_child_autofree(sm)
	await get_tree().process_frame

	assert_null(sm.current_state, "current_state should remain null without initial_state")
	assert_false(state_a.entered, "state should not be entered without initial_state")


func test_initial_state_entered_on_ready() -> void:
	var sm := StateMachineScript.new()
	var state_a := MockState.new()
	state_a.name = "StateA"
	sm.add_child(state_a)
	sm.initial_state = state_a
	add_child_autofree(sm)
	await get_tree().process_frame

	assert_eq(sm.current_state, state_a, "current_state should be initial_state after _ready")
	assert_true(state_a.entered, "initial_state.enter() should be called in _ready")


func test_transition_default_msg_is_empty_dict() -> void:
	var sm := StateMachineScript.new()
	var state_a := MockState.new()
	state_a.name = "StateA"
	var state_b := MockState.new()
	state_b.name = "StateB"
	sm.add_child(state_a)
	sm.add_child(state_b)
	sm.initial_state = state_a
	add_child_autofree(sm)
	await get_tree().process_frame

	sm.transition_to("StateB")
	assert_eq(state_b.last_msg, {}, "Default msg should be empty dict")


func test_multiple_transitions() -> void:
	var sm := StateMachineScript.new()
	var state_a := MockState.new()
	state_a.name = "StateA"
	var state_b := MockState.new()
	state_b.name = "StateB"
	sm.add_child(state_a)
	sm.add_child(state_b)
	sm.initial_state = state_a
	add_child_autofree(sm)
	await get_tree().process_frame

	sm.transition_to("StateB")
	assert_eq(sm.current_state, state_b, "After first transition, current_state should be state_b")

	# Reset flags to test second transition
	state_b.exited = false
	state_a.entered = false

	sm.transition_to("StateA")
	assert_eq(sm.current_state, state_a, "After second transition, current_state should be state_a")
	assert_true(state_b.exited, "state_b should be exited on second transition")
	assert_true(state_a.entered, "state_a should be re-entered on second transition")


func test_transition_case_insensitive() -> void:
	var sm := StateMachineScript.new()
	var state_a := MockState.new()
	state_a.name = "StateA"
	var state_b := MockState.new()
	state_b.name = "StateB"
	sm.add_child(state_a)
	sm.add_child(state_b)
	sm.initial_state = state_a
	add_child_autofree(sm)
	await get_tree().process_frame

	sm.transition_to("STATEB")
	assert_eq(sm.current_state, state_b, "transition_to should be case-insensitive")


func test_source_declares_transition_to() -> void:
	var src: String = (StateMachineScript as GDScript).source_code
	assert_true(
		src.contains("func transition_to("),
		"state_machine.gd must declare 'func transition_to('"
	)


func test_source_declares_current_state_var() -> void:
	var src: String = (StateMachineScript as GDScript).source_code
	assert_true(
		src.contains("var current_state"),
		"state_machine.gd must declare 'var current_state'"
	)


func test_source_declares_states_dict() -> void:
	var src: String = (StateMachineScript as GDScript).source_code
	assert_true(
		src.contains("var states"),
		"state_machine.gd must declare 'var states'"
	)
