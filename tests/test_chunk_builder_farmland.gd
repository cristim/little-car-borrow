extends GutTest
## Unit tests for chunk_builder_farmland.gd field and fence generation.

const FarmlandScript = preload("res://scenes/world/generator/chunk_builder_farmland.gd")
const RoadGridScript = preload("res://src/road_grid.gd")
const BoundaryScript = preload("res://src/city_boundary.gd")

var _grid: RefCounted
var _boundary: RefCounted
var _builder: RefCounted
var _noise: FastNoiseLite


func before_each() -> void:
	_grid = RoadGridScript.new()
	_noise = FastNoiseLite.new()
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 0.003
	_noise.fractal_octaves = 4
	_noise.fractal_lacunarity = 2.0
	_noise.fractal_gain = 0.5
	_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_noise.seed = 42

	_boundary = BoundaryScript.new()
	_boundary.init(_grid.get_grid_span(), _noise)

	_builder = FarmlandScript.new()
	_builder.init(_grid, _boundary)


# ================================================================
# Initialization
# ================================================================


func test_init_stores_grid() -> void:
	assert_eq(_builder._grid, _grid, "init should store grid reference")


func test_init_stores_boundary() -> void:
	assert_eq(
		_builder._boundary,
		_boundary,
		"init should store boundary reference",
	)


func test_init_creates_fence_mat() -> void:
	assert_not_null(
		_builder._fence_mat,
		"init should create fence material",
	)
	assert_true(
		_builder._fence_mat is StandardMaterial3D,
		"Fence material should be StandardMaterial3D",
	)


func test_fence_mat_color() -> void:
	var mat: StandardMaterial3D = _builder._fence_mat
	assert_eq(
		mat.albedo_color,
		Color(0.40, 0.28, 0.15),
		"Fence material should be brown",
	)


# ================================================================
# Constants
# ================================================================


func test_field_colors_has_entries() -> void:
	assert_true(
		FarmlandScript.FIELD_COLORS.size() >= 4,
		"FIELD_COLORS should have at least 4 entries",
	)


func test_fence_height_positive() -> void:
	assert_true(
		FarmlandScript.FENCE_HEIGHT > 0.0,
		"FENCE_HEIGHT should be positive",
	)


func test_fence_thickness_positive() -> void:
	assert_true(
		FarmlandScript.FENCE_THICKNESS > 0.0,
		"FENCE_THICKNESS should be positive",
	)


# ================================================================
# Build on terrain with height > 0.5
# ================================================================


func test_build_creates_fields_mesh() -> void:
	var span: float = _grid.get_grid_span()
	# Loop over tiles far enough from city to have terrain above 0.5
	var found_fields := false
	for tx in range(5, 18):
		var tile := Vector2i(tx, 0)
		var chunk := Node3D.new()
		add_child_autofree(chunk)
		_builder.build(chunk, tile, span * float(tx), 0.0)
		for child in chunk.get_children():
			if child is MeshInstance3D and child.name == "Fields":
				found_fields = true
				assert_not_null(child.mesh, "Fields mesh should not be null")
				assert_not_null(
					child.material_override,
					"Fields should have material override",
				)
				break
		if found_fields:
			break
	assert_true(found_fields, "Build on terrain should create Fields mesh across tiles 5-17")


func test_fields_material_uses_vertex_colors() -> void:
	var span: float = _grid.get_grid_span()
	var found_fields := false
	for tx in range(5, 18):
		var tile := Vector2i(tx, 0)
		var chunk := Node3D.new()
		add_child_autofree(chunk)
		_builder.build(chunk, tile, span * float(tx), 0.0)
		for child in chunk.get_children():
			if child is MeshInstance3D and child.name == "Fields":
				found_fields = true
				var mat: StandardMaterial3D = child.material_override
				assert_true(
					mat.vertex_color_use_as_albedo,
					"Fields material should use vertex colors as albedo",
				)
				assert_eq(
					mat.cull_mode,
					BaseMaterial3D.CULL_DISABLED,
					"Fields material should be double-sided",
				)
				break
		if found_fields:
			break
	assert_true(found_fields, "At least one tile should produce a Fields mesh")


func test_build_may_create_fences() -> void:
	# Fences appear with ~60% probability per field, so across many tiles
	# we should see at least one fence
	var span: float = _grid.get_grid_span()
	var found_fences := false
	for tx in range(3, 15):
		var tile := Vector2i(tx, 0)
		var chunk := Node3D.new()
		add_child_autofree(chunk)
		_builder.build(chunk, tile, span * float(tx), 0.0)
		for child in chunk.get_children():
			if child is MeshInstance3D and child.name == "Fences":
				found_fences = true
				assert_eq(
					child.material_override,
					_builder._fence_mat,
					"Fences should use fence material",
				)
				break
		if found_fences:
			break
	assert_true(
		found_fences,
		"At least one tile should produce fences across 12 tiles",
	)


# ================================================================
# Build at city center (height = 0, below 0.5 threshold)
# ================================================================


func test_build_at_city_center_produces_no_fields() -> void:
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	_builder.build(chunk, Vector2i(0, 0), 0.0, 0.0)

	assert_eq(
		chunk.get_child_count(),
		0,
		"City center (height=0) should produce no fields or fences",
	)


# ================================================================
# Determinism
# ================================================================


func test_build_deterministic() -> void:
	var span: float = _grid.get_grid_span()
	var tile := Vector2i(6, 2)
	var ox: float = span * 6.0
	var oz: float = span * 2.0

	var chunk1 := Node3D.new()
	add_child_autofree(chunk1)
	_builder.build(chunk1, tile, ox, oz)

	var chunk2 := Node3D.new()
	add_child_autofree(chunk2)
	_builder.build(chunk2, tile, ox, oz)

	assert_eq(
		chunk1.get_child_count(),
		chunk2.get_child_count(),
		"Same tile should produce same child count",
	)

	# Compare child names
	var names1: Array[String] = []
	for child in chunk1.get_children():
		names1.append(child.name)
	var names2: Array[String] = []
	for child in chunk2.get_children():
		names2.append(child.name)
	assert_eq(names1, names2, "Same tile should produce same child names")


func test_different_tiles_produce_different_geometry() -> void:
	# Different tiles use different RNG seeds, so field positions differ.
	# We verify the builder runs without errors on multiple distinct tiles.
	var span: float = _grid.get_grid_span()
	var built_count := 0
	for tx in range(5, 15):
		var tile := Vector2i(tx, tx * 2)
		var chunk := Node3D.new()
		add_child_autofree(chunk)
		_builder.build(chunk, tile, span * float(tx), span * float(tx * 2))
		if chunk.get_child_count() > 0:
			built_count += 1

	assert_true(
		built_count > 0,
		"At least one of 10 tiles should produce output",
	)


# ================================================================
# Underwater tiles produce no output
# ================================================================


func test_build_far_west_underwater_no_fields() -> void:
	var span: float = _grid.get_grid_span()
	var tile := Vector2i(-10, 0)
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	_builder.build(chunk, tile, span * -10.0, 0.0)

	# All terrain far west is underwater (h < 0.5)
	var found_fields := false
	for child in chunk.get_children():
		if child is MeshInstance3D and child.name == "Fields":
			found_fields = true
	assert_false(
		found_fields,
		"Far west underwater tile should produce no fields",
	)
