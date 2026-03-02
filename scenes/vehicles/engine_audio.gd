extends AudioStreamPlayer3D
## Procedural engine sound using AudioStreamGenerator.
## Frequency maps to vehicle speed; harmonics add richness.

const SAMPLE_RATE := 22050.0
const BASE_FREQ_MIN := 80.0
const BASE_FREQ_MAX := 300.0
const IDLE_WOBBLE_FREQ := 3.0
const IDLE_WOBBLE_DEPTH := 8.0
const HARMONIC_2_AMP := 0.3
const HARMONIC_3_AMP := 0.15

var _phase := 0.0
var _phase2 := 0.0
var _phase3 := 0.0
var _wobble_phase := 0.0
var _vehicle: Node = null
var _playback: AudioStreamGeneratorPlayback = null


func _ready() -> void:
	_vehicle = get_parent()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = SAMPLE_RATE
	gen.buffer_length = 0.1
	stream = gen
	bus = "SFX"
	max_distance = 80.0
	attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	play()
	_playback = get_stream_playback()


func _process(_delta: float) -> void:
	if not _playback or not _vehicle:
		return

	var speed_kmh := 0.0
	if "linear_velocity" in _vehicle:
		speed_kmh = _vehicle.linear_velocity.length() * 3.6

	var throttle := 0.0
	if "throttle_input" in _vehicle:
		throttle = _vehicle.throttle_input

	var speed_ratio := clampf(speed_kmh / 120.0, 0.0, 1.0)
	var base_freq := lerpf(BASE_FREQ_MIN, BASE_FREQ_MAX, speed_ratio)

	# Idle wobble
	if speed_kmh < 5.0:
		_wobble_phase += IDLE_WOBBLE_FREQ / SAMPLE_RATE
		base_freq += sin(_wobble_phase * TAU) * IDLE_WOBBLE_DEPTH

	var volume := lerpf(0.15, 0.6, maxf(speed_ratio, throttle))

	var frames_available := _playback.get_frames_available()
	for _i in range(frames_available):
		var sample := sin(_phase * TAU) * volume
		sample += sin(_phase2 * TAU) * volume * HARMONIC_2_AMP
		sample += sin(_phase3 * TAU) * volume * HARMONIC_3_AMP

		_playback.push_frame(Vector2(sample, sample))

		_phase += base_freq / SAMPLE_RATE
		_phase2 += (base_freq * 2.0) / SAMPLE_RATE
		_phase3 += (base_freq * 3.0) / SAMPLE_RATE

		if _phase > 1.0:
			_phase -= 1.0
		if _phase2 > 1.0:
			_phase2 -= 1.0
		if _phase3 > 1.0:
			_phase3 -= 1.0
