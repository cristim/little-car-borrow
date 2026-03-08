extends Node
## Manages a 24-hour day-night cycle compressed to real-time.
## Emits EventBus.time_of_day_changed every half-hour increment.

const CYCLE_DURATION := 1200.0  # 20 real minutes = 24 game hours
const HOURS_PER_SECOND := 24.0 / CYCLE_DURATION
const EMIT_INTERVAL := 0.5  # emit signal every 0.5 game-hours

var current_hour := 21.0  # start at 9 PM (evening for testing)
var time_speed := 1.0  # debug multiplier

var _last_emitted_hour := -1.0


func _ready() -> void:
	_emit_time()


func _process(delta: float) -> void:
	current_hour += delta * HOURS_PER_SECOND * time_speed
	current_hour = fmod(current_hour, 24.0)

	var quantized := snappedf(current_hour, EMIT_INTERVAL)
	if not is_equal_approx(quantized, _last_emitted_hour):
		_emit_time()


func is_night() -> bool:
	return current_hour < 6.0 or current_hour > 20.0


func is_dusk_or_dawn() -> bool:
	return (
		(current_hour >= 5.0 and current_hour <= 7.0)
		or (current_hour >= 17.0 and current_hour <= 20.0)
	)


func get_sun_progress() -> float:
	# 0.0 at hour 0, 0.5 at noon, 1.0 at hour 24
	return current_hour / 24.0


func _emit_time() -> void:
	_last_emitted_hour = snappedf(current_hour, EMIT_INTERVAL)
	EventBus.time_of_day_changed.emit(current_hour)
