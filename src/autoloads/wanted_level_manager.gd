extends Node
## Tracks crime heat and wanted level (0-5 stars).
## Listens to EventBus.crime_committed, accumulates heat, and emits
## wanted_level_changed when crossing thresholds.

const HEAT_THRESHOLDS := [0.0, 20.0, 50.0, 100.0, 170.0, 260.0]
const HEAT_DECAY_RATE := 3.0
const HEAT_DECAY_DELAY := 5.0

var wanted_level := 0
var heat := 0.0
var _decay_cooldown := 0.0


func _ready() -> void:
	EventBus.crime_committed.connect(_on_crime_committed)


func _process(delta: float) -> void:
	if heat <= 0.0:
		return

	if _decay_cooldown > 0.0:
		_decay_cooldown -= delta
		return

	heat = maxf(heat - HEAT_DECAY_RATE * delta, 0.0)
	_update_level()


func _on_crime_committed(_crime_type: String, heat_points: int) -> void:
	heat += heat_points
	_decay_cooldown = HEAT_DECAY_DELAY
	_update_level()


func _update_level() -> void:
	var new_level := 0
	for i in range(HEAT_THRESHOLDS.size()):
		if heat >= HEAT_THRESHOLDS[i]:
			new_level = i
	if new_level != wanted_level:
		wanted_level = new_level
		EventBus.wanted_level_changed.emit(wanted_level)


func clear() -> void:
	heat = 0.0
	wanted_level = 0
	_decay_cooldown = 0.0
	EventBus.wanted_level_changed.emit(0)
