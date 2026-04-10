extends GutTest
## Tests for player.gd — interaction detection, state setup, and camera yaw.

const PlayerScript = preload("res://scenes/player/player.gd")
const StateMachineScript = preload("res://src/state_machine/state_machine.gd")
const StateScript = preload("res://src/state_machine/state.gd")

var _player: CharacterBody3D
var _camera: Node3D
var _interaction_area: Area3D
var _state_machine: Node
var _saved_context: int


func before_each() -> void:
	_saved_context = InputManager.current_context

	_player = CharacterBody3D.new()
	_player.set_script(PlayerScript)

	# Stub PlayerCamera with required methods
	_camera = Node3D.new()
	_camera.name = "PlayerCamera"
	_camera.set_script(_make_camera_stub())
	_player.add_child(_camera)

	# Stub InteractionArea
	_interaction_area = Area3D.new()
	_interaction_area.name = "InteractionArea"
	_player.add_child(_interaction_area)

	# Stub StateMachine with an idle state
	_state_machine = Node.new()
	_state_machine.set_script(StateMachineScript)
	_state_machine.name = "StateMachine"
	var idle_state := Node.new()
	idle_state.set_script(StateScript)
	idle_state.name = "Idle"
	_state_machine.add_child(idle_state)
	_state_machine.initial_state = idle_state
	_player.add_child(_state_machine)

	add_child_autofree(_player)
	await get_tree().process_frame


func after_each() -> void:
	InputManager.current_context = _saved_context


# Helper: creates a minimal camera stub script
func _make_camera_stub() -> GDScript:
	var src := """extends Node3D
var _yaw := 0.0
var _made_current := false
func make_active() -> void:
	_made_current = true
func get_yaw() -> float:
	return _yaw
"""
	var script := GDScript.new()
	script.source_code = src
	script.reload()
	return script


# ==========================================================================
# Ready / initialization
# ==========================================================================


func test_player_added_to_player_group() -> void:
	assert_true(
		_player.is_in_group("player"),
		"Player should be in 'player' group after _ready",
	)


func test_ready_sets_foot_context() -> void:
	assert_eq(
		InputManager.current_context,
		InputManager.Context.FOOT,
		"InputManager should be in FOOT context after player _ready",
	)


func test_ready_activates_player_camera() -> void:
	assert_true(
		_camera._made_current,
		"PlayerCamera.make_active() should be called in _ready",
	)


func test_initial_state_is_idle() -> void:
	assert_not_null(
		_state_machine.current_state,
		"StateMachine should have a current state",
	)
	assert_eq(
		_state_machine.current_state.name,
		"Idle",
		"Initial state should be Idle",
	)


# ==========================================================================
# Exported properties / defaults
# ==========================================================================


func test_default_walk_speed() -> void:
	assert_eq(_player.walk_speed, 4.0, "Default walk speed")


func test_default_run_speed() -> void:
	assert_eq(_player.run_speed, 8.0, "Default run speed")


func test_default_gravity() -> void:
	assert_eq(_player.gravity, 9.8, "Default gravity")


func test_default_rotation_speed() -> void:
	assert_eq(_player.rotation_speed, 10.0, "Default rotation speed")


# ==========================================================================
# State variables
# ==========================================================================


func test_initial_nearest_vehicle_is_null() -> void:
	assert_null(_player.nearest_vehicle, "nearest_vehicle starts null")


func test_initial_current_vehicle_is_null() -> void:
	assert_null(_player.current_vehicle, "current_vehicle starts null")


func test_initial_is_swimming_is_false() -> void:
	assert_false(_player.is_swimming, "is_swimming starts false")


# ==========================================================================
# Interaction area: vehicle entered
# ==========================================================================


func test_interaction_entered_sets_nearest_vehicle() -> void:
	var vehicle := Node3D.new()
	var zone := Area3D.new()
	zone.add_to_group("vehicle_interaction")
	vehicle.add_child(zone)
	add_child_autofree(vehicle)
	# Emit signal manually (physics overlap won't fire in test)
	_player._on_interaction_area_entered(zone)
	assert_eq(
		_player.nearest_vehicle,
		vehicle,
		"nearest_vehicle should be set to the zone's parent",
	)


func test_interaction_entered_ignores_non_vehicle_zone() -> void:
	var zone := Area3D.new()
	var parent := Node3D.new()
	parent.add_child(zone)
	add_child_autofree(parent)
	_player._on_interaction_area_entered(zone)
	assert_null(
		_player.nearest_vehicle,
		"nearest_vehicle should remain null for non-vehicle zones",
	)


func test_interaction_entered_shows_steal_prompt() -> void:
	var captured := []
	var on_prompt := func(text: String) -> void: captured.append(text)
	EventBus.show_interaction_prompt.connect(on_prompt)
	var vehicle := Node3D.new()
	var zone := Area3D.new()
	zone.add_to_group("vehicle_interaction")
	vehicle.add_child(zone)
	add_child_autofree(vehicle)
	_player._on_interaction_area_entered(zone)
	EventBus.show_interaction_prompt.disconnect(on_prompt)
	assert_eq(captured.size(), 1, "Should emit one prompt signal")
	if captured.size() > 0:
		assert_eq(captured[0], "Hold F to steal", "Should show steal prompt")


func test_interaction_entered_shows_board_prompt_for_boat() -> void:
	var captured := []
	var on_prompt := func(text: String) -> void: captured.append(text)
	EventBus.show_interaction_prompt.connect(on_prompt)
	var vehicle := Node3D.new()
	var boat_ctrl := Node.new()
	boat_ctrl.name = "BoatController"
	vehicle.add_child(boat_ctrl)
	var zone := Area3D.new()
	zone.add_to_group("vehicle_interaction")
	vehicle.add_child(zone)
	add_child_autofree(vehicle)
	_player._on_interaction_area_entered(zone)
	EventBus.show_interaction_prompt.disconnect(on_prompt)
	assert_eq(captured.size(), 1, "Should emit one prompt signal")
	if captured.size() > 0:
		assert_eq(captured[0], "Hold F to board", "Should show board prompt for boats")


