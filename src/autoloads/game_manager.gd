extends Node
## Manages global game state: money, health, save/load, pause.

const MAX_HEALTH := 100.0

var money: int = 0
var is_paused: bool = false
var health: float = MAX_HEALTH
var is_dead: bool = false


func add_money(amount: int) -> void:
	money += amount
	EventBus.player_money_changed.emit(money)


func deduct_money(amount: int) -> bool:
	if money < amount:
		return false
	money -= amount
	EventBus.player_money_changed.emit(money)
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
	money = 0
	WantedLevelManager.clear()
	get_tree().reload_current_scene()


func toggle_pause() -> void:
	is_paused = !is_paused
	get_tree().paused = is_paused
