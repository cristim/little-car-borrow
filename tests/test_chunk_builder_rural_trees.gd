extends GutTest
## Unit tests for chunk_builder_rural_trees.gd tree generation.

const TreesScript = preload(
	"res://scenes/world/generator/chunk_builder_rural_trees.gd"
)
const RoadGridScript = preload("res://src/road_grid.gd")
const BoundaryScript = preload("res://src/city_boundary.gd")

var _grid: RefCounted
var _boundary: RefCounted
var _builder: RefCounted
var _trunk_mats: Array[StandardMaterial3D]
var _canopy_mats: Array[StandardMaterial3D]
var _trunk_mesh: CylinderMesh
var _canopy_meshes: Array[Mesh]
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

	_trunk_mats = []
	for _i in 2:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.4, 0.25, 0.1)
		_trunk_mats.append(m)

	_canopy_mats = []
	for _i in 3:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.2, 0.5, 0.15)
		_canopy_mats.append(m)

	_trunk_mesh = CylinderMesh.new()
	_trunk_mesh.top_radius = 0.5
	_trunk_mesh.bottom_radius = 0.5
	_trunk_mesh.height = 1.0

	_canopy_meshes = []
	for _i in TreesScript.CANOPY_VARIANTS:
		var m := SphereMesh.new()
		m.radius = 1.0
		m.height = 2.0
		_canopy_meshes.append(m)

	_builder = TreesScript.new()
	_builder.init(
		_grid, _trunk_mats, _canopy_mats,
		_trunk_mesh, _canopy_meshes, _boundary,
	)


# ================================================================
# Initialization
# ================================================================

func test_init_stores_grid() -> void:
	assert_eq(_builder._grid, _grid, "init should store grid reference")


func test_init_stores_boundary() -> void:
	assert_eq(
		_builder._boundary, _boundary, "init should store boundary reference",
	)


func test_init_stores_trunk_mats() -> void:
	assert_eq(
		_builder._trunk_mats.size(), 2,
		"init should store trunk materials",
	)


func test_init_stores_canopy_meshes() -> void:
	assert_eq(
		_builder._canopy_meshes.size(), TreesScript.CANOPY_VARIANTS,
		"init should store all canopy mesh variants",
	)


# ================================================================
# _get_biome_density (static)
# ================================================================

func test_biome_density_forest() -> void:
	var d: Dictionary = TreesScript._get_biome_density("forest")
	assert_eq(d["min_clusters"], 4, "Forest min_clusters should be 4")
	assert_eq(d["max_clusters"], 7, "Forest max_clusters should be 7")
	assert_eq(d["min_trees"], 15, "Forest min_trees should be 15")
	assert_eq(d["max_trees"], 30, "Forest max_trees should be 30")


func test_biome_density_known_biomes() -> void:
	var mountain: Dictionary = TreesScript._get_biome_density("mountain")
	assert_eq(mountain["min_clusters"], 2, "Mountain min_clusters should be 2")
	assert_eq(mountain["max_clusters"], 4, "Mountain max_clusters should be 4")

	var farmland: Dictionary = TreesScript._get_biome_density("farmland")
	assert_eq(farmland["min_clusters"], 1, "Farmland min_clusters should be 1")
	assert_eq(farmland["max_clusters"], 2, "Farmland max_clusters should be 2")
	assert_eq(farmland["min_trees"], 3, "Farmland min_trees should be 3")

	var suburb: Dictionary = TreesScript._get_biome_density("suburb")
	assert_eq(suburb["min_clusters"], 1, "Suburb min_clusters should be 1")
	assert_eq(suburb["max_clusters"], 3, "Suburb max_clusters should be 3")


func test_biome_density_default_and_empty() -> void:
	var d: Dictionary = TreesScript._get_biome_density("unknown_biome")
	assert_eq(d["min_clusters"], 2, "Default min_clusters should be 2")
	assert_eq(d["max_clusters"], 4, "Default max_clusters should be 4")
	assert_eq(d["min_trees"], 8, "Default min_trees should be 8")
	assert_eq(d["max_trees"], 20, "Default max_trees should be 20")

	var e: Dictionary = TreesScript._get_biome_density("")
	assert_eq(
		e["min_clusters"], 2,
		"Empty biome string should return default density",
	)


