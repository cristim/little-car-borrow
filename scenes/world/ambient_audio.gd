extends AudioStreamPlayer
## Procedural ambient city soundscape: low traffic drone with occasional detail.

const SAMPLE_RATE := 22050.0
const DRONE_FREQ := 55.0
const DRONE_FREQ_2 := 82.0
const HORN_INTERVAL_MIN_DAY := 8.0
const HORN_INTERVAL_MAX_DAY := 20.0
const HORN_INTERVAL_MIN_NIGHT := 15.0
const HORN_INTERVAL_MAX_NIGHT := 40.0
const HORN_DURATION := 0.3
const DRONE_AMP_DAY := 0.04
const DRONE_AMP_NIGHT := 0.02
const CRICKET_FREQ := 4000.0
const CRICKET_AMP := 0.008

var _phase := 0.0
var _phase2 := 0.0
var _horn_phase := 0.0
var _playback: AudioStreamGeneratorPlayback = null
var _rng := RandomNumberGenerator.new()
var _horn_timer := 0.0
var _horn_active := false
var _horn_remaining := 0.0
var _horn_freq := 300.0
var _cricket_phase := 0.0
var _is_night := false
var _drone_amp := DRONE_AMP_DAY
var _horn_min := HORN_INTERVAL_MIN_DAY
var _horn_max := HORN_INTERVAL_MAX_DAY


func _ready() -> void:
	_rng.randomize()
	_horn_timer = _rng.randf_range(_horn_min, _horn_max)
	EventBus.time_of_day_changed.connect(_on_time_changed)

	var gen := AudioStreamGenerator.new()
	gen.mix_rate = SAMPLE_RATE
	gen.buffer_length = 0.1
	stream = gen
	bus = "Ambient"
	play()
	_playback = get_stream_playback()


func _process(delta: float) -> void:
	if not _playback:
		return

	# Horn timing
	if _horn_active:
		_horn_remaining -= delta
		if _horn_remaining <= 0.0:
			_horn_active = false
			_horn_timer = _rng.randf_range(_horn_min, _horn_max)
	else:
		_horn_timer -= delta
		if _horn_timer <= 0.0:
			_horn_active = true
			_horn_remaining = HORN_DURATION
			_horn_freq = _rng.randf_range(280.0, 400.0)
			_horn_phase = 0.0

	var frames_available := _playback.get_frames_available()
	for _i in range(frames_available):
		# City drone: two low sine waves
		var drone := sin(_phase * TAU) * _drone_amp
		drone += sin(_phase2 * TAU) * (_drone_amp * 0.625)

		# Occasional horn honk
		var horn := 0.0
		if _horn_active:
			horn = sin(_horn_phase * TAU) * 0.06
			_horn_phase += _horn_freq / SAMPLE_RATE
			if _horn_phase > 1.0:
				_horn_phase -= 1.0

		# Night crickets
		var cricket := 0.0
		if _is_night:
			cricket = sin(_cricket_phase * TAU) * CRICKET_AMP
			_cricket_phase += CRICKET_FREQ / SAMPLE_RATE
			if _cricket_phase > 1.0:
				_cricket_phase -= 1.0

		var sample := drone + horn + cricket
		_playback.push_frame(Vector2(sample, sample))

		_phase += DRONE_FREQ / SAMPLE_RATE
		_phase2 += DRONE_FREQ_2 / SAMPLE_RATE
		if _phase > 1.0:
			_phase -= 1.0
		if _phase2 > 1.0:
			_phase2 -= 1.0


func _on_time_changed(hour: float) -> void:
	_is_night = hour < 6.0 or hour > 20.0
	if _is_night:
		_drone_amp = DRONE_AMP_NIGHT
		_horn_min = HORN_INTERVAL_MIN_NIGHT
		_horn_max = HORN_INTERVAL_MAX_NIGHT
	else:
		_drone_amp = DRONE_AMP_DAY
		_horn_min = HORN_INTERVAL_MIN_DAY
		_horn_max = HORN_INTERVAL_MAX_DAY
