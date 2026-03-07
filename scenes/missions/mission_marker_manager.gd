extends Node
## Spawns and despawns mission marker instances based on EventBus signals.

const MARKER_COLORS := {
	"start": Color(0.2, 0.9, 0.2),
	"pickup": Color(0.3, 0.5, 1.0),
	"dropoff": Color(1.0, 0.9, 0.2),
}

var _marker_scene: PackedScene = preload(
	"res://scenes/missions/mission_marker.tscn"
)
var _markers: Dictionary = {}  # mission_id -> Array[Node3D]


func _ready() -> void:
	EventBus.missions_refreshed.connect(_on_missions_refreshed)
	EventBus.mission_available.connect(_on_mission_available)
	EventBus.mission_started.connect(_on_mission_started)
	EventBus.mission_completed.connect(_on_mission_done)
	EventBus.mission_failed.connect(_on_mission_done)
	EventBus.mission_marker_reached.connect(
		_on_marker_reached
	)
	EventBus.vehicle_entered.connect(_on_vehicle_entered)


func _on_missions_refreshed() -> void:
	var all_ids: Array[String] = []
	for mid: String in _markers:
		all_ids.append(mid)
	for mid in all_ids:
		_clear_markers(mid)


func _on_mission_available(mission_data: Dictionary) -> void:
	var mid: String = mission_data.get("id", "")
	if mid.is_empty():
		return
	var pos: Vector3 = mission_data.get(
		"start_pos", Vector3.ZERO
	)
	_spawn_marker(mid, "start", pos)


func _on_mission_started(mission_id: String) -> void:
	# Remove all available start markers
	var to_remove: Array[String] = []
	for mid: String in _markers:
		if mid != mission_id:
			to_remove.append(mid)
	for mid in to_remove:
		_clear_markers(mid)

	# Clear the start marker for the accepted mission
	_clear_markers(mission_id)

	# Spawn pickup/dropoff based on active mission data
	var mission := MissionManager.get_active_mission()
	if mission.is_empty():
		return

	var mtype: String = mission.get("type", "")
	if mtype == "theft":
		# Theft: no marker yet — dropoff spawns when vehicle entered
		pass
	elif mtype == "taxi":
		# Taxi: passenger at start, spawn dropoff immediately
		var dp: Vector3 = mission.get(
			"dropoff_pos", Vector3.ZERO
		)
		_spawn_marker(mission_id, "dropoff", dp)
	else:
		var pp: Vector3 = mission.get(
			"pickup_pos", Vector3.ZERO
		)
		_spawn_marker(mission_id, "pickup", pp)


func _on_vehicle_entered(_vehicle: Node) -> void:
	# Check if theft mission dropoff needs spawning
	var mission := MissionManager.get_active_mission()
	if mission.is_empty():
		return
	if mission.get("type") != "theft":
		return
	if mission.get("state") != "active":
		return
	var mid: String = mission.get("id", "")
	if _markers.has(mid):
		return  # already spawned
	var dp: Vector3 = mission.get("dropoff_pos", Vector3.ZERO)
	_spawn_marker(mid, "dropoff", dp)


func _on_marker_reached(
	mission_id: String, marker_type: String,
) -> void:
	if marker_type == "pickup":
		# Clear pickup marker, spawn dropoff
		_clear_markers(mission_id)
		spawn_dropoff_for_active()


func _on_mission_done(_mission_id: String) -> void:
	# Clear all markers
	var all_ids: Array[String] = []
	for mid: String in _markers:
		all_ids.append(mid)
	for mid in all_ids:
		_clear_markers(mid)


func _spawn_marker(
	mid: String, mtype: String, pos: Vector3,
) -> void:
	var marker: Node3D = _marker_scene.instantiate()
	marker.position = pos
	marker.set("mission_id", mid)
	marker.set("marker_type", mtype)
	get_tree().current_scene.add_child(marker)

	var color: Color = MARKER_COLORS.get(mtype, Color.WHITE)
	if marker.has_method("set_marker_color"):
		marker.set_marker_color(color)

	if not _markers.has(mid):
		_markers[mid] = []
	(_markers[mid] as Array).append(marker)


func _clear_markers(mid: String) -> void:
	if not _markers.has(mid):
		return
	var arr: Array = _markers[mid]
	for m in arr:
		if is_instance_valid(m):
			(m as Node).queue_free()
	_markers.erase(mid)


func spawn_dropoff_for_active() -> void:
	var mission := MissionManager.get_active_mission()
	if mission.is_empty():
		return
	var mid: String = mission.get("id", "")
	var dp: Vector3 = mission.get("dropoff_pos", Vector3.ZERO)
	_spawn_marker(mid, "dropoff", dp)
