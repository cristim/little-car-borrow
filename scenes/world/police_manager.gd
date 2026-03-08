extends Node
## Spawns and despawns police vehicles based on wanted level.
## Follows TrafficManager pattern: spawn on roads near player.

const SPAWN_RADIUS := 180.0
const DESPAWN_RADIUS := 250.0
const MIN_SPAWN_DIST := 40.0
const MIN_VEHICLE_DIST := 20.0
const SPAWN_INTERVAL := 1.0
const DESPAWN_FADE_TIME := 10.0
const LOD_FREEZE_DIST := 140.0

var _grid = preload("res://src/road_grid.gd").new()
var _police_scene: PackedScene = preload("res://scenes/vehicles/police_vehicle.tscn")
var _ai_script: GDScript = preload("res://scenes/vehicles/police_ai_controller.gd")
var _vehicle_health_script: GDScript = preload(
	"res://scenes/vehicles/vehicle_health.gd"
)
var _vehicle_lights_script: GDScript = preload(
	"res://scenes/vehicles/vehicle_lights.gd"
)

var _police: Array[Node] = []
var _player: Node3D = null
var _rng := RandomNumberGenerator.new()
var _spawn_timer := 0.0
var _despawn_timer := 0.0
var _despawning := false
var _helicopter: CharacterBody3D = null
var _heli_script: GDScript = preload(
	"res://scenes/vehicles/helicopter_ai.gd"
)


func _ready() -> void:
	_rng.randomize()
	EventBus.wanted_level_changed.connect(_on_wanted_level_changed)


func _process(delta: float) -> void:
	if not _player:
		_player = get_tree().get_first_node_in_group("player") as Node3D
		if not _player:
			return

	# Clean stale helicopter reference
	if _helicopter and not is_instance_valid(_helicopter):
		_helicopter = null

	var max_police := _get_max_police()

	if _despawning:
		_despawn_timer += delta
		if _despawn_timer >= DESPAWN_FADE_TIME or _police.is_empty():
			_despawning = false
		else:
			_despawn_one()
		return

	_despawn_far()

	if max_police <= 0:
		return

	var level := WantedLevelManager.wanted_level
	# Spawn faster at higher wanted levels
	var interval := SPAWN_INTERVAL
	if level >= 4:
		interval = 0.3
	elif level >= 3:
		interval = 0.5
	elif level >= 2:
		interval = 0.7

	_spawn_timer += delta
	if _spawn_timer >= interval:
		_spawn_timer = 0.0
		var deficit := max_police - _police.size()
		var spawns := 1
		if deficit > 4:
			spawns = 3
		elif deficit > 2:
			spawns = 2
		for _i in range(spawns):
			if _police.size() < max_police:
				_try_spawn()


func _get_max_police() -> int:
	var level := WantedLevelManager.wanted_level
	# L0=0, L1=3, L2=5, L3=8, L4=12, L5=16
	var caps := [0, 3, 5, 8, 12, 16]
	if level < 0 or level >= caps.size():
		return 0
	return caps[level]


func _on_wanted_level_changed(level: int) -> void:
	if level <= 0 and not _police.is_empty():
		_despawning = true
		_despawn_timer = 0.0
	else:
		_despawning = false

	# Helicopter management (clean stale ref first)
	if _helicopter and not is_instance_valid(_helicopter):
		_helicopter = null
	if level >= 5 and not _helicopter:
		_spawn_helicopter()
	elif level < 5 and _helicopter:
		_despawn_helicopter()


