extends "res://src/vehicle_ai_base.gd"
## Police AI that patrols roads and pursues the player when wanted.
## Inherits road-following logic pattern from vehicle_ai_base.gd.

enum AIState { PATROL, PURSUE }

# Driving tuning
const PATROL_SPEED := 40.0
const PURSUIT_SPEED := 60.0

# Pursuit steering
const PURSUIT_STEER_GAIN := 1.5
const PURSUIT_TURN_SLOW_ANGLE := 0.5
const PURSUIT_MIN_TURN_SPEED := 30.0

# Collision avoidance
const RAY_MASK := 122  # Static | PlayerVehicle | NPC | Pedestrians | Police

# Pursuit braking (shorter distances for aggressive chase)
const PURSUIT_HARD_BRAKE_DIST := 1.5
const PURSUIT_SOFT_BRAKE_DIST := 6.0
const PURSUIT_HARD_BRAKE := 0.4
const PURSUIT_HARD_THROTTLE := 0.3
const PATROL_HARD_BRAKE := 0.6
const PATROL_HARD_THROTTLE := 0.1
const SOFT_BRAKE_FACTOR := 0.3
const SOFT_THROTTLE_MIN := 0.2

# Cross-traffic detection
const MAX_YIELD_TIME := 1.0
const PURSUIT_YIELD_TIME := 0.5
const YIELD_BRAKE := 0.3
const YIELD_THROTTLE_MAX := 0.15

# Line-of-sight
const LOS_RANGE := 100.0
const LOS_LOCK_RANGE := 80.0  # within this distance, chase is never abandoned
const LOS_LOST_TIMEOUT := 40.0
const LOS_CHECK_INTERVAL := 0.2

# Stuck detection
const ESCAPE_FORCE_DURATION := 1.5

# Officer dismount
const DISMOUNT_RANGE := 12.0
const DISMOUNT_COOLDOWN := 15.0
const MAX_OFFICERS_PER_CAR := 2

# A* path following
const PATH_REFRESH_INTERVAL := 2.0
const WAYPOINT_ARRIVAL_DIST := 12.0
const DIRECT_CHASE_DIST := 30.0
const PATH_MIN_LENGTH := 2

var _ai_state: int = AIState.PATROL
var _player: Node3D = null

# Collision avoidance state (extends base)
var _hitting_pedestrian := false

# Stuck
var _escaping := false

# LOS tracking
var _los_lost_timer := 0.0
var _pursuit_locked := false
var _los_check_timer := 0.0
var _los_cached := false

# Officer spawning
var _officer_script: GDScript = preload("res://scenes/police/police_officer.gd")
var _officers_spawned := 0
var _dismount_timer := 0.0

# A* path following
var _road_graph = preload("res://src/road_graph.gd").new()
var _path_waypoints: Array[Vector3] = []
var _path_idx := 0
var _path_refresh_timer := 0.0


func initialize(vehicle: RigidBody3D, road_idx: int, direction: int) -> void:
	_vehicle = vehicle
	_road_index = road_idx
	_direction = direction
	_rng.randomize()
	_find_next_intersection()
	_spawn_grace = 2.0
	_path_refresh_timer = _rng.randf() * PATH_REFRESH_INTERVAL


func _physics_process(delta: float) -> void:
	if not active or not _vehicle:
		return

	if _spawn_grace > 0.0:
		_spawn_grace -= delta

	if not _player:
		_player = get_tree().get_first_node_in_group("player") as Node3D

	# Distance-based LOD — skip AI entirely for very far vehicles
	var cam := get_viewport().get_camera_3d()
	if cam:
		var cam_dist := _vehicle.global_position.distance_to(cam.global_position)
		if cam_dist > LOD_FREEZE_DIST:
			return

	_update_ai_state(delta)
	if _ai_state == AIState.PURSUE:
		_update_path(delta)
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
		if _stuck_timer > STUCK_TIMEOUT and _spawn_grace <= 0.0:
			if absf(_vehicle.linear_velocity.y) > 2.0:
				_stuck_timer = 0.0
			else:
				_begin_escape()
	else:
		_stuck_timer = 0.0
		if speed_kmh > 10.0:
			_escape_attempts = 0

	if _cross_traffic:
		_yield_timer += delta
	else:
		_yield_timer = 0.0

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
			_yield_timer = 0.0
			_cross_traffic = false
			_path_waypoints.clear()
			_path_idx = 0
			_path_refresh_timer = 0.0
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
		_yield_timer = 0.0
		_cross_traffic = false
		# Trigger immediate path computation on next frame
		_path_refresh_timer = PATH_REFRESH_INTERVAL

	# Throttle LOS raycasts to track if player is visible
	_los_check_timer += delta
	if _los_check_timer >= LOS_CHECK_INTERVAL:
		_los_check_timer = 0.0
		_los_cached = _check_los()

	# Drop pursuit only after losing LOS for a long time.
	# Within LOS_LOCK_RANGE the player is considered visible regardless of
	# raycast result — prevents quitting while the player is right there.
	var player_dist: float = (
		_vehicle.global_position.distance_to(_get_player_vehicle_pos()) if _vehicle else INF
	)
	if _los_cached or player_dist <= LOS_LOCK_RANGE:
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
			_yield_timer = 0.0
			_cross_traffic = false
			_path_waypoints.clear()
			_path_idx = 0
			_path_refresh_timer = 0.0


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


