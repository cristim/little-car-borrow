extends Node
## Spawns and despawns NPC vehicles around the player to create traffic.
## Uses road_grid.gd for infinite tiling — spawns work at any world position.
## Applies random body variants (sedan, sports, SUV, hatchback, van, pickup).

const SPAWN_RADIUS := 200.0
const DESPAWN_RADIUS := 250.0
const DESPAWN_BEHIND_RADIUS := 80.0
const MIN_SPAWN_DIST := 90.0
const MIN_VEHICLE_DIST := 12.0
const MAX_VEHICLES := 30
const SPAWN_INTERVAL := 0.5
const SPAWNS_PER_TICK := 3

# Body variant definitions — each adjusts the base vehicle proportions.
# body_scale: overall Body node scale
# cabin_scale: cabin mesh scale relative to body
# cabin_y_offset: vertical shift for cabin position
# windshield_angle / rear_angle: glass tilt in degrees
# side_tilt: side window inward lean in degrees
# mass_mult: multiplier on base 1200 kg mass
const VARIANTS := [
	{
		"name": "sedan", "weight": 3,
		"body_scale": Vector3(1.0, 1.0, 1.0),
		"cabin_scale": Vector3(1.0, 1.0, 1.0),
		"cabin_y_offset": 0.0,
		"windshield_angle": 25.0, "rear_angle": 20.0,
		"side_tilt": 3.0, "mass_mult": 1.0,
	},
	{
		"name": "sports", "weight": 2,
		"body_scale": Vector3(1.05, 0.85, 1.05),
		"cabin_scale": Vector3(0.95, 0.78, 0.9),
		"cabin_y_offset": -0.04,
		"windshield_angle": 35.0, "rear_angle": 30.0,
		"side_tilt": 5.0, "mass_mult": 0.9,
	},
	{
		"name": "suv", "weight": 2,
		"body_scale": Vector3(1.1, 1.15, 1.05),
		"cabin_scale": Vector3(1.05, 1.25, 1.1),
		"cabin_y_offset": 0.06,
		"windshield_angle": 18.0, "rear_angle": 12.0,
		"side_tilt": 2.0, "mass_mult": 1.3,
	},
	{
		"name": "hatchback", "weight": 2,
		"body_scale": Vector3(0.95, 1.0, 0.88),
		"cabin_scale": Vector3(0.97, 1.05, 0.78),
		"cabin_y_offset": 0.0,
		"windshield_angle": 28.0, "rear_angle": 40.0,
		"side_tilt": 3.0, "mass_mult": 0.85,
	},
	{
		"name": "van", "weight": 1,
		"body_scale": Vector3(1.05, 1.3, 1.15),
		"cabin_scale": Vector3(1.1, 1.5, 1.4),
		"cabin_y_offset": 0.1,
		"windshield_angle": 12.0, "rear_angle": 5.0,
		"side_tilt": 1.0, "mass_mult": 1.6,
	},
	{
		"name": "pickup", "weight": 1,
		"body_scale": Vector3(1.1, 1.1, 1.2),
		"cabin_scale": Vector3(1.0, 1.15, 0.6),
		"cabin_y_offset": 0.04,
		"windshield_angle": 20.0, "rear_angle": 5.0,
		"side_tilt": 2.0, "mass_mult": 1.5,
	},
]

var _grid = preload("res://src/road_grid.gd").new()
var _total_weight := 0

var _vehicles: Array[Node] = []
var _vehicle_scene: PackedScene = preload("res://scenes/vehicles/base_vehicle.tscn")
var _npc_controller_script: GDScript = preload(
	"res://scenes/vehicles/npc_vehicle_controller.gd"
)
var _spawn_timer := 0.0
var _player: Node3D = null
var _rng := RandomNumberGenerator.new()
var _player_velocity := Vector3.ZERO
var _time_multiplier := 1.0

var _car_colors: Array[Color] = [
	Color(0.15, 0.25, 0.55),
	Color(0.1, 0.5, 0.2),
	Color(0.9, 0.85, 0.7),
	Color(0.3, 0.3, 0.3),
	Color(0.85, 0.85, 0.85),
	Color(0.6, 0.1, 0.1),
	Color(0.95, 0.7, 0.1),
	Color(0.05, 0.05, 0.05),
	Color(0.95, 0.95, 0.95),
	Color(0.4, 0.2, 0.5),
]


func _ready() -> void:
	_rng.randomize()
	EventBus.vehicle_entered.connect(_on_vehicle_stolen)
	EventBus.time_of_day_changed.connect(_on_time_changed)
	for v in VARIANTS:
		_total_weight += v.weight


func _process(delta: float) -> void:
	if not _player:
		_player = get_tree().get_first_node_in_group("player") as Node3D
		if not _player:
			return

	if "velocity" in _player:
		_player_velocity = _player.velocity
	else:
		_player_velocity = Vector3.ZERO

	_spawn_timer += delta
	if _spawn_timer >= SPAWN_INTERVAL:
		_spawn_timer = 0.0
		_despawn_far()
		# Spawn more aggressively when vehicle count is low
		var effective_max := int(MAX_VEHICLES * _time_multiplier)
		var deficit := effective_max - _vehicles.size()
		var count := SPAWNS_PER_TICK
		if deficit > effective_max / 2:
			count = 10
		elif deficit > effective_max / 4:
			count = 6
		for _i in range(count):
			_try_spawn()