func _try_spawn() -> void:
	var player_pos := _player.global_position

	for _attempt in range(5):
		var is_ns := _rng.randi() % 2 == 0
		var road_idx := _rng.randi_range(0, _grid.GRID_SIZE)
		var road_center: float
		if is_ns:
			road_center = _grid.get_road_center_near(road_idx, player_pos.x)
		else:
			road_center = _grid.get_road_center_near(road_idx, player_pos.z)

		var rw := _grid.get_road_width(road_idx)
		var along := _rng.randf_range(-SPAWN_RADIUS, SPAWN_RADIUS)
		var spawn_pos: Vector3
		var direction: int
		var yaw: float

		if is_ns:
			var lane_offset := rw / 4.0
			# Head toward player, not random
			var heading_north := (player_pos.z + along) > player_pos.z
			if heading_north:
				direction = 0
				spawn_pos = Vector3(
					road_center + lane_offset, 0.5, player_pos.z + along
				)
				yaw = 0.0
			else:
				direction = 1
				spawn_pos = Vector3(
					road_center - lane_offset, 0.5, player_pos.z + along
				)
				yaw = PI
		else:
			var lane_offset := rw / 4.0
			# Head toward player, not random
			var heading_east := (player_pos.x + along) < player_pos.x
			if heading_east:
				direction = 2
				spawn_pos = Vector3(
					player_pos.x + along, 0.5, road_center + lane_offset
				)
				yaw = -PI / 2.0
			else:
				direction = 3
				spawn_pos = Vector3(
					player_pos.x + along, 0.5, road_center - lane_offset
				)
				yaw = PI / 2.0

		var dist := spawn_pos.distance_to(player_pos)
		if dist < MIN_SPAWN_DIST or dist > SPAWN_RADIUS:
			continue

		if _grid.is_on_ramp(spawn_pos.x, spawn_pos.z):
			continue

		var too_close := false
		for v in _police:
			if is_instance_valid(v) and spawn_pos.distance_to(
				(v as Node3D).global_position
			) < MIN_VEHICLE_DIST:
				too_close = true
				break
		if not too_close:
			for v in get_tree().get_nodes_in_group("npc_vehicle"):
				if spawn_pos.distance_to(
					(v as Node3D).global_position
				) < MIN_VEHICLE_DIST:
					too_close = true
					break
		if too_close:
			continue

		var vehicle := _police_scene.instantiate()
		vehicle.position = spawn_pos
		vehicle.rotation.y = yaw

		var vc := vehicle.get_node_or_null("VehicleController")
		if vc:
			vc.active = false

		var ai: Node = _ai_script.new()
		ai.name = "PoliceAIController"
		vehicle.add_child(ai)

		var vh: Node = _vehicle_health_script.new()
		vh.name = "VehicleHealth"
		vehicle.add_child(vh)

		get_tree().current_scene.add_child(vehicle)
		vehicle.add_to_group("police_vehicle")

		var lights: Node3D = _vehicle_lights_script.new()
		lights.name = "VehicleLights"
		vehicle.get_node("Body").add_child(lights)
		lights.initialize(vehicle)

		ai.initialize(vehicle, road_idx, direction)

		_police.append(vehicle)
		return


func _despawn_far() -> void:
	if not _player:
		return
	var player_pos := _player.global_position
	var to_remove: Array[Node] = []
	for v in _police:
		if not is_instance_valid(v):
			to_remove.append(v)
			continue
		var d := (v as Node3D).global_position.distance_to(player_pos)
		if d > DESPAWN_RADIUS:
			to_remove.append(v)
		# Freeze/unfreeze GEVP physics by distance
		if "freeze" in v:
			v.freeze = d >= LOD_FREEZE_DIST
	for v in to_remove:
		_police.erase(v)
		if is_instance_valid(v):
			v.queue_free()


func _despawn_one() -> void:
	if _police.is_empty():
		return
	var v: Node = _police.pop_back()
	if is_instance_valid(v):
		v.queue_free()


func _spawn_helicopter() -> void:
	if _helicopter and is_instance_valid(_helicopter):
		return
	# Check group in case a despawning helicopter is still flying away
	if not get_tree().get_nodes_in_group(
		"police_helicopter"
	).is_empty():
		return
	if not _player:
		return

	var heli := CharacterBody3D.new()
	heli.set_script(_heli_script)

	var angle := _rng.randf_range(0.0, TAU)
	var offset := Vector3(
		sin(angle) * 200.0, 50.0, cos(angle) * 200.0
	)
	heli.position = _player.global_position + offset

	get_tree().current_scene.add_child(heli)
	_helicopter = heli


func _despawn_helicopter() -> void:
	if not _helicopter or not is_instance_valid(_helicopter):
		_helicopter = null
		return
	if _helicopter.has_method("begin_despawn"):
		_helicopter.begin_despawn()
	_helicopter = null
