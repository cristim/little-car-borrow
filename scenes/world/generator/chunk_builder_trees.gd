extends RefCounted
## Builds trees using MultiMeshInstance3D for trunks and canopy variants.
## ~6 draw calls + 1 compound collision body per chunk instead of ~3000 nodes.

const TREE_SPACING := 15.0
const CANOPY_VARIANTS := 5

var _grid: RefCounted
var _trunk_mats: Array[StandardMaterial3D] = []
var _canopy_mats: Array[StandardMaterial3D] = []
var _trunk_mesh: CylinderMesh
var _canopy_meshes: Array[Mesh] = []

var _city_script: GDScript = preload("res://scenes/world/city.gd")


func init(
	grid: RefCounted,
	trunk_mats: Array[StandardMaterial3D],
	canopy_mats: Array[StandardMaterial3D],
	trunk_mesh: CylinderMesh,
	canopy_meshes: Array[Mesh],
) -> void:
	_grid = grid
	_trunk_mats = trunk_mats
	_canopy_mats = canopy_mats
	_trunk_mesh = trunk_mesh
	_canopy_meshes = canopy_meshes
	# Pre-set vertex_color_use_as_albedo on all shared materials so
	# _build_multimesh can pass them directly instead of duplicating.
	for m in _trunk_mats:
		m.vertex_color_use_as_albedo = true
	for m in _canopy_mats:
		m.vertex_color_use_as_albedo = true


