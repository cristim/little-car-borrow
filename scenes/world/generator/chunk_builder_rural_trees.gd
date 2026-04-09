extends RefCounted
## Builds trees in rural terrain chunks using MultiMesh.
## Two categories: roadside trees along highways and forest clusters.

const CANOPY_VARIANTS := 6  # 0=sphere, 1=cone, 2=tall, 3=flat, 4=sphere2, 5=pine
const HIGHWAY_INDICES := [0, 5]
const ROADSIDE_SPACING_MIN := 20.0
const ROADSIDE_SPACING_MAX := 30.0
const ROADSIDE_OFFSET := 5.0
const MIN_TREE_HEIGHT := 1.0
const VILLAGE_CLEARANCE := 40.0
const CLUSTER_RADIUS_MIN := 30.0
const CLUSTER_RADIUS_MAX := 50.0
const CLUSTER_TREES_MIN := 8
const CLUSTER_TREES_MAX := 20
const HIGHWAY_CLEARANCE := 30.0
const VILLAGE_CLUSTER_CLEARANCE := 30.0

var _grid: RefCounted
var _trunk_mats: Array[StandardMaterial3D] = []
var _canopy_mats: Array[StandardMaterial3D] = []
var _trunk_mesh: CylinderMesh
var _canopy_meshes: Array[Mesh] = []
var _boundary: RefCounted

var _city_script: GDScript = preload("res://scenes/world/city.gd")


func init(
	grid: RefCounted,
	trunk_mats: Array[StandardMaterial3D],
	canopy_mats: Array[StandardMaterial3D],
	trunk_mesh: CylinderMesh,
	canopy_meshes: Array[Mesh],
	boundary: RefCounted,
) -> void:
	_grid = grid
	_trunk_mats = trunk_mats
	_canopy_mats = canopy_mats
	_trunk_mesh = trunk_mesh
	_canopy_meshes = canopy_meshes
	_boundary = boundary
	# Pre-set vertex_color_use_as_albedo on all shared materials so
	# _build_multimesh can pass them directly instead of duplicating.
	for m in _trunk_mats:
		m.vertex_color_use_as_albedo = true
	for m in _canopy_mats:
		m.vertex_color_use_as_albedo = true


func build(
	chunk: Node3D,
	tile: Vector2i,
	ox: float,
	oz: float,
	biome: String = "",
) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(tile) ^ 0x7B3E

	var span: float = _grid.get_grid_span()

	# Get village center if one exists in this chunk
	var has_village: bool = chunk.get_meta("has_village", false)
	var village_center := Vector2.ZERO
	if has_village:
		village_center = chunk.get_meta("village_center", Vector2.ZERO)

	# Collect tree data
	var trunk_transforms: Array[Transform3D] = []
	var trunk_colors: Array[Color] = []
	var canopy_transforms: Array = []
	var canopy_colors: Array = []
	for _v in range(CANOPY_VARIANTS):
		canopy_transforms.append([])
		canopy_colors.append([])

	var body := StaticBody3D.new()
	body.name = "RuralTrees"
	body.collision_layer = 2
	body.collision_mask = 0
	body.add_to_group("Static")

	# A) Roadside trees along each highway
	for hi in HIGHWAY_INDICES:
		var rw: float = _grid.get_road_width(hi)
		var offset: float = rw * 0.5 + ROADSIDE_OFFSET

		# N-S highways — trees along both sides
		var road_cx: float = _grid.get_road_center_local(hi) + ox
		for side in [-1.0, 1.0]:
			var tx: float = road_cx + side * offset
			var z: float = oz - span * 0.5
			while z < oz + span * 0.5:
				z += rng.randf_range(ROADSIDE_SPACING_MIN, ROADSIDE_SPACING_MAX)
				if z >= oz + span * 0.5:
					break
				if _near_village(tx, z, has_village, village_center):
					continue
				var h: float = _boundary.get_mesh_height(tx, z)
				if h < MIN_TREE_HEIGHT:
					continue
				_collect_tree(
					rng,
					Vector3(tx, h, z),
					trunk_transforms,
					trunk_colors,
					canopy_transforms,
					canopy_colors,
					body,
				)

		# E-W highways — trees along both sides
		var road_cz: float = _grid.get_road_center_local(hi) + oz
		for side in [-1.0, 1.0]:
			var tz: float = road_cz + side * offset
			var x: float = ox - span * 0.5
			while x < ox + span * 0.5:
				x += rng.randf_range(ROADSIDE_SPACING_MIN, ROADSIDE_SPACING_MAX)
				if x >= ox + span * 0.5:
					break
				if _near_village(x, tz, has_village, village_center):
					continue
				var h: float = _boundary.get_mesh_height(x, tz)
				if h < MIN_TREE_HEIGHT:
					continue
				_collect_tree(
					rng,
					Vector3(x, h, tz),
					trunk_transforms,
					trunk_colors,
					canopy_transforms,
					canopy_colors,
					body,
				)

	# B) Forest clusters — density varies by biome
	var density := _get_biome_density(biome)
	var cluster_count := (
		rng
		. randi_range(
			density["min_clusters"],
			density["max_clusters"],
		)
	)
	for _ci in range(cluster_count):
		var cx: float = ox + rng.randf_range(-span * 0.4, span * 0.4)
		var cz: float = oz + rng.randf_range(-span * 0.4, span * 0.4)

		# Skip if near a highway center
		if _near_highway(cx, cz, ox, oz):
			continue
		# Skip if near village
		if _near_village(cx, cz, has_village, village_center):
			continue
		# Skip if terrain too low
		var ch: float = _boundary.get_ground_height(cx, cz)
		if ch < MIN_TREE_HEIGHT:
			continue

		var cluster_r: float = rng.randf_range(CLUSTER_RADIUS_MIN, CLUSTER_RADIUS_MAX)
		var tree_count := (
			rng
			. randi_range(
				density["min_trees"],
				density["max_trees"],
			)
		)
		for _ti in range(tree_count):
			var angle: float = rng.randf() * TAU
			var dist: float = rng.randf() * cluster_r
			var tx: float = cx + cos(angle) * dist
			var tz: float = cz + sin(angle) * dist
			var h: float = _boundary.get_mesh_height(tx, tz)
			if h < MIN_TREE_HEIGHT:
				continue
			_collect_tree(
				rng,
				Vector3(tx, h, tz),
				trunk_transforms,
				trunk_colors,
				canopy_transforms,
				canopy_colors,
				body,
			)

	if trunk_transforms.is_empty():
		body.queue_free()
		return

	# Build trunk MultiMesh
	var mm := _build_multimesh(_trunk_mesh, trunk_transforms, trunk_colors, _trunk_mats[0])
	mm.name = "RuralTrunksMM"
	body.add_child(mm)

	# Build canopy MultiMeshes
	for v in range(CANOPY_VARIANTS):
		var transforms: Array = canopy_transforms[v]
		if transforms.size() == 0:
			continue
		var colors: Array = canopy_colors[v]
		var cmm := _build_multimesh(_canopy_meshes[v], transforms, colors, _canopy_mats[0])
		cmm.name = "RuralCanopyMM_%d" % v
		body.add_child(cmm)

	chunk.add_child(body)


