extends GutTest
## Tests for entering_vehicle state (scenes/player/states/entering_vehicle.gd).

const EnteringScript = preload("res://scenes/player/states/entering_vehicle.gd")


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


class StubProgressBar:
	extends ProgressBar
	var shown := false
	var was_hidden := false
	var last_value := 0.0
	func show_progress() -> void:
		shown = true
	func hide_progress() -> void:
		was_hidden = true
	func update_progress(val: float) -> void:
		last_value = val


class MockPlayer:
	extends CharacterBody3D
	var current_vehicle: Node = null
	var walk_speed := 4.0
	var run_speed := 8.0
	var gravity := 20.0
	var nearest_vehicle: Node = null
	var is_swimming := false


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

var _state: Node
var _player: MockPlayer
var _sm: StubStateMachine
var _vehicle: Node3D
var _progress_bar: StubProgressBar


func _build_vehicle(with_boat := false) -> Node3D:
	var v := Node3D.new()
	v.name = "Vehicle"
	var body := Node3D.new()
	body.name = "Body"
	v.add_child(body)
	if with_boat:
		var bc := Node.new()
		bc.name = "BoatController"
		v.add_child(bc)
	return v


func before_each() -> void:
	_player = MockPlayer.new()
	_player.name = "Player"

	# PlayerUI/StealProgressBar stub
	var ui := Control.new()
	ui.name = "PlayerUI"
	_progress_bar = StubProgressBar.new()
	_progress_bar.name = "StealProgressBar"
	ui.add_child(_progress_bar)
	_player.add_child(ui)

	_sm = StubStateMachine.new()
	_sm.name = "StateMachine"

	_state = EnteringScript.new()
	_state.name = "EnteringVehicle"
	_sm.add_child(_state)
	_player.add_child(_sm)
	_state.state_machine = _sm

	add_child_autofree(_player)
	await get_tree().process_frame
	_state.owner = _player

	_vehicle = _build_vehicle()
	add_child_autofree(_vehicle)


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

func test_steal_duration_is_positive() -> void:
	assert_gt(EnteringScript.STEAL_DURATION, 0.0)


func test_door_anim_duration_is_positive() -> void:
	assert_gt(EnteringScript.DOOR_ANIM_DURATION, 0.0)


# ---------------------------------------------------------------------------
# enter() — car
# ---------------------------------------------------------------------------

func test_enter_resets_timer() -> void:
	_state.enter({"vehicle": _vehicle})
	assert_eq(_state._timer, 0.0, "Timer should be 0 on enter for car")


func test_enter_zeros_player_velocity() -> void:
	_player.velocity = Vector3(5.0, 3.0, 2.0)
	_state.enter({"vehicle": _vehicle})
	assert_eq(_player.velocity, Vector3.ZERO)


func test_enter_shows_progress_bar() -> void:
	_state.enter({"vehicle": _vehicle})
	assert_true(_progress_bar.shown, "Progress bar should be shown for car steal")


func test_enter_hides_interaction_prompt() -> void:
	watch_signals(EventBus)
	_state.enter({"vehicle": _vehicle})
	assert_signal_emitted(EventBus, "hide_interaction_prompt")


# ---------------------------------------------------------------------------
# enter() — boat (instant board)
# ---------------------------------------------------------------------------

func test_enter_boat_sets_timer_to_steal_duration() -> void:
	var boat := _build_vehicle(true)
	add_child_autofree(boat)
	_state.enter({"vehicle": boat})
	assert_eq(
		_state._timer, EnteringScript.STEAL_DURATION,
		"Boat should instantly set timer to STEAL_DURATION",
	)


func test_enter_boat_does_not_show_progress_bar() -> void:
	var boat := _build_vehicle(true)
	add_child_autofree(boat)
	_state.enter({"vehicle": boat})
	assert_false(
		_progress_bar.shown,
		"Progress bar should not be shown for boat boarding",
	)


# ---------------------------------------------------------------------------
# update() — timer progression
# ---------------------------------------------------------------------------

func test_update_increments_timer() -> void:
	_state.enter({"vehicle": _vehicle})
	# Simulate holding interact
	Input.action_press("interact")
	_state.update(0.5)
	assert_almost_eq(_state._timer, 0.5, 0.001)
	Input.action_release("interact")


