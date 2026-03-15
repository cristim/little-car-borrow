extends RefCounted
## Persists tile data to disk as binary files.
## Directory: user://chunks/ with one file per tile: {x}_{z}.dat

const CHUNKS_DIR := "user://chunks/"

var _dirty: Dictionary = {}


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(CHUNKS_DIR)


## Save tile data to disk.
func save_tile(tile: Vector2i, data: Dictionary) -> void:
	var path: String = _tile_path(tile)
	var bytes: PackedByteArray = var_to_bytes(data)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_buffer(bytes)


## Load tile data from disk. Returns empty dict if not found or corrupt.
func load_tile(tile: Vector2i) -> Dictionary:
	var path: String = _tile_path(tile)
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}
	var bytes: PackedByteArray = file.get_buffer(file.get_length())
	var result: Variant = bytes_to_var(bytes)
	if result is Dictionary and (result as Dictionary).has("biome"):
		return result
	# Corrupted or incomplete file — delete and return empty
	DirAccess.remove_absolute(path)
	return {}


## Delete tile data from disk and pending writes.
func delete_tile(tile: Vector2i) -> void:
	_dirty.erase(tile)
	var path: String = _tile_path(tile)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


## Check if tile data exists on disk.
func has_tile(tile: Vector2i) -> bool:
	return FileAccess.file_exists(_tile_path(tile))


## Mark a tile as dirty (needs flushing).
func mark_dirty(tile: Vector2i, data: Dictionary) -> void:
	_dirty[tile] = data


## Flush all dirty tiles to disk.
func flush_dirty() -> void:
	for tile: Vector2i in _dirty:
		save_tile(tile, _dirty[tile])
	_dirty.clear()


## Return number of dirty tiles pending write.
func dirty_count() -> int:
	return _dirty.size()


func _tile_path(tile: Vector2i) -> String:
	return CHUNKS_DIR + "%d_%d.dat" % [tile.x, tile.y]
