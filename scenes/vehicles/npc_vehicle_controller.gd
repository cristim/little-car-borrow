extends Node
## AI driver that follows roads and turns at intersections.
## Uses road_grid.gd for infinite tiling — works at any world position.
## Forward + angled side rays for collision avoidance and steering.
## Multi-phase jam escape: reverse → steer out → return to lane.
## Cross-traffic yield is time-limited to prevent intersection gridlock.

enum Direction { NORTH, SOUTH, EAST, WEST }
enum EscapePhase { NONE, REVERSE, STEER, RETURN }

# Driving tuning
const CRUISE_SPEED := 40.0  # km/h
const ARRIVAL_DIST := 6.0
const LANE_STEER_GAIN := 0.6
const LANE_STEER_MAX := 0.5
const HEADING_STEER_GAIN := 2.0
const OFF_ROAD_THRESHOLD := 5.0  # lane_error above this = aggressive return
const OFF_ROAD_LANE_GAIN := 2.0
const OFF_ROAD_LANE_MAX := 0.9

# Collision avoidance
const RAY_LENGTH := 25.0
const SIDE_RAY_LENGTH := 15.0
const SIDE_RAY_ANGLE := 20.0
const HARD_BRAKE_DIST := 3.0
const SOFT_BRAKE_DIST := 12.0
const RAY_INTERVAL := 3
const STEER_AVOID_GAIN := 0.6
const CROSS_RAY_LENGTH := 10.0
const MAX_YIELD_TIME := 2.0  # max seconds to wait for cross traffic
const RAY_MASK := 90  # Static | PlayerVehicle | NPC | Police

# Stuck detection
const REVERSE_TIMEOUT := 1.5
const STUCK_TIMEOUT := 0.8
const STUCK_SPEED := 2.0
const MIN_CREEP_THROTTLE := 0.25

# Escape maneuver phases
const ESCAPE_REVERSE_DURATION := 1.5
const ESCAPE_STEER_DURATION := 1.2
const ESCAPE_RETURN_DURATION := 3.0
const ESCAPE_RETURN_LANE_GAIN := 1.2
const ESCAPE_RETURN_HEADING_GAIN := 3.0
const MAX_ESCAPE_ATTEMPTS := 3
const ON_LANE_THRESHOLD := 3.0
const HEADING_ALIGN_DOT := 0.85  # ~30° — consider heading aligned with lane

# Recovery target (commit-once system)
const RECOVERY_HEADING_BIAS := 8.0  # heading-alignment bonus to break distance ties
const RECOVERY_ARRIVAL_DIST := 4.0  # perpendicular dist to consider "on lane"
const RECOVERY_MIN_SPEED := 5.0  # km/h — must be moving to confirm recovery

var active := true
var _grid = preload("res://src/road_grid.gd").new()
var _vehicle: RigidBody3D = null
var _road_index := 0
var _direction: int = Direction.NORTH
var _next_intersection := 0.0
var _rng := RandomNumberGenerator.new()

# Collision avoidance state
var _ray_cooldown := 0
var _dist_to_ahead := -1.0  # forward obstacle only
var _hitting_wall := false  # true if forward obstacle is static (building)
var _cross_traffic := false  # cross-traffic detected this frame
var _steer_avoidance := 0.0

# Stuck / yield detection
var _reverse_timer := 0.0
var _stuck_timer := 0.0
var _yield_timer := 0.0  # time spent waiting for cross traffic

# Escape state
var _escape_phase: int = EscapePhase.NONE
var _escape_timer := 0.0
var _escape_steer := 0.0
var _escape_attempts := 0

# Recovery target state (commit-once)
var _recovery_active := false
var _recovery_road_index := 0
var _recovery_direction: int = Direction.NORTH


func initialize(vehicle: RigidBody3D, road_idx: int, direction: int) -> void:
	_vehicle = vehicle
	_road_index = road_idx
	_direction = direction
	_find_next_intersection()


