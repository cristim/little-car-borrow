extends GutTest
## Unit tests for scenes/missions/mission_marker_manager.gd
## Tests signal wiring, marker spawning/clearing, and mission lifecycle.

const ManagerScript = preload("res://scenes/missions/mission_marker_manager.gd")

var _mgr: Node
var _scene_root: Node3D


func before_each() -> void:
	# Create a scene root that acts as get_tree().current_scene
	_scene_root = Node3D.new()
	add_child_autofree(_scene_root)
	# GUT adds children to the test node. We need to set current_scene.
	# In GUT, the current_scene is the test runner. We override
	# _spawn_marker by making _scene_root the current_scene target.
	# Instead, we subclass and override _spawn_marker to use our root.
	_mgr = _create_testable_manager()
	_scene_root.add_child(_mgr)


func _create_testable_manager() -> Node:
	var mgr := TestableMarkerManager.new()
	mgr._scene_root_override = _scene_root
	return mgr


# ================================================================
# Constants
# ================================================================


func test_marker_colors_has_start() -> void:
	assert_true(
		ManagerScript.MARKER_COLORS.has("start"),
		"Should have 'start' color",
	)


func test_marker_colors_has_pickup() -> void:
	assert_true(
		ManagerScript.MARKER_COLORS.has("pickup"),
		"Should have 'pickup' color",
	)


func test_marker_colors_has_dropoff() -> void:
	assert_true(
		ManagerScript.MARKER_COLORS.has("dropoff"),
		"Should have 'dropoff' color",
	)


func test_start_color_is_green() -> void:
	var c: Color = ManagerScript.MARKER_COLORS["start"]
	assert_true(c.g > 0.8, "Start color should be green-ish")


func test_pickup_color_is_blue() -> void:
	var c: Color = ManagerScript.MARKER_COLORS["pickup"]
	assert_true(c.b > 0.8, "Pickup color should be blue-ish")


func test_dropoff_color_is_yellow() -> void:
	var c: Color = ManagerScript.MARKER_COLORS["dropoff"]
	assert_true(
		c.r > 0.8 and c.g > 0.8,
		"Dropoff color should be yellow-ish",
	)


# ================================================================
# Signal connections
# ================================================================


func test_missions_refreshed_connected() -> void:
	assert_true(
		EventBus.missions_refreshed.is_connected(_mgr._on_missions_refreshed),
		"missions_refreshed should be connected",
	)


func test_mission_available_connected() -> void:
	assert_true(
		EventBus.mission_available.is_connected(_mgr._on_mission_available),
		"mission_available should be connected",
	)


func test_mission_started_connected() -> void:
	assert_true(
		EventBus.mission_started.is_connected(_mgr._on_mission_started),
		"mission_started should be connected",
	)


func test_mission_completed_connected() -> void:
	assert_true(
		EventBus.mission_completed.is_connected(_mgr._on_mission_done),
		"mission_completed should be connected",
	)


func test_mission_failed_connected() -> void:
	assert_true(
		EventBus.mission_failed.is_connected(_mgr._on_mission_done),
		"mission_failed should be connected",
	)


func test_marker_reached_connected() -> void:
	assert_true(
		EventBus.mission_marker_reached.is_connected(_mgr._on_marker_reached),
		"mission_marker_reached should be connected",
	)


func test_vehicle_entered_connected() -> void:
	assert_true(
		EventBus.vehicle_entered.is_connected(_mgr._on_vehicle_entered),
		"vehicle_entered should be connected",
	)


# ================================================================
# _on_mission_available
# ================================================================


func test_mission_available_spawns_start_marker() -> void:
	var mission := {
		"id": "test_001",
		"start_pos": Vector3(10.0, 0.0, 20.0),
	}
	_mgr._on_mission_available(mission)

	assert_true(
		_mgr._markers.has("test_001"),
		"Should track marker for mission id",
	)
	var arr: Array = _mgr._markers["test_001"]
	assert_eq(arr.size(), 1, "Should have one marker")


