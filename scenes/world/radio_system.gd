extends Node
## In-vehicle radio with multi-genre sample-based music, DJ chatter
## via TTS, and police scanner announcements.
## Press T (radio_next) to switch stations or turn off.
## Each genre plays melody + bass + percussion simultaneously using
## AudioStreamPolyphonic for sample playback.

const MUSIC_INTERVAL_MIN := 2.0
const MUSIC_INTERVAL_MAX := 5.0
const DJ_INTERVAL_MIN := 25.0
const DJ_INTERVAL_MAX := 50.0
const POLICE_ANNOUNCE_INTERVAL := 20.0
const STATIC_DURATION := 0.4
const MIX_RATE := 22050.0

# --- Preloaded samples ---
const SMP_KICK = preload("res://assets/audio/samples/drums/kick.wav")
const SMP_SNARE = preload("res://assets/audio/samples/drums/snare.wav")
const SMP_SNARE_BRUSH = preload("res://assets/audio/samples/drums/snare_brush.wav")
const SMP_HIHAT_CLOSED = preload("res://assets/audio/samples/drums/hihat_closed.wav")
const SMP_HIHAT_OPEN = preload("res://assets/audio/samples/drums/hihat_open.wav")
const SMP_RIDE = preload("res://assets/audio/samples/drums/ride.wav")
const SMP_PIANO_C4 = preload("res://assets/audio/samples/melodic/piano_c4.wav")
const SMP_PIANO_C2 = preload("res://assets/audio/samples/melodic/piano_c2.wav")
const SMP_GUITAR_DIST_C3 = preload("res://assets/audio/samples/melodic/guitar_dist_c3.wav")
const SMP_BASS_GUITAR_C2 = preload("res://assets/audio/samples/melodic/bass_guitar_c2.wav")
const SMP_SAX_C4 = preload("res://assets/audio/samples/melodic/sax_c4.wav")
const SMP_UPRIGHT_BASS_C2 = preload("res://assets/audio/samples/melodic/upright_bass_c2.wav")
const SMP_SYNTH_LEAD_C4 = preload("res://assets/audio/samples/melodic/synth_lead_c4.wav")
const SMP_SYNTH_BASS_C2 = preload("res://assets/audio/samples/melodic/synth_bass_c2.wav")
const SMP_VIOLIN_C4 = preload("res://assets/audio/samples/melodic/violin_c4.wav")

# Drum kit lookup: name -> AudioStream
const DRUM_SAMPLES := {
	"kick": SMP_KICK,
	"snare": SMP_SNARE,
	"snare_brush": SMP_SNARE_BRUSH,
	"hihat_closed": SMP_HIHAT_CLOSED,
	"hihat_open": SMP_HIHAT_OPEN,
	"ride": SMP_RIDE,
}

# Chord progressions as scale-degree indices (0-based into 8-note scale)
const PROGRESSIONS := [
	[[0, 2, 4], [3, 5, 7], [4, 6, 1], [0, 2, 4]],  # I-IV-V-I
	[[0, 2, 4], [4, 6, 1], [5, 7, 2], [3, 5, 7]],  # I-V-vi-IV
	[[0, 2, 4], [5, 7, 2], [3, 5, 7], [4, 6, 1]],  # I-vi-IV-V
	[[1, 3, 5], [4, 6, 1], [0, 2, 4], [0, 2, 4]],  # ii-V-I-I
	[[0, 2, 4], [2, 4, 6], [3, 5, 7], [4, 6, 1]],  # I-iii-IV-V
	[[5, 7, 2], [3, 5, 7], [0, 2, 4], [4, 6, 1]],  # vi-IV-I-V
]

