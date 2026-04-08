extends RefCounted
## Builds dark asphalt highway strips on terrain chunks.
## Reads road positions from tile edge profiles when available,
## falls back to fixed highway grid indices 0 and 5.
## Roads follow terrain height and skip underwater segments.

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
	chunk: Node3D,
	_tile: Vector2i,
	ox: float,
	oz: float,
	tile_data: Dictionary = {},
) -> void:
	var span: float = _grid.get_grid_span()
	var step: float = span / float(SUBDIVISIONS)

	# Collect road positions: N-S roads from N/S edges, E-W from E/W edges
	var ns_roads: Array = _collect_roads(tile_data, 0, 2)
	var ew_roads: Array = _collect_roads(tile_data, 3, 1)

	# Fallback to fixed highway positions if no edge data
	if ns_roads.is_empty() and ew_roads.is_empty():
		for hi in HIGHWAY_INDICES:
			var center: float = _grid.get_road_center_local(hi)
			var width: float = _grid.get_road_width(hi)
			var pos: float = (center + span * 0.5) / span
			ns_roads.append({"position": pos, "width": width})
			ew_roads.append({"position": pos, "width": width})

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var has_verts := false

	# N-S road strips
	for road: Dictionary in ns_roads:
		var pos: float = road.get("position", 0.5)
		var rw: float = road.get("width", 8.0)
		var hw: float = rw * 0.5
		var road_cx: float = ox - span * 0.5 + pos * span
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

	# E-W road strips
	for road: Dictionary in ew_roads:
		var pos: float = road.get("position", 0.5)
		var rw: float = road.get("width", 8.0)
		var hw: float = rw * 0.5
		var road_cz: float = oz - span * 0.5 + pos * span
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

	# Road collision for vehicle physics
	var body := StaticBody3D.new()
	body.name = "RuralRoadBody"
	body.collision_layer = 1  # Ground layer
	body.collision_mask = 0
	body.add_to_group("Road")

	# Per-segment collision boxes that follow terrain slope
	for road: Dictionary in ns_roads:
		var pos: float = road.get("position", 0.5)
		var rw: float = road.get("width", 8.0)
		var road_cx: float = ox - span * 0.5 + pos * span
		for iz in range(SUBDIVISIONS):
			var z0: float = oz - span * 0.5 + float(iz) * step
			var z1: float = z0 + step
			var h0: float = _boundary.get_ground_height(road_cx, z0)
			var h1: float = _boundary.get_ground_height(road_cx, z1)
			if h0 < SEA_LEVEL or h1 < SEA_LEVEL:
				continue
			var avg_h: float = (h0 + h1) * 0.5 + ROAD_Y_OFFSET
			var col := CollisionShape3D.new()
			var shape := BoxShape3D.new()
			shape.size = Vector3(rw, 0.3, step)
			col.shape = shape
			col.position = Vector3(road_cx, avg_h, (z0 + z1) * 0.5)
			body.add_child(col)

	for road: Dictionary in ew_roads:
		var pos: float = road.get("position", 0.5)
		var rw: float = road.get("width", 8.0)
		var road_cz: float = oz - span * 0.5 + pos * span
		for ix in range(SUBDIVISIONS):
			var x0: float = ox - span * 0.5 + float(ix) * step
			var x1: float = x0 + step
			var h0: float = _boundary.get_ground_height(x0, road_cz)
			var h1: float = _boundary.get_ground_height(x1, road_cz)
			if h0 < SEA_LEVEL or h1 < SEA_LEVEL:
				continue
			var avg_h: float = (h0 + h1) * 0.5 + ROAD_Y_OFFSET
			var col := CollisionShape3D.new()
			var shape := BoxShape3D.new()
			shape.size = Vector3(step, 0.3, rw)
			col.shape = shape
			col.position = Vector3((x0 + x1) * 0.5, avg_h, road_cz)
			body.add_child(col)

	if body.get_child_count() > 0:
		chunk.add_child(body)
	else:
		body.queue_free()


## Collect unique road positions from two facing edges.
func _collect_roads(
	tile_data: Dictionary,
	dir_a: int,
	dir_b: int,
) -> Array:
	var edges: Dictionary = tile_data.get("edges", {})
	var seen: Dictionary = {}
	var result: Array = []
	for dir: int in [dir_a, dir_b]:
		if not edges.has(dir):
			continue
		var edge: Dictionary = edges[dir]
		var roads: Array = edge.get("roads", [])
		for road: Dictionary in roads:
			var pos: float = road.get("position", 0.5)
			var key: int = int(pos * 1000.0)
			if not seen.has(key):
				seen[key] = true
				result.append(road)
	return result


func _add_quad(
	st: SurfaceTool,
	v0: Vector3,
	v1: Vector3,
	v2: Vector3,
	v3: Vector3,
) -> void:
	# Two triangles: v0-v3-v1 and v1-v3-v2 (CCW from above)
	st.add_vertex(v0)
	st.add_vertex(v3)
	st.add_vertex(v1)
	st.add_vertex(v1)
	st.add_vertex(v3)
	st.add_vertex(v2)
