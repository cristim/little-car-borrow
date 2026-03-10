extends RefCounted
## Builds river channels through terrain chunks.
## Water plane + carved banks from entry to exit edge.

const SEA_LEVEL := -2.0
const RIVER_DEPTH := 2.0
const BANK_SLOPE_WIDTH := 3.0
const SUBDIVISIONS := 8

var _grid: RefCounted
var _boundary: RefCounted
var _water_mat: StandardMaterial3D


func init(grid: RefCounted, boundary: RefCounted) -> void:
	_grid = grid
	_boundary = boundary
	_water_mat = StandardMaterial3D.new()
	_water_mat.albedo_color = Color(0.1, 0.3, 0.6, 0.55)
	_water_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_water_mat.cull_mode = BaseMaterial3D.CULL_DISABLED


func build(
	chunk: Node3D, _tile: Vector2i, ox: float, oz: float,
	river_data: Dictionary,
) -> void:
	if river_data.is_empty():
		return

	var entry_dir: int = river_data.get("entry_dir", 0)
	var exit_dir: int = river_data.get("exit_dir", 2)
	var width: float = river_data.get("width", 6.0)
	var pos: float = river_data.get("position", 0.5)

	var span: float = _grid.get_grid_span()
	var hs: float = span * 0.5

	# Compute entry and exit world points on chunk edges
	var entry_pt := _edge_point(ox, oz, hs, entry_dir, pos)
	var exit_pt := _edge_point(ox, oz, hs, exit_dir, pos)

	# Build water plane along the river path
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for i in range(SUBDIVISIONS):
		var t0: float = float(i) / float(SUBDIVISIONS)
		var t1: float = float(i + 1) / float(SUBDIVISIONS)
		var p0: Vector3 = entry_pt.lerp(exit_pt, t0)
		var p1: Vector3 = entry_pt.lerp(exit_pt, t1)

		# Water surface height follows terrain minus depth
		var h0: float = _boundary.get_ground_height(p0.x, p0.z)
		var h1: float = _boundary.get_ground_height(p1.x, p1.z)
		var wy0: float = h0 - RIVER_DEPTH * 0.5
		var wy1: float = h1 - RIVER_DEPTH * 0.5

		# Perpendicular direction for width
		var dir := (exit_pt - entry_pt).normalized()
		var perp := Vector3(-dir.z, 0.0, dir.x) * width * 0.5

		var v0 := Vector3(p0.x - perp.x, wy0, p0.z - perp.z)
		var v1 := Vector3(p0.x + perp.x, wy0, p0.z + perp.z)
		var v2 := Vector3(p1.x + perp.x, wy1, p1.z + perp.z)
		var v3 := Vector3(p1.x - perp.x, wy1, p1.z - perp.z)

		# Two triangles
		st.add_vertex(v0)
		st.add_vertex(v3)
		st.add_vertex(v1)
		st.add_vertex(v1)
		st.add_vertex(v3)
		st.add_vertex(v2)

	st.generate_normals()
	var mesh := st.commit()
	var inst := MeshInstance3D.new()
	inst.name = "River"
	inst.mesh = mesh
	inst.material_override = _water_mat
	chunk.add_child(inst)


func _edge_point(
	ox: float, oz: float, hs: float,
	dir: int, pos: float,
) -> Vector3:
	var offset: float = (pos - 0.5) * hs * 2.0
	match dir:
		0:  # NORTH -Z
			return Vector3(ox + offset, 0.0, oz - hs)
		1:  # EAST +X
			return Vector3(ox + hs, 0.0, oz + offset)
		2:  # SOUTH +Z
			return Vector3(ox + offset, 0.0, oz + hs)
		3:  # WEST -X
			return Vector3(ox - hs, 0.0, oz + offset)
	return Vector3(ox, 0.0, oz)
