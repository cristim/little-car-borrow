extends GutTest
## Tests for exiting_vehicle state (scenes/player/states/exiting_vehicle.gd).

const ExitingScript = preload("res://scenes/player/states/exiting_vehicle.gd")

# ---------------------------------------------------------------------------
# Stubs
# ---------------------------------------------------------------------------


class StubCamera:
	extends Node3D
	var active := false

	func make_active() -> void:
		active = true


class StubVehicleController:
	extends Node
	var active := true


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
var _vehicle: Node3D
var _pcam: StubCamera


func _build_vehicle(with_door := false, with_marker := false) -> Node3D:
	var v := Node3D.new()
	v.name = "Vehicle"
	var body := Node3D.new()
	body.name = "Body"
	v.add_child(body)
	if with_door:
		var pivot := Node3D.new()
		pivot.name = "LeftDoorPivot"
		body.add_child(pivot)
	if with_marker:
		var marker := Marker3D.new()
		marker.name = "DoorMarker"
		v.add_child(marker)
	return v


func before_each() -> void:
	_player = MockPlayer.new()
	_player.name = "Player"
	_pcam = StubCamera.new()
	_pcam.name = "PlayerCamera"
	_player.add_child(_pcam)
	_player.player_camera = _pcam

	_sm = StubStateMachine.new()
	_sm.name = "StateMachine"

	_state = ExitingScript.new()
	_state.name = "ExitingVehicle"
	_sm.add_child(_state)
	_player.add_child(_sm)
	_state.state_machine = _sm

	add_child_autofree(_player)
	await get_tree().process_frame
	_state.owner = _player

	_vehicle = _build_vehicle()
	add_child_autofree(_vehicle)


# ---------------------------------------------------------------------------
# enter() — null/invalid vehicle guard (C1)
# ---------------------------------------------------------------------------


func test_enter_with_null_vehicle_transitions_to_idle() -> void:
	_state.enter({})  # no "vehicle" key — msg.get returns null
	assert_eq(
		_sm.last_transition,
		"Idle",
		"enter() with null vehicle should transition to Idle",
	)


func test_enter_with_null_vehicle_leaves_done_false() -> void:
	_state.enter({"vehicle": null})
	assert_false(_state._done, "_done should remain false when vehicle is null")


# ---------------------------------------------------------------------------
# enter() tests
# ---------------------------------------------------------------------------


func test_enter_zeros_player_velocity() -> void:
	_player.velocity = Vector3(10.0, 5.0, 3.0)
	_state.enter({"vehicle": _vehicle})
	assert_eq(_player.velocity, Vector3.ZERO)


func test_enter_teleports_to_fallback_offset_without_marker() -> void:
	_vehicle.global_position = Vector3(10.0, 0.0, 5.0)
	_state.enter({"vehicle": _vehicle})
	var expected := Vector3(8.0, 0.5, 5.0)
	assert_almost_eq(_player.global_position.x, expected.x, 0.01)
	assert_almost_eq(_player.global_position.y, expected.y, 0.01)
	assert_almost_eq(_player.global_position.z, expected.z, 0.01)


func test_enter_teleports_to_door_marker_when_present() -> void:
	var v := _build_vehicle(false, true)
	add_child_autofree(v)
	var marker := v.get_node("DoorMarker") as Marker3D
	marker.global_position = Vector3(20.0, 1.0, 15.0)
	_state.enter({"vehicle": v})
	assert_almost_eq(_player.global_position.x, 20.0, 0.01)
	assert_almost_eq(_player.global_position.z, 15.0, 0.01)


func test_enter_clamps_y_to_sea_level_when_underwater() -> void:
	_vehicle.global_position = Vector3(0.0, -10.0, 0.0)
	_state.enter({"vehicle": _vehicle})
	assert_gte(
		_player.global_position.y,
		ExitingScript.SEA_LEVEL,
		"Player should not be below sea level after exit",
	)


func test_enter_deactivates_vehicle_controller() -> void:
	var vc := StubVehicleController.new()
	vc.name = "VehicleController"
	_vehicle.add_child(vc)
	_state.enter({"vehicle": _vehicle})
	assert_false(vc.active, "VehicleController should be deactivated")


func test_enter_deactivates_boat_controller() -> void:
	var bc := StubVehicleController.new()
	bc.name = "BoatController"
	_vehicle.add_child(bc)
	_state.enter({"vehicle": _vehicle})
	assert_false(bc.active, "BoatController should be deactivated")


func test_enter_activates_player_camera() -> void:
	_state.enter({"vehicle": _vehicle})
	assert_true(_pcam.active, "Player camera should be made active")


func test_enter_emits_vehicle_exited() -> void:
	watch_signals(EventBus)
	_state.enter({"vehicle": _vehicle})
	assert_signal_emitted(EventBus, "vehicle_exited")


func test_enter_sets_done_flag() -> void:
	_state.enter({"vehicle": _vehicle})
	assert_true(_state._done, "Done flag should be true after enter completes")


func test_enter_opens_door_pivot() -> void:
	var v := _build_vehicle(true)
	add_child_autofree(v)
	var pivot := v.get_node("Body/LeftDoorPivot")
	_state.enter({"vehicle": v})
	assert_almost_eq(
		pivot.rotation.y,
		ExitingScript.DOOR_OPEN_ANGLE,
		0.01,
		"Door should be opened to DOOR_OPEN_ANGLE",
	)


# ---------------------------------------------------------------------------
# physics_update() tests
# ---------------------------------------------------------------------------


func test_physics_update_transitions_to_idle_when_done() -> void:
	_state.enter({"vehicle": _vehicle})
	assert_true(_state._done)
	_state.physics_update(0.016)
	assert_eq(_sm.last_transition, "Idle")


func test_physics_update_does_not_transition_when_not_done() -> void:
	# Don't call enter, _done defaults to false
	_state._done = false
	_state.physics_update(0.016)
	assert_eq(_sm.last_transition, "", "Should not transition when not done")
