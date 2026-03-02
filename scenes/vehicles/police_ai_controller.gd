extends Node
## Police AI that patrols roads and pursues the player when wanted.
## Inherits road-following logic pattern from npc_vehicle_controller.

enum Direction { NORTH, SOUTH, EAST, WEST }
enum AIState { PATROL, PURSUE }

# Driving tuning
const PATROL_SPEED := 40.0
const PURSUIT_SPEED := 52.0
const ARRIVAL_DIST := 6.0
const LANE_STEER_GAIN := 0.6
const LANE_STEER_MAX := 0.5
const HEADING_STEER_GAIN := 2.0
const OFF_ROAD_THRESHOLD := 5.0
const OFF_ROAD_LANE_GAIN := 2.0
const OFF_ROAD_LANE_MAX := 0.9
const PIT_DISTANCE := 15.0
const PIT_STEER_GAIN := 1.5

# Collision avoidance
const RAY_LENGTH := 25.0
const SIDE_RAY_LENGTH := 15.0
const SIDE_RAY_ANGLE := 20.0
const HARD_BRAKE_DIST := 3.0
const SOFT_BRAKE_DIST := 12.0
const RAY_INTERVAL := 3
const STEER_AVOID_GAIN := 0.6
# Static | PlayerVehicle | NPC | Police
const RAY_MASK := 90

# Line-of-sight
const LOS_RANGE := 80.0
const LOS_LOCK_TIME := 3.0
const LOS_LOST_TIMEOUT := 15.0

# Stuck detection
const STUCK_TIMEOUT := 0.8
const STUCK_SPEED := 2.0
const ESCAPE_FORCE_DURATION := 1.5

var active := true

var _grid = preload("res://src/road_grid.gd").new()
var _vehicle: RigidBody3D = null
var _road_index := 0
var _direction: int = Direction.NORTH
var _next_intersection := 0.0
var _rng := RandomNumberGenerator.new()
var _ai_state: int = AIState.PATROL
var _player: Node3D = null

# Collision avoidance state
var _ray_cooldown := 0
var _dist_to_ahead := -1.0
var _hitting_wall := false
var _steer_avoidance := 0.0

# Stuck
var _stuck_timer := 0.0
var _escape_timer := 0.0
var _escaping := false

# LOS tracking
var _los_timer := 0.0
var _los_lost_timer := 0.0
var _pursuit_locked := false


func initialize(vehicle: RigidBody3D, road_idx: int, direction: int) -> void:
	_vehicle = vehicle
	_road_index = road_idx
	_direction = direction
	_rng.randomize()
	_find_next_intersection()


func _physics_process(delta: float) -> void:
	if not active or not _vehicle:
		return

	if not _player:
		_player = get_tree().get_first_node_in_group("player") as Node3D

	_update_ai_state(delta)
	_update_lights_and_siren()

	# Collision detection (throttled)
	_ray_cooldown -= 1
	if _ray_cooldown <= 0:
		_ray_cooldown = RAY_INTERVAL
		_cast_rays()

	# Stuck detection
	if _escaping:
		_process_escape(delta)
		return

	var speed_kmh := _vehicle.linear_velocity.length() * 3.6
	if speed_kmh < STUCK_SPEED:
		_stuck_timer += delta
		if _stuck_timer > STUCK_TIMEOUT:
			_begin_escape()
	else:
		_stuck_timer = 0.0

	# Check intersection arrival
	if _past_intersection():
		_pick_next_direction()
		_find_next_intersection()

	_drive(delta)


func _update_ai_state(delta: float) -> void:
	if WantedLevelManager.wanted_level <= 0:
		if _ai_state == AIState.PURSUE:
			_ai_state = AIState.PATROL
			_pursuit_locked = false
			_los_timer = 0.0
			_los_lost_timer = 0.0
		return

	if _ai_state == AIState.PATROL:
		if _check_los():
			_los_timer += delta
			_los_lost_timer = 0.0
			if _los_timer >= LOS_LOCK_TIME:
				_ai_state = AIState.PURSUE
				_pursuit_locked = true
		else:
			_los_timer = maxf(_los_timer - delta, 0.0)
	elif _ai_state == AIState.PURSUE:
		if _check_los():
			_los_lost_timer = 0.0
		else:
			_los_lost_timer += delta
			if _los_lost_timer >= LOS_LOST_TIMEOUT:
				_ai_state = AIState.PATROL
				_pursuit_locked = false
				_los_timer = 0.0


