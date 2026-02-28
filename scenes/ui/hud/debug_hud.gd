extends CanvasLayer
## Debug HUD showing speed, FPS, and vehicle state.

var _speed_kmh := 0.0

@onready var speed_label: Label = $SpeedLabel
@onready var fps_label: Label = $FPSLabel


func _ready() -> void:
	EventBus.vehicle_speed_changed.connect(_on_speed_changed)


func _process(_delta: float) -> void:
	fps_label.text = "FPS: %d" % Engine.get_frames_per_second()
	speed_label.text = "%d km/h" % roundi(_speed_kmh)


func _on_speed_changed(speed: float) -> void:
	_speed_kmh = speed
