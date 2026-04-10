extends RefCounted
## Shared spawn-placement helpers used by traffic_manager.gd and
## police_manager.gd.  All functions are static so no instance is needed.

## GEVP wheel footprint half-extents (metres).
## Wheels are ≈1.2 m left/right and ≈1.4 m front/rear of body centre.
const FP_X := 1.2
const FP_Z := 1.4
const SEA_LEVEL := -2.0


## Probes the spawn surface at spawn_pos, returning a placement result.
##
## Result fields
##   ok             bool         – false → caller must skip this position
##   sd             float        – signed distance from city boundary (< 0 = inside)
##   surface_y      float        – max terrain height across the 4-corner footprint
##   corner_h       Array[float] – per-corner heights  [FL, FR, RL, RR]
##   terrain_normal Vector3      – best-fit plane normal (y > 0.3 guaranteed when ok)
static func probe_spawn_surface(
	space: PhysicsDirectSpaceState3D,
	boundary: RefCounted,
	spawn_pos: Vector3,
) -> Dictionary:
	var result := {
		"ok": false,
		"sd": 0.0,
		"surface_y": 0.0,
		"corner_h": [] as Array[float],
		"terrain_normal": Vector3.UP,
	}

	var sd: float = boundary.get_signed_distance(spawn_pos.x, spawn_pos.z)
	result.sd = sd

	# Centre raycast — Ground layer only (mask 1) to exclude buildings.
	var rq := (
		PhysicsRayQueryParameters3D
		. create(
			Vector3(spawn_pos.x, 80.0, spawn_pos.z),
			Vector3(spawn_pos.x, -5.0, spawn_pos.z),
		)
	)
	rq.collision_mask = 1
	var hit: Dictionary = space.intersect_ray(rq)
	var surface_y: float
	if not hit.is_empty():
		surface_y = (hit["position"] as Vector3).y
		# Outside city: flat base-plane hit (unloaded chunk) → use noise instead.
		if sd >= 0.0 and surface_y < 1.0:
			var noise_y: float = boundary.get_ground_height(spawn_pos.x, spawn_pos.z)
			if noise_y > 1.0:
				surface_y = noise_y
	else:
		if sd < 0.0:
			return result  # inside city, no road — skip
		surface_y = boundary.get_ground_height(spawn_pos.x, spawn_pos.z)

	if sd < 0.0 and surface_y < GameManager.SEA_LEVEL:
		return result
	if sd >= 0.0 and surface_y < 0.0:
		return result

	# Footprint probe: sample all four wheel corners; use the maximum height
	# so every wheel starts clear of the ground on the first physics tick.
	var max_surface_y: float = surface_y
	var corner_h: Array[float] = [surface_y, surface_y, surface_y, surface_y]
	var offsets: Array[Vector2] = [
		Vector2(-FP_X, -FP_Z),
		Vector2(FP_X, -FP_Z),
		Vector2(-FP_X, FP_Z),
		Vector2(FP_X, FP_Z),
	]
	for fi in range(4):
		var fo: Vector2 = offsets[fi]
		var fq := (
			PhysicsRayQueryParameters3D
			. create(
				Vector3(spawn_pos.x + fo.x, 80.0, spawn_pos.z + fo.y),
				Vector3(spawn_pos.x + fo.x, -5.0, spawn_pos.z + fo.y),
			)
		)
		fq.collision_mask = 1
		var fhit: Dictionary = space.intersect_ray(fq)
		if not fhit.is_empty():
			var fy: float = (fhit["position"] as Vector3).y
			corner_h[fi] = fy
			max_surface_y = maxf(max_surface_y, fy)
	surface_y = max_surface_y

	# Terrain normal via cross-product of the two footprint diagonals.
	# Skip positions steeper than ~73° (normal.y ≤ 0.3) — not drivable.
	var p_fl := Vector3(spawn_pos.x - FP_X, corner_h[0], spawn_pos.z - FP_Z)
	var p_fr := Vector3(spawn_pos.x + FP_X, corner_h[1], spawn_pos.z - FP_Z)
	var p_rl := Vector3(spawn_pos.x - FP_X, corner_h[2], spawn_pos.z + FP_Z)
	var p_rr := Vector3(spawn_pos.x + FP_X, corner_h[3], spawn_pos.z + FP_Z)
	var terrain_normal: Vector3 = (p_rl - p_fr).cross(p_rr - p_fl).normalized()
	if terrain_normal.y <= 0.3:
		return result

	result.ok = true
	result.surface_y = surface_y
	result.corner_h = corner_h
	result.terrain_normal = terrain_normal
	return result


## Applies terrain-slope tilt to a vehicle's basis while preserving spawn yaw.
static func apply_terrain_tilt(vehicle: Node3D, terrain_normal: Vector3, yaw: float) -> void:
	var fwd_flat := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var fwd_t: Vector3 = fwd_flat - terrain_normal * fwd_flat.dot(terrain_normal)
	if fwd_t.length_squared() > 0.01:
		fwd_t = fwd_t.normalized()
		vehicle.basis = Basis(fwd_t.cross(terrain_normal), terrain_normal, -fwd_t)
	else:
		vehicle.rotation.y = yaw


## Returns true if the vehicle body is at or below terrain level.
## When transitioning from freeze=true → false, call this first; if it returns
## true, cull the vehicle instead of unfreezing to prevent physics ejection.
static func is_embedded(v: Node, world: World3D) -> bool:
	var vp: Vector3 = (v as Node3D).global_position
	var uq := (
		PhysicsRayQueryParameters3D
		. create(
			Vector3(vp.x, vp.y + 2.0, vp.z),
			Vector3(vp.x, vp.y - 1.0, vp.z),
		)
	)
	uq.collision_mask = 1
	var uhit: Dictionary = world.direct_space_state.intersect_ray(uq)
	if not uhit.is_empty():
		return (uhit["position"] as Vector3).y >= vp.y
	return false
