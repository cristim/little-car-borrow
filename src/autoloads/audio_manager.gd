extends Node
## Central audio manager with bus control and helper methods.

const BUS_MASTER := "Master"
const BUS_SFX := "SFX"
const BUS_MUSIC := "Music"
const BUS_AMBIENT := "Ambient"

func _ready() -> void:
	_ensure_buses()


func _ensure_buses() -> void:
	if AudioServer.bus_count > 1:
		return
	for bus_name in [BUS_SFX, BUS_MUSIC, BUS_AMBIENT]:
		if AudioServer.get_bus_index(bus_name) == -1:
			var idx := AudioServer.bus_count
			AudioServer.add_bus(idx)
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, BUS_MASTER)
	_setup_music_bus_effects()


func _setup_music_bus_effects() -> void:
	var idx := AudioServer.get_bus_index(BUS_MUSIC)
	if idx < 0:
		return
	# Slot 0: Delay effect (adjusted per-genre by radio_system)
	var delay := AudioEffectDelay.new()
	delay.tap1_active = true
	delay.tap1_delay_ms = 300.0
	delay.tap1_level_db = -14.0
	delay.tap2_active = false
	delay.feedback_active = true
	delay.feedback_delay_ms = 300.0
	delay.feedback_level_db = -14.0
	delay.dry = 1.0
	AudioServer.add_bus_effect(idx, delay)
	# Slot 1: Distortion (off by default, enabled for rock)
	var dist := AudioEffectDistortion.new()
	dist.mode = AudioEffectDistortion.MODE_CLIP
	dist.drive = 0.0
	dist.pre_gain = 0.0
	dist.post_gain = 0.0
	dist.keep_hf_hz = 8000.0
	AudioServer.add_bus_effect(idx, dist)


func set_bus_volume(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(clampf(linear, 0.0, 1.0)))


func get_bus_volume(bus_name: String) -> float:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		return db_to_linear(AudioServer.get_bus_volume_db(idx))
	return 1.0


func play_sfx(stream: AudioStream, position: Vector3) -> void:
	if not stream:
		return
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.bus = BUS_SFX
	player.position = position
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)


func play_ui(stream: AudioStream) -> void:
	if not stream:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = BUS_SFX
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)
