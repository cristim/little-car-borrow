extends GutTest
## Tests for the State base class (src/state_machine/state.gd).

const StateScript = preload("res://src/state_machine/state.gd")


func test_state_extends_node() -> void:
	var state := StateScript.new()
	add_child_autofree(state)
	assert_is(state, Node, "State should extend Node")


func test_state_machine_var_defaults_to_null() -> void:
	var state := StateScript.new()
	add_child_autofree(state)
	assert_null(state.state_machine, "state_machine should default to null")


func test_state_machine_var_can_be_assigned() -> void:
	var state := StateScript.new()
	var dummy := Node.new()
	add_child_autofree(state)
	add_child_autofree(dummy)
	state.state_machine = dummy
	assert_eq(state.state_machine, dummy)


func test_enter_accepts_empty_dict() -> void:
	var state := StateScript.new()
	add_child_autofree(state)
	# Should not error
	state.enter()
	pass_test("enter() with no args does not error")


func test_enter_accepts_dict() -> void:
	var state := StateScript.new()
	add_child_autofree(state)
	state.enter({"key": "value"})
	pass_test("enter() with dict does not error")


func test_exit_does_not_error() -> void:
	var state := StateScript.new()
	add_child_autofree(state)
	state.exit()
	pass_test("exit() does not error")


func test_update_accepts_delta() -> void:
	var state := StateScript.new()
	add_child_autofree(state)
	state.update(0.016)
	pass_test("update() accepts delta without error")


func test_physics_update_accepts_delta() -> void:
	var state := StateScript.new()
	add_child_autofree(state)
	state.physics_update(0.016)
	pass_test("physics_update() accepts delta without error")


func test_handle_input_accepts_event() -> void:
	var state := StateScript.new()
	add_child_autofree(state)
	var event := InputEventKey.new()
	state.handle_input(event)
	pass_test("handle_input() accepts InputEvent without error")
