extends Node
## In-vehicle radio with multi-genre procedural music, DJ chatter via TTS,
## and police scanner announcements.
## Press T (radio_next) to switch stations or turn off.
## Only audible while player is driving (InputManager.is_vehicle()).

const MUSIC_INTERVAL_MIN := 10.0
const MUSIC_INTERVAL_MAX := 20.0
const DJ_INTERVAL_MIN := 25.0
const DJ_INTERVAL_MAX := 50.0
const POLICE_ANNOUNCE_INTERVAL := 20.0
const STATIC_DURATION := 0.4
const MIX_RATE := 22050.0

# --- Genre definitions ---
# Each genre: {scales, waveform, tempo_range, notes_range, volume, name, dj}
const GENRE_POP := {
	"name": "Little Car FM Pop",
	"waveform": "square",
	"scales": [
		[261.6, 293.7, 329.6, 349.2, 392.0, 440.0, 493.9, 523.3],
		[329.6, 370.0, 392.0, 440.0, 493.9, 523.3, 587.3, 659.3],
	],
	"tempo_min": 0.13,
	"tempo_max": 0.2,
	"notes_min": 16,
	"notes_max": 40,
	"volume": 0.07,
	"dj_lines": [
		"You're listening to Little Car Pop, number one hits!",
		"That was a banger! More pop coming right up.",
		"Pop FM, feel good music all day!",
		"Next up, another chart topper. Stay tuned!",
	],
}

const GENRE_ROCK := {
	"name": "Car Rock Radio",
	"waveform": "distorted",
	"scales": [
		[130.8, 146.8, 164.8, 174.6, 196.0, 220.0, 246.9, 261.6],
		[98.0, 110.0, 123.5, 130.8, 146.8, 164.8, 174.6, 196.0],
	],
	"tempo_min": 0.08,
	"tempo_max": 0.14,
	"notes_min": 24,
	"notes_max": 60,
	"volume": 0.09,
	"dj_lines": [
		"Car Rock Radio! Crank it up!",
		"That riff was insane! More rock ahead.",
		"Rock and roll on four wheels!",
		"Head banging while driving. Not recommended, but here we are.",
	],
}

const GENRE_JAZZ := {
	"name": "Smooth Jazz Drive",
	"waveform": "triangle",
	"scales": [
		[220.0, 261.6, 277.2, 293.7, 329.6, 370.0, 392.0, 440.0],
		[196.0, 233.1, 246.9, 261.6, 293.7, 311.1, 349.2, 392.0],
	],
	"tempo_min": 0.18,
	"tempo_max": 0.35,
	"notes_min": 12,
	"notes_max": 32,
	"volume": 0.06,
	"dj_lines": [
		"Smooth Jazz Drive. Relax and cruise.",
		"That was silky smooth. More jazz coming up.",
		"Easy listening for easy driving.",
		"Jazz FM, where every note takes you somewhere.",
	],
}

const GENRE_ELECTRONIC := {
	"name": "Neon Beat FM",
	"waveform": "saw",
	"scales": [
		[130.8, 164.8, 196.0, 220.0, 261.6, 293.7, 329.6, 392.0],
		[65.4, 82.4, 98.0, 130.8, 164.8, 196.0, 261.6, 329.6],
	],
	"tempo_min": 0.06,
	"tempo_max": 0.1,
	"notes_min": 32,
	"notes_max": 80,
	"volume": 0.065,
	"dj_lines": [
		"Neon Beat FM! Drop the bass!",
		"Electronic vibes for night riders.",
		"Beats per minute: way too many. You're welcome.",
		"Neon Beat, the sound of the city.",
	],
}

const GENRE_CLASSICAL := {
	"name": "Classical Cruise",
	"waveform": "sine",
	"scales": [
		[261.6, 293.7, 329.6, 349.2, 392.0, 440.0, 493.9, 523.3],
		[196.0, 220.0, 246.9, 261.6, 293.7, 329.6, 349.2, 392.0],
		[349.2, 392.0, 440.0, 493.9, 523.3, 587.3, 659.3, 698.5],
	],
	"tempo_min": 0.25,
	"tempo_max": 0.45,
	"notes_min": 10,
	"notes_max": 28,
	"volume": 0.06,
	"dj_lines": [
		"Classical Cruise. Elegant driving.",
		"A timeless masterpiece. More after this.",
		"Orchestral beauty for your commute.",
		"Classical Cruise, where every drive is a concerto.",
	],
}

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

