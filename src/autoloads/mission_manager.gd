extends Node
## Manages mission lifecycle: generation, acceptance, tracking, completion.
## Missions are plain Dictionaries — no class_name.

const REFRESH_INTERVAL := 20.0
const MAX_AVAILABLE := 8
const SIDEWALK_OFFSET := 1.5

var _available_missions: Array[Dictionary] = []
var _active_mission: Dictionary = {}
var _refresh_timer := 0.0
var _mission_timer := 0.0
var _mission_counter: int = 0
var _player: Node3D = null
var _rng := RandomNumberGenerator.new()
var _grid = preload("res://src/road_grid.gd").new()
var _boundary = null  # lazy-cached city boundary


func _ready() -> void:
	_rng.randomize()
	EventBus.mission_marker_reached.connect(_on_marker_reached)
	EventBus.vehicle_entered.connect(_on_vehicle_entered)


func _process(delta: float) -> void:
	if not _player:
		_player = (get_tree().get_first_node_in_group("player") as Node3D)
		if not _player:
			return

	# Refresh available missions periodically
	_refresh_timer += delta
	if _refresh_timer >= REFRESH_INTERVAL:
		_refresh_timer = 0.0
		_refresh_available()

	# Initial missions
	if _available_missions.is_empty() and _active_mission.is_empty():
		_refresh_available()

	# Active mission timer
	if not _active_mission.is_empty():
		var tl: float = _active_mission.get("time_limit", 0.0)
		if tl > 0.0 and _active_mission.get("state") == "active":
			_mission_timer -= delta
			EventBus.mission_timer_updated.emit(_mission_timer)
			if _mission_timer <= 0.0:
				fail_mission("timeout")


func _refresh_available() -> void:
	if not _active_mission.is_empty():
		return
	if not _player:
		return

	# Remove old available missions and stale markers
	EventBus.missions_refreshed.emit()
	_available_missions.clear()

	var generators := [
		"_generate_delivery",
		"_generate_taxi",
		"_generate_theft",
	]

	for _i in range(MAX_AVAILABLE):
		var gen_name: String = generators[_rng.randi() % generators.size()]
		var mission: Dictionary = call(gen_name)
		if not mission.is_empty():
			_available_missions.append(mission)
			EventBus.mission_available.emit(mission)


func accept_mission(mission_id: String) -> void:
	var mission := _find_available(mission_id)
	if mission.is_empty():
		return

	var mtype: String = mission.get("type", "")

	# Taxi requires being in a vehicle
	if mtype == "taxi" and not InputManager.is_vehicle():
		return

	_active_mission = mission
	_available_missions.clear()

	if mtype == "theft":
		# Theft skips pickup — go straight to needing the vehicle
		_active_mission["state"] = "pickup"
		EventBus.mission_started.emit(mission_id)
		EventBus.mission_objective_updated.emit(_active_mission.get("objective", ""))
	elif mtype == "taxi":
		# Taxi: passenger is at start, skip to active
		_active_mission["state"] = "active"
		var tl: float = mission.get("time_limit", 0.0)
		if tl > 0.0:
			_mission_timer = tl
		EventBus.mission_started.emit(mission_id)
		EventBus.mission_objective_updated.emit("Drive the passenger to the destination")
	else:
		_active_mission["state"] = "pickup"
		EventBus.mission_started.emit(mission_id)
		EventBus.mission_objective_updated.emit("Go to the pickup location")


func complete_mission() -> void:
	if _active_mission.is_empty():
		return
	var mid: String = _active_mission.get("id", "")
	var reward: int = _active_mission.get("reward", 0)
	_active_mission["state"] = "completed"

	# Theft: remove the vehicle
	var delivered_vehicle = _active_mission.get("_delivered_vehicle", null)
	if delivered_vehicle and is_instance_valid(delivered_vehicle):
		# Force player out first, then free next frame
		EventBus.force_exit_vehicle.emit(delivered_vehicle)
		(delivered_vehicle as Node).call_deferred("queue_free")

	GameManager.add_money(reward)
	EventBus.mission_completed.emit(mid)
	EventBus.mission_objective_updated.emit("")
	_try_unlock_smg()
	_active_mission = {}
	_refresh_timer = 0.0


func fail_mission(_reason: String) -> void:
	if _active_mission.is_empty():
		return
	var mid: String = _active_mission.get("id", "")
	_active_mission["state"] = "failed"
	EventBus.mission_failed.emit(mid)
	EventBus.mission_objective_updated.emit("")
	_active_mission = {}
	_refresh_timer = 0.0


func get_active_mission() -> Dictionary:
	return _active_mission


func _on_marker_reached(
	mission_id: String,
	marker_type: String,
) -> void:
	# Start marker — accept the mission
	if marker_type == "start":
		if _active_mission.is_empty():
			accept_mission(mission_id)
		return

	# Only process markers for active mission
	if _active_mission.is_empty():
		return
	if _active_mission.get("id", "") != mission_id:
		return

	if marker_type == "pickup":
		_on_pickup_reached()
	elif marker_type == "dropoff":
		_on_dropoff_reached()


func _on_pickup_reached() -> void:
	_active_mission["state"] = "active"
	var tl: float = _active_mission.get("time_limit", 0.0)
	if tl > 0.0:
		_mission_timer = tl

	var mtype: String = _active_mission.get("type", "")
	var obj := "Complete the objective"
	if mtype == "delivery":
		obj = "Deliver the package"
	elif mtype == "taxi":
		obj = "Drive the passenger to the destination"
	EventBus.mission_objective_updated.emit(obj)


func _on_dropoff_reached() -> void:
	if _active_mission.get("state") != "active":
		return
	complete_mission()


