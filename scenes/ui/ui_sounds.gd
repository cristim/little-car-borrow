extends Node
## Procedural UI sounds: wanted level change tones.

const SAMPLE_RATE := 22050.0
const TONE_DURATION := 0.15
const BASE_FREQ := 440.0

var _playback: AudioStreamGeneratorPlayback = null
var _player: AudioStreamPlayer = null
var _tone_queue: Array[float] = []
var _tone_remaining := 0.0
var _phase := 0.0


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = SAMPLE_RATE
	gen.buffer_length = 0.5
	_player.stream = gen
	_player.bus = "SFX"
	add_child(_player)
	_player.play()
	_playback = _player.get_stream_playback()

	EventBus.wanted_level_changed.connect(_on_wanted_level_changed)


func _process(_delta: float) -> void:
	if not _playback:
		return

	var frames_available := _playback.get_frames_available()
	for _i in range(frames_available):
		if _tone_remaining <= 0.0:
			if _tone_queue.is_empty():
				_playback.push_frame(Vector2.ZERO)
				continue
			_phase = 0.0
			_tone_remaining = TONE_DURATION
			# Current freq is already set by queue processing below

		var freq := _tone_queue[0] if not _tone_queue.is_empty() else BASE_FREQ
		var sample := sin(_phase * TAU) * 0.25
		_playback.push_frame(Vector2(sample, sample))
		_phase += freq / SAMPLE_RATE
		if _phase > 1.0:
			_phase -= 1.0

		_tone_remaining -= 1.0 / SAMPLE_RATE
		if _tone_remaining <= 0.0 and not _tone_queue.is_empty():
			_tone_queue.remove_at(0)


func _on_wanted_level_changed(level: int) -> void:
	_tone_queue.clear()
	if level > 0:
		# Ascending tones for level up
		for i in range(level):
			_tone_queue.append(BASE_FREQ + i * 100.0)
	else:
		# Descending tone for cleared
		_tone_queue.append(BASE_FREQ)
		_tone_queue.append(BASE_FREQ - 100.0)