# 16-step drum patterns per genre: each step is [kick_vel, snare_vel, hihat_vel, open_hat_vel]
const DRUM_PATTERNS := {
	"pop": [
		[1.0, 0.0, 0.8, 0.0], [0.0, 0.0, 0.5, 0.0],
		[0.0, 0.0, 0.8, 0.0], [0.0, 0.0, 0.5, 0.0],
		[0.0, 1.0, 0.8, 0.0], [0.0, 0.0, 0.5, 0.0],
		[0.3, 0.0, 0.8, 0.0], [0.0, 0.0, 0.5, 0.0],
		[1.0, 0.0, 0.8, 0.0], [0.0, 0.0, 0.5, 0.0],
		[0.0, 0.0, 0.8, 0.0], [0.0, 0.3, 0.5, 0.0],
		[0.0, 1.0, 0.8, 0.0], [0.0, 0.0, 0.5, 0.0],
		[0.3, 0.0, 0.8, 0.0], [0.0, 0.0, 0.5, 0.0],
	],
	"rock": [
		[1.0, 0.0, 1.0, 0.0], [0.0, 0.0, 1.0, 0.0],
		[0.0, 0.0, 1.0, 0.0], [0.0, 0.0, 1.0, 0.0],
		[0.0, 1.0, 1.0, 0.0], [0.0, 0.0, 1.0, 0.0],
		[0.0, 0.0, 1.0, 0.0], [0.5, 0.0, 1.0, 0.0],
		[1.0, 0.0, 1.0, 0.0], [0.0, 0.0, 1.0, 0.0],
		[0.0, 0.0, 1.0, 0.0], [0.0, 0.0, 1.0, 0.0],
		[0.0, 1.0, 0.0, 1.0], [0.0, 0.0, 1.0, 0.0],
		[0.5, 0.0, 1.0, 0.0], [0.0, 0.3, 1.0, 0.0],
	],
	"jazz": [
		[0.0, 0.0, 0.0, 0.0], [0.0, 0.0, 0.8, 0.0],
		[0.0, 0.0, 0.0, 0.0], [0.0, 0.0, 0.8, 0.0],
		[0.0, 0.0, 0.0, 0.0], [0.0, 0.0, 0.8, 0.0],
		[0.0, 0.3, 0.0, 0.0], [0.0, 0.0, 0.8, 0.0],
		[0.0, 0.0, 0.0, 0.0], [0.0, 0.0, 0.8, 0.0],
		[0.0, 0.0, 0.0, 0.0], [0.0, 0.0, 0.8, 0.0],
		[0.0, 0.0, 0.0, 0.0], [0.0, 0.3, 0.8, 0.0],
		[0.5, 0.0, 0.0, 0.0], [0.0, 0.0, 0.8, 0.0],
	],
	"electronic": [
		[1.0, 0.0, 0.8, 0.0], [0.0, 0.0, 0.8, 0.0],
		[0.0, 0.0, 0.0, 0.8], [0.0, 0.0, 0.8, 0.0],
		[1.0, 1.0, 0.8, 0.0], [0.0, 0.0, 0.8, 0.0],
		[0.0, 0.0, 0.0, 0.8], [0.0, 0.0, 0.8, 0.0],
		[1.0, 0.0, 0.8, 0.0], [0.0, 0.0, 0.8, 0.0],
		[0.0, 0.0, 0.0, 0.8], [0.0, 0.0, 0.8, 0.0],
		[1.0, 1.0, 0.8, 0.0], [0.0, 0.0, 0.8, 0.0],
		[0.5, 0.0, 0.0, 0.8], [0.0, 0.0, 0.8, 0.0],
	],
	"classical": [
		[0.0, 0.0, 0.0, 0.0], [0.0, 0.0, 0.0, 0.0],
		[0.0, 0.0, 0.0, 0.0], [0.0, 0.0, 0.0, 0.0],
		[0.0, 0.0, 0.0, 0.0], [0.0, 0.0, 0.0, 0.0],
		[0.0, 0.0, 0.0, 0.0], [0.0, 0.0, 0.0, 0.0],
		[0.0, 0.0, 0.0, 0.0], [0.0, 0.0, 0.0, 0.0],
		[0.0, 0.0, 0.0, 0.0], [0.0, 0.0, 0.0, 0.0],
		[0.0, 0.0, 0.0, 0.0], [0.0, 0.0, 0.0, 0.0],
		[0.0, 0.0, 0.0, 0.0], [0.0, 0.0, 0.0, 0.0],
	],
}

