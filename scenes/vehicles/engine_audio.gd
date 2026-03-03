extends AudioStreamPlayer3D
## Procedural engine sound using AudioStreamGenerator.
## Multi-harmonic synthesis with sub-bass rumble, exhaust crackle,
## throttle response shaping, and RPM-based frequency sweep.

const SAMPLE_RATE := 22050.0
const BASE_FREQ_MIN := 60.0
const BASE_FREQ_MAX := 280.0
const IDLE_WOBBLE_FREQ := 3.5
const IDLE_WOBBLE_DEPTH := 10.0
const CULL_DISTANCE := 60.0

# Harmonic amplitudes relative to fundamental
const H2_AMP := 0.35
const H3_AMP := 0.18
const H4_AMP := 0.08
const H5_AMP := 0.04
# Sub-bass one octave below fundamental
const SUB_AMP := 0.2

var _phase := 0.0
var _phase2 := 0.0
var _phase3 := 0.0
var _phase4 := 0.0
var _phase5 := 0.0
var _phase_sub := 0.0
var _wobble_phase := 0.0
var _vehicle: Node = null
var _playback: AudioStreamGeneratorPlayback = null
var _rng := RandomNumberGenerator.new()
var _crackle_timer := 0.0
var _crackle_amp := 0.0
var _prev_throttle := 0.0
var _smooth_volume := 0.15


func _ready() -> void:
	_vehicle = get_parent()
	_rng.randomize()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = SAMPLE_RATE
	gen.buffer_length = 0.1
	stream = gen
	bus = "SFX"
	max_distance = 80.0
	attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	play()
	_playback = get_stream_playback()


func _process(delta: float) -> void:
	if not _playback or not _vehicle:
		return

	# Distance culling
	var cam := get_viewport().get_camera_3d()
	if cam:
		var dist := global_position.distance_to(cam.global_position)
		if dist > CULL_DISTANCE:
			var frames_available := _playback.get_frames_available()
			for _i in range(frames_available):
				_playback.push_frame(Vector2.ZERO)
			return

	var speed_kmh := 0.0
	if "linear_velocity" in _vehicle:
		speed_kmh = _vehicle.linear_velocity.length() * 3.6

	var throttle := 0.0
	if "throttle_input" in _vehicle:
		throttle = _vehicle.throttle_input

	var speed_ratio := clampf(speed_kmh / 120.0, 0.0, 1.0)
	var base_freq := lerpf(BASE_FREQ_MIN, BASE_FREQ_MAX, speed_ratio)

	# Idle wobble with slight irregularity
	if speed_kmh < 5.0:
		_wobble_phase += IDLE_WOBBLE_FREQ / SAMPLE_RATE
		if _wobble_phase > 1.0:
			_wobble_phase -= 1.0
		base_freq += sin(_wobble_phase * TAU) * IDLE_WOBBLE_DEPTH
		base_freq += sin(_wobble_phase * TAU * 2.3) * 3.0

	# Exhaust crackle on throttle lift-off at speed
	if _prev_throttle > 0.3 and throttle < 0.1 and speed_kmh > 30.0:
		_crackle_timer = 0.3
		_crackle_amp = 0.12
	_prev_throttle = throttle
	if _crackle_timer > 0.0:
		_crackle_timer -= delta
		_crackle_amp *= 0.92

	# Smooth volume transitions
	var target_vol := lerpf(0.15, 0.55, maxf(speed_ratio, throttle))
	_smooth_volume = lerpf(_smooth_volume, target_vol, delta * 8.0)
	var volume := _smooth_volume

	var frames_available := _playback.get_frames_available()
	for _i in range(frames_available):
		# Fundamental with slight waveshaping (squared sine for growl)
		var fund := sin(_phase * TAU)
		var shaped := fund * (0.8 + 0.2 * absf(fund))

		# Build harmonic stack
		var sample := shaped * volume
		sample += sin(_phase2 * TAU) * volume * H2_AMP
		sample += sin(_phase3 * TAU) * volume * H3_AMP
		sample += sin(_phase4 * TAU) * volume * H4_AMP
		sample += sin(_phase5 * TAU) * volume * H5_AMP
		# Sub-bass rumble
		sample += sin(_phase_sub * TAU) * volume * SUB_AMP

		# Exhaust crackle: bursts of filtered noise
		if _crackle_timer > 0.0:
			sample += (_rng.randf() - 0.5) * _crackle_amp

		_playback.push_frame(Vector2(sample, sample))

		_phase += base_freq / SAMPLE_RATE
		_phase2 += (base_freq * 2.0) / SAMPLE_RATE
		_phase3 += (base_freq * 3.0) / SAMPLE_RATE
		_phase4 += (base_freq * 4.0) / SAMPLE_RATE
		_phase5 += (base_freq * 5.0) / SAMPLE_RATE
		_phase_sub += (base_freq * 0.5) / SAMPLE_RATE

		if _phase > 1.0:
			_phase -= 1.0
		if _phase2 > 1.0:
			_phase2 -= 1.0
		if _phase3 > 1.0:
			_phase3 -= 1.0
		if _phase4 > 1.0:
			_phase4 -= 1.0
		if _phase5 > 1.0:
			_phase5 -= 1.0
		if _phase_sub > 1.0:
			_phase_sub -= 1.0
