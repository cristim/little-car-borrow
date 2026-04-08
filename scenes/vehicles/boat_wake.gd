extends Node3D
## Visual wake effects for boats: spray particles and foam trail.

const SPEED_THRESHOLD := 2.0  # m/s (~7 km/h) before wake appears
const MAX_SPRAY_SPEED := 15.0  # m/s for full spray intensity

var _vehicle: RigidBody3D = null
var _port_spray: GPUParticles3D = null
var _starboard_spray: GPUParticles3D = null
var _foam_trail: GPUParticles3D = null


func _ready() -> void:
	_vehicle = get_parent() as RigidBody3D
	if not _vehicle:
		return

	_port_spray = _create_spray(Vector3(-0.8, 0.0, 2.0), Vector3(0.3, 1, 0.5))
	add_child(_port_spray)

	_starboard_spray = _create_spray(Vector3(0.8, 0.0, 2.0), Vector3(-0.3, 1, 0.5))
	add_child(_starboard_spray)

	_foam_trail = _create_foam()
	add_child(_foam_trail)


func _process(_delta: float) -> void:
	if not _vehicle:
		return

	var speed := _vehicle.linear_velocity.length()
	var active: bool = speed > SPEED_THRESHOLD
	var intensity := clampf(
		(speed - SPEED_THRESHOLD) / (MAX_SPRAY_SPEED - SPEED_THRESHOLD),
		0.0,
		1.0,
	)

	if _port_spray:
		_port_spray.emitting = active
		_port_spray.amount_ratio = intensity
	if _starboard_spray:
		_starboard_spray.emitting = active
		_starboard_spray.amount_ratio = intensity
	if _foam_trail:
		_foam_trail.emitting = active
		_foam_trail.amount_ratio = clampf(intensity * 0.7, 0.0, 1.0)


func _create_spray(offset: Vector3, direction: Vector3) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.position = offset
	particles.amount = 20
	particles.lifetime = 0.5
	particles.emitting = false

	var mat := ParticleProcessMaterial.new()
	mat.direction = direction.normalized()
	mat.spread = 15.0
	mat.initial_velocity_min = 2.0
	mat.initial_velocity_max = 5.0
	mat.gravity = Vector3(0, -5, 0)
	mat.scale_min = 0.05
	mat.scale_max = 0.12
	mat.color = Color(0.8, 0.9, 1.0, 0.5)
	particles.process_material = mat

	var sphere := SphereMesh.new()
	sphere.radius = 0.3
	sphere.height = 0.6
	sphere.radial_segments = 4
	sphere.rings = 2
	particles.draw_pass_1 = sphere

	return particles


func _create_foam() -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.position = Vector3(0, 0.1, 2.5)
	particles.amount = 30
	particles.lifetime = 1.5
	particles.emitting = false

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 0, 1)  # trail behind
	mat.spread = 30.0
	mat.initial_velocity_min = 0.5
	mat.initial_velocity_max = 1.5
	mat.gravity = Vector3(0, 0, 0)
	mat.scale_min = 0.15
	mat.scale_max = 0.3
	mat.color = Color(0.9, 0.95, 1.0, 0.35)
	particles.process_material = mat

	# Flat disc particle
	var disc := CylinderMesh.new()
	disc.top_radius = 0.5
	disc.bottom_radius = 0.5
	disc.height = 0.02
	disc.radial_segments = 6
	disc.rings = 1
	particles.draw_pass_1 = disc

	return particles
