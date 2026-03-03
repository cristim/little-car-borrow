extends Node
## In-vehicle radio with multi-genre layered procedural music, DJ chatter
## via TTS, and police scanner announcements.
## Press T (radio_next) to switch stations or turn off.
## Each genre plays melody + bass + percussion simultaneously.

const MUSIC_INTERVAL_MIN := 2.0
const MUSIC_INTERVAL_MAX := 5.0
const DJ_INTERVAL_MIN := 25.0
const DJ_INTERVAL_MAX := 50.0
const POLICE_ANNOUNCE_INTERVAL := 20.0
const STATIC_DURATION := 0.4
const MIX_RATE := 22050.0
const DELAY_SIZE := 7718  # ~0.35s at 22050 Hz

# Chord progressions as scale-degree indices (0-based into 8-note scale)
# Each progression is 4 chords; each chord is a triad [root, third, fifth]
const PROGRESSIONS := [
	[[0, 2, 4], [3, 5, 7], [4, 6, 1], [0, 2, 4]],  # I-IV-V-I
	[[0, 2, 4], [4, 6, 1], [5, 7, 2], [3, 5, 7]],  # I-V-vi-IV
	[[0, 2, 4], [5, 7, 2], [3, 5, 7], [4, 6, 1]],  # I-vi-IV-V
	[[1, 3, 5], [4, 6, 1], [0, 2, 4], [0, 2, 4]],  # ii-V-I-I
	[[0, 2, 4], [2, 4, 6], [3, 5, 7], [4, 6, 1]],  # I-iii-IV-V
	[[5, 7, 2], [3, 5, 7], [0, 2, 4], [4, 6, 1]],  # vi-IV-I-V
]

# 16-step drum patterns per genre: each step is [kick_vel, snare_vel, hihat_vel, open_hat_vel]
# Velocity 0.0 = silent, 1.0 = full hit, <1.0 = ghost note
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
# melody_wave: square, distorted, triangle, saw, sine
# bass_wave: sine, square, saw (bass is always lower octave)
# drum_pattern: key into DRUM_PATTERNS
const GENRE_POP := {
	"name": "Little Car FM Pop",
	"melody_wave": "square",
	"bass_wave": "sine",
	"drum_pattern": "pop",
	"scales": [
		[261.6, 293.7, 329.6, 349.2, 392.0, 440.0, 493.9, 523.3],
		[329.6, 370.0, 392.0, 440.0, 493.9, 523.3, 587.3, 659.3],
	],
	"tempo_min": 0.13,
	"tempo_max": 0.2,
	"notes_min": 80,
	"notes_max": 200,
	"melody_vol": 0.055,
	"bass_vol": 0.04,
	"perc_vol": 0.03,
	"adsr": [0.01, 0.05, 0.7, 0.08],
	"chord_beats": 4,
	"passing_tone_chance": 0.2,
	"delay": [0.15, 0.25],
	"bass_cutoff": 0.15,
	"dj_lines": [
		"You're listening to Little Car Pop, number one hits!",
		"That was a banger! More pop coming right up.",
		"Pop FM, feel good music all day!",
		"Next up, another chart topper. Stay tuned!",
	],
}

const GENRE_ROCK := {
	"name": "Car Rock Radio",
	"melody_wave": "distorted",
	"bass_wave": "sine",
	"drum_pattern": "rock",
	"scales": [
		# E minor pentatonic - classic rock lead range
		[164.8, 196.0, 220.0, 246.9, 293.7, 329.6, 392.0, 440.0],
		# A minor pentatonic - higher register solos
		[220.0, 261.6, 293.7, 329.6, 392.0, 440.0, 523.3, 587.3],
	],
	"tempo_min": 0.12,
	"tempo_max": 0.22,
	"notes_min": 100,
	"notes_max": 250,
	"melody_vol": 0.06,
	"bass_vol": 0.05,
	"perc_vol": 0.04,
	"adsr": [0.005, 0.03, 0.85, 0.05],
	"chord_beats": 4,
	"passing_tone_chance": 0.15,
	"delay": [0.10, 0.20],
	"bass_cutoff": 0.30,
	"dj_lines": [
		"Car Rock Radio! Crank it up!",
		"That riff was insane! More rock ahead.",
		"Rock and roll on four wheels!",
		"Head banging while driving. Not recommended, but here we are.",
	],
}

