extends GutTest
## Unit tests for chunk_builder_mountain.gd rock placement on elevated terrain.

const MountainScript = preload(
	"res://scenes/world/generator/chunk_builder_mountain.gd"
)
const RoadGridScript = preload("res://src/road_grid.gd")
const BoundaryScript = preload("res://src/city_boundary.gd")


var _grid: RefCounted
var _noise: FastNoiseLite
var _boundary: RefCounted
var _builder: RefCounted


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

	_builder = MountainScript.new()
	_builder.init(_grid, _boundary)


# ================================================================
# Initialization
# ================================================================

func test_init_sets_grid() -> void:
	assert_not_null(_builder._grid, "init should set _grid")


func test_init_sets_boundary() -> void:
	assert_not_null(_builder._boundary, "init should set _boundary")


func test_init_creates_rock_material() -> void:
	assert_not_null(_builder._rock_mat, "init should create rock material")


func test_rock_material_color() -> void:
	var c: Color = _builder._rock_mat.albedo_color
	assert_almost_eq(c.r, 0.50, 0.01, "Rock red channel should be ~0.50")
	assert_almost_eq(c.g, 0.48, 0.01, "Rock green channel should be ~0.48")
	assert_almost_eq(c.b, 0.44, 0.01, "Rock blue channel should be ~0.44")


func test_rock_material_roughness() -> void:
	assert_almost_eq(
		_builder._rock_mat.roughness, 0.95, 0.01,
		"Rock roughness should be 0.95",
	)


# ================================================================
# Build on city tile (flat, height 0 - no rocks expected)
# ================================================================

func test_build_no_rocks_on_flat_tile() -> void:
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	# Tile (0,0) is inside the city where ground height is 0
	_builder.build(chunk, Vector2i(0, 0), 0.0, 0.0)

	var child_count := chunk.get_child_count()
	assert_eq(
		child_count, 0,
		"Flat tile (h=0) should produce no rock children",
	)


func test_build_no_rocks_on_low_terrain() -> void:
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	var span: float = _grid.get_grid_span()
	_builder.build(chunk, Vector2i(1, 0), span, 0.0)

	var found_rocks := false
	for child in chunk.get_children():
		if child is MeshInstance3D and child.name == "Rocks":
			found_rocks = true
	assert_false(
		found_rocks,
		"Low-terrain tile should not produce Rocks mesh",
	)


# ================================================================
# Build on elevated tile (rocks expected if height >= 15)
# ================================================================

func test_build_creates_rocks_on_elevated_tile() -> void:
	var span: float = _grid.get_grid_span()
	var found_rocks := false
	for tx in range(4, 15):
		for tz in [-3, 0, 3]:
			var chunk := Node3D.new()
			add_child_autofree(chunk)
			var tile := Vector2i(tx, tz)
			_builder.build(
				chunk, tile, span * float(tx), span * float(tz),
			)
			for child in chunk.get_children():
				if child is MeshInstance3D and child.name == "Rocks":
					found_rocks = true
					break
			if found_rocks:
				break
		if found_rocks:
			break

	assert_true(
		found_rocks,
		"At least one tile should produce Rocks mesh on elevated terrain",
	)


func test_build_creates_collision_body_with_rocks() -> void:
	var span: float = _grid.get_grid_span()
	var found_body := false
	for tx in range(4, 15):
		for tz in [-3, 0, 3]:
			var chunk := Node3D.new()
			add_child_autofree(chunk)
			var tile := Vector2i(tx, tz)
			_builder.build(
				chunk, tile, span * float(tx), span * float(tz),
			)
			for child in chunk.get_children():
				if child is StaticBody3D and child.name == "RockBodies":
					found_body = true
					break
			if found_body:
				break
		if found_body:
			break

	assert_true(
		found_body,
		"Elevated tile should create RockBodies StaticBody3D",
	)


func test_rock_body_collision_layer() -> void:
	var span: float = _grid.get_grid_span()
	for tx in range(4, 15):
		for tz in [-3, 0, 3]:
			var chunk := Node3D.new()
			add_child_autofree(chunk)
			var tile := Vector2i(tx, tz)
			_builder.build(
				chunk, tile, span * float(tx), span * float(tz),
			)
			for child in chunk.get_children():
				if child is StaticBody3D and child.name == "RockBodies":
					assert_eq(
						child.collision_layer, 2,
						"RockBodies collision_layer should be 2 (Static)",
					)
					assert_eq(
						child.collision_mask, 0,
						"RockBodies collision_mask should be 0",
					)
					return

	pass_test("No elevated tile found in range")


func test_rock_body_in_static_group() -> void:
	var span: float = _grid.get_grid_span()
	for tx in range(4, 15):
		for tz in [-3, 0, 3]:
			var chunk := Node3D.new()
			add_child_autofree(chunk)
			var tile := Vector2i(tx, tz)
			_builder.build(
				chunk, tile, span * float(tx), span * float(tz),
			)
			for child in chunk.get_children():
				if child is StaticBody3D and child.name == "RockBodies":
					assert_true(
						child.is_in_group("Static"),
						"RockBodies should be in Static group",
					)
					return

	pass_test("No elevated tile found in range")


func test_rocks_mesh_has_material_override() -> void:
	var span: float = _grid.get_grid_span()
	for tx in range(4, 15):
		for tz in [-3, 0, 3]:
			var chunk := Node3D.new()
			add_child_autofree(chunk)
			var tile := Vector2i(tx, tz)
			_builder.build(
				chunk, tile, span * float(tx), span * float(tz),
			)
			for child in chunk.get_children():
				if child is MeshInstance3D and child.name == "Rocks":
					assert_eq(
						child.material_override, _builder._rock_mat,
						"Rocks mesh should use the rock material",
					)
					return

	pass_test("No elevated tile found in range")


# ================================================================
# Determinism
# ================================================================

func test_build_deterministic_same_tile() -> void:
	var span: float = _grid.get_grid_span()
	var tile := Vector2i(8, 2)
	var ox: float = span * 8.0
	var oz: float = span * 2.0

	var chunk1 := Node3D.new()
	add_child_autofree(chunk1)
	_builder.build(chunk1, tile, ox, oz)

	var chunk2 := Node3D.new()
	add_child_autofree(chunk2)
	_builder.build(chunk2, tile, ox, oz)

	assert_eq(
		chunk1.get_child_count(), chunk2.get_child_count(),
		"Same tile should produce same number of children",
	)


func test_build_different_tiles_may_differ() -> void:
	var span: float = _grid.get_grid_span()

	var chunk_a := Node3D.new()
	add_child_autofree(chunk_a)
	_builder.build(chunk_a, Vector2i(6, 0), span * 6.0, 0.0)

	var chunk_b := Node3D.new()
	add_child_autofree(chunk_b)
	_builder.build(chunk_b, Vector2i(7, 1), span * 7.0, span)

	pass_test("Different tiles build without error")
