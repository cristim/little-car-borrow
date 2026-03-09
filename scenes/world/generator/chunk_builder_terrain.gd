extends RefCounted
## Builds terrain mesh for non-city chunks using noise-based heightmap.
## One MeshInstance3D with vertex colors + one StaticBody3D with trimesh collision.

const SUBDIVISIONS := 16  # 16x16 grid = 512 triangles per chunk
const SEA_LEVEL := -2.0

var _noise: FastNoiseLite
var _grid: RefCounted
var _terrain_mat: StandardMaterial3D
var _boundary: RefCounted
var _boat_mat: StandardMaterial3D

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
	_boundary = boundary


func build(chunk: Node3D, tile: Vector2i, ox: float, oz: float) -> void:
	var span: float = _grid.get_grid_span()
	var step: float = span / float(SUBDIVISIONS)

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
		_build_boats(chunk, tile, ox, oz, span)

	# Store minimap summary data on the chunk node
	chunk.set_meta("terrain_min_height", min_height)
	chunk.set_meta("terrain_max_height", max_height)
	chunk.set_meta("has_water", min_height < SEA_LEVEL)


func _sample_height(wx: float, wz: float) -> float:
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
	var h: float = n * max_h - 6.0

	# West ocean: terrain descends below sea level westward
	var west_t: float = clampf(-wx / (grid_span * 3.0), 0.0, 1.0)
	h -= west_t * west_t * 20.0

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
	chunk: Node3D, ox: float, oz: float, span: float,
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

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.1, 0.3, 0.6, 0.55)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL

	var mesh_inst := MeshInstance3D.new()
	mesh_inst.name = "SeaPlane"
	mesh_inst.mesh = mesh
	mesh_inst.material_override = mat
	chunk.add_child(mesh_inst)


func _build_boats(
	chunk: Node3D, tile: Vector2i,
	ox: float, oz: float, span: float,
) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(tile) ^ 0xF15F

	var count := rng.randi_range(0, 3)
	if count == 0:
		return

	if not _boat_mat:
		_boat_mat = StandardMaterial3D.new()
		_boat_mat.albedo_color = Color(0.45, 0.30, 0.15)

	for _i in range(count):
		var bx: float = ox + rng.randf_range(
			-span * 0.4, span * 0.4
		)
		var bz: float = oz + rng.randf_range(
			-span * 0.4, span * 0.4
		)
		var h: float = _sample_height(bx, bz)
		if h >= SEA_LEVEL:
			continue

		var boat := MeshInstance3D.new()
		boat.name = "Boat"
		var box := BoxMesh.new()
		box.size = Vector3(
			rng.randf_range(2.0, 4.0),
			0.6,
			rng.randf_range(4.0, 8.0),
		)
		boat.mesh = box
		boat.material_override = _boat_mat
		boat.position = Vector3(bx, SEA_LEVEL + 0.1, bz)
		boat.rotation.y = rng.randf() * TAU
		chunk.add_child(boat)
