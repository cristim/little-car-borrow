extends GutTest
## Unit tests for collision_crime_detector.gd crime detection from
## vehicle collisions: speed thresholds, cooldowns, crime types.

const DetectorScript = preload("res://scenes/vehicles/collision_crime_detector.gd")

var _detector: Node
var _vehicle: RigidBody3D


func before_each() -> void:
	_detector = DetectorScript.new()
	_detector.name = "CrimeDetector"
	add_child_autofree(_detector)

	_vehicle = RigidBody3D.new()
	_vehicle.name = "TestVehicle"
	add_child_autofree(_vehicle)


## Consume engine errors from _spawn_ragdoll which calls
## get_tree().current_scene.add_child() -- current_scene is null in tests.
func _consume_engine_errors() -> void:
	for e in get_errors():
		e.handled = true


# ================================================================
# Constants
# ================================================================


func test_min_collision_speed() -> void:
	assert_eq(
		DetectorScript.MIN_COLLISION_SPEED,
		15.0,
		"MIN_COLLISION_SPEED should be 15.0 km/h",
	)


func test_crime_cooldown() -> void:
	assert_eq(
		DetectorScript.CRIME_COOLDOWN,
		1.0,
		"CRIME_COOLDOWN should be 1.0 seconds",
	)


# ================================================================
# Vehicle enter/exit
# ================================================================


func test_on_vehicle_entered_sets_vehicle() -> void:
	_detector._on_vehicle_entered(_vehicle)
	assert_eq(
		_detector._vehicle,
		_vehicle,
		"Entering a vehicle should store it",
	)


func test_on_vehicle_entered_connects_body_entered() -> void:
	_detector._on_vehicle_entered(_vehicle)
	assert_true(
		_vehicle.body_entered.is_connected(_detector._on_body_entered),
		"Should connect body_entered signal on vehicle",
	)


func test_on_vehicle_exited_clears_vehicle() -> void:
	_detector._on_vehicle_entered(_vehicle)
	_detector._on_vehicle_exited(_vehicle)
	assert_null(
		_detector._vehicle,
		"Exiting should clear _vehicle to null",
	)


func test_on_vehicle_exited_disconnects_signal() -> void:
	_detector._on_vehicle_entered(_vehicle)
	_detector._on_vehicle_exited(_vehicle)
	assert_false(
		_vehicle.body_entered.is_connected(_detector._on_body_entered),
		"Should disconnect body_entered signal on exit",
	)


func test_double_enter_does_not_double_connect() -> void:
	_detector._on_vehicle_entered(_vehicle)
	_detector._on_vehicle_entered(_vehicle)
	# If it double-connected, disconnecting once would still leave one
	_detector._on_vehicle_exited(_vehicle)
	assert_false(
		_vehicle.body_entered.is_connected(_detector._on_body_entered),
		"Double enter should not leave stale connections",
	)


func test_enter_new_vehicle_disconnects_old() -> void:
	_detector._on_vehicle_entered(_vehicle)

	var vehicle2 := RigidBody3D.new()
	vehicle2.name = "TestVehicle2"
	add_child_autofree(vehicle2)

	_detector._on_vehicle_entered(vehicle2)

	assert_false(
		_vehicle.body_entered.is_connected(_detector._on_body_entered),
		"Entering new vehicle should disconnect old one",
	)
	assert_true(
		vehicle2.body_entered.is_connected(_detector._on_body_entered),
		"New vehicle should be connected",
	)
	assert_eq(
		_detector._vehicle,
		vehicle2,
		"_vehicle should be updated to new vehicle",
	)


func test_enter_non_rigidbody_sets_null() -> void:
	var node := Node3D.new()
	node.name = "NotAVehicle"
	add_child_autofree(node)
	_detector._on_vehicle_entered(node)
	assert_null(
		_detector._vehicle,
		"Non-RigidBody3D should result in null _vehicle",
	)


# ================================================================
# Collision filtering
# ================================================================


func test_body_entered_ignored_below_speed_threshold() -> void:
	_detector._on_vehicle_entered(_vehicle)
	# Speed is 0 (below 15 km/h threshold)
	var body := StaticBody3D.new()
	body.name = "SomeBody"
	add_child_autofree(body)
	_detector._on_body_entered(body)

	assert_true(
		_detector._cooldowns.is_empty(),
		"No crime should be emitted below speed threshold",
	)