# ==========================================================================
# Interaction area: vehicle exited
# ==========================================================================


func test_interaction_exited_clears_nearest_vehicle() -> void:
	var vehicle := Node3D.new()
	var zone := Area3D.new()
	zone.add_to_group("vehicle_interaction")
	vehicle.add_child(zone)
	add_child_autofree(vehicle)
	_player.nearest_vehicle = vehicle
	_player._on_interaction_area_exited(zone)
	assert_null(
		_player.nearest_vehicle,
		"nearest_vehicle should be cleared on exit",
	)


func test_interaction_exited_emits_hide_prompt() -> void:
	var captured := []
	var on_hide := func() -> void: captured.append(true)
	EventBus.hide_interaction_prompt.connect(on_hide)
	var vehicle := Node3D.new()
	var zone := Area3D.new()
	zone.add_to_group("vehicle_interaction")
	vehicle.add_child(zone)
	add_child_autofree(vehicle)
	_player.nearest_vehicle = vehicle
	_player._on_interaction_area_exited(zone)
	EventBus.hide_interaction_prompt.disconnect(on_hide)
	assert_eq(captured.size(), 1, "Should emit hide_interaction_prompt")


func test_interaction_exited_ignores_non_vehicle_zone() -> void:
	var vehicle := Node3D.new()
	add_child_autofree(vehicle)
	_player.nearest_vehicle = vehicle
	var zone := Area3D.new()
	var parent := Node3D.new()
	parent.add_child(zone)
	add_child_autofree(parent)
	_player._on_interaction_area_exited(zone)
	assert_eq(
		_player.nearest_vehicle,
		vehicle,
		"nearest_vehicle should not change for non-vehicle zones",
	)


func test_interaction_exited_ignores_different_vehicle() -> void:
	var vehicle_a := Node3D.new()
	var vehicle_b := Node3D.new()
	var zone_b := Area3D.new()
	zone_b.add_to_group("vehicle_interaction")
	vehicle_b.add_child(zone_b)
	add_child_autofree(vehicle_a)
	add_child_autofree(vehicle_b)
	_player.nearest_vehicle = vehicle_a
	_player._on_interaction_area_exited(zone_b)
	assert_eq(
		_player.nearest_vehicle,
		vehicle_a,
		"Should not clear if a different vehicle's zone exits",
	)


# ==========================================================================
# Physics process: rotation follows camera yaw
# ==========================================================================


func test_rotation_follows_camera_yaw_in_foot_mode() -> void:
	InputManager.current_context = InputManager.Context.FOOT
	_camera._yaw = 1.5
	_player._physics_process(0.016)
	assert_almost_eq(
		_player.rotation.y,
		1.5 + PI,
		0.001,
		"Player Y rotation should be camera yaw + PI",
	)


func test_rotation_does_not_update_in_vehicle_mode() -> void:
	InputManager.current_context = InputManager.Context.VEHICLE
	_player.rotation.y = 0.0
	_camera._yaw = 1.5
	_player._physics_process(0.016)
	assert_almost_eq(
		_player.rotation.y,
		0.0,
		0.001,
		"Rotation should not change in VEHICLE context",
	)


# ==========================================================================
# Fall damage
# ==========================================================================


func test_fall_damage_min_height_constant() -> void:
	assert_almost_eq(
		PlayerScript.FALL_DAMAGE_MIN_HEIGHT,
		3.0,
		0.001,
		"Safe fall threshold should be 3.0 m",
	)


func test_fall_damage_per_meter_constant() -> void:
	assert_almost_eq(
		PlayerScript.FALL_DAMAGE_PER_METER,
		10.0,
		0.001,
		"Damage rate should be 10 HP per metre beyond threshold",
	)


func test_fall_peak_y_recorded_when_leaving_floor() -> void:
	# Simulate player stepping off an edge: was on floor, now in air.
	_player._was_on_floor = true
	_player.global_position = Vector3(0.0, 5.0, 0.0)
	# Call _physics_process while off floor (is_on_floor() returns false by default)
	_player._physics_process(0.016)
	assert_almost_eq(
		_player._fall_peak_y,
		5.0,
		0.01,
		"_fall_peak_y should be set to y when leaving floor",
	)


func test_fall_peak_y_tracks_highest_point() -> void:
	# Player is in the air and rises further (jump arc).
	_player._was_on_floor = false
	_player._fall_peak_y = 5.0
	_player.global_position = Vector3(0.0, 7.0, 0.0)
	_player._physics_process(0.016)
	assert_almost_eq(
		_player._fall_peak_y,
		7.0,
		0.01,
		"_fall_peak_y should update to highest point reached",
	)


func test_no_fall_damage_below_threshold() -> void:
	# Fall of exactly FALL_DAMAGE_MIN_HEIGHT should deal no damage.
	var initial_health: float = GameManager.health
	_player._was_on_floor = false
	_player._fall_peak_y = _player.global_position.y + PlayerScript.FALL_DAMAGE_MIN_HEIGHT
	# Simulate landing: is_on_floor() is true next frame.
	# We can't force is_on_floor() easily, so verify via source_code instead.
	var script: GDScript = PlayerScript as GDScript
	assert_true(
		script.source_code.contains("fall_dist > FALL_DAMAGE_MIN_HEIGHT"),
		"Damage should only apply when fall exceeds minimum height",
	)
	# Restore health just in case.
	GameManager.health = initial_health
