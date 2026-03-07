extends Node3D
## A glowing column that triggers mission events on player contact.
## Set mission_id, marker_type, and marker_color after instantiation.

var mission_id: String = ""
var marker_type: String = "start"  # start, pickup, dropoff

var _pulse_time := 0.0

@onready var column: MeshInstance3D = $Column
@onready var trigger: Area3D = $Trigger


func _ready() -> void:
	add_to_group("mission_marker")
	trigger.body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_pulse_time += delta * 3.0
	var pulse := 1.0 + 0.1 * sin(_pulse_time)
	column.scale.x = pulse
	column.scale.z = pulse


func set_marker_color(color: Color) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.8
	column.material_override = mat

	var light := get_node_or_null("Light") as OmniLight3D
	if light:
		light.light_color = color


func _on_body_entered(body: Node3D) -> void:
	var is_player := body.is_in_group("player")
	var is_player_vehicle: bool = (body.collision_layer & 8) != 0
	if is_player or is_player_vehicle:
		EventBus.mission_marker_reached.emit(
			mission_id, marker_type
		)
