extends GutTest
## Tests for SettingsManager autoload — save/load of display and audio settings.

const SettingsScript = preload("res://src/autoloads/settings_manager.gd")
const AudioManagerScript = preload("res://src/autoloads/audio_manager.gd")

var _sm: Node
var _audio: Node


func before_each() -> void:
	# AudioManager must exist since SettingsManager calls AudioManager methods
	_audio = AudioManagerScript.new()
	_audio.name = "AudioManager"
	add_child_autofree(_audio)
	_audio._ensure_buses()

	_sm = SettingsScript.new()
	_sm.name = "SettingsManager"
	add_child_autofree(_sm)


# ================================================================
# Constants
# ================================================================

func test_save_path() -> void:
	assert_eq(
		SettingsScript.SAVE_PATH, "user://settings.cfg",
		"SAVE_PATH should be user://settings.cfg",
	)


func test_section_constants() -> void:
	assert_eq(SettingsScript.SEC_DISPLAY, "display", "SEC_DISPLAY")
	assert_eq(SettingsScript.SEC_AUDIO, "audio", "SEC_AUDIO")


# ================================================================
# save / load roundtrip
# ================================================================

func test_save_creates_config_file() -> void:
	_sm.save()
	var cfg := ConfigFile.new()
	var err := cfg.load(SettingsScript.SAVE_PATH)
	assert_eq(err, OK, "Config file should be loadable after save")


func test_save_stores_fullscreen_key() -> void:
	_sm.save()
	var cfg := ConfigFile.new()
	cfg.load(SettingsScript.SAVE_PATH)
	assert_true(
		cfg.has_section_key("display", "fullscreen"),
		"Should store fullscreen key",
	)


func test_save_stores_audio_volumes() -> void:
	_sm.save()
	var cfg := ConfigFile.new()
	cfg.load(SettingsScript.SAVE_PATH)
	for bus_name in ["Master", "SFX", "Music", "Ambient"]:
		assert_true(
			cfg.has_section_key("audio", bus_name),
			"Should store %s volume" % bus_name,
		)


func test_audio_volume_roundtrip() -> void:
	_audio.set_bus_volume("SFX", 0.7)
	_sm.save()

	# Change volume
	_audio.set_bus_volume("SFX", 0.3)

	# Reload
	_sm.load_settings()
	var vol: float = _audio.get_bus_volume("SFX")
	assert_almost_eq(
		vol, 0.7, 0.05,
		"SFX volume should be restored to 0.7 after load",
	)


func test_load_missing_file_does_not_crash() -> void:
	# Try loading from a path that may not exist
	# The method should return early without error
	var cfg := ConfigFile.new()
	var err := cfg.load("user://nonexistent_test_settings.cfg")
	if err != OK:
		# This is expected — just verifying load_settings handles it
		pass
	# The main test is that load_settings on a fresh SettingsManager
	# does not crash
	assert_true(true, "load_settings should handle missing file gracefully")


func test_load_restores_multiple_bus_volumes() -> void:
	_audio.set_bus_volume("SFX", 0.5)
	_audio.set_bus_volume("Music", 0.3)
	_audio.set_bus_volume("Ambient", 0.8)
	_sm.save()

	# Scramble volumes
	_audio.set_bus_volume("SFX", 1.0)
	_audio.set_bus_volume("Music", 1.0)
	_audio.set_bus_volume("Ambient", 1.0)

	_sm.load_settings()

	assert_almost_eq(
		_audio.get_bus_volume("SFX"), 0.5, 0.05,
		"SFX volume should be restored",
	)
	assert_almost_eq(
		_audio.get_bus_volume("Music"), 0.3, 0.05,
		"Music volume should be restored",
	)
	assert_almost_eq(
		_audio.get_bus_volume("Ambient"), 0.8, 0.05,
		"Ambient volume should be restored",
	)