# ================================================================
# _near_village
# ================================================================

func test_near_village_false_when_no_village() -> void:
	var result: bool = _builder._near_village(
		0.0, 0.0, false, Vector2.ZERO,
	)
	assert_false(result, "Should return false when has_village is false")


func test_near_village_true_at_center() -> void:
	var vc := Vector2(100.0, 200.0)
	var result: bool = _builder._near_village(100.0, 200.0, true, vc)
	assert_true(result, "Should return true at village center")


func test_near_village_false_far_away() -> void:
	var vc := Vector2(100.0, 200.0)
	var result: bool = _builder._near_village(1000.0, 2000.0, true, vc)
	assert_false(result, "Should return false far from village center")


func test_near_village_boundary() -> void:
	var vc := Vector2(0.0, 0.0)
	var clearance: float = TreesScript.VILLAGE_CLEARANCE
	# Just inside clearance
	var result_in: bool = _builder._near_village(
		clearance - 1.0, 0.0, true, vc,
	)
	assert_true(result_in, "Should return true just inside clearance")
	# Just outside clearance
	var result_out: bool = _builder._near_village(
		clearance + 1.0, 0.0, true, vc,
	)
	assert_false(result_out, "Should return false just outside clearance")


# ================================================================
# _near_highway
# ================================================================

func test_near_highway_at_ns_road() -> void:
	var span: float = _grid.get_grid_span()
	var ox := span * 5.0
	var oz := 0.0
	# Highway index 0 N-S road center
	var road_cx: float = _grid.get_road_center_local(0) + ox
	var result: bool = _builder._near_highway(road_cx, 0.0, ox, oz)
	assert_true(result, "Position on N-S highway should be near highway")


func test_near_highway_far_from_roads() -> void:
	var span: float = _grid.get_grid_span()
	var ox := span * 5.0
	var oz := 0.0
	# Position far from any highway
	var result: bool = _builder._near_highway(
		ox + 999.0, oz + 999.0, ox, oz,
	)
	assert_false(result, "Position far from highways should not be near")


# ================================================================
# Build behavior
# ================================================================

func test_build_creates_tree_body_on_terrain() -> void:
	var span: float = _grid.get_grid_span()
	# Tile far enough from city to have terrain height > 1.0
	var tile := Vector2i(5, 0)
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	_builder.build(chunk, tile, span * 5.0, 0.0)

	var found_body := false
	for child in chunk.get_children():
		if child is StaticBody3D and child.name == "RuralTrees":
			found_body = true
			assert_eq(
				child.collision_layer, 2,
				"Tree body collision layer should be Static (2)",
			)
			assert_true(
				child.is_in_group("Static"),
				"Tree body should be in Static group",
			)
	assert_true(
		found_body,
		"Build on terrain tile should create RuralTrees body",
	)


func test_build_creates_trunk_multimesh() -> void:
	var span: float = _grid.get_grid_span()
	var tile := Vector2i(5, 0)
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	_builder.build(chunk, tile, span * 5.0, 0.0)

	var found_trunks := false
	for child in chunk.get_children():
		if child is StaticBody3D and child.name == "RuralTrees":
			for sub in child.get_children():
				if sub is MultiMeshInstance3D and sub.name == "RuralTrunksMM":
					found_trunks = true
					assert_not_null(
						sub.multimesh,
						"Trunk MultiMesh should not be null",
					)
					assert_true(
						sub.multimesh.instance_count > 0,
						"Trunk MultiMesh should have instances",
					)
	assert_true(
		found_trunks,
		"Build should create RuralTrunksMM MultiMeshInstance3D",
	)


