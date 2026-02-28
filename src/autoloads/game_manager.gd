extends Node
## Manages global game state: money, save/load, pause.

var money: int = 0
var is_paused: bool = false


func add_money(amount: int) -> void:
	money += amount
	EventBus.player_money_changed.emit(money)


func deduct_money(amount: int) -> bool:
	if money < amount:
		return false
	money -= amount
	EventBus.player_money_changed.emit(money)
	return true


func toggle_pause() -> void:
	is_paused = !is_paused
	get_tree().paused = is_paused
