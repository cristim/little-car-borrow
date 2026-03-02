extends AudioStreamPlayer3D
## Procedural two-tone police siren using AudioStreamGenerator.
## Alternates between low and high tone in a wail pattern.

const SAMPLE_RATE := 22050.0
const FREQ_LOW := 600.0
const FREQ_HIGH := 800.0
const WAIL_SPEED := 2.0

var siren_active := false

var _phase := 0.0
var _wail_phase := 0.0
var _playback: AudioStreamGeneratorPlayback = null


func _ready() -> void:
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = SAMPLE_RATE
	gen.buffer_length = 0.1
	stream = gen
	bus = "SFX"
	max_distance = 120.0
	attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	play()
	_playback = get_stream_playback()


func _process(_delta: float) -> void:
	if not _playback:
		return

	var frames_available := _playback.get_frames_available()
	for _i in range(frames_available):
		if not siren_active:
			_playback.push_frame(Vector2.ZERO)
			continue

		_wail_phase += WAIL_SPEED / SAMPLE_RATE
		if _wail_phase > 1.0:
			_wail_phase -= 1.0

		var freq := lerpf(FREQ_LOW, FREQ_HIGH, _wail_phase)
		var sample := sin(_phase * TAU) * 0.4

		_playback.push_frame(Vector2(sample, sample))
		_phase += freq / SAMPLE_RATE
		if _phase > 1.0:
			_phase -= 1.0