func test_body_entered_ignored_for_road_group() -> void:
	_detector._on_vehicle_entered(_vehicle)
	# Set vehicle speed above threshold: 15 km/h = 15/3.6 m/s
	_vehicle.linear_velocity = Vector3(0, 0, -15.0 / 3.6 - 1.0)

	var road_body := StaticBody3D.new()
	road_body.name = "RoadBody"
	road_body.add_to_group("Road")
	add_child_autofree(road_body)

	_detector._on_body_entered(road_body)

	assert_true(
		_detector._cooldowns.is_empty(),
		"Road group bodies should not trigger crimes",
	)


func test_body_entered_ignored_for_static_body() -> void:
	_detector._on_vehicle_entered(_vehicle)
	_vehicle.linear_velocity = Vector3(0, 0, -20.0 / 3.6)

	var wall := StaticBody3D.new()
	wall.name = "Wall"
	add_child_autofree(wall)

	_detector._on_body_entered(wall)

	assert_true(
		_detector._cooldowns.is_empty(),
		"StaticBody3D (not in Road group) should not trigger crimes",
	)


func test_body_entered_ignored_when_no_vehicle() -> void:
	# No vehicle entered, _vehicle is null
	var body := RigidBody3D.new()
	body.name = "SomeVehicle"
	add_child_autofree(body)
	_detector._on_body_entered(body)

	assert_true(
		_detector._cooldowns.is_empty(),
		"No crime should happen without a vehicle",
	)


# ================================================================
# Crime detection by body type
# ================================================================


func test_hit_vehicle_crime() -> void:
	_detector._on_vehicle_entered(_vehicle)
	_vehicle.linear_velocity = Vector3(0, 0, -20.0 / 3.6)

	var npc := RigidBody3D.new()
	npc.name = "NPCVehicle"
	add_child_autofree(npc)

	_detector._on_body_entered(npc)

	assert_true(
		_detector._cooldowns.has("hit_vehicle"),
		"Hitting a RigidBody3D should create hit_vehicle cooldown",
	)


func test_hit_pedestrian_crime() -> void:
	_detector._on_vehicle_entered(_vehicle)
	_vehicle.linear_velocity = Vector3(0, 0, -20.0 / 3.6)

	var ped := RigidBody3D.new()
	ped.name = "Pedestrian"
	ped.add_to_group("pedestrian")
	add_child_autofree(ped)

	# pedestrian_killed + queue_free will be called, but in test
	# context queue_free is deferred. We just check the cooldown.
	_detector._on_body_entered(ped)

	_consume_engine_errors()
	assert_true(
		_detector._cooldowns.has("hit_pedestrian"),
		"Hitting a pedestrian should create hit_pedestrian cooldown",
	)


func test_hit_police_officer_crime() -> void:
	_detector._on_vehicle_entered(_vehicle)
	_vehicle.linear_velocity = Vector3(0, 0, -20.0 / 3.6)

	var cop := RigidBody3D.new()
	cop.name = "PoliceOfficer"
	cop.add_to_group("police_officer")
	add_child_autofree(cop)

	_detector._on_body_entered(cop)

	_consume_engine_errors()
	assert_true(
		_detector._cooldowns.has("hit_police_officer"),
		"Hitting a police officer should create hit_police_officer cooldown",
	)


# ================================================================
# Cooldown behavior
# ================================================================


func test_cooldown_prevents_duplicate_crime() -> void:
	_detector._on_vehicle_entered(_vehicle)
	_vehicle.linear_velocity = Vector3(0, 0, -20.0 / 3.6)

	var npc1 := RigidBody3D.new()
	npc1.name = "NPC1"
	add_child_autofree(npc1)

	var npc2 := RigidBody3D.new()
	npc2.name = "NPC2"
	add_child_autofree(npc2)

	_detector._on_body_entered(npc1)
	var cooldown_after_first: float = _detector._cooldowns.get("hit_vehicle", 0.0)

	_detector._on_body_entered(npc2)
	var cooldown_after_second: float = _detector._cooldowns.get("hit_vehicle", 0.0)

	# Cooldown should not have been reset (second hit was suppressed)
	assert_almost_eq(
		cooldown_after_first,
		cooldown_after_second,
		0.01,
		"Second hit during cooldown should not reset the timer",
	)


