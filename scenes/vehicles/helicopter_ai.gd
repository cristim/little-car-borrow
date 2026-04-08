extends CharacterBody3D
## Police helicopter AI -- orbits player at altitude, searchlight, shoots.
## Spawned/despawned by PoliceManager based on wanted level.

enum HeliState { APPROACH, ORBIT, DESPAWNING }

# Flight
const FLIGHT_HEIGHT := 50.0
const APPROACH_SPEED := 25.0
const MAX_SPEED := 30.0
const ORBIT_RADIUS := 25.0
const ORBIT_SPEED := 0.6
const ORBIT_ENTER_DIST := 20.0
const ALTITUDE_LERP := 4.0
const TILT_ANGLE := 0.15

# Shooting
const SHOOT_INTERVAL_MIN := 2.0
const SHOOT_INTERVAL_MAX := 3.5
const SHOOT_SPREAD := 3.0
const SHOOT_DAMAGE := 10.0
const SHOOT_HIT_CHANCE := 0.35
const TRACER_FADE_TIME := 0.2
const TRACER_RADIUS := 0.03
const LOS_MASK := 2

# Searchlight
const SPOTLIGHT_RANGE := 70.0
const SPOTLIGHT_ANGLE := 25.0
const SPOTLIGHT_ENERGY := 3.0

# Rotor
const MAIN_ROTOR_SPEED := 15.0
const TAIL_ROTOR_SPEED := 30.0

# Despawn
const DESPAWN_ASCEND_SPEED := 20.0
const DESPAWN_HEIGHT := 120.0

var _state: int = HeliState.APPROACH
var _orbit_angle := 0.0
var _player: Node3D = null
var _rng := RandomNumberGenerator.new()
var _rotor_pivot: Node3D = null
var _tail_rotor_pivot: Node3D = null
var _spotlight: SpotLight3D = null
var _shoot_timer: Timer = null
var _body_builder: RefCounted = preload("res://scenes/vehicles/helicopter_body_builder.gd").new()
var _tracers: Array[MeshInstance3D] = []
var _rotor_audio: AudioStreamPlayer3D = null
var _rotor_phase := 0.0
var _rotor_noise_state := 0.0


func _ready() -> void:
	_rng.randomize()
	add_to_group("police_helicopter")
	collision_layer = 0
	collision_mask = 2
	_build_scene_tree()
	_setup_audio()
	_start_shoot_timer()


func _physics_process(delta: float) -> void:
	if not _player:
		_player = (get_tree().get_first_node_in_group("player") as Node3D)
		if not _player:
			return

	# Spin rotors (visual only)
	if _rotor_pivot:
		_rotor_pivot.rotation.y += MAIN_ROTOR_SPEED * delta
	if _tail_rotor_pivot:
		_tail_rotor_pivot.rotation.x += TAIL_ROTOR_SPEED * delta

	match _state:
		HeliState.APPROACH:
			_process_approach(delta)
		HeliState.ORBIT:
			_process_orbit(delta)
		HeliState.DESPAWNING:
			_process_despawn(delta)

	# Searchlight always tracks player (except when despawning)
	if _state != HeliState.DESPAWNING:
		_update_searchlight()

	move_and_slide()


func _process(_delta: float) -> void:
	_fill_rotor_audio()


func _process_approach(_delta: float) -> void:
	var target := _get_player_pos()
	var desired := Vector3(target.x, FLIGHT_HEIGHT, target.z)
	var to_target := desired - global_position
	var h_dist := Vector2(to_target.x, to_target.z).length()

	if h_dist < ORBIT_ENTER_DIST:
		_state = HeliState.ORBIT
		var rel := global_position - Vector3(target.x, 0.0, target.z)
		_orbit_angle = atan2(rel.x, rel.z)
		return

	var dir := to_target.normalized()
	velocity = dir * minf(APPROACH_SPEED, h_dist * 2.0)
	velocity = velocity.limit_length(MAX_SPEED)
	velocity.y = (FLIGHT_HEIGHT - global_position.y) * ALTITUDE_LERP

	_apply_body_tilt()


func _process_orbit(delta: float) -> void:
	var target := _get_player_pos()
	var h_dist := Vector2(global_position.x - target.x, global_position.z - target.z).length()

	if h_dist > ORBIT_RADIUS * 2.0:
		_state = HeliState.APPROACH
		return

	_orbit_angle += ORBIT_SPEED * delta
	if _orbit_angle > TAU:
		_orbit_angle -= TAU

	var orbit_x := target.x + sin(_orbit_angle) * ORBIT_RADIUS
	var orbit_z := target.z + cos(_orbit_angle) * ORBIT_RADIUS
	var desired := Vector3(orbit_x, FLIGHT_HEIGHT, orbit_z)

	var to_desired := desired - global_position
	velocity = to_desired * 4.0
	velocity = velocity.limit_length(MAX_SPEED)
	velocity.y = (FLIGHT_HEIGHT - global_position.y) * ALTITUDE_LERP

	_apply_body_tilt()


