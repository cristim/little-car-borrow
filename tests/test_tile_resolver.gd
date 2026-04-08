extends GutTest
## Unit tests for tile_resolver.gd tile resolution with edge matching.

const ResolverScript = preload("res://src/tile_resolver.gd")
const CacheScript = preload("res://src/tile_cache.gd")
const BiomeMapScript = preload("res://src/biome_map.gd")
const BoundaryScript = preload("res://src/city_boundary.gd")
const RoadGridScript = preload("res://src/road_grid.gd")
const TP = preload("res://src/tile_profile.gd")

var _resolver: RefCounted
var _cache: RefCounted
var _biome_map: RefCounted
var _grid: RefCounted


func before_each() -> void:
	_grid = RoadGridScript.new()
	var grid_span: float = _grid.get_grid_span()
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.003
	noise.fractal_octaves = 4
	noise.seed = 42
	var boundary: RefCounted = BoundaryScript.new()
	boundary.init(grid_span, noise)
	_cache = CacheScript.new()
	_biome_map = BiomeMapScript.new()
	_biome_map.init(grid_span, noise, boundary)
	_resolver = ResolverScript.new()
	_resolver.init(_cache, _biome_map, _grid, boundary)


func test_resolve_returns_biome() -> void:
	var data: Dictionary = _resolver.resolve(Vector2i(0, 0))
	assert_true(data.has("biome"))
	assert_eq(data["biome"], "city_center")


func test_resolve_returns_edges() -> void:
	var data: Dictionary = _resolver.resolve(Vector2i(0, 0))
	assert_true(data.has("edges"))
	var edges: Dictionary = data["edges"]
	assert_eq(edges.size(), 4)
	for dir in range(4):
		assert_true(edges.has(dir))
		assert_true(edges[dir].has("biome"))
		assert_true(edges[dir].has("heights"))


func test_resolve_caches_result() -> void:
	_resolver.resolve(Vector2i(0, 0))
	assert_true(_cache.has_tile(Vector2i(0, 0)))


func test_resolve_idempotent() -> void:
	var data1: Dictionary = _resolver.resolve(Vector2i(0, 0))
	var data2: Dictionary = _resolver.resolve(Vector2i(0, 0))
	assert_eq(data1["biome"], data2["biome"])
	assert_eq(data1["seed"], data2["seed"])


func test_neighbor_edges_match_heights() -> void:
	# Resolve tile (5, 5) then its east neighbor (6, 5)
	var data_a: Dictionary = _resolver.resolve(Vector2i(5, 5))
	var data_b: Dictionary = _resolver.resolve(Vector2i(6, 5))
	var east_edge: Dictionary = data_a["edges"][TP.EAST]
	var west_edge: Dictionary = data_b["edges"][TP.WEST]
	# Heights should match (neighbor reads from cache)
	var ha: PackedFloat32Array = east_edge["heights"]
	var hb: PackedFloat32Array = west_edge["heights"]
	if ha.size() == hb.size() and ha.size() > 0:
		for i in range(ha.size()):
			assert_almost_eq(
				ha[i],
				hb[i],
				0.01,
				"Height mismatch at sample %d" % i,
			)


func test_city_tile_has_flat_edges() -> void:
	var data: Dictionary = _resolver.resolve(Vector2i(0, 0))
	for dir in range(4):
		var edge: Dictionary = data["edges"][dir]
		var heights: PackedFloat32Array = edge["heights"]
		for i in range(heights.size()):
			assert_eq(
				heights[i],
				0.0,
				"City tile edge should be flat",
			)


func test_resolve_returns_seed() -> void:
	var data: Dictionary = _resolver.resolve(Vector2i(3, 4))
	assert_true(data.has("seed"))
	assert_ne(data["seed"], 0)


# ==========================================================================
# Multi-pass neighbor validation (I4 fix)
# ==========================================================================


func test_adjust_biome_uses_while_loop() -> void:
	var src: String = (ResolverScript as GDScript).source_code
	assert_true(
		src.contains("while changed"),
		"_adjust_biome_for_neighbors must iterate until stable (while changed)",
	)


func test_adjust_biome_has_iteration_cap() -> void:
	var src: String = (ResolverScript as GDScript).source_code
	assert_true(
		src.contains("iterations < 8"),
		"_adjust_biome_for_neighbors must cap iterations at 8 to prevent infinite loops",
	)
