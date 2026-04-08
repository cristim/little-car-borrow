extends GutTest
## Tests for AudioManager autoload — bus creation, volume control, SFX helpers.

const AudioManagerScript = preload("res://src/autoloads/audio_manager.gd")

var _am: Node


func before_each() -> void:
	_am = AudioManagerScript.new()
	_am.name = "AudioManager"
	add_child_autofree(_am)


# ================================================================
# Constants
# ================================================================


func test_bus_name_constants() -> void:
	assert_eq(_am.BUS_MASTER, "Master", "BUS_MASTER should be Master")
	assert_eq(_am.BUS_SFX, "SFX", "BUS_SFX should be SFX")
	assert_eq(_am.BUS_MUSIC, "Music", "BUS_MUSIC should be Music")
	assert_eq(_am.BUS_AMBIENT, "Ambient", "BUS_AMBIENT should be Ambient")


# ================================================================
# Bus creation (_ensure_buses)
# ================================================================


func test_ensure_buses_creates_sfx_bus() -> void:
	_am._ensure_buses()
	var idx := AudioServer.get_bus_index("SFX")
	assert_gt(idx, -1, "SFX bus should exist after _ensure_buses")


func test_ensure_buses_creates_music_bus() -> void:
	_am._ensure_buses()
	var idx := AudioServer.get_bus_index("Music")
	assert_gt(idx, -1, "Music bus should exist after _ensure_buses")


func test_ensure_buses_creates_ambient_bus() -> void:
	_am._ensure_buses()
	var idx := AudioServer.get_bus_index("Ambient")
	assert_gt(idx, -1, "Ambient bus should exist after _ensure_buses")


func test_ensure_buses_idempotent() -> void:
	_am._ensure_buses()
	var count_before := AudioServer.bus_count
	_am._buses_created = false  # reset guard to test re-entry
	_am._ensure_buses()
	# Buses already exist so no new ones should be added
	assert_eq(
		AudioServer.bus_count,
		count_before,
		"Calling _ensure_buses twice should not duplicate buses",
	)


func test_ensure_buses_sets_flag() -> void:
	_am._buses_created = false
	_am._ensure_buses()
	assert_true(_am._buses_created, "_buses_created should be true")


# ================================================================
# Volume control
# ================================================================


func test_set_bus_volume_and_get_bus_volume_roundtrip() -> void:
	_am._ensure_buses()
	_am.set_bus_volume("SFX", 0.5)
	var vol: float = _am.get_bus_volume("SFX")
	assert_almost_eq(vol, 0.5, 0.02, "Volume should round-trip at 0.5")


func test_set_bus_volume_clamps_above_one() -> void:
	_am._ensure_buses()
	_am.set_bus_volume("SFX", 2.0)
	var vol: float = _am.get_bus_volume("SFX")
	assert_almost_eq(vol, 1.0, 0.02, "Volume above 1.0 should clamp to 1.0")


func test_set_bus_volume_clamps_below_zero() -> void:
	_am._ensure_buses()
	_am.set_bus_volume("SFX", -0.5)
	var vol: float = _am.get_bus_volume("SFX")
	assert_almost_eq(vol, 0.0, 0.02, "Volume below 0.0 should clamp to 0.0")


func test_set_bus_volume_at_zero() -> void:
	_am._ensure_buses()
	_am.set_bus_volume("SFX", 0.0)
	var vol: float = _am.get_bus_volume("SFX")
	assert_almost_eq(vol, 0.0, 0.02, "Volume at 0.0 should be 0.0")


func test_set_bus_volume_at_one() -> void:
	_am._ensure_buses()
	_am.set_bus_volume("SFX", 1.0)
	var vol: float = _am.get_bus_volume("SFX")
	assert_almost_eq(vol, 1.0, 0.02, "Volume at 1.0 should be 1.0")


func test_get_bus_volume_nonexistent_returns_one() -> void:
	var vol: float = _am.get_bus_volume("NonExistentBus_XYZ")
	assert_almost_eq(vol, 1.0, 0.01, "Non-existent bus should return 1.0")


func test_set_bus_volume_nonexistent_does_not_crash() -> void:
	# Should silently return without error
	_am.set_bus_volume("NonExistentBus_XYZ", 0.5)
	assert_true(true, "Setting volume on non-existent bus should not crash")


# ================================================================
# Music bus effects
# ================================================================


func test_music_bus_has_delay_effect() -> void:
	_am._ensure_buses()
	var idx := AudioServer.get_bus_index("Music")
	if idx < 0:
		fail_test("Music bus not found")
		return
	var found_delay := false
	for i in range(AudioServer.get_bus_effect_count(idx)):
		if AudioServer.get_bus_effect(idx, i) is AudioEffectDelay:
			found_delay = true
			break
	assert_true(found_delay, "Music bus should have a delay effect")