func _physics_process(delta: float) -> void:
	if not active or not _vehicle:
		return

	# --- Escape maneuver phases ---
	if _escape_phase != EscapePhase.NONE:
		_process_escape(delta)
		return

	# --- Collision detection (throttled) ---
	_ray_cooldown -= 1
	if _ray_cooldown <= 0:
		_ray_cooldown = RAY_INTERVAL
		_cast_rays()

	# --- Stuck detection ---
	var desired_heading := _get_desired_heading()
	var vel := _vehicle.linear_velocity
	var speed_kmh := vel.length() * 3.6
	var going_backwards := vel.dot(desired_heading) < 0.0

	if going_backwards and speed_kmh > STUCK_SPEED:
		_reverse_timer += delta
		if _reverse_timer > REVERSE_TIMEOUT:
			_begin_escape()
	else:
		_reverse_timer = 0.0

	# Stuck against a wall = faster escape trigger
	var stuck_timeout := STUCK_TIMEOUT
	if _hitting_wall and _dist_to_ahead >= 0.0 and _dist_to_ahead < SOFT_BRAKE_DIST:
		stuck_timeout = 0.4

	if speed_kmh < STUCK_SPEED:
		_stuck_timer += delta
		if _stuck_timer > stuck_timeout:
			_begin_escape()
	else:
		_stuck_timer = 0.0
		if speed_kmh > 10.0:
			_escape_attempts = 0

	# --- Cross-traffic yield timer ---
	if _cross_traffic:
		_yield_timer += delta
	else:
		_yield_timer = 0.0

	# Off-road: commit recovery target once, check completion each frame
	if absf(_get_lane_error()) > OFF_ROAD_THRESHOLD:
		_commit_recovery_target()
	elif _recovery_active:
		if _check_recovery_complete():
			_cancel_recovery()

	# Check if we've arrived at the next intersection
	if _past_intersection():
		_recovery_active = false
		_pick_next_direction()
		_find_next_intersection()

	# --- Normal driving ---
	_drive_normal(delta)