func _near_village(
	wx: float,
	wz: float,
	has_village: bool,
	village_center: Vector2,
) -> bool:
	if not has_village:
		return false
	var dx: float = wx - village_center.x
	var dz: float = wz - village_center.y
	return dx * dx + dz * dz < VILLAGE_CLEARANCE * VILLAGE_CLEARANCE


func _near_highway(wx: float, wz: float, ox: float, oz: float) -> bool:
	for hi in HIGHWAY_INDICES:
		var ns_cx: float = _grid.get_road_center_local(hi) + ox
		if absf(wx - ns_cx) < HIGHWAY_CLEARANCE:
			return true
		var ew_cz: float = _grid.get_road_center_local(hi) + oz
		if absf(wz - ew_cz) < HIGHWAY_CLEARANCE:
			return true
	return false


## Biome-specific tree density parameters.
static func _get_biome_density(biome: String) -> Dictionary:
	match biome:
		"forest":
			return {
				"min_clusters": 4,
				"max_clusters": 7,
				"min_trees": 15,
				"max_trees": 30,
			}
		"mountain":
			return {
				"min_clusters": 2,
				"max_clusters": 4,
				"min_trees": 6,
				"max_trees": 15,
			}
		"farmland":
			return {
				"min_clusters": 1,
				"max_clusters": 2,
				"min_trees": 3,
				"max_trees": 8,
			}
		"suburb":
			return {
				"min_clusters": 1,
				"max_clusters": 3,
				"min_trees": 4,
				"max_trees": 10,
			}
		_:
			return {
				"min_clusters": 2,
				"max_clusters": 4,
				"min_trees": 8,
				"max_trees": 20,
			}


