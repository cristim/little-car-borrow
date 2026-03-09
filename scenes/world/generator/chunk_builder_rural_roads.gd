extends RefCounted
## Builds dark asphalt highway strips on terrain chunks along road grid
## indices 0 and 5 (tile boundaries and centers). Roads follow terrain
## height and skip underwater segments.

const SUBDIVISIONS := 16
const SEA_LEVEL := -2.0
const ROAD_Y_OFFSET := 0.15
const HIGHWAY_INDICES := [0, 5]

var _grid: RefCounted
var _road_mat: StandardMaterial3D
var _boundary: RefCounted


func init(
	grid: RefCounted,
	road_mat: StandardMaterial3D,
	boundary: RefCounted,
) -> void:
	_grid = grid
	_road_mat = road_mat
	_boundary = boundary


func build(
	chunk: Node3D, _tile: Vector2i, ox: float, oz: float,
) -> void:
	var span: float = _grid.get_grid_span()
	var step: float = span / float(SUBDIVISIONS)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var has_verts := false

	for hi in HIGHWAY_INDICES:
		var rw: float = _grid.get_road_width(hi)
		var hw: float = rw * 0.5

		# N-S road strip
		var road_cx: float = _grid.get_road_center_local(hi) + ox
		for iz in range(SUBDIVISIONS):
			var z0: float = oz - span * 0.5 + float(iz) * step
			var z1: float = z0 + step
			var h0: float = _boundary.get_ground_height(road_cx, z0)
			var h1: float = _boundary.get_ground_height(road_cx, z1)
			if h0 < SEA_LEVEL or h1 < SEA_LEVEL:
				continue
			h0 += ROAD_Y_OFFSET
			h1 += ROAD_Y_OFFSET
			_add_quad(
				st,
				Vector3(road_cx - hw, h0, z0),
				Vector3(road_cx + hw, h0, z0),
				Vector3(road_cx + hw, h1, z1),
				Vector3(road_cx - hw, h1, z1),
			)
			has_verts = true

		# E-W road strip
		var road_cz: float = _grid.get_road_center_local(hi) + oz
		for ix in range(SUBDIVISIONS):
			var x0: float = ox - span * 0.5 + float(ix) * step
			var x1: float = x0 + step
			var h0: float = _boundary.get_ground_height(x0, road_cz)
			var h1: float = _boundary.get_ground_height(x1, road_cz)
			if h0 < SEA_LEVEL or h1 < SEA_LEVEL:
				continue
			h0 += ROAD_Y_OFFSET
			h1 += ROAD_Y_OFFSET
			_add_quad(
				st,
				Vector3(x0, h0, road_cz - hw),
				Vector3(x0, h0, road_cz + hw),
				Vector3(x1, h1, road_cz + hw),
				Vector3(x1, h1, road_cz - hw),
			)
			has_verts = true

	if not has_verts:
		return

	st.generate_normals()
	var mesh := st.commit()
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.name = "RuralRoads"
	mesh_inst.mesh = mesh
	mesh_inst.material_override = _road_mat
	chunk.add_child(mesh_inst)


func _add_quad(
	st: SurfaceTool,
	v0: Vector3, v1: Vector3, v2: Vector3, v3: Vector3,
) -> void:
	# Two triangles: v0-v3-v1 and v1-v3-v2 (CCW from above)
	st.add_vertex(v0)
	st.add_vertex(v3)
	st.add_vertex(v1)
	st.add_vertex(v1)
	st.add_vertex(v3)
	st.add_vertex(v2)