const GENRE_JAZZ := {
	"name": "Smooth Jazz Drive",
	"melody_wave": "triangle",
	"bass_wave": "sine",
	"drum_pattern": "jazz",
	"scales": [
		[220.0, 261.6, 277.2, 293.7, 329.6, 370.0, 392.0, 440.0],
		[196.0, 233.1, 246.9, 261.6, 293.7, 311.1, 349.2, 392.0],
	],
	"tempo_min": 0.18,
	"tempo_max": 0.35,
	"notes_min": 50,
	"notes_max": 120,
	"melody_vol": 0.045,
	"bass_vol": 0.035,
	"perc_vol": 0.015,
	"adsr": [0.04, 0.1, 0.4, 0.15],
	"chord_beats": 2,
	"passing_tone_chance": 0.3,
	"delay": [0.20, 0.35],
	"bass_cutoff": 0.10,
	"dj_lines": [
		"Smooth Jazz Drive. Relax and cruise.",
		"That was silky smooth. More jazz coming up.",
		"Easy listening for easy driving.",
		"Jazz FM, where every note takes you somewhere.",
	],
}

const GENRE_ELECTRONIC := {
	"name": "Neon Beat FM",
	"melody_wave": "saw",
	"bass_wave": "saw",
	"drum_pattern": "electronic",
	"scales": [
		[130.8, 164.8, 196.0, 220.0, 261.6, 293.7, 329.6, 392.0],
		[65.4, 82.4, 98.0, 130.8, 164.8, 196.0, 261.6, 329.6],
	],
	"tempo_min": 0.06,
	"tempo_max": 0.1,
	"notes_min": 150,
	"notes_max": 400,
	"melody_vol": 0.045,
	"bass_vol": 0.055,
	"perc_vol": 0.04,
	"adsr": [0.002, 0.06, 0.2, 0.04],
	"chord_beats": 8,
	"passing_tone_chance": 0.1,
	"delay": [0.25, 0.35],
	"bass_cutoff": 0.18,
	"dj_lines": [
		"Neon Beat FM! Drop the bass!",
		"Electronic vibes for night riders.",
		"Beats per minute: way too many. You're welcome.",
		"Neon Beat, the sound of the city.",
	],
}

