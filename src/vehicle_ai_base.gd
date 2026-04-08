extends Node
## Shared base for NPC and police vehicle AI controllers.
## Provides the Direction enum, shared tuning constants, shared instance
## variables, and all road-following / geometry helper methods.

enum Direction { NORTH, SOUTH, EAST, WEST }

# Driving tuning
const ARRIVAL_DIST := 6.0
const LANE_STEER_GAIN := 0.6
const LANE_STEER_MAX := 0.5
const HEADING_STEER_GAIN := 2.0
const OFF_ROAD_THRESHOLD := 5.0
const OFF_ROAD_LANE_GAIN := 2.0
const OFF_ROAD_LANE_MAX := 0.9

# Collision avoidance
const RAY_LENGTH := 25.0
const SIDE_RAY_LENGTH := 15.0
const SIDE_RAY_ANGLE := 20.0
const HARD_BRAKE_DIST := 3.0
const SOFT_BRAKE_DIST := 12.0
const RAY_INTERVAL_NEAR := 3
const RAY_INTERVAL_MID := 8
const RAY_INTERVAL_FAR := 15
const LOD_MID_DIST := 60.0
const LOD_FAR_DIST := 100.0
const LOD_FREEZE_DIST := 140.0
const STEER_AVOID_GAIN := 0.6
const CROSS_RAY_LENGTH := 10.0

# Stuck detection
const STUCK_TIMEOUT := 0.8
const STUCK_SPEED := 2.0
const MAX_ESCAPE_ATTEMPTS := 3

var active := true
var _grid = preload("res://src/road_grid.gd").new()
var _vehicle: RigidBody3D = null
var _road_index := 0
var _direction: int = Direction.NORTH
var _next_intersection := 0.0
var _rng := RandomNumberGenerator.new()

# Collision avoidance state
var _ray_cooldown := 0
var _dist_to_ahead := -1.0
var _hitting_wall := false
var _steer_avoidance := 0.0
var _cross_traffic := false
var _yield_timer := 0.0

# Stuck / escape state
var _stuck_timer := 0.0
var _escape_timer := 0.0
var _escape_attempts := 0

# Spawn grace — suppress stuck detection for newly spawned vehicles
var _spawn_grace := 0.0


func _dir_to_heading(d: int) -> Vector3:
	match d:
		Direction.NORTH:
			return Vector3(0, 0, -1)
		Direction.SOUTH:
			return Vector3(0, 0, 1)
		Direction.EAST:
			return Vector3(1, 0, 0)
		Direction.WEST:
			return Vector3(-1, 0, 0)
	return Vector3(0, 0, -1)


func _get_vehicle_forward() -> Vector3:
	var forward := -_vehicle.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.001:
		return _dir_to_heading(_direction)
	return forward.normalized()


func _get_lane_error() -> float:
	var pos := _vehicle.global_position
	var is_ns := _direction == Direction.NORTH or _direction == Direction.SOUTH
	var road_axis := pos.x if is_ns else pos.z
	var road_center := _grid.get_road_center_near(_road_index, road_axis)
	var rw := _grid.get_road_width(_road_index)
	var lane_offset := rw / 4.0

	match _direction:
		Direction.NORTH:
			return pos.x - (road_center + lane_offset)
		Direction.SOUTH:
			return pos.x - (road_center - lane_offset)
		Direction.EAST:
			return pos.z - (road_center + lane_offset)
		Direction.WEST:
			return pos.z - (road_center - lane_offset)
	return 0.0


func _past_intersection() -> bool:
	var pos := _vehicle.global_position
	match _direction:
		Direction.NORTH:
			return pos.z <= _next_intersection + ARRIVAL_DIST
		Direction.SOUTH:
			return pos.z >= _next_intersection - ARRIVAL_DIST
		Direction.EAST:
			return pos.x >= _next_intersection - ARRIVAL_DIST
		Direction.WEST:
			return pos.x <= _next_intersection + ARRIVAL_DIST
	return false


func _find_next_intersection() -> void:
	var pos := _vehicle.global_position if _vehicle else Vector3.ZERO
	match _direction:
		Direction.NORTH:
			_next_intersection = _find_next_road_coord(pos.z, -1)
		Direction.SOUTH:
			_next_intersection = _find_next_road_coord(pos.z, 1)
		Direction.EAST:
			_next_intersection = _find_next_road_coord(pos.x, 1)
		Direction.WEST:
			_next_intersection = _find_next_road_coord(pos.x, -1)


func _find_next_road_coord(current: float, sign_dir: int) -> float:
	var min_ahead := 15.0
	var threshold := current + sign_dir * min_ahead
	var best := current + sign_dir * 1000.0
	for i in range(_grid.GRID_SIZE + 1):
		var c := _grid.get_road_center_near(i, current)
		if sign_dir > 0:
			if c > threshold and c < best:
				best = c
		else:
			if c < threshold and c > best:
				best = c
	return best


func _pick_best_direction() -> int:
	var forward := _get_vehicle_forward()
	var best_dir := _direction
	var best_dot := -2.0
	for d in [Direction.NORTH, Direction.SOUTH, Direction.EAST, Direction.WEST]:
		var heading := _dir_to_heading(d)
		var dot := forward.dot(heading)
		if dot > best_dot:
			best_dot = dot
			best_dir = d
	return best_dir


func _get_reverse(dir: int) -> int:
	match dir:
		Direction.NORTH:
			return Direction.SOUTH
		Direction.SOUTH:
			return Direction.NORTH
		Direction.EAST:
			return Direction.WEST
		Direction.WEST:
			return Direction.EAST
	return Direction.NORTH


func _find_nearest_road_index() -> int:
	var pos := _vehicle.global_position
	var was_ns := _direction == Direction.NORTH or _direction == Direction.SOUTH
	var coord := pos.z if was_ns else pos.x
	return _grid.get_nearest_road_index(coord)


func _get_ray_interval() -> int:
	var cam := get_viewport().get_camera_3d()
	if not cam:
		return RAY_INTERVAL_NEAR
	var d := _vehicle.global_position.distance_to(cam.global_position)
	if d > LOD_FAR_DIST:
		return RAY_INTERVAL_FAR
	if d > LOD_MID_DIST:
		return RAY_INTERVAL_MID
	return RAY_INTERVAL_NEAR


func deactivate() -> void:
	active = false
	if _vehicle:
		_vehicle.steering_input = 0.0
		_vehicle.throttle_input = 0.0
		_vehicle.brake_input = 1.0
		_vehicle.handbrake_input = 1.0
