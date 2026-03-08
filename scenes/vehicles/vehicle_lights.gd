extends Node3D
## Adds headlights, tail lights, and reverse lights to a vehicle.
## Attach as child of the vehicle's Body node.
## Call initialize(vehicle_ref) after adding to tree.

const HEADLIGHT_OFFSETS := [Vector3(-0.55, 0.05, -2.1), Vector3(0.55, 0.05, -2.1)]
const TAILLIGHT_OFFSETS := [Vector3(-0.55, 0.3, 2.0), Vector3(0.55, 0.3, 2.0)]
const REVERSE_OFFSETS := [Vector3(-0.4, 0.3, 2.0), Vector3(0.4, 0.3, 2.0)]
const CULL_DISTANCE := 80.0
const REVERSE_SPEED_THRESHOLD := -0.5

var _vehicle: RigidBody3D = null
var _camera: Camera3D = null
var _headlights: Array[SpotLight3D] = []
var _taillights: Array[OmniLight3D] = []
var _reverse_lights: Array[OmniLight3D] = []
var _is_night := false


func _ready() -> void:
	# Headlights (SpotLight3D, front, warm white, night-only)
	for offset in HEADLIGHT_OFFSETS:
		var light := SpotLight3D.new()
		light.position = offset
		light.rotation_degrees.x = -5.0
		light.spot_range = 20.0
		light.spot_angle = 35.0
		light.light_color = Color(1.0, 0.95, 0.8)
		light.light_energy = 2.0
		light.shadow_enabled = false
		light.visible = false
		add_child(light)
		_headlights.append(light)

	# Tail lights (OmniLight3D, rear, red, night-only)
	for offset in TAILLIGHT_OFFSETS:
		var light := OmniLight3D.new()
		light.position = offset
		light.omni_range = 3.0
		light.light_color = Color(1.0, 0.1, 0.05)
		light.light_energy = 0.8
		light.shadow_enabled = false
		light.visible = false
		add_child(light)
		_taillights.append(light)

	# Reverse lights (OmniLight3D, rear, white, on when reversing)
	for offset in REVERSE_OFFSETS:
		var light := OmniLight3D.new()
		light.position = offset
		light.omni_range = 4.0
		light.light_color = Color(1.0, 1.0, 1.0)
		light.light_energy = 0.6
		light.shadow_enabled = false
		light.visible = false
		add_child(light)
		_reverse_lights.append(light)

	# Time-of-day signal + initial state
	EventBus.time_of_day_changed.connect(_on_time_changed)
	_set_night_mode(DayNightManager.is_night() or DayNightManager.is_dusk_or_dawn())


func initialize(vehicle_ref: RigidBody3D) -> void:
	_vehicle = vehicle_ref


func _physics_process(_delta: float) -> void:
	if _vehicle == null or not is_instance_valid(_vehicle):
		return

	# Distance culling — cache camera ref, refresh if stale
	if _camera == null or not is_instance_valid(_camera):
		_camera = get_viewport().get_camera_3d()
	if _camera and global_position.distance_to(_camera.global_position) > CULL_DISTANCE:
		for light in _headlights:
			light.visible = false
		for light in _taillights:
			light.visible = false
		for light in _reverse_lights:
			light.visible = false
		return

	# Restore night-mode lights if within cull distance
	if _is_night:
		for light in _headlights:
			light.visible = true
		for light in _taillights:
			light.visible = true

	# Reverse detection: dot product of velocity onto vehicle forward (-Z)
	var forward_dot: float = _vehicle.linear_velocity.dot(
		-_vehicle.global_transform.basis.z
	)
	var is_reversing: bool = forward_dot < REVERSE_SPEED_THRESHOLD
	for light in _reverse_lights:
		light.visible = is_reversing


func _on_time_changed(_hour: float) -> void:
	_set_night_mode(DayNightManager.is_night() or DayNightManager.is_dusk_or_dawn())


func _set_night_mode(night: bool) -> void:
	_is_night = night
	for light in _headlights:
		light.visible = night
	for light in _taillights:
		light.visible = night
	# When transitioning to day, also turn off reverse lights
	# (they'll re-evaluate next physics frame if still reversing)
	if not night:
		for light in _reverse_lights:
			light.visible = false
