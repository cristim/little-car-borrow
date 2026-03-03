extends Node
## Persists user settings (display, audio) to user://settings.cfg.
## Loads and applies saved values on startup.

const SAVE_PATH := "user://settings.cfg"

const SEC_DISPLAY := "display"
const SEC_AUDIO := "audio"


func _ready() -> void:
	load_settings()


func save() -> void:
	var cfg := ConfigFile.new()

	# Display
	var is_fs := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	cfg.set_value(SEC_DISPLAY, "fullscreen", is_fs)

	# Audio bus volumes
	for bus_name in ["Master", "SFX", "Music", "Ambient"]:
		cfg.set_value(SEC_AUDIO, bus_name, AudioManager.get_bus_volume(bus_name))

	cfg.save(SAVE_PATH)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return

	# Display
	if cfg.has_section_key(SEC_DISPLAY, "fullscreen"):
		var fs: bool = cfg.get_value(SEC_DISPLAY, "fullscreen", false)
		if fs:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

	# Audio bus volumes
	for bus_name in ["Master", "SFX", "Music", "Ambient"]:
		if cfg.has_section_key(SEC_AUDIO, bus_name):
			var vol: float = cfg.get_value(SEC_AUDIO, bus_name, 1.0)
			AudioManager.set_bus_volume(bus_name, vol)