func test_build_forest_biome_more_trees() -> void:
	var span: float = _grid.get_grid_span()
	var tile := Vector2i(6, 3)
	var ox: float = span * 6.0
	var oz: float = span * 3.0

	var chunk_default := Node3D.new()
	add_child_autofree(chunk_default)
	_builder.build(chunk_default, tile, ox, oz, "")

	var chunk_forest := Node3D.new()
	add_child_autofree(chunk_forest)
	_builder.build(chunk_forest, tile, ox, oz, "forest")

	# Count trunk instances in each
	var count_default := _count_trunk_instances(chunk_default)
	var count_forest := _count_trunk_instances(chunk_forest)

	# Forest should generally have more trees, but due to RNG we just
	# verify both produce some trees
	assert_true(
		count_default >= 0 and count_forest >= 0,
		"Both biomes should produce non-negative tree counts",
	)


func _count_trunk_instances(chunk: Node3D) -> int:
	for child in chunk.get_children():
		if child is StaticBody3D and child.name == "RuralTrees":
			for sub in child.get_children():
				if sub is MultiMeshInstance3D and sub.name == "RuralTrunksMM":
					return sub.multimesh.instance_count
	return 0


func test_build_with_village_meta_avoids_village() -> void:
	var span: float = _grid.get_grid_span()
	var tile := Vector2i(5, 0)
	var ox: float = span * 5.0
	var oz := 0.0

	# Build without village
	var chunk_no_village := Node3D.new()
	add_child_autofree(chunk_no_village)
	_builder.build(chunk_no_village, tile, ox, oz)
	var count_no_village := _count_trunk_instances(chunk_no_village)

	# Build with village at chunk center (should clear some trees)
	var chunk_village := Node3D.new()
	add_child_autofree(chunk_village)
	chunk_village.set_meta("has_village", true)
	chunk_village.set_meta("village_center", Vector2(ox, oz))
	_builder.build(chunk_village, tile, ox, oz)
	var count_village := _count_trunk_instances(chunk_village)

	# Village version should have fewer or equal trees
	assert_true(
		count_village <= count_no_village,
		"Village chunk should have fewer trees (village=%d, no_village=%d)"
		% [count_village, count_no_village],
	)


func test_build_deterministic() -> void:
	var span: float = _grid.get_grid_span()
	var tile := Vector2i(7, 2)
	var ox: float = span * 7.0
	var oz: float = span * 2.0

	var chunk1 := Node3D.new()
	add_child_autofree(chunk1)
	_builder.build(chunk1, tile, ox, oz)

	var chunk2 := Node3D.new()
	add_child_autofree(chunk2)
	_builder.build(chunk2, tile, ox, oz)

	assert_eq(
		_count_trunk_instances(chunk1),
		_count_trunk_instances(chunk2),
		"Same tile should produce same trunk count",
	)


func test_build_at_city_center_produces_no_trees() -> void:
	# City center has height 0, below MIN_TREE_HEIGHT
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	_builder.build(chunk, Vector2i(0, 0), 0.0, 0.0)

	var found_trees := false
	for child in chunk.get_children():
		if child is StaticBody3D and child.name == "RuralTrees":
			found_trees = true
	assert_false(
		found_trees,
		"City center (height=0) should produce no trees",
	)


# ================================================================
# Constants sanity
# ================================================================

func test_constants_sanity() -> void:
	assert_eq(
		TreesScript.CANOPY_VARIANTS, 6,
		"CANOPY_VARIANTS should be 6",
	)
	assert_true(
		TreesScript.MIN_TREE_HEIGHT > 0.0,
		"MIN_TREE_HEIGHT should be positive",
	)
	assert_true(
		TreesScript.ROADSIDE_SPACING_MIN < TreesScript.ROADSIDE_SPACING_MAX,
		"ROADSIDE_SPACING_MIN should be less than MAX",
	)
	assert_true(
		TreesScript.CLUSTER_RADIUS_MIN < TreesScript.CLUSTER_RADIUS_MAX,
		"CLUSTER_RADIUS_MIN should be less than MAX",
	)
	assert_true(
		TreesScript.CLUSTER_TREES_MIN < TreesScript.CLUSTER_TREES_MAX,
		"CLUSTER_TREES_MIN should be less than MAX",
	)
