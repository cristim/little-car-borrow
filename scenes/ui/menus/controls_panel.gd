extends PanelContainer
## Scrollable controls panel showing all rebindable actions.
## Click a key label to enter rebind mode, then press a new key.

const SAVE_PATH := "user://keybindings.cfg"

const REBINDABLE_ACTIONS: Array[Dictionary] = [
	{"action": "move_forward", "label": "Move Forward"},
	{"action": "move_backward", "label": "Move Backward"},
	{"action": "move_left", "label": "Move Left"},
	{"action": "move_right", "label": "Move Right"},
	{"action": "sprint", "label": "Sprint"},
	{"action": "handbrake", "label": "Handbrake"},
	{"action": "interact", "label": "Enter / Exit Vehicle"},
	{"action": "shoot", "label": "Shoot"},
	{"action": "aim", "label": "Aim"},
	{"action": "reload", "label": "Reload / Restart"},
	{"action": "horn", "label": "Horn"},
	{"action": "radio_next", "label": "Next Radio"},
	{"action": "pause", "label": "Pause"},
	{"action": "toggle_fullscreen", "label": "Toggle Fullscreen"},
]

var _key_buttons: Dictionary = {}
var _waiting_action := ""

@onready var _vbox: VBoxContainer = $Margin/VBox
@onready var _title: Label = $Margin/VBox/Title
@onready var _scroll: ScrollContainer = $Margin/VBox/Scroll
@onready var _grid: GridContainer = $Margin/VBox/Scroll/Grid
@onready var _back_btn: Button = $Margin/VBox/BackBtn


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_bindings()
	_build_rows()
	_back_btn.pressed.connect(_on_back)


func _build_rows() -> void:
	for child in _grid.get_children():
		child.queue_free()
	_key_buttons.clear()

	for entry in REBINDABLE_ACTIONS:
		var action: String = entry.action
		var display: String = entry.label

		var name_label := Label.new()
		name_label.text = display
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_grid.add_child(name_label)

		var key_btn := Button.new()
		key_btn.text = _get_key_name(action)
		key_btn.custom_minimum_size = Vector2(160, 0)
		key_btn.pressed.connect(_start_rebind.bind(action))
		_grid.add_child(key_btn)
		_key_buttons[action] = key_btn


func _start_rebind(action: String) -> void:
	_waiting_action = action
	(_key_buttons[action] as Button).text = "< Press a key >"


func _unhandled_input(event: InputEvent) -> void:
	if _waiting_action.is_empty():
		return

	if event is InputEventKey and event.pressed:
		_rebind(_waiting_action, event)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		_rebind(_waiting_action, event)
		get_viewport().set_input_as_handled()


func _rebind(action: String, event: InputEvent) -> void:
	# Remove existing keyboard/mouse events, keep gamepad
	var existing := InputMap.action_get_events(action)
	for ev in existing:
		if ev is InputEventKey or ev is InputEventMouseButton:
			InputMap.action_erase_event(action, ev)

	InputMap.action_add_event(action, event)
	(_key_buttons[action] as Button).text = _get_key_name(action)
	_waiting_action = ""
	_save_bindings()


func _get_key_name(action: String) -> String:
	var events := InputMap.action_get_events(action)
	for ev in events:
		if ev is InputEventKey:
			var k := ev as InputEventKey
			var code: Key = k.physical_keycode if k.physical_keycode != 0 else k.keycode
			return OS.get_keycode_string(code)
		if ev is InputEventMouseButton:
			return _mouse_button_name(ev as InputEventMouseButton)
	return "---"


func _mouse_button_name(mb: InputEventMouseButton) -> String:
	var names := {
		MOUSE_BUTTON_LEFT: "Mouse Left",
		MOUSE_BUTTON_RIGHT: "Mouse Right",
		MOUSE_BUTTON_MIDDLE: "Mouse Middle",
		MOUSE_BUTTON_WHEEL_UP: "Scroll Up",
		MOUSE_BUTTON_WHEEL_DOWN: "Scroll Down",
	}
	return names.get(mb.button_index, "Mouse %d" % mb.button_index)


func _save_bindings() -> void:
	var cfg := ConfigFile.new()
	for entry in REBINDABLE_ACTIONS:
		var action: String = entry.action
		var events := InputMap.action_get_events(action)
		for ev in events:
			if ev is InputEventKey:
				var k := ev as InputEventKey
				var code: int = k.physical_keycode if k.physical_keycode != 0 else k.keycode
				cfg.set_value("keys", action, code)
				break
			elif ev is InputEventMouseButton:
				var mb := ev as InputEventMouseButton
				cfg.set_value("mouse", action, mb.button_index)
				break
	cfg.save(SAVE_PATH)


func _load_bindings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return

	for entry in REBINDABLE_ACTIONS:
		var action: String = entry.action
		if cfg.has_section_key("keys", action):
			var code: int = cfg.get_value("keys", action)
			var existing := InputMap.action_get_events(action)
			for ev in existing:
				if ev is InputEventKey or ev is InputEventMouseButton:
					InputMap.action_erase_event(action, ev)
			var new_ev := InputEventKey.new()
			new_ev.physical_keycode = code as Key
			InputMap.action_add_event(action, new_ev)
		elif cfg.has_section_key("mouse", action):
			var btn: int = cfg.get_value("mouse", action)
			var existing := InputMap.action_get_events(action)
			for ev in existing:
				if ev is InputEventKey or ev is InputEventMouseButton:
					InputMap.action_erase_event(action, ev)
			var new_ev := InputEventMouseButton.new()
			new_ev.button_index = btn as MouseButton
			InputMap.action_add_event(action, new_ev)


func _on_back() -> void:
	visible = false
	get_parent().get_node("Panel").visible = true