# --- Genre definitions ---
const GENRE_POP := {
	"name": "Little Car FM Pop",
	"mel_sample": SMP_PIANO_C4,
	"mel_root_hz": 261.626,
	"bas_sample": SMP_PIANO_C2,
	"bas_root_hz": 65.406,
	"drum_pattern": "pop",
	"drum_kit": ["kick", "snare", "hihat_closed", "hihat_open"],
	"scales": [
		[261.6, 293.7, 329.6, 349.2, 392.0, 440.0, 493.9, 523.3],
		[329.6, 370.0, 392.0, 440.0, 493.9, 523.3, 587.3, 659.3],
	],
	"tempo_min": 0.13,
	"tempo_max": 0.2,
	"notes_min": 80,
	"notes_max": 200,
	"mel_vol_db": -18.0,
	"bas_vol_db": -20.0,
	"drum_vol_db": -16.0,
	"chord_beats": 4,
	"passing_tone_chance": 0.2,
	"melody_mode": "chord",
	"delay_ms": 250.0,
	"delay_feedback_db": -14.0,
	"dist_drive": 0.0,
	"dj_lines": [
		"You're listening to Little Car Pop, number one hits!",
		"That was a banger! More pop coming right up.",
		"Pop FM, feel good music all day!",
		"Next up, another chart topper. Stay tuned!",
	],
}

const GENRE_ROCK := {
	"name": "Car Rock Radio",
	"mel_sample": SMP_GUITAR_DIST_C3,
	"mel_root_hz": 130.813,
	"bas_sample": SMP_BASS_GUITAR_C2,
	"bas_root_hz": 65.406,
	"drum_pattern": "rock",
	"drum_kit": ["kick", "snare", "hihat_closed", "hihat_open"],
	"scales": [
		[110.0, 130.8, 146.8, 164.8, 196.0, 220.0, 261.6, 293.7],
		[164.8, 196.0, 220.0, 246.9, 293.7, 329.6, 392.0, 440.0],
	],
	"tempo_min": 0.15,
	"tempo_max": 0.30,
	"notes_min": 80,
	"notes_max": 200,
	"mel_vol_db": -14.0,
	"bas_vol_db": -18.0,
	"drum_vol_db": -14.0,
	"chord_beats": 4,
	"passing_tone_chance": 0.40,
	"melody_mode": "power_chord",
	"delay_ms": 80.0,
	"delay_feedback_db": -20.0,
	"dist_drive": 0.5,
	"dj_lines": [
		"Car Rock Radio! Crank it up!",
		"That riff was insane! More rock ahead.",
		"Rock and roll on four wheels!",
		"Head banging while driving. Not recommended, but here we are.",
	],
}

const GENRE_JAZZ := {
	"name": "Smooth Jazz Drive",
	"mel_sample": SMP_SAX_C4,
	"mel_root_hz": 261.626,
	"bas_sample": SMP_UPRIGHT_BASS_C2,
	"bas_root_hz": 65.406,
	"drum_pattern": "jazz",
	"drum_kit": ["kick", "snare_brush", "ride", "hihat_open"],
	"scales": [
		[220.0, 261.6, 277.2, 293.7, 329.6, 370.0, 392.0, 440.0],
		[196.0, 233.1, 246.9, 261.6, 293.7, 311.1, 349.2, 392.0],
	],
	"tempo_min": 0.18,
	"tempo_max": 0.35,
	"notes_min": 50,
	"notes_max": 120,
	"mel_vol_db": -18.0,
	"bas_vol_db": -20.0,
	"drum_vol_db": -20.0,
	"chord_beats": 2,
	"passing_tone_chance": 0.3,
	"melody_mode": "chord",
	"delay_ms": 350.0,
	"delay_feedback_db": -12.0,
	"dist_drive": 0.0,
	"dj_lines": [
		"Smooth Jazz Drive. Relax and cruise.",
		"That was silky smooth. More jazz coming up.",
		"Easy listening for easy driving.",
		"Jazz FM, where every note takes you somewhere.",
	],
}

