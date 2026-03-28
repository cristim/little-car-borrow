extends GutTest
## Tests for scenes/world/radio_system.gd — constants, genre definitions,
## station switching, chord progressions, drum patterns, and callbacks.

const RadioScript = preload("res://scenes/world/radio_system.gd")

var _required_genre_keys := [
	"name", "mel_sample", "mel_root_hz", "bas_sample", "bas_root_hz",
	"drum_pattern", "drum_kit", "scales", "tempo_min", "tempo_max",
	"notes_min", "notes_max", "mel_vol_db", "bas_vol_db", "drum_vol_db",
	"chord_beats", "passing_tone_chance", "melody_mode", "delay_ms",
	"delay_feedback_db", "dist_drive", "dj_lines",
]


# ==========================================================================
# Constants
# ==========================================================================

func test_music_interval_range() -> void:
	assert_lt(
		RadioScript.MUSIC_INTERVAL_MIN,
		RadioScript.MUSIC_INTERVAL_MAX,
	)


func test_dj_interval_range() -> void:
	assert_lt(
		RadioScript.DJ_INTERVAL_MIN,
		RadioScript.DJ_INTERVAL_MAX,
	)


func test_police_announce_interval() -> void:
	assert_eq(RadioScript.POLICE_ANNOUNCE_INTERVAL, 20.0)


func test_static_duration() -> void:
	assert_eq(RadioScript.STATIC_DURATION, 0.4)


func test_mix_rate() -> void:
	assert_eq(RadioScript.MIX_RATE, 22050.0)


# ==========================================================================
# Genre definitions — each genre has required keys
# ==========================================================================

func _assert_genre_complete(genre: Dictionary, genre_name: String) -> void:
	for key in _required_genre_keys:
		assert_true(
			genre.has(key),
			"%s should have key '%s'" % [genre_name, key],
		)


func test_genre_pop_complete() -> void:
	_assert_genre_complete(RadioScript.GENRE_POP, "GENRE_POP")


func test_genre_rock_complete() -> void:
	_assert_genre_complete(RadioScript.GENRE_ROCK, "GENRE_ROCK")


func test_genre_jazz_complete() -> void:
	_assert_genre_complete(RadioScript.GENRE_JAZZ, "GENRE_JAZZ")


func test_genre_electronic_complete() -> void:
	_assert_genre_complete(
		RadioScript.GENRE_ELECTRONIC, "GENRE_ELECTRONIC",
	)


func test_genre_classical_complete() -> void:
	_assert_genre_complete(
		RadioScript.GENRE_CLASSICAL, "GENRE_CLASSICAL",
	)


# ==========================================================================
# Genre tempo ranges
# ==========================================================================

func test_genre_tempo_min_less_than_max() -> void:
	var genres := [
		RadioScript.GENRE_POP, RadioScript.GENRE_ROCK,
		RadioScript.GENRE_JAZZ, RadioScript.GENRE_ELECTRONIC,
		RadioScript.GENRE_CLASSICAL,
	]
	for g in genres:
		assert_lt(
			g.tempo_min, g.tempo_max,
			"%s tempo_min should be less than tempo_max" % g.name,
		)


func test_genre_notes_min_less_than_max() -> void:
	var genres := [
		RadioScript.GENRE_POP, RadioScript.GENRE_ROCK,
		RadioScript.GENRE_JAZZ, RadioScript.GENRE_ELECTRONIC,
		RadioScript.GENRE_CLASSICAL,
	]
	for g in genres:
		assert_lt(
			g.notes_min, g.notes_max,
			"%s notes_min should be less than notes_max" % g.name,
		)


# ==========================================================================
# Drum patterns
# ==========================================================================

func test_five_drum_patterns_defined() -> void:
	assert_eq(
		RadioScript.DRUM_PATTERNS.size(), 5,
		"Should have 5 drum patterns",
	)


func test_all_drum_patterns_have_16_steps() -> void:
	for key: String in RadioScript.DRUM_PATTERNS:
		var pattern: Array = RadioScript.DRUM_PATTERNS[key]
		assert_eq(
			pattern.size(), 16,
			"Drum pattern '%s' should have 16 steps" % key,
		)


func test_drum_pattern_step_has_4_voices() -> void:
	for key: String in RadioScript.DRUM_PATTERNS:
		var pattern: Array = RadioScript.DRUM_PATTERNS[key]
		for i in pattern.size():
			assert_eq(
				pattern[i].size(), 4,
				"Pattern '%s' step %d should have 4 voices" % [key, i],
			)


func test_classical_drum_pattern_all_silent() -> void:
	var classical: Array = RadioScript.DRUM_PATTERNS["classical"]
	for step in classical:
		for vel: float in step:
			assert_eq(
				vel, 0.0,
				"Classical drum pattern should be all silent",
			)