var _genres: Array = []
var _genre_index := 0

var _music_player: AudioStreamPlayer
var _static_player: AudioStreamPlayer
var _music_playback: AudioStreamGeneratorPlayback
var _static_playback: AudioStreamGeneratorPlayback

var _rng := RandomNumberGenerator.new()
var _music_timer := 0.0
var _dj_timer := 0.0
var _police_timer := 0.0
var _is_playing_music := false
var _radio_on := false

# Music generation state
var _note_phase := 0.0
var _note_phase2 := 0.0
var _note_freq := 440.0
var _note_freq2 := 0.0
var _note_timer := 0.0
var _note_duration := 0.0
var _current_scale: Array = []
var _notes_remaining := 0
var _music_volume := 0.07
var _beat_time := 0.15
var _waveform := "square"

# Arpeggio state for electronic
var _arp_index := 0
var _arp_pattern: Array = []

# Static burst state
var _static_timer := 0.0
var _playing_static := false

# TTS
var _tts_voice_id := ""
var _tts_queue: Array[String] = []


func _ready() -> void:
	_rng.randomize()

	_genres = [
		GENRE_POP, GENRE_ROCK, GENRE_JAZZ,
		GENRE_ELECTRONIC, GENRE_CLASSICAL,
	]
	_genre_index = 0

	_music_timer = _rng.randf_range(2.0, 5.0)
	_dj_timer = _rng.randf_range(8.0, 15.0)
	_police_timer = POLICE_ANNOUNCE_INTERVAL

	# Music generator
	_music_player = AudioStreamPlayer.new()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = MIX_RATE
	gen.buffer_length = 0.1
	_music_player.stream = gen
	_music_player.bus = "Ambient"
	add_child(_music_player)
	_music_player.play()
	_music_playback = _music_player.get_stream_playback()

	# Static burst generator
	_static_player = AudioStreamPlayer.new()
	var sgen := AudioStreamGenerator.new()
	sgen.mix_rate = MIX_RATE
	sgen.buffer_length = 0.1
	_static_player.stream = sgen
	_static_player.bus = "Ambient"
	add_child(_static_player)
	_static_player.play()
	_static_playback = _static_player.get_stream_playback()

	# TTS setup
	var voices := DisplayServer.tts_get_voices()
	for v in voices:
		var lang: String = v.get("language", "")
		if lang.begins_with("en"):
			_tts_voice_id = v.get("id", "")
			break
	if _tts_voice_id.is_empty() and not voices.is_empty():
		_tts_voice_id = voices[0].get("id", "")

	_apply_genre()
	EventBus.wanted_level_changed.connect(_on_wanted_changed)
	EventBus.vehicle_entered.connect(_on_vehicle_entered)
	EventBus.vehicle_exited.connect(_on_vehicle_exited)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("radio_next"):
		_switch_station()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	var in_vehicle := InputManager.is_vehicle()

	if not in_vehicle or not _radio_on:
		_fill_silence()
		_fill_static_silence()
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
		var genre: Dictionary = _genres[_genre_index]
		var lines: Array = genre.get("dj_lines", [])
		if not lines.is_empty():
			_speak_tts(lines[_rng.randi() % lines.size()])

	# Police scanner
	_police_timer -= delta
	if _police_timer <= 0.0:
		_police_timer = POLICE_ANNOUNCE_INTERVAL
		_play_police_announcement()

	# TTS queue processing
	_process_tts_queue()


func _switch_station() -> void:
	if not InputManager.is_vehicle():
		return

	# Cycle: genre0 -> genre1 -> ... -> genreN -> OFF -> genre0
	if _radio_on:
		if _genre_index < _genres.size() - 1:
			_genre_index += 1
		else:
			# Turn off
			_radio_on = false
			_is_playing_music = false
			_play_static_burst()
			_speak_tts("Radio off.")
			return
	else:
		# Turn back on at first genre
		_radio_on = true
		_genre_index = 0

	_apply_genre()
	_is_playing_music = false
	_music_timer = _rng.randf_range(1.0, 3.0)
	_play_static_burst()

	var genre: Dictionary = _genres[_genre_index]
	var station_name: String = genre.get("name", "Radio")
	_speak_tts("Now playing: " + station_name)


func _apply_genre() -> void:
	var genre: Dictionary = _genres[_genre_index]
	_waveform = genre.get("waveform", "square")
	_music_volume = genre.get("volume", 0.07)
	var scales: Array = genre.get("scales", [[440.0]])
	_current_scale = scales[_rng.randi() % scales.size()]


