extends Control
## On-screen touch controls for mobile. Draws joystick, camera zone, and
## action buttons. Injects synthetic input events so all existing controller
## code works unmodified.
##
## Added as child of a dedicated CanvasLayer (layer 20) in main.tscn.
## On non-touch devices, disables itself completely for zero overhead.

# -- Joystick geometry --
const JOY_RADIUS := 80.0
const JOY_THUMB_RADIUS := 30.0
const JOY_DEADZONE := 0.15

# -- Button definitions --
# Each button: {name, color, radius, offset (from bottom-right), context}
const BUTTONS := [
	{
		"name": "shoot",
		"color": Color(0.9, 0.2, 0.2, 0.5),
		"radius": 50.0,
		"offset": Vector2(-120, -200),
		"context": "all",
	},
	{
		"name": "interact",
		"color": Color(0.2, 0.4, 0.9, 0.5),
		"radius": 40.0,
		"offset": Vector2(-200, -320),
		"context": "all",
	},
	{
		"name": "handbrake",
		"color": Color(0.9, 0.8, 0.2, 0.5),
		"radius": 35.0,
		"offset": Vector2(-120, -340),
		"context": "vehicle",
	},
	{
		"name": "toggle_flashlight",
		"color": Color(0.9, 0.9, 0.3, 0.5),
		"radius": 30.0,
		"offset": Vector2(-220, -200),
		"context": "all",
	},
	{
		"name": "map_toggle",
		"color": Color(0.3, 0.7, 0.9, 0.5),
		"radius": 28.0,
		"offset": Vector2(-60, -130),
		"context": "all",
	},
	{
		"name": "pause",
		"color": Color(0.8, 0.8, 0.8, 0.4),
		"radius": 25.0,
		"offset": Vector2(-60, -60),
		"context": "all",
	},
]

# -- Runtime state --
var _joystick_finger := -1
var _joystick_center := Vector2.ZERO
var _joystick_thumb := Vector2.ZERO
var _joystick_direction := Vector2.ZERO

var _camera_finger := -1
var _camera_last_pos := Vector2.ZERO

var _button_fingers: Dictionary = {}  # button name -> finger index

var _viewport_size := Vector2.ZERO
var _joy_center := Vector2.ZERO  # Default joystick center position

# -- Cached button positions (recomputed on resize) --
var _button_positions: Array = []  # Array of {name, center, radius, color, context}
var _last_vehicle_ctx := false
var _last_dead_state := false


func _ready() -> void:
	if not DisplayServer.is_touchscreen_available():
		visible = false
		set_process(false)
		set_process_input(false)
		return

	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchors_preset = Control.PRESET_FULL_RECT
	_update_layout()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_layout()
	elif what == NOTIFICATION_PAUSED:
		_release_all_fingers()


func _update_layout() -> void:
	_viewport_size = get_viewport_rect().size
	_joy_center = Vector2(160.0, _viewport_size.y - 200.0)
	_joystick_thumb = _joy_center

	_button_positions.clear()
	for bdef in BUTTONS:
		var offset: Vector2 = bdef["offset"]
		var center := Vector2(
			_viewport_size.x + offset.x,
			_viewport_size.y + offset.y
		)
		_button_positions.append({
			"name": bdef["name"],
			"center": center,
			"radius": bdef["radius"],
			"color": bdef["color"],
			"context": bdef["context"],
		})
	queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_screen_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_handle_screen_drag(event as InputEventScreenDrag)


# -- Touch start / end --
func _handle_screen_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		_on_touch_start(event.index, event.position)
	else:
		_on_touch_end(event.index)


