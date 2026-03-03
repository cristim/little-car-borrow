extends AudioStreamPlayer3D
## Procedural police siren with wail and yelp patterns.
## Uses dual oscillators with overtones and amplitude modulation.

const SAMPLE_RATE := 22050.0

# Wail pattern: slow sweep between frequencies
const WAIL_LOW := 570.0
const WAIL_HIGH := 850.0
const WAIL_SPEED := 1.8

# Yelp pattern: fast sweep (triggered periodically)
const YELP_LOW := 650.0
const YELP_HIGH := 1600.0
const YELP_SPEED := 12.0
const YELP_DURATION := 2.0
const YELP_INTERVAL := 8.0

var siren_active := false

var _phase := 0.0
var _phase_overtone := 0.0
var _wail_phase := 0.0
var _mode_timer := 0.0
var _is_yelp := false
var _am_phase := 0.0


func _ready() -> void:
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = SAMPLE_RATE
	gen.buffer_length = 0.1
	stream = gen
	bus = "SFX"
	max_distance = 120.0
	attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	play()


func _process(delta: float) -> void:
	var playback := get_stream_playback() as AudioStreamGeneratorPlayback
	if not playback:
		return

	# Switch between wail and yelp modes
	if siren_active:
		_mode_timer += delta
		if _is_yelp and _mode_timer >= YELP_DURATION:
			_is_yelp = false
			_mode_timer = 0.0
		elif not _is_yelp and _mode_timer >= YELP_INTERVAL:
			_is_yelp = true
			_mode_timer = 0.0

	var frames_available := playback.get_frames_available()
	for _i in range(frames_available):
		if not siren_active:
			playback.push_frame(Vector2.ZERO)
			continue

		# Frequency sweep
		var freq: float
		var sweep_speed: float
		if _is_yelp:
			sweep_speed = YELP_SPEED
			freq = lerpf(YELP_LOW, YELP_HIGH, _wail_phase)
		else:
			sweep_speed = WAIL_SPEED
			# Sine sweep for smooth wail
			var sweep := (sin(_wail_phase * TAU) + 1.0) * 0.5
			freq = lerpf(WAIL_LOW, WAIL_HIGH, sweep)

		_wail_phase += sweep_speed / SAMPLE_RATE
		if _wail_phase > 1.0:
			_wail_phase -= 1.0

		# Primary oscillator
		var primary := sin(_phase * TAU)
		# Add 3rd harmonic overtone for richness
		var overtone := sin(_phase_overtone * TAU) * 0.15
		# Slight square-ish character via clipping
		var shaped := clampf(primary * 1.3, -1.0, 1.0)

		# Amplitude modulation for pulsing effect
		_am_phase += 6.0 / SAMPLE_RATE
		if _am_phase > 1.0:
			_am_phase -= 1.0
		var am := 0.85 + 0.15 * sin(_am_phase * TAU)

		var sample := (shaped + overtone) * 0.35 * am
		playback.push_frame(Vector2(sample, sample))

		_phase += freq / SAMPLE_RATE
		_phase_overtone += (freq * 3.0) / SAMPLE_RATE
		if _phase > 1.0:
			_phase -= 1.0
		if _phase_overtone > 1.0:
			_phase_overtone -= 1.0
