extends AudioStreamPlayer
## Procedural ambient city soundscape with layered elements:
## low traffic drone, distant horns, wind gusts, bird chirps (day),
## crickets (night), and occasional brake squeal.

const SAMPLE_RATE := 22050.0

# Drone frequencies (traffic rumble)
const DRONE_FREQ := 55.0
const DRONE_FREQ_2 := 82.0
const DRONE_FREQ_3 := 110.0
const DRONE_AMP_DAY := 0.04
const DRONE_AMP_NIGHT := 0.02

# Horn parameters
const HORN_INTERVAL_MIN_DAY := 8.0
const HORN_INTERVAL_MAX_DAY := 18.0
const HORN_INTERVAL_MIN_NIGHT := 15.0
const HORN_INTERVAL_MAX_NIGHT := 40.0
const HORN_DURATION := 0.35

# Wind gust parameters
const GUST_INTERVAL_MIN := 6.0
const GUST_INTERVAL_MAX := 15.0
const GUST_DURATION := 2.5

# Bird chirp parameters (daytime only)
const CHIRP_INTERVAL_MIN := 4.0
const CHIRP_INTERVAL_MAX := 12.0
const CHIRP_FREQ_LOW := 2800.0
const CHIRP_FREQ_HIGH := 4500.0
const CHIRP_DURATION := 0.12

# Brake squeal (occasional distant)
const BRAKE_INTERVAL_MIN := 12.0
const BRAKE_INTERVAL_MAX := 30.0
const BRAKE_DURATION := 0.5

# Cricket frequency
const CRICKET_FREQ := 4000.0
const CRICKET_FREQ_2 := 4800.0
const CRICKET_AMP := 0.006

var _phase := 0.0
var _phase2 := 0.0
var _phase3 := 0.0
var _horn_phase := 0.0
var _playback: AudioStreamGeneratorPlayback = null
var _rng := RandomNumberGenerator.new()

# Horn state
var _horn_timer := 0.0
var _horn_active := false
var _horn_remaining := 0.0
var _horn_freq := 300.0
var _horn_freq2 := 0.0

# Wind gust state
var _gust_timer := 0.0
var _gust_active := false
var _gust_remaining := 0.0
var _gust_filter := 0.0

# Bird chirp state
var _chirp_timer := 0.0
var _chirp_active := false
var _chirp_remaining := 0.0
var _chirp_freq := 3200.0
var _chirp_phase := 0.0

# Brake squeal state
var _brake_timer := 0.0
var _brake_active := false
var _brake_remaining := 0.0
var _brake_phase := 0.0

# Cricket state
var _cricket_phase := 0.0
var _cricket_phase2 := 0.0
var _is_night := false
var _drone_amp := DRONE_AMP_DAY
var _horn_min := HORN_INTERVAL_MIN_DAY
var _horn_max := HORN_INTERVAL_MAX_DAY


func _ready() -> void:
	_rng.randomize()
	_horn_timer = _rng.randf_range(_horn_min, _horn_max)
	_gust_timer = _rng.randf_range(GUST_INTERVAL_MIN, GUST_INTERVAL_MAX)
	_chirp_timer = _rng.randf_range(CHIRP_INTERVAL_MIN, CHIRP_INTERVAL_MAX)
	_brake_timer = _rng.randf_range(BRAKE_INTERVAL_MIN, BRAKE_INTERVAL_MAX)
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
	_update_horn(delta)
	_update_gust(delta)
	_update_chirp(delta)
	_update_brake(delta)
	_fill_buffer()


func _update_horn(delta: float) -> void:
	if _horn_active:
		_horn_remaining -= delta
		if _horn_remaining <= 0.0:
			_horn_active = false
			_horn_timer = _rng.randf_range(_horn_min, _horn_max)
	else:
		_horn_timer -= delta
		if _horn_timer <= 0.0:
			_horn_active = true
			_horn_remaining = HORN_DURATION + _rng.randf_range(-0.1, 0.15)
			_horn_freq = _rng.randf_range(280.0, 420.0)
			_horn_freq2 = _horn_freq * _rng.randf_range(1.18, 1.35)
			_horn_phase = 0.0


func _update_gust(delta: float) -> void:
	if _gust_active:
		_gust_remaining -= delta
		if _gust_remaining <= 0.0:
			_gust_active = false
			_gust_timer = _rng.randf_range(GUST_INTERVAL_MIN, GUST_INTERVAL_MAX)
	else:
		_gust_timer -= delta
		if _gust_timer <= 0.0:
			_gust_active = true
			_gust_remaining = GUST_DURATION + _rng.randf_range(-0.5, 1.0)


