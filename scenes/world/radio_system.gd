extends Node
## In-vehicle radio with music simulation, DJ chatter via TTS,
## and police scanner announcements.
## Only audible while player is driving (InputManager.is_vehicle()).

const MUSIC_INTERVAL_MIN := 15.0
const MUSIC_INTERVAL_MAX := 30.0
const DJ_INTERVAL_MIN := 30.0
const DJ_INTERVAL_MAX := 60.0
const POLICE_ANNOUNCE_INTERVAL := 20.0
const STATIC_DURATION := 0.3

const DJ_LINES := [
	"You're listening to Little Car FM, the city's number one station!",
	"That was a classic! Stay tuned for more hits.",
	"Traffic is heavy downtown. Good luck out there!",
	"It's a beautiful day in the city. Keep those wheels rolling!",
	"Next up, a fan favorite. Don't touch that dial!",
	"Little Car FM, all hits, all the time.",
	"Coming up, more music after these messages.",
	"You're cruising with Little Car FM!",
	"The weather today: sunny with a chance of reckless driving.",
	"This one goes out to all the night owls out there.",
]

const POLICE_LINES_WANTED := [
	"All units, suspect vehicle spotted. Pursue with caution.",
	"Dispatch to all units. We have a reckless driver in the area.",
	"Be advised, suspect is armed and dangerous.",
	"Units in the area, suspect fleeing at high speed.",
	"Requesting backup. Suspect vehicle heading downtown.",
	"All units, be on the lookout. Suspect has evaded pursuit.",
]

const POLICE_LINES_CALM := [
	"All units, situation normal. Routine patrol.",
	"Dispatch, no incidents reported. Stay alert.",
	"Unit seven, proceed to your assigned sector.",
	"All clear on the main boulevard. Over.",
]

# Music note frequencies for procedural radio tunes
const SCALES := [
	[261.6, 293.7, 329.6, 349.2, 392.0, 440.0, 493.9, 523.3],
	[220.0, 246.9, 261.6, 293.7, 329.6, 349.2, 392.0, 440.0],
	[329.6, 370.0, 392.0, 440.0, 493.9, 523.3, 587.3, 659.3],
]

var _music_player: AudioStreamPlayer
var _static_player: AudioStreamPlayer
var _music_playback: AudioStreamGeneratorPlayback
var _static_playback: AudioStreamGeneratorPlayback

var _rng := RandomNumberGenerator.new()
var _music_timer := 0.0
var _dj_timer := 0.0
var _police_timer := 0.0
var _is_playing_music := false
var _radio_on := true

# Music generation state
var _note_phase := 0.0
var _note_freq := 440.0
var _note_timer := 0.0
var _note_duration := 0.0
var _current_scale: Array = []
var _notes_remaining := 0
var _music_volume := 0.08
var _beat_time := 0.15

# Static burst state
var _static_timer := 0.0
var _playing_static := false

# TTS
var _tts_available := false
var _tts_voice_id := ""
var _tts_queue: Array[String] = []
var _tts_speaking := false


func _ready() -> void:
	_rng.randomize()
	_music_timer = _rng.randf_range(2.0, 5.0)
	_dj_timer = _rng.randf_range(10.0, 20.0)
	_police_timer = POLICE_ANNOUNCE_INTERVAL

	# Music generator
	_music_player = AudioStreamPlayer.new()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.1
	_music_player.stream = gen
	_music_player.bus = "Ambient"
	add_child(_music_player)
	_music_player.play()
	_music_playback = _music_player.get_stream_playback()

	# Static burst generator
	_static_player = AudioStreamPlayer.new()
	var sgen := AudioStreamGenerator.new()
	sgen.mix_rate = 22050.0
	sgen.buffer_length = 0.1
	_static_player.stream = sgen
	_static_player.bus = "Ambient"
	add_child(_static_player)
	_static_player.play()
	_static_playback = _static_player.get_stream_playback()

	# TTS setup
	_tts_available = DisplayServer.tts_is_speaking() or true
	var voices := DisplayServer.tts_get_voices()
	for v in voices:
		var lang: String = v.get("language", "")
		if lang.begins_with("en"):
			_tts_voice_id = v.get("id", "")
			break
	if _tts_voice_id.is_empty() and not voices.is_empty():
		_tts_voice_id = voices[0].get("id", "")

	_current_scale = SCALES[0]

	EventBus.wanted_level_changed.connect(_on_wanted_changed)


