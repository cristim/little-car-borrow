extends Node
## Police AI that patrols roads and pursues the player when wanted.
## Inherits road-following logic pattern from npc_vehicle_controller.

enum Direction { NORTH, SOUTH, EAST, WEST }
enum AIState { PATROL, PURSUE }

# Driving tuning
const PATROL_SPEED := 40.0
const PURSUIT_SPEED := 60.0
const ARRIVAL_DIST := 6.0
const LANE_STEER_GAIN := 0.6
const LANE_STEER_MAX := 0.5
const HEADING_STEER_GAIN := 2.0
const OFF_ROAD_THRESHOLD := 5.0
const OFF_ROAD_LANE_GAIN := 2.0
const OFF_ROAD_LANE_MAX := 0.9

# Pursuit steering
const PURSUIT_STEER_GAIN := 1.5
const PURSUIT_TURN_SLOW_ANGLE := 0.5
const PURSUIT_MIN_TURN_SPEED := 30.0

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
# Static | PlayerVehicle | NPC | Police
const RAY_MASK := 90

# Line-of-sight
const LOS_RANGE := 100.0
const LOS_LOST_TIMEOUT := 20.0
const LOS_CHECK_INTERVAL := 0.2

# Stuck detection
const STUCK_TIMEOUT := 0.8
const STUCK_SPEED := 2.0
const ESCAPE_FORCE_DURATION := 1.5
const MAX_ESCAPE_ATTEMPTS := 3

# Officer dismount
const DISMOUNT_RANGE := 12.0
const DISMOUNT_COOLDOWN := 15.0
const MAX_OFFICERS_PER_CAR := 2

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
var _escape_attempts := 0

# LOS tracking
var _los_lost_timer := 0.0
var _pursuit_locked := false
var _los_check_timer := 0.0
var _los_cached := false

# Officer spawning
var _officer_script: GDScript = preload(
	"res://scenes/police/police_officer.gd"
)
var _officers_spawned := 0
var _dismount_timer := 0.0


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

	# Distance-based LOD — skip AI entirely for very far vehicles
	var cam := get_viewport().get_camera_3d()
	if cam:
		var cam_dist := _vehicle.global_position.distance_to(
			cam.global_position
		)
		if cam_dist > LOD_FREEZE_DIST:
			return

	_update_ai_state(delta)
	_update_lights_and_siren()
	_try_dismount(delta)

	# Collision detection (distance-throttled)
	_ray_cooldown -= 1
	if _ray_cooldown <= 0:
		_ray_cooldown = _get_ray_interval()
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
		if speed_kmh > 10.0:
			_escape_attempts = 0

	# Only check intersections during patrol (pursuit uses direct steering)
	if _ai_state == AIState.PATROL and _past_intersection():
		_pick_next_direction()
		_find_next_intersection()

	_drive(delta)


func _update_ai_state(delta: float) -> void:
	if WantedLevelManager.wanted_level <= 0:
		if _ai_state == AIState.PURSUE:
			_ai_state = AIState.PATROL
			_road_index = _find_nearest_road_index()
			_direction = _pick_best_direction()
			_find_next_intersection()
			_pursuit_locked = false
			_los_lost_timer = 0.0
			_escaping = false
			_escape_timer = 0.0
			_escape_attempts = 0
		return

	# Wanted level > 0: pursue immediately
	if _ai_state == AIState.PATROL:
		_ai_state = AIState.PURSUE
		_pursuit_locked = true
		_los_lost_timer = 0.0
		_los_check_timer = 0.0
		_escaping = false
		_escape_timer = 0.0
		_escape_attempts = 0

	# Throttle LOS raycasts to track if player is visible
	_los_check_timer += delta
	if _los_check_timer >= LOS_CHECK_INTERVAL:
		_los_check_timer = 0.0
		_los_cached = _check_los()

	# Drop pursuit only after losing LOS for a long time
	if _los_cached:
		_los_lost_timer = 0.0
	else:
		_los_lost_timer += delta
		if _los_lost_timer >= LOS_LOST_TIMEOUT:
			_ai_state = AIState.PATROL
			_road_index = _find_nearest_road_index()
			_direction = _pick_best_direction()
			_find_next_intersection()
			_pursuit_locked = false
			_los_lost_timer = 0.0
			_escaping = false
			_escape_timer = 0.0
			_escape_attempts = 0


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


