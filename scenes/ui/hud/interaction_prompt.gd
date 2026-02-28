extends PanelContainer
## Shows contextual interaction prompts (e.g., "Hold F to steal").

@onready var label: Label = $Label


func _ready() -> void:
	visible = false
	EventBus.show_interaction_prompt.connect(_on_show)
	EventBus.hide_interaction_prompt.connect(_on_hide)


func _on_show(text: String) -> void:
	label.text = text
	visible = true


func _on_hide() -> void:
	visible = false