func test_update_transitions_to_driving_when_timer_full() -> void:
	_state.enter({"vehicle": _vehicle})
	Input.action_press("interact")
	_state.update(EnteringScript.STEAL_DURATION + 0.1)
	assert_eq(_sm.last_transition, "Driving")
	assert_eq(_sm.last_msg.get("vehicle"), _vehicle)
	Input.action_release("interact")


func test_update_transitions_to_idle_when_interact_released() -> void:
	_state.enter({"vehicle": _vehicle})
	# interact is not pressed
	_state.update(0.1)
	assert_eq(_sm.last_transition, "Idle")


func test_update_updates_progress_bar() -> void:
	_state.enter({"vehicle": _vehicle})
	Input.action_press("interact")
	_state.update(0.75)
	var expected: float = 0.75 / EnteringScript.STEAL_DURATION
	assert_almost_eq(_progress_bar.last_value, expected, 0.01)
	Input.action_release("interact")


# ---------------------------------------------------------------------------
# exit()
# ---------------------------------------------------------------------------

func test_exit_hides_progress_bar() -> void:
	_state.enter({"vehicle": _vehicle})
	_state.exit()
	assert_true(_progress_bar.was_hidden, "Progress bar should be hidden on exit")


func test_exit_clears_vehicle() -> void:
	_state.enter({"vehicle": _vehicle})
	_state.exit()
	assert_null(_state._vehicle, "Vehicle should be null after exit")


func test_exit_resets_timer() -> void:
	_state.enter({"vehicle": _vehicle})
	Input.action_press("interact")
	_state.update(0.5)
	Input.action_release("interact")
	_state.exit()
	assert_eq(_state._timer, 0.0)


# ---------------------------------------------------------------------------
# _get_nearest_door_pivot()
# ---------------------------------------------------------------------------

func test_nearest_door_returns_null_when_no_doors() -> void:
	_state._vehicle = _vehicle
	var result: Node3D = _state._get_nearest_door_pivot(_player)
	assert_null(result, "Should return null when no door pivots exist")


func test_nearest_door_returns_left_when_only_left() -> void:
	var left := Node3D.new()
	left.name = "LeftDoorPivot"
	_vehicle.get_node("Body").add_child(left)
	_state.enter({"vehicle": _vehicle})
	var result: Node3D = _state._get_nearest_door_pivot(_player)
	assert_eq(result, left)


func test_nearest_door_returns_right_when_only_right() -> void:
	var right := Node3D.new()
	right.name = "RightDoorPivot"
	_vehicle.get_node("Body").add_child(right)
	_state.enter({"vehicle": _vehicle})
	var result: Node3D = _state._get_nearest_door_pivot(_player)
	assert_eq(result, right)


func test_nearest_door_picks_closer_door() -> void:
	var left := Node3D.new()
	left.name = "LeftDoorPivot"
	_vehicle.get_node("Body").add_child(left)
	var right := Node3D.new()
	right.name = "RightDoorPivot"
	_vehicle.get_node("Body").add_child(right)
	_state.enter({"vehicle": _vehicle})

	# Put player closer to right door
	_player.global_position = Vector3(5.0, 0.0, 0.0)
	right.global_position = Vector3(4.0, 0.0, 0.0)
	left.global_position = Vector3(-4.0, 0.0, 0.0)
	var result: Node3D = _state._get_nearest_door_pivot(_player)
	assert_eq(result, right, "Should pick the closer door")


# ---------------------------------------------------------------------------
# physics_update() — gravity while entering
# ---------------------------------------------------------------------------

func test_physics_update_applies_gravity() -> void:
	_state.enter({"vehicle": _vehicle})
	_player.velocity = Vector3.ZERO
	_state.physics_update(0.1)
	# gravity * delta = 20.0 * 0.1 = 2.0 downward
	assert_lt(
		_player.velocity.y, 0.0,
		"physics_update should apply gravity (velocity.y should be negative)",
	)


func test_physics_update_accumulates_gravity() -> void:
	_state.enter({"vehicle": _vehicle})
	_player.velocity = Vector3.ZERO
	_state.physics_update(0.1)
	var first_y: float = _player.velocity.y
	_state.physics_update(0.1)
	assert_lt(
		_player.velocity.y, first_y,
		"Gravity should accumulate over multiple frames",
	)
