extends GutTest
## Unit tests for tile_cache.gd in-memory tile data cache.

const CacheScript = preload("res://src/tile_cache.gd")
const TP = preload("res://src/tile_profile.gd")

var _cache: RefCounted


func before_each() -> void:
	_cache = CacheScript.new()


func test_empty_cache_returns_empty_dict() -> void:
	var data: Dictionary = _cache.get_tile_data(Vector2i(0, 0))
	assert_true(data.is_empty())


func test_has_tile_false_when_empty() -> void:
	assert_false(_cache.has_tile(Vector2i(0, 0)))


func test_set_and_get_tile_data() -> void:
	var data: Dictionary = {"biome": "forest", "seed": 42}
	_cache.set_tile_data(Vector2i(1, 2), data)
	assert_true(_cache.has_tile(Vector2i(1, 2)))
	var got: Dictionary = _cache.get_tile_data(Vector2i(1, 2))
	assert_eq(got["biome"], "forest")
	assert_eq(got["seed"], 42)


func test_clear_tile() -> void:
	_cache.set_tile_data(Vector2i(0, 0), {"biome": "ocean"})
	_cache.clear_tile(Vector2i(0, 0))
	assert_false(_cache.has_tile(Vector2i(0, 0)))


func test_size() -> void:
	assert_eq(_cache.size(), 0)
	_cache.set_tile_data(Vector2i(0, 0), {"biome": "forest"})
	assert_eq(_cache.size(), 1)
	_cache.set_tile_data(Vector2i(1, 0), {"biome": "mountain"})
	assert_eq(_cache.size(), 2)
	_cache.clear_tile(Vector2i(0, 0))
	assert_eq(_cache.size(), 1)


func test_get_neighbor_edge_no_neighbor() -> void:
	var edge: Dictionary = _cache.get_neighbor_edge(
		Vector2i(0, 0), TP.NORTH,
	)
	assert_true(edge.is_empty())


func test_get_neighbor_edge_returns_facing_edge() -> void:
	# Place a tile at (0, -1) with a SOUTH edge
	var south_edge: Dictionary = TP.create_flat_edge("residential")
	var neighbor_data: Dictionary = {
		"biome": "residential",
		"edges": {TP.SOUTH: south_edge},
	}
	_cache.set_tile_data(Vector2i(0, -1), neighbor_data)

	# Query from (0, 0) looking NORTH — should get neighbor's SOUTH edge
	var result: Dictionary = _cache.get_neighbor_edge(
		Vector2i(0, 0), TP.NORTH,
	)
	assert_false(result.is_empty())
	assert_eq(result["biome"], "residential")


func test_get_neighbor_edge_east() -> void:
	var west_edge: Dictionary = TP.create_flat_edge("suburb")
	var neighbor_data: Dictionary = {
		"biome": "suburb",
		"edges": {TP.WEST: west_edge},
	}
	_cache.set_tile_data(Vector2i(1, 0), neighbor_data)

	var result: Dictionary = _cache.get_neighbor_edge(
		Vector2i(0, 0), TP.EAST,
	)
	assert_eq(result["biome"], "suburb")


func test_overwrite_tile_data() -> void:
	_cache.set_tile_data(Vector2i(0, 0), {"biome": "forest"})
	_cache.set_tile_data(Vector2i(0, 0), {"biome": "mountain"})
	var got: Dictionary = _cache.get_tile_data(Vector2i(0, 0))
	assert_eq(got["biome"], "mountain")
	assert_eq(_cache.size(), 1)