func _process_despawn(_delta: float) -> void:
	velocity = Vector3(0.0, DESPAWN_ASCEND_SPEED, 0.0)
	if global_position.y > DESPAWN_HEIGHT:
		queue_free()


func _apply_body_tilt() -> void:
	var h_vel := Vector2(velocity.x, velocity.z)
	if h_vel.length() > 1.0:
		var move_angle := atan2(h_vel.x, h_vel.y)
		rotation.y = move_angle
		rotation.x = -TILT_ANGLE
	else:
		rotation.x = lerpf(rotation.x, 0.0, 0.1)


func _update_searchlight() -> void:
	if not _spotlight or not _player:
		return
	var target := _get_player_pos()
	_spotlight.look_at(target, Vector3.UP)


func _start_shoot_timer() -> void:
	_shoot_timer = Timer.new()
	_shoot_timer.name = "ShootTimer"
	_shoot_timer.one_shot = true
	_shoot_timer.timeout.connect(_on_shoot_timer_timeout)
	add_child(_shoot_timer)
	_shoot_timer.start(_rng.randf_range(SHOOT_INTERVAL_MIN, SHOOT_INTERVAL_MAX))


func _on_shoot_timer_timeout() -> void:
	if _state == HeliState.DESPAWNING or not _player:
		return
	if GameManager.is_dead:
		return

	_try_shoot()

	_shoot_timer.start(_rng.randf_range(SHOOT_INTERVAL_MIN, SHOOT_INTERVAL_MAX))


func _try_shoot() -> void:
	var target := _get_player_pos()
	var from := global_position

	# LOS check -- buildings block shots
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, target)
	query.collision_mask = LOS_MASK
	var result := space.intersect_ray(query)
	if not result.is_empty():
		return

	var spread_offset := Vector3(
		_rng.randf_range(-SHOOT_SPREAD, SHOOT_SPREAD),
		0.0,
		_rng.randf_range(-SHOOT_SPREAD, SHOOT_SPREAD),
	)
	var actual_target := target + spread_offset

	_spawn_tracer(from, actual_target)
	_play_shoot_sound()

	if _rng.randf() < SHOOT_HIT_CHANCE:
		GameManager.take_damage(SHOOT_DAMAGE)


func _spawn_tracer(from_pos: Vector3, to_pos: Vector3) -> void:
	var tracer := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	var dist := from_pos.distance_to(to_pos)
	cyl.top_radius = TRACER_RADIUS
	cyl.bottom_radius = TRACER_RADIUS
	cyl.height = dist
	cyl.radial_segments = 4
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.95, 0.4, 0.8)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.9, 0.3)
	mat.emission_energy_multiplier = 2.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cyl.material = mat
	tracer.mesh = cyl
	tracer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var midpoint := (from_pos + to_pos) * 0.5
	get_tree().current_scene.add_child(tracer)
	tracer.global_position = midpoint
	var dir := (to_pos - from_pos).normalized()
	if absf(dir.dot(Vector3.UP)) < 0.999:
		tracer.look_at(tracer.global_position + dir, Vector3.UP)
	else:
		tracer.look_at(tracer.global_position + dir, Vector3.FORWARD)
	tracer.rotate_object_local(Vector3.RIGHT, PI / 2.0)

	_tracers.append(tracer)
	get_tree().create_timer(TRACER_FADE_TIME).timeout.connect(
		func() -> void:
			if is_instance_valid(self):
				_tracers.erase(tracer)
			if is_instance_valid(tracer):
				tracer.queue_free()
	)


