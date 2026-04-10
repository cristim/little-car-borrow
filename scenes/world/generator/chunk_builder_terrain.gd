extends RefCounted
## Builds terrain mesh for non-city chunks using noise-based heightmap.
## One MeshInstance3D with vertex colors + one StaticBody3D with trimesh collision.

const SUBDIVISIONS := 16  # 16x16 grid = 512 triangles per chunk
const SEA_LEVEL := -2.0
const BLEND_CELLS := 3  # blend edge constraints over this many cells

var _noise: FastNoiseLite
var _grid: RefCounted
var _terrain_mat: StandardMaterial3D
var _sea_mat: StandardMaterial3D
var _boundary: RefCounted

# Color palette for height-based vertex coloring
var _color_water := Color(0.15, 0.35, 0.65)
var _color_sand := Color(0.76, 0.70, 0.50)
var _color_grass := Color(0.22, 0.45, 0.18)
var _color_rock := Color(0.45, 0.42, 0.38)
var _color_snow := Color(0.90, 0.90, 0.92)


func init(
	grid: RefCounted,
	noise: FastNoiseLite,
	terrain_mat: StandardMaterial3D,
	boundary: RefCounted = null,
) -> void:
	_grid = grid
	_noise = noise
	_terrain_mat = terrain_mat
	_sea_mat = StandardMaterial3D.new()
	_sea_mat.albedo_color = Color(0.08, 0.25, 0.52, 0.90)
	_sea_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_sea_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_sea_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_boundary = boundary


