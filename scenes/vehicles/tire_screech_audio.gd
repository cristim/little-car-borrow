extends AudioStreamPlayer3D
## Procedural tire screech with resonant filtered noise,
## speed-dependent pitch, and smooth attack/release envelope.

const SAMPLE_RATE := 22050.0
const SLIP_SPEED_THRESHOLD := 20.0
const LATERAL_THRESHOLD := 0.3
const CULL_DISTANCE := 50.0

# Resonant frequency bands for screech character
const RES_FREQ_LOW := 600.0
const RES_FREQ_HIGH := 1800.0
const ATTACK_SPEED := 8.0
const RELEASE_SPEED := 4.0

var _phase := 0.0
var _phase2 := 0.0
var _playback: AudioStreamGeneratorPlayback = null
var _vehicle: Node = null
var _rng := RandomNumberGenerator.new()
var _envelope := 0.0
var _filter_state := 0.0
var _filter_state2 := 0.0


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

	# Distance culling — stop playback entirely instead of pushing silence
	var cam := get_viewport().get_camera_3d()
	if cam:
		var dist := global_position.distance_to(cam.global_position)
		if dist > CULL_DISTANCE:
			if playing:
				stop()
			return
		if not playing:
			play()
			_playback = get_stream_playback()
			if not _playback:
				return

	var slip := _get_slip_intensity()

	# Speed-dependent resonant frequency
	var speed_kmh := 0.0
	if "linear_velocity" in _vehicle:
		speed_kmh = _vehicle.linear_velocity.length() * 3.6
	var speed_ratio := clampf(speed_kmh / 120.0, 0.0, 1.0)
	var res_freq := lerpf(RES_FREQ_LOW, RES_FREQ_HIGH, speed_ratio)
	var res_freq2 := res_freq * 1.5  # Second resonance band

	# Filter coefficient (simple one-pole bandpass approximation)
	var dt := 1.0 / SAMPLE_RATE
	var rc := 1.0 / (TAU * res_freq)
	var alpha := dt / (rc + dt)
	var rc2 := 1.0 / (TAU * res_freq2)
	var alpha2 := dt / (rc2 + dt)

	var frames_available := _playback.get_frames_available()
	for _i in range(frames_available):
		# Smooth envelope
		if slip > 0.01:
			_envelope = minf(_envelope + ATTACK_SPEED * dt, slip)
		else:
			_envelope = maxf(_envelope - RELEASE_SPEED * dt, 0.0)

		if _envelope < 0.005:
			_playback.push_frame(Vector2.ZERO)
			continue

		# Raw noise source
		var noise := _rng.randf() * 2.0 - 1.0

		# Resonant filtered noise (two bands mixed)
		_filter_state += alpha * (noise - _filter_state)
		_filter_state2 += alpha2 * (noise - _filter_state2)
		var filtered := _filter_state * 0.6 + _filter_state2 * 0.3

		# Add tonal component that rises with slip
		_phase += res_freq * 0.5 / SAMPLE_RATE
		if _phase > 1.0:
			_phase -= 1.0
		_phase2 += res_freq * 0.75 / SAMPLE_RATE
		if _phase2 > 1.0:
			_phase2 -= 1.0
		var tone := sin(_phase * TAU) * 0.08 + sin(_phase2 * TAU) * 0.04

		var sample := (filtered + tone) * _envelope * 0.4
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