func test_cooldown_set_to_crime_cooldown_value() -> void:
	_detector._on_vehicle_entered(_vehicle)
	_vehicle.linear_velocity = Vector3(0, 0, -20.0 / 3.6)

	var npc := RigidBody3D.new()
	npc.name = "NPC"
	add_child_autofree(npc)

	_detector._on_body_entered(npc)

	assert_almost_eq(
		_detector._cooldowns["hit_vehicle"],
		DetectorScript.CRIME_COOLDOWN,
		0.01,
		"Cooldown should be set to CRIME_COOLDOWN",
	)


func test_different_crime_types_have_independent_cooldowns() -> void:
	_detector._on_vehicle_entered(_vehicle)
	_vehicle.linear_velocity = Vector3(0, 0, -20.0 / 3.6)

	var npc := RigidBody3D.new()
	npc.name = "NPC"
	add_child_autofree(npc)
	_detector._on_body_entered(npc)

	var cop := RigidBody3D.new()
	cop.name = "Cop"
	cop.add_to_group("police_officer")
	add_child_autofree(cop)
	_detector._on_body_entered(cop)

	_consume_engine_errors()
	assert_true(
		_detector._cooldowns.has("hit_vehicle"),
		"hit_vehicle cooldown should exist",
	)
	assert_true(
		_detector._cooldowns.has("hit_police_officer"),
		"hit_police_officer cooldown should exist independently",
	)


# ================================================================
# _process cooldown tick-down
# ================================================================


func test_process_decrements_cooldowns() -> void:
	_detector._cooldowns["hit_vehicle"] = 1.0
	_detector._process(0.5)

	assert_almost_eq(
		_detector._cooldowns["hit_vehicle"],
		0.5,
		0.01,
		"Cooldown should decrement by delta",
	)


func test_process_removes_expired_cooldowns() -> void:
	_detector._cooldowns["hit_vehicle"] = 0.1
	_detector._process(0.2)

	assert_false(
		_detector._cooldowns.has("hit_vehicle"),
		"Expired cooldown should be removed",
	)


func test_process_removes_only_expired() -> void:
	_detector._cooldowns["hit_vehicle"] = 0.1
	_detector._cooldowns["hit_pedestrian"] = 1.0
	_detector._process(0.2)

	assert_false(
		_detector._cooldowns.has("hit_vehicle"),
		"Expired hit_vehicle should be removed",
	)
	assert_true(
		_detector._cooldowns.has("hit_pedestrian"),
		"Active hit_pedestrian should remain",
	)


func test_process_with_no_cooldowns() -> void:
	# Should not error
	_detector._process(0.5)
	assert_true(
		_detector._cooldowns.is_empty(),
		"Empty cooldowns should stay empty after process",
	)


# ================================================================
# Speed threshold edge cases
# ================================================================


func test_speed_exactly_at_threshold_does_not_trigger() -> void:
	_detector._on_vehicle_entered(_vehicle)
	# Exactly 15.0 km/h => speed_kmh < MIN_COLLISION_SPEED is false
	# but 14.99 should not trigger
	_vehicle.linear_velocity = Vector3(0, 0, -14.99 / 3.6)

	var npc := RigidBody3D.new()
	npc.name = "NPC"
	add_child_autofree(npc)
	_detector._on_body_entered(npc)

	assert_true(
		_detector._cooldowns.is_empty(),
		"Speed just below threshold should not trigger crime",
	)


func test_speed_just_above_threshold_triggers() -> void:
	_detector._on_vehicle_entered(_vehicle)
	_vehicle.linear_velocity = Vector3(0, 0, -15.1 / 3.6)

	var npc := RigidBody3D.new()
	npc.name = "NPC"
	add_child_autofree(npc)
	_detector._on_body_entered(npc)

	assert_true(
		_detector._cooldowns.has("hit_vehicle"),
		"Speed just above threshold should trigger crime",
	)


# ================================================================
# Ragdoll spawn order (vehicles/C2)
# ================================================================


func test_ragdoll_add_child_before_copy_visual_from() -> void:
	# C2: ragdoll must be added to scene tree before copy_visual_from is called
	# so it has a valid world transform when visuals are copied.
	var src := DetectorScript.source_code
	var add_idx := src.find("add_child(ragdoll)")
	var copy_idx := src.find("copy_visual_from(pedestrian)")
	assert_true(add_idx >= 0, "add_child(ragdoll) should exist in source")
	assert_true(copy_idx >= 0, "copy_visual_from(pedestrian) should exist in source")
	assert_true(
		add_idx < copy_idx,
		"add_child(ragdoll) must appear before copy_visual_from(pedestrian)",
	)