func _collect_tree(
	rng: RandomNumberGenerator,
	pos: Vector3,
	trunk_transforms: Array[Transform3D],
	trunk_colors: Array[Color],
	canopy_transforms: Array,
	canopy_colors: Array,
	body: StaticBody3D,
) -> void:
	var trunk_h := rng.randf_range(2.0, 5.0)
	var trunk_r := rng.randf_range(0.12, 0.3)

	var t_scale := Vector3(trunk_r * 2.0, trunk_h, trunk_r * 2.0)
	var t_pos := Vector3(pos.x, pos.y + trunk_h * 0.5, pos.z)
	var xform := Transform3D(Basis.from_scale(t_scale), t_pos)
	trunk_transforms.append(xform)
	var trunk_color := _trunk_mats[rng.randi() % _trunk_mats.size()].albedo_color
	trunk_colors.append(trunk_color)

	_city_script.add_cylinder_collision(body, t_pos, trunk_r, trunk_h)

	var shape_type := rng.randi() % mini(CANOPY_VARIANTS, _canopy_meshes.size())
	var canopy_color := _canopy_mats[rng.randi() % _canopy_mats.size()].albedo_color
	var trunk_top := pos.y + trunk_h

	match shape_type:
		0:
			var count := rng.randi_range(2, 3)
			var base_r := rng.randf_range(1.0, 2.0)
			for ci in range(count):
				var r := base_r * rng.randf_range(0.6, 1.0)
				var h := r * rng.randf_range(1.4, 2.0)
				var cy := trunk_top + base_r * 0.3 + ci * base_r * 0.35
				var cx := pos.x + rng.randf_range(-base_r * 0.4, base_r * 0.4)
				var cz := pos.z + rng.randf_range(-base_r * 0.4, base_r * 0.4)
				_add_canopy(
					canopy_transforms,
					canopy_colors,
					0,
					Vector3(cx, cy, cz),
					Vector3(r, h * 0.5, r),
					canopy_color
				)
		1:
			var tiers := rng.randi_range(2, 3)
			var base_r := rng.randf_range(1.2, 2.2)
			var tier_h := rng.randf_range(1.5, 2.5)
			var y := trunk_top - tier_h * 0.2
			for ci in range(tiers):
				var frac := 1.0 - float(ci) / float(tiers)
				var r := base_r * frac
				var cy := y + tier_h * 0.5
				_add_canopy(
					canopy_transforms,
					canopy_colors,
					1,
					Vector3(pos.x, cy, pos.z),
					Vector3(r, tier_h, r),
					canopy_color
				)
				y += tier_h * 0.55
		2:
			var r := rng.randf_range(0.6, 1.2)
			var h := rng.randf_range(4.0, 7.0)
			_add_canopy(
				canopy_transforms,
				canopy_colors,
				2,
				Vector3(pos.x, trunk_top + h * 0.35, pos.z),
				Vector3(r, h / 3.75, r),
				canopy_color
			)
		3:
			var main_r := rng.randf_range(1.5, 2.8)
			var main_h := main_r * rng.randf_range(0.6, 0.9)
			_add_canopy(
				canopy_transforms,
				canopy_colors,
				3,
				Vector3(pos.x, trunk_top + main_h * 0.3, pos.z),
				Vector3(main_r, main_h * 1.5, main_r),
				canopy_color
			)
			var lobes := rng.randi_range(2, 3)
			for ci in range(lobes):
				var angle := float(ci) * TAU / float(lobes) + rng.randf_range(-0.3, 0.3)
				var lr := main_r * rng.randf_range(0.3, 0.5)
				var lh := lr * rng.randf_range(1.5, 2.5)
				var lx := pos.x + cos(angle) * main_r * 0.6
				var lz := pos.z + sin(angle) * main_r * 0.6
				_add_canopy(
					canopy_transforms,
					canopy_colors,
					0,
					Vector3(lx, trunk_top - lh * 0.1, lz),
					Vector3(lr, lh * 0.5, lr),
					canopy_color
				)
		4:
			var tiers := rng.randi_range(2, 3)
			var base_r := rng.randf_range(1.2, 2.0)
			var gap := rng.randf_range(0.8, 1.4)
			var y := trunk_top
			for ci in range(tiers):
				var r := base_r * (1.0 - float(ci) * 0.2)
				var h := r * rng.randf_range(0.7, 1.2)
				var cx := pos.x + rng.randf_range(-0.3, 0.3)
				var cz := pos.z + rng.randf_range(-0.3, 0.3)
				_add_canopy(
					canopy_transforms,
					canopy_colors,
					4,
					Vector3(cx, y + h * 0.4, cz),
					Vector3(r, h / 2.0, r),
					canopy_color
				)
				y += gap
		5:
			# Pine: 2-3 stacked cones, narrowing upward
			var tiers := rng.randi_range(2, 3)
			var base_r := rng.randf_range(1.0, 1.8)
			var tier_h := rng.randf_range(1.5, 2.5)
			var y := trunk_top - tier_h * 0.3
			# Blue-green tint for pine
			var pine_color := Color(
				canopy_color.r * 0.7,
				canopy_color.g * 0.85,
				canopy_color.b * 1.3,
			)
			for ci in range(tiers):
				var frac := 1.0 - float(ci) / float(tiers) * 0.6
				var r := base_r * frac
				_add_canopy(
					canopy_transforms,
					canopy_colors,
					5,
					Vector3(pos.x, y + tier_h * 0.5, pos.z),
					Vector3(r, tier_h / 2.0, r),
					pine_color
				)
				y += tier_h * 0.5


func _add_canopy(
	canopy_transforms: Array,
	canopy_colors: Array,
	variant: int,
	center: Vector3,
	scale: Vector3,
	color: Color,
) -> void:
	var xform := Transform3D(Basis.from_scale(scale), center)
	canopy_transforms[variant].append(xform)
	canopy_colors[variant].append(color)


func _build_multimesh(
	mesh: Mesh,
	transforms: Array,
	colors: Array,
	base_mat: StandardMaterial3D,
) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.instance_count = transforms.size()
	mm.mesh = mesh

	for i in range(transforms.size()):
		mm.set_instance_transform(i, transforms[i])
		mm.set_instance_color(i, colors[i])

	# base_mat already has vertex_color_use_as_albedo set in init() — reuse directly.
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = base_mat
	return mmi