func _on_touch_start(finger: int, pos: Vector2) -> void:
	# Check restart button when dead (ignore all other touches)
	if GameManager.is_dead:
		var restart_center := _viewport_size * 0.5 + Vector2(0, 80)
		if pos.distance_to(restart_center) <= 55.0:  # 45px drawn radius + 10px grace
			GameManager.restart_game()
		return

	# Check buttons first (highest priority)
	for bdata in _button_positions:
		var bname: String = bdata["name"]
		var bcenter: Vector2 = bdata["center"]
		var bradius: float = bdata["radius"]
		var bctx: String = bdata["context"]

		# Skip context-restricted buttons
		if bctx == "vehicle" and not InputManager.is_vehicle():
			continue

		if pos.distance_to(bcenter) <= bradius + 10.0:  # 10px grace margin
			_button_fingers[bname] = finger
			# Use InputEventAction so both event-based (handle_input) and
			# polled (Input.is_action_pressed) checks work
			var ev := InputEventAction.new()
			ev.action = bname
			ev.pressed = true
			Input.parse_input_event(ev)
			queue_redraw()
			return

	# Check joystick zone (left half, below top 20%)
	if pos.x < _viewport_size.x * 0.5 and pos.y > _viewport_size.y * 0.2:
		if _joystick_finger == -1:
			_joystick_finger = finger
			_joystick_center = pos  # Floating joystick: center where you touch
			_joystick_thumb = pos
			_joystick_direction = Vector2.ZERO
			queue_redraw()
			return

	# Otherwise: camera control (right side or unassigned)
	if _camera_finger == -1:
		_camera_finger = finger
		_camera_last_pos = pos


func _on_touch_end(finger: int) -> void:
	if finger == _joystick_finger:
		_joystick_finger = -1
		_joystick_direction = Vector2.ZERO
		_joystick_thumb = _joy_center
		_inject_joystick(Vector2.ZERO)
		queue_redraw()
		return

	if finger == _camera_finger:
		_camera_finger = -1
		return

	# Check button releases
	for bname in _button_fingers:
		if _button_fingers[bname] == finger:
			var ev := InputEventAction.new()
			ev.action = bname
			ev.pressed = false
			Input.parse_input_event(ev)
			_button_fingers.erase(bname)
			queue_redraw()
			return


# -- Touch drag --
func _handle_screen_drag(event: InputEventScreenDrag) -> void:
	var finger := event.index
	var pos := event.position

	if finger == _joystick_finger:
		var offset := pos - _joystick_center
		if offset.length() > JOY_RADIUS:
			offset = offset.normalized() * JOY_RADIUS
		_joystick_thumb = _joystick_center + offset

		# Compute normalized direction (-1 to 1 on each axis)
		var raw := offset / JOY_RADIUS
		if raw.length() < JOY_DEADZONE:
			_joystick_direction = Vector2.ZERO
		else:
			_joystick_direction = raw
		_inject_joystick(_joystick_direction)
		queue_redraw()
		return

	if finger == _camera_finger:
		_inject_camera_motion(event.relative)
		_camera_last_pos = pos
		return


# -- Synthetic input injection --
func _inject_joystick(direction: Vector2) -> void:
	# Left stick X axis (axis 0): move_left / move_right
	var ev_x := InputEventJoypadMotion.new()
	ev_x.axis = JOY_AXIS_LEFT_X
	ev_x.axis_value = direction.x
	Input.parse_input_event(ev_x)

	# Left stick Y axis (axis 1): move_forward (negative) / move_backward (positive)
	var ev_y := InputEventJoypadMotion.new()
	ev_y.axis = JOY_AXIS_LEFT_Y
	ev_y.axis_value = direction.y
	Input.parse_input_event(ev_y)

	# Auto-sprint when joystick pushed beyond 80%
	var magnitude := direction.length()
	var is_sprinting := Input.is_action_pressed("sprint")
	if magnitude > 0.8 and not is_sprinting:
		var ev := InputEventAction.new()
		ev.action = "sprint"
		ev.pressed = true
		Input.parse_input_event(ev)
	elif magnitude <= 0.8 and is_sprinting:
		var ev := InputEventAction.new()
		ev.action = "sprint"
		ev.pressed = false
		Input.parse_input_event(ev)


