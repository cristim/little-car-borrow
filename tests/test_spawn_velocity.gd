extends GutTest
## Verify that traffic and pedestrian managers read velocity from the driven
## vehicle (RigidBody3D.linear_velocity) instead of the stale
## CharacterBody3D.velocity while driving.
##
## The velocity logic is inline in _process(), so we verify the source code
## contains the vehicle-aware pattern (same approach as test_vehicle_health.gd).

const TrafficManagerScript = preload("res://scenes/world/traffic_manager.gd")
const PedestrianManagerScript = preload("res://scenes/world/pedestrian_manager.gd")


func test_traffic_manager_reads_current_vehicle() -> void:
	var src: String = TrafficManagerScript.source_code
	assert_true(
		src.contains('_player.get("current_vehicle")'),
		"traffic_manager should check _player.current_vehicle",
	)


func test_traffic_manager_reads_linear_velocity() -> void:
	var src: String = TrafficManagerScript.source_code
	assert_true(
		src.contains("linear_velocity"),
		"traffic_manager should read RigidBody3D.linear_velocity",
	)


func test_traffic_manager_checks_rigidbody3d() -> void:
	var src: String = TrafficManagerScript.source_code
	assert_true(
		src.contains("vehicle is RigidBody3D"),
		"traffic_manager should type-check vehicle as RigidBody3D",
	)


func test_pedestrian_manager_reads_current_vehicle() -> void:
	var src: String = PedestrianManagerScript.source_code
	assert_true(
		src.contains('_player.get("current_vehicle")'),
		"pedestrian_manager should check _player.current_vehicle",
	)


func test_pedestrian_manager_reads_linear_velocity() -> void:
	var src: String = PedestrianManagerScript.source_code
	assert_true(
		src.contains("linear_velocity"),
		"pedestrian_manager should read RigidBody3D.linear_velocity",
	)


func test_pedestrian_manager_checks_rigidbody3d() -> void:
	var src: String = PedestrianManagerScript.source_code
	assert_true(
		src.contains("vehicle is RigidBody3D"),
		"pedestrian_manager should type-check vehicle as RigidBody3D",
	)
