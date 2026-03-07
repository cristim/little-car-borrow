extends CharacterBody3D
## Pedestrian NPC with Walk/Idle/Flee states and vehicle proximity detection.

const FLEE_VEHICLE_SPEED := 5.0


func _ready() -> void:
	add_to_group("pedestrian")
	var area := get_node_or_null("ProximityArea") as Area3D
	if area:
		area.body_entered.connect(_on_proximity_body_entered)


func _on_proximity_body_entered(body: Node) -> void:
	if not body is RigidBody3D:
		return

	var speed_kmh: float = (body as RigidBody3D).linear_velocity.length() * 3.6
	if speed_kmh < FLEE_VEHICLE_SPEED:
		return

	var sm := get_node_or_null("StateMachine")
	if sm and sm.current_state:
		var current_name: String = sm.current_state.name.to_lower()
		if current_name != "pedestrianflee":
			sm.transition_to(
				"PedestrianFlee",
				{"threat_pos": (body as Node3D).global_position},
			)
