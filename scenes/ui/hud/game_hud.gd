extends CanvasLayer
## Consolidated HUD combining minimap, money, wanted stars, speed,
## FPS, and mission objective/timer into one CanvasLayer.

const MAX_STARS := 5
const FLASH_SPEED := 4.0

var _speed_kmh := 0.0
var _wanted_level := 0
var _flash_timer := 0.0
var _reward_timer := 0.0

@onready var minimap: Control = $TopRight/MinimapControl
@onready var money_label: Label = $TopRight/MoneyLabel
@onready var speed_label: Label = $BottomCenter/SpeedLabel
@onready var fps_label: Label = $TopRightCorner/FPSLabel
@onready var objective_label: Label = $TopLeft/ObjectiveLabel
@onready var timer_label: Label = $TopLeft/TimerLabel
@onready var reward_label: Label = $CenterTop/RewardLabel
@onready var stars_hbox: HBoxContainer = $TopRight/StarsHBox
@onready var health_bar: ColorRect = $BottomLeft/HealthBg/HealthBar
@onready var death_label: Label = $DeathLabel
@onready var restart_prompt: Label = $RestartPrompt
@onready var crosshair: Label = $Crosshair


func _ready() -> void:
	EventBus.vehicle_speed_changed.connect(_on_speed)
	EventBus.wanted_level_changed.connect(_on_wanted)
	EventBus.player_money_changed.connect(_on_money)
	EventBus.mission_objective_updated.connect(_on_objective)
	EventBus.mission_timer_updated.connect(_on_timer)
	EventBus.mission_completed.connect(_on_mission_completed)
	EventBus.mission_failed.connect(_on_mission_failed)
	EventBus.player_health_changed.connect(_on_health)
	EventBus.player_died.connect(_on_died)
	EventBus.vehicle_entered.connect(_on_vehicle_entered)
	EventBus.vehicle_exited.connect(_on_vehicle_exited)

	money_label.text = "$%d" % GameManager.money
	objective_label.visible = false
	timer_label.visible = false
	reward_label.visible = false
	death_label.visible = false
	restart_prompt.visible = false
	_update_stars()


func _process(delta: float) -> void:
	fps_label.text = "FPS: %d" % Engine.get_frames_per_second()
	speed_label.text = "%d km/h" % roundi(_speed_kmh)

	if _wanted_level > 0:
		_flash_timer += delta * FLASH_SPEED
		var alpha := 0.6 + 0.4 * absf(sin(_flash_timer))
		for i in range(_wanted_level):
			var star := stars_hbox.get_child(i) as ColorRect
			star.modulate.a = alpha

	if _reward_timer > 0.0:
		_reward_timer -= delta
		if _reward_timer <= 0.0:
			reward_label.visible = false


func _on_speed(speed: float) -> void:
	_speed_kmh = speed


func _on_wanted(level: int) -> void:
	_wanted_level = level
	_flash_timer = 0.0
	_update_stars()


func _on_money(amount: int) -> void:
	money_label.text = "$%d" % amount


func _on_objective(text: String) -> void:
	if text.is_empty():
		objective_label.visible = false
		timer_label.visible = false
	else:
		objective_label.text = text
		objective_label.visible = true


func _on_timer(time_remaining: float) -> void:
	if time_remaining <= 0.0:
		timer_label.visible = false
		return
	timer_label.visible = true
	var mins := int(time_remaining) / 60
	var secs := int(time_remaining) % 60
	timer_label.text = "%d:%02d" % [mins, secs]
	if time_remaining < 15.0:
		timer_label.add_theme_color_override(
			"font_color", Color(1.0, 0.3, 0.3)
		)
	else:
		timer_label.add_theme_color_override(
			"font_color", Color(1.0, 1.0, 1.0)
		)


func _on_mission_completed(_mission_id: String) -> void:
	var mission := MissionManager.get_active_mission()
	var reward: int = mission.get("reward", 0)
	reward_label.text = "+$%d" % reward
	reward_label.remove_theme_color_override("font_color")
	reward_label.visible = true
	_reward_timer = 3.0
	objective_label.visible = false
	timer_label.visible = false


func _on_mission_failed(_mission_id: String) -> void:
	reward_label.text = "MISSION FAILED"
	reward_label.add_theme_color_override(
		"font_color", Color(1.0, 0.3, 0.3)
	)
	reward_label.visible = true
	_reward_timer = 3.0
	objective_label.visible = false
	timer_label.visible = false


func _on_health(current: float, max_hp: float) -> void:
	var ratio := current / max_hp if max_hp > 0.0 else 0.0
	health_bar.size.x = 200.0 * ratio
	if ratio < 0.3:
		health_bar.color = Color(0.9, 0.1, 0.1, 0.9)
	elif ratio < 0.6:
		health_bar.color = Color(0.9, 0.6, 0.1, 0.9)
	else:
		health_bar.color = Color(0.2, 0.8, 0.2, 0.9)


func _on_vehicle_entered(_vehicle: Node) -> void:
	crosshair.visible = false


func _on_vehicle_exited(_vehicle: Node) -> void:
	crosshair.visible = true
	_speed_kmh = 0.0


func _on_died() -> void:
	death_label.visible = true
	death_label.add_theme_color_override(
		"font_color", Color(0.8, 0.1, 0.1)
	)
	# Show restart prompt after a short delay
	get_tree().create_timer(2.0).timeout.connect(_show_restart_prompt)


func _show_restart_prompt() -> void:
	if GameManager.is_dead:
		restart_prompt.visible = true


func _unhandled_input(event: InputEvent) -> void:
	if GameManager.is_dead and event.is_action_pressed("reload"):
		GameManager.restart_game()


func _update_stars() -> void:
	for i in range(MAX_STARS):
		var star := stars_hbox.get_child(i) as ColorRect
		if i < _wanted_level:
			star.color = Color(1.0, 0.85, 0.0)
			star.modulate.a = 1.0
		else:
			star.color = Color(0.3, 0.3, 0.3)
			star.modulate.a = 0.4
