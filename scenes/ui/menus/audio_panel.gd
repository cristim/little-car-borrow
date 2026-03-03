extends PanelContainer
## Audio settings panel with volume sliders for each bus.
## Changes are applied immediately and persisted via SettingsManager.

const BUSES: Array[Dictionary] = [
	{"bus": "Master", "label": "Master Volume"},
	{"bus": "SFX", "label": "Sound Effects"},
	{"bus": "Music", "label": "Music"},
	{"bus": "Ambient", "label": "Ambient"},
]

var _sliders: Dictionary = {}

@onready var _grid: GridContainer = $Margin/VBox/Grid
@onready var _back_btn: Button = $Margin/VBox/BackBtn


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_rows()
	_back_btn.pressed.connect(_on_back)


func _build_rows() -> void:
	for entry in BUSES:
		var bus_name: String = entry.bus
		var display: String = entry.label

		var lbl := Label.new()
		lbl.text = display
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_grid.add_child(lbl)

		var hbox := HBoxContainer.new()
		hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.05
		slider.value = AudioManager.get_bus_volume(bus_name)
		slider.custom_minimum_size = Vector2(160, 0)
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.value_changed.connect(_on_volume_changed.bind(bus_name))
		hbox.add_child(slider)

		var val_label := Label.new()
		val_label.text = "%d%%" % roundi(slider.value * 100.0)
		val_label.custom_minimum_size = Vector2(45, 0)
		val_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		hbox.add_child(val_label)

		_grid.add_child(hbox)
		_sliders[bus_name] = {"slider": slider, "label": val_label}


func _on_volume_changed(value: float, bus_name: String) -> void:
	AudioManager.set_bus_volume(bus_name, value)
	var data: Dictionary = _sliders[bus_name]
	(data.label as Label).text = "%d%%" % roundi(value * 100.0)
	SettingsManager.save()


func _on_back() -> void:
	visible = false
	get_parent().get_node("Panel").visible = true


func refresh_sliders() -> void:
	for entry in BUSES:
		var bus_name: String = entry.bus
		if _sliders.has(bus_name):
			var data: Dictionary = _sliders[bus_name]
			var vol := AudioManager.get_bus_volume(bus_name)
			(data.slider as HSlider).value = vol
			(data.label as Label).text = "%d%%" % roundi(vol * 100.0)
