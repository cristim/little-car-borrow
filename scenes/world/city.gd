extends Node3D
## Procedural greybox city builder.
## Generates a 10x10 block grid with roads, sidewalks, buildings, trees,
## ramps, and a safety ground plane at _ready().

const GRID_SIZE := 10
const BLOCK_SIZE := 40.0
const ROAD_WIDTH := 8.0
const BOULEVARD_WIDTH := 12.0
const ALLEY_WIDTH := 4.0
const SIDEWALK_WIDTH := 2.5
const SIDEWALK_HEIGHT := 0.15
const ROAD_THICKNESS := 0.2
const BOULEVARD_INDEX := 5
const ALLEY_INDEX := 2
const CURB_RAMP_RUN := 0.3

var _road_mat: StandardMaterial3D
var _sidewalk_mat: StandardMaterial3D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 42
	_init_materials()
	_build_roads()
	_build_block_ground()
	_build_sidewalks()
	_build_buildings()
	_build_trees()
	_build_ramps()
	_build_safety_ground()


func _init_materials() -> void:
	_road_mat = StandardMaterial3D.new()
	_road_mat.albedo_color = Color(0.2, 0.2, 0.22)

	_sidewalk_mat = StandardMaterial3D.new()
	_sidewalk_mat.albedo_color = Color(0.55, 0.55, 0.53)


func _get_road_width(index: int) -> float:
	if index == BOULEVARD_INDEX:
		return BOULEVARD_WIDTH
	if index == ALLEY_INDEX:
		return ALLEY_WIDTH
	return ROAD_WIDTH


## Returns the center X or Z position of road at given index.
func _get_road_center(index: int) -> float:
	var pos := 0.0
	for i in range(index):
		pos += _get_road_width(i) * 0.5 + BLOCK_SIZE + _get_road_width(i + 1) * 0.5
	# Offset so grid is centered around origin.
	var total := _get_grid_span()
	return pos - total * 0.5 + _get_road_width(0) * 0.5


func _get_grid_span() -> float:
	var span := 0.0
	for i in range(GRID_SIZE + 1):
		span += _get_road_width(i)
	span += BLOCK_SIZE * GRID_SIZE
	return span


func _create_static_body(
	parent: Node3D,
	node_name: String,
	pos: Vector3,
	size: Vector3,
	material: StandardMaterial3D,
	group: String,
	layer: int,
	rotation_deg := Vector3.ZERO,
) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = pos
	if rotation_deg != Vector3.ZERO:
		body.rotation_degrees = rotation_deg
	body.collision_layer = layer
	body.collision_mask = 0
	body.add_to_group(group)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)

	var mesh_inst := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	box_mesh.material = material
	mesh_inst.mesh = box_mesh
	body.add_child(mesh_inst)

	parent.add_child(body)
	return body


func _build_roads() -> void:
	var roads_parent := Node3D.new()
	roads_parent.name = "Roads"
	add_child(roads_parent)

	var span := _get_grid_span()

	# N-S roads (run along Z axis)
	for i in range(GRID_SIZE + 1):
		var w := _get_road_width(i)
		var cx := _get_road_center(i)
		_create_static_body(
			roads_parent,
			"RoadNS_%d" % i,
			Vector3(cx, -ROAD_THICKNESS * 0.5, 0.0),
			Vector3(w, ROAD_THICKNESS, span),
			_road_mat,
			"Road",
			1,
		)

	# E-W roads (run along X axis)
	for j in range(GRID_SIZE + 1):
		var w := _get_road_width(j)
		var cz := _get_road_center(j)
		_create_static_body(
			roads_parent,
			"RoadEW_%d" % j,
			Vector3(0.0, -ROAD_THICKNESS * 0.5, cz),
			Vector3(span, ROAD_THICKNESS, w),
			_road_mat,
			"Road",
			1,
		)


