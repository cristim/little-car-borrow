extends CanvasLayer
## Displays 0-5 wanted stars in the top-right corner.
## Active stars flash when player is wanted.

const MAX_STARS := 5
const FLASH_SPEED := 4.0

var _level := 0
var _flash_timer := 0.0
var _stars: Array[ColorRect] = []


func _ready() -> void:
	EventBus.wanted_level_changed.connect(_on_wanted_level_changed)
	for i in range(MAX_STARS):
		var star := get_node("HBox/Star%d" % (i + 1)) as ColorRect
		_stars.append(star)
	_update_stars()


func _process(delta: float) -> void:
	if _level <= 0:
		return
	_flash_timer += delta * FLASH_SPEED
	var alpha := 0.6 + 0.4 * absf(sin(_flash_timer))
	for i in range(_level):
		_stars[i].modulate.a = alpha


func _on_wanted_level_changed(level: int) -> void:
	_level = level
	_flash_timer = 0.0
	_update_stars()


func _update_stars() -> void:
	for i in range(MAX_STARS):
		if i < _level:
			_stars[i].color = Color(1.0, 0.85, 0.0)
			_stars[i].modulate.a = 1.0
		else:
			_stars[i].color = Color(0.3, 0.3, 0.3)
			_stars[i].modulate.a = 0.4