func _update_chirp(delta: float) -> void:
	if _is_night:
		return
	if _chirp_active:
		_chirp_remaining -= delta
		if _chirp_remaining <= 0.0:
			_chirp_active = false
			_chirp_timer = _rng.randf_range(CHIRP_INTERVAL_MIN, CHIRP_INTERVAL_MAX)
	else:
		_chirp_timer -= delta
		if _chirp_timer <= 0.0:
			_chirp_active = true
			_chirp_remaining = CHIRP_DURATION
			_chirp_freq = _rng.randf_range(CHIRP_FREQ_LOW, CHIRP_FREQ_HIGH)
			_chirp_phase = 0.0


func _update_brake(delta: float) -> void:
	if _brake_active:
		_brake_remaining -= delta
		if _brake_remaining <= 0.0:
			_brake_active = false
			_brake_timer = _rng.randf_range(BRAKE_INTERVAL_MIN, BRAKE_INTERVAL_MAX)
	else:
		_brake_timer -= delta
		if _brake_timer <= 0.0:
			_brake_active = true
			_brake_remaining = BRAKE_DURATION
			_brake_phase = 0.0


func _fill_buffer() -> void:
	var frames_available := _playback.get_frames_available()
	for _i in range(frames_available):
		var sample := _gen_drone() + _gen_horn() + _gen_gust()
		sample += _gen_chirp() + _gen_brake() + _gen_cricket()
		_playback.push_frame(Vector2(sample, sample))

		_advance_drone()


func _gen_drone() -> float:
	var d := sin(_phase * TAU) * _drone_amp
	d += sin(_phase2 * TAU) * (_drone_amp * 0.6)
	d += sin(_phase3 * TAU) * (_drone_amp * 0.3)
	return d


func _advance_drone() -> void:
	_phase += DRONE_FREQ / SAMPLE_RATE
	_phase2 += DRONE_FREQ_2 / SAMPLE_RATE
	_phase3 += DRONE_FREQ_3 / SAMPLE_RATE
	if _phase > 1.0:
		_phase -= 1.0
	if _phase2 > 1.0:
		_phase2 -= 1.0
	if _phase3 > 1.0:
		_phase3 -= 1.0


func _gen_horn() -> float:
	if not _horn_active:
		return 0.0
	# Dual-tone horn with envelope
	var env := 1.0
	if _horn_remaining < 0.05:
		env = _horn_remaining / 0.05
	var h := sin(_horn_phase * TAU) * 0.04 * env
	h += sin(_horn_phase * TAU * _horn_freq2 / _horn_freq) * 0.025 * env
	_horn_phase += _horn_freq / SAMPLE_RATE
	if _horn_phase > 1.0:
		_horn_phase -= 1.0
	return h


func _gen_gust() -> float:
	if not _gust_active:
		_gust_filter *= 0.999
		return _gust_filter * 0.03
	# Wind: heavily filtered noise with swell envelope
	var progress := 1.0 - (_gust_remaining / GUST_DURATION)
	var env := sin(progress * PI) * 0.5
	var noise := _rng.randf() - 0.5
	_gust_filter += 0.02 * (noise * env - _gust_filter)
	return _gust_filter * 0.06


func _gen_chirp() -> float:
	if not _chirp_active or _is_night:
		return 0.0
	var progress := 1.0 - (_chirp_remaining / CHIRP_DURATION)
	var env := sin(progress * PI)
	# Frequency modulated chirp (rising)
	var freq := _chirp_freq * (1.0 + progress * 0.3)
	_chirp_phase += freq / SAMPLE_RATE
	if _chirp_phase > 1.0:
		_chirp_phase -= 1.0
	return sin(_chirp_phase * TAU) * 0.012 * env


func _gen_brake() -> float:
	if not _brake_active:
		return 0.0
	var progress := 1.0 - (_brake_remaining / BRAKE_DURATION)
	var env := (1.0 - progress) * (1.0 - progress)
	var freq := lerpf(1200.0, 800.0, progress)
	_brake_phase += freq / SAMPLE_RATE
	if _brake_phase > 1.0:
		_brake_phase -= 1.0
	# Mix sine with noise for brake character
	var tone := sin(_brake_phase * TAU) * 0.015 * env
	var noise := (_rng.randf() - 0.5) * 0.008 * env
	return tone + noise


func _gen_cricket() -> float:
	if not _is_night:
		return 0.0
	# Dual-frequency cricket chirp with amplitude modulation
	_cricket_phase += CRICKET_FREQ / SAMPLE_RATE
	if _cricket_phase > 1.0:
		_cricket_phase -= 1.0
	_cricket_phase2 += CRICKET_FREQ_2 / SAMPLE_RATE
	if _cricket_phase2 > 1.0:
		_cricket_phase2 -= 1.0
	# Pulsing amplitude at ~10 Hz for realistic cricket
	var pulse := maxf(sin(_cricket_phase * TAU * 10.0 / CRICKET_FREQ), 0.0)
	var c := sin(_cricket_phase * TAU) * CRICKET_AMP * pulse
	c += sin(_cricket_phase2 * TAU) * CRICKET_AMP * 0.5 * pulse
	return c


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