func _drive_normal(_delta: float) -> void:
	var forward := _get_vehicle_forward()

	# When recovering, steer toward the locked recovery target
	var desired_heading: Vector3
	var lane_error: float
	if _recovery_active:
		desired_heading = _dir_to_heading(_recovery_direction)
		lane_error = _get_recovery_lane_error()
	else:
		desired_heading = _get_desired_heading()
		lane_error = _get_lane_error()

	var heading_error := forward.cross(desired_heading).y
	var steer := clampf(-heading_error * HEADING_STEER_GAIN, -1.0, 1.0)

	var abs_lane := absf(lane_error)
	var off_road := abs_lane > OFF_ROAD_THRESHOLD

	# Lane correction — stronger when far off-road
	if off_road:
		steer += clampf(
			-lane_error * OFF_ROAD_LANE_GAIN, -OFF_ROAD_LANE_MAX, OFF_ROAD_LANE_MAX
		)
	else:
		steer += clampf(-lane_error * LANE_STEER_GAIN, -LANE_STEER_MAX, LANE_STEER_MAX)

	steer += clampf(_steer_avoidance, -0.5, 0.5)

	# Wall evasion: when close to a wall, steer hard toward lane
	if _hitting_wall and _dist_to_ahead >= 0.0 and _dist_to_ahead < SOFT_BRAKE_DIST:
		var wall_urgency := 1.0 - (_dist_to_ahead / SOFT_BRAKE_DIST)
		var lane_steer := -signf(lane_error) if abs_lane > 0.5 else _steer_avoidance
		steer = lerpf(steer, lane_steer, wall_urgency * 0.7)

	steer = clampf(steer, -1.0, 1.0)

	var speed_kmh := _vehicle.linear_velocity.length() * 3.6
	var speed_error := CRUISE_SPEED - speed_kmh
	var throttle := clampf(speed_error * 0.03, 0.0, 0.7)
	var brake := 0.0
	if speed_kmh > CRUISE_SPEED + 15.0:
		brake = clampf((speed_kmh - CRUISE_SPEED) * 0.05, 0.0, 1.0)

	# Forward obstacle braking
	if _dist_to_ahead >= 0.0:
		if _hitting_wall:
			# Wall ahead: stop completely and steer away, do NOT creep
			if _dist_to_ahead < HARD_BRAKE_DIST:
				brake = 0.8
				throttle = 0.0
			elif _dist_to_ahead < SOFT_BRAKE_DIST:
				var t := (
					(_dist_to_ahead - HARD_BRAKE_DIST)
					/ (SOFT_BRAKE_DIST - HARD_BRAKE_DIST)
				)
				brake = maxf(brake, 0.6 * (1.0 - t))
				throttle = lerpf(0.0, throttle, t)
		else:
			# Vehicle ahead: slow down but keep creeping
			if _dist_to_ahead < HARD_BRAKE_DIST:
				brake = 0.4
				throttle = MIN_CREEP_THROTTLE
			elif _dist_to_ahead < SOFT_BRAKE_DIST:
				var t := (
					(_dist_to_ahead - HARD_BRAKE_DIST)
					/ (SOFT_BRAKE_DIST - HARD_BRAKE_DIST)
				)
				brake = maxf(brake, 0.4 * (1.0 - t))
				throttle = lerpf(MIN_CREEP_THROTTLE, throttle, t)

	# Cross-traffic: light brake but only up to MAX_YIELD_TIME
	if _cross_traffic and _yield_timer < MAX_YIELD_TIME:
		brake = maxf(brake, 0.3)
		throttle = minf(throttle, 0.15)

	# Maintain forward creep only if NOT facing a wall up close
	if not (_hitting_wall and _dist_to_ahead >= 0.0 and _dist_to_ahead < HARD_BRAKE_DIST):
		throttle = maxf(throttle, MIN_CREEP_THROTTLE)

	_vehicle.steering_input = steer
	_vehicle.throttle_input = throttle
	_vehicle.brake_input = brake
	_vehicle.handbrake_input = 0.0


func _begin_escape() -> void:
	_reverse_timer = 0.0
	_stuck_timer = 0.0
	_yield_timer = 0.0
	_escape_attempts += 1

	if _escape_attempts > MAX_ESCAPE_ATTEMPTS:
		_escape_attempts = 0
		_recovery_active = false  # force fresh recovery target
		_road_index = _find_nearest_road_index()
		_direction = _pick_best_direction()
		_find_next_intersection()

	# Ensure we have a recovery target
	_commit_recovery_target()

	# Steer toward the recovery lane
	var lane_err := _get_recovery_lane_error()
	if absf(lane_err) > 1.0:
		_escape_steer = -signf(lane_err)
	elif absf(_steer_avoidance) > 0.1:
		_escape_steer = signf(_steer_avoidance)
	elif _escape_attempts % 2 == 0:
		_escape_steer = 1.0
	else:
		_escape_steer = -1.0

	_escape_phase = EscapePhase.REVERSE
	_escape_timer = 0.0