func _build_block_ground() -> void:
	var ground_parent := Node3D.new()
	ground_parent.name = "BlockGround"
	add_child(ground_parent)

	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_color = Color(0.45, 0.45, 0.43)

	for bx in range(GRID_SIZE):
		for bz in range(GRID_SIZE):
			var x_start := _get_road_center(bx) + _get_road_width(bx) * 0.5
			var x_end := _get_road_center(bx + 1) - _get_road_width(bx + 1) * 0.5
			var z_start := _get_road_center(bz) + _get_road_width(bz) * 0.5
			var z_end := _get_road_center(bz + 1) - _get_road_width(bz + 1) * 0.5
			var bw := x_end - x_start
			var bd := z_end - z_start
			_create_static_body(
				ground_parent,
				"BlockGround_%d_%d" % [bx, bz],
				Vector3((x_start + x_end) * 0.5, -ROAD_THICKNESS * 0.5, (z_start + z_end) * 0.5),
				Vector3(bw, ROAD_THICKNESS, bd),
				ground_mat,
				"Road",
				1,
			)


func _build_sidewalks() -> void:
	var sw_parent := Node3D.new()
	sw_parent.name = "Sidewalks"
	add_child(sw_parent)

	# N-S road sidewalks: one segment per block (between consecutive E-W roads)
	for i in range(GRID_SIZE + 1):
		var rw := _get_road_width(i)
		var cx := _get_road_center(i)
		for j in range(GRID_SIZE):
			var z_start := _get_road_center(j) + _get_road_width(j) * 0.5
			var z_end := _get_road_center(j + 1) - _get_road_width(j + 1) * 0.5
			var seg_len := z_end - z_start
			var seg_cz := (z_start + z_end) * 0.5
			_create_sidewalk(
				sw_parent,
				"SwNS_%d_%d_L" % [i, j],
				Vector3(cx - rw * 0.5 - SIDEWALK_WIDTH * 0.5, SIDEWALK_HEIGHT * 0.5, seg_cz),
				SIDEWALK_WIDTH,
				seg_len,
				"z",
			)
			_create_sidewalk(
				sw_parent,
				"SwNS_%d_%d_R" % [i, j],
				Vector3(cx + rw * 0.5 + SIDEWALK_WIDTH * 0.5, SIDEWALK_HEIGHT * 0.5, seg_cz),
				SIDEWALK_WIDTH,
				seg_len,
				"z",
			)

	# E-W road sidewalks: one segment per block (between consecutive N-S roads)
	for j in range(GRID_SIZE + 1):
		var rw := _get_road_width(j)
		var cz := _get_road_center(j)
		for i in range(GRID_SIZE):
			var x_start := _get_road_center(i) + _get_road_width(i) * 0.5
			var x_end := _get_road_center(i + 1) - _get_road_width(i + 1) * 0.5
			var seg_len := x_end - x_start
			var seg_cx := (x_start + x_end) * 0.5
			_create_sidewalk(
				sw_parent,
				"SwEW_%d_%d_T" % [j, i],
				Vector3(seg_cx, SIDEWALK_HEIGHT * 0.5, cz - rw * 0.5 - SIDEWALK_WIDTH * 0.5),
				SIDEWALK_WIDTH,
				seg_len,
				"x",
			)
			_create_sidewalk(
				sw_parent,
				"SwEW_%d_%d_B" % [j, i],
				Vector3(seg_cx, SIDEWALK_HEIGHT * 0.5, cz + rw * 0.5 + SIDEWALK_WIDTH * 0.5),
				SIDEWALK_WIDTH,
				seg_len,
				"x",
			)


## Creates a sidewalk with trapezoidal collision (sloped edges) for step-up.
## along_axis: "z" for N-S sidewalks (width in X), "x" for E-W (width in Z).
func _create_sidewalk(
	parent: Node3D,
	node_name: String,
	pos: Vector3,
	sw_width: float,
	length: float,
	along_axis: String,
) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = pos
	body.collision_layer = 1
	body.collision_mask = 0
	body.add_to_group("Road")

	var hw := sw_width * 0.5
	var hh := SIDEWALK_HEIGHT * 0.5
	var hl := length * 0.5
	var rr := CURB_RAMP_RUN

	var col := CollisionShape3D.new()
	var shape := ConvexPolygonShape3D.new()
	var points: PackedVector3Array

	if along_axis == "z":
		points = PackedVector3Array([
			Vector3(-hw, -hh, -hl),
			Vector3(-hw + rr, hh, -hl),
			Vector3(hw - rr, hh, -hl),
			Vector3(hw, -hh, -hl),
			Vector3(-hw, -hh, hl),
			Vector3(-hw + rr, hh, hl),
			Vector3(hw - rr, hh, hl),
			Vector3(hw, -hh, hl),
		])
	else:
		points = PackedVector3Array([
			Vector3(-hl, -hh, -hw),
			Vector3(-hl, hh, -hw + rr),
			Vector3(-hl, hh, hw - rr),
			Vector3(-hl, -hh, hw),
			Vector3(hl, -hh, -hw),
			Vector3(hl, hh, -hw + rr),
			Vector3(hl, hh, hw - rr),
			Vector3(hl, -hh, hw),
		])

	shape.points = points
	col.shape = shape
	body.add_child(col)

	var mesh_inst := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	if along_axis == "z":
		box_mesh.size = Vector3(sw_width, SIDEWALK_HEIGHT, length)
	else:
		box_mesh.size = Vector3(length, SIDEWALK_HEIGHT, sw_width)
	box_mesh.material = _sidewalk_mat
	mesh_inst.mesh = box_mesh
	body.add_child(mesh_inst)

	parent.add_child(body)


