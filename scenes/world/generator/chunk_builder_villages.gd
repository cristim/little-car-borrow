extends RefCounted
## Places small village building clusters on flat terrain areas.
## 0-1 village per terrain chunk. Buildings are smaller than city buildings.

const MAX_VILLAGE_BUILDINGS := 8
const MIN_VILLAGE_BUILDINGS := 3
const VILLAGE_SEARCH_ATTEMPTS := 10
const FLATNESS_THRESHOLD := 2.0  # max height variance within village footprint
const VILLAGE_RADIUS := 30.0  # meters

var _grid: RefCounted
var _noise: FastNoiseLite
var _building_mats: Array[StandardMaterial3D] = []
var _window_mat: StandardMaterial3D  # reserved for future village windows
var _boundary: RefCounted

var _city_script: GDScript = preload("res://scenes/world/city.gd")


func init(
	grid: RefCounted,
	noise: FastNoiseLite,
	building_mats: Array[StandardMaterial3D],
	window_mat: StandardMaterial3D,
	boundary: RefCounted = null,
) -> void:
	_grid = grid
	_noise = noise
	_building_mats = building_mats
	_window_mat = window_mat
	_boundary = boundary


func build(
	chunk: Node3D, tile: Vector2i, ox: float, oz: float,
) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(tile) ^ 0xBEEF
	# ~40% chance of a village
	if rng.randf() > 0.4:
		chunk.set_meta("has_village", false)
		return

	var span: float = _grid.get_grid_span()

	# Try to find a flat spot within the chunk
	var village_center := Vector3.ZERO
	var found := false
	for _attempt in range(VILLAGE_SEARCH_ATTEMPTS):
		var test_x: float = ox + rng.randf_range(
			-span * 0.3, span * 0.3
		)
		var test_z: float = oz + rng.randf_range(
			-span * 0.3, span * 0.3
		)
		if _is_flat_enough(test_x, test_z):
			var center_h: float = _sample_height(test_x, test_z)
			if center_h > 1.0:
				village_center = Vector3(
					test_x, center_h, test_z
				)
				found = true
				break

	if not found:
		chunk.set_meta("has_village", false)
		return

	chunk.set_meta("has_village", true)
	chunk.set_meta(
		"village_center",
		Vector2(village_center.x, village_center.z),
	)

	var count := rng.randi_range(
		MIN_VILLAGE_BUILDINGS, MAX_VILLAGE_BUILDINGS
	)
	var mat_count := _building_mats.size()

	var body := StaticBody3D.new()
	body.name = "VillageBuildings"
	body.collision_layer = 2  # Static
	body.collision_mask = 0
	body.add_to_group("Static")

	var sts: Array[SurfaceTool] = []
	var st_used: Array[bool] = []
	for _i in range(mat_count):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		sts.append(st)
		st_used.append(false)

	for _b in range(count):
		var angle: float = rng.randf() * TAU
		var dist: float = rng.randf_range(5.0, VILLAGE_RADIUS)
		var bx: float = village_center.x + cos(angle) * dist
		var bz: float = village_center.z + sin(angle) * dist
		var by: float = _sample_height(bx, bz)

		if by < 1.0:
			continue  # skip if underwater

		var bw: float = rng.randf_range(4.0, 8.0)
		var bd: float = rng.randf_range(4.0, 8.0)
		var bh: float = rng.randf_range(2.0, 6.0)

		var mat_idx := rng.randi() % mat_count
		var center := Vector3(bx, by + bh * 0.5, bz)
		var bsize := Vector3(bw, bh, bd)

		_city_script.st_add_box_no_bottom(
			sts[mat_idx], center, bsize
		)
		st_used[mat_idx] = true
		_city_script.add_box_collision(body, center, bsize)

	# Check if any buildings were actually placed
	var any_placed := false
	for i in range(mat_count):
		if not st_used[i]:
			continue
		any_placed = true
		sts[i].generate_normals()
		var mesh := sts[i].commit()
		var mesh_inst := MeshInstance3D.new()
		mesh_inst.name = "VillageMat_%d" % i
		mesh_inst.mesh = mesh
		mesh_inst.material_override = _building_mats[i]
		body.add_child(mesh_inst)

	if any_placed:
		chunk.add_child(body)
	else:
		body.queue_free()
		chunk.set_meta("has_village", false)


func _is_flat_enough(cx: float, cz: float) -> bool:
	var r := VILLAGE_RADIUS
	var samples: Array[float] = [
		_sample_height(cx, cz),
		_sample_height(cx - r, cz - r),
		_sample_height(cx + r, cz - r),
		_sample_height(cx - r, cz + r),
		_sample_height(cx + r, cz + r),
	]
	var min_h := samples[0]
	var max_h := samples[0]
	for h in samples:
		min_h = minf(min_h, h)
		max_h = maxf(max_h, h)
	return (max_h - min_h) < FLATNESS_THRESHOLD


func _sample_height(wx: float, wz: float) -> float:
	# Must match chunk_builder_terrain.gd _sample_height exactly
	var raw: float = _noise.get_noise_2d(wx, wz)
	var n: float = (raw + 1.0) * 0.5
	var grid_span: float = _grid.get_grid_span()

	var edge_dist: float = _boundary.get_signed_distance(wx, wz)
	if edge_dist < 0.0:
		return 0.0  # inside city

	var fade: float = clampf(
		edge_dist / (grid_span * 3.0), 0.0, 1.0
	)
	var max_h: float = lerpf(20.0, 80.0, fade)
	var h: float = n * max_h - 2.0

	# Smooth blend from city ground (y=0) over one full tile span.
	if edge_dist < grid_span:
		var t: float = edge_dist / grid_span
		t = t * t * (3.0 - 2.0 * t)  # smoothstep
		h = lerpf(0.0, maxf(h, 0.0), t)

	return h