func _try_spawn() -> void:
	var effective_max := int(MAX_VEHICLES * _time_multiplier)
	if _vehicles.size() >= effective_max:
		return

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
		for v in _vehicles:
			if is_instance_valid(v) and spawn_pos.distance_to(
				(v as Node3D).global_position
			) < MIN_VEHICLE_DIST:
				too_close = true
				break
		if too_close:
			continue

		# Bias spawns ahead of player movement
		var h_vel := Vector3(_player_velocity.x, 0.0, _player_velocity.z)
		if h_vel.length_squared() > 1.0:
			var offset := spawn_pos - player_pos
			offset.y = 0.0
			if h_vel.normalized().dot(offset.normalized()) < -0.3:
				if _rng.randf() < 0.7:
					continue

		var vehicle := _vehicle_scene.instantiate()
		_apply_variant(vehicle)
		_randomize_color(vehicle)
		vehicle.position = spawn_pos
		vehicle.rotation.y = yaw

		var vc := vehicle.get_node_or_null("VehicleController")
		if vc:
			vc.active = false

		var npc: Node = _npc_controller_script.new()
		npc.name = "NPCVehicleController"
		vehicle.add_child(npc)

		get_tree().current_scene.add_child(vehicle)
		vehicle.add_to_group("npc_vehicle")
		npc.initialize(vehicle, road_idx, direction)

		_vehicles.append(vehicle)
		return


func _despawn_far() -> void:
	if not _player:
		return

	var player_pos := _player.global_position
	var h_vel := Vector3(_player_velocity.x, 0.0, _player_velocity.z)
	var moving := h_vel.length_squared() > 1.0
	var vel_dir := h_vel.normalized() if moving else Vector3.ZERO
	var to_remove: Array[Node] = []

	for v in _vehicles:
		if not is_instance_valid(v):
			to_remove.append(v)
			continue
		var v_pos := (v as Node3D).global_position
		var d := v_pos.distance_to(player_pos)
		if d > DESPAWN_RADIUS:
			to_remove.append(v)
		elif moving and d > DESPAWN_BEHIND_RADIUS:
			var offset := v_pos - player_pos
			offset.y = 0.0
			if vel_dir.dot(offset.normalized()) < -0.5:
				to_remove.append(v)

	for v in to_remove:
		_vehicles.erase(v)
		if is_instance_valid(v):
			v.queue_free()


func _on_vehicle_stolen(vehicle: Node) -> void:
	if vehicle in _vehicles:
		_vehicles.erase(vehicle)
		var npc := vehicle.get_node_or_null("NPCVehicleController")
		if npc:
			npc.deactivate()


func _pick_weighted_variant() -> int:
	var roll := _rng.randi_range(0, _total_weight - 1)
	var cumulative := 0
	for i in range(VARIANTS.size()):
		cumulative += VARIANTS[i].weight
		if roll < cumulative:
			return i
	return 0


func _apply_variant(vehicle: Node) -> void:
	var v: Dictionary = VARIANTS[_pick_weighted_variant()]
	var body := vehicle.get_node_or_null("Body") as Node3D
	if not body:
		return

	# Scale the whole body
	body.scale = v.body_scale

	# Cabin proportions — base mesh is 1.5 x 0.45 x 1.8 at (0, 0.275, 0.15)
	var cs: Vector3 = v.cabin_scale
	var cabin_y: float = 0.275 + float(v.cabin_y_offset)
	var cabin_z: float = 0.15
	var cabin_half_w: float = 0.75 * cs.x
	var cabin_half_len: float = 0.9 * cs.z
	var cabin := body.get_node_or_null("Cabin") as Node3D
	if cabin:
		cabin.scale = cs
		cabin.position.y = cabin_y

	# Windshield at front face of cabin
	var ws := body.get_node_or_null("Windshield") as Node3D
	if ws:
		var a: float = deg_to_rad(float(v.windshield_angle))
		var ws_z: float = cabin_z - cabin_half_len
		ws.transform = Transform3D(
			Basis(Vector3.RIGHT, a), Vector3(0, cabin_y, ws_z)
		)

	# Rear window at rear face of cabin
	var rear := body.get_node_or_null("RearWindow") as Node3D
	if rear:
		var a: float = deg_to_rad(float(v.rear_angle))
		var rw_z: float = cabin_z + cabin_half_len
		rear.transform = Transform3D(
			Basis(Vector3.RIGHT, -a), Vector3(0, cabin_y, rw_z)
		)

	# Side windows — positioned at cabin edges, scaled to cabin length
	var tilt: float = deg_to_rad(float(v.side_tilt))
	var side_x: float = cabin_half_w + 0.01
	var side_y: float = cabin_y + 0.05
	var side_scale_z: float = cabin_half_len * 2.0 / 1.6
	var lw := body.get_node_or_null("LeftWindow") as Node3D
	if lw:
		lw.position = Vector3(-side_x, side_y, cabin_z)
		lw.rotation.z = tilt
		lw.scale.z = side_scale_z
	var rw := body.get_node_or_null("RightWindow") as Node3D
	if rw:
		rw.position = Vector3(side_x, side_y, cabin_z)
		rw.rotation.z = -tilt
		rw.scale.z = side_scale_z

	# Adjust vehicle mass
	if "vehicle_mass" in vehicle:
		vehicle.vehicle_mass = 1200.0 * v.mass_mult


func _randomize_color(vehicle: Node) -> void:
	var body := vehicle.get_node_or_null("Body")
	if not body:
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = _car_colors[_rng.randi() % _car_colors.size()]
	for child_name in ["LowerBody", "Cabin", "LeftDoorPivot/DoorPanel"]:
		var child := body.get_node_or_null(child_name)
		if child:
			child.material_override = mat


func _on_time_changed(hour: float) -> void:
	if hour < 5.0 or hour > 22.0:
		_time_multiplier = 0.5  # deep night
	elif hour < 7.0 or hour > 20.0:
		_time_multiplier = 0.7  # dawn/dusk
	else:
		_time_multiplier = 1.0  # day