func test_music_bus_has_distortion_effect() -> void:
	_am._ensure_buses()
	var idx := AudioServer.get_bus_index("Music")
	if idx < 0:
		fail_test("Music bus not found")
		return
	var found_dist := false
	for i in range(AudioServer.get_bus_effect_count(idx)):
		if AudioServer.get_bus_effect(idx, i) is AudioEffectDistortion:
			found_dist = true
			break
	assert_true(found_dist, "Music bus should have a distortion effect")


# ================================================================
# play_sfx / play_ui
# ================================================================


func test_play_sfx_adds_child_player() -> void:
	_am._ensure_buses()
	var stream := AudioStreamGenerator.new()
	var child_count_before := _am.get_child_count()
	_am.play_sfx(stream, Vector3(1, 2, 3))
	assert_gt(
		_am.get_child_count(),
		child_count_before,
		"play_sfx should add an AudioStreamPlayer3D child",
	)


func test_play_sfx_child_is_3d_player() -> void:
	_am._ensure_buses()
	var stream := AudioStreamGenerator.new()
	_am.play_sfx(stream, Vector3.ZERO)
	var last_child := _am.get_child(_am.get_child_count() - 1)
	assert_true(
		last_child is AudioStreamPlayer3D,
		"play_sfx child should be AudioStreamPlayer3D",
	)


func test_play_sfx_sets_bus_to_sfx() -> void:
	_am._ensure_buses()
	var stream := AudioStreamGenerator.new()
	_am.play_sfx(stream, Vector3.ZERO)
	var player := _am.get_child(_am.get_child_count() - 1) as AudioStreamPlayer3D
	assert_eq(player.bus, "SFX", "SFX player should use SFX bus")


func test_play_sfx_sets_position() -> void:
	_am._ensure_buses()
	var stream := AudioStreamGenerator.new()
	var pos := Vector3(10.0, 5.0, -3.0)
	_am.play_sfx(stream, pos)
	var player := _am.get_child(_am.get_child_count() - 1) as AudioStreamPlayer3D
	assert_eq(player.position, pos, "SFX player position should match")


func test_play_ui_adds_child_player() -> void:
	_am._ensure_buses()
	var stream := AudioStreamGenerator.new()
	var child_count_before := _am.get_child_count()
	_am.play_ui(stream)
	assert_gt(
		_am.get_child_count(),
		child_count_before,
		"play_ui should add an AudioStreamPlayer child",
	)


func test_play_ui_child_is_2d_player() -> void:
	_am._ensure_buses()
	var stream := AudioStreamGenerator.new()
	_am.play_ui(stream)
	var last_child := _am.get_child(_am.get_child_count() - 1)
	assert_true(
		last_child is AudioStreamPlayer,
		"play_ui child should be AudioStreamPlayer (non-3D)",
	)


func test_play_ui_sets_bus_to_sfx() -> void:
	_am._ensure_buses()
	var stream := AudioStreamGenerator.new()
	_am.play_ui(stream)
	var player := _am.get_child(_am.get_child_count() - 1) as AudioStreamPlayer
	assert_eq(player.bus, "SFX", "UI player should use SFX bus")


# ================================================================
# get_bus_volume / set_bus_volume
# ================================================================


func test_get_bus_volume_master_returns_valid_range() -> void:
	_am._ensure_buses()
	var vol: float = _am.get_bus_volume("Master")
	assert_true(vol >= 0.0 and vol <= 1.0, "Master volume should be in [0.0, 1.0]")


func test_get_bus_volume_nonexistent_fallback() -> void:
	var vol: float = _am.get_bus_volume("NonExistentBus_ABC")
	assert_almost_eq(vol, 1.0, 0.01, "Non-existent bus should return fallback 1.0")


func test_set_then_get_bus_volume_roundtrip() -> void:
	_am._ensure_buses()
	_am.set_bus_volume("SFX", 0.5)
	var vol: float = _am.get_bus_volume("SFX")
	assert_almost_eq(vol, 0.5, 0.02, "Volume should round-trip at 0.5")


# ================================================================
# play_sfx / play_ui with AudioStreamWAV
# ================================================================


func test_play_sfx_with_wav_stream_no_crash() -> void:
	_am._ensure_buses()
	var stream := AudioStreamWAV.new()
	_am.play_sfx(stream, Vector3.ZERO)
	assert_true(true, "play_sfx with AudioStreamWAV should not crash")


func test_play_ui_with_wav_stream_no_crash() -> void:
	_am._ensure_buses()
	var stream := AudioStreamWAV.new()
	_am.play_ui(stream)
	assert_true(true, "play_ui with AudioStreamWAV should not crash")
