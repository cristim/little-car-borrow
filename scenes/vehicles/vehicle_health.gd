extends Node
## Tracks vehicle health, spawns bullet hole decals, catches fire, and explodes.

const MAX_HEALTH := 100.0
const FIRE_THRESHOLD := 30.0
const BURN_TIME := 6.0
const MAX_BULLET_HOLES := 10
const FIRE_AMOUNT := 60
const SMOKE_AMOUNT := 30
const FIRE_LIFETIME := 1.0
const SMOKE_LIFETIME := 1.8

var health := MAX_HEALTH
var on_fire := false
var destroyed := false

var _fire_particles: GPUParticles3D = null
var _smoke_particles: GPUParticles3D = null
var _fire_sound: AudioStreamPlayer3D = null
var _fire_timer := 0.0
var _bullet_holes: Array[MeshInstance3D] = []
var _vehicle: RigidBody3D = null
var _body: Node3D = null
var _original_color := Color.WHITE


func _ready() -> void:
	_vehicle = get_parent() as RigidBody3D
	if _vehicle:
		_body = _vehicle.get_node_or_null("Body") as Node3D
	if _body:
		_store_original_color()


func _process(delta: float) -> void:
	if not on_fire:
		return
	_fire_timer += delta
	if _fire_timer >= BURN_TIME:
		_explode()


func take_damage(amount: float, hit_pos: Vector3, hit_normal: Vector3) -> void:
	if destroyed:
		return
	health -= amount
	if health < 0.0:
		health = 0.0

	EventBus.vehicle_damaged.emit(_vehicle, amount)
	_spawn_bullet_hole(hit_pos, hit_normal)
	_darken_body()

	if health <= FIRE_THRESHOLD and not on_fire:
		_catch_fire()


func _store_original_color() -> void:
	var mesh := _body.get_node_or_null("CarBody") as MeshInstance3D
	if not mesh:
		return
	if mesh.material_override:
		_original_color = mesh.material_override.albedo_color
	elif mesh.mesh and mesh.mesh.surface_get_material(0):
		_original_color = mesh.mesh.surface_get_material(0).albedo_color


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
	if not hit_normal.abs().is_equal_approx(Vector3.UP):
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
	var mesh := _body.get_node_or_null("CarBody") as MeshInstance3D
	if not mesh:
		return

	# Ensure material_override exists so we can darken it
	if not mesh.material_override:
		var new_mat := StandardMaterial3D.new()
		new_mat.albedo_color = _original_color
		mesh.material_override = new_mat

	# Compute darkened color from original, not from current
	var ratio: float = health / MAX_HEALTH
	var darkened := Color(
		_original_color.r * ratio,
		_original_color.g * ratio,
		_original_color.b * ratio,
	)
	mesh.material_override.albedo_color = darkened


func _catch_fire() -> void:
	on_fire = true
	_fire_timer = 0.0

	_create_fire_particles()
	_create_smoke_particles()
	_play_fire_sound()


func _create_fire_particles() -> void:
	_fire_particles = GPUParticles3D.new()
	_fire_particles.amount = FIRE_AMOUNT
	_fire_particles.lifetime = FIRE_LIFETIME
	_fire_particles.emitting = true

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 25.0
	mat.initial_velocity_min = 0.8
	mat.initial_velocity_max = 2.0
	mat.gravity = Vector3(0, 1.5, 0)
	mat.scale_min = 0.06
	mat.scale_max = 0.22
	mat.damping_min = 1.0
	mat.damping_max = 2.0

	# Emission shape — spread across hood area
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(0.5, 0.1, 0.4)

	# Orange-yellow color ramp fading to dark red/transparent
	var color_ramp := Gradient.new()
	color_ramp.add_point(0.0, Color(1.0, 0.95, 0.4, 1.0))
	color_ramp.add_point(0.25, Color(1.0, 0.6, 0.1, 0.9))
	color_ramp.add_point(0.6, Color(0.8, 0.2, 0.0, 0.6))
	color_ramp.add_point(1.0, Color(0.2, 0.05, 0.0, 0.0))
	var tex := GradientTexture1D.new()
	tex.gradient = color_ramp
	mat.color_ramp = tex

	# Scale curve — grow then shrink
	var scale_curve := Curve.new()
	scale_curve.add_point(Vector2(0.0, 0.3))
	scale_curve.add_point(Vector2(0.3, 1.0))
	scale_curve.add_point(Vector2(1.0, 0.2))
	var scale_tex := CurveTexture.new()
	scale_tex.curve = scale_curve
	mat.scale_curve = scale_tex

	_fire_particles.process_material = mat

	# Draw pass — emissive sphere
	var sphere := SphereMesh.new()
	sphere.radius = 0.08
	sphere.height = 0.16
	sphere.radial_segments = 6
	sphere.rings = 3
	var sphere_mat := StandardMaterial3D.new()
	sphere_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sphere_mat.albedo_color = Color(1.0, 0.7, 0.2, 0.8)
	sphere_mat.emission_enabled = true
	sphere_mat.emission = Color(1.0, 0.5, 0.1)
	sphere_mat.emission_energy_multiplier = 4.0
	sphere_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	sphere.material = sphere_mat
	_fire_particles.draw_pass_1 = sphere

	# Position above engine area (front-top of body)
	_fire_particles.position = Vector3(0.0, 0.5, -0.6)
	if _body:
		_body.add_child(_fire_particles)
	elif _vehicle:
		_vehicle.add_child(_fire_particles)