const GENRE_CLASSICAL := {
	"name": "Classical Cruise",
	"melody_wave": "sine",
	"bass_wave": "sine",
	"drum_pattern": "classical",
	"scales": [
		[261.6, 293.7, 329.6, 349.2, 392.0, 440.0, 493.9, 523.3],
		[196.0, 220.0, 246.9, 261.6, 293.7, 329.6, 349.2, 392.0],
		[349.2, 392.0, 440.0, 493.9, 523.3, 587.3, 659.3, 698.5],
	],
	"tempo_min": 0.25,
	"tempo_max": 0.45,
	"notes_min": 40,
	"notes_max": 100,
	"melody_vol": 0.05,
	"bass_vol": 0.03,
	"perc_vol": 0.0,
	"adsr": [0.08, 0.1, 0.8, 0.2],
	"chord_beats": 4,
	"passing_tone_chance": 0.25,
	"delay": [0.18, 0.30],
	"bass_cutoff": 0.12,
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

# Melody state
var _mel_phase := 0.0
var _mel_phase2 := 0.0
var _mel_freq := 440.0
var _mel_freq2 := 0.0
var _mel_timer := 0.0
var _mel_vol := 0.05
var _mel_wave := "square"

# Bass state
var _bass_phase := 0.0
var _bass_freq := 110.0
var _bass_timer := 0.0
var _bass_vol := 0.04
var _bass_wave := "sine"
var _bass_root := 0

# Drum pattern state
var _drum_pattern: Array = []
var _drum_step := 0
var _drum_timer := 0.0
var _perc_vol := 0.03
# Per-voice envelopes and phases: [kick, snare, hihat_closed, hihat_open]
var _drum_env := [0.0, 0.0, 0.0, 0.0]
var _drum_phase := [0.0, 0.0, 0.0, 0.0]

# Chorus/PWM state
var _chorus_phase := 0.0
var _pwm_phase := 0.0

# Bass low-pass filter state
var _bass_lp_prev := 0.0
var _bass_cutoff := 0.15

# Melody envelope state (0=off, 1=attack, 2=decay, 3=sustain, 4=release)
var _mel_env := 0.0
var _mel_env_state := 0

# Bass envelope state
var _bass_env := 0.0
var _bass_env_state := 0

# Precomputed envelope rates (per sample)
var _env_attack_rate := 0.0
var _env_decay_rate := 0.0
var _env_sustain := 0.7
var _env_release_rate := 0.0
var _env_release_time := 0.08

# Chord progression state
var _chord_progression: Array = []
var _chord_index := 0
var _chord_tones: Array = []
var _chord_beat_counter := 0
var _chord_beats_per_change := 4
var _passing_tone_chance := 0.2

# Delay effect state
var _delay_buf := PackedFloat32Array()
var _delay_write := 0
var _delay_mix := 0.15
var _delay_feedback := 0.25

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

	# Delay buffer
	_delay_buf.resize(DELAY_SIZE)
	_delay_buf.fill(0.0)
	_delay_write = 0

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

	if _radio_on:
		if _genre_index < _genres.size() - 1:
			_genre_index += 1
		else:
			_radio_on = false
			_is_playing_music = false
			_play_static_burst()
			_speak_tts("Radio off.")
			return
	else:
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
	_mel_wave = genre.get("melody_wave", "square")
	_mel_vol = genre.get("melody_vol", 0.05)
	_bass_wave = genre.get("bass_wave", "sine")
	_bass_vol = genre.get("bass_vol", 0.04)
	var dp_key: String = genre.get("drum_pattern", "pop")
	_drum_pattern = DRUM_PATTERNS.get(dp_key, DRUM_PATTERNS["pop"])
	_perc_vol = genre.get("perc_vol", 0.03)
	var adsr: Array = genre.get("adsr", [0.01, 0.05, 0.7, 0.08])
	var atk: float = maxf(adsr[0], 0.001)
	var dec: float = maxf(adsr[1], 0.001)
	_env_sustain = adsr[2]
	_env_release_time = adsr[3]
	var rel: float = maxf(adsr[3], 0.001)
	_env_attack_rate = 1.0 / (atk * MIX_RATE)
	_env_decay_rate = (1.0 - _env_sustain) / (dec * MIX_RATE)
	_env_release_rate = 1.0 / (rel * MIX_RATE)
	var delay_cfg: Array = genre.get("delay", [0.15, 0.25])
	_delay_mix = delay_cfg[0]
	_delay_feedback = delay_cfg[1]
	_bass_cutoff = genre.get("bass_cutoff", 0.15)
	_bass_lp_prev = 0.0
	_chord_beats_per_change = genre.get("chord_beats", 4)
	_passing_tone_chance = genre.get("passing_tone_chance", 0.2)
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

	# Reset drum sequencer
	_drum_step = 0
	_drum_timer = 0.0

	# Initialize chord progression
	_chord_progression = PROGRESSIONS[_rng.randi() % PROGRESSIONS.size()]
	_chord_index = 0
	_chord_beat_counter = 0
	_update_chord()

	# Bass follows chord root
	_bass_freq = _current_scale[_chord_tones[0] % _current_scale.size()] * 0.5

	# Build arpeggio pattern from chord tones for electronic genre
	if _mel_wave == "saw":
		_arp_pattern.clear()
		for i in range(4):
			var deg: int = _chord_tones[i % _chord_tones.size()]
			_arp_pattern.append(_current_scale[deg % _current_scale.size()])
		_arp_index = 0

	_mel_timer = 0.0
	_bass_timer = 0.0
	_pick_next_melody_note()
	_pick_next_bass_note()


func _update_chord() -> void:
	if _chord_progression.is_empty():
		return
	_chord_tones = _chord_progression[_chord_index % _chord_progression.size()]


func _pick_next_melody_note() -> void:
	# Advance chord progression
	_chord_beat_counter += 1
	if _chord_beat_counter >= _chord_beats_per_change:
		_chord_beat_counter = 0
		_chord_index += 1
		_update_chord()
		# Rebuild arp from new chord
		if _mel_wave == "saw" and not _chord_tones.is_empty():
			_arp_pattern.clear()
			for i in range(4):
				var deg: int = _chord_tones[i % _chord_tones.size()]
				_arp_pattern.append(
					_current_scale[deg % _current_scale.size()]
				)
			_arp_index = 0

	if _mel_wave == "saw" and not _arp_pattern.is_empty():
		_mel_freq = _arp_pattern[_arp_index % _arp_pattern.size()]
		_arp_index += 1
	elif not _chord_tones.is_empty() and _rng.randf() > _passing_tone_chance:
		# Pick from current chord tones
		var deg: int = _chord_tones[_rng.randi() % _chord_tones.size()]
		_mel_freq = _current_scale[deg % _current_scale.size()]
	else:
		# Passing tone - any scale note
		_mel_freq = _current_scale[
			_rng.randi() % _current_scale.size()
		]

	# Rock: add a fifth for power chord feel
	if _mel_wave == "distorted":
		_mel_freq2 = _mel_freq * 1.5
	else:
		_mel_freq2 = 0.0

	var duration := _beat_time * _rng.randi_range(1, 3)
	_mel_timer = duration
	_mel_phase = 0.0
	_mel_phase2 = 0.0
	_mel_env = 0.0
	_mel_env_state = 1


func _pick_next_bass_note() -> void:
	# Bass follows chord root
	if not _chord_tones.is_empty():
		var root_deg: int = _chord_tones[0]
		var choice := _rng.randi() % 3
		if choice == 0:
			_bass_freq = _current_scale[root_deg % _current_scale.size()] * 0.5
		elif choice == 1:
			# Fifth of chord
			var fifth_deg: int = _chord_tones[2 % _chord_tones.size()]
			_bass_freq = _current_scale[fifth_deg % _current_scale.size()] * 0.5
		else:
			# Chord third
			var third_deg: int = _chord_tones[1 % _chord_tones.size()]
			_bass_freq = _current_scale[third_deg % _current_scale.size()] * 0.5
	else:
		_bass_freq = _current_scale[0] * 0.5
	_bass_timer = _beat_time * _rng.randi_range(2, 4)
	_bass_phase = 0.0
	_bass_env = 0.0
	_bass_env_state = 1


func _fill_music(delta: float) -> void:
	if not _music_playback:
		return
	var frames := _music_playback.get_frames_available()
	var inv_rate := 1.0 / MIX_RATE
	for _i in range(frames):
		var mel := _gen_melody()
		var bass := _gen_bass()
		var perc := _gen_percussion()

		# Stereo panning: melody right (0.2), bass left (-0.15), perc center
		var left := mel * 0.8 + bass * 1.15 + perc
		var right := mel * 1.2 + bass * 0.85 + perc

		# Delay on mono sum, then add to both channels
		var mono := mel + bass + perc
		var delayed: float = _delay_buf[_delay_write]
		_delay_buf[_delay_write] = mono + delayed * _delay_feedback
		_delay_write += 1
		if _delay_write >= DELAY_SIZE:
			_delay_write = 0
		var delay_wet := delayed * _delay_mix
		left += delay_wet
		right += delay_wet

		_music_playback.push_frame(Vector2(
			clampf(left, -0.5, 0.5),
			clampf(right, -0.5, 0.5),
		))

		# Advance oscillator phases
		_mel_phase += _mel_freq * inv_rate
		if _mel_phase > 1.0:
			_mel_phase -= 1.0
		_chorus_phase += _mel_freq * 1.003 * inv_rate
		if _chorus_phase > 1.0:
			_chorus_phase -= 1.0
		_pwm_phase += 0.8 * inv_rate
		if _pwm_phase > 1.0:
			_pwm_phase -= 1.0
		if _mel_freq2 > 0.0:
			_mel_phase2 += _mel_freq2 * inv_rate
			if _mel_phase2 > 1.0:
				_mel_phase2 -= 1.0
		_bass_phase += _bass_freq * inv_rate
		if _bass_phase > 1.0:
			_bass_phase -= 1.0
		# Advance drum voice phases and envelopes
		_drum_phase[0] += inv_rate
		_drum_phase[1] += inv_rate
		_drum_phase[2] += inv_rate
		_drum_phase[3] += inv_rate
		_drum_env[0] = maxf(_drum_env[0] - inv_rate * 12.0, 0.0)
		_drum_env[1] = maxf(_drum_env[1] - inv_rate * 18.0, 0.0)
		_drum_env[2] = maxf(_drum_env[2] - inv_rate * 25.0, 0.0)
		_drum_env[3] = maxf(_drum_env[3] - inv_rate * 8.0, 0.0)

		# Advance melody envelope
		if _mel_env_state == 1:
			_mel_env += _env_attack_rate
			if _mel_env >= 1.0:
				_mel_env = 1.0
				_mel_env_state = 2
		elif _mel_env_state == 2:
			_mel_env -= _env_decay_rate
			if _mel_env <= _env_sustain:
				_mel_env = _env_sustain
				_mel_env_state = 3
		elif _mel_env_state == 4:
			_mel_env -= _env_release_rate
			if _mel_env <= 0.0:
				_mel_env = 0.0
				_mel_env_state = 0

		# Advance bass envelope
		if _bass_env_state == 1:
			_bass_env += _env_attack_rate
			if _bass_env >= 1.0:
				_bass_env = 1.0
				_bass_env_state = 2
		elif _bass_env_state == 2:
			_bass_env -= _env_decay_rate
			if _bass_env <= _env_sustain:
				_bass_env = _env_sustain
				_bass_env_state = 3
		elif _bass_env_state == 4:
			_bass_env -= _env_release_rate
			if _bass_env <= 0.0:
				_bass_env = 0.0
				_bass_env_state = 0

	# Trigger release when note is about to end
	if _mel_env_state != 4 and _mel_env_state != 0 and _mel_timer <= _env_release_time:
		_mel_env_state = 4
	if _bass_env_state != 4 and _bass_env_state != 0 and _bass_timer <= _env_release_time:
		_bass_env_state = 4

	# Melody note timing
	_mel_timer -= delta
	if _mel_timer <= 0.0:
		_notes_remaining -= 1
		if _notes_remaining <= 0:
			_is_playing_music = false
			_music_timer = _rng.randf_range(
				MUSIC_INTERVAL_MIN, MUSIC_INTERVAL_MAX
			)
			return
		_pick_next_melody_note()

	# Bass note timing
	_bass_timer -= delta
	if _bass_timer <= 0.0:
		_pick_next_bass_note()

	# Drum step sequencer (16 steps per bar, each step = beat_time)
	if not _drum_pattern.is_empty():
		_drum_timer -= delta
		if _drum_timer <= 0.0:
			_drum_timer += _beat_time
			_advance_drum_step()


func _gen_melody() -> float:
	if _mel_env <= 0.0:
		return 0.0
	var vol := _mel_vol * _mel_env
	var phase := _mel_phase

	# Chorus: detuned second oscillator at freq*1.003 (30% mix)
	var chorus_p := fmod(_chorus_phase, 1.0)

	if _mel_wave == "square":
		# PWM: duty cycle varies slowly between 0.35 and 0.65
		var duty := 0.5 + 0.15 * sin(_pwm_phase * TAU)
		var p := fmod(phase, 1.0)
		var wave := (1.0 if p < duty else -1.0) * vol
		var cp := fmod(chorus_p, 1.0)
		wave += (1.0 if cp < duty else -1.0) * (vol * 0.3)
		return wave

	if _mel_wave == "distorted":
		var wave := clampf(
			sin(phase * TAU) * 3.0, -1.0, 1.0
		) * vol
		# Chorus on distorted
		wave += clampf(
			sin(chorus_p * TAU) * 3.0, -1.0, 1.0
		) * (vol * 0.3)
		# Rock power chord fifth
		if _mel_freq2 > 0.0:
			wave += clampf(
				sin(_mel_phase2 * TAU) * 3.0, -1.0, 1.0
			) * (vol * 0.7)
		return wave

	if _mel_wave == "triangle":
		var vibrato := sin(phase * TAU * 0.02) * 0.003
		var p := fmod(phase + vibrato, 1.0)
		var tri := (2.0 * absf(2.0 * p - 1.0) - 1.0) * vol
		# Chorus
		var cp := fmod(chorus_p + vibrato, 1.0)
		tri += (2.0 * absf(2.0 * cp - 1.0) - 1.0) * (vol * 0.3)
		return tri

	if _mel_wave == "saw":
		var saw1 := (2.0 * fmod(phase, 1.0) - 1.0) * vol
		# Chorus replaces the old detuned saw
		var saw2 := (2.0 * fmod(chorus_p, 1.0) - 1.0) * (vol * 0.3)
		return saw1 + saw2

	# Sine (classical) with overtone + chorus
	var wave := sin(phase * TAU) * vol
	wave += sin(phase * TAU * 2.0) * (vol * 0.15)
	wave += sin(chorus_p * TAU) * (vol * 0.3)
	return wave


func _gen_bass() -> float:
	if _bass_env <= 0.0:
		return 0.0
	var phase := _bass_phase
	var vol := _bass_vol * _bass_env
	var raw := 0.0

	if _bass_wave == "square":
		raw = signf(sin(phase * TAU)) * vol
	elif _bass_wave == "saw":
		raw = (2.0 * fmod(phase, 1.0) - 1.0) * vol
	else:
		raw = sin(phase * TAU) * vol

	# One-pole low-pass filter for warmth
	_bass_lp_prev += _bass_cutoff * (raw - _bass_lp_prev)
	return _bass_lp_prev


func _advance_drum_step() -> void:
	if _drum_pattern.is_empty():
		return
	var step: Array = _drum_pattern[_drum_step % _drum_pattern.size()]
	_drum_step += 1
	for v in range(4):
		var vel: float = step[v]
		if vel > 0.0:
			_drum_env[v] = vel
			_drum_phase[v] = 0.0


func _gen_percussion() -> float:
	var out := 0.0

	# Kick: pitch-dropping sine
	var kick_e: float = _drum_env[0]
	if kick_e > 0.0:
		var vol: float = _perc_vol * kick_e
		var freq := lerpf(150.0, 50.0, 1.0 - kick_e)
		var ph: float = _drum_phase[0]
		out += sin(ph * freq * TAU) * vol

	# Snare: noise + tone
	var snare_e: float = _drum_env[1]
	if snare_e > 0.0:
		var vol: float = _perc_vol * snare_e
		var ph: float = _drum_phase[1]
		out += (_rng.randf() - 0.5) * vol * 0.8
		out += sin(ph * 200.0 * TAU) * vol * 0.4

	# Closed hihat: short high noise
	var hh_e: float = _drum_env[2]
	if hh_e > 0.0:
		var vol: float = _perc_vol * hh_e
		out += (_rng.randf() - 0.5) * vol * 0.5

	# Open hihat: longer high noise
	var oh_e: float = _drum_env[3]
	if oh_e > 0.0:
		var vol: float = _perc_vol * oh_e
		out += (_rng.randf() - 0.5) * vol * 0.6

	return out


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