func _inject_camera_motion(relative: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.relative = relative
	Input.parse_input_event(ev)


# -- Release all fingers (called on pause) --
func _release_all_fingers() -> void:
	if _joystick_finger != -1:
		_joystick_finger = -1
		_joystick_direction = Vector2.ZERO
		_inject_joystick(Vector2.ZERO)  # Also releases sprint if active
	_camera_finger = -1
	for bname in _button_fingers:
		var ev := InputEventAction.new()
		ev.action = bname
		ev.pressed = false
		Input.parse_input_event(ev)
	_button_fingers.clear()
	queue_redraw()


# -- Drawing --
func _draw() -> void:
	_draw_joystick()
	_draw_buttons()
	_draw_restart_button()


func _draw_joystick() -> void:
	var is_active := _joystick_finger != -1
	var center := _joystick_center if is_active else _joy_center
	var thumb := _joystick_thumb if is_active else _joy_center
	var alpha := 0.7 if is_active else 0.4

	# Outer circle
	draw_arc(
		center, JOY_RADIUS, 0.0, TAU, 48,
		Color(1.0, 1.0, 1.0, alpha * 0.5), 2.0
	)
	# Fill
	draw_circle(center, JOY_RADIUS, Color(0.1, 0.1, 0.1, alpha * 0.3))
	# Thumb
	draw_circle(thumb, JOY_THUMB_RADIUS, Color(0.8, 0.8, 0.8, alpha))


func _draw_buttons() -> void:
	for bdata in _button_positions:
		var bname: String = bdata["name"]
		var center: Vector2 = bdata["center"]
		var radius: float = bdata["radius"]
		var color: Color = bdata["color"]
		var ctx: String = bdata["context"]

		# Skip vehicle-only buttons when on foot
		if ctx == "vehicle" and not InputManager.is_vehicle():
			continue

		var is_pressed: bool = _button_fingers.has(bname)
		var alpha := 0.7 if is_pressed else 0.4

		# Button fill
		var fill_color := Color(color.r, color.g, color.b, alpha * 0.6)
		draw_circle(center, radius, fill_color)

		# Button outline
		var outline_color := Color(1.0, 1.0, 1.0, alpha)
		draw_arc(center, radius, 0.0, TAU, 32, outline_color, 2.0)

		# Label
		var label := bname.capitalize().substr(0, 1)
		if bname == "handbrake":
			label = "HB"
		elif bname == "pause":
			label = "||"
		elif bname == "interact":
			label = "F"
		elif bname == "toggle_flashlight":
			label = "L"
		elif bname == "map_toggle":
			label = "M"
		draw_string(
			ThemeDB.fallback_font,
			center + Vector2(-6, 6),
			label,
			HORIZONTAL_ALIGNMENT_CENTER,
			-1, 16,
			Color(1.0, 1.0, 1.0, alpha),
		)


func _draw_restart_button() -> void:
	if not GameManager.is_dead:
		return
	var center := _viewport_size * 0.5 + Vector2(0, 80)
	var radius := 45.0
	draw_circle(center, radius, Color(0.2, 0.7, 0.2, 0.6))
	draw_arc(center, radius, 0.0, TAU, 32, Color(1, 1, 1, 0.7), 2.0)
	draw_string(
		ThemeDB.fallback_font,
		center + Vector2(-30, 6),
		"RESTART",
		HORIZONTAL_ALIGNMENT_CENTER,
		-1, 14,
		Color(1.0, 1.0, 1.0, 0.9),
	)


# -- Context change listener --
func _process(_delta: float) -> void:
	# Redraw only when context or death state changes
	var is_vehicle := InputManager.is_vehicle()
	var is_dead: bool = GameManager.is_dead
	if is_vehicle != _last_vehicle_ctx or is_dead != _last_dead_state:
		_last_vehicle_ctx = is_vehicle
		_last_dead_state = is_dead
		queue_redraw()
