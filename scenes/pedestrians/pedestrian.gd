extends CharacterBody3D
## Pedestrian NPC with Walk/Idle/Flee states and vehicle proximity detection.
## Flees from fast vehicles (ProximityArea) and from gunshots within hearing range.

const FLEE_VEHICLE_SPEED := 5.0
const LOD_MID_DIST := 40.0
const LOD_FAR_DIST := 70.0
const GUNSHOT_HEAR_RADIUS := 100.0

var _frame_counter := 0


func _ready() -> void:
	add_to_group("pedestrian")
	var area := get_node_or_null("ProximityArea") as Area3D
	if area:
		area.body_entered.connect(_on_proximity_body_entered)
	EventBus.gunshot_fired.connect(_on_gunshot_fired)


func _exit_tree() -> void:
	if EventBus.gunshot_fired.is_connected(_on_gunshot_fired):
		EventBus.gunshot_fired.disconnect(_on_gunshot_fired)


func _physics_process(delta: float) -> void:
	_frame_counter += 1

	# Distance-based throttling of state machine updates
	var skip := false
	var cam := get_viewport().get_camera_3d()
	if cam:
		var d := global_position.distance_to(cam.global_position)
		if d > LOD_FAR_DIST:
			skip = _frame_counter % 4 != 0
		elif d > LOD_MID_DIST:
			skip = _frame_counter % 2 != 0

	var sm := get_node_or_null("StateMachine")
	if skip:
		# Disable state machine tick this frame; just apply gravity
		if sm:
			sm.set_physics_process(false)
		velocity.y -= 9.8 * delta
	else:
		if sm:
			sm.set_physics_process(true)


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
			(
				sm
				. transition_to(
					"PedestrianFlee",
					{"threat_pos": (body as Node3D).global_position},
				)
			)


func _on_gunshot_fired(shot_pos: Vector3) -> void:
	if global_position.distance_to(shot_pos) > GUNSHOT_HEAR_RADIUS:
		return
	var sm := get_node_or_null("StateMachine")
	if sm and sm.current_state:
		var current_name: String = sm.current_state.name.to_lower()
		if current_name != "pedestrianflee":
			sm.transition_to("PedestrianFlee", {"threat_pos": shot_pos})
