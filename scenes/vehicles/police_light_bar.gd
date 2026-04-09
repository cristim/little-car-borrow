extends Node3D
## Alternating red/blue police light bar with OmniLight3D nodes.

const FLASH_INTERVAL := 0.15

var lights_active := false

var _timer := 0.0
var _red_on := true
var _red_light: OmniLight3D = null
var _blue_light: OmniLight3D = null
var _lights_were_active := false


func _ready() -> void:
	_red_light = OmniLight3D.new()
	_red_light.light_color = Color(1.0, 0.1, 0.1)
	_red_light.light_energy = 3.0
	_red_light.omni_range = 15.0
	_red_light.position = Vector3(-0.4, 0.0, 0.0)
	add_child(_red_light)

	_blue_light = OmniLight3D.new()
	_blue_light.light_color = Color(0.1, 0.2, 1.0)
	_blue_light.light_energy = 3.0
	_blue_light.omni_range = 15.0
	_blue_light.position = Vector3(0.4, 0.0, 0.0)
	add_child(_blue_light)

	_set_lights(false, false)


func _process(delta: float) -> void:
	if not lights_active:
		# Only call _set_lights when transitioning from active to inactive
		if _lights_were_active:
			_lights_were_active = false
			_set_lights(false, false)
		return
	_lights_were_active = true

	_timer += delta
	if _timer >= FLASH_INTERVAL:
		_timer = 0.0
		_red_on = not _red_on
	_set_lights(_red_on, not _red_on)


func _set_lights(red_on: bool, blue_on: bool) -> void:
	if _red_light:
		_red_light.visible = red_on
	if _blue_light:
		_blue_light.visible = blue_on
