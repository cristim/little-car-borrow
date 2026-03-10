extends RefCounted
## In-memory cache of resolved tile data (biome, edge profiles, seed).
## Maps Vector2i tile coords to Dictionary tile data.

const TileProfile = preload("res://src/tile_profile.gd")

var _cache: Dictionary = {}


## Get tile data for a tile coordinate. Returns empty dict if missing.
func get_tile_data(tile: Vector2i) -> Dictionary:
	return _cache.get(tile, {})


## Store tile data for a tile coordinate.
func set_tile_data(tile: Vector2i, data: Dictionary) -> void:
	_cache[tile] = data


## Remove tile data from cache.
func clear_tile(tile: Vector2i) -> void:
	_cache.erase(tile)


## Check if tile data exists in cache.
func has_tile(tile: Vector2i) -> bool:
	return _cache.has(tile)


## Get the facing edge of a neighbor tile.
## Returns the edge of the neighbor at `tile + offset(direction)` that faces
## back toward `tile`. Returns empty dict if neighbor not cached.
func get_neighbor_edge(tile: Vector2i, direction: int) -> Dictionary:
	var offset := _dir_to_offset(direction)
	var neighbor := tile + offset
	if not _cache.has(neighbor):
		return {}
	var neighbor_data: Dictionary = _cache[neighbor]
	var edges: Dictionary = neighbor_data.get("edges", {})
	var opposite: int = TileProfile.get_opposite(direction)
	return edges.get(opposite, {})


## Return number of cached tiles.
func size() -> int:
	return _cache.size()


static func _dir_to_offset(direction: int) -> Vector2i:
	match direction:
		TileProfile.NORTH:
			return Vector2i(0, -1)
		TileProfile.EAST:
			return Vector2i(1, 0)
		TileProfile.SOUTH:
			return Vector2i(0, 1)
		TileProfile.WEST:
			return Vector2i(-1, 0)
	return Vector2i.ZERO