const GENRE_ELECTRONIC := {
	"name": "Neon Beat FM",
	"mel_sample": SMP_SYNTH_LEAD_C4,
	"mel_root_hz": 261.626,
	"bas_sample": SMP_SYNTH_BASS_C2,
	"bas_root_hz": 65.406,
	"drum_pattern": "electronic",
	"drum_kit": ["kick", "snare", "hihat_closed", "hihat_open"],
	"scales": [
		[130.8, 164.8, 196.0, 220.0, 261.6, 293.7, 329.6, 392.0],
		[98.0, 130.8, 164.8, 196.0, 220.0, 261.6, 329.6, 392.0],
	],
	"tempo_min": 0.06,
	"tempo_max": 0.1,
	"notes_min": 150,
	"notes_max": 400,
	"mel_vol_db": -18.0,
	"bas_vol_db": -16.0,
	"drum_vol_db": -14.0,
	"chord_beats": 8,
	"passing_tone_chance": 0.1,
	"melody_mode": "arp",
	"delay_ms": 300.0,
	"delay_feedback_db": -10.0,
	"dist_drive": 0.0,
	"dj_lines": [
		"Neon Beat FM! Drop the bass!",
		"Electronic vibes for night riders.",
		"Beats per minute: way too many. You're welcome.",
		"Neon Beat, the sound of the city.",
	],
}

