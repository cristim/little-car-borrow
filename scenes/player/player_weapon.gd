extends Node
## Handles player shooting via raycast from the active camera center.
## Supports multiple weapon types with switching, spread, and auto-fire.
## Works both on foot and from inside a vehicle.

const WEAPONS := [
	{
		"name": "Pistol", "range": 50.0, "damage": 25.0, "cooldown": 0.3,
		"auto": false, "spread": 0.0, "pellets": 1, "crime_mult": 1.0,
		"body": Vector3(0.06, 0.06, 0.2), "muzzle_z": -0.2,
		"snap_dur": 0.005, "body_dur": 0.06, "tail_decay": 6.0,
		"base_freq": 200.0, "end_freq": 60.0, "elbow": -0.05,
	},
	{
		"name": "SMG", "range": 40.0, "damage": 12.0, "cooldown": 0.08,
		"auto": true, "spread": 0.03, "pellets": 1, "crime_mult": 1.0,
		"body": Vector3(0.06, 0.08, 0.25), "muzzle_z": -0.25,
		"snap_dur": 0.003, "body_dur": 0.03, "tail_decay": 10.0,
		"base_freq": 280.0, "end_freq": 100.0, "elbow": -0.05,
	},
	{
		"name": "Shotgun", "range": 25.0, "damage": 60.0, "cooldown": 0.8,
		"auto": false, "spread": 0.08, "pellets": 6, "crime_mult": 1.5,
		"body": Vector3(0.08, 0.06, 0.3), "muzzle_z": -0.3,
		"snap_dur": 0.008, "body_dur": 0.08, "tail_decay": 4.0,
		"base_freq": 160.0, "end_freq": 40.0, "elbow": -0.4,
	},
	{
		"name": "Rifle", "range": 100.0, "damage": 40.0, "cooldown": 0.5,
		"auto": false, "spread": 0.005, "pellets": 1, "crime_mult": 1.2,
		"body": Vector3(0.04, 0.04, 0.4), "muzzle_z": -0.4,
		"snap_dur": 0.004, "body_dur": 0.05, "tail_decay": 5.0,
		"base_freq": 240.0, "end_freq": 50.0, "elbow": -0.3,
	},
]
const VEHICLE_IMPULSE := 80.0
const MAX_WORLD_DECALS := 30
const WORLD_DECAL_LIFETIME := 15.0
const MAX_BLOOD_DECALS := 20
const BLOOD_DECAL_LIFETIME := 20.0
const MUZZLE_FLASH_TIME := 0.06

var _ragdoll_script: GDScript = preload(
	"res://scenes/pedestrians/pedestrian_ragdoll.gd"
)
var _builder_script: GDScript = preload(
	"res://src/weapon_mesh_builder.gd"
)
var _current_idx := 0
var _armed := false
var _unlocked: Array[bool] = [true, true, true, true]
var _rng := RandomNumberGenerator.new()
var _cooldown := 0.0
var _flash_timer := 0.0
var _muzzle_flash: MeshInstance3D = null
var _gun_mesh: Node3D = null
var _elbow: Node3D = null
var _player_model: Node3D = null
var _world_decals: Array[MeshInstance3D] = []
var _blood_decals: Array[MeshInstance3D] = []


func _ready() -> void:
	_rng.randomize()
	_player_model = owner.get_node_or_null("PlayerModel")
	if _player_model:
		_elbow = _player_model.get_node_or_null(
			"RightShoulderPivot/RightElbowPivot"
		)


func _process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown -= delta

	if _flash_timer > 0.0:
		_flash_timer -= delta
		if _flash_timer <= 0.0 and _muzzle_flash:
			_muzzle_flash.visible = false

	if GameManager.is_dead:
		return

	# Weapon key: draw weapon or switch; press same key again to holster
	for i in range(WEAPONS.size()):
		var action: String = "weapon_%d" % (i + 1)
		if Input.is_action_just_pressed(action) and _unlocked[i]:
			if _armed and i == _current_idx:
				_holster()
			else:
				_draw_weapon(i)
			return

	if Input.is_action_just_pressed("weapon_next"):
		_cycle_weapon(1)
		return
	if Input.is_action_just_pressed("weapon_prev"):
		_cycle_weapon(-1)
		return

	if not _armed:
		return

	if _cooldown > 0.0:
		return

	var w: Dictionary = WEAPONS[_current_idx]
	var is_auto: bool = w.get("auto", false)
	var should_fire := false
	if is_auto:
		should_fire = Input.is_action_pressed("shoot")
	else:
		should_fire = Input.is_action_just_pressed("shoot")

	if should_fire:
		_shoot()
		var cd: float = w.get("cooldown", 0.3)
		_cooldown = cd


func _draw_weapon(idx: int) -> void:
	if idx < 0 or idx >= WEAPONS.size():
		return
	if not _unlocked[idx]:
		return
	_current_idx = idx
	_armed = true
	_setup_gun_mesh()
	EventBus.weapon_switched.emit(idx)


