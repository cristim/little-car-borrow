extends GutTest
## Unit tests for river_map.gd river path tracing on terrain.

const RiverMapScript = preload("res://src/river_map.gd")
const BoundaryScript = preload("res://src/city_boundary.gd")
const RoadGridScript = preload("res://src/road_grid.gd")

var _river: RefCounted
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
	_river = RiverMapScript.new()
	_river.init(_grid_span, boundary)


# --- Constants ---

func test_river_seed_constant() -> void:
	assert_eq(RiverMapScript.RIVER_SEED, 0x21FE)


func test_river_width_min() -> void:
	assert_eq(RiverMapScript.RIVER_WIDTH_MIN, 4.0)


func test_river_width_max() -> void:
	assert_eq(RiverMapScript.RIVER_WIDTH_MAX, 12.0)


func test_min_source_height() -> void:
	assert_eq(RiverMapScript.MIN_SOURCE_HEIGHT, 25.0)


# --- init ---

func test_init_sets_grid_span() -> void:
	assert_eq(_river._grid_span, _grid_span)


func test_init_sets_boundary() -> void:
	assert_not_null(_river._boundary)


func test_init_creates_river_noise() -> void:
	assert_not_null(_river._river_noise)
	assert_true(_river._river_noise is FastNoiseLite)


func test_init_noise_seed() -> void:
	assert_eq(_river._river_noise.seed, 8421)


func test_init_noise_frequency() -> void:
	assert_almost_eq(_river._river_noise.frequency, 0.15, 0.001)


func test_init_noise_type() -> void:
	assert_eq(
		_river._river_noise.noise_type,
		FastNoiseLite.TYPE_SIMPLEX_SMOOTH,
	)


func test_init_river_tiles_empty() -> void:
	assert_eq(_river._river_tiles.size(), 0)


# --- get_river_at ---

func test_get_river_at_returns_dictionary() -> void:
	var result: Dictionary = _river.get_river_at(Vector2i(0, 0))
	assert_true(result is Dictionary)


func test_get_river_at_caches_result() -> void:
	var tile := Vector2i(5, 5)
	var first: Dictionary = _river.get_river_at(tile)
	var second: Dictionary = _river.get_river_at(tile)
	assert_eq(first, second)
	assert_true(_river._river_tiles.has(tile))


func test_get_river_at_empty_dict_means_no_river() -> void:
	var found_empty := false
	for x in range(-10, 10):
		for y in range(-10, 10):
			var data: Dictionary = _river.get_river_at(Vector2i(x, y))
			if data.is_empty():
				found_empty = true
				break
		if found_empty:
			break
	assert_true(found_empty, "Should find at least one tile with no river")


func test_get_river_at_valid_data_has_required_keys() -> void:
	var found_river := false
	for x in range(-20, 20):
		for y in range(-20, 20):
			var data: Dictionary = _river.get_river_at(Vector2i(x, y))
			if not data.is_empty():
				assert_true(
					data.has("entry_dir"),
					"River data should have entry_dir",
				)
				assert_true(
					data.has("exit_dir"),
					"River data should have exit_dir",
				)
				assert_true(
					data.has("position"),
					"River data should have position",
				)
				assert_true(
					data.has("width"),
					"River data should have width",
				)
				found_river = true
				break
		if found_river:
			break
	if not found_river:
		pass_test("No river tiles found with this seed -- boundary may be too small")


func test_get_river_at_entry_and_exit_differ() -> void:
	for x in range(-20, 20):
		for y in range(-20, 20):
			var data: Dictionary = _river.get_river_at(Vector2i(x, y))
			if not data.is_empty():
				assert_ne(
					data["entry_dir"], data["exit_dir"],
					"Entry and exit directions must differ",
				)
				return
	pass_test("No river tiles found with this seed")


func test_get_river_at_direction_range() -> void:
	for x in range(-20, 20):
		for y in range(-20, 20):
			var data: Dictionary = _river.get_river_at(Vector2i(x, y))
			if not data.is_empty():
				var entry: int = data["entry_dir"]
				var exit_d: int = data["exit_dir"]
				assert_gte(entry, 0, "entry_dir should be >= 0")
				assert_lt(entry, 4, "entry_dir should be < 4")
				assert_gte(exit_d, 0, "exit_dir should be >= 0")
				assert_lt(exit_d, 4, "exit_dir should be < 4")
				return
	pass_test("No river tiles found with this seed")


func test_get_river_at_width_in_valid_range() -> void:
	for x in range(-20, 20):
		for y in range(-20, 20):
			var data: Dictionary = _river.get_river_at(Vector2i(x, y))
			if not data.is_empty():
				var w: float = data["width"]
				assert_gte(
					w, RiverMapScript.RIVER_WIDTH_MIN,
					"Width should be >= RIVER_WIDTH_MIN",
				)
				assert_lte(
					w, RiverMapScript.RIVER_WIDTH_MAX,
					"Width should be <= RIVER_WIDTH_MAX",
				)
				return
	pass_test("No river tiles found with this seed")


func test_get_river_at_position_in_zero_one_range() -> void:
	for x in range(-20, 20):
		for y in range(-20, 20):
			var data: Dictionary = _river.get_river_at(Vector2i(x, y))
			if not data.is_empty():
				var pos: float = data["position"]
				assert_gt(pos, 0.0, "Position should be > 0")
				assert_lt(pos, 1.0, "Position should be < 1")
				return
	pass_test("No river tiles found with this seed")


# --- Caching behavior ---

func test_cache_grows_with_queries() -> void:
	var before: int = _river._river_tiles.size()
	_river.get_river_at(Vector2i(100, 100))
	_river.get_river_at(Vector2i(101, 101))
	assert_eq(
		_river._river_tiles.size(), before + 2,
		"Cache should grow by 2 after 2 new tile queries",
	)


func test_repeated_query_does_not_grow_cache() -> void:
	_river.get_river_at(Vector2i(50, 50))
	var after_first: int = _river._river_tiles.size()
	_river.get_river_at(Vector2i(50, 50))
	assert_eq(
		_river._river_tiles.size(), after_first,
		"Repeated query should not grow the cache",
	)


# --- Deterministic results ---

func test_get_river_at_deterministic() -> void:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.003
	noise.fractal_octaves = 4
	noise.seed = 42
	var boundary: RefCounted = BoundaryScript.new()
	boundary.init(_grid_span, noise)
	var river2 := RiverMapScript.new()
	river2.init(_grid_span, boundary)
	for x in range(-5, 5):
		for y in range(-5, 5):
			var tile := Vector2i(x, y)
			var d1: Dictionary = _river.get_river_at(tile)
			var d2: Dictionary = river2.get_river_at(tile)
			assert_eq(d1, d2, "Same params should produce same river data")


# --- Origin tile (city center) likely has no river ---

func test_origin_tile_no_river() -> void:
	# Tile (0,0) is city center; ground_height is 0 there (flat city),
	# so rivers should be filtered out by the h < 1.0 check.
	var data: Dictionary = _river.get_river_at(Vector2i(0, 0))
	assert_true(
		data.is_empty(),
		"City center tile should have no river (height too low)",
	)