func _update_path(delta: float) -> void:
	_path_refresh_timer += delta
	if _path_refresh_timer < PATH_REFRESH_INTERVAL:
		return
	_path_refresh_timer = 0.0

	if not _player or not _vehicle:
		return

	var from := _vehicle.global_position
	var to := _get_player_vehicle_pos()

	# Skip pathfinding at short range -- direct chase is better
	if from.distance_to(to) < DIRECT_CHASE_DIST:
		_path_waypoints.clear()
		_path_idx = 0
		return

	var path: Array[Vector3] = _road_graph.find_path(from, to, _grid)
	if path.size() >= PATH_MIN_LENGTH:
		_path_waypoints = path
		# Skip first waypoint (our snapped starting intersection)
		_path_idx = 1 if path.size() > 1 else 0
	else:
		_path_waypoints.clear()
		_path_idx = 0


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
	officer.global_position = (_vehicle.global_position + side + Vector3(0.0, 0.5, 0.0))
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

		# Path-following when waypoints available and player is far
		if (
			_path_waypoints.size() > 0
			and _path_idx < _path_waypoints.size()
			and dist > DIRECT_CHASE_DIST
		):
			var wp: Vector3 = _path_waypoints[_path_idx]
			var to_wp := wp - _vehicle.global_position
			to_wp.y = 0.0
			var wp_dist := to_wp.length()

			# Advance waypoint when close enough
			if wp_dist < WAYPOINT_ARRIVAL_DIST:
				_path_idx += 1
				if _path_idx < _path_waypoints.size():
					wp = _path_waypoints[_path_idx]
					to_wp = wp - _vehicle.global_position
					to_wp.y = 0.0

			if to_wp.length() > 1.0:
				var cross_y := forward.cross(to_wp.normalized()).y
				var dot_p := forward.dot(to_wp.normalized())
				heading_err = atan2(cross_y, dot_p)
				steer = _calc_pursuit_steer(heading_err, PURSUIT_STEER_GAIN)
			else:
				steer = 0.0
		elif dist > 1.0:
			# Direct chase: close range or no path
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
			absf(heading_err),
			cruise,
			PURSUIT_TURN_SLOW_ANGLE,
			PURSUIT_MIN_TURN_SPEED,
		)

	var speed_kmh := _vehicle.linear_velocity.length() * 3.6
	var speed_error := cruise - speed_kmh
	var throttle := clampf(speed_error * 0.04, 0.0, 0.8)
	var brake := 0.0
	if speed_kmh > cruise + 15.0:
		brake = clampf((speed_kmh - cruise) * 0.05, 0.0, 1.0)

	# Forward obstacle braking
	if _dist_to_ahead >= 0.0:
		var bp := _calc_brake_params(pursuing, _hitting_pedestrian)
		if _dist_to_ahead < bp.hard_dist:
			brake = bp.hard_brake
			throttle = bp.hard_throttle
		elif _dist_to_ahead < bp.soft_dist:
			var t: float = (_dist_to_ahead - bp.hard_dist) / (bp.soft_dist - bp.hard_dist)
			brake = maxf(brake, SOFT_BRAKE_FACTOR * (1.0 - t))
			throttle = lerpf(SOFT_THROTTLE_MIN, throttle, t)

	# Cross-traffic yield
	var max_yield := PURSUIT_YIELD_TIME if pursuing else MAX_YIELD_TIME
	if _should_yield(_cross_traffic, _yield_timer, max_yield):
		brake = maxf(brake, YIELD_BRAKE)
		throttle = minf(throttle, YIELD_THROTTLE_MAX)

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
			-OFF_ROAD_LANE_MAX,
			OFF_ROAD_LANE_MAX,
		)
	else:
		steer += clampf(
			-lane_error * LANE_STEER_GAIN,
			-LANE_STEER_MAX,
			LANE_STEER_MAX,
		)
	return steer


static func _calc_pursuit_steer(heading_err: float, gain: float) -> float:
	return clampf(heading_err * gain, -1.0, 1.0)


static func _calc_pursuit_cruise(
	heading_err_abs: float,
	base_cruise: float,
	slow_angle: float,
	min_speed: float,
) -> float:
	if heading_err_abs <= slow_angle:
		return base_cruise
	var max_err := PI
	var t := (heading_err_abs - slow_angle) / (max_err - slow_angle)
	return lerpf(base_cruise, min_speed, t)