func _holster() -> void:
	_armed = false
	if _gun_mesh and is_instance_valid(_gun_mesh):
		_gun_mesh.queue_free()
		_gun_mesh = null
	if _muzzle_flash and is_instance_valid(_muzzle_flash):
		_muzzle_flash.queue_free()
		_muzzle_flash = null
	EventBus.weapon_switched.emit(-1)


func _switch_weapon(idx: int) -> void:
	if idx == _current_idx and _armed:
		return
	_draw_weapon(idx)


func _cycle_weapon(direction: int) -> void:
	var idx := _current_idx
	for _i in range(WEAPONS.size()):
		idx = (idx + direction) % WEAPONS.size()
		if idx < 0:
			idx += WEAPONS.size()
		if _unlocked[idx]:
			_switch_weapon(idx)
			return


func unlock_weapon(idx: int) -> void:
	if idx < 0 or idx >= WEAPONS.size():
		return
	if _unlocked[idx]:
		return
	_unlocked[idx] = true
	EventBus.weapon_unlocked.emit(idx)
	var wname: String = WEAPONS[idx]["name"]
	EventBus.show_notification.emit(
		"%s unlocked! Press %d to equip" % [wname, idx + 1], 3.0
	)


func _shoot() -> void:
	var camera := get_viewport().get_camera_3d()
	if not camera:
		return

	var w: Dictionary = WEAPONS[_current_idx]
	var shoot_range: float = w.get("range", 50.0)
	var shoot_damage: float = w.get("damage", 25.0)
	var spread: float = w.get("spread", 0.0)
	var pellets: int = w.get("pellets", 1)
	var crime_mult: float = w.get("crime_mult", 1.0)

	var vp_size := get_viewport().get_visible_rect().size
	var crosshair_screen := Vector2(vp_size.x * 0.5, vp_size.y * 0.35)
	var from := camera.project_ray_origin(crosshair_screen)
	var base_dir := camera.project_ray_normal(crosshair_screen)

	var space: PhysicsDirectSpaceState3D = (
		owner.get_world_3d().direct_space_state
	)

	if _muzzle_flash:
		_muzzle_flash.visible = true
		_flash_timer = MUZZLE_FLASH_TIME

	_play_gunshot()

	for _p in range(pellets):
		var dir := base_dir
		if spread > 0.0:
			dir = _apply_spread(dir, spread)

		var to := from + dir * shoot_range

		var query := PhysicsRayQueryParameters3D.create(from, to)
		query.collision_mask = 0b01111111
		query.exclude = [owner.get_rid()]
		if (
			owner.current_vehicle
			and is_instance_valid(owner.current_vehicle)
		):
			query.exclude.append(
				(owner.current_vehicle as CollisionObject3D).get_rid()
			)

		var result: Dictionary = space.intersect_ray(query)
		if result.is_empty():
			continue

		var body: Node = result["collider"]
		var hit_pos: Vector3 = result["position"]
		var hit_normal: Vector3 = result["normal"]
		var pellet_dmg: float = shoot_damage / float(pellets)

		if body.is_in_group("pedestrian"):
			_spawn_ragdoll(body, dir)
			_spawn_blood(hit_pos)
			EventBus.pedestrian_killed.emit(body)
			var heat: int = roundi(35.0 * crime_mult)
			EventBus.crime_committed.emit("shoot_pedestrian", heat)
			body.queue_free()
		elif body.is_in_group("police_officer"):
			_spawn_ragdoll(body, dir)
			_spawn_blood(hit_pos)
			var heat: int = roundi(60.0 * crime_mult)
			EventBus.crime_committed.emit("shoot_police", heat)
			body.queue_free()
		elif body is RigidBody3D:
			var impulse := dir * VEHICLE_IMPULSE
			(body as RigidBody3D).apply_impulse(
				impulse, hit_pos - body.global_position
			)
			var vh := body.get_node_or_null("VehicleHealth")
			if vh:
				vh.take_damage(pellet_dmg, hit_pos, hit_normal)
			var heat: int = roundi(15.0 * crime_mult)
			EventBus.crime_committed.emit("shoot_vehicle", heat)
		elif body is StaticBody3D:
			_spawn_world_decal(hit_pos, hit_normal)


func _apply_spread(dir: Vector3, spread: float) -> Vector3:
	var right := dir.cross(Vector3.UP).normalized()
	var up := right.cross(dir).normalized()
	var offset_x: float = _rng.randf_range(-spread, spread)
	var offset_y: float = _rng.randf_range(-spread, spread)
	return (dir + right * offset_x + up * offset_y).normalized()


func _spawn_ragdoll(target: Node, shoot_dir: Vector3) -> void:
	var ragdoll := RigidBody3D.new()
	ragdoll.set_script(_ragdoll_script)
	ragdoll.position = (target as Node3D).global_position
	ragdoll.rotation = (target as Node3D).global_rotation
	ragdoll.copy_visual_from(target)
	get_tree().current_scene.add_child(ragdoll)
	var impulse := shoot_dir * 15.0
	impulse.y = 0.0
	ragdoll.apply_central_impulse(impulse)