func _check_los() -> bool:
	if not _player or not _vehicle:
		return false

	var target := _get_player_vehicle_pos()
	var from := _vehicle.global_position + Vector3(0, 0.5, 0)
	var dist := from.distance_to(target)
	if dist > LOS_RANGE:
		return false

	var space := _vehicle.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, target)
	query.collision_mask = 2  # Static only (buildings block LOS)
	query.exclude = [_vehicle.get_rid()]
	var result := space.intersect_ray(query)
	return result.is_empty()


func _get_player_vehicle_pos() -> Vector3:
	if _player and "current_vehicle" in _player and _player.current_vehicle:
		return (_player.current_vehicle as Node3D).global_position
	if _player:
		return _player.global_position
	return _vehicle.global_position


func _update_lights_and_siren() -> void:
	var pursuing := _ai_state == AIState.PURSUE
	var light_bar := _vehicle.get_node_or_null("PoliceLightBar")
	if light_bar:
		light_bar.lights_active = pursuing
	var siren := _vehicle.get_node_or_null("PoliceSiren")
	if siren:
		siren.siren_active = pursuing


func _drive(_delta: float) -> void:
	var cruise := PATROL_SPEED if _ai_state == AIState.PATROL else PURSUIT_SPEED
	var desired_heading := _get_desired_heading()
	var forward := _get_vehicle_forward()
	var lane_error := _get_lane_error()

	var heading_error := forward.cross(desired_heading).y
	var steer := clampf(-heading_error * HEADING_STEER_GAIN, -1.0, 1.0)

	# Lane correction
	if absf(lane_error) > OFF_ROAD_THRESHOLD:
		steer += clampf(
			-lane_error * OFF_ROAD_LANE_GAIN, -OFF_ROAD_LANE_MAX, OFF_ROAD_LANE_MAX
		)
	else:
		steer += clampf(-lane_error * LANE_STEER_GAIN, -LANE_STEER_MAX, LANE_STEER_MAX)

	steer += clampf(_steer_avoidance, -0.5, 0.5)

	# PIT maneuver: steer toward player when close in pursuit
	if _ai_state == AIState.PURSUE and _player:
		var to_player := _get_player_vehicle_pos() - _vehicle.global_position
		to_player.y = 0.0
		var dist := to_player.length()
		if dist < PIT_DISTANCE and dist > 2.0:
			var pit_steer := forward.cross(to_player.normalized()).y
			steer += clampf(-pit_steer * PIT_STEER_GAIN, -0.6, 0.6)

	steer = clampf(steer, -1.0, 1.0)

	var speed_kmh := _vehicle.linear_velocity.length() * 3.6
	var speed_error := cruise - speed_kmh
	var throttle := clampf(speed_error * 0.04, 0.0, 0.8)
	var brake := 0.0
	if speed_kmh > cruise + 15.0:
		brake = clampf((speed_kmh - cruise) * 0.05, 0.0, 1.0)

	# Forward obstacle braking
	if _dist_to_ahead >= 0.0:
		if _dist_to_ahead < HARD_BRAKE_DIST:
			brake = 0.6
			throttle = 0.1
		elif _dist_to_ahead < SOFT_BRAKE_DIST:
			var t := (
				(_dist_to_ahead - HARD_BRAKE_DIST)
				/ (SOFT_BRAKE_DIST - HARD_BRAKE_DIST)
			)
			brake = maxf(brake, 0.4 * (1.0 - t))
			throttle = lerpf(0.15, throttle, t)

	throttle = maxf(throttle, 0.2)

	_vehicle.steering_input = steer
	_vehicle.throttle_input = throttle
	_vehicle.brake_input = brake
	_vehicle.handbrake_input = 0.0


func _begin_escape() -> void:
	_stuck_timer = 0.0
	_escaping = true
	_escape_timer = 0.0


func _process_escape(delta: float) -> void:
	_escape_timer += delta
	var back_dir := _vehicle.global_transform.basis.z
	_vehicle.apply_central_force(back_dir * 6000.0)
	_vehicle.steering_input = 0.5
	_vehicle.throttle_input = 0.0
	_vehicle.brake_input = 0.0
	_vehicle.handbrake_input = 0.0
	if _escape_timer >= ESCAPE_FORCE_DURATION:
		_escaping = false