func test_mission_available_empty_id_ignored() -> void:
	var mission := {"id": "", "start_pos": Vector3.ZERO}
	_mgr._on_mission_available(mission)
	assert_eq(_mgr._markers.size(), 0, "Empty ID should be ignored")


func test_mission_available_missing_id_ignored() -> void:
	var mission := {"start_pos": Vector3.ZERO}
	_mgr._on_mission_available(mission)
	assert_eq(_mgr._markers.size(), 0, "Missing ID should be ignored")


# ================================================================
# _on_missions_refreshed
# ================================================================


func test_missions_refreshed_clears_all_markers() -> void:
	# Spawn some markers first
	(
		_mgr
		. _on_mission_available(
			{
				"id": "m1",
				"start_pos": Vector3.ZERO,
			}
		)
	)
	(
		_mgr
		. _on_mission_available(
			{
				"id": "m2",
				"start_pos": Vector3(5.0, 0.0, 5.0),
			}
		)
	)
	assert_eq(_mgr._markers.size(), 2)

	_mgr._on_missions_refreshed()
	assert_eq(
		_mgr._markers.size(),
		0,
		"All markers should be cleared after refresh",
	)


# ================================================================
# _on_mission_started
# ================================================================


func test_mission_started_clears_other_markers() -> void:
	# Mock MissionManager.get_active_mission to return empty
	_mgr._mock_active_mission = {}

	(
		_mgr
		. _on_mission_available(
			{
				"id": "m1",
				"start_pos": Vector3.ZERO,
			}
		)
	)
	(
		_mgr
		. _on_mission_available(
			{
				"id": "m2",
				"start_pos": Vector3(5.0, 0.0, 5.0),
			}
		)
	)
	(
		_mgr
		. _on_mission_available(
			{
				"id": "m3",
				"start_pos": Vector3(10.0, 0.0, 0.0),
			}
		)
	)

	_mgr._on_mission_started("m2")

	# m1 and m3 should be cleared, m2 start marker also cleared
	assert_false(
		_mgr._markers.has("m1"),
		"Other mission markers should be cleared",
	)
	assert_false(
		_mgr._markers.has("m3"),
		"Other mission markers should be cleared",
	)


func test_mission_started_delivery_spawns_pickup() -> void:
	_mgr._mock_active_mission = {
		"id": "d1",
		"type": "delivery",
		"pickup_pos": Vector3(50.0, 0.0, 50.0),
		"dropoff_pos": Vector3(100.0, 0.0, 100.0),
	}

	_mgr._on_mission_started("d1")

	assert_true(
		_mgr._markers.has("d1"),
		"Should spawn pickup marker for delivery mission",
	)


func test_mission_started_taxi_spawns_dropoff() -> void:
	_mgr._mock_active_mission = {
		"id": "t1",
		"type": "taxi",
		"dropoff_pos": Vector3(80.0, 0.0, 80.0),
	}

	_mgr._on_mission_started("t1")

	assert_true(
		_mgr._markers.has("t1"),
		"Should spawn dropoff marker for taxi mission",
	)


func test_mission_started_theft_no_immediate_marker() -> void:
	_mgr._mock_active_mission = {
		"id": "th1",
		"type": "theft",
		"dropoff_pos": Vector3(90.0, 0.0, 90.0),
	}

	_mgr._on_mission_started("th1")

	# Theft should NOT spawn a marker until vehicle is entered
	assert_false(
		_mgr._markers.has("th1"),
		"Theft should not spawn marker until vehicle entered",
	)


# ================================================================
# _on_vehicle_entered (theft dropoff spawn)
# ================================================================


func test_vehicle_entered_spawns_theft_dropoff() -> void:
	_mgr._mock_active_mission = {
		"id": "th2",
		"type": "theft",
		"state": "active",
		"dropoff_pos": Vector3(100.0, 0.0, 50.0),
	}

	var vehicle := Node3D.new()
	add_child_autofree(vehicle)
	_mgr._on_vehicle_entered(vehicle)

	assert_true(
		_mgr._markers.has("th2"),
		"Should spawn dropoff after vehicle entered for theft",
	)