func _spawn_decal(
	pos: Vector3,
	normal: Vector3,
	size: float,
	color: Color,
) -> MeshInstance3D:
	var decal := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(size, size)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	plane.material = mat
	decal.mesh = plane
	decal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_tree().current_scene.add_child(decal)
	decal.global_position = pos + normal * 0.01
	if normal.abs() != Vector3.UP:
		decal.look_at(decal.global_position + normal, Vector3.UP)
	else:
		decal.look_at(decal.global_position + normal, Vector3.FORWARD)
	decal.rotate_object_local(Vector3.RIGHT, -PI / 2.0)
	return decal


func _spawn_world_decal(pos: Vector3, normal: Vector3) -> void:
	var decal := _spawn_decal(pos, normal, 0.12, Color(0.08, 0.08, 0.08))
	_world_decals.append(decal)
	if _world_decals.size() > MAX_WORLD_DECALS:
		var old: MeshInstance3D = _world_decals.pop_front()
		if is_instance_valid(old):
			old.queue_free()
	get_tree().create_timer(WORLD_DECAL_LIFETIME).timeout.connect(
		func() -> void:
			_world_decals.erase(decal)
			if is_instance_valid(decal):
				decal.queue_free()
	)


func _spawn_blood(hit_pos: Vector3) -> void:
	var blood_pos := Vector3(hit_pos.x, 0.02, hit_pos.z)
	var decal := _spawn_decal(
		blood_pos, Vector3.UP, 0.2, Color(0.4, 0.02, 0.02)
	)
	_blood_decals.append(decal)
	if _blood_decals.size() > MAX_BLOOD_DECALS:
		var old: MeshInstance3D = _blood_decals.pop_front()
		if is_instance_valid(old):
			old.queue_free()
	get_tree().create_timer(BLOOD_DECAL_LIFETIME).timeout.connect(
		func() -> void:
			_blood_decals.erase(decal)
			if is_instance_valid(decal):
				decal.queue_free()
	)


func _setup_gun_mesh() -> void:
	if not _elbow:
		return

	if _gun_mesh and is_instance_valid(_gun_mesh):
		_gun_mesh.queue_free()
		_gun_mesh = null
	if _muzzle_flash and is_instance_valid(_muzzle_flash):
		_muzzle_flash.queue_free()
		_muzzle_flash = null

	var w: Dictionary = WEAPONS[_current_idx]
	var weapon_name: String = w.get("name", "Pistol")

	var builder: RefCounted = _builder_script.new()
	_gun_mesh = builder.build(weapon_name)
	_gun_mesh.position = Vector3(0.0, -0.2, -0.08)
	# Barrel is built along -Z; forearm points along -Y of elbow pivot
	_gun_mesh.rotation.x = -PI / 2.0
	_elbow.add_child(_gun_mesh)

	var muzzle_local: Vector3 = _gun_mesh.get_meta("muzzle_local_pos")
	# Transform muzzle offset by gun root's rotation into elbow space
	var flash_pos := _gun_mesh.position + _gun_mesh.transform.basis * muzzle_local

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
	_muzzle_flash.position = flash_pos
	_muzzle_flash.visible = false
	_elbow.add_child(_muzzle_flash)


func _play_gunshot() -> void:
	var w: Dictionary = WEAPONS[_current_idx]
	var snap_dur: float = w.get("snap_dur", 0.005)
	var body_dur: float = w.get("body_dur", 0.06)
	var tail_decay: float = w.get("tail_decay", 6.0)
	var base_freq: float = w.get("base_freq", 200.0)
	var end_freq: float = w.get("end_freq", 60.0)

	var asp := AudioStreamPlayer3D.new()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.5
	asp.stream = gen
	asp.max_distance = 60.0
	asp.bus = "SFX"
	owner.add_child(asp)
	asp.play()

	var playback: AudioStreamGeneratorPlayback = asp.get_stream_playback()

	var rate := 22050.0
	var total_frames := int(rate * 0.4)
	var snap_end := int(rate * snap_dur)
	var body_end := int(rate * body_dur)
	var phase := 0.0
	var filter_state := 0.0

	for i in range(total_frames):
		var t := float(i) / rate
		var sample := 0.0

		if i < snap_end:
			var snap_env := 1.0 - float(i) / float(snap_end)
			sample += (_rng.randf() - 0.5) * 0.7 * snap_env * snap_env
		if i < body_end:
			var body_t := float(i) / float(body_end)
			var body_env := (1.0 - body_t) * (1.0 - body_t)
			var freq := lerpf(base_freq, end_freq, body_t)
			phase += freq / rate
			if phase > 1.0:
				phase -= 1.0
			sample += sin(phase * TAU) * 0.5 * body_env

		if i >= snap_end:
			var tail_t := float(i - snap_end) / float(
				total_frames - snap_end
			)
			var tail_env := exp(-tail_t * tail_decay)
			var noise := (_rng.randf() - 0.5) * 0.25 * tail_env
			filter_state += 0.08 * (noise - filter_state)
			sample += filter_state

		playback.push_frame(Vector2(sample, sample))

	get_tree().create_timer(0.5).timeout.connect(asp.queue_free)