func test_drum_patterns_match_genre_references() -> void:
	var genres := [
		RadioScript.GENRE_POP, RadioScript.GENRE_ROCK,
		RadioScript.GENRE_JAZZ, RadioScript.GENRE_ELECTRONIC,
		RadioScript.GENRE_CLASSICAL,
	]
	for g in genres:
		var key: String = g.drum_pattern
		assert_true(
			RadioScript.DRUM_PATTERNS.has(key),
			"Genre '%s' references drum pattern '%s' which must exist" % [
				g.name, key,
			],
		)


# ==========================================================================
# Chord progressions
# ==========================================================================

func test_six_progressions_defined() -> void:
	assert_eq(
		RadioScript.PROGRESSIONS.size(), 6,
		"Should have 6 chord progressions",
	)


func test_progressions_have_4_chords() -> void:
	for i in RadioScript.PROGRESSIONS.size():
		assert_eq(
			RadioScript.PROGRESSIONS[i].size(), 4,
			"Progression %d should have 4 chords" % i,
		)


func test_progression_chords_have_3_notes() -> void:
	for i in RadioScript.PROGRESSIONS.size():
		for j in RadioScript.PROGRESSIONS[i].size():
			assert_eq(
				RadioScript.PROGRESSIONS[i][j].size(), 3,
				"Progression %d chord %d should have 3 notes" % [i, j],
			)


# ==========================================================================
# Drum samples lookup
# ==========================================================================

func test_drum_samples_has_kick() -> void:
	assert_true(RadioScript.DRUM_SAMPLES.has("kick"))


func test_drum_samples_has_snare() -> void:
	assert_true(RadioScript.DRUM_SAMPLES.has("snare"))


func test_drum_samples_has_hihat_closed() -> void:
	assert_true(RadioScript.DRUM_SAMPLES.has("hihat_closed"))


func test_drum_samples_has_hihat_open() -> void:
	assert_true(RadioScript.DRUM_SAMPLES.has("hihat_open"))


func test_drum_samples_has_ride() -> void:
	assert_true(RadioScript.DRUM_SAMPLES.has("ride"))


func test_drum_samples_has_snare_brush() -> void:
	assert_true(RadioScript.DRUM_SAMPLES.has("snare_brush"))


func test_all_genre_drum_kits_reference_valid_samples() -> void:
	var genres := [
		RadioScript.GENRE_POP, RadioScript.GENRE_ROCK,
		RadioScript.GENRE_JAZZ, RadioScript.GENRE_ELECTRONIC,
		RadioScript.GENRE_CLASSICAL,
	]
	for g in genres:
		var kit: Array = g.drum_kit
		for sample_name: String in kit:
			assert_true(
				RadioScript.DRUM_SAMPLES.has(sample_name),
				"Genre '%s' drum kit references '%s' which must exist" % [
					g.name, sample_name,
				],
			)


# ==========================================================================
# Police lines
# ==========================================================================

func test_police_lines_wanted_not_empty() -> void:
	assert_gt(
		RadioScript.POLICE_LINES_WANTED.size(), 0,
		"Should have wanted police lines",
	)


func test_police_lines_calm_not_empty() -> void:
	assert_gt(
		RadioScript.POLICE_LINES_CALM.size(), 0,
		"Should have calm police lines",
	)


func test_all_dj_lines_non_empty() -> void:
	var genres := [
		RadioScript.GENRE_POP, RadioScript.GENRE_ROCK,
		RadioScript.GENRE_JAZZ, RadioScript.GENRE_ELECTRONIC,
		RadioScript.GENRE_CLASSICAL,
	]
	for g in genres:
		var lines: Array = g.dj_lines
		assert_gt(
			lines.size(), 0,
			"Genre '%s' should have DJ lines" % g.name,
		)
		for line: String in lines:
			assert_gt(
				line.length(), 0,
				"DJ line should not be empty",
			)


# ==========================================================================
# Initial state
# ==========================================================================

func test_radio_starts_off() -> void:
	var radio: Node = RadioScript.new()
	add_child_autofree(radio)
	assert_false(radio._radio_on, "Radio should start off")


func test_genre_index_starts_at_zero() -> void:
	var radio: Node = RadioScript.new()
	add_child_autofree(radio)
	assert_eq(radio._genre_index, 0)


func test_not_playing_music_initially() -> void:
	var radio: Node = RadioScript.new()
	add_child_autofree(radio)
	assert_false(radio._is_playing_music)


func test_tts_queue_starts_empty() -> void:
	var radio: Node = RadioScript.new()
	add_child_autofree(radio)
	assert_eq(radio._tts_queue.size(), 0)


# ==========================================================================
# _speak_tts
# ==========================================================================

func test_speak_tts_with_empty_voice_id_does_nothing() -> void:
	var radio: Node = RadioScript.new()
	add_child_autofree(radio)
	radio._tts_voice_id = ""
	radio._speak_tts("Hello world")
	assert_eq(
		radio._tts_queue.size(), 0,
		"Should not queue TTS without a voice ID",
	)


func test_speak_tts_with_voice_id_queues() -> void:
	var radio: Node = RadioScript.new()
	add_child_autofree(radio)
	radio._tts_voice_id = "test_voice"
	radio._speak_tts("Hello")
	assert_eq(radio._tts_queue.size(), 1)
	assert_eq(radio._tts_queue[0], "Hello")