func _create_smoke_particles() -> void:
	_smoke_particles = GPUParticles3D.new()
	_smoke_particles.amount = SMOKE_AMOUNT
	_smoke_particles.lifetime = SMOKE_LIFETIME
	_smoke_particles.emitting = true

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 35.0
	mat.initial_velocity_min = 0.5
	mat.initial_velocity_max = 1.5
	mat.gravity = Vector3(0, 0.8, 0)
	mat.scale_min = 0.15
	mat.scale_max = 0.5
	mat.damping_min = 0.5
	mat.damping_max = 1.0

	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(0.4, 0.05, 0.3)

	# Dark smoke fading out
	var color_ramp := Gradient.new()
	color_ramp.add_point(0.0, Color(0.15, 0.12, 0.1, 0.5))
	color_ramp.add_point(0.4, Color(0.2, 0.18, 0.15, 0.35))
	color_ramp.add_point(1.0, Color(0.25, 0.22, 0.2, 0.0))
	var tex := GradientTexture1D.new()
	tex.gradient = color_ramp
	mat.color_ramp = tex

	# Scale up as smoke rises
	var scale_curve := Curve.new()
	scale_curve.add_point(Vector2(0.0, 0.4))
	scale_curve.add_point(Vector2(0.5, 1.0))
	scale_curve.add_point(Vector2(1.0, 1.5))
	var scale_tex := CurveTexture.new()
	scale_tex.curve = scale_curve
	mat.scale_curve = scale_tex

	_smoke_particles.process_material = mat

	# Smoke draw pass — larger semi-transparent sphere
	var sphere := SphereMesh.new()
	sphere.radius = 0.12
	sphere.height = 0.24
	sphere.radial_segments = 6
	sphere.rings = 3
	var sphere_mat := StandardMaterial3D.new()
	sphere_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sphere_mat.albedo_color = Color(0.2, 0.18, 0.15, 0.4)
	sphere_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	sphere.material = sphere_mat
	_smoke_particles.draw_pass_1 = sphere

	# Position slightly above fire
	_smoke_particles.position = Vector3(0.0, 0.8, -0.6)
	if _body:
		_body.add_child(_smoke_particles)
	elif _vehicle:
		_vehicle.add_child(_smoke_particles)


func _explode() -> void:
	on_fire = false
	destroyed = true
	if _fire_sound and is_instance_valid(_fire_sound):
		_fire_sound.stop()
	if not _vehicle or not is_instance_valid(_vehicle):
		return

	# Eject player if they're driving this vehicle
	EventBus.force_exit_vehicle.emit(_vehicle)

	# Small upward pop, not a launch
	_vehicle.apply_central_impulse(Vector3(0, 500.0, 0))

	EventBus.vehicle_destroyed.emit(_vehicle)

	# Eject NPC controller if present
	var npc := _vehicle.get_node_or_null("NPCVehicleController")
	if npc:
		npc.deactivate()
	var police := _vehicle.get_node_or_null("PoliceAIController")
	if police:
		police.deactivate()

	# Kill police lights and siren
	var light_bar := _vehicle.get_node_or_null("PoliceLightBar")
	if light_bar:
		light_bar.lights_active = false
	var siren := _vehicle.get_node_or_null("PoliceSiren")
	if siren:
		siren.siren_active = false

	# Turn the body fully black (burned out)
	_set_body_burned()

	# Stop fire particles, keep smoke going briefly
	if _fire_particles and is_instance_valid(_fire_particles):
		_fire_particles.emitting = false
		get_tree().create_timer(2.0).timeout.connect(
			func() -> void:
				if is_instance_valid(_fire_particles):
					_fire_particles.queue_free()
		)
	if _smoke_particles and is_instance_valid(_smoke_particles):
		# Reduce smoke after explosion
		get_tree().create_timer(4.0).timeout.connect(
			func() -> void:
				if is_instance_valid(_smoke_particles):
					_smoke_particles.emitting = false
				get_tree().create_timer(3.0).timeout.connect(
					func() -> void:
						if is_instance_valid(_smoke_particles):
							_smoke_particles.queue_free()
				)
		)

	# Freeze the vehicle so it stays put
	_vehicle.freeze = true


func _set_body_burned() -> void:
	if not _body:
		return
	var burned_mat := StandardMaterial3D.new()
	burned_mat.albedo_color = Color(0.03, 0.03, 0.03)
	var car_body := _body.get_node_or_null("CarBody") as MeshInstance3D
	if car_body:
		car_body.material_override = burned_mat


func _play_fire_sound() -> void:
	if not _vehicle:
		return
	_fire_sound = AudioStreamPlayer3D.new()
	var asp: AudioStreamPlayer3D = _fire_sound
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
