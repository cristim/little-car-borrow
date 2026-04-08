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


func test_state_machine_reassignable() -> void:
	var state := StateScript.new()
	add_child_autofree(state)
	var node_a := Node.new()
	var node_b := Node.new()
	add_child_autofree(node_a)
	add_child_autofree(node_b)
	state.state_machine = node_a
	assert_eq(state.state_machine, node_a, "state_machine should hold node_a")
	state.state_machine = node_b
	assert_eq(state.state_machine, node_b, "state_machine should be reassignable")


func test_enter_with_multiple_keys() -> void:
	var state := StateScript.new()
	add_child_autofree(state)
	state.enter({"a": 1, "b": "two", "c": true})
	pass_test("enter() accepts dict with multiple keys without error")


func test_update_zero_delta() -> void:
	var state := StateScript.new()
	add_child_autofree(state)
	state.update(0.0)
	pass_test("update() accepts zero delta without error")


func test_physics_update_zero_delta() -> void:
	var state := StateScript.new()
	add_child_autofree(state)
	state.physics_update(0.0)
	pass_test("physics_update() accepts zero delta without error")


func test_source_declares_state_machine_var() -> void:
	var src: String = (StateScript as GDScript).source_code
	assert_true(
		src.contains("var state_machine"),
		"state.gd must declare 'var state_machine'"
	)


func test_source_declares_enter() -> void:
	var src: String = (StateScript as GDScript).source_code
	assert_true(src.contains("func enter("), "state.gd must declare 'func enter('")


func test_source_declares_exit() -> void:
	var src: String = (StateScript as GDScript).source_code
	assert_true(src.contains("func exit()"), "state.gd must declare 'func exit()'")


func test_source_declares_update() -> void:
	var src: String = (StateScript as GDScript).source_code
	assert_true(src.contains("func update("), "state.gd must declare 'func update('")


func test_source_declares_physics_update() -> void:
	var src: String = (StateScript as GDScript).source_code
	assert_true(
		src.contains("func physics_update("),
		"state.gd must declare 'func physics_update('"
	)


func test_source_declares_handle_input() -> void:
	var src: String = (StateScript as GDScript).source_code
	assert_true(
		src.contains("func handle_input("),
		"state.gd must declare 'func handle_input('"
	)
