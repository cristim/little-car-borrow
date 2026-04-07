extends CharacterBody3D
## Player character controller. Owns state machine, interaction detection, and camera.

const FALL_DAMAGE_MIN_HEIGHT := 3.0   # metres — falls shorter than this deal no damage
const FALL_DAMAGE_PER_METER := 10.0   # HP per metre beyond the safe threshold

@export var walk_speed := 4.0
@export var run_speed := 8.0
@export var gravity := 9.8
@export var jump_speed := 4.9
@export var rotation_speed := 10.0

var nearest_vehicle: Node = null
var current_vehicle: Node = null
var is_swimming := false

var _was_on_floor := true
var _fall_peak_y := 0.0

@onready var player_camera: Node3D = $PlayerCamera


func _physics_process(_delta: float) -> void:
	if InputManager.is_foot():
		rotation.y = player_camera.get_yaw() + PI

	# Fall-damage detection (runs every foot-physics frame).
	# is_on_floor() reflects the result of move_and_slide() from the previous
	# frame, so detection is one frame behind landing — imperceptible in play.
	var on_floor := is_on_floor()
	if not _was_on_floor and on_floor:
		var fall_dist: float = _fall_peak_y - global_position.y
		if fall_dist > FALL_DAMAGE_MIN_HEIGHT:
			var dmg: float = (
				(fall_dist - FALL_DAMAGE_MIN_HEIGHT) * FALL_DAMAGE_PER_METER
			)
			GameManager.take_damage(dmg)
	if not on_floor:
		if _was_on_floor:
			_fall_peak_y = global_position.y
		elif global_position.y > _fall_peak_y:
			_fall_peak_y = global_position.y
	_was_on_floor = on_floor


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
		var foot_states := ["idle", "walking", "running", "swimming"]
		if sm.current_state and sm.current_state.name.to_lower() in foot_states:
			var is_boat: bool = nearest_vehicle.get_node_or_null(
				"BoatController"
			) != null
			var is_heli: bool = nearest_vehicle.get_node_or_null(
				"HelicopterController"
			) != null
			var prompt := (
				"Hold F to board" if (is_boat or is_heli) else "Hold F to steal"
			)
			EventBus.show_interaction_prompt.emit(prompt)


func _on_interaction_area_exited(area: Area3D) -> void:
	if area.is_in_group("vehicle_interaction"):
		if nearest_vehicle == area.get_parent():
			nearest_vehicle = null
			EventBus.hide_interaction_prompt.emit()