func _play_shoot_sound() -> void:
	var asp := AudioStreamPlayer3D.new()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.2
	asp.stream = gen
	asp.max_distance = 80.0
	asp.bus = "Ambient"
	add_child(asp)
	asp.play()

	var playback: AudioStreamGeneratorPlayback = asp.get_stream_playback()
	var shoot_rng := RandomNumberGenerator.new()
	shoot_rng.randomize()

	var rate := 22050.0
	var frames := int(rate * 0.12)
	var snap_end := int(rate * 0.003)
	var filter_state := 0.0

	for i in range(frames):
		var t := float(i) / float(frames)
		var sample := 0.0

		if i < snap_end:
			var snap_env := 1.0 - float(i) / float(snap_end)
			sample += (shoot_rng.randf() - 0.5) * 0.5 * snap_env

		var tail_env := exp(-t * 12.0)
		var noise := (shoot_rng.randf() - 0.5) * 0.2 * tail_env
		filter_state += 0.15 * (noise - filter_state)
		sample += filter_state

		playback.push_frame(Vector2(sample, sample))

	get_tree().create_timer(0.3).timeout.connect(
		func() -> void:
			if is_instance_valid(asp):
				asp.queue_free()
	)


func _get_player_pos() -> Vector3:
	if _player and "current_vehicle" in _player and _player.current_vehicle:
		return (_player.current_vehicle as Node3D).global_position
	if _player:
		return _player.global_position
	return global_position


func _build_scene_tree() -> void:
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.0, 1.5, 4.0)
	col.shape = box
	add_child(col)

	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.08, 0.1, 0.22)

	var rotor_mat := StandardMaterial3D.new()
	rotor_mat.albedo_color = Color(0.15, 0.15, 0.15)

	var body := Node3D.new()
	body.name = "Body"
	add_child(body)

	var fuselage := MeshInstance3D.new()
	fuselage.name = "FuselageMesh"
	fuselage.mesh = _body_builder.build_fuselage()
	fuselage.material_override = body_mat
	fuselage.cast_shadow = (GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
	body.add_child(fuselage)

	_rotor_pivot = Node3D.new()
	_rotor_pivot.name = "RotorPivot"
	_rotor_pivot.position = Vector3(0.0, 0.85, 0.0)
	add_child(_rotor_pivot)

	var rotor_mesh := MeshInstance3D.new()
	rotor_mesh.name = "RotorMesh"
	rotor_mesh.mesh = _body_builder.build_main_rotor()
	rotor_mesh.material_override = rotor_mat
	_rotor_pivot.add_child(rotor_mesh)

	_tail_rotor_pivot = Node3D.new()
	_tail_rotor_pivot.name = "TailRotorPivot"
	_tail_rotor_pivot.position = Vector3(0.3, 0.65, 5.0)
	add_child(_tail_rotor_pivot)

	var tail_rotor_mesh := MeshInstance3D.new()
	tail_rotor_mesh.name = "TailRotorMesh"
	tail_rotor_mesh.mesh = _body_builder.build_tail_rotor()
	tail_rotor_mesh.material_override = rotor_mat
	_tail_rotor_pivot.add_child(tail_rotor_mesh)

	_spotlight = SpotLight3D.new()
	_spotlight.name = "Searchlight"
	_spotlight.spot_range = SPOTLIGHT_RANGE
	_spotlight.spot_angle = SPOTLIGHT_ANGLE
	_spotlight.light_energy = SPOTLIGHT_ENERGY
	_spotlight.shadow_enabled = true
	_spotlight.position = Vector3(0.0, -0.5, -1.0)
	add_child(_spotlight)


func _setup_audio() -> void:
	_rotor_audio = AudioStreamPlayer3D.new()
	_rotor_audio.name = "RotorAudio"
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.1
	_rotor_audio.stream = gen
	_rotor_audio.bus = "SFX"
	_rotor_audio.max_distance = 120.0
	_rotor_audio.attenuation_model = (AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE)
	add_child(_rotor_audio)
	_rotor_audio.play()


func _fill_rotor_audio() -> void:
	if not _rotor_audio:
		return
	var playback := _rotor_audio.get_stream_playback() as AudioStreamGeneratorPlayback
	if not playback:
		return

	var frames_available := playback.get_frames_available()
	var rate := 22050.0
	var blade_freq := 20.0
	var noise_alpha := 0.04

	for _i in range(frames_available):
		_rotor_phase += blade_freq / rate
		if _rotor_phase > 1.0:
			_rotor_phase -= 1.0
		var pulse := sin(_rotor_phase * TAU)
		pulse = pulse * pulse * pulse * signf(pulse)
		var blade_sample := pulse * 0.25

		var noise := _rng.randf() - 0.5
		_rotor_noise_state += noise_alpha * (noise - _rotor_noise_state)
		var wind_sample := _rotor_noise_state * 0.15

		var sample := blade_sample + wind_sample
		playback.push_frame(Vector2(sample, sample))


func begin_despawn() -> void:
	_state = HeliState.DESPAWNING
	if _shoot_timer:
		_shoot_timer.stop()
