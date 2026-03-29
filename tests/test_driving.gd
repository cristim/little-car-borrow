# gdlint:ignore = max-public-methods
extends GutTest
## Tests for driving state (scenes/player/states/driving.gd).

const DrivingScript = preload("res://scenes/player/states/driving.gd")
const StateScript = preload("res://src/state_machine/state.gd")


# ---------------------------------------------------------------------------
# Minimal stubs
# ---------------------------------------------------------------------------

class StubCamera:
	extends Node3D
	var active := false
	func make_active() -> void:
		active = true


class StubVehicleController:
	extends Node
	var active := false


class StubBoatController:
	extends Node
	var active := false


class StubLights:
	extends Node3D
	var player_driving := false
	var toggled := false
	func set_player_driving(v: bool) -> void:
		player_driving = v
	func toggle_lights() -> void:
		toggled = true


class StubProgressBar:
	extends Control
	func show_progress() -> void:
		pass
	func hide_progress() -> void:
		pass


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
var _vehicle: StaticBody3D
var _vcam: StubCamera
var _vc: StubVehicleController


func _build_vehicle(with_boat := false, with_npc := false) -> StaticBody3D:
	var v := StaticBody3D.new()
	v.name = "Vehicle"
	v.collision_layer = 16

	var cam := StubCamera.new()
	cam.name = "VehicleCamera"
	v.add_child(cam)
	_vcam = cam

	var vc := StubVehicleController.new()
	vc.name = "VehicleController"
	v.add_child(vc)
	_vc = vc

	if with_boat:
		var bc := StubBoatController.new()
		bc.name = "BoatController"
		v.add_child(bc)

	if with_npc:
		var npc := Node.new()
		npc.name = "NPCVehicleController"
		v.add_child(npc)

	# Body with pre-existing VehicleLights stub (avoids real script instantiation)
	var body := Node3D.new()
	body.name = "Body"
	var stub_lights := StubLights.new()
	stub_lights.name = "VehicleLights"
	body.add_child(stub_lights)
	v.add_child(body)

	# Pre-add VehicleWaterDetector stub to avoid real script instantiation
	var wd := Node.new()
	wd.name = "VehicleWaterDetector"
	v.add_child(wd)

	return v


func before_each() -> void:
	_player = MockPlayer.new()
	_player.name = "Player"
	# Player needs a camera
	var pcam := StubCamera.new()
	pcam.name = "PlayerCamera"
	_player.add_child(pcam)
	_player.player_camera = pcam

	_sm = StubStateMachine.new()
	_sm.name = "StateMachine"

	_state = DrivingScript.new()
	_state.name = "Driving"
	_sm.add_child(_state)
	_player.add_child(_sm)
	_state.state_machine = _sm
	# owner is set when added to the scene tree with owner param
	# For states, owner is the player (root of the scene)
	# In GUT we set it manually after adding to tree
	add_child_autofree(_player)
	await get_tree().process_frame
	# Manually set owner since we are not using scene tree owner propagation
	_state.owner = _player

	_vehicle = _build_vehicle()
	add_child_autofree(_vehicle)


# ---------------------------------------------------------------------------
# enter() tests
# ---------------------------------------------------------------------------

func test_enter_sets_current_vehicle() -> void:
	_state.enter({"vehicle": _vehicle})
	assert_eq(_player.current_vehicle, _vehicle)


func test_enter_hides_player_for_car() -> void:
	_state.enter({"vehicle": _vehicle})
	assert_false(_player.visible, "Player should be hidden when driving a car")


func test_enter_disables_player_physics() -> void:
	_state.enter({"vehicle": _vehicle})
	assert_false(
		_player.is_physics_processing(),
		"Player physics should be disabled while driving",
	)


func test_enter_zeros_player_collision() -> void:
	_state.enter({"vehicle": _vehicle})
	assert_eq(_player.collision_layer, 0)
	assert_eq(_player.collision_mask, 0)


func test_enter_activates_vehicle_controller() -> void:
	_state.enter({"vehicle": _vehicle})
	assert_true(_vc.active, "VehicleController should be activated")


func test_enter_activates_vehicle_camera() -> void:
	_state.enter({"vehicle": _vehicle})
	assert_true(_vcam.active, "VehicleCamera should be made active")


func test_enter_sets_vehicle_collision_layer_to_player_vehicle() -> void:
	_vehicle.collision_layer = 16
	_state.enter({"vehicle": _vehicle})
	assert_eq(_vehicle.collision_layer, 8, "Should set to PlayerVehicle layer (8)")


func test_enter_boat_keeps_player_visible() -> void:
	var boat := _build_vehicle(true)
	add_child_autofree(boat)
	_state.enter({"vehicle": boat})
	assert_true(_player.visible, "Player should stay visible on boat")


func test_enter_boat_activates_boat_controller() -> void:
	var boat := _build_vehicle(true)
	add_child_autofree(boat)
	var bc := boat.get_node("BoatController")
	_state.enter({"vehicle": boat})
	assert_true(bc.active, "BoatController should be activated")


func test_enter_npc_vehicle_emits_crime() -> void:
	var npc_vehicle := _build_vehicle(false, true)
	add_child_autofree(npc_vehicle)
	watch_signals(EventBus)
	_state.enter({"vehicle": npc_vehicle})
	assert_signal_emitted(EventBus, "crime_committed")


