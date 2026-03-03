extends Node
## Monitors the player's current vehicle for collisions and emits crimes.
## Attaches/detaches via EventBus vehicle_entered/exited signals.

const MIN_COLLISION_SPEED := 15.0
const CRIME_COOLDOWN := 1.0

var _ragdoll_script: GDScript = preload(
	"res://scenes/pedestrians/pedestrian_ragdoll.gd"
)
var _vehicle: RigidBody3D = null
var _cooldowns: Dictionary = {}


func _ready() -> void:
	EventBus.vehicle_entered.connect(_on_vehicle_entered)
	EventBus.vehicle_exited.connect(_on_vehicle_exited)


func _on_vehicle_entered(vehicle: Node) -> void:
	_vehicle = vehicle as RigidBody3D
	if _vehicle:
		_vehicle.body_entered.connect(_on_body_entered)


func _on_vehicle_exited(_vehicle_exited: Node) -> void:
	if _vehicle and is_instance_valid(_vehicle):
		if _vehicle.body_entered.is_connected(_on_body_entered):
			_vehicle.body_entered.disconnect(_on_body_entered)
	_vehicle = null


func _process(delta: float) -> void:
	var keys_to_remove: Array[String] = []
	for key in _cooldowns:
		_cooldowns[key] -= delta
		if _cooldowns[key] <= 0.0:
			keys_to_remove.append(key)
	for key in keys_to_remove:
		_cooldowns.erase(key)


func _on_body_entered(body: Node) -> void:
	if not _vehicle or not is_instance_valid(_vehicle):
		return

	var speed_kmh := _vehicle.linear_velocity.length() * 3.6
	if speed_kmh < MIN_COLLISION_SPEED:
		return

	# Ignore ground/road
	if body.is_in_group("Road"):
		return

	var crime_type: String
	var heat_points: int

	if body.is_in_group("police_officer"):
		crime_type = "hit_police_officer"
		heat_points = 50
		_spawn_ragdoll(body)
		body.queue_free()
	elif body.is_in_group("pedestrian"):
		crime_type = "hit_pedestrian"
		heat_points = 25
		_spawn_ragdoll(body)
		EventBus.pedestrian_killed.emit(body)
		body.queue_free()
	elif body is RigidBody3D:
		crime_type = "hit_vehicle"
		heat_points = 10
	elif body is StaticBody3D:
		return
	else:
		return

	if _cooldowns.has(crime_type):
		return

	_cooldowns[crime_type] = CRIME_COOLDOWN
	EventBus.crime_committed.emit(crime_type, heat_points)


func _spawn_ragdoll(pedestrian: Node) -> void:
	if not _vehicle or not is_instance_valid(_vehicle):
		return
	var ragdoll := RigidBody3D.new()
	ragdoll.set_script(_ragdoll_script)
	ragdoll.position = (pedestrian as Node3D).global_position
	ragdoll.rotation = (pedestrian as Node3D).global_rotation
	ragdoll.copy_visual_from(pedestrian)
	get_tree().current_scene.add_child(ragdoll)
	ragdoll.launch(_vehicle.linear_velocity)