const GENRE_CLASSICAL := {
	"name": "Classical Cruise",
	"mel_sample": SMP_VIOLIN_C4,
	"mel_root_hz": 261.626,
	"bas_sample": SMP_UPRIGHT_BASS_C2,
	"bas_root_hz": 65.406,
	"drum_pattern": "classical",
	"drum_kit": ["kick", "snare", "hihat_closed", "hihat_open"],
	"scales": [
		[261.6, 293.7, 329.6, 349.2, 392.0, 440.0, 493.9, 523.3],
		[196.0, 220.0, 246.9, 261.6, 293.7, 329.6, 349.2, 392.0],
		[349.2, 392.0, 440.0, 493.9, 523.3, 587.3, 659.3, 698.5],
	],
	"tempo_min": 0.25,
	"tempo_max": 0.45,
	"notes_min": 40,
	"notes_max": 100,
	"mel_vol_db": -16.0,
	"bas_vol_db": -20.0,
	"drum_vol_db": -40.0,
	"chord_beats": 4,
	"passing_tone_chance": 0.25,
	"melody_mode": "chord",
	"delay_ms": 250.0,
	"delay_feedback_db": -14.0,
	"dist_drive": 0.0,
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

# Polyphonic players for sample playback
var _melody_player: AudioStreamPlayer
var _bass_player: AudioStreamPlayer
var _drum_player: AudioStreamPlayer
var _melody_poly: AudioStreamPlaybackPolyphonic
var _bass_poly: AudioStreamPlaybackPolyphonic
var _drum_poly: AudioStreamPlaybackPolyphonic

# Active stream IDs for note-off
var _mel_stream_id: int = -1
var _mel_stream_id2: int = -1  # Power chord fifth
var _bass_stream_id: int = -1

# Static burst (keeps AudioStreamGenerator)
var _static_player: AudioStreamPlayer
var _static_playback: AudioStreamGeneratorPlayback

var _rng := RandomNumberGenerator.new()
var _music_timer := 0.0
var _dj_timer := 0.0
var _police_timer := 0.0
var _is_playing_music := false
var _radio_on := false

# Current genre sample/volume config
var _mel_sample: AudioStream
var _mel_root_hz := 261.626
var _mel_vol_db := -18.0
var _bas_sample: AudioStream
var _bas_root_hz := 65.406
var _bas_vol_db := -20.0
var _drum_kit: Array = []
var _drum_vol_db := -16.0
var _melody_mode := "chord"

# Melody/bass note timing
var _mel_timer := 0.0
var _bass_timer := 0.0

# Drum pattern state
var _drum_pattern: Array = []
var _drum_step := 0
var _drum_timer := 0.0

# Chord progression state
var _chord_progression: Array = []
var _chord_index := 0
var _chord_tones: Array = []
var _chord_beat_counter := 0
var _chord_beats_per_change := 4
var _passing_tone_chance := 0.2

# Shared music state
var _current_scale: Array = []
var _notes_remaining := 0
var _beat_time := 0.15

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

	# Melody polyphonic player
	_melody_player = AudioStreamPlayer.new()
	var mel_stream := AudioStreamPolyphonic.new()
	mel_stream.polyphony = 4
	_melody_player.stream = mel_stream
	_melody_player.bus = "Music"
	add_child(_melody_player)
	_melody_player.play()
	_melody_poly = _melody_player.get_stream_playback()

	# Bass polyphonic player
	_bass_player = AudioStreamPlayer.new()
	var bas_stream := AudioStreamPolyphonic.new()
	bas_stream.polyphony = 2
	_bass_player.stream = bas_stream
	_bass_player.bus = "Music"
	add_child(_bass_player)
	_bass_player.play()
	_bass_poly = _bass_player.get_stream_playback()

	# Drum polyphonic player
	_drum_player = AudioStreamPlayer.new()
	var drm_stream := AudioStreamPolyphonic.new()
	drm_stream.polyphony = 8
	_drum_player.stream = drm_stream
	_drum_player.bus = "Music"
	add_child(_drum_player)
	_drum_player.play()
	_drum_poly = _drum_player.get_stream_playback()

	# Static burst generator (keeps AudioStreamGenerator)
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
		_stop_all_music()
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
		_advance_music(delta)
	else:
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

	if _radio_on:
		if _genre_index < _genres.size() - 1:
			_genre_index += 1
		else:
			_radio_on = false
			_is_playing_music = false
			_stop_all_music()
			_play_static_burst()
			_speak_tts("Radio off.")
			return
	else:
		_radio_on = true
		_genre_index = 0

	_apply_genre()
	_is_playing_music = false
	_stop_all_music()
	_music_timer = _rng.randf_range(1.0, 3.0)
	_play_static_burst()

	var genre: Dictionary = _genres[_genre_index]
	var station_name: String = genre.get("name", "Radio")
	_speak_tts("Now playing: " + station_name)


func _apply_genre() -> void:
	var genre: Dictionary = _genres[_genre_index]
	_mel_sample = genre.get("mel_sample", SMP_PIANO_C4)
	_mel_root_hz = genre.get("mel_root_hz", 261.626)
	_mel_vol_db = genre.get("mel_vol_db", -18.0)
	_bas_sample = genre.get("bas_sample", SMP_PIANO_C2)
	_bas_root_hz = genre.get("bas_root_hz", 65.406)
	_bas_vol_db = genre.get("bas_vol_db", -20.0)
	var dp_key: String = genre.get("drum_pattern", "pop")
	_drum_pattern = DRUM_PATTERNS.get(dp_key, DRUM_PATTERNS["pop"])
	_drum_kit = genre.get("drum_kit", ["kick", "snare", "hihat_closed", "hihat_open"])
	_drum_vol_db = genre.get("drum_vol_db", -16.0)
	_melody_mode = genre.get("melody_mode", "chord")
	_chord_beats_per_change = genre.get("chord_beats", 4)
	_passing_tone_chance = genre.get("passing_tone_chance", 0.2)
	var scales: Array = genre.get("scales", [[440.0]])
	_current_scale = scales[_rng.randi() % scales.size()]
	_update_bus_effects(genre)


func _update_bus_effects(genre: Dictionary) -> void:
	var bus_idx := AudioServer.get_bus_index("Music")
	if bus_idx < 0:
		return
	# Update delay (slot 0)
	var delay_ms: float = genre.get("delay_ms", 300.0)
	var delay_fb: float = genre.get("delay_feedback_db", -14.0)
	var delay_effect: AudioEffectDelay = AudioServer.get_bus_effect(bus_idx, 0)
	if delay_effect:
		delay_effect.tap1_delay_ms = delay_ms
		delay_effect.tap1_level_db = delay_fb
		delay_effect.feedback_delay_ms = delay_ms
		delay_effect.feedback_level_db = delay_fb
	# Update distortion (slot 1)
	var dist_drive: float = genre.get("dist_drive", 0.0)
	var dist_effect: AudioEffectDistortion = AudioServer.get_bus_effect(bus_idx, 1)
	if dist_effect:
		if dist_drive > 0.0:
			dist_effect.drive = dist_drive
			dist_effect.pre_gain = 6.0
			dist_effect.post_gain = -3.0
		else:
			dist_effect.drive = 0.0
			dist_effect.pre_gain = 0.0
			dist_effect.post_gain = 0.0


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

	# Reset drum sequencer
	_drum_step = 0
	_drum_timer = 0.0

	# Initialize chord progression
	_chord_progression = PROGRESSIONS[_rng.randi() % PROGRESSIONS.size()]
	_chord_index = 0
	_chord_beat_counter = -1
	_update_chord()

	# Build arpeggio pattern for electronic genre
	if _melody_mode == "arp":
		_arp_pattern.clear()
		for i in range(4):
			var deg: int = _chord_tones[i % _chord_tones.size()]
			_arp_pattern.append(_current_scale[deg % _current_scale.size()])
		_arp_index = 0

	_mel_timer = 0.0
	_bass_timer = 0.0
	_trigger_melody_note()
	_trigger_bass_note()


func _update_chord() -> void:
	if _chord_progression.is_empty():
		return
	_chord_tones = _chord_progression[_chord_index % _chord_progression.size()]


func _trigger_melody_note() -> void:
	# Advance chord progression
	_chord_beat_counter += 1
	if _chord_beat_counter >= _chord_beats_per_change:
		_chord_beat_counter = 0
		_chord_index += 1
		_update_chord()
		# Rebuild arp from new chord
		if _melody_mode == "arp" and not _chord_tones.is_empty():
			_arp_pattern.clear()
			for i in range(4):
				var deg: int = _chord_tones[i % _chord_tones.size()]
				_arp_pattern.append(
					_current_scale[deg % _current_scale.size()]
				)
			_arp_index = 0

	var desired_hz := 440.0
	if _melody_mode == "arp" and not _arp_pattern.is_empty():
		desired_hz = _arp_pattern[_arp_index % _arp_pattern.size()]
		_arp_index += 1
	elif not _chord_tones.is_empty() and _rng.randf() > _passing_tone_chance:
		var deg: int = _chord_tones[_rng.randi() % _chord_tones.size()]
		desired_hz = _current_scale[deg % _current_scale.size()]
	else:
		desired_hz = _current_scale[_rng.randi() % _current_scale.size()]

	var pitch_scale: float = desired_hz / _mel_root_hz

	# Stop previous melody note
	if _mel_stream_id >= 0 and _melody_poly:
		_melody_poly.stop_stream(_mel_stream_id)
		_mel_stream_id = -1
	if _mel_stream_id2 >= 0 and _melody_poly:
		_melody_poly.stop_stream(_mel_stream_id2)
		_mel_stream_id2 = -1

	# Play new melody note
	if _melody_poly:
		_mel_stream_id = _melody_poly.play_stream(
			_mel_sample, 0.0, _mel_vol_db, pitch_scale
		)
		# Rock: power chord fifth
		if _melody_mode == "power_chord":
			_mel_stream_id2 = _melody_poly.play_stream(
				_mel_sample, 0.0, _mel_vol_db - 3.0, pitch_scale * 1.5
			)

	var duration := _beat_time * _rng.randi_range(1, 3)
	_mel_timer = duration


func _trigger_bass_note() -> void:
	var desired_hz := 65.0
	if not _chord_tones.is_empty():
		var root_deg: int = _chord_tones[0]
		var choice := _rng.randi() % 3
		if choice == 0:
			desired_hz = _current_scale[root_deg % _current_scale.size()] * 0.5
		elif choice == 1:
			var fifth_deg: int = _chord_tones[2 % _chord_tones.size()]
			desired_hz = _current_scale[fifth_deg % _current_scale.size()] * 0.5
		else:
			var third_deg: int = _chord_tones[1 % _chord_tones.size()]
			desired_hz = _current_scale[third_deg % _current_scale.size()] * 0.5
	else:
		desired_hz = _current_scale[0] * 0.5

	var pitch_scale: float = desired_hz / _bas_root_hz

	# Stop previous bass note
	if _bass_stream_id >= 0 and _bass_poly:
		_bass_poly.stop_stream(_bass_stream_id)
		_bass_stream_id = -1

	# Play new bass note
	if _bass_poly:
		_bass_stream_id = _bass_poly.play_stream(
			_bas_sample, 0.0, _bas_vol_db, pitch_scale
		)

	_bass_timer = _beat_time * _rng.randi_range(2, 4)


func _advance_drum_step() -> void:
	if _drum_pattern.is_empty() or not _drum_poly:
		return
	var step: Array = _drum_pattern[_drum_step % _drum_pattern.size()]
	_drum_step += 1

	# Map step voices to drum kit samples
	# step = [kick_vel, snare_vel, hihat_vel, open_hat_vel]
	for v in range(mini(step.size(), _drum_kit.size())):
		var vel: float = step[v]
		if vel > 0.0:
			var kit_name: String = _drum_kit[v]
			var sample: AudioStream = DRUM_SAMPLES.get(kit_name)
			if sample:
				var vel_db: float = _drum_vol_db + linear_to_db(vel)
				_drum_poly.play_stream(sample, 0.0, vel_db, 1.0)


func _advance_music(delta: float) -> void:
	# Melody note timing
	_mel_timer -= delta
	if _mel_timer <= 0.0:
		_notes_remaining -= 1
		if _notes_remaining <= 0:
			_stop_all_music()
			_is_playing_music = false
			_music_timer = _rng.randf_range(
				MUSIC_INTERVAL_MIN, MUSIC_INTERVAL_MAX
			)
			return
		_trigger_melody_note()

	# Bass note timing
	_bass_timer -= delta
	if _bass_timer <= 0.0:
		if _notes_remaining > 0:
			_trigger_bass_note()

	# Drum step sequencer
	if not _drum_pattern.is_empty():
		_drum_timer -= delta
		while _drum_timer <= 0.0:
			_drum_timer += _beat_time
			_advance_drum_step()


func _stop_all_music() -> void:
	if _mel_stream_id >= 0 and _melody_poly:
		_melody_poly.stop_stream(_mel_stream_id)
		_mel_stream_id = -1
	if _mel_stream_id2 >= 0 and _melody_poly:
		_melody_poly.stop_stream(_mel_stream_id2)
		_mel_stream_id2 = -1
	if _bass_stream_id >= 0 and _bass_poly:
		_bass_poly.stop_stream(_bass_stream_id)
		_bass_stream_id = -1


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
	_stop_all_music()
	_tts_queue.clear()
	DisplayServer.tts_stop()


func _on_wanted_changed(level: int) -> void:
	if not _radio_on:
		return
	if level >= 3:
		_police_timer = minf(_police_timer, 8.0)
	if level >= 1:
		_play_static_burst()
		_speak_tts(
			POLICE_LINES_WANTED[
				_rng.randi() % POLICE_LINES_WANTED.size()
			]
		)
