extends GutTest
## Tests for walking state (scenes/player/states/walking.gd).

const WalkingScript = preload("res://scenes/player/states/walking.gd")


# ---------------------------------------------------------------------------
# Stubs
# ---------------------------------------------------------------------------

class StubCamera:
	extends Node3D
	var _yaw := 0.0
	func get_yaw() -> float:
		return _yaw


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
var _pcam: StubCamera


func before_each() -> void:
	_player = MockPlayer.new()
	_player.name = "Player"
	_pcam = StubCamera.new()
	_pcam.name = "PlayerCamera"
	_player.add_child(_pcam)
	_player.player_camera = _pcam

	_sm = StubStateMachine.new()
	_sm.name = "StateMachine"

	_state = WalkingScript.new()
	_state.name = "Walking"
	_sm.add_child(_state)
	_player.add_child(_sm)
	_state.state_machine = _sm

	add_child_autofree(_player)
	await get_tree().process_frame
	_state.owner = _player


func after_each() -> void:
	for action in ["move_forward", "move_backward", "move_left", "move_right", "sprint", "interact"]:
		if Input.is_action_pressed(action):
			Input.action_release(action)


# ---------------------------------------------------------------------------
# enter() tests
# ---------------------------------------------------------------------------

func test_enter_shows_steal_prompt_with_car() -> void:
	var vehicle := Node3D.new()
	add_child_autofree(vehicle)
	_player.nearest_vehicle = vehicle
	watch_signals(EventBus)
	_state.enter()
	assert_signal_emitted_with_parameters(
		EventBus, "show_interaction_prompt", ["Hold F to steal"],
	)


func test_enter_shows_board_prompt_with_boat() -> void:
	var boat := Node3D.new()
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


func test_enter_does_not_emit_prompt_without_vehicle() -> void:
	_player.nearest_vehicle = null
	watch_signals(EventBus)
	_state.enter()
	assert_signal_not_emitted(EventBus, "hide_interaction_prompt")
	assert_signal_not_emitted(EventBus, "show_interaction_prompt")


# ---------------------------------------------------------------------------
# exit() tests
# ---------------------------------------------------------------------------

func test_exit_does_not_hide_prompt() -> void:
	watch_signals(EventBus)
	_state.exit()
	assert_signal_not_emitted(EventBus, "hide_interaction_prompt")


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
	assert_eq(_sm.last_transition, "")


# ---------------------------------------------------------------------------
# physics_update() — transitions
# ---------------------------------------------------------------------------

func test_no_input_transitions_to_idle() -> void:
	_state.physics_update(0.016)
	assert_eq(_sm.last_transition, "Idle")


func test_sprint_transitions_to_running() -> void:
	Input.action_press("move_forward")
	Input.action_press("sprint")
	_state.physics_update(0.016)
	assert_eq(_sm.last_transition, "Running")
	Input.action_release("move_forward")
	Input.action_release("sprint")


func test_walk_input_stays_walking() -> void:
	Input.action_press("move_forward")
	_state.physics_update(0.016)
	assert_eq(_sm.last_transition, "", "Should stay in walking state")
	Input.action_release("move_forward")


func test_walking_uses_walk_speed() -> void:
	Input.action_press("move_forward")
	_player.velocity = Vector3.ZERO
	_state.physics_update(0.016)
	var h_speed := Vector2(_player.velocity.x, _player.velocity.z).length()
	assert_almost_eq(h_speed, _player.walk_speed, 0.1, "Should move at walk_speed")
	Input.action_release("move_forward")


# ---------------------------------------------------------------------------
# _get_camera_relative_direction() tests
# ---------------------------------------------------------------------------

func test_camera_direction_is_normalized() -> void:
	_pcam._yaw = 0.0
	var result: Vector3 = _state._get_camera_relative_direction(Vector2(0, -1))
	assert_almost_eq(result.length(), 1.0, 0.01)
	assert_almost_eq(result.y, 0.0, 0.001)


func test_camera_direction_rotates_with_yaw() -> void:
	_pcam._yaw = PI / 2.0
	var result_rotated: Vector3 = _state._get_camera_relative_direction(Vector2(0, -1))
	_pcam._yaw = 0.0
	var result_default: Vector3 = _state._get_camera_relative_direction(Vector2(0, -1))
	# The directions should differ when yaw changes
	assert_gt(
		result_rotated.distance_to(result_default), 0.1,
		"Direction should change with camera yaw",
	)


# ---------------------------------------------------------------------------
# _is_over_water() tests
# ---------------------------------------------------------------------------

func test_is_over_water_returns_false_without_city_manager() -> void:
	var result: bool = _state._is_over_water(Vector3.ZERO)
	assert_false(result, "Should return false without city_manager in scene")


# ---------------------------------------------------------------------------
# Jump — source-level verification
# ---------------------------------------------------------------------------

func test_walking_checks_jump_input_on_floor() -> void:
	var src: String = WalkingScript.source_code
	assert_true(
		src.contains("is_action_just_pressed(\"jump\")"),
		"Walking state should check for jump input when on floor",
	)


func test_walking_uses_jump_speed_property() -> void:
	var src: String = WalkingScript.source_code
	assert_true(
		src.contains("player.jump_speed"),
		"Walking state should set velocity.y to player.jump_speed on jump",
	)