func _try_dismount(delta: float) -> void:
	if _ai_state != AIState.PURSUE:
		return
	if _officers_spawned >= MAX_OFFICERS_PER_CAR:
		return

	_dismount_timer -= delta
	if _dismount_timer > 0.0:
		return

	if not _player or not _vehicle:
		return

	var target := _get_player_vehicle_pos()
	var dist := _vehicle.global_position.distance_to(target)
	if dist > DISMOUNT_RANGE:
		return

	# Spawn officer on the side of the vehicle
	var officer := CharacterBody3D.new()
	officer.set_script(_officer_script)
	var side := _vehicle.global_transform.basis.x * 2.0
	officer.global_position = (
		_vehicle.global_position + side
		+ Vector3(0.0, 0.5, 0.0)
	)
	get_tree().current_scene.add_child(officer)

	_officers_spawned += 1
	_dismount_timer = DISMOUNT_COOLDOWN


func _drive(_delta: float) -> void:
	var pursuing := _ai_state == AIState.PURSUE
	var cruise := PURSUIT_SPEED if pursuing else PATROL_SPEED
	var forward := _get_vehicle_forward()

	# Steering: direct-to-player during pursuit, road-following during patrol
	var steer: float
	var heading_err := 0.0

	if pursuing and _player:
		var to_player := _get_player_vehicle_pos() - _vehicle.global_position
		to_player.y = 0.0
		var dist := to_player.length()
		if dist > 1.0:
			var cross_y := forward.cross(to_player.normalized()).y
			var dot_p := forward.dot(to_player.normalized())
			heading_err = atan2(cross_y, dot_p)
			steer = _calc_pursuit_steer(heading_err, PURSUIT_STEER_GAIN)
		else:
			steer = 0.0
	else:
		steer = _compute_patrol_steer(forward)

	# Add obstacle avoidance
	steer += clampf(_steer_avoidance, -0.5, 0.5)
	steer = clampf(steer, -1.0, 1.0)

	# Wall evasion: override steer when close to a wall
	if _hitting_wall and _dist_to_ahead >= 0.0 and _dist_to_ahead < SOFT_BRAKE_DIST:
		var wall_urgency := 1.0 - (_dist_to_ahead / SOFT_BRAKE_DIST)
		steer = _calc_wall_steer(wall_urgency, _steer_avoidance, steer)

	# Reduce cruise speed for sharp turns during pursuit
	if pursuing:
		cruise = _calc_pursuit_cruise(
			absf(heading_err), cruise,
			PURSUIT_TURN_SLOW_ANGLE, PURSUIT_MIN_TURN_SPEED,
		)

	var speed_kmh := _vehicle.linear_velocity.length() * 3.6
	var speed_error := cruise - speed_kmh
	var throttle := clampf(speed_error * 0.04, 0.0, 0.8)
	var brake := 0.0
	if speed_kmh > cruise + 15.0:
		brake = clampf((speed_kmh - cruise) * 0.05, 0.0, 1.0)

	# Forward obstacle braking (less cautious in pursuit)
	if _dist_to_ahead >= 0.0:
		var hard_dist := 1.5 if pursuing else HARD_BRAKE_DIST
		var soft_dist := 6.0 if pursuing else SOFT_BRAKE_DIST
		if _dist_to_ahead < hard_dist:
			brake = 0.4 if pursuing else 0.6
			throttle = 0.3 if pursuing else 0.1
		elif _dist_to_ahead < soft_dist:
			var t := (
				(_dist_to_ahead - hard_dist)
				/ (soft_dist - hard_dist)
			)
			brake = maxf(brake, 0.3 * (1.0 - t))
			throttle = lerpf(0.2, throttle, t)

	# Only apply min throttle when not braking (avoid fighting brakes)
	if brake < 0.1:
		var min_throttle := 0.35 if pursuing else 0.2
		throttle = maxf(throttle, min_throttle)

	_vehicle.steering_input = steer
	_vehicle.throttle_input = throttle
	_vehicle.brake_input = brake
	_vehicle.handbrake_input = 0.0


