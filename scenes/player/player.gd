extends CharacterBody3D
## Player character controller. Owns state machine, interaction detection, and camera.

@export var walk_speed := 4.0
@export var run_speed := 8.0
@export var gravity := 20.0
@export var rotation_speed := 10.0

var nearest_vehicle: Node = null
var current_vehicle: Node = null
var is_swimming := false

@onready var player_camera: Node3D = $PlayerCamera


func _physics_process(_delta: float) -> void:
	if InputManager.is_foot():
		rotation.y = player_camera.get_yaw() + PI


func _ready() -> void:
	add_to_group("player")
	InputManager.set_context(InputManager.Context.FOOT)
	player_camera.make_active()
	$InteractionArea.area_entered.connect(_on_interaction_area_entered)
	$InteractionArea.area_exited.connect(_on_interaction_area_exited)


func _on_interaction_area_entered(area: Area3D) -> void:
	if area.is_in_group("vehicle_interaction"):
		nearest_vehicle = area.get_parent()
		var sm := $StateMachine
		var foot_states := ["idle", "walking", "running"]
		if sm.current_state and sm.current_state.name.to_lower() in foot_states:
			EventBus.show_interaction_prompt.emit("Hold F to steal")


func _on_interaction_area_exited(area: Area3D) -> void:
	if area.is_in_group("vehicle_interaction"):
		if nearest_vehicle == area.get_parent():
			nearest_vehicle = null
			EventBus.hide_interaction_prompt.emit()
