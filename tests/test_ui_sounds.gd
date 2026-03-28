extends GutTest
## Tests for UISounds — procedural wanted-level tone generation.

const UISoundsScript = preload("res://scenes/ui/ui_sounds.gd")


func _build_ui_sounds() -> Node:
	var snd: Node = UISoundsScript.new()
	add_child_autofree(snd)
	# Wait for _ready to create AudioStreamPlayer and connect signal
	return snd


# ================================================================
# Constants
# ================================================================

func test_constants() -> void:
	var snd := _build_ui_sounds()
	assert_eq(snd.SAMPLE_RATE, 22050.0, "Sample rate should be 22050")
	assert_eq(snd.TONE_DURATION, 0.15, "Tone duration should be 0.15s")
	assert_eq(snd.BASE_FREQ, 440.0, "Base frequency should be 440 Hz")


# ================================================================
# Initialization
# ================================================================

func test_ready_creates_audio_player() -> void:
	var snd := _build_ui_sounds()
	await get_tree().process_frame

	assert_not_null(snd._player, "Audio player should be created")
	assert_true(snd._player is AudioStreamPlayer, "Should be AudioStreamPlayer")


func test_ready_sets_sfx_bus() -> void:
	var snd := _build_ui_sounds()
	await get_tree().process_frame

	assert_eq(snd._player.bus, "SFX", "Audio bus should be SFX")


func test_ready_creates_generator_stream() -> void:
	var snd := _build_ui_sounds()
	await get_tree().process_frame

	assert_true(
		snd._player.stream is AudioStreamGenerator,
		"Stream should be AudioStreamGenerator",
	)
	var gen := snd._player.stream as AudioStreamGenerator
	assert_eq(gen.mix_rate, 22050.0, "Mix rate should match SAMPLE_RATE")


func test_ready_player_is_playing() -> void:
	var snd := _build_ui_sounds()
	await get_tree().process_frame

	assert_true(snd._player.playing, "Player should be playing after ready")


func test_ready_gets_playback() -> void:
	var snd := _build_ui_sounds()
	await get_tree().process_frame

	assert_not_null(snd._playback, "Playback should be obtained")


func test_ready_connects_wanted_signal() -> void:
	var snd := _build_ui_sounds()
	await get_tree().process_frame

	assert_true(
		EventBus.wanted_level_changed.is_connected(
			snd._on_wanted_level_changed,
		),
		"Should connect to wanted_level_changed signal",
	)


# ================================================================
# Wanted level tone queue
# ================================================================

func test_wanted_level_1_queues_one_ascending_tone() -> void:
	var snd := _build_ui_sounds()
	await get_tree().process_frame

	snd._on_wanted_level_changed(1)

	assert_eq(snd._tone_queue.size(), 1, "Level 1 should queue 1 tone")
	assert_almost_eq(
		snd._tone_queue[0], 440.0, 0.01,
		"First tone should be BASE_FREQ",
	)


func test_wanted_level_3_queues_three_ascending_tones() -> void:
	var snd := _build_ui_sounds()
	await get_tree().process_frame

	snd._on_wanted_level_changed(3)

	assert_eq(snd._tone_queue.size(), 3, "Level 3 should queue 3 tones")
	assert_almost_eq(snd._tone_queue[0], 440.0, 0.01, "Tone 0: 440 Hz")
	assert_almost_eq(snd._tone_queue[1], 540.0, 0.01, "Tone 1: 540 Hz")
	assert_almost_eq(snd._tone_queue[2], 640.0, 0.01, "Tone 2: 640 Hz")


func test_wanted_level_5_queues_five_ascending_tones() -> void:
	var snd := _build_ui_sounds()
	await get_tree().process_frame

	snd._on_wanted_level_changed(5)

	assert_eq(snd._tone_queue.size(), 5, "Level 5 should queue 5 tones")
	assert_almost_eq(snd._tone_queue[4], 840.0, 0.01, "Tone 4: 840 Hz")


func test_wanted_level_0_queues_descending_tones() -> void:
	var snd := _build_ui_sounds()
	await get_tree().process_frame

	snd._on_wanted_level_changed(0)

	assert_eq(snd._tone_queue.size(), 2, "Level 0 should queue 2 descending tones")
	assert_almost_eq(snd._tone_queue[0], 440.0, 0.01, "First tone: BASE_FREQ")
	assert_almost_eq(snd._tone_queue[1], 340.0, 0.01, "Second tone: BASE_FREQ - 100")


func test_wanted_change_clears_previous_queue() -> void:
	var snd := _build_ui_sounds()
	await get_tree().process_frame

	snd._on_wanted_level_changed(3)
	assert_eq(snd._tone_queue.size(), 3, "3 tones queued")

	snd._on_wanted_level_changed(1)
	assert_eq(snd._tone_queue.size(), 1, "Queue cleared and replaced with 1 tone")


func test_wanted_via_event_bus_signal() -> void:
	var snd := _build_ui_sounds()
	await get_tree().process_frame

	EventBus.wanted_level_changed.emit(2)

	assert_eq(snd._tone_queue.size(), 2, "Signal should trigger tone queue")
	assert_almost_eq(snd._tone_queue[0], 440.0, 0.01, "Tone 0 via signal")
	assert_almost_eq(snd._tone_queue[1], 540.0, 0.01, "Tone 1 via signal")


# ================================================================
# Process / tone consumption
# ================================================================

func test_initial_state_empty_queue() -> void:
	var snd := _build_ui_sounds()
	await get_tree().process_frame

	assert_eq(snd._tone_queue.size(), 0, "Queue should be empty initially")
	assert_eq(snd._tone_remaining, 0.0, "No tone remaining initially")
	assert_eq(snd._phase, 0.0, "Phase should be 0 initially")


func test_process_with_empty_queue_does_not_crash() -> void:
	var snd := _build_ui_sounds()
	await get_tree().process_frame

	# Let several frames run with empty queue
	for _i in range(5):
		await get_tree().process_frame
	assert_true(true, "Process with empty queue should not crash")


func test_process_consumes_tones() -> void:
	var snd := _build_ui_sounds()
	await get_tree().process_frame

	snd._on_wanted_level_changed(1)
	assert_eq(snd._tone_queue.size(), 1, "One tone queued")

	# In headless mode get_frames_available() may return 0, so manually
	# simulate consumption: set remaining to near-zero and call _process
	# so the next frame drains the queue entry.
	snd._tone_remaining = 1.0 / 22050.0  # last sample of tone
	for _i in range(30):
		await get_tree().process_frame

	assert_eq(snd._tone_queue.size(), 0, "Tone should be consumed after processing")


func test_process_without_playback_does_not_crash() -> void:
	var snd := _build_ui_sounds()
	await get_tree().process_frame

	snd._playback = null
	await get_tree().process_frame
	assert_true(true, "Null playback should exit early without crash")
