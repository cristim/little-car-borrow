extends Node
## Detects when a vehicle enters water and applies sinking behavior.
## Ejects the player, applies heavy damping, and spawns bubble particles.

const SEA_LEVEL := -2.0
const CHECK_INTERVAL := 0.1
const SINK_LINEAR_DAMP := 2.0
const SINK_ANGULAR_DAMP := 3.0

var _timer := 0.0
var _sinking := false
var _vehicle: Node = null


func _ready() -> void:
	_vehicle = get_parent()
	# Boats float — disable sinking behavior
	if _vehicle and _vehicle.get_node_or_null("BoatController"):
		set_physics_process(false)


func _physics_process(delta: float) -> void:
	if _sinking or not _vehicle:
		return

	_timer += delta
	if _timer < CHECK_INTERVAL:
		return
	_timer = 0.0

	if not _vehicle is RigidBody3D:
		return

	if _vehicle.global_position.y > SEA_LEVEL:
		return

	if not _is_over_water(_vehicle.global_position):
		return

	_start_sinking()


func _start_sinking() -> void:
	_sinking = true

	# Apply heavy damping to simulate water resistance
	_vehicle.linear_damp = SINK_LINEAR_DAMP
	_vehicle.angular_damp = SINK_ANGULAR_DAMP

	# Eject player if driving this vehicle
	EventBus.force_exit_vehicle.emit(_vehicle)
	EventBus.vehicle_entered_water.emit(_vehicle)

	# Deactivate NPC/police controllers
	var npc := _vehicle.get_node_or_null("NPCVehicleController")
	if npc and npc.has_method("deactivate"):
		npc.deactivate()

	var police := _vehicle.get_node_or_null("PoliceAIController")
	if police and police.has_method("deactivate"):
		police.deactivate()

	# Kill vehicle lights (power died in water)
	var lights := _vehicle.get_node_or_null("Body/VehicleLights")
	if lights and lights.has_method("disable"):
		lights.disable()

	# Kill engine audio
	var audio := _vehicle.get_node_or_null("EngineAudio")
	if audio:
		audio.stop()

	# Spawn bubble particles
	_spawn_bubbles()


func _spawn_bubbles() -> void:
	var particles := GPUParticles3D.new()
	particles.name = "SinkBubbles"
	particles.amount = 30
	particles.lifetime = 2.0
	particles.emitting = true
	particles.one_shot = false

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 25.0
	mat.initial_velocity_min = 1.0
	mat.initial_velocity_max = 3.0
	mat.gravity = Vector3(0, 0, 0)
	mat.scale_min = 0.05
	mat.scale_max = 0.15
	mat.color = Color(0.7, 0.85, 1.0, 0.6)
	particles.process_material = mat

	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 4
	sphere.rings = 2
	particles.draw_pass_1 = sphere

	particles.position = Vector3(0, 0.5, 0)
	_vehicle.add_child(particles)


func _is_over_water(pos: Vector3) -> bool:
	var city_nodes := get_tree().get_nodes_in_group("city_manager")
	if city_nodes.is_empty():
		return false
	if not city_nodes[0].has_meta("city_boundary"):
		return false
	var boundary: RefCounted = city_nodes[0].get_meta("city_boundary")
	if not boundary:
		return false
	var ground_h: float = boundary.get_ground_height(pos.x, pos.z)
	return ground_h < SEA_LEVEL
