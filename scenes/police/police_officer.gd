extends CharacterBody3D
## On-foot police officer that chases and shoots the player.
## Spawned by police vehicles when close enough during pursuit.

const CHASE_SPEED := 5.5
const SHOOT_RANGE := 30.0
const SHOOT_COOLDOWN := 1.2
const SHOOT_DAMAGE := 8.0
const DESPAWN_DIST := 80.0
const GRAVITY := 20.0
const MUZZLE_FLASH_TIME := 0.08

var _player: Node3D = null
var _shoot_timer := 0.0
var _flash_timer := 0.0
var _muzzle_flash: MeshInstance3D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	add_to_group("police_officer")
	collision_layer = 4  # NPC layer
	collision_mask = 3   # Static + Ground

	_build_model()

	# Collision capsule
	var col := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.3
	shape.height = 1.7
	col.shape = shape
	col.position.y = 0.85
	add_child(col)


func _physics_process(delta: float) -> void:
	if GameManager.is_dead:
		return

	if not _player:
		_player = (
			get_tree().get_first_node_in_group("player")
			as Node3D
		)
		if not _player:
			return

	# Despawn if too far from player
	var target_pos := _get_target_pos()
	var dist := global_position.distance_to(target_pos)
	if dist > DESPAWN_DIST:
		queue_free()
		return

	# Gravity
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0

	# Chase player
	var to_target := target_pos - global_position
	to_target.y = 0.0
	var h_dist := to_target.length()

	if h_dist > 2.0:
		var dir := to_target.normalized()
		velocity.x = dir.x * CHASE_SPEED
		velocity.z = dir.z * CHASE_SPEED
		# Face movement direction
		look_at(
			global_position + Vector3(dir.x, 0.0, dir.z),
			Vector3.UP,
		)
	else:
		velocity.x = 0.0
		velocity.z = 0.0

	move_and_slide()

	# Shooting
	_shoot_timer -= delta
	if h_dist < SHOOT_RANGE and _shoot_timer <= 0.0:
		_shoot(target_pos)
		_shoot_timer = SHOOT_COOLDOWN + _rng.randf_range(-0.2, 0.3)

	# Muzzle flash fadeout
	if _flash_timer > 0.0:
		_flash_timer -= delta
		if _flash_timer <= 0.0 and _muzzle_flash:
			_muzzle_flash.visible = false


func _shoot(_target_pos: Vector3) -> void:
	# Accuracy check — miss sometimes
	var hit := _rng.randf() < 0.4
	if hit:
		GameManager.take_damage(SHOOT_DAMAGE)

	# Muzzle flash visual
	if _muzzle_flash:
		_muzzle_flash.visible = true
		_flash_timer = MUZZLE_FLASH_TIME

	# Gunshot sound via audio generator would be heavy;
	# use a simple AudioStreamPlayer with procedural pop
	_play_gunshot()


func _play_gunshot() -> void:
	var player := AudioStreamPlayer3D.new()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.15
	player.stream = gen
	player.max_distance = 50.0
	player.bus = "Ambient"
	add_child(player)
	player.play()

	var playback: AudioStreamGeneratorPlayback = (
		player.get_stream_playback()
	)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	# Short noise burst = gunshot
	var frames := int(22050.0 * 0.08)
	for i in range(frames):
		var t := float(i) / float(frames)
		var env := (1.0 - t) * (1.0 - t)
		var noise := (rng.randf() - 0.5) * 0.3 * env
		playback.push_frame(Vector2(noise, noise))

	# Auto-cleanup after sound finishes
	get_tree().create_timer(0.3).timeout.connect(player.queue_free)


func _get_target_pos() -> Vector3:
	if _player and "current_vehicle" in _player and _player.current_vehicle:
		return (_player.current_vehicle as Node3D).global_position
	if _player:
		return _player.global_position
	return global_position


func _build_model() -> void:
	var model := Node3D.new()
	model.name = "OfficerModel"
	add_child(model)

	var uniform_mat := StandardMaterial3D.new()
	uniform_mat.albedo_color = Color(0.1, 0.12, 0.25)

	var skin_mat := StandardMaterial3D.new()
	skin_mat.albedo_color = Color(0.75, 0.6, 0.45)

	# Torso
	var torso := MeshInstance3D.new()
	var torso_mesh := BoxMesh.new()
	torso_mesh.size = Vector3(0.38, 0.5, 0.22)
	torso.mesh = torso_mesh
	torso.material_override = uniform_mat
	torso.position = Vector3(0.0, 1.0, 0.0)
	model.add_child(torso)

	# Head
	var head := MeshInstance3D.new()
	var head_mesh := BoxMesh.new()
	head_mesh.size = Vector3(0.22, 0.22, 0.22)
	head.mesh = head_mesh
	head.material_override = skin_mat
	head.position = Vector3(0.0, 1.36, 0.0)
	model.add_child(head)

	# Hat (dark blue cap)
	var hat := MeshInstance3D.new()
	var hat_mesh := BoxMesh.new()
	hat_mesh.size = Vector3(0.26, 0.08, 0.26)
	hat.mesh = hat_mesh
	hat.material_override = uniform_mat
	hat.position = Vector3(0.0, 1.51, 0.0)
	model.add_child(hat)

	# Legs
	var leg_mesh := CylinderMesh.new()
	leg_mesh.top_radius = 0.08
	leg_mesh.bottom_radius = 0.08
	leg_mesh.height = 0.75
	for x_off in [-0.1, 0.1]:
		var leg := MeshInstance3D.new()
		leg.mesh = leg_mesh
		leg.material_override = uniform_mat
		leg.position = Vector3(x_off, 0.375, 0.0)
		model.add_child(leg)

	# Arms
	var arm_mesh := CylinderMesh.new()
	arm_mesh.top_radius = 0.06
	arm_mesh.bottom_radius = 0.06
	arm_mesh.height = 0.55
	for x_off in [-0.25, 0.25]:
		var arm := MeshInstance3D.new()
		arm.mesh = arm_mesh
		arm.material_override = uniform_mat
		arm.position = Vector3(x_off, 0.97, 0.0)
		model.add_child(arm)

	# Gun (small box in right hand)
	var gun := MeshInstance3D.new()
	var gun_mesh := BoxMesh.new()
	gun_mesh.size = Vector3(0.06, 0.06, 0.2)
	gun.mesh = gun_mesh
	var gun_mat := StandardMaterial3D.new()
	gun_mat.albedo_color = Color(0.1, 0.1, 0.1)
	gun.material_override = gun_mat
	gun.position = Vector3(0.25, 0.75, -0.15)
	model.add_child(gun)

	# Muzzle flash (yellow emissive, starts hidden)
	_muzzle_flash = MeshInstance3D.new()
	var flash_mesh := SphereMesh.new()
	flash_mesh.radius = 0.08
	flash_mesh.height = 0.16
	flash_mesh.radial_segments = 4
	flash_mesh.rings = 2
	var flash_mat := StandardMaterial3D.new()
	flash_mat.albedo_color = Color(1.0, 0.9, 0.3)
	flash_mat.emission_enabled = true
	flash_mat.emission = Color(1.0, 0.8, 0.2)
	flash_mat.emission_energy_multiplier = 3.0
	flash_mesh.material = flash_mat
	_muzzle_flash.mesh = flash_mesh
	_muzzle_flash.position = Vector3(0.25, 0.75, -0.28)
	_muzzle_flash.visible = false
	model.add_child(_muzzle_flash)
