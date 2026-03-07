extends Node
## Spawns and despawns police vehicles based on wanted level.
## Follows TrafficManager pattern: spawn on roads near player.

const SPAWN_RADIUS := 180.0
const DESPAWN_RADIUS := 250.0
const MIN_SPAWN_DIST := 60.0
const MIN_VEHICLE_DIST := 20.0
const SPAWN_INTERVAL := 1.0
const DESPAWN_FADE_TIME := 10.0

var _grid = preload("res://src/road_grid.gd").new()
var _police_scene: PackedScene = preload("res://scenes/vehicles/police_vehicle.tscn")
var _ai_script: GDScript = preload("res://scenes/vehicles/police_ai_controller.gd")
var _vehicle_health_script: GDScript = preload(
	"res://scenes/vehicles/vehicle_health.gd"
)

var _police: Array[Node] = []
var _player: Node3D = null
var _rng := RandomNumberGenerator.new()
var _spawn_timer := 0.0
var _despawn_timer := 0.0
var _despawning := false


func _ready() -> void:
	EventBus.wanted_level_changed.connect(_on_wanted_level_changed)


func _process(delta: float) -> void:
	if not _player:
		_player = get_tree().get_first_node_in_group("player") as Node3D
		if not _player:
			return

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
	# 1 star=2, 2=4, 3=7, 4=10, 5=14
	if level <= 2:
		return level * 2
	return level * 3 - 1


func _on_wanted_level_changed(level: int) -> void:
	if level <= 0 and not _police.is_empty():
		_despawning = true
		_despawn_timer = 0.0
	else:
		_despawning = false


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
			var heading_north := _rng.randi() % 2 == 0
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
			var heading_east := _rng.randi() % 2 == 0
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

		var too_close := false
		for v in _police:
			if is_instance_valid(v) and spawn_pos.distance_to(
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
		if (v as Node3D).global_position.distance_to(player_pos) > DESPAWN_RADIUS:
			to_remove.append(v)
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
