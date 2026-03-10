extends RefCounted
## In-memory cache of resolved tile data (biome, edge profiles, seed).
## Maps Vector2i tile coords to Dictionary tile data.
## Falls through to disk persistence when memory cache misses.

const TileProfile = preload("res://src/tile_profile.gd")

var _cache: Dictionary = {}
var _persistence: RefCounted


func init(persistence: RefCounted = null) -> void:
	_persistence = persistence


## Get tile data for a tile coordinate. Returns empty dict if missing.
## Checks memory first, then disk.
func get_tile_data(tile: Vector2i) -> Dictionary:
	if _cache.has(tile):
		return _cache[tile]
	if _persistence:
		var disk_data: Dictionary = _persistence.load_tile(tile)
		if not disk_data.is_empty():
			_cache[tile] = disk_data
			return disk_data
	return {}


## Store tile data for a tile coordinate.
func set_tile_data(tile: Vector2i, data: Dictionary) -> void:
	_cache[tile] = data
	if _persistence:
		_persistence.mark_dirty(tile, data)


## Remove tile data from cache and disk.
func clear_tile(tile: Vector2i) -> void:
	_cache.erase(tile)
	if _persistence:
		_persistence.delete_tile(tile)


## Check if tile data exists in cache or on disk.
func has_tile(tile: Vector2i) -> bool:
	if _cache.has(tile):
		return true
	if _persistence:
		return _persistence.has_tile(tile)
	return false


## Flush dirty tiles to disk.
func flush() -> void:
	if _persistence:
		_persistence.flush_dirty()


## Get the facing edge of a neighbor tile.
## Returns the edge of the neighbor at `tile + offset(direction)` that faces
## back toward `tile`. Returns empty dict if neighbor not cached.
func get_neighbor_edge(tile: Vector2i, direction: int) -> Dictionary:
	var offset := _dir_to_offset(direction)
	var neighbor := tile + offset
	var neighbor_data: Dictionary = get_tile_data(neighbor)
	if neighbor_data.is_empty():
		return {}
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
