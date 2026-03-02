extends AudioStreamPlayer3D
## Procedural tire screech sound triggered by sharp turns or hard braking.

const SAMPLE_RATE := 22050.0
const SLIP_SPEED_THRESHOLD := 20.0
const LATERAL_THRESHOLD := 0.3
const CULL_DISTANCE := 50.0

var _phase := 0.0
var _playback: AudioStreamGeneratorPlayback = null
var _vehicle: Node = null
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_vehicle = get_parent()
	_rng.randomize()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = SAMPLE_RATE
	gen.buffer_length = 0.1
	stream = gen
	bus = "SFX"
	max_distance = 60.0
	attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	play()
	_playback = get_stream_playback()


func _process(_delta: float) -> void:
	if not _playback or not _vehicle:
		return

	# Distance culling
	var cam := get_viewport().get_camera_3d()
	if cam:
		var dist := global_position.distance_to(cam.global_position)
		if dist > CULL_DISTANCE:
			var avail := _playback.get_frames_available()
			for _i in range(avail):
				_playback.push_frame(Vector2.ZERO)
			return

	var slip := _get_slip_intensity()
	var frames_available := _playback.get_frames_available()
	for _i in range(frames_available):
		if slip < 0.01:
			_playback.push_frame(Vector2.ZERO)
			continue

		# Filtered noise for screech
		var noise := (_rng.randf() * 2.0 - 1.0) * slip * 0.3
		_phase += 800.0 / SAMPLE_RATE
		if _phase > 1.0:
			_phase -= 1.0
		var tone := sin(_phase * TAU) * slip * 0.1
		var sample := noise + tone
		_playback.push_frame(Vector2(sample, sample))


func _get_slip_intensity() -> float:
	if not "linear_velocity" in _vehicle:
		return 0.0

	var vel: Vector3 = _vehicle.linear_velocity
	var speed_kmh := vel.length() * 3.6
	if speed_kmh < SLIP_SPEED_THRESHOLD:
		return 0.0

	var forward: Vector3 = -_vehicle.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.001:
		return 0.0
	forward = forward.normalized()

	var h_vel := Vector3(vel.x, 0.0, vel.z)
	if h_vel.length_squared() < 0.001:
		return 0.0

	var lateral := absf(h_vel.normalized().cross(forward).y)

	# Check handbrake
	var handbrake := 0.0
	if "handbrake_input" in _vehicle:
		handbrake = _vehicle.handbrake_input

	var slip := 0.0
	if lateral > LATERAL_THRESHOLD:
		slip = clampf((lateral - LATERAL_THRESHOLD) * 2.0, 0.0, 1.0)
	if handbrake > 0.5 and speed_kmh > 30.0:
		slip = maxf(slip, 0.6)

	return slip