func _start_music_segment() -> void:
	_is_playing_music = true
	var genre: Dictionary = _genres[_genre_index]
	var scales: Array = genre.get("scales", [[440.0]])
	_current_scale = scales[_rng.randi() % scales.size()]

	var nmin: int = genre.get("notes_min", 16)
	var nmax: int = genre.get("notes_max", 40)
	_notes_remaining = _rng.randi_range(nmin, nmax)

	var tmin: float = genre.get("tempo_min", 0.12)
	var tmax: float = genre.get("tempo_max", 0.2)
	_beat_time = _rng.randf_range(tmin, tmax)

	# Build arpeggio pattern for electronic genre
	if _waveform == "saw":
		_arp_pattern.clear()
		for _i in range(4):
			_arp_pattern.append(
				_current_scale[_rng.randi() % _current_scale.size()]
			)
		_arp_index = 0

	_note_timer = 0.0
	_pick_next_note()


func _pick_next_note() -> void:
	if _waveform == "saw" and not _arp_pattern.is_empty():
		# Electronic: cycle through arpeggio pattern
		_note_freq = _arp_pattern[_arp_index % _arp_pattern.size()]
		_arp_index += 1
	else:
		_note_freq = _current_scale[
			_rng.randi() % _current_scale.size()
		]

	# Rock: add a fifth for power chord feel
	if _waveform == "distorted":
		_note_freq2 = _note_freq * 1.5
	else:
		_note_freq2 = 0.0

	_note_duration = _beat_time * _rng.randi_range(1, 3)
	_note_timer = _note_duration
	_note_phase = 0.0
	_note_phase2 = 0.0


func _fill_music(delta: float) -> void:
	if not _music_playback:
		return
	var frames := _music_playback.get_frames_available()
	var inv_rate := 1.0 / MIX_RATE
	for _i in range(frames):
		var sample := _generate_sample()
		_music_playback.push_frame(Vector2(sample, sample))
		_note_phase += _note_freq * inv_rate
		if _note_phase > 1.0:
			_note_phase -= 1.0
		if _note_freq2 > 0.0:
			_note_phase2 += _note_freq2 * inv_rate
			if _note_phase2 > 1.0:
				_note_phase2 -= 1.0

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


func _generate_sample() -> float:
	var vol := _music_volume
	var phase := _note_phase

	if _waveform == "square":
		var wave := signf(sin(phase * TAU)) * vol
		wave += signf(sin(phase * TAU * 1.005)) * (vol * 0.3)
		return wave

	if _waveform == "distorted":
		# Distorted square with power chord fifth
		var wave := clampf(
			sin(phase * TAU) * 3.0, -1.0, 1.0
		) * vol
		if _note_freq2 > 0.0:
			wave += clampf(
				sin(_note_phase2 * TAU) * 3.0, -1.0, 1.0
			) * (vol * 0.7)
		return wave

	if _waveform == "triangle":
		# Triangle wave with slight vibrato
		var vibrato := sin(phase * TAU * 0.02) * 0.003
		var tri := (2.0 * absf(2.0 * fmod(phase + vibrato, 1.0) - 1.0) - 1.0)
		return tri * vol

	if _waveform == "saw":
		# Saw wave with detune for thickness
		var saw1 := (2.0 * fmod(phase, 1.0) - 1.0) * vol
		var saw2_phase := fmod(phase * 1.01, 1.0)
		var saw2 := (2.0 * saw2_phase - 1.0) * (vol * 0.5)
		return saw1 + saw2

	# Sine (classical)
	var wave := sin(phase * TAU) * vol
	wave += sin(phase * TAU * 2.0) * (vol * 0.15)
	return wave


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


func _on_vehicle_entered(_vehicle: Node) -> void:
	_radio_on = true
	_genre_index = _rng.randi() % _genres.size()
	_apply_genre()
	_is_playing_music = false
	_music_timer = _rng.randf_range(1.0, 3.0)
	_dj_timer = _rng.randf_range(3.0, 8.0)
	_play_static_burst()
	var genre: Dictionary = _genres[_genre_index]
	var station_name: String = genre.get("name", "Radio")
	_speak_tts("Now playing: " + station_name)


func _on_vehicle_exited(_vehicle: Node) -> void:
	_radio_on = false
	_is_playing_music = false
	_tts_queue.clear()
	DisplayServer.tts_stop()


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