func _process_escape(delta: float) -> void:
	_escape_timer += delta

	_ray_cooldown -= 1
	if _ray_cooldown <= 0:
		_ray_cooldown = RAY_INTERVAL
		_cast_rays()

	# Commit recovery target once (idempotent guard inside)
	_commit_recovery_target()

	# Only allow escape cancel during RETURN phase with full recovery check
	if _escape_phase == EscapePhase.RETURN and _check_recovery_complete():
		_cancel_recovery()
		_escape_phase = EscapePhase.NONE
		_escape_timer = 0.0
		_stuck_timer = 0.0
		_escape_attempts = 0
		return

	match _escape_phase:
		EscapePhase.REVERSE:
			_vehicle.steering_input = -_escape_steer * 0.5
			_vehicle.throttle_input = 0.0
			_vehicle.brake_input = 0.0
			_vehicle.handbrake_input = 0.0
			var back_dir := _vehicle.global_transform.basis.z
			_vehicle.apply_central_force(back_dir * 6000.0)
			if _escape_timer >= ESCAPE_REVERSE_DURATION:
				_escape_phase = EscapePhase.STEER
				_escape_timer = 0.0

		EscapePhase.STEER:
			# Steer toward recovery lane (stable target)
			var lane_err := _get_recovery_lane_error()
			if absf(lane_err) > 1.0:
				_escape_steer = -signf(lane_err)
			_vehicle.steering_input = _escape_steer
			_vehicle.throttle_input = 0.6
			_vehicle.brake_input = 0.0
			_vehicle.handbrake_input = 0.0
			if _escape_timer >= ESCAPE_STEER_DURATION:
				_escape_phase = EscapePhase.RETURN
				_escape_timer = 0.0

		EscapePhase.RETURN:
			var desired_heading := _dir_to_heading(_recovery_direction)
			var forward := _get_vehicle_forward()

			var heading_err := forward.cross(desired_heading).y
			var steer := clampf(
				-heading_err * ESCAPE_RETURN_HEADING_GAIN, -1.0, 1.0
			)

			var lane_err := _get_recovery_lane_error()
			steer += clampf(-lane_err * ESCAPE_RETURN_LANE_GAIN, -0.6, 0.6)
			steer += clampf(_steer_avoidance, -0.4, 0.4)
			steer = clampf(steer, -1.0, 1.0)

			var speed_kmh := _vehicle.linear_velocity.length() * 3.6
			var throttle := clampf(
				(CRUISE_SPEED - speed_kmh) * 0.03, 0.15, 0.5
			)

			if _dist_to_ahead >= 0.0 and _dist_to_ahead < HARD_BRAKE_DIST:
				throttle = MIN_CREEP_THROTTLE

			_vehicle.steering_input = steer
			_vehicle.throttle_input = throttle
			_vehicle.brake_input = 0.0
			_vehicle.handbrake_input = 0.0

			if _escape_timer >= ESCAPE_RETURN_DURATION:
				_escape_phase = EscapePhase.NONE
				_escape_timer = 0.0


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


func _get_vehicle_forward() -> Vector3:
	var forward := -_vehicle.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.001:
		return _get_desired_heading()
	return forward.normalized()


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

	# Forward ray — uses ACTUAL vehicle forward, not desired heading
	var to := from + vehicle_fwd * RAY_LENGTH
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = RAY_MASK
	query.exclude = exclude
	var result := space.intersect_ray(query)
	if result:
		_dist_to_ahead = from.distance_to(result.position)
		# StaticBody3D = building/wall, RigidBody3D = another vehicle
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

	# Cross-traffic rays — SEPARATE from forward obstacle detection
	var heading := _get_desired_heading()
	var cross_left := heading.rotated(Vector3.UP, PI * 0.5)
	var cross_right := heading.rotated(Vector3.UP, -PI * 0.5)
	var cross_mask := 88  # PlayerVehicle | NPC | Police

	var clq := PhysicsRayQueryParameters3D.create(
		from, from + cross_left * CROSS_RAY_LENGTH
	)
	clq.collision_mask = cross_mask
	clq.exclude = exclude
	var clr := space.intersect_ray(clq)

	var crq := PhysicsRayQueryParameters3D.create(
		from, from + cross_right * CROSS_RAY_LENGTH
	)
	crq.collision_mask = cross_mask
	crq.exclude = exclude
	var crr := space.intersect_ray(crq)

	# Cross traffic is a separate flag — does NOT feed into _dist_to_ahead
	_cross_traffic = not clr.is_empty() or not crr.is_empty()

	# Steer avoidance from side rays
	if left_dist < SIDE_RAY_LENGTH or right_dist < SIDE_RAY_LENGTH:
		var diff := left_dist - right_dist
		_steer_avoidance = clampf(
			-diff * STEER_AVOID_GAIN / SIDE_RAY_LENGTH, -0.5, 0.5
		)
	else:
		_steer_avoidance = 0.0


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
	var reverse := _get_reverse(_direction)
	var options: Array[int] = []
	for d in [Direction.NORTH, Direction.SOUTH, Direction.EAST, Direction.WEST]:
		if d != reverse:
			options.append(d)

	var new_dir: int = options[_rng.randi() % options.size()]

	var is_new_ns := new_dir == Direction.NORTH or new_dir == Direction.SOUTH
	var was_ns := _direction == Direction.NORTH or _direction == Direction.SOUTH
	if is_new_ns != was_ns:
		_road_index = _find_nearest_road_index()

	_direction = new_dir


