extends GutTest
## Unit tests for biome_map.gd noise-based biome assignment.

const BiomeMapScript = preload("res://src/biome_map.gd")
const BoundaryScript = preload("res://src/city_boundary.gd")
const RoadGridScript = preload("res://src/road_grid.gd")
const TileProfile = preload("res://src/tile_profile.gd")

var _biome_map: RefCounted
var _grid_span: float


func before_each() -> void:
	var grid: RefCounted = RoadGridScript.new()
	_grid_span = grid.get_grid_span()
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.003
	noise.fractal_octaves = 4
	noise.seed = 42
	var boundary: RefCounted = BoundaryScript.new()
	boundary.init(_grid_span, noise)
	_biome_map = BiomeMapScript.new()
	_biome_map.init(_grid_span, noise, boundary)


func test_origin_is_city_center() -> void:
	var biome: String = _biome_map.get_biome(Vector2i(0, 0))
	assert_eq(biome, "city_center", "Origin should be city_center")


func test_origin_is_city_tile() -> void:
	assert_true(_biome_map.is_city_tile(Vector2i(0, 0)))


func test_far_tile_is_not_city() -> void:
	assert_false(_biome_map.is_city_tile(Vector2i(10, 10)))


func test_far_tile_has_rural_biome() -> void:
	var biome: String = _biome_map.get_biome(Vector2i(10, 10))
	assert_false(
		biome in TileProfile.CITY_BIOMES,
		"Far tile should have rural biome, got: %s" % biome,
	)


func test_all_biomes_are_valid() -> void:
	# Sample a grid of tiles and verify all returned biomes are valid
	var valid_biomes: Array = TileProfile.BIOME_ADJACENCY.keys()
	for x in range(-8, 9):
		for z in range(-8, 9):
			var biome: String = _biome_map.get_biome(Vector2i(x, z))
			assert_true(
				biome in valid_biomes,
				"Biome '%s' at (%d,%d) not in valid set" % [biome, x, z],
			)


func test_is_city_biome_classification() -> void:
	assert_true(_biome_map.is_city_biome("city_center"))
	assert_true(_biome_map.is_city_biome("residential"))
	assert_true(_biome_map.is_city_biome("suburb"))
	assert_false(_biome_map.is_city_biome("forest"))
	assert_false(_biome_map.is_city_biome("ocean"))


func test_deterministic_results() -> void:
	# Same tile should always return same biome
	var biome1: String = _biome_map.get_biome(Vector2i(3, 3))
	var biome2: String = _biome_map.get_biome(Vector2i(3, 3))
	assert_eq(biome1, biome2)


# ==========================================================================
# Biome noise scaling (I2 fix)
# ==========================================================================


func test_biome_noise_call_has_no_double_scaling() -> void:
	var src: String = (BiomeMapScript as GDScript).source_code
	assert_false(
		src.contains("get_noise_2d(wx * 0.01"),
		"_biome_noise.get_noise_2d must not double-scale with * 0.01; noise frequency handles it",
	)