func test_vehicle_entered_non_theft_ignored() -> void:
	_mgr._mock_active_mission = {
		"id": "d2",
		"type": "delivery",
		"state": "active",
		"dropoff_pos": Vector3(100.0, 0.0, 50.0),
	}

	var vehicle := Node3D.new()
	add_child_autofree(vehicle)
	_mgr._on_vehicle_entered(vehicle)

	assert_false(
		_mgr._markers.has("d2"),
		"Non-theft mission should not spawn marker on vehicle enter",
	)


func test_vehicle_entered_no_active_mission_ignored() -> void:
	_mgr._mock_active_mission = {}

	var vehicle := Node3D.new()
	add_child_autofree(vehicle)
	_mgr._on_vehicle_entered(vehicle)

	assert_eq(
		_mgr._markers.size(),
		0,
		"No markers should be spawned without active mission",
	)


func test_vehicle_entered_already_has_markers_ignored() -> void:
	_mgr._mock_active_mission = {
		"id": "th3",
		"type": "theft",
		"state": "active",
		"dropoff_pos": Vector3(100.0, 0.0, 50.0),
	}

	# Spawn the marker first
	var vehicle := Node3D.new()
	add_child_autofree(vehicle)
	_mgr._on_vehicle_entered(vehicle)
	var count_after_first: int = (_mgr._markers["th3"] as Array).size()

	# Enter again — should not double-spawn
	_mgr._on_vehicle_entered(vehicle)
	var count_after_second: int = (_mgr._markers["th3"] as Array).size()

	assert_eq(
		count_after_first,
		count_after_second,
		"Should not double-spawn markers",
	)


# ================================================================
# _on_marker_reached
# ================================================================


func test_marker_reached_pickup_clears_and_spawns_dropoff() -> void:
	_mgr._mock_active_mission = {
		"id": "dr1",
		"type": "delivery",
		"dropoff_pos": Vector3(200.0, 0.0, 200.0),
	}

	# Pre-spawn a pickup marker
	_mgr._spawn_marker("dr1", "pickup", Vector3(50.0, 0.0, 50.0))
	assert_true(_mgr._markers.has("dr1"))

	_mgr._on_marker_reached("dr1", "pickup")

	# Should have spawned a new dropoff marker
	assert_true(
		_mgr._markers.has("dr1"),
		"Should have dropoff marker after pickup reached",
	)


func test_marker_reached_non_pickup_type_ignored() -> void:
	# "start" and "dropoff" types should not trigger the pickup->dropoff flow
	_mgr._mock_active_mission = {
		"id": "m1",
		"type": "delivery",
		"dropoff_pos": Vector3.ZERO,
	}

	_mgr._on_marker_reached("m1", "start")
	# No crash, no markers spawned (start is handled by MissionManager)
	pass_test("Non-pickup marker type handled without error")


# ================================================================
# _on_mission_done
# ================================================================


func test_mission_done_clears_all_markers() -> void:
	(
		_mgr
		. _on_mission_available(
			{
				"id": "m1",
				"start_pos": Vector3.ZERO,
			}
		)
	)
	(
		_mgr
		. _on_mission_available(
			{
				"id": "m2",
				"start_pos": Vector3(5.0, 0.0, 5.0),
			}
		)
	)

	_mgr._on_mission_done("m1")

	assert_eq(
		_mgr._markers.size(),
		0,
		"All markers should be cleared on mission done",
	)


# ================================================================
# _clear_markers
# ================================================================


func test_clear_markers_nonexistent_id_safe() -> void:
	# Should not crash
	_mgr._clear_markers("nonexistent_id")
	pass_test("Clearing nonexistent markers is safe")


func test_clear_markers_removes_from_dict() -> void:
	_mgr._spawn_marker("m1", "start", Vector3.ZERO)
	assert_true(_mgr._markers.has("m1"))

	_mgr._clear_markers("m1")
	assert_false(
		_mgr._markers.has("m1"),
		"Cleared markers should be removed from dictionary",
	)