func build(
	chunk: Node3D,
	_tile: Vector2i,
	ox: float,
	oz: float,
	tile_data: Dictionary = {},
	river_data: Dictionary = {},
) -> Dictionary:
	var span: float = _grid.get_grid_span()
	var step: float = span / float(SUBDIVISIONS)

	# Parse edge height constraints from tile_data
	var edge_heights: Dictionary = _parse_edge_heights(tile_data)

	# Pre-compute river path for terrain carving
	var river_entry := Vector3.ZERO
	var river_exit := Vector3.ZERO
	var river_width := 0.0
	var has_river := not river_data.is_empty()
	if has_river:
		river_entry = _river_edge_point(
			ox,
			oz,
			span * 0.5,
			river_data.get("entry_dir", 0),
			river_data.get("position", 0.5),
		)
		river_exit = _river_edge_point(
			ox,
			oz,
			span * 0.5,
			river_data.get("exit_dir", 2),
			river_data.get("position", 0.5),
		)
		river_width = river_data.get("width", 6.0)

	# Sample heights into a (SUBDIVISIONS+1) x (SUBDIVISIONS+1) grid
	var heights: Array[float] = []
	heights.resize((SUBDIVISIONS + 1) * (SUBDIVISIONS + 1))
	var min_height := INF
	var max_height := -INF

	for iz in range(SUBDIVISIONS + 1):
		for ix in range(SUBDIVISIONS + 1):
			var wx: float = ox - span * 0.5 + float(ix) * step
			var wz: float = oz - span * 0.5 + float(iz) * step
			var h: float = _sample_height(wx, wz)
			h = _apply_edge_constraints(
				h,
				ix,
				iz,
				edge_heights,
			)
			if has_river:
				h = _apply_river_carving(
					h,
					wx,
					wz,
					river_entry,
					river_exit,
					river_width,
				)
			var idx: int = iz * (SUBDIVISIONS + 1) + ix
			heights[idx] = h
			min_height = minf(min_height, h)
			max_height = maxf(max_height, h)

	# Build terrain mesh with vertex colors
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for iz in range(SUBDIVISIONS):
		for ix in range(SUBDIVISIONS):
			var i00: int = iz * (SUBDIVISIONS + 1) + ix
			var i10: int = iz * (SUBDIVISIONS + 1) + ix + 1
			var i01: int = (iz + 1) * (SUBDIVISIONS + 1) + ix
			var i11: int = (iz + 1) * (SUBDIVISIONS + 1) + ix + 1

			var x0: float = ox - span * 0.5 + float(ix) * step
			var x1: float = ox - span * 0.5 + float(ix + 1) * step
			var z0: float = oz - span * 0.5 + float(iz) * step
			var z1: float = oz - span * 0.5 + float(iz + 1) * step

			var v00 := Vector3(x0, heights[i00], z0)
			var v10 := Vector3(x1, heights[i10], z0)
			var v01 := Vector3(x0, heights[i01], z1)
			var v11 := Vector3(x1, heights[i11], z1)

			var c00 := _height_to_color(heights[i00])
			var c10 := _height_to_color(heights[i10])
			var c01 := _height_to_color(heights[i01])
			var c11 := _height_to_color(heights[i11])

			# Triangle 1: v00, v01, v10
			st.set_color(c00)
			st.add_vertex(v00)
			st.set_color(c01)
			st.add_vertex(v01)
			st.set_color(c10)
			st.add_vertex(v10)

			# Triangle 2: v10, v01, v11
			st.set_color(c10)
			st.add_vertex(v10)
			st.set_color(c01)
			st.add_vertex(v01)
			st.set_color(c11)
			st.add_vertex(v11)

	st.generate_normals()
	var mesh := st.commit()

	var mesh_inst := MeshInstance3D.new()
	mesh_inst.name = "TerrainMesh"
	mesh_inst.mesh = mesh
	mesh_inst.material_override = _terrain_mat
	chunk.add_child(mesh_inst)

	# HeightMap collision (reliable for GEVP raycasts and CharacterBody3D)
	var body := StaticBody3D.new()
	body.name = "TerrainBody"
	body.collision_layer = 1  # Ground layer
	body.collision_mask = 0
	body.add_to_group("Road")  # GEVP tire friction
	# Position at chunk center; scale X/Z so each cell = step meters
	body.position = Vector3(ox, 0.0, oz)
	body.scale = Vector3(step, 1.0, step)

	var hmap := HeightMapShape3D.new()
	hmap.map_width = SUBDIVISIONS + 1
	hmap.map_depth = SUBDIVISIONS + 1
	var map_data := PackedFloat32Array()
	map_data.resize((SUBDIVISIONS + 1) * (SUBDIVISIONS + 1))
	for i in range(heights.size()):
		map_data[i] = heights[i]
	hmap.map_data = map_data

	var col := CollisionShape3D.new()
	col.shape = hmap
	body.add_child(col)

	chunk.add_child(body)

	# Sea plane if any part of chunk is below sea level
	if min_height < SEA_LEVEL:
		_build_sea_plane(chunk, ox, oz, span)

	# Store minimap summary data on the chunk node
	chunk.set_meta("terrain_min_height", min_height)
	chunk.set_meta("terrain_max_height", max_height)
	chunk.set_meta("has_water", min_height < SEA_LEVEL)

	# Return actual edge heights for storage in tile cache
	return _extract_edge_heights(heights)


## Extract the actual heights along each edge from the built heightmap.
## Returns { 0: PackedFloat32Array, 1: ..., 2: ..., 3: ... }
func _extract_edge_heights(heights: Array[float]) -> Dictionary:
	var s: int = SUBDIVISIONS + 1
	var result: Dictionary = {}
	# NORTH (iz=0): first row
	var north := PackedFloat32Array()
	north.resize(s)
	for ix in range(s):
		north[ix] = heights[ix]
	result[0] = north
	# SOUTH (iz=SUBDIVISIONS): last row
	var south := PackedFloat32Array()
	south.resize(s)
	for ix in range(s):
		south[ix] = heights[SUBDIVISIONS * s + ix]
	result[2] = south
	# WEST (ix=0): first column
	var west := PackedFloat32Array()
	west.resize(s)
	for iz in range(s):
		west[iz] = heights[iz * s]
	result[3] = west
	# EAST (ix=SUBDIVISIONS): last column
	var east := PackedFloat32Array()
	east.resize(s)
	for iz in range(s):
		east[iz] = heights[iz * s + SUBDIVISIONS]
	result[1] = east
	return result