func _build_buildings() -> void:
	var bld_parent := Node3D.new()
	bld_parent.name = "Buildings"
	add_child(bld_parent)

	var idx := 0
	for bx in range(GRID_SIZE):
		for bz in range(GRID_SIZE):
			var block_center := _get_block_center(bx, bz)
			var count := _rng.randi_range(1, 4)
			for _b in range(count):
				var bw := _rng.randf_range(6.0, 22.0)
				var bd := _rng.randf_range(6.0, 22.0)
				# Mix of short shops and tall towers
				var bh: float
				if _rng.randf() < 0.15:
					bh = _rng.randf_range(25.0, 45.0)
				elif _rng.randf() < 0.3:
					bh = _rng.randf_range(3.0, 6.0)
				else:
					bh = _rng.randf_range(7.0, 20.0)
				var margin := 2.0
				var max_offset_x := maxf((BLOCK_SIZE - bw) * 0.5 - margin, 0.0)
				var max_offset_z := maxf((BLOCK_SIZE - bd) * 0.5 - margin, 0.0)
				var ox := _rng.randf_range(-max_offset_x, max_offset_x)
				var oz := _rng.randf_range(-max_offset_z, max_offset_z)

				var mat := StandardMaterial3D.new()
				mat.albedo_color = Color(
					_rng.randf_range(0.35, 0.75),
					_rng.randf_range(0.35, 0.7),
					_rng.randf_range(0.35, 0.7),
				)

				_create_static_body(
					bld_parent,
					"Building_%d" % idx,
					Vector3(block_center.x + ox, bh * 0.5, block_center.y + oz),
					Vector3(bw, bh, bd),
					mat,
					"Static",
					2,
				)
				idx += 1


func _get_block_center(bx: int, bz: int) -> Vector2:
	# Block (bx, bz) sits between road bx and road bx+1 (same for z).
	var cx := (_get_road_center(bx) + _get_road_width(bx) * 0.5
		+ _get_road_center(bx + 1) - _get_road_width(bx + 1) * 0.5) * 0.5
	var cz := (_get_road_center(bz) + _get_road_width(bz) * 0.5
		+ _get_road_center(bz + 1) - _get_road_width(bz + 1) * 0.5) * 0.5
	return Vector2(cx, cz)


func _build_trees() -> void:
	var tree_parent := Node3D.new()
	tree_parent.name = "Trees"
	add_child(tree_parent)

	var tree_spacing := 15.0
	var idx := 0

	# Place trees along N-S road sidewalks (right side), segmented per block
	for i in range(GRID_SIZE + 1):
		var rw := _get_road_width(i)
		var cx := _get_road_center(i)
		var tree_x := cx + rw * 0.5 + SIDEWALK_WIDTH * 0.5
		for j in range(GRID_SIZE):
			var z_start := _get_road_center(j) + _get_road_width(j) * 0.5
			var z_end := _get_road_center(j + 1) - _get_road_width(j + 1) * 0.5
			var z := z_start + tree_spacing * 0.5
			while z < z_end - 1.0:
				_add_tree(tree_parent, idx, Vector3(tree_x, SIDEWALK_HEIGHT, z))
				idx += 1
				z += tree_spacing + _rng.randf_range(-3.0, 3.0)

	# Place trees along E-W road sidewalks (bottom side), segmented per block
	for j in range(GRID_SIZE + 1):
		var rw := _get_road_width(j)
		var cz := _get_road_center(j)
		var tree_z := cz + rw * 0.5 + SIDEWALK_WIDTH * 0.5
		for i in range(GRID_SIZE):
			var x_start := _get_road_center(i) + _get_road_width(i) * 0.5
			var x_end := _get_road_center(i + 1) - _get_road_width(i + 1) * 0.5
			var x := x_start + tree_spacing * 0.5
			while x < x_end - 1.0:
				_add_tree(tree_parent, idx, Vector3(x, SIDEWALK_HEIGHT, tree_z))
				idx += 1
				x += tree_spacing + _rng.randf_range(-3.0, 3.0)


