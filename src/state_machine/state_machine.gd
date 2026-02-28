class_name StateMachine
extends Node
## Generic node-based state machine. Add State children to use.

@export var initial_state: State

var current_state: State
var states: Dictionary = {}


func _ready() -> void:
	for child in get_children():
		if child is State:
			states[child.name.to_lower()] = child
			child.state_machine = self
	if initial_state:
		current_state = initial_state
		current_state.enter()


func _process(delta: float) -> void:
	if current_state:
		current_state.update(delta)


func _physics_process(delta: float) -> void:
	if current_state:
		current_state.physics_update(delta)


func _unhandled_input(event: InputEvent) -> void:
	if current_state:
		current_state.handle_input(event)


func transition_to(target_state_name: String, msg: Dictionary = {}) -> void:
	var target_name := target_state_name.to_lower()
	if not states.has(target_name):
		push_error("State '%s' not found in StateMachine" % target_state_name)
		return
	if current_state:
		current_state.exit()
	current_state = states[target_name]
	current_state.enter(msg)