func _sample_height(wx: float, wz: float) -> float:
	var raw: float = _noise.get_noise_2d(wx, wz)
	var n: float = (raw + 1.0) * 0.5
	var grid_span: float = _grid.get_grid_span()

	var edge_dist: float = _boundary.get_signed_distance(wx, wz)
	if edge_dist < 0.0:
		return 0.0  # inside city

	var fade: float = clampf(edge_dist / (grid_span * 3.0), 0.0, 1.0)
	var max_h: float = lerpf(20.0, 80.0, fade)
	var h: float = n * max_h - 6.0

	# West ocean: terrain descends below sea level westward.
	# Shore slope starts ~2.5 tiles west (just past suburb ring at ~2.26),
	# fully submerged by ~3.5 tiles. 100m depression overwhelms terrain noise.
	var shore_start: float = grid_span * 2.5
	var shore_end: float = grid_span * 3.5
	var in_ocean := -wx > shore_start
	if in_ocean:
		var west_t: float = clampf(
			(-wx - shore_start) / (shore_end - shore_start),
			0.0,
			1.0,
		)
		h -= west_t * west_t * 100.0

	# Non-ocean terrain stays above sea level (no scattered ponds)
	if not in_ocean:
		h = maxf(h, -2.0)

	# Cubic ease-in blend from city ground (y=0) over two tile spans.
	# Keeps terrain nearly flat for the first tile outside the city
	# (where the city-terrain tile boundary falls), then rises gradually.
	# Negative heights allowed for beach slopes and underwater seabed.
	var blend_range: float = grid_span * 2.0
	if edge_dist < blend_range:
		var t: float = edge_dist / blend_range
		t = t * t * t  # cubic — very flat near city
		h = lerpf(0.0, h, t)

	return h


func _height_to_color(h: float) -> Color:
	if h < SEA_LEVEL:
		# Depth gradient: deeper water is darker blue
		var depth_t: float = clampf((SEA_LEVEL - h) / 5.0, 0.0, 1.0)
		var deep := Color(0.08, 0.18, 0.45)
		return deep.lerp(_color_water, 1.0 - depth_t)
	if h < 0.0:
		# Beach: sand to grass between water line and city ground
		var t: float = clampf((h - SEA_LEVEL) / (0.0 - SEA_LEVEL), 0.0, 1.0)
		return _color_sand.lerp(_color_grass, t)
	if h < 30.0:
		var t: float = clampf((h - 20.0) / 10.0, 0.0, 1.0)
		return _color_grass.lerp(_color_rock, t)
	if h < 50.0:
		var t: float = clampf((h - 40.0) / 10.0, 0.0, 1.0)
		return _color_rock.lerp(_color_snow, t)
	return _color_snow


func _build_sea_plane(
	chunk: Node3D,
	ox: float,
	oz: float,
	span: float,
) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var hs := span * 0.5
	var y := SEA_LEVEL
	var v0 := Vector3(ox - hs, y, oz - hs)
	var v1 := Vector3(ox + hs, y, oz - hs)
	var v2 := Vector3(ox + hs, y, oz + hs)
	var v3 := Vector3(ox - hs, y, oz + hs)

	# CCW winding viewed from above (+Y) so normals point up
	st.add_vertex(v0)
	st.add_vertex(v3)
	st.add_vertex(v1)
	st.add_vertex(v1)
	st.add_vertex(v3)
	st.add_vertex(v2)

	st.generate_normals()
	var mesh := st.commit()

	var mesh_inst := MeshInstance3D.new()
	mesh_inst.name = "SeaPlane"
	mesh_inst.mesh = mesh
	# _sea_mat is shared across all sea-plane chunks (created once in init())
	mesh_inst.material_override = _sea_mat
	chunk.add_child(mesh_inst)


