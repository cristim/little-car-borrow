extends CanvasLayer
## Displays mission objective text and countdown timer.
## Hidden when no mission is active.

var _reward_timer := 0.0

@onready var objective_label: Label = $ObjectiveLabel
@onready var timer_label: Label = $TimerLabel
@onready var reward_label: Label = $RewardLabel


func _ready() -> void:
	EventBus.mission_objective_updated.connect(
		_on_objective_updated
	)
	EventBus.mission_timer_updated.connect(
		_on_timer_updated
	)
	EventBus.mission_completed.connect(_on_completed)
	EventBus.mission_failed.connect(_on_failed)
	_hide_all()


func _process(delta: float) -> void:
	if _reward_timer > 0.0:
		_reward_timer -= delta
		if _reward_timer <= 0.0:
			reward_label.visible = false


func _on_objective_updated(text: String) -> void:
	if text.is_empty():
		objective_label.visible = false
		timer_label.visible = false
	else:
		objective_label.text = text
		objective_label.visible = true


func _on_timer_updated(time_remaining: float) -> void:
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


func _on_completed(_mission_id: String) -> void:
	var mission := MissionManager.get_active_mission()
	var reward: int = mission.get("reward", 0)
	if reward > 0:
		reward_label.text = "+$%d" % reward
		reward_label.visible = true
		_reward_timer = 3.0
	_hide_mission()


func _on_failed(_mission_id: String) -> void:
	reward_label.text = "MISSION FAILED"
	reward_label.add_theme_color_override(
		"font_color", Color(1.0, 0.3, 0.3)
	)
	reward_label.visible = true
	_reward_timer = 3.0
	_hide_mission()


func _hide_all() -> void:
	objective_label.visible = false
	timer_label.visible = false
	reward_label.visible = false


func _hide_mission() -> void:
	objective_label.visible = false
	timer_label.visible = false