func _find_nearest_road_index() -> int:
	var pos := _vehicle.global_position
	var was_ns := _direction == Direction.NORTH or _direction == Direction.SOUTH
	var coord := pos.z if was_ns else pos.x
	return _grid.get_nearest_road_index(coord)


func _commit_recovery_target() -> void:
	if _recovery_active:
		return
	var pos := _vehicle.global_position
	var forward := _get_vehicle_forward()

	# Find nearest NS road (road center varies along x-axis)
	var ns_idx := _grid.get_nearest_road_index(pos.x)
	var ns_center := _grid.get_road_center_near(ns_idx, pos.x)
	var ns_dist := absf(pos.x - ns_center)

	# Find nearest EW road (road center varies along z-axis)
	var ew_idx := _grid.get_nearest_road_index(pos.z)
	var ew_center := _grid.get_road_center_near(ew_idx, pos.z)
	var ew_dist := absf(pos.z - ew_center)

	# Score = distance - heading alignment bonus (lower = better)
	var ns_heading_component := absf(forward.z)  # how aligned with NS
	var ew_heading_component := absf(forward.x)  # how aligned with EW
	var ns_score := ns_dist - ns_heading_component * RECOVERY_HEADING_BIAS
	var ew_score := ew_dist - ew_heading_component * RECOVERY_HEADING_BIAS

	if ns_score <= ew_score:
		_recovery_road_index = ns_idx
		_recovery_direction = Direction.NORTH if forward.z < 0.0 else Direction.SOUTH
	else:
		_recovery_road_index = ew_idx
		_recovery_direction = Direction.EAST if forward.x > 0.0 else Direction.WEST

	_recovery_active = true


func _cancel_recovery() -> void:
	_road_index = _recovery_road_index
	_direction = _recovery_direction
	_find_next_intersection()
	_recovery_active = false


func _check_recovery_complete() -> bool:
	var perp_dist := absf(_get_recovery_lane_error())
	if perp_dist > RECOVERY_ARRIVAL_DIST:
		return false
	var forward := _get_vehicle_forward()
	var desired := _dir_to_heading(_recovery_direction)
	if forward.dot(desired) < HEADING_ALIGN_DOT:
		return false
	var speed_kmh := _vehicle.linear_velocity.length() * 3.6
	if speed_kmh < RECOVERY_MIN_SPEED:
		return false
	return true


func _get_recovery_lane_error() -> float:
	var pos := _vehicle.global_position
	var is_ns := (
		_recovery_direction == Direction.NORTH
		or _recovery_direction == Direction.SOUTH
	)
	var road_axis := pos.x if is_ns else pos.z
	var road_center := _grid.get_road_center_near(_recovery_road_index, road_axis)
	var rw := _grid.get_road_width(_recovery_road_index)
	var lane_offset := rw / 4.0

	match _recovery_direction:
		Direction.NORTH:
			return pos.x - (road_center + lane_offset)
		Direction.SOUTH:
			return pos.x - (road_center - lane_offset)
		Direction.EAST:
			return pos.z - (road_center + lane_offset)
		Direction.WEST:
			return pos.z - (road_center - lane_offset)
	return 0.0


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
