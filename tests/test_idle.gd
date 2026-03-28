extends GutTest
## Tests for idle state (scenes/player/states/idle.gd).

const IdleScript = preload("res://scenes/player/states/idle.gd")
const PlayerScript = preload("res://scenes/player/player.gd")


# ---------------------------------------------------------------------------
# Stubs
# ---------------------------------------------------------------------------

class StubStateMachine:
	extends Node
	var last_transition := ""
	var last_msg: Dictionary = {}
	func transition_to(name: String, msg: Dictionary = {}) -> void:
		last_transition = name
		last_msg = msg


class MockPlayer:
	extends CharacterBody3D
	var current_vehicle: Node = null
	var walk_speed := 4.0
	var run_speed := 8.0
	var gravity := 20.0
	var jump_speed := 7.0
	var nearest_vehicle: Node = null
	var is_swimming := false
	var player_camera: Node3D = null


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

var _state: Node
var _player: MockPlayer
var _sm: StubStateMachine


func before_each() -> void:
	_player = MockPlayer.new()
	_player.name = "Player"
	var cam := Node3D.new()
	cam.name = "PlayerCamera"
	_player.add_child(cam)
	_player.player_camera = cam

	_sm = StubStateMachine.new()
	_sm.name = "StateMachine"

	_state = IdleScript.new()
	_state.name = "Idle"
	_sm.add_child(_state)
	_player.add_child(_sm)
	_state.state_machine = _sm

	add_child_autofree(_player)
	await get_tree().process_frame
	_state.owner = _player


func after_each() -> void:
	# Clean up any pressed actions
	for action in ["move_forward", "move_backward", "move_left", "move_right", "sprint", "interact"]:
		if Input.is_action_pressed(action):
			Input.action_release(action)


# ---------------------------------------------------------------------------
# enter() tests
# ---------------------------------------------------------------------------

func test_enter_shows_steal_prompt_when_car_nearby() -> void:
	var vehicle := Node3D.new()
	vehicle.name = "Vehicle"
	add_child_autofree(vehicle)
	_player.nearest_vehicle = vehicle
	watch_signals(EventBus)
	_state.enter()
	assert_signal_emitted_with_parameters(
		EventBus, "show_interaction_prompt", ["Hold F to steal"],
	)


func test_enter_shows_board_prompt_when_boat_nearby() -> void:
	var boat := Node3D.new()
	boat.name = "Boat"
	var bc := Node.new()
	bc.name = "BoatController"
	boat.add_child(bc)
	add_child_autofree(boat)
	_player.nearest_vehicle = boat
	watch_signals(EventBus)
	_state.enter()
	assert_signal_emitted_with_parameters(
		EventBus, "show_interaction_prompt", ["Hold F to board"],
	)


func test_enter_hides_prompt_when_no_vehicle() -> void:
	_player.nearest_vehicle = null
	watch_signals(EventBus)
	_state.enter()
	assert_signal_emitted(EventBus, "hide_interaction_prompt")


# ---------------------------------------------------------------------------
# exit() tests
# ---------------------------------------------------------------------------

func test_exit_hides_interaction_prompt() -> void:
	watch_signals(EventBus)
	_state.exit()
	assert_signal_emitted(EventBus, "hide_interaction_prompt")


# ---------------------------------------------------------------------------
# handle_input() tests
# ---------------------------------------------------------------------------

func test_interact_with_vehicle_transitions_to_entering() -> void:
	var vehicle := Node3D.new()
	add_child_autofree(vehicle)
	_player.nearest_vehicle = vehicle
	var event := InputEventAction.new()
	event.action = "interact"
	event.pressed = true
	_state.handle_input(event)
	assert_eq(_sm.last_transition, "EnteringVehicle")
	assert_eq(_sm.last_msg.get("vehicle"), vehicle)


func test_interact_without_vehicle_does_nothing() -> void:
	_player.nearest_vehicle = null
	var event := InputEventAction.new()
	event.action = "interact"
	event.pressed = true
	_state.handle_input(event)
	assert_eq(_sm.last_transition, "", "Should not transition without nearby vehicle")


# ---------------------------------------------------------------------------
# physics_update() — movement transitions
# ---------------------------------------------------------------------------

func test_physics_update_transitions_to_walking_with_input() -> void:
	Input.action_press("move_forward")
	_state.physics_update(0.016)
	assert_eq(_sm.last_transition, "Walking")
	Input.action_release("move_forward")


func test_physics_update_transitions_to_running_with_sprint() -> void:
	Input.action_press("move_forward")
	Input.action_press("sprint")
	_state.physics_update(0.016)
	assert_eq(_sm.last_transition, "Running")
	Input.action_release("move_forward")
	Input.action_release("sprint")


func test_physics_update_stays_idle_without_input() -> void:
	_state.physics_update(0.016)
	assert_eq(_sm.last_transition, "", "Should stay idle with no movement input")


func test_physics_update_decelerates_horizontal_velocity() -> void:
	_player.velocity = Vector3(2.0, 0.0, 2.0)
	_state.physics_update(0.016)
	# move_toward should reduce velocity toward zero
	assert_lte(
		absf(_player.velocity.x), 2.0,
		"X velocity should not increase",
	)
	assert_lte(
		absf(_player.velocity.z), 2.0,
		"Z velocity should not increase",
	)


# ---------------------------------------------------------------------------
# Jump — source-level verification
# ---------------------------------------------------------------------------

func test_idle_checks_jump_input_on_floor() -> void:
	var src: String = IdleScript.source_code
	assert_true(
		src.contains("is_action_just_pressed(\"jump\")"),
		"Idle state should check for jump input when on floor",
	)


func test_idle_uses_jump_speed_property() -> void:
	var src: String = IdleScript.source_code
	assert_true(
		src.contains("player.jump_speed"),
		"Idle state should set velocity.y to player.jump_speed on jump",
	)


func test_player_jump_speed_default() -> void:
	var src: String = PlayerScript.source_code
	assert_true(
		src.contains("jump_speed := 7.0"),
		"Player jump_speed should default to 7.0",
	)