func test_enter_emits_vehicle_entered() -> void:
	watch_signals(EventBus)
	_state.enter({"vehicle": _vehicle})
	assert_signal_emitted(EventBus, "vehicle_entered")


func test_enter_connects_force_exit() -> void:
	_state.enter({"vehicle": _vehicle})
	assert_true(
		EventBus.force_exit_vehicle.is_connected(_state._on_force_exit),
		"Should connect force_exit_vehicle signal",
	)


# ---------------------------------------------------------------------------
# exit() tests
# ---------------------------------------------------------------------------

func test_exit_restores_vehicle_collision_layer() -> void:
	_vehicle.collision_layer = 16
	_state.enter({"vehicle": _vehicle})
	_state.exit()
	assert_eq(_vehicle.collision_layer, 16, "Should restore original collision layer")


func test_exit_restores_player_visibility() -> void:
	_state.enter({"vehicle": _vehicle})
	_state.exit()
	assert_true(_player.visible, "Player should be visible after exiting vehicle")


func test_exit_re_enables_player_physics() -> void:
	_state.enter({"vehicle": _vehicle})
	_state.exit()
	assert_true(
		_player.is_physics_processing(),
		"Player physics should be re-enabled",
	)


func test_exit_restores_player_collision() -> void:
	_state.enter({"vehicle": _vehicle})
	_state.exit()
	assert_eq(_player.collision_layer, 4, "Player layer should be 4")
	assert_eq(_player.collision_mask, 115, "Player mask should be 115")


func test_exit_clears_current_vehicle() -> void:
	_state.enter({"vehicle": _vehicle})
	_state.exit()
	assert_null(_player.current_vehicle, "current_vehicle should be null after exit")


func test_exit_disconnects_force_exit() -> void:
	_state.enter({"vehicle": _vehicle})
	_state.exit()
	assert_false(
		EventBus.force_exit_vehicle.is_connected(_state._on_force_exit),
		"Should disconnect force_exit_vehicle signal",
	)


func test_exit_applies_brakes_to_stop_car() -> void:
	_state.enter({"vehicle": _vehicle})
	_vehicle.steering_input = 0.5
	_vehicle.throttle_input = 1.0
	_state.exit()
	assert_eq(_vehicle.brake_input, 1.0, "brake_input should be 1.0 on exit")
	assert_eq(_vehicle.handbrake_input, 1.0, "handbrake_input should be 1.0 on exit")
	assert_eq(_vehicle.throttle_input, 0.0, "throttle_input should be 0 on exit")


func test_exit_deactivates_boat_controller() -> void:
	var boat := _build_vehicle(true)
	add_child_autofree(boat)
	_state.enter({"vehicle": boat})
	var bc := boat.get_node("BoatController")
	_state.exit()
	assert_false(bc.active, "BoatController should be deactivated on exit")


func test_exit_re_enables_player_model_for_boat() -> void:
	# Boats disable player_model.set_process on entry; verify exit re-enables it.
	var src: String = DrivingScript.source_code
	assert_true(
		src.contains("if boat_ctrl or heli_ctrl:"),
		"exit() must reset player model for boats as well as helicopters",
	)


func test_exit_disables_lights_player_driving() -> void:
	var lights: Node = _vehicle.get_node("Body/VehicleLights")
	_state.enter({"vehicle": _vehicle})
	assert_true(lights.player_driving, "Lights should be player_driving during drive")
	_state.exit()
	assert_false(lights.player_driving, "Lights player_driving should be false on exit")


# ---------------------------------------------------------------------------
# handle_input() tests
# ---------------------------------------------------------------------------

func test_interact_transitions_to_exiting_vehicle() -> void:
	_state.enter({"vehicle": _vehicle})
	var event := InputEventAction.new()
	event.action = "interact"
	event.pressed = true
	_state.handle_input(event)
	assert_eq(_sm.last_transition, "ExitingVehicle")
	assert_eq(_sm.last_msg.get("vehicle"), _vehicle)


func test_toggle_flashlight_toggles_lights() -> void:
	var lights: Node = _vehicle.get_node("Body/VehicleLights")
	_state.enter({"vehicle": _vehicle})
	var event := InputEventAction.new()
	event.action = "toggle_flashlight"
	event.pressed = true
	_state.handle_input(event)
	assert_true(lights.toggled, "toggle_flashlight should call toggle_lights()")


# ---------------------------------------------------------------------------
# physics_update() tests
# ---------------------------------------------------------------------------

func test_physics_update_syncs_player_position() -> void:
	_state.enter({"vehicle": _vehicle})
	_vehicle.global_position = Vector3(10.0, 5.0, 20.0)
	_state.physics_update(0.016)
	assert_eq(
		_player.global_position, _vehicle.global_position,
		"Player position should match vehicle position",
	)


# ---------------------------------------------------------------------------
# _on_force_exit() tests
# ---------------------------------------------------------------------------

func test_force_exit_triggers_transition_for_matching_vehicle() -> void:
	_state.enter({"vehicle": _vehicle})
	_state._on_force_exit(_vehicle)
	assert_eq(_sm.last_transition, "ExitingVehicle")


func test_force_exit_ignores_different_vehicle() -> void:
	_state.enter({"vehicle": _vehicle})
	var other := Node3D.new()
	add_child_autofree(other)
	_state._on_force_exit(other)
	assert_eq(_sm.last_transition, "", "Should not transition for different vehicle")