func test_speak_tts_queues_multiple() -> void:
	var radio: Node = RadioScript.new()
	add_child_autofree(radio)
	radio._tts_voice_id = "test_voice"
	radio._speak_tts("One")
	radio._speak_tts("Two")
	assert_eq(radio._tts_queue.size(), 2)


# ==========================================================================
# _play_static_burst
# ==========================================================================

func test_play_static_burst_sets_state() -> void:
	var radio: Node = RadioScript.new()
	add_child_autofree(radio)
	radio._play_static_burst()
	assert_true(radio._playing_static)
	assert_almost_eq(
		radio._static_timer,
		RadioScript.STATIC_DURATION,
		0.001,
	)


# ==========================================================================
# _on_vehicle_entered callback
# ==========================================================================

func test_on_vehicle_entered_turns_radio_on() -> void:
	var radio: Node = RadioScript.new()
	add_child_autofree(radio)
	await get_tree().process_frame
	radio._on_vehicle_entered(Node.new())
	assert_true(radio._radio_on, "Entering vehicle should turn radio on")


func test_on_vehicle_entered_resets_music() -> void:
	var radio: Node = RadioScript.new()
	add_child_autofree(radio)
	await get_tree().process_frame
	radio._is_playing_music = true
	radio._on_vehicle_entered(Node.new())
	assert_false(
		radio._is_playing_music,
		"Entering vehicle should reset music playing state",
	)


# ==========================================================================
# _on_vehicle_exited callback
# ==========================================================================

func test_on_vehicle_exited_turns_radio_off() -> void:
	var radio: Node = RadioScript.new()
	add_child_autofree(radio)
	await get_tree().process_frame
	radio._radio_on = true
	radio._on_vehicle_exited(Node.new())
	assert_false(radio._radio_on, "Exiting vehicle should turn radio off")


func test_on_vehicle_exited_clears_tts_queue() -> void:
	var radio: Node = RadioScript.new()
	add_child_autofree(radio)
	await get_tree().process_frame
	radio._tts_voice_id = "test"
	radio._speak_tts("Hello")
	radio._on_vehicle_exited(Node.new())
	assert_eq(
		radio._tts_queue.size(), 0,
		"Exiting vehicle should clear TTS queue",
	)


# ==========================================================================
# _on_wanted_changed callback
# ==========================================================================

func test_on_wanted_changed_with_radio_off_does_nothing() -> void:
	var radio: Node = RadioScript.new()
	add_child_autofree(radio)
	await get_tree().process_frame
	radio._radio_on = false
	radio._tts_voice_id = "test"
	radio._on_wanted_changed(3)
	assert_eq(
		radio._tts_queue.size(), 0,
		"Should not queue announcements when radio is off",
	)


func test_on_wanted_changed_high_level_reduces_police_timer() -> void:
	var radio: Node = RadioScript.new()
	add_child_autofree(radio)
	await get_tree().process_frame
	radio._radio_on = true
	radio._police_timer = 20.0
	radio._on_wanted_changed(3)
	assert_lte(
		radio._police_timer, 8.0,
		"High wanted level should cap police timer at 8",
	)


func test_on_wanted_changed_level_1_plays_static() -> void:
	var radio: Node = RadioScript.new()
	add_child_autofree(radio)
	await get_tree().process_frame
	radio._radio_on = true
	radio._playing_static = false
	radio._on_wanted_changed(1)
	assert_true(
		radio._playing_static,
		"Wanted level 1+ should trigger static burst",
	)


# ==========================================================================
# Genre melody modes
# ==========================================================================

func test_electronic_uses_arp_mode() -> void:
	assert_eq(
		RadioScript.GENRE_ELECTRONIC.melody_mode, "arp",
		"Electronic genre should use arp melody mode",
	)


func test_rock_uses_power_chord_mode() -> void:
	assert_eq(
		RadioScript.GENRE_ROCK.melody_mode, "power_chord",
		"Rock genre should use power_chord melody mode",
	)


func test_pop_uses_chord_mode() -> void:
	assert_eq(RadioScript.GENRE_POP.melody_mode, "chord")


func test_jazz_uses_chord_mode() -> void:
	assert_eq(RadioScript.GENRE_JAZZ.melody_mode, "chord")


func test_classical_uses_chord_mode() -> void:
	assert_eq(RadioScript.GENRE_CLASSICAL.melody_mode, "chord")


# ==========================================================================
# Genre distortion
# ==========================================================================

func test_only_rock_has_distortion() -> void:
	assert_gt(
		RadioScript.GENRE_ROCK.dist_drive, 0.0,
		"Rock should have distortion",
	)
	assert_eq(RadioScript.GENRE_POP.dist_drive, 0.0)
	assert_eq(RadioScript.GENRE_JAZZ.dist_drive, 0.0)
	assert_eq(RadioScript.GENRE_ELECTRONIC.dist_drive, 0.0)
	assert_eq(RadioScript.GENRE_CLASSICAL.dist_drive, 0.0)
