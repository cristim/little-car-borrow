extends RefCounted
## Builds helipads in suburb chunks: a concrete pad with an "H" marking and a
## parked helicopter ready for the player to board.
## Called after suburb_builder so helipads sit on flat ground.

const PAD_SIZE := 14.0
const PAD_THICKNESS := 0.12
const HELIPADS_PER_CHUNK := 2
## Spawn Y: FUSE_HH(1.1) + SKID_DROP(0.7) + SKID_HEIGHT/2(0.03) + epsilon
const HELI_SPAWN_Y := 1.85
## Inset from chunk edge when choosing pad centre
const EDGE_MARGIN := 12.0
## "H" marking dimensions
const H_BAR_W := 0.5
const H_BAR_L := 4.0
const H_CROSS_W := 3.2
const H_CROSS_H := 0.5
const MARKING_Y := 0.003

var _grid: RefCounted
var _pad_mat: StandardMaterial3D
var _marking_mat: StandardMaterial3D
var _heli_scene: PackedScene


func init(
	grid: RefCounted,
	pad_mat: StandardMaterial3D,
	marking_mat: StandardMaterial3D,
) -> void:
	_grid = grid
	_pad_mat = pad_mat
	_marking_mat = marking_mat
	_heli_scene = load("res://scenes/vehicles/helicopter.tscn") as PackedScene


func build(chunk: Node3D, tile: Vector2i, ox: float, oz: float) -> void:
	if _heli_scene == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(tile) ^ 0x4EA1

	var span: float = _grid.get_grid_span()

	for _i in range(HELIPADS_PER_CHUNK):
		var lx := rng.randf_range(EDGE_MARGIN, span - EDGE_MARGIN)
		var lz := rng.randf_range(EDGE_MARGIN, span - EDGE_MARGIN)
		var world_pos := Vector3(ox + lx, 0.0, oz + lz)
		_build_pad(chunk, world_pos)
		_build_marking(chunk, world_pos)
		_spawn_helicopter(chunk, world_pos + Vector3(0.0, HELI_SPAWN_Y, 0.0))


func _build_pad(chunk: Node3D, center: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = "Helipad"
	body.collision_layer = 1  # ground layer — helicopter can land on it
	body.collision_mask = 0
	body.add_to_group("Road")
	body.add_to_group("helipad")
	# Store world centre so the minimap can draw the H icon at the correct spot
	body.set_meta("helipad_center", center)

	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(PAD_SIZE, PAD_THICKNESS, PAD_SIZE)
	col.shape = box
	# Position pad so top surface sits at Y=0
	col.position = Vector3(center.x, -PAD_THICKNESS * 0.5, center.z)
	body.add_child(col)

	var mesh_inst := MeshInstance3D.new()
	mesh_inst.name = "PadMesh"
	var arr_mesh := ArrayMesh.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pad_center := Vector3(center.x, -PAD_THICKNESS * 0.5, center.z)
	var hs := PAD_SIZE * 0.5
	var ht := PAD_THICKNESS * 0.5
	# Top face
	_st_quad(
		st,
		Vector3(pad_center.x - hs, pad_center.y + ht, pad_center.z - hs),
		Vector3(pad_center.x + hs, pad_center.y + ht, pad_center.z - hs),
		Vector3(pad_center.x + hs, pad_center.y + ht, pad_center.z + hs),
		Vector3(pad_center.x - hs, pad_center.y + ht, pad_center.z + hs),
	)
	# Four side faces
	_st_quad(
		st,
		Vector3(pad_center.x - hs, pad_center.y - ht, pad_center.z - hs),
		Vector3(pad_center.x + hs, pad_center.y - ht, pad_center.z - hs),
		Vector3(pad_center.x + hs, pad_center.y + ht, pad_center.z - hs),
		Vector3(pad_center.x - hs, pad_center.y + ht, pad_center.z - hs),
	)
	_st_quad(
		st,
		Vector3(pad_center.x + hs, pad_center.y - ht, pad_center.z + hs),
		Vector3(pad_center.x - hs, pad_center.y - ht, pad_center.z + hs),
		Vector3(pad_center.x - hs, pad_center.y + ht, pad_center.z + hs),
		Vector3(pad_center.x + hs, pad_center.y + ht, pad_center.z + hs),
	)
	_st_quad(
		st,
		Vector3(pad_center.x - hs, pad_center.y - ht, pad_center.z + hs),
		Vector3(pad_center.x - hs, pad_center.y - ht, pad_center.z - hs),
		Vector3(pad_center.x - hs, pad_center.y + ht, pad_center.z - hs),
		Vector3(pad_center.x - hs, pad_center.y + ht, pad_center.z + hs),
	)
	_st_quad(
		st,
		Vector3(pad_center.x + hs, pad_center.y - ht, pad_center.z - hs),
		Vector3(pad_center.x + hs, pad_center.y - ht, pad_center.z + hs),
		Vector3(pad_center.x + hs, pad_center.y + ht, pad_center.z + hs),
		Vector3(pad_center.x + hs, pad_center.y + ht, pad_center.z - hs),
	)
	st.generate_normals()
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, st.commit_to_arrays())
	mesh_inst.mesh = arr_mesh
	mesh_inst.material_override = _pad_mat
	body.add_child(mesh_inst)

	chunk.add_child(body)


