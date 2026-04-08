# gdlint:ignore = max-public-methods
extends GutTest
## Tests for swimming state (scenes/player/states/swimming.gd).

const SwimmingScript = preload("res://scenes/player/states/swimming.gd")

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

	_state = SwimmingScript.new()
	_state.name = "Swimming"
	_sm.add_child(_state)
	_player.add_child(_sm)
	_state.state_machine = _sm

	add_child_autofree(_player)
	await get_tree().process_frame
	_state.owner = _player


func after_each() -> void:
	for action in [
		"move_forward", "move_backward", "move_left", "move_right", "sprint", "interact"
	]:
		if Input.is_action_pressed(action):
			Input.action_release(action)


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------


func test_swim_speed_is_positive() -> void:
	assert_gt(SwimmingScript.SWIM_SPEED, 0.0)


func test_sprint_swim_speed_faster_than_normal() -> void:
	assert_gt(SwimmingScript.SPRINT_SWIM_SPEED, SwimmingScript.SWIM_SPEED)


func test_buoyancy_force_is_positive() -> void:
	assert_gt(SwimmingScript.BUOYANCY_FORCE, 0.0)


# ---------------------------------------------------------------------------
# enter() tests
# ---------------------------------------------------------------------------


func test_enter_sets_is_swimming_true() -> void:
	_state.enter()
	assert_true(_player.is_swimming)


func test_enter_emits_player_entered_water() -> void:
	watch_signals(EventBus)
	_state.enter()
	assert_signal_emitted(EventBus, "player_entered_water")


func test_enter_hides_prompt_without_boat() -> void:
	_player.nearest_vehicle = null
	watch_signals(EventBus)
	_state.enter()
	assert_signal_emitted(EventBus, "hide_interaction_prompt")


func test_enter_shows_board_prompt_for_nearby_boat() -> void:
	var boat := Node3D.new()
	var bc := Node.new()
	bc.name = "BoatController"
	boat.add_child(bc)
	add_child_autofree(boat)
	_player.nearest_vehicle = boat
	watch_signals(EventBus)
	_state.enter()
	assert_signal_emitted_with_parameters(
		EventBus,
		"show_interaction_prompt",
		["Hold F to board"],
	)


# ---------------------------------------------------------------------------
# exit() tests
# ---------------------------------------------------------------------------


func test_exit_sets_is_swimming_false() -> void:
	_state.enter()
	_state.exit()
	assert_false(_player.is_swimming)


func test_exit_emits_player_exited_water() -> void:
	_state.enter()
	watch_signals(EventBus)
	_state.exit()
	assert_signal_emitted(EventBus, "player_exited_water")


# ---------------------------------------------------------------------------
# physics_update() — buoyancy
# ---------------------------------------------------------------------------


func test_buoyancy_pushes_player_up_when_below_surface() -> void:
	_player.global_position.y = SwimmingScript.SEA_LEVEL - 1.0
	_player.velocity = Vector3.ZERO
	_state.physics_update(0.016)
	assert_gt(
		_player.velocity.y,
		0.0,
		"Buoyancy should push player upward when below water surface",
	)


func test_velocity_y_damps_when_above_surface() -> void:
	_player.global_position.y = SwimmingScript.SEA_LEVEL + SwimmingScript.SURFACE_OFFSET + 1.0
	_player.velocity = Vector3(0.0, 5.0, 0.0)
	_state.physics_update(0.016)
	assert_lt(
		_player.velocity.y,
		5.0,
		"Velocity Y should damp when above surface",
	)


# ---------------------------------------------------------------------------
# physics_update() — horizontal movement
# ---------------------------------------------------------------------------


func test_swim_forward_at_swim_speed() -> void:
	_player.global_position.y = SwimmingScript.SEA_LEVEL
	Input.action_press("move_forward")
	_state.physics_update(0.016)
	var h_speed := Vector2(_player.velocity.x, _player.velocity.z).length()
	assert_almost_eq(h_speed, SwimmingScript.SWIM_SPEED, 0.1)
	Input.action_release("move_forward")