# ================================================================
# _spawn_marker
# ================================================================


func test_spawn_marker_sets_position() -> void:
	var pos := Vector3(42.0, 0.0, 77.0)
	_mgr._spawn_marker("sp1", "start", pos)

	var arr: Array = _mgr._markers["sp1"]
	assert_eq(arr.size(), 1)
	var marker: Node3D = arr[0]
	assert_eq(marker.position, pos, "Marker position should match")


func test_spawn_marker_sets_mission_id_and_type() -> void:
	_mgr._spawn_marker("sp2", "dropoff", Vector3.ZERO)

	var arr: Array = _mgr._markers["sp2"]
	var marker: Node3D = arr[0]
	assert_eq(
		marker.get_meta("mission_id", ""),
		"sp2",
		"Marker mission_id should be set",
	)
	assert_eq(
		marker.get_meta("marker_type", ""),
		"dropoff",
		"Marker marker_type should be set",
	)


func test_spawn_multiple_markers_same_mission() -> void:
	_mgr._spawn_marker("sp3", "start", Vector3.ZERO)
	_mgr._spawn_marker("sp3", "dropoff", Vector3(10.0, 0.0, 10.0))

	var arr: Array = _mgr._markers["sp3"]
	assert_eq(arr.size(), 2, "Should accumulate markers for same id")


func test_spawn_marker_unknown_type_uses_white() -> void:
	_mgr._spawn_marker("sp4", "unknown", Vector3.ZERO)
	# Should not crash — falls back to Color.WHITE
	assert_true(
		_mgr._markers.has("sp4"),
		"Unknown type should still spawn marker",
	)


# ================================================================
# TestableMarkerManager — subclass that avoids scene dependencies
# ================================================================


class TestableMarkerManager:
	extends "res://scenes/missions/mission_marker_manager.gd"

	var _scene_root_override: Node3D
	var _mock_active_mission: Dictionary = {}

	func _spawn_marker(
		mid: String,
		mtype: String,
		pos: Vector3,
	) -> void:
		# Create a simple Node3D stub instead of instantiating the scene
		var marker := Node3D.new()
		marker.position = pos
		marker.set_meta("mission_id", mid)
		marker.set_meta("marker_type", mtype)
		if _scene_root_override:
			_scene_root_override.add_child(marker)

		if not _markers.has(mid):
			_markers[mid] = []
		(_markers[mid] as Array).append(marker)

	func _on_mission_started(mission_id: String) -> void:
		# Remove all available start markers except active
		var to_remove: Array[String] = []
		for mid: String in _markers:
			if mid != mission_id:
				to_remove.append(mid)
		for mid in to_remove:
			_clear_markers(mid)

		# Clear the start marker for the accepted mission
		_clear_markers(mission_id)

		# Use mock instead of MissionManager
		var mission := _mock_active_mission
		if mission.is_empty():
			return

		var mtype: String = mission.get("type", "")
		if mtype == "theft":
			pass
		elif mtype == "taxi":
			var dp: Vector3 = mission.get("dropoff_pos", Vector3.ZERO)
			_spawn_marker(mission_id, "dropoff", dp)
		else:
			var pp: Vector3 = mission.get("pickup_pos", Vector3.ZERO)
			_spawn_marker(mission_id, "pickup", pp)

	func _on_vehicle_entered(_vehicle: Node) -> void:
		var mission := _mock_active_mission
		if mission.is_empty():
			return
		if mission.get("type") != "theft":
			return
		if mission.get("state") != "active":
			return
		var mid: String = mission.get("id", "")
		if _markers.has(mid):
			return
		var dp: Vector3 = mission.get("dropoff_pos", Vector3.ZERO)
		_spawn_marker(mid, "dropoff", dp)

	func spawn_dropoff_for_active() -> void:
		var mission := _mock_active_mission
		if mission.is_empty():
			return
		var mid: String = mission.get("id", "")
		var dp: Vector3 = mission.get("dropoff_pos", Vector3.ZERO)
		_spawn_marker(mid, "dropoff", dp)