func _build_marking(chunk: Node3D, center: Vector3) -> void:
	if _marking_mat == null:
		return
	var node := Node3D.new()
	node.name = "HelipadH"
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var y := MARKING_Y
	var cx := center.x
	var cz := center.z
	# Left vertical bar of H
	_st_quad_flat(
		st,
		cx - H_CROSS_W * 0.5 - H_BAR_W * 0.5,
		y,
		cz,
		H_BAR_W,
		H_BAR_L,
	)
	# Right vertical bar of H
	_st_quad_flat(
		st,
		cx + H_CROSS_W * 0.5 + H_BAR_W * 0.5,
		y,
		cz,
		H_BAR_W,
		H_BAR_L,
	)
	# Horizontal crossbar of H
	_st_quad_flat(
		st,
		cx,
		y,
		cz,
		H_CROSS_W + H_BAR_W,
		H_CROSS_H,
	)
	st.generate_normals()
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.name = "HMarking"
	mesh_inst.mesh = st.commit()
	mesh_inst.material_override = _marking_mat
	node.add_child(mesh_inst)
	chunk.add_child(node)


func _spawn_helicopter(chunk: Node3D, pos: Vector3) -> void:
	var heli: Node3D = _heli_scene.instantiate() as Node3D
	heli.position = pos
	chunk.add_child(heli)


## Flat Y-axis quad (top-face only) at world position (cx, y, cz), sized w×d.
func _st_quad_flat(st: SurfaceTool, cx: float, y: float, cz: float, w: float, d: float) -> void:
	var hw := w * 0.5
	var hd := d * 0.5
	var n := Vector3.UP
	st.set_normal(n)
	st.add_vertex(Vector3(cx - hw, y, cz - hd))
	st.set_normal(n)
	st.add_vertex(Vector3(cx + hw, y, cz - hd))
	st.set_normal(n)
	st.add_vertex(Vector3(cx + hw, y, cz + hd))
	st.set_normal(n)
	st.add_vertex(Vector3(cx - hw, y, cz - hd))
	st.set_normal(n)
	st.add_vertex(Vector3(cx + hw, y, cz + hd))
	st.set_normal(n)
	st.add_vertex(Vector3(cx - hw, y, cz + hd))


func _st_quad(st: SurfaceTool, v0: Vector3, v1: Vector3, v2: Vector3, v3: Vector3) -> void:
	var n: Vector3 = (v1 - v0).cross(v2 - v0).normalized()
	st.set_normal(n)
	st.add_vertex(v0)
	st.set_normal(n)
	st.add_vertex(v1)
	st.set_normal(n)
	st.add_vertex(v2)
	st.set_normal(n)
	st.add_vertex(v0)
	st.set_normal(n)
	st.add_vertex(v2)
	st.set_normal(n)
	st.add_vertex(v3)