## Extract edge height arrays from tile_data edges.
## Returns dict mapping direction -> PackedFloat32Array.
func _parse_edge_heights(tile_data: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var edges: Dictionary = tile_data.get("edges", {})
	for dir: int in edges:
		var edge: Dictionary = edges[dir]
		var h: PackedFloat32Array = (
			edge
			. get(
				"heights",
				PackedFloat32Array(),
			)
		)
		if h.size() > 0:
			result[dir] = h
	return result


## Blend a height sample toward edge constraints when near chunk edges.
## NORTH=0 is iz=0, SOUTH=2 is iz=SUBDIVISIONS,
## WEST=3 is ix=0, EAST=1 is ix=SUBDIVISIONS.
func _apply_edge_constraints(
	h: float,
	ix: int,
	iz: int,
	edge_heights: Dictionary,
) -> float:
	if edge_heights.is_empty():
		return h

	var total_weight := 0.0
	var weighted_target := 0.0

	# NORTH (iz=0)
	if edge_heights.has(0) and iz <= BLEND_CELLS:
		var edge_h: float = _sample_edge_array(edge_heights[0], ix)
		var t: float = 1.0 - float(iz) / float(BLEND_CELLS)
		weighted_target += edge_h * t
		total_weight += t

	# SOUTH (iz=SUBDIVISIONS)
	if edge_heights.has(2) and iz >= SUBDIVISIONS - BLEND_CELLS:
		var edge_h: float = _sample_edge_array(edge_heights[2], ix)
		var dist: int = SUBDIVISIONS - iz
		var t: float = 1.0 - float(dist) / float(BLEND_CELLS)
		weighted_target += edge_h * t
		total_weight += t

	# WEST (ix=0)
	if edge_heights.has(3) and ix <= BLEND_CELLS:
		var edge_h: float = _sample_edge_array(edge_heights[3], iz)
		var t: float = 1.0 - float(ix) / float(BLEND_CELLS)
		weighted_target += edge_h * t
		total_weight += t

	# EAST (ix=SUBDIVISIONS)
	if edge_heights.has(1) and ix >= SUBDIVISIONS - BLEND_CELLS:
		var edge_h: float = _sample_edge_array(edge_heights[1], iz)
		var dist: int = SUBDIVISIONS - ix
		var t: float = 1.0 - float(dist) / float(BLEND_CELLS)
		weighted_target += edge_h * t
		total_weight += t

	if total_weight <= 0.0:
		return h

	weighted_target /= total_weight
	return lerpf(h, weighted_target, clampf(total_weight, 0.0, 1.0))


## Sample a height from an edge array, mapping grid index to edge sample.
func _sample_edge_array(
	edge_arr: PackedFloat32Array,
	grid_idx: int,
) -> float:
	var t: float = float(grid_idx) / float(SUBDIVISIONS)
	var fi: float = t * float(edge_arr.size() - 1)
	var i0: int = int(fi)
	var i1: int = mini(i0 + 1, edge_arr.size() - 1)
	var frac: float = fi - float(i0)
	return lerpf(edge_arr[i0], edge_arr[i1], frac)


## Depress terrain height along the river path.
func _apply_river_carving(
	h: float,
	wx: float,
	wz: float,
	entry: Vector3,
	exit_pt: Vector3,
	width: float,
) -> float:
	var river_dir := exit_pt - entry
	var len_sq: float = river_dir.length_squared()
	if len_sq < 0.01:
		return h
	var to_point := Vector3(wx, 0.0, wz) - entry
	var t: float = clampf(to_point.dot(river_dir) / len_sq, 0.0, 1.0)
	var closest := entry + river_dir * t
	var dist: float = (
		Vector2(
			wx - closest.x,
			wz - closest.z,
		)
		. length()
	)
	var half_w: float = width * 0.5
	if dist > half_w + 3.0:
		return h
	# Inside river channel: depress to river bed
	if dist <= half_w:
		return h - 2.0
	# Bank slope: blend between terrain and river bed
	var bank_t: float = (dist - half_w) / 3.0
	return lerpf(h - 2.0, h, bank_t)


## Compute a world point on the chunk edge for a river direction.
func _river_edge_point(
	ox: float,
	oz: float,
	hs: float,
	dir: int,
	pos: float,
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