func _compute_patrol_steer(forward: Vector3) -> float:
	var desired_heading := _dir_to_heading(_direction)
	var lane_error := _get_lane_error()
	# Use atan2 for heading error — works at all angles including 180 degrees
	# (cross product alone gives zero at 180, causing the car to drive straight)
	var cross_y := forward.cross(desired_heading).y
	var dot := forward.dot(desired_heading)
	var heading_error := atan2(cross_y, dot)
	var steer := clampf(-heading_error * HEADING_STEER_GAIN, -1.0, 1.0)
	if absf(lane_error) > OFF_ROAD_THRESHOLD:
		steer += clampf(
			-lane_error * OFF_ROAD_LANE_GAIN,
			-OFF_ROAD_LANE_MAX, OFF_ROAD_LANE_MAX,
		)
	else:
		steer += clampf(
			-lane_error * LANE_STEER_GAIN,
			-LANE_STEER_MAX, LANE_STEER_MAX,
		)
	return steer


static func _calc_pursuit_steer(heading_err: float, gain: float) -> float:
	return clampf(heading_err * gain, -1.0, 1.0)


static func _calc_pursuit_cruise(
	heading_err_abs: float, base_cruise: float,
	slow_angle: float, min_speed: float,
) -> float:
	if heading_err_abs <= slow_angle:
		return base_cruise
	var max_err := PI
	var t := (heading_err_abs - slow_angle) / (max_err - slow_angle)
	return lerpf(base_cruise, min_speed, t)


static func _calc_wall_steer(
	wall_urgency: float, steer_avoidance: float, current_steer: float,
) -> float:
	var wall_steer: float
	if absf(steer_avoidance) > 0.1:
		wall_steer = signf(steer_avoidance)
	else:
		wall_steer = signf(current_steer) if absf(current_steer) > 0.1 else 1.0
	if wall_urgency > 0.8:
		return wall_steer
	return lerpf(current_steer, wall_steer, wall_urgency * 0.7)


static func _calc_escape_steer(
	ai_state: int, steer_avoidance: float, lane_err: float,
) -> float:
	if ai_state == AIState.PURSUE:
		if absf(steer_avoidance) > 0.1:
			return signf(steer_avoidance)
		return 0.0
	# Patrol (or unknown state): steer toward lane center
	if absf(lane_err) > 1.0:
		return -signf(lane_err)
	return 0.0


func _begin_escape() -> void:
	_stuck_timer = 0.0
	_escape_timer = 0.0
	_escape_attempts += 1

	if _escape_attempts > MAX_ESCAPE_ATTEMPTS:
		_escape_attempts = 0
		_road_index = _find_nearest_road_index()
		_direction = _pick_best_direction()
		_find_next_intersection()

	_escaping = true


func _process_escape(delta: float) -> void:
	_escape_timer += delta
	var back_dir := _vehicle.global_transform.basis.z
	_vehicle.apply_central_force(back_dir * 6000.0)

	# During pursuit: use raycast avoidance; during patrol: use lane error
	var lane_err := _get_lane_error() if _ai_state != AIState.PURSUE else 0.0
	var escape_steer := _calc_escape_steer(
		_ai_state, _steer_avoidance, lane_err,
	)

	_vehicle.steering_input = escape_steer
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
	_pick_random_direction()


func _pick_random_direction() -> void:
	var reverse := _get_reverse(_direction)
	var options: Array[int] = []
	for d in [Direction.NORTH, Direction.SOUTH, Direction.EAST, Direction.WEST]:
		if d != reverse:
			options.append(d)
	var new_dir: int = options[_rng.randi() % options.size()]
	_update_direction(new_dir)


func _update_direction(new_dir: int) -> void:
	var is_new_ns := new_dir == Direction.NORTH or new_dir == Direction.SOUTH
	var was_ns := _direction == Direction.NORTH or _direction == Direction.SOUTH
	if is_new_ns != was_ns:
		var pos := _vehicle.global_position
		var coord := pos.z if was_ns else pos.x
		_road_index = _grid.get_nearest_road_index(coord)
	_direction = new_dir


func _find_nearest_road_index() -> int:
	var pos := _vehicle.global_position
	var was_ns := _direction == Direction.NORTH or _direction == Direction.SOUTH
	var coord := pos.z if was_ns else pos.x
	return _grid.get_nearest_road_index(coord)


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