func _add_tree(parent: Node3D, idx: int, pos: Vector3) -> void:
	var trunk_h := _rng.randf_range(2.0, 5.0)
	var trunk_r := _rng.randf_range(0.12, 0.3)
	var canopy_r := _rng.randf_range(1.0, 2.5)
	var canopy_h := canopy_r * _rng.randf_range(1.2, 2.5)

	var tree_node := Node3D.new()
	tree_node.name = "Tree_%d" % idx
	tree_node.position = pos
	parent.add_child(tree_node)

	# Trunk (cylinder) with random brown tint
	var trunk_mat := StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(
		_rng.randf_range(0.25, 0.45),
		_rng.randf_range(0.15, 0.28),
		_rng.randf_range(0.05, 0.15),
	)
	var trunk_mesh := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = trunk_r * _rng.randf_range(0.6, 0.9)
	cyl.bottom_radius = trunk_r
	cyl.height = trunk_h
	cyl.material = trunk_mat
	trunk_mesh.mesh = cyl
	trunk_mesh.position.y = trunk_h * 0.5
	tree_node.add_child(trunk_mesh)

	# Canopy (sphere) with random green tint
	var canopy_mat := StandardMaterial3D.new()
	canopy_mat.albedo_color = Color(
		_rng.randf_range(0.08, 0.25),
		_rng.randf_range(0.3, 0.55),
		_rng.randf_range(0.05, 0.2),
	)
	var canopy_mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = canopy_r
	sphere.height = canopy_h
	sphere.material = canopy_mat
	canopy_mesh.mesh = sphere
	canopy_mesh.position.y = trunk_h + canopy_h * 0.3
	tree_node.add_child(canopy_mesh)

	# Collision body for trunk
	var body := StaticBody3D.new()
	body.collision_layer = 2
	body.collision_mask = 0
	body.add_to_group("Static")
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = trunk_r
	shape.height = trunk_h
	col.shape = shape
	col.position.y = trunk_h * 0.5
	body.add_child(col)
	tree_node.add_child(body)


func _build_ramps() -> void:
	var ramp_parent := Node3D.new()
	ramp_parent.name = "Ramps"
	add_child(ramp_parent)

	var ramp_mat := StandardMaterial3D.new()
	ramp_mat.albedo_color = Color(0.6, 0.55, 0.2)

	# Place ramps on the boulevard and other wide roads.
	var boulevard_x := _get_road_center(BOULEVARD_INDEX)
	var ramp_data := [
		# [position, rotation_degrees] — tilted box acts as wedge
		[Vector3(boulevard_x, 0.4, -80.0), Vector3(-15.0, 0.0, 0.0)],
		[Vector3(boulevard_x, 0.4, 80.0), Vector3(15.0, 0.0, 0.0)],
		# Cross-street ramps on road index 7 (an 8m road)
		[Vector3(-60.0, 0.4, _get_road_center(7)), Vector3(0.0, 0.0, 15.0)],
		[Vector3(60.0, 0.4, _get_road_center(3)), Vector3(0.0, 0.0, -15.0)],
	]

	for r_idx in range(ramp_data.size()):
		var rpos: Vector3 = ramp_data[r_idx][0]
		var rrot: Vector3 = ramp_data[r_idx][1]
		_create_static_body(
			ramp_parent,
			"Ramp_%d" % r_idx,
			rpos,
			Vector3(4.0, 0.3, 6.0),
			ramp_mat,
			"Road",
			1,
			rrot,
		)


func _build_safety_ground() -> void:
	var body := StaticBody3D.new()
	body.name = "SafetyGround"
	body.position = Vector3(0.0, -5.0, 0.0)
	body.collision_layer = 1
	body.collision_mask = 0
	body.add_to_group("Road")

	var col := CollisionShape3D.new()
	col.shape = WorldBoundaryShape3D.new()
	body.add_child(col)

	add_child(body)
