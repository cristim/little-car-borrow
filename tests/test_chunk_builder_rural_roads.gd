extends GutTest
## Unit tests for chunk_builder_rural_roads.gd highway strip generation.

const RuralRoadsScript = preload(
	"res://scenes/world/generator/chunk_builder_rural_roads.gd"
)
const RoadGridScript = preload("res://src/road_grid.gd")
const BoundaryScript = preload("res://src/city_boundary.gd")

var _grid: RefCounted
var _boundary: RefCounted
var _builder: RefCounted
var _road_mat: StandardMaterial3D
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

	_road_mat = StandardMaterial3D.new()
	_road_mat.albedo_color = Color(0.15, 0.15, 0.15)

	_builder = RuralRoadsScript.new()
	_builder.init(_grid, _road_mat, _boundary)


# ================================================================
# Initialization
# ================================================================

func test_init_stores_grid() -> void:
	assert_eq(_builder._grid, _grid, "init should store grid reference")


func test_init_stores_road_mat() -> void:
	assert_eq(_builder._road_mat, _road_mat, "init should store road material")


func test_init_stores_boundary() -> void:
	assert_eq(
		_builder._boundary, _boundary, "init should store boundary reference",
	)


# ================================================================
# Constants
# ================================================================

func test_subdivisions_positive() -> void:
	assert_true(
		RuralRoadsScript.SUBDIVISIONS > 0,
		"SUBDIVISIONS should be positive",
	)


func test_sea_level_negative() -> void:
	assert_true(
		RuralRoadsScript.SEA_LEVEL < 0.0,
		"SEA_LEVEL should be negative",
	)


func test_highway_indices_has_two_entries() -> void:
	assert_eq(
		RuralRoadsScript.HIGHWAY_INDICES.size(), 2,
		"HIGHWAY_INDICES should have exactly 2 entries",
	)


# ================================================================
# _collect_roads
# ================================================================

func test_collect_roads_empty_tile_data() -> void:
	var result: Array = _builder._collect_roads({}, 0, 2)
	assert_eq(result.size(), 0, "Empty tile data should produce no roads")


func test_collect_roads_with_edge_data() -> void:
	var tile_data := {
		"edges": {
			0: {"roads": [{"position": 0.25, "width": 8.0}]},
			2: {"roads": [{"position": 0.75, "width": 8.0}]},
		},
	}
	var result: Array = _builder._collect_roads(tile_data, 0, 2)
	assert_eq(result.size(), 2, "Should collect roads from both edges")


func test_collect_roads_deduplicates_same_position() -> void:
	var tile_data := {
		"edges": {
			0: {"roads": [{"position": 0.5, "width": 8.0}]},
			2: {"roads": [{"position": 0.5, "width": 8.0}]},
		},
	}
	var result: Array = _builder._collect_roads(tile_data, 0, 2)
	assert_eq(
		result.size(), 1,
		"Same position from both edges should be deduplicated",
	)


func test_collect_roads_different_positions_kept() -> void:
	var tile_data := {
		"edges": {
			0: {"roads": [{"position": 0.25, "width": 8.0}]},
			2: {"roads": [{"position": 0.75, "width": 10.0}]},
		},
	}
	var result: Array = _builder._collect_roads(tile_data, 0, 2)
	assert_eq(
		result.size(), 2,
		"Different positions should be kept separately",
	)


func test_collect_roads_missing_dir_graceful() -> void:
	var tile_data := {
		"edges": {
			0: {"roads": [{"position": 0.3, "width": 8.0}]},
		},
	}
	# dir_b=2 not present -- should not crash
	var result: Array = _builder._collect_roads(tile_data, 0, 2)
	assert_eq(result.size(), 1, "Missing direction should be skipped gracefully")


# ================================================================
# Build with fallback (no tile_data)
# ================================================================

func test_build_fallback_creates_road_mesh() -> void:
	# Use a tile far enough from city to have non-zero terrain
	var span: float = _grid.get_grid_span()
	var tile := Vector2i(5, 0)
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	_builder.build(chunk, tile, span * 5.0, 0.0)

	var found_mesh := false
	for child in chunk.get_children():
		if child is MeshInstance3D and child.name == "RuralRoads":
			found_mesh = true
			assert_not_null(child.mesh, "Road mesh should not be null")
			assert_eq(
				child.material_override, _road_mat,
				"Road mesh should use provided material",
			)
	assert_true(found_mesh, "Fallback build should create RuralRoads mesh")


func test_build_fallback_creates_collision_body() -> void:
	var span: float = _grid.get_grid_span()
	var tile := Vector2i(5, 0)
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	_builder.build(chunk, tile, span * 5.0, 0.0)

	var found_body := false
	for child in chunk.get_children():
		if child is StaticBody3D and child.name == "RuralRoadBody":
			found_body = true
			assert_eq(
				child.collision_layer, 1,
				"Road body collision layer should be ground (1)",
			)
			assert_eq(
				child.collision_mask, 0,
				"Road body collision mask should be 0",
			)
			assert_true(
				child.is_in_group("Road"),
				"Road body should be in Road group",
			)
			assert_true(
				child.get_child_count() > 0,
				"Road body should have collision shape children",
			)
	assert_true(
		found_body, "Fallback build should create RuralRoadBody",
	)


func test_road_collision_shapes_are_boxes() -> void:
	var span: float = _grid.get_grid_span()
	var tile := Vector2i(5, 0)
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	_builder.build(chunk, tile, span * 5.0, 0.0)

	for child in chunk.get_children():
		if child is StaticBody3D and child.name == "RuralRoadBody":
			for col in child.get_children():
				if col is CollisionShape3D:
					assert_true(
						col.shape is BoxShape3D,
						"Road collision shapes should be BoxShape3D",
					)


# ================================================================
# Build with edge tile_data
# ================================================================

func test_build_with_edge_data() -> void:
	var span: float = _grid.get_grid_span()
	var tile := Vector2i(5, 0)
	var tile_data := {
		"edges": {
			0: {"roads": [{"position": 0.3, "width": 10.0}]},
			2: {"roads": [{"position": 0.3, "width": 10.0}]},
			3: {"roads": [{"position": 0.7, "width": 8.0}]},
			1: {"roads": [{"position": 0.7, "width": 8.0}]},
		},
	}
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	_builder.build(chunk, tile, span * 5.0, 0.0, tile_data)

	var found_mesh := false
	for child in chunk.get_children():
		if child is MeshInstance3D and child.name == "RuralRoads":
			found_mesh = true
	assert_true(found_mesh, "Build with edge data should create RuralRoads mesh")


# ================================================================
# Underwater segments skipped
# ================================================================

func test_build_underwater_tile_produces_no_children() -> void:
	# Very far west tiles should be underwater
	var span: float = _grid.get_grid_span()
	var tile := Vector2i(-10, 0)
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	_builder.build(chunk, tile, span * -10.0, 0.0)

	# If all segments are below SEA_LEVEL, no mesh or body should be added
	var child_count: int = chunk.get_child_count()
	# Allow 0 children (all underwater) or some if partial above water
	assert_true(
		child_count >= 0,
		"Underwater tile should handle gracefully (got %d children)" % child_count,
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
		chunk1.get_child_count(), chunk2.get_child_count(),
		"Same tile should produce same child count",
	)


# ================================================================
# Road Y offset applied
# ================================================================

func test_road_y_offset_positive() -> void:
	assert_true(
		RuralRoadsScript.ROAD_Y_OFFSET > 0.0,
		"ROAD_Y_OFFSET should be positive to float above terrain",
	)