func _on_vehicle_entered(vehicle: Node) -> void:
	if _active_mission.is_empty():
		return
	if _active_mission.get("type") != "theft":
		return
	if _active_mission.get("state") != "pickup":
		return

	# Check if vehicle variant matches
	var needed: String = _active_mission.get("vehicle_variant", "")
	var body := vehicle.get_node_or_null("Body") as Node3D
	if not body:
		return

	var variant_name := _identify_variant(body.scale)
	if variant_name == needed:
		_active_mission["state"] = "active"
		_active_mission["_delivered_vehicle"] = vehicle
		EventBus.mission_objective_updated.emit("Deliver the %s to the garage" % needed)


# --- Mission generators ---


func _generate_delivery() -> Dictionary:
	_mission_counter += 1
	var pp := _player.global_position
	var start := _gen_sidewalk_pos(pp, 40.0, 150.0)
	var pickup := _gen_sidewalk_pos(start, 40.0, 120.0)
	var dropoff := _gen_sidewalk_pos(pickup, 150.0, 400.0)
	var tl := _rng.randf_range(90.0, 150.0)
	var reward := _rng.randi_range(300, 800)
	return {
		"id": "delivery_%d" % _mission_counter,
		"type": "delivery",
		"title": "Express Delivery",
		"objective": "Pick up the package",
		"reward": reward,
		"time_limit": tl,
		"state": "available",
		"start_pos": start,
		"pickup_pos": pickup,
		"dropoff_pos": dropoff,
		"vehicle_variant": "",
	}


func _generate_taxi() -> Dictionary:
	_mission_counter += 1
	var pp := _player.global_position
	var start := _gen_sidewalk_pos(pp, 40.0, 150.0)
	var dropoff := _gen_sidewalk_pos(start, 100.0, 300.0)
	var tl := _rng.randf_range(60.0, 120.0)
	var reward := _rng.randi_range(200, 500)
	return {
		"id": "taxi_%d" % _mission_counter,
		"type": "taxi",
		"title": "Taxi Fare",
		"objective": "Pick up the passenger",
		"reward": reward,
		"time_limit": tl,
		"state": "available",
		"start_pos": start,
		"pickup_pos": start,
		"dropoff_pos": dropoff,
		"vehicle_variant": "",
	}


func _generate_theft() -> Dictionary:
	_mission_counter += 1
	var variants := [
		"sedan",
		"sports",
		"suv",
		"hatchback",
		"van",
		"pickup",
	]
	var variant: String = variants[_rng.randi() % variants.size()]
	var pp := _player.global_position
	var start := _gen_sidewalk_pos(pp, 40.0, 150.0)
	var dropoff := _gen_sidewalk_pos(start, 200.0, 400.0)
	var reward := _rng.randi_range(500, 1500)
	return {
		"id": "theft_%d" % _mission_counter,
		"type": "theft",
		"title": "Vehicle Theft",
		"objective": "Steal a %s and deliver it" % variant,
		"reward": reward,
		"time_limit": 0.0,
		"state": "available",
		"start_pos": start,
		"pickup_pos": Vector3.ZERO,
		"dropoff_pos": dropoff,
		"vehicle_variant": variant,
	}


# --- Helpers ---


func _get_boundary():
	if is_instance_valid(_boundary):
		return _boundary
	var city_nodes := get_tree().get_nodes_in_group("city_manager")
	if city_nodes.is_empty():
		return null
	_boundary = city_nodes[0].get_meta("city_boundary", null)
	return _boundary


func _gen_sidewalk_pos(
	near: Vector3,
	min_dist: float,
	max_dist: float,
) -> Vector3:
	for _attempt in range(10):
		var angle := _rng.randf() * TAU
		var dist := _rng.randf_range(min_dist, max_dist)
		var raw := near + Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
		# Snap to nearest sidewalk
		var is_ns := _rng.randi() % 2 == 0
		var road_idx := _grid.get_nearest_road_index(raw.x if is_ns else raw.z)
		var rc: float = _grid.get_road_center_near(road_idx, raw.x if is_ns else raw.z)
		var rw: float = _grid.get_road_width(road_idx)
		var sw := rc + rw * 0.5 + SIDEWALK_OFFSET
		var pos: Vector3
		if is_ns:
			pos = Vector3(sw, 0.15, raw.z)
		else:
			pos = Vector3(raw.x, 0.15, sw)
		var b = _get_boundary()
		if b and b.get_signed_distance(pos.x, pos.z) >= 0.0:
			continue
		return pos
	# Fallback: offset from near position at street level
	return Vector3(near.x + min_dist, 0.15, near.z)


func _find_available(mission_id: String) -> Dictionary:
	for m in _available_missions:
		if m.get("id") == mission_id:
			return m
	return {}


func _identify_variant(body_scale: Vector3) -> String:
	# Match against TrafficManager VARIANTS by body_scale
	var tm_variants := [
		["sedan", Vector3(1.0, 1.0, 1.0)],
		["sports", Vector3(1.05, 0.85, 1.05)],
		["suv", Vector3(1.1, 1.15, 1.05)],
		["hatchback", Vector3(0.95, 1.0, 0.88)],
		["van", Vector3(1.05, 1.3, 1.15)],
		["pickup", Vector3(1.1, 1.1, 1.2)],
	]
	var best_name := "sedan"
	var best_dist := INF
	for entry in tm_variants:
		var s: Vector3 = entry[1]
		var d := body_scale.distance_to(s)
		if d < best_dist:
			best_dist = d
			best_name = entry[0]
	return best_name


func _try_unlock_smg() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var weapon := players[0].get_node_or_null("PlayerWeapon")
	if weapon and weapon.has_method("unlock_weapon"):
		weapon.unlock_weapon(1)
