extends GutTest
## Tests for the Pedestrian CharacterBody3D (scenes/pedestrians/pedestrian.gd).

const PedestrianScript = preload("res://scenes/pedestrians/pedestrian.gd")
const StateScript = preload("res://src/state_machine/state.gd")
const StateMachineScript = preload("res://src/state_machine/state_machine.gd")


class MockState:
	extends "res://src/state_machine/state.gd"
	var entered := false
	var last_msg: Dictionary = {}

	func enter(msg: Dictionary = {}) -> void:
		entered = true
		last_msg = msg


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _make_pedestrian_with_sm() -> CharacterBody3D:
	var ped := CharacterBody3D.new()
	ped.set_script(PedestrianScript)

	var sm := Node.new()
	sm.set_script(StateMachineScript)
	sm.name = "StateMachine"

	var walk := MockState.new()
	walk.name = "PedestrianWalk"
	sm.add_child(walk)

	var flee := MockState.new()
	flee.name = "PedestrianFlee"
	sm.add_child(flee)

	sm.initial_state = walk
	ped.add_child(sm)
	return ped


func _make_pedestrian_bare() -> CharacterBody3D:
	var ped := CharacterBody3D.new()
	ped.set_script(PedestrianScript)
	return ped


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

func test_flee_vehicle_speed_constant() -> void:
	assert_eq(PedestrianScript.FLEE_VEHICLE_SPEED, 5.0)


func test_lod_mid_dist_constant() -> void:
	assert_eq(PedestrianScript.LOD_MID_DIST, 40.0)


func test_lod_far_dist_constant() -> void:
	assert_eq(PedestrianScript.LOD_FAR_DIST, 70.0)


# ---------------------------------------------------------------------------
# _ready
# ---------------------------------------------------------------------------

func test_ready_adds_to_pedestrian_group() -> void:
	var ped := _make_pedestrian_bare()
	add_child_autofree(ped)
	await get_tree().process_frame

	assert_true(ped.is_in_group("pedestrian"))


func test_ready_without_proximity_area_does_not_crash() -> void:
	var ped := _make_pedestrian_bare()
	add_child_autofree(ped)
	await get_tree().process_frame

	# Should complete _ready without error
	assert_true(ped.is_in_group("pedestrian"))


func test_ready_connects_proximity_area_signal() -> void:
	var ped := _make_pedestrian_bare()
	var area := Area3D.new()
	area.name = "ProximityArea"
	ped.add_child(area)
	add_child_autofree(ped)
	await get_tree().process_frame

	assert_true(area.body_entered.is_connected(ped._on_proximity_body_entered))


# ---------------------------------------------------------------------------
# _on_proximity_body_entered
# ---------------------------------------------------------------------------

func test_proximity_ignores_non_rigidbody() -> void:
	var ped := _make_pedestrian_with_sm()
	add_child_autofree(ped)
	await get_tree().process_frame

	var body := CharacterBody3D.new()
	add_child_autofree(body)

	ped._on_proximity_body_entered(body)

	# Flee state should NOT be entered
	var sm := ped.get_node("StateMachine")
	var flee := sm.get_node("PedestrianFlee") as MockState
	assert_false(flee.entered)


func test_proximity_ignores_slow_rigidbody() -> void:
	var ped := _make_pedestrian_with_sm()
	add_child_autofree(ped)
	await get_tree().process_frame

	var rb := RigidBody3D.new()
	add_child_autofree(rb)
	# Speed 0 km/h < FLEE_VEHICLE_SPEED (5.0)
	rb.linear_velocity = Vector3.ZERO

	ped._on_proximity_body_entered(rb)

	var sm := ped.get_node("StateMachine")
	var flee := sm.get_node("PedestrianFlee") as MockState
	assert_false(flee.entered)


func test_proximity_triggers_flee_for_fast_rigidbody() -> void:
	var ped := _make_pedestrian_with_sm()
	add_child_autofree(ped)
	await get_tree().process_frame

	var rb := RigidBody3D.new()
	add_child_autofree(rb)
	# 10 m/s = 36 km/h, well above FLEE_VEHICLE_SPEED (5.0 km/h)
	rb.linear_velocity = Vector3(10.0, 0.0, 0.0)

	ped._on_proximity_body_entered(rb)

	var sm := ped.get_node("StateMachine")
	var flee := sm.get_node("PedestrianFlee") as MockState
	assert_true(flee.entered, "Flee state should be entered for fast vehicle")
	assert_true(
		flee.last_msg.has("threat_pos"),
		"Message should include threat_pos",
	)


func test_proximity_does_not_flee_when_already_fleeing() -> void:
	var ped := _make_pedestrian_with_sm()
	add_child_autofree(ped)
	await get_tree().process_frame

	# First: transition to flee manually
	var sm := ped.get_node("StateMachine")
	sm.transition_to("PedestrianFlee", {"threat_pos": Vector3.ZERO})

	var flee := sm.get_node("PedestrianFlee") as MockState
	flee.entered = false  # Reset tracking

	# Second proximity trigger while already in flee
	var rb := RigidBody3D.new()
	add_child_autofree(rb)
	rb.linear_velocity = Vector3(10.0, 0.0, 0.0)

	ped._on_proximity_body_entered(rb)

	# Should not re-enter flee (already fleeing)
	assert_false(flee.entered, "Should not re-enter flee when already fleeing")


func test_proximity_speed_threshold_boundary() -> void:
	var ped := _make_pedestrian_with_sm()
	add_child_autofree(ped)
	await get_tree().process_frame

	var rb := RigidBody3D.new()
	add_child_autofree(rb)
	# Exactly at threshold: 5.0 km/h = 5.0/3.6 m/s ~ 1.389 m/s
	# speed_kmh < FLEE_VEHICLE_SPEED means exactly 5.0 should NOT trigger
	rb.linear_velocity = Vector3(5.0 / 3.6, 0.0, 0.0)

	ped._on_proximity_body_entered(rb)

	var sm := ped.get_node("StateMachine")
	var flee := sm.get_node("PedestrianFlee") as MockState
	assert_false(flee.entered, "Exactly at threshold should not trigger flee")


func test_proximity_just_above_threshold_triggers() -> void:
	var ped := _make_pedestrian_with_sm()
	add_child_autofree(ped)
	await get_tree().process_frame

	var rb := RigidBody3D.new()
	add_child_autofree(rb)
	# Just above: 5.1 km/h = 5.1/3.6 m/s
	rb.linear_velocity = Vector3(5.1 / 3.6, 0.0, 0.0)

	ped._on_proximity_body_entered(rb)

	var sm := ped.get_node("StateMachine")
	var flee := sm.get_node("PedestrianFlee") as MockState
	assert_true(flee.entered, "Just above threshold should trigger flee")


# ---------------------------------------------------------------------------
# _physics_process — frame counter
# ---------------------------------------------------------------------------

func test_frame_counter_increments() -> void:
	var ped := _make_pedestrian_bare()
	add_child_autofree(ped)
	await get_tree().process_frame

	var initial: int = ped._frame_counter
	# Wait a few physics frames
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_gt(ped._frame_counter, initial, "Frame counter should increment")


# ---------------------------------------------------------------------------
# _physics_process — no state machine does not crash
# ---------------------------------------------------------------------------

func test_physics_process_without_sm_does_not_crash() -> void:
	var ped := _make_pedestrian_bare()
	add_child_autofree(ped)
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame

	# Should survive without crashing
	assert_true(ped.is_in_group("pedestrian"))