func build(chunk: Node3D, tile: Vector2i, ox: float, oz: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(tile) ^ 0x7F3A

	# Collect per-tree data first, then batch into MultiMeshes
	var trunk_transforms: Array[Transform3D] = []
	var trunk_colors: Array[Color] = []
	# Per canopy variant: array of transforms + colors
	var canopy_transforms: Array = []  # Array of Array[Transform3D]
	var canopy_colors: Array = []  # Array of Array[Color]
	for _v in range(CANOPY_VARIANTS):
		canopy_transforms.append([])
		canopy_colors.append([])

	# Compound collision body for all tree trunks
	var body := StaticBody3D.new()
	body.name = "Trees"
	body.collision_layer = 2
	body.collision_mask = 0
	body.add_to_group("Static")

	# N-S road sidewalks (right side)
	for i in range(_grid.GRID_SIZE + 1):
		var rw: float = _grid.get_road_width(i)
		var cx: float = _grid.get_road_center_local(i) + ox
		var tree_x: float = cx + rw * 0.5 + _grid.SIDEWALK_WIDTH * 0.5
		for j in range(_grid.GRID_SIZE):
			var z_start: float = _grid.get_road_center_local(j) + _grid.get_road_width(j) * 0.5
			var z_end: float = (
				_grid.get_road_center_local(j + 1) - _grid.get_road_width(j + 1) * 0.5
			)
			var z := z_start + TREE_SPACING * 0.5
			while z < z_end - 1.0:
				var sh: float = _grid.SIDEWALK_HEIGHT
				var pos := Vector3(tree_x, sh, z + oz)
				_collect_tree(
					rng, pos, trunk_transforms, trunk_colors, canopy_transforms, canopy_colors, body
				)
				z += TREE_SPACING + rng.randf_range(-3.0, 3.0)

	# E-W road sidewalks (bottom side)
	for j in range(_grid.GRID_SIZE + 1):
		var rw: float = _grid.get_road_width(j)
		var cz: float = _grid.get_road_center_local(j) + oz
		var tree_z: float = cz + rw * 0.5 + _grid.SIDEWALK_WIDTH * 0.5
		for i in range(_grid.GRID_SIZE):
			var x_start: float = _grid.get_road_center_local(i) + _grid.get_road_width(i) * 0.5
			var x_end: float = (
				_grid.get_road_center_local(i + 1) - _grid.get_road_width(i + 1) * 0.5
			)
			var x := x_start + TREE_SPACING * 0.5
			while x < x_end - 1.0:
				var sh: float = _grid.SIDEWALK_HEIGHT
				var pos := Vector3(x + ox, sh, tree_z)
				_collect_tree(
					rng, pos, trunk_transforms, trunk_colors, canopy_transforms, canopy_colors, body
				)
				x += TREE_SPACING + rng.randf_range(-3.0, 3.0)

	# N-S road sidewalks (left side — mirror of right)
	for i in range(_grid.GRID_SIZE + 1):
		var rw: float = _grid.get_road_width(i)
		var cx: float = _grid.get_road_center_local(i) + ox
		var tree_x: float = cx - rw * 0.5 - _grid.SIDEWALK_WIDTH * 0.5
		for j in range(_grid.GRID_SIZE):
			var z_start: float = _grid.get_road_center_local(j) + _grid.get_road_width(j) * 0.5
			var z_end: float = (
				_grid.get_road_center_local(j + 1) - _grid.get_road_width(j + 1) * 0.5
			)
			var z := z_start + TREE_SPACING * 0.5
			while z < z_end - 1.0:
				var sh: float = _grid.SIDEWALK_HEIGHT
				var pos := Vector3(tree_x, sh, z + oz)
				_collect_tree(
					rng, pos, trunk_transforms, trunk_colors, canopy_transforms, canopy_colors, body
				)
				z += TREE_SPACING + rng.randf_range(-3.0, 3.0)

	# E-W road sidewalks (top side — mirror of bottom)
	for j in range(_grid.GRID_SIZE + 1):
		var rw: float = _grid.get_road_width(j)
		var cz: float = _grid.get_road_center_local(j) + oz
		var tree_z: float = cz - rw * 0.5 - _grid.SIDEWALK_WIDTH * 0.5
		for i in range(_grid.GRID_SIZE):
			var x_start: float = _grid.get_road_center_local(i) + _grid.get_road_width(i) * 0.5
			var x_end: float = (
				_grid.get_road_center_local(i + 1) - _grid.get_road_width(i + 1) * 0.5
			)
			var x := x_start + TREE_SPACING * 0.5
			while x < x_end - 1.0:
				var sh: float = _grid.SIDEWALK_HEIGHT
				var pos := Vector3(x + ox, sh, tree_z)
				_collect_tree(
					rng, pos, trunk_transforms, trunk_colors, canopy_transforms, canopy_colors, body
				)
				x += TREE_SPACING + rng.randf_range(-3.0, 3.0)

	# Build trunk MultiMesh
	if trunk_transforms.size() > 0:
		var mm := _build_multimesh(_trunk_mesh, trunk_transforms, trunk_colors, _trunk_mats[0])
		mm.name = "TrunksMM"
		body.add_child(mm)

	# Build canopy MultiMeshes (one per variant that has instances)
	for v in range(CANOPY_VARIANTS):
		var transforms: Array = canopy_transforms[v]
		if transforms.size() == 0:
			continue
		var colors: Array = canopy_colors[v]
		var mm := _build_multimesh(_canopy_meshes[v], transforms, colors, _canopy_mats[0])
		mm.name = "CanopyMM_%d" % v
		body.add_child(mm)

	chunk.add_child(body)


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

	# Trunk transform: scale cylinder to actual size, position at base
	var t_scale := Vector3(trunk_r * 2.0, trunk_h, trunk_r * 2.0)
	var t_pos := Vector3(pos.x, pos.y + trunk_h * 0.5, pos.z)
	var xform := Transform3D(Basis.from_scale(t_scale), t_pos)
	trunk_transforms.append(xform)
	var trunk_color := _trunk_mats[rng.randi() % _trunk_mats.size()].albedo_color
	trunk_colors.append(trunk_color)

	# Collision for trunk
	_city_script.add_cylinder_collision(body, t_pos, trunk_r, trunk_h)

	# Canopy — multiple overlapping shapes like original tree generation
	var shape_type := rng.randi() % 5
	var canopy_color := _canopy_mats[rng.randi() % _canopy_mats.size()].albedo_color
	var trunk_top := pos.y + trunk_h

	match shape_type:
		0:
			# Round: 2-3 overlapping spheres (variant 0)
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
			# Conifer: 2-3 stacked cones (variant 1)
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
			# Columnar: single tall sphere (variant 2)
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
			# Weeping: flat main + drooping lobes (variant 3)
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
			# Multi-tier: 2-3 stacked spheres (variant 4)
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
