extends Node
## Handles player shooting via raycast from the active camera center.
## Works both on foot and from inside a vehicle.

const SHOOT_RANGE := 50.0
const SHOOT_COOLDOWN := 0.3
const SHOOT_DAMAGE := 25.0
const VEHICLE_IMPULSE := 500.0
const MUZZLE_FLASH_TIME := 0.06
const AIM_POSE_TIME := 0.3

var _ragdoll_script: GDScript = preload(
	"res://scenes/pedestrians/pedestrian_ragdoll.gd"
)
var _cooldown := 0.0
var _flash_timer := 0.0
var _muzzle_flash: MeshInstance3D = null
var _player_model: Node3D = null


func _ready() -> void:
	_player_model = owner.get_node_or_null("PlayerModel")
	_setup_gun_mesh()


func _process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown -= delta

	if _flash_timer > 0.0:
		_flash_timer -= delta
		if _flash_timer <= 0.0 and _muzzle_flash:
			_muzzle_flash.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if GameManager.is_dead:
		return
	if event.is_action_pressed("shoot") and _cooldown <= 0.0:
		_shoot()
		_cooldown = SHOOT_COOLDOWN


func _shoot() -> void:
	var camera := get_viewport().get_camera_3d()
	if not camera:
		return

	var from := camera.global_position
	var dir := -camera.global_transform.basis.z
	var to := from + dir * SHOOT_RANGE

	var space: PhysicsDirectSpaceState3D = owner.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	# Layers 1-7 (Ground, Static, PlayerFoot, PlayerVehicle, NPCVehicle,
	# Pedestrian, Police)
	query.collision_mask = 0b01111111
	query.exclude = [owner.get_rid()]
	# Also exclude current vehicle if driving
	if owner.current_vehicle and is_instance_valid(owner.current_vehicle):
		query.exclude.append(
			(owner.current_vehicle as CollisionObject3D).get_rid()
		)

	var result: Dictionary = space.intersect_ray(query)

	# Show muzzle flash
	if _muzzle_flash:
		_muzzle_flash.visible = true
		_flash_timer = MUZZLE_FLASH_TIME

	# Aiming pose on player model
	if _player_model and _player_model.has_method("set_aiming"):
		_player_model.set_aiming(AIM_POSE_TIME)

	# Gunshot sound
	_play_gunshot()

	if result.is_empty():
		return

	var body: Node = result["collider"]
	var hit_pos: Vector3 = result["position"]

	if body.is_in_group("pedestrian"):
		_spawn_ragdoll(body, dir)
		EventBus.pedestrian_killed.emit(body)
		EventBus.crime_committed.emit("shoot_pedestrian", 35)
		body.queue_free()
	elif body.is_in_group("police_officer"):
		_spawn_ragdoll(body, dir)
		EventBus.crime_committed.emit("shoot_police", 60)
		body.queue_free()
	elif body is RigidBody3D:
		var impulse := dir * VEHICLE_IMPULSE
		(body as RigidBody3D).apply_impulse(impulse, hit_pos - body.global_position)
		EventBus.crime_committed.emit("shoot_vehicle", 15)


func _spawn_ragdoll(target: Node, shoot_dir: Vector3) -> void:
	var ragdoll := RigidBody3D.new()
	ragdoll.set_script(_ragdoll_script)
	ragdoll.position = (target as Node3D).global_position
	ragdoll.rotation = (target as Node3D).global_rotation
	ragdoll.copy_visual_from(target)
	get_tree().current_scene.add_child(ragdoll)
	# Launch ragdoll in the direction of the shot
	var impulse := shoot_dir * 6.0
	impulse.y = 3.0
	ragdoll.apply_central_impulse(impulse * ragdoll.mass)


func _setup_gun_mesh() -> void:
	if not _player_model:
		return
	var elbow := _player_model.get_node_or_null(
		"RightShoulderPivot/RightElbowPivot"
	)
	if not elbow:
		return

	# Gun body
	var gun := MeshInstance3D.new()
	gun.name = "GunMesh"
	var gun_mesh := BoxMesh.new()
	gun_mesh.size = Vector3(0.06, 0.06, 0.2)
	var gun_mat := StandardMaterial3D.new()
	gun_mat.albedo_color = Color(0.1, 0.1, 0.1)
	gun_mesh.material = gun_mat
	gun.mesh = gun_mesh
	gun.position = Vector3(0.0, -0.2, -0.08)
	elbow.add_child(gun)

	# Muzzle flash
	_muzzle_flash = MeshInstance3D.new()
	_muzzle_flash.name = "MuzzleFlash"
	var flash_mesh := SphereMesh.new()
	flash_mesh.radius = 0.06
	flash_mesh.height = 0.12
	flash_mesh.radial_segments = 4
	flash_mesh.rings = 2
	var flash_mat := StandardMaterial3D.new()
	flash_mat.albedo_color = Color(1.0, 0.9, 0.3)
	flash_mat.emission_enabled = true
	flash_mat.emission = Color(1.0, 0.8, 0.2)
	flash_mat.emission_energy_multiplier = 3.0
	flash_mesh.material = flash_mat
	_muzzle_flash.mesh = flash_mesh
	_muzzle_flash.position = Vector3(0.0, -0.2, -0.2)
	_muzzle_flash.visible = false
	elbow.add_child(_muzzle_flash)


func _play_gunshot() -> void:
	var asp := AudioStreamPlayer3D.new()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.15
	asp.stream = gen
	asp.max_distance = 50.0
	asp.bus = "Ambient"
	owner.add_child(asp)
	asp.play()

	var playback: AudioStreamGeneratorPlayback = asp.get_stream_playback()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var frames := int(22050.0 * 0.08)
	for i in range(frames):
		var t := float(i) / float(frames)
		var env := (1.0 - t) * (1.0 - t)
		var noise := (rng.randf() - 0.5) * 0.4 * env
		playback.push_frame(Vector2(noise, noise))

	get_tree().create_timer(0.3).timeout.connect(asp.queue_free)
