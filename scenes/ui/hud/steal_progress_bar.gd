extends ProgressBar
## Steal/hotwire progress bar shown during vehicle entry.


func _ready() -> void:
	visible = false
	min_value = 0.0
	max_value = 1.0
	value = 0.0


func show_progress() -> void:
	value = 0.0
	visible = true


func update_progress(ratio: float) -> void:
	value = ratio


func hide_progress() -> void:
	visible = false
	value = 0.0
