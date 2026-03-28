extends GutTest
## Tests for InteractionPrompt — shows/hides contextual prompts
## via EventBus signals.

const PromptScript = preload("res://scenes/ui/hud/interaction_prompt.gd")


func _build_prompt() -> PanelContainer:
	var prompt: PanelContainer = PromptScript.new()
	var label := Label.new()
	label.name = "Label"
	prompt.add_child(label)
	add_child_autofree(prompt)
	return prompt


# ================================================================
# Initialization
# ================================================================

func test_ready_hides_prompt() -> void:
	var prompt := _build_prompt()
	await get_tree().process_frame

	assert_false(prompt.visible, "Prompt should be hidden on ready")


func test_ready_connects_show_signal() -> void:
	var prompt := _build_prompt()
	await get_tree().process_frame

	assert_true(
		EventBus.show_interaction_prompt.is_connected(prompt._on_show),
		"Should connect to show_interaction_prompt",
	)


func test_ready_connects_hide_signal() -> void:
	var prompt := _build_prompt()
	await get_tree().process_frame

	assert_true(
		EventBus.hide_interaction_prompt.is_connected(prompt._on_hide),
		"Should connect to hide_interaction_prompt",
	)


# ================================================================
# Show prompt
# ================================================================

func test_show_sets_text_and_visibility() -> void:
	var prompt := _build_prompt()
	await get_tree().process_frame

	EventBus.show_interaction_prompt.emit("Hold F to steal")

	assert_true(prompt.visible, "Prompt should be visible after show")
	assert_eq(prompt.label.text, "Hold F to steal", "Label text should match")


func test_show_updates_text_when_already_visible() -> void:
	var prompt := _build_prompt()
	await get_tree().process_frame

	EventBus.show_interaction_prompt.emit("Press E to enter")
	EventBus.show_interaction_prompt.emit("Press E to talk")

	assert_true(prompt.visible, "Should remain visible")
	assert_eq(prompt.label.text, "Press E to talk", "Text should update to latest")


func test_show_with_empty_string() -> void:
	var prompt := _build_prompt()
	await get_tree().process_frame

	EventBus.show_interaction_prompt.emit("")

	assert_true(prompt.visible, "Prompt visible even with empty text (script does not guard)")
	assert_eq(prompt.label.text, "", "Label should be empty string")


# ================================================================
# Hide prompt
# ================================================================

func test_hide_makes_prompt_invisible() -> void:
	var prompt := _build_prompt()
	await get_tree().process_frame

	EventBus.show_interaction_prompt.emit("Test")
	EventBus.hide_interaction_prompt.emit()

	assert_false(prompt.visible, "Prompt should be hidden after hide signal")


func test_hide_when_already_hidden() -> void:
	var prompt := _build_prompt()
	await get_tree().process_frame

	# Already hidden from _ready
	EventBus.hide_interaction_prompt.emit()

	assert_false(prompt.visible, "Should remain hidden when hide called twice")


# ================================================================
# Show then hide cycle
# ================================================================

func test_show_hide_show_cycle() -> void:
	var prompt := _build_prompt()
	await get_tree().process_frame

	EventBus.show_interaction_prompt.emit("First")
	assert_true(prompt.visible, "Visible after first show")

	EventBus.hide_interaction_prompt.emit()
	assert_false(prompt.visible, "Hidden after hide")

	EventBus.show_interaction_prompt.emit("Second")
	assert_true(prompt.visible, "Visible after second show")
	assert_eq(prompt.label.text, "Second", "Text matches second show")