static func _calc_wall_steer(
	wall_urgency: float,
	steer_avoidance: float,
	current_steer: float,
) -> float:
	var wall_steer: float
	if absf(steer_avoidance) > 0.1:
		wall_steer = signf(steer_avoidance)
	else:
		wall_steer = signf(current_steer) if absf(current_steer) > 0.1 else 1.0
	if wall_urgency > 0.8:
		return wall_steer
	return lerpf(current_steer, wall_steer, wall_urgency * 0.7)


func _calc_brake_params(pursuing: bool, hitting_pedestrian: bool) -> Dictionary:
	if pursuing and not hitting_pedestrian:
		return {
			hard_dist = PURSUIT_HARD_BRAKE_DIST,
			soft_dist = PURSUIT_SOFT_BRAKE_DIST,
			hard_brake = PURSUIT_HARD_BRAKE,
			hard_throttle = PURSUIT_HARD_THROTTLE,
		}
	return {
		hard_dist = HARD_BRAKE_DIST,
		soft_dist = SOFT_BRAKE_DIST,
		hard_brake = PATROL_HARD_BRAKE,
		hard_throttle = PATROL_HARD_THROTTLE,
	}


static func _should_yield(
	cross_traffic: bool,
	yield_timer: float,
	max_yield: float,
) -> bool:
	if not cross_traffic:
		return false
	return yield_timer < max_yield


static func _calc_escape_steer(
	ai_state: int,
	steer_avoidance: float,
	lane_err: float,
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

	if absf(_vehicle.linear_velocity.y) <= 2.0:
		var back_dir := _vehicle.global_transform.basis.z
		back_dir.y = 0.0
		if back_dir.length_squared() > 0.001:
			back_dir = back_dir.normalized()
			_vehicle.apply_central_force(back_dir * 2000.0)

	# During pursuit: use raycast avoidance; during patrol: use lane error
	var lane_err := _get_lane_error() if _ai_state != AIState.PURSUE else 0.0
	var escape_steer := _calc_escape_steer(
		_ai_state,
		_steer_avoidance,
		lane_err,
	)

	_vehicle.steering_input = escape_steer
	_vehicle.throttle_input = 0.0
	_vehicle.brake_input = 0.0
	_vehicle.handbrake_input = 0.0
	if _escape_timer >= ESCAPE_FORCE_DURATION:
		_escaping = false


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
		_hitting_pedestrian = result.collider is CharacterBody3D
	else:
		_dist_to_ahead = -1.0
		_hitting_wall = false
		_hitting_pedestrian = false

	# Side rays
	var angle_rad := deg_to_rad(SIDE_RAY_ANGLE)
	var left_dir := vehicle_fwd.rotated(Vector3.UP, angle_rad)
	var right_dir := vehicle_fwd.rotated(Vector3.UP, -angle_rad)
	var left_dist := SIDE_RAY_LENGTH + 1.0
	var right_dist := SIDE_RAY_LENGTH + 1.0

	var lq := PhysicsRayQueryParameters3D.create(from, from + left_dir * SIDE_RAY_LENGTH)
	lq.collision_mask = RAY_MASK
	lq.exclude = exclude
	var lr := space.intersect_ray(lq)
	if lr:
		left_dist = from.distance_to(lr.position)

	var rq := PhysicsRayQueryParameters3D.create(from, from + right_dir * SIDE_RAY_LENGTH)
	rq.collision_mask = RAY_MASK
	rq.exclude = exclude
	var rr := space.intersect_ray(rq)
	if rr:
		right_dist = from.distance_to(rr.position)

	if left_dist < SIDE_RAY_LENGTH or right_dist < SIDE_RAY_LENGTH:
		var diff := left_dist - right_dist
		_steer_avoidance = clampf(-diff * STEER_AVOID_GAIN / SIDE_RAY_LENGTH, -0.5, 0.5)
	else:
		_steer_avoidance = 0.0

	# Cross-traffic rays — perpendicular to travel direction
	var travel_dir: Vector3
	var speed_kmh := _vehicle.linear_velocity.length() * 3.6
	if _ai_state == AIState.PURSUE and speed_kmh > 5.0:
		travel_dir = vehicle_fwd
	else:
		travel_dir = _dir_to_heading(_direction)
	var cross_left := travel_dir.rotated(Vector3.UP, PI * 0.5)
	var cross_right := travel_dir.rotated(Vector3.UP, -PI * 0.5)
	# NPC(16) | Pedestrians(32) | Police(64) = 112
	var cross_mask := 112

	var clq := PhysicsRayQueryParameters3D.create(from, from + cross_left * CROSS_RAY_LENGTH)
	clq.collision_mask = cross_mask
	clq.exclude = exclude
	var clr := space.intersect_ray(clq)

	var crq := PhysicsRayQueryParameters3D.create(from, from + cross_right * CROSS_RAY_LENGTH)
	crq.collision_mask = cross_mask
	crq.exclude = exclude
	var crr := space.intersect_ray(crq)

	_cross_traffic = not clr.is_empty() or not crr.is_empty()


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
