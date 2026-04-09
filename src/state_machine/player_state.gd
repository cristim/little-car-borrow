extends "res://src/state_machine/state.gd"
## Shared base for player foot-movement states.
## Provides SEA_LEVEL, camera-relative direction, ground height,
## water detection, and the land-vehicle interaction prompt.

const SEA_LEVEL: float = GameManager.SEA_LEVEL


func _get_camera_relative_direction(input: Vector2) -> Vector3:
	var cam_yaw: float = owner.player_camera.get_yaw()
	var forward := Vector3(-sin(cam_yaw), 0, -cos(cam_yaw))
	var right := Vector3(-forward.z, 0, forward.x)
	var direction := (forward * -input.y + right * input.x).normalized()
	return direction


func _get_ground_height(pos: Vector3) -> float:
	var city_nodes := owner.get_tree().get_nodes_in_group("city_manager")
	if city_nodes.is_empty():
		return 0.0
	var boundary: RefCounted = city_nodes[0].get_meta("city_boundary")
	if not boundary:
		return 0.0
	return boundary.get_ground_height(pos.x, pos.z)


func _is_over_water(pos: Vector3) -> bool:
	return _get_ground_height(pos) < SEA_LEVEL


func _update_prompt() -> void:
	if owner.nearest_vehicle and is_instance_valid(owner.nearest_vehicle):
		var is_boat: bool = owner.nearest_vehicle.get_node_or_null("BoatController") != null
		var prompt := "Hold F to board" if is_boat else "Hold F to steal"
		EventBus.show_interaction_prompt.emit(prompt)
