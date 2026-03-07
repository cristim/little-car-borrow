extends Node
## Manages global game state: money, health, save/load, pause.

const MAX_HEALTH := 100.0
const SAVE_PATH := "user://savegame.cfg"
const SECTION := "progress"

var money: int = 0
var missions_completed: int = 0
var total_earnings: int = 0
var health: float = MAX_HEALTH
var is_dead: bool = false


func _ready() -> void:
	load_progress()
	EventBus.mission_completed.connect(_on_mission_completed)


func add_money(amount: int) -> void:
	money += amount
	if amount > 0:
		total_earnings += amount
	EventBus.player_money_changed.emit(money)
	save_progress()


func deduct_money(amount: int) -> bool:
	if money < amount:
		return false
	money -= amount
	EventBus.player_money_changed.emit(money)
	save_progress()
	return true


func take_damage(amount: float) -> void:
	if is_dead:
		return
	health = maxf(health - amount, 0.0)
	EventBus.player_health_changed.emit(health, MAX_HEALTH)
	if health <= 0.0:
		_die()


func heal(amount: float) -> void:
	if is_dead:
		return
	health = minf(health + amount, MAX_HEALTH)
	EventBus.player_health_changed.emit(health, MAX_HEALTH)


func _die() -> void:
	is_dead = true
	EventBus.player_died.emit()


func restart_game() -> void:
	is_dead = false
	health = MAX_HEALTH
	WantedLevelManager.clear()
	MissionManager.fail_mission("restart")
	get_tree().reload_current_scene()


func save_progress() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value(SECTION, "money", money)
	cfg.set_value(SECTION, "missions_completed", missions_completed)
	cfg.set_value(SECTION, "total_earnings", total_earnings)
	cfg.save(SAVE_PATH)


func load_progress() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	money = cfg.get_value(SECTION, "money", 0)
	missions_completed = cfg.get_value(SECTION, "missions_completed", 0)
	total_earnings = cfg.get_value(SECTION, "total_earnings", 0)
	EventBus.player_money_changed.emit(money)


func _on_mission_completed(_mission_id: String) -> void:
	missions_completed += 1
	save_progress()
