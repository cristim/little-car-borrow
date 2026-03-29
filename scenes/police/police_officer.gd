extends CharacterBody3D
## On-foot police officer that chases and shoots the player.
## Spawned by police vehicles when close enough during pursuit.

const CHASE_SPEED := 5.5
const SHOOT_RANGE := 30.0
const SHOOT_COOLDOWN := 1.2
const SHOOT_DAMAGE := 8.0
const DESPAWN_DIST := 80.0
const GRAVITY := 9.8
const MUZZLE_FLASH_TIME := 0.08

var _player: Node3D = null
var _shoot_timer := 0.0
var _flash_timer := 0.0
var _shoot_pose_timer := 0.0
var _anim_phase := 0.0
var _muzzle_flash: MeshInstance3D
var _left_shoulder: Node3D
var _right_shoulder: Node3D
var _left_hip: Node3D
var _right_hip: Node3D
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

	# Limb animation
	_animate_limbs(delta, h_dist)


func _shoot(target_pos: Vector3) -> void:
	# Line-of-sight check — cast against ground (1) + static geometry (2).
	# If anything is hit the player is behind a wall; don't fire at all.
	var muzzle := global_position + Vector3(0.0, 1.2, 0.0)
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(muzzle, target_pos, 3)
	query.exclude = [self]
	if not space.intersect_ray(query).is_empty():
		return

	# Accuracy check — miss sometimes
	if _rng.randf() < 0.4:
		GameManager.take_damage(SHOOT_DAMAGE)

	# Muzzle flash visual
	if _muzzle_flash:
		_muzzle_flash.visible = true
		_flash_timer = MUZZLE_FLASH_TIME

	# Raise right arm to aim
	_shoot_pose_timer = 0.4

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


func _animate_limbs(delta: float, h_dist: float) -> void:
	if not _left_shoulder:
		return

	# Shoot pose timer
	if _shoot_pose_timer > 0.0:
		_shoot_pose_timer -= delta

	# Run cycle when moving
	if h_dist > 2.0:
		_anim_phase += delta * CHASE_SPEED * 6.0
		var swing := sin(_anim_phase) * 0.5
		_left_shoulder.rotation.x = swing
		_left_hip.rotation.x = -swing
		_right_hip.rotation.x = swing
		# Right arm follows walk cycle unless shooting
		if _shoot_pose_timer <= 0.0:
			_right_shoulder.rotation.x = -swing
		else:
			_right_shoulder.rotation.x = -PI / 2.0
	else:
		# Decay to idle
		_left_shoulder.rotation.x = lerpf(
			_left_shoulder.rotation.x, 0.0, delta * 8.0
		)
		_left_hip.rotation.x = lerpf(
			_left_hip.rotation.x, 0.0, delta * 8.0
		)
		_right_hip.rotation.x = lerpf(
			_right_hip.rotation.x, 0.0, delta * 8.0
		)
		if _shoot_pose_timer <= 0.0:
			_right_shoulder.rotation.x = lerpf(
				_right_shoulder.rotation.x, 0.0, delta * 8.0
			)
		else:
			_right_shoulder.rotation.x = -PI / 2.0
		_anim_phase = 0.0


func _build_model() -> void:
	var model := Node3D.new()
	model.name = "OfficerModel"
	add_child(model)

	var uniform_mat := StandardMaterial3D.new()
	uniform_mat.albedo_color = Color(0.1, 0.12, 0.25)

	var skin_mat := StandardMaterial3D.new()
	skin_mat.albedo_color = Color(0.75, 0.6, 0.45)

	var gun_mat := StandardMaterial3D.new()
	gun_mat.albedo_color = Color(0.1, 0.1, 0.1)

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

	# Hat
	var hat := MeshInstance3D.new()
	var hat_mesh := BoxMesh.new()
	hat_mesh.size = Vector3(0.26, 0.08, 0.26)
	hat.mesh = hat_mesh
	hat.material_override = uniform_mat
	hat.position = Vector3(0.0, 1.51, 0.0)
	model.add_child(hat)

	# Arm mesh (shared)
	var arm_mesh := CylinderMesh.new()
	arm_mesh.top_radius = 0.06
	arm_mesh.bottom_radius = 0.06
	arm_mesh.height = 0.5

	# Left shoulder pivot
	_left_shoulder = Node3D.new()
	_left_shoulder.name = "LeftShoulderPivot"
	_left_shoulder.position = Vector3(-0.25, 1.2, 0.0)
	model.add_child(_left_shoulder)
	var l_arm := MeshInstance3D.new()
	l_arm.mesh = arm_mesh
	l_arm.material_override = uniform_mat
	l_arm.position = Vector3(0.0, -0.25, 0.0)
	_left_shoulder.add_child(l_arm)

	# Right shoulder pivot (holds gun + muzzle flash)
	_right_shoulder = Node3D.new()
	_right_shoulder.name = "RightShoulderPivot"
	_right_shoulder.position = Vector3(0.25, 1.2, 0.0)
	model.add_child(_right_shoulder)
	var r_arm := MeshInstance3D.new()
	r_arm.mesh = arm_mesh
	r_arm.material_override = uniform_mat
	r_arm.position = Vector3(0.0, -0.25, 0.0)
	_right_shoulder.add_child(r_arm)

	# Gun on right arm
	var gun := MeshInstance3D.new()
	var g_mesh := BoxMesh.new()
	g_mesh.size = Vector3(0.06, 0.06, 0.2)
	gun.mesh = g_mesh
	gun.material_override = gun_mat
	gun.position = Vector3(0.0, -0.45, -0.08)
	_right_shoulder.add_child(gun)

	# Muzzle flash on right arm
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
	_muzzle_flash.position = Vector3(0.0, -0.45, -0.2)
	_muzzle_flash.visible = false
	_right_shoulder.add_child(_muzzle_flash)

	# Leg mesh (shared)
	var leg_mesh := CylinderMesh.new()
	leg_mesh.top_radius = 0.08
	leg_mesh.bottom_radius = 0.08
	leg_mesh.height = 0.75

	# Left hip pivot
	_left_hip = Node3D.new()
	_left_hip.name = "LeftHipPivot"
	_left_hip.position = Vector3(-0.1, 0.75, 0.0)
	model.add_child(_left_hip)
	var l_leg := MeshInstance3D.new()
	l_leg.mesh = leg_mesh
	l_leg.material_override = uniform_mat
	l_leg.position = Vector3(0.0, -0.375, 0.0)
	_left_hip.add_child(l_leg)

	# Right hip pivot
	_right_hip = Node3D.new()
	_right_hip.name = "RightHipPivot"
	_right_hip.position = Vector3(0.1, 0.75, 0.0)
	model.add_child(_right_hip)
	var r_leg := MeshInstance3D.new()
	r_leg.mesh = leg_mesh
	r_leg.material_override = uniform_mat
	r_leg.position = Vector3(0.0, -0.375, 0.0)
	_right_hip.add_child(r_leg)