func deactivate() -> void:
	active = false
	if _vehicle:
		_vehicle.steering_input = 0.0
		_vehicle.throttle_input = 0.0
		_vehicle.brake_input = 1.0
		_vehicle.handbrake_input = 1.0


func _cast_rays() -> void:
	var space := _vehicle.get_world_3d().direct_space_state
	var from := _vehicle.global_position + Vector3(0, 0.5, 0)
	var vehicle_fwd := _get_vehicle_forward()
	var exclude := [_vehicle.get_rid()]

	var to := from + vehicle_fwd * RAY_LENGTH
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = RAY_MASK
	query.exclude = exclude
	var result := space.intersect_ray(query)
	if result:
		_dist_to_ahead = from.distance_to(result.position)
		_hitting_wall = result.collider is StaticBody3D
	else:
		_dist_to_ahead = -1.0
		_hitting_wall = false

	# Side rays
	var angle_rad := deg_to_rad(SIDE_RAY_ANGLE)
	var left_dir := vehicle_fwd.rotated(Vector3.UP, angle_rad)
	var right_dir := vehicle_fwd.rotated(Vector3.UP, -angle_rad)
	var left_dist := SIDE_RAY_LENGTH + 1.0
	var right_dist := SIDE_RAY_LENGTH + 1.0

	var lq := PhysicsRayQueryParameters3D.create(
		from, from + left_dir * SIDE_RAY_LENGTH
	)
	lq.collision_mask = RAY_MASK
	lq.exclude = exclude
	var lr := space.intersect_ray(lq)
	if lr:
		left_dist = from.distance_to(lr.position)

	var rq := PhysicsRayQueryParameters3D.create(
		from, from + right_dir * SIDE_RAY_LENGTH
	)
	rq.collision_mask = RAY_MASK
	rq.exclude = exclude
	var rr := space.intersect_ray(rq)
	if rr:
		right_dist = from.distance_to(rr.position)

	if left_dist < SIDE_RAY_LENGTH or right_dist < SIDE_RAY_LENGTH:
		var diff := left_dist - right_dist
		_steer_avoidance = clampf(
			-diff * STEER_AVOID_GAIN / SIDE_RAY_LENGTH, -0.5, 0.5
		)
	else:
		_steer_avoidance = 0.0


func _get_vehicle_forward() -> Vector3:
	var forward := -_vehicle.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.001:
		return _dir_to_heading(_direction)
	return forward.normalized()


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


func _get_desired_heading() -> Vector3:
	if _ai_state == AIState.PURSUE and _player:
		var to_player := _get_player_vehicle_pos() - _vehicle.global_position
		to_player.y = 0.0
		if to_player.length_squared() > 1.0:
			# Blend road heading with direct pursuit heading
			var road_heading := _dir_to_heading(_direction)
			return road_heading.lerp(to_player.normalized(), 0.3).normalized()
	return _dir_to_heading(_direction)


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


func _pick_next_direction() -> void:
	if _ai_state == AIState.PURSUE and _player:
		_pick_pursuit_direction()
	else:
		_pick_random_direction()


func _pick_random_direction() -> void:
	var reverse := _get_reverse(_direction)
	var options: Array[int] = []
	for d in [Direction.NORTH, Direction.SOUTH, Direction.EAST, Direction.WEST]:
		if d != reverse:
			options.append(d)
	var new_dir: int = options[_rng.randi() % options.size()]
	_update_direction(new_dir)


func _pick_pursuit_direction() -> void:
	var to_player := _get_player_vehicle_pos() - _vehicle.global_position
	to_player.y = 0.0
	var reverse := _get_reverse(_direction)
	var best_dir := _direction
	var best_dot := -2.0
	for d in [Direction.NORTH, Direction.SOUTH, Direction.EAST, Direction.WEST]:
		if d == reverse:
			continue
		var heading := _dir_to_heading(d)
		var dot := to_player.normalized().dot(heading)
		if dot > best_dot:
			best_dot = dot
			best_dir = d
	_update_direction(best_dir)


func _update_direction(new_dir: int) -> void:
	var is_new_ns := new_dir == Direction.NORTH or new_dir == Direction.SOUTH
	var was_ns := _direction == Direction.NORTH or _direction == Direction.SOUTH
	if is_new_ns != was_ns:
		var pos := _vehicle.global_position
		var coord := pos.z if was_ns else pos.x
		_road_index = _grid.get_nearest_road_index(coord)
	_direction = new_dir


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