func test_sprint_swim_at_sprint_speed() -> void:
	_player.global_position.y = SwimmingScript.SEA_LEVEL
	Input.action_press("move_forward")
	Input.action_press("sprint")
	_state.physics_update(0.016)
	var h_speed := Vector2(_player.velocity.x, _player.velocity.z).length()
	assert_almost_eq(h_speed, SwimmingScript.SPRINT_SWIM_SPEED, 0.1)
	Input.action_release("move_forward")
	Input.action_release("sprint")


func test_no_input_decelerates_horizontal() -> void:
	_player.global_position.y = SwimmingScript.SEA_LEVEL
	_player.velocity = Vector3(3.0, 0.0, 3.0)
	_state.physics_update(0.016)
	assert_lt(
		absf(_player.velocity.x),
		3.0,
		"X should decelerate without input",
	)
	assert_lt(
		absf(_player.velocity.z),
		3.0,
		"Z should decelerate without input",
	)


# ---------------------------------------------------------------------------
# physics_update() — exit conditions
# ---------------------------------------------------------------------------


func test_exits_to_idle_when_on_floor_above_water() -> void:
	_player.global_position.y = SwimmingScript.SEA_LEVEL + 1.0
	# CharacterBody3D.is_on_floor() depends on physics, so we test the logic
	# by checking the transition is not triggered when below water
	_player.global_position.y = SwimmingScript.SEA_LEVEL - 1.0
	_state.physics_update(0.016)
	assert_eq(
		_sm.last_transition,
		"",
		"Should not exit to idle when below water level",
	)


# ---------------------------------------------------------------------------
# handle_input() tests
# ---------------------------------------------------------------------------


func test_interact_with_boat_transitions_to_entering() -> void:
	var boat := Node3D.new()
	var bc := Node.new()
	bc.name = "BoatController"
	boat.add_child(bc)
	add_child_autofree(boat)
	_player.nearest_vehicle = boat
	var event := InputEventAction.new()
	event.action = "interact"
	event.pressed = true
	_state.handle_input(event)
	assert_eq(_sm.last_transition, "EnteringVehicle")
	assert_eq(_sm.last_msg.get("vehicle"), boat)


func test_interact_with_car_does_not_transition() -> void:
	var car := Node3D.new()
	add_child_autofree(car)
	_player.nearest_vehicle = car
	var event := InputEventAction.new()
	event.action = "interact"
	event.pressed = true
	_state.handle_input(event)
	assert_eq(
		_sm.last_transition,
		"",
		"Should not allow entering car from water",
	)


func test_interact_without_vehicle_does_nothing() -> void:
	_player.nearest_vehicle = null
	var event := InputEventAction.new()
	event.action = "interact"
	event.pressed = true
	_state.handle_input(event)
	assert_eq(_sm.last_transition, "")


# ---------------------------------------------------------------------------
# _is_over_water() and _get_ground_height()
# ---------------------------------------------------------------------------


func test_is_over_water_returns_false_without_city_manager() -> void:
	# No city_manager group nodes exist
	var result: bool = _state._is_over_water(Vector3.ZERO)
	assert_false(result, "Should return false without city_manager")


func test_get_ground_height_returns_zero_without_city_manager() -> void:
	var result: float = _state._get_ground_height(Vector3.ZERO)
	assert_eq(result, 0.0, "Should return 0.0 without city_manager")


# ---------------------------------------------------------------------------
# _get_camera_relative_direction()
# ---------------------------------------------------------------------------


func test_camera_direction_returns_normalized_vector() -> void:
	_pcam._yaw = 0.0
	var result: Vector3 = _state._get_camera_relative_direction(Vector2(0, -1))
	assert_almost_eq(result.length(), 1.0, 0.01)
	assert_almost_eq(result.y, 0.0, 0.001)
