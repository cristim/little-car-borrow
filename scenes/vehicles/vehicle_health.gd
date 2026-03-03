extends Node
## Tracks vehicle health, spawns bullet hole decals, catches fire, and explodes.

const MAX_HEALTH := 100.0
const FIRE_THRESHOLD := 30.0
const BURN_TIME := 6.0
const MAX_BULLET_HOLES := 10
const FIRE_PARTICLES := 40
const FIRE_LIFETIME := 0.8

var health := MAX_HEALTH
var on_fire := false

var _fire_particles: GPUParticles3D = null
var _fire_timer := 0.0
var _bullet_holes: Array[MeshInstance3D] = []
var _vehicle: RigidBody3D = null
var _body: Node3D = null


func _ready() -> void:
	_vehicle = get_parent() as RigidBody3D
	if _vehicle:
		_body = _vehicle.get_node_or_null("Body") as Node3D


func _process(delta: float) -> void:
	if not on_fire:
		return
	_fire_timer += delta
	if _fire_timer >= BURN_TIME:
		_explode()


func take_damage(amount: float, hit_pos: Vector3, hit_normal: Vector3) -> void:
	if health <= 0.0:
		return
	health -= amount
	if health < 0.0:
		health = 0.0

	EventBus.vehicle_damaged.emit(_vehicle, amount)
	_spawn_bullet_hole(hit_pos, hit_normal)
	_darken_body()

	if health <= FIRE_THRESHOLD and not on_fire:
		_catch_fire()


func _spawn_bullet_hole(hit_pos: Vector3, hit_normal: Vector3) -> void:
	if not _body:
		return

	var hole := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(0.15, 0.15)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.05, 0.05, 0.05)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	plane.material = mat
	hole.mesh = plane
	hole.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	_body.add_child(hole)
	# Position in body-local space, offset slightly along normal to avoid z-fight
	hole.global_position = hit_pos + hit_normal * 0.01
	# Orient plane to face outward along the surface normal
	if hit_normal.abs() != Vector3.UP:
		hole.look_at(hole.global_position + hit_normal, Vector3.UP)
	else:
		hole.look_at(hole.global_position + hit_normal, Vector3.FORWARD)
	# PlaneMesh faces +Y by default; rotate so it faces along -Z after look_at
	hole.rotate_object_local(Vector3.RIGHT, -PI / 2.0)

	_bullet_holes.append(hole)
	if _bullet_holes.size() > MAX_BULLET_HOLES:
		var old: MeshInstance3D = _bullet_holes.pop_front()
		if is_instance_valid(old):
			old.queue_free()


func _darken_body() -> void:
	if not _body:
		return
	# All body panels share one material instance; modify it once via LowerBody
	var mesh := _body.get_node_or_null("LowerBody") as MeshInstance3D
	if not mesh or not mesh.material_override:
		return
	var ratio: float = health / MAX_HEALTH
	var darken: float = 1.0 - (1.0 - ratio) * 0.7
	var c: Color = mesh.material_override.albedo_color
	mesh.material_override.albedo_color = Color(
		c.r * darken, c.g * darken, c.b * darken
	)


func _catch_fire() -> void:
	on_fire = true
	_fire_timer = 0.0

	# Build fire particles in code
	_fire_particles = GPUParticles3D.new()
	_fire_particles.amount = FIRE_PARTICLES
	_fire_particles.lifetime = FIRE_LIFETIME
	_fire_particles.emitting = true

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 30.0
	mat.initial_velocity_min = 1.0
	mat.initial_velocity_max = 2.5
	mat.gravity = Vector3(0, -2.0, 0)
	mat.scale_min = 0.08
	mat.scale_max = 0.18
	mat.color = Color(1.0, 0.6, 0.1)
	var color_ramp := Gradient.new()
	color_ramp.set_color(0, Color(1.0, 0.8, 0.2))
	color_ramp.set_color(1, Color(0.3, 0.05, 0.0, 0.0))
	var tex := GradientTexture1D.new()
	tex.gradient = color_ramp
	mat.color_ramp = tex
	_fire_particles.process_material = mat

	# Draw pass — small emissive sphere
	var sphere := SphereMesh.new()
	sphere.radius = 0.06
	sphere.height = 0.12
	sphere.radial_segments = 4
	sphere.rings = 2
	var sphere_mat := StandardMaterial3D.new()
	sphere_mat.albedo_color = Color(1.0, 0.5, 0.1)
	sphere_mat.emission_enabled = true
	sphere_mat.emission = Color(1.0, 0.6, 0.1)
	sphere_mat.emission_energy_multiplier = 3.0
	sphere.material = sphere_mat
	_fire_particles.draw_pass_1 = sphere

	# Position above engine area (front-top of body)
	_fire_particles.position = Vector3(0.0, 0.5, -0.8)
	if _body:
		_body.add_child(_fire_particles)
	elif _vehicle:
		_vehicle.add_child(_fire_particles)

	_play_fire_sound()


func _explode() -> void:
	on_fire = false
	if not _vehicle or not is_instance_valid(_vehicle):
		return

	# Strong upward impulse
	_vehicle.apply_central_impulse(Vector3(0, 4000.0, 0))

	EventBus.vehicle_destroyed.emit(_vehicle)

	# Eject NPC controller if present
	var npc := _vehicle.get_node_or_null("NPCVehicleController")
	if npc:
		npc.deactivate()
	var police := _vehicle.get_node_or_null("PoliceAIController")
	if police:
		police.deactivate()

	# Remove after brief delay
	get_tree().create_timer(0.5).timeout.connect(_vehicle.queue_free)


func _play_fire_sound() -> void:
	if not _vehicle:
		return
	var asp := AudioStreamPlayer3D.new()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 2.0
	asp.stream = gen
	asp.max_distance = 35.0
	asp.bus = "SFX"
	_vehicle.add_child(asp)
	asp.play()

	var playback: AudioStreamGeneratorPlayback = asp.get_stream_playback()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var rate := 22050.0
	var frames := int(rate * 1.5)
	var filter_lo := 0.0
	var filter_hi := 0.0
	var crackle_counter := 0
	var crackle_interval := rng.randi_range(400, 1200)

	for i in range(frames):
		var noise := rng.randf() - 0.5

		# Low rumble via low-pass filtered noise
		filter_lo += 0.015 * (noise - filter_lo)
		# Higher crackle via band-pass
		filter_hi += 0.12 * (noise - filter_hi)
		var band := filter_hi - filter_lo

		var sample := filter_lo * 0.2 + band * 0.08

		# Random crackle pops
		crackle_counter += 1
		if crackle_counter >= crackle_interval:
			crackle_counter = 0
			crackle_interval = rng.randi_range(300, 1000)
			sample += (rng.randf() - 0.5) * 0.3

		playback.push_frame(Vector2(sample, sample))
