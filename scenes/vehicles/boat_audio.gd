extends AudioStreamPlayer3D
## Procedural outboard motor sound using AudioStreamGenerator.
## Lower frequency range than car engine, with water gurgle and hull slap.

const SAMPLE_RATE := 22050.0
const BASE_FREQ_MIN := 35.0
const BASE_FREQ_MAX := 140.0
const IDLE_BURBLE_FREQ := 2.0
const IDLE_BURBLE_DEPTH := 8.0
const CULL_DISTANCE := 60.0

# Harmonic amplitudes (stronger 2nd harmonic for outboard character)
const H2_AMP := 0.50
const H3_AMP := 0.15
const H4_AMP := 0.06
const SUB_AMP := 0.25

var _phase := 0.0
var _phase2 := 0.0
var _phase3 := 0.0
var _phase4 := 0.0
var _phase_sub := 0.0
var _burble_phase := 0.0
var _vehicle: Node = null
var _controller: Node = null
var _playback: AudioStreamGeneratorPlayback = null
var _rng := RandomNumberGenerator.new()
var _smooth_volume := 0.12


func _ready() -> void:
	_vehicle = get_parent()
	_rng.randomize()
	if _vehicle:
		_controller = _vehicle.get_node_or_null("BoatController")

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
			if playing:
				stop()
			return
		if not playing:
			play()
			_playback = get_stream_playback()
			if not _playback:
				return

	var speed_kmh := 0.0
	if "linear_velocity" in _vehicle:
		speed_kmh = _vehicle.linear_velocity.length() * 3.6

	var throttle := 0.0
	if _controller and "active" in _controller and _controller.active:
		throttle = Input.get_action_strength("move_forward")

	var speed_ratio := clampf(speed_kmh / 80.0, 0.0, 1.0)
	var base_freq := lerpf(BASE_FREQ_MIN, BASE_FREQ_MAX, speed_ratio)

	# Idle burble (2 Hz amplitude modulation)
	if speed_kmh < 5.0:
		_burble_phase += IDLE_BURBLE_FREQ / SAMPLE_RATE
		if _burble_phase > 1.0:
			_burble_phase -= 1.0
		base_freq += sin(_burble_phase * TAU) * IDLE_BURBLE_DEPTH

	# Volume
	var target_vol := lerpf(0.12, 0.45, maxf(speed_ratio, throttle))
	_smooth_volume = lerpf(_smooth_volume, target_vol, delta * 6.0)
	var volume := _smooth_volume

	# Water gurgle amplitude (always present, louder at speed)
	var gurgle_amp := lerpf(0.1, 0.25, speed_ratio)

	# Hull slap at speed
	var slap_amp := 0.0
	if speed_kmh > 15.0:
		slap_amp = clampf((speed_kmh - 15.0) / 40.0, 0.0, 0.15)

	var frames_available := _playback.get_frames_available()
	for _i in range(frames_available):
		var fund := sin(_phase * TAU)
		var shaped := fund * (0.8 + 0.2 * absf(fund))

		var sample := shaped * volume
		sample += sin(_phase2 * TAU) * volume * H2_AMP
		sample += sin(_phase3 * TAU) * volume * H3_AMP
		sample += sin(_phase4 * TAU) * volume * H4_AMP
		sample += sin(_phase_sub * TAU) * volume * SUB_AMP

		# Water gurgle (filtered noise)
		sample += (_rng.randf() - 0.5) * gurgle_amp * volume

		# Hull slap (noise bursts)
		if slap_amp > 0.0:
			sample += (_rng.randf() - 0.5) * slap_amp

		_playback.push_frame(Vector2(sample, sample))

		_phase += base_freq / SAMPLE_RATE
		_phase2 += (base_freq * 2.0) / SAMPLE_RATE
		_phase3 += (base_freq * 3.0) / SAMPLE_RATE
		_phase4 += (base_freq * 4.0) / SAMPLE_RATE
		_phase_sub += (base_freq * 0.5) / SAMPLE_RATE

		if _phase > 1.0:
			_phase -= 1.0
		if _phase2 > 1.0:
			_phase2 -= 1.0
		if _phase3 > 1.0:
			_phase3 -= 1.0
		if _phase4 > 1.0:
			_phase4 -= 1.0
		if _phase_sub > 1.0:
			_phase_sub -= 1.0
