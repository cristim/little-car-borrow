extends Node
## Central audio manager with bus control and helper methods.

const BUS_MASTER := "Master"
const BUS_SFX := "SFX"
const BUS_MUSIC := "Music"
const BUS_AMBIENT := "Ambient"

var _buses_created := false


func _ready() -> void:
	_ensure_buses()


func _ensure_buses() -> void:
	if _buses_created:
		return
	for bus_name in [BUS_SFX, BUS_MUSIC, BUS_AMBIENT]:
		if AudioServer.get_bus_index(bus_name) == -1:
			var idx := AudioServer.bus_count
			AudioServer.add_bus(idx)
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, BUS_MASTER)
	_buses_created = true


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
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.bus = BUS_SFX
	player.position = position
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)


func play_ui(stream: AudioStream) -> void:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = BUS_SFX
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)
