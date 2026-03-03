extends Node
## Spawns and despawns pedestrians on sidewalks around the player.
## Follows TrafficManager pattern with road_grid for positioning.

const SPAWN_RADIUS := 120.0
const DESPAWN_RADIUS := 150.0
const MIN_SPAWN_DIST := 25.0
const MIN_PED_DIST := 5.0
const MAX_PEDESTRIANS := 40
const SPAWN_INTERVAL := 0.5
const SPAWNS_PER_TICK := 3
const SIDEWALK_OFFSET := 1.5

var _grid = preload("res://src/road_grid.gd").new()
var _ped_scene: PackedScene = preload("res://scenes/pedestrians/pedestrian.tscn")
var _pedestrians: Array[Node] = []
var _player: Node3D = null
var _rng := RandomNumberGenerator.new()
var _spawn_timer := 0.0
var _initial_burst_done := false


func _ready() -> void:
	_rng.randomize()
	EventBus.pedestrian_killed.connect(_on_pedestrian_killed)


func _process(delta: float) -> void:
	if not _player:
		_player = get_tree().get_first_node_in_group("player") as Node3D
		if not _player:
			return

	if not _initial_burst_done:
		_initial_burst_done = true
		for _i in range(MAX_PEDESTRIANS):
			_try_spawn()
		return

	_spawn_timer += delta
	if _spawn_timer >= SPAWN_INTERVAL:
		_spawn_timer = 0.0
		_despawn_far()
		for _i in range(SPAWNS_PER_TICK):
			_try_spawn()


func _try_spawn() -> void:
	if _pedestrians.size() >= MAX_PEDESTRIANS:
		return

	var player_pos := _player.global_position

	for _attempt in range(5):
		# Pick a random road and side (left/right sidewalk)
		var is_ns := _rng.randi() % 2 == 0
		var road_idx := _rng.randi_range(0, _grid.GRID_SIZE)
		var road_center: float
		if is_ns:
			road_center = _grid.get_road_center_near(road_idx, player_pos.x)
		else:
			road_center = _grid.get_road_center_near(road_idx, player_pos.z)

		var rw := _grid.get_road_width(road_idx)
		var sidewalk_center := road_center + (rw / 2.0 + SIDEWALK_OFFSET)
		if _rng.randi() % 2 == 0:
			sidewalk_center = road_center - (rw / 2.0 + SIDEWALK_OFFSET)

		var along := _rng.randf_range(-SPAWN_RADIUS, SPAWN_RADIUS)
		var spawn_pos: Vector3
		var walk_dir: Vector3

		if is_ns:
			spawn_pos = Vector3(sidewalk_center, 0.15, player_pos.z + along)
			walk_dir = Vector3(0, 0, -1) if _rng.randi() % 2 == 0 else Vector3(0, 0, 1)
		else:
			spawn_pos = Vector3(player_pos.x + along, 0.15, sidewalk_center)
			walk_dir = Vector3(1, 0, 0) if _rng.randi() % 2 == 0 else Vector3(-1, 0, 0)

		var dist := spawn_pos.distance_to(player_pos)
		if dist < MIN_SPAWN_DIST or dist > SPAWN_RADIUS:
			continue

		var too_close := false
		for p in _pedestrians:
			if is_instance_valid(p) and spawn_pos.distance_to(
				(p as Node3D).global_position
			) < MIN_PED_DIST:
				too_close = true
				break
		if too_close:
			continue

		var ped := _ped_scene.instantiate()
		ped.position = spawn_pos
		get_tree().current_scene.add_child(ped)

		# Set initial walk direction
		var sm := ped.get_node_or_null("StateMachine")
		if sm and sm.current_state and sm.current_state.has_method("enter"):
			sm.current_state.enter({"direction": walk_dir})

		_pedestrians.append(ped)
		return


func _despawn_far() -> void:
	if not _player:
		return
	var player_pos := _player.global_position
	var to_remove: Array[Node] = []
	for p in _pedestrians:
		if not is_instance_valid(p):
			to_remove.append(p)
			continue
		if (p as Node3D).global_position.distance_to(player_pos) > DESPAWN_RADIUS:
			to_remove.append(p)
	for p in to_remove:
		_pedestrians.erase(p)
		if is_instance_valid(p):
			p.queue_free()


func _on_pedestrian_killed(pedestrian: Node) -> void:
	_pedestrians.erase(pedestrian)