func _process(delta: float) -> void:
	var in_vehicle := InputManager.is_vehicle()

	if not in_vehicle or not _radio_on:
		_fill_silence()
		return

	# Static bursts
	if _playing_static:
		_static_timer -= delta
		if _static_timer <= 0.0:
			_playing_static = false
		_fill_static()
	else:
		_fill_static_silence()

	# Music timing
	if _is_playing_music:
		_fill_music(delta)
	else:
		_fill_silence()
		_music_timer -= delta
		if _music_timer <= 0.0:
			_start_music_segment()

	# DJ chatter
	_dj_timer -= delta
	if _dj_timer <= 0.0:
		_dj_timer = _rng.randf_range(DJ_INTERVAL_MIN, DJ_INTERVAL_MAX)
		_play_static_burst()
		_speak_tts(DJ_LINES[_rng.randi() % DJ_LINES.size()])

	# Police scanner
	_police_timer -= delta
	if _police_timer <= 0.0:
		_police_timer = POLICE_ANNOUNCE_INTERVAL
		_play_police_announcement()

	# TTS queue processing
	_process_tts_queue()


func _start_music_segment() -> void:
	_is_playing_music = true
	_current_scale = SCALES[_rng.randi() % SCALES.size()]
	_notes_remaining = _rng.randi_range(16, 48)
	_beat_time = _rng.randf_range(0.12, 0.2)
	_note_timer = 0.0
	_pick_next_note()


func _pick_next_note() -> void:
	_note_freq = _current_scale[
		_rng.randi() % _current_scale.size()
	]
	_note_duration = _beat_time * _rng.randi_range(1, 3)
	_note_timer = _note_duration
	_note_phase = 0.0


func _fill_music(delta: float) -> void:
	if not _music_playback:
		return
	var frames := _music_playback.get_frames_available()
	for _i in range(frames):
		# Simple square wave with slight detune for warmth
		var wave := signf(sin(_note_phase * TAU)) * _music_volume
		wave += signf(sin(_note_phase * TAU * 1.005)) * (
			_music_volume * 0.3
		)
		_music_playback.push_frame(Vector2(wave, wave))
		_note_phase += _note_freq / 22050.0
		if _note_phase > 1.0:
			_note_phase -= 1.0

	_note_timer -= delta
	if _note_timer <= 0.0:
		_notes_remaining -= 1
		if _notes_remaining <= 0:
			_is_playing_music = false
			_music_timer = _rng.randf_range(
				MUSIC_INTERVAL_MIN, MUSIC_INTERVAL_MAX
			)
		else:
			_pick_next_note()


func _fill_silence() -> void:
	if not _music_playback:
		return
	var frames := _music_playback.get_frames_available()
	for _i in range(frames):
		_music_playback.push_frame(Vector2.ZERO)


func _play_static_burst() -> void:
	_playing_static = true
	_static_timer = STATIC_DURATION


func _fill_static() -> void:
	if not _static_playback:
		return
	var frames := _static_playback.get_frames_available()
	for _i in range(frames):
		var noise := (_rng.randf() - 0.5) * 0.12
		_static_playback.push_frame(Vector2(noise, noise))


func _fill_static_silence() -> void:
	if not _static_playback:
		return
	var frames := _static_playback.get_frames_available()
	for _i in range(frames):
		_static_playback.push_frame(Vector2.ZERO)


func _play_police_announcement() -> void:
	_play_static_burst()
	var level := WantedLevelManager.wanted_level
	var lines: Array
	if level > 0:
		lines = POLICE_LINES_WANTED
	else:
		lines = POLICE_LINES_CALM
	_speak_tts(lines[_rng.randi() % lines.size()])


func _speak_tts(text: String) -> void:
	if _tts_voice_id.is_empty():
		return
	_tts_queue.append(text)


func _process_tts_queue() -> void:
	if _tts_queue.is_empty():
		return
	if DisplayServer.tts_is_speaking():
		return
	var text: String = _tts_queue.pop_front()
	DisplayServer.tts_speak(text, _tts_voice_id, 70, 1.0, 1.1)


func _on_wanted_changed(level: int) -> void:
	if level >= 3:
		_police_timer = minf(_police_timer, 8.0)
	if level >= 1:
		_play_static_burst()
		_speak_tts(
			POLICE_LINES_WANTED[
				_rng.randi() % POLICE_LINES_WANTED.size()
			]
		)
