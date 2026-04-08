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
	var edge: Dictionary = (
		_cache
		. get_neighbor_edge(
			Vector2i(0, 0),
			TP.NORTH,
		)
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
	var result: Dictionary = (
		_cache
		. get_neighbor_edge(
			Vector2i(0, 0),
			TP.NORTH,
		)
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

	var result: Dictionary = (
		_cache
		. get_neighbor_edge(
			Vector2i(0, 0),
			TP.EAST,
		)
	)
	assert_eq(result["biome"], "suburb")


func test_overwrite_tile_data() -> void:
	_cache.set_tile_data(Vector2i(0, 0), {"biome": "forest"})
	_cache.set_tile_data(Vector2i(0, 0), {"biome": "mountain"})
	var got: Dictionary = _cache.get_tile_data(Vector2i(0, 0))
	assert_eq(got["biome"], "mountain")
	assert_eq(_cache.size(), 1)


# ---------------------------------------------------------------------------
# Extended tests — return values, edge cases, coordinates
# ---------------------------------------------------------------------------


func test_get_tile_missing_returns_empty_dict() -> void:
	var data: Dictionary = _cache.get_tile_data(Vector2i(99, 99))
	assert_true(data.is_empty(), "Missing tile should return empty dict")


func test_has_tile_true_after_set() -> void:
	_cache.set_tile_data(Vector2i(3, 5), {"biome": "ocean"})
	assert_true(_cache.has_tile(Vector2i(3, 5)))


func test_has_tile_false_after_clear() -> void:
	_cache.set_tile_data(Vector2i(1, 1), {"biome": "city_center"})
	_cache.clear_tile(Vector2i(1, 1))
	assert_false(_cache.has_tile(Vector2i(1, 1)), "has_tile should return false after clear")


func test_clear_nonexistent_tile_does_not_error() -> void:
	# Clearing a tile that was never set should not raise an error
	_cache.clear_tile(Vector2i(100, 200))
	assert_true(true, "No error clearing absent tile")


func test_size_starts_at_zero() -> void:
	assert_eq(_cache.size(), 0)


func test_size_after_multiple_sets_distinct_keys() -> void:
	for i in range(10):
		_cache.set_tile_data(Vector2i(i, 0), {"seed": i})
	assert_eq(_cache.size(), 10)


func test_size_does_not_grow_on_overwrite() -> void:
	_cache.set_tile_data(Vector2i(0, 0), {"biome": "forest"})
	_cache.set_tile_data(Vector2i(0, 0), {"biome": "mountain"})
	_cache.set_tile_data(Vector2i(0, 0), {"biome": "ocean"})
	assert_eq(_cache.size(), 1, "Overwriting same key must not grow size")


func test_size_decrements_on_clear() -> void:
	_cache.set_tile_data(Vector2i(0, 0), {"biome": "forest"})
	_cache.set_tile_data(Vector2i(1, 0), {"biome": "ocean"})
	_cache.clear_tile(Vector2i(0, 0))
	assert_eq(_cache.size(), 1)


func test_negative_tile_coords_stored_and_retrieved() -> void:
	var tile: Vector2i = Vector2i(-5, -10)
	_cache.set_tile_data(tile, {"biome": "village", "seed": 7})
	assert_true(_cache.has_tile(tile))
	var got: Dictionary = _cache.get_tile_data(tile)
	assert_eq(got["biome"], "village")
	assert_eq(got["seed"], 7)


func test_large_tile_coords_stored_and_retrieved() -> void:
	var tile: Vector2i = Vector2i(100000, 100000)
	_cache.set_tile_data(tile, {"biome": "ocean"})
	assert_true(_cache.has_tile(tile))
	var got: Dictionary = _cache.get_tile_data(tile)
	assert_eq(got["biome"], "ocean")


func test_mixed_positive_negative_coords_are_distinct() -> void:
	_cache.set_tile_data(Vector2i(1, -1), {"biome": "forest"})
	_cache.set_tile_data(Vector2i(-1, 1), {"biome": "mountain"})
	assert_eq(_cache.size(), 2)
	assert_eq(_cache.get_tile_data(Vector2i(1, -1))["biome"], "forest")
	assert_eq(_cache.get_tile_data(Vector2i(-1, 1))["biome"], "mountain")


func test_tile_data_can_store_multiple_fields() -> void:
	var data: Dictionary = {"biome": "farmland", "seed": 1234, "elevation": 3.5, "roads": []}
	_cache.set_tile_data(Vector2i(2, 3), data)
	var got: Dictionary = _cache.get_tile_data(Vector2i(2, 3))
	assert_eq(got["biome"], "farmland")
	assert_eq(got["seed"], 1234)
	assert_eq(got["elevation"], 3.5)


func test_get_neighbor_edge_south() -> void:
	# Tile at (0, 1) has a NORTH edge; querying (0,0) SOUTH should return it
	var north_edge: Dictionary = TP.create_flat_edge("farmland")
	_cache.set_tile_data(Vector2i(0, 1), {"biome": "farmland", "edges": {TP.NORTH: north_edge}})
	var result: Dictionary = _cache.get_neighbor_edge(Vector2i(0, 0), TP.SOUTH)
	assert_false(result.is_empty(), "SOUTH neighbor edge should be returned")
	assert_eq(result["biome"], "farmland")


func test_get_neighbor_edge_west() -> void:
	# Tile at (-1, 0) has an EAST edge; querying (0,0) WEST should return it
	var east_edge: Dictionary = TP.create_flat_edge("mountain")
	_cache.set_tile_data(Vector2i(-1, 0), {"biome": "mountain", "edges": {TP.EAST: east_edge}})
	var result: Dictionary = _cache.get_neighbor_edge(Vector2i(0, 0), TP.WEST)
	assert_false(result.is_empty(), "WEST neighbor edge should be returned")
	assert_eq(result["biome"], "mountain")


func test_get_neighbor_edge_missing_edge_key_returns_empty() -> void:
	# Tile exists but has no edge data for the queried direction
	_cache.set_tile_data(Vector2i(0, -1), {"biome": "ocean", "edges": {}})
	var result: Dictionary = _cache.get_neighbor_edge(Vector2i(0, 0), TP.NORTH)
	assert_true(result.is_empty(), "Missing edge entry should return empty dict")


func test_flush_without_persistence_does_not_error() -> void:
	_cache.set_tile_data(Vector2i(0, 0), {"biome": "forest"})
	_cache.flush()
	assert_true(true, "flush() without persistence should not raise")


func test_init_called_without_args_sets_no_persistence() -> void:
	var c: RefCounted = CacheScript.new()
	c.init()
	# get_tile_data on empty cache without persistence should return empty dict
	var got: Dictionary = c.get_tile_data(Vector2i(0, 0))
	assert_true(got.is_empty())
