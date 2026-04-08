extends GutTest
## Unit tests for chunk_persistence.gd tile save/load/delete/dirty tracking.

const ChunkPersistenceScript = preload("res://src/chunk_persistence.gd")

var _cp: RefCounted
# Test tiles that won't collide with real game data
var _tile_a := Vector2i(9990, 9990)
var _tile_b := Vector2i(9991, 9991)
var _tile_c := Vector2i(9992, 9992)


func before_each() -> void:
	_cp = ChunkPersistenceScript.new()
	# Clean up any leftover test tiles
	_cp.delete_tile(_tile_a)
	_cp.delete_tile(_tile_b)
	_cp.delete_tile(_tile_c)


func after_each() -> void:
	# Clean up test tiles after each test
	_cp.delete_tile(_tile_a)
	_cp.delete_tile(_tile_b)
	_cp.delete_tile(_tile_c)


# --- Constants ---


func test_chunks_dir_constant() -> void:
	assert_eq(
		ChunkPersistenceScript.CHUNKS_DIR,
		"user://chunks/",
	)


# --- _init ---


func test_init_creates_directory() -> void:
	# The directory should exist after construction
	assert_true(
		DirAccess.dir_exists_absolute("user://chunks/"),
		"chunks directory should exist after init",
	)


# --- save_tile / load_tile roundtrip ---


func test_save_and_load_tile() -> void:
	var data := {"biome": "forest", "height": 42.5}
	_cp.save_tile(_tile_a, data)
	var loaded: Dictionary = _cp.load_tile(_tile_a)
	assert_eq(loaded["biome"], "forest")
	assert_almost_eq(float(loaded["height"]), 42.5, 0.001)


func test_save_tile_overwrites_previous() -> void:
	_cp.save_tile(_tile_a, {"biome": "ocean", "depth": 10})
	_cp.save_tile(_tile_a, {"biome": "desert", "temp": 45})
	var loaded: Dictionary = _cp.load_tile(_tile_a)
	assert_eq(loaded["biome"], "desert")
	assert_true(loaded.has("temp"))
	assert_false(loaded.has("depth"))


func test_save_tile_with_nested_data() -> void:
	var data := {
		"biome": "city",
		"buildings": [1, 2, 3],
		"meta": {"version": 1},
	}
	_cp.save_tile(_tile_a, data)
	var loaded: Dictionary = _cp.load_tile(_tile_a)
	assert_eq(loaded["biome"], "city")
	assert_eq(loaded["buildings"], [1, 2, 3])


# --- load_tile ---


func test_load_tile_nonexistent_returns_empty() -> void:
	var loaded: Dictionary = _cp.load_tile(Vector2i(99999, 99999))
	assert_true(loaded.is_empty())


func test_load_tile_dict_without_biome_returns_empty() -> void:
	# Write a valid Dictionary that lacks the required "biome" key
	var path: String = "user://chunks/9990_9990.dat"
	var data := {"terrain": "flat", "height": 5.0}
	var bytes: PackedByteArray = var_to_bytes(data)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_buffer(bytes)
		file = null
	var loaded: Dictionary = _cp.load_tile(_tile_a)
	assert_true(
		loaded.is_empty(),
		"Dict without biome key should return empty dict",
	)


func test_load_tile_no_biome_key_gets_deleted() -> void:
	# Write a valid Dictionary but without "biome" key -- load_tile should
	# delete it and return empty.
	var path: String = "user://chunks/9990_9990.dat"
	var data := {"not_biome": "test"}
	var bytes: PackedByteArray = var_to_bytes(data)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_buffer(bytes)
		file = null
	var loaded: Dictionary = _cp.load_tile(_tile_a)
	assert_true(
		loaded.is_empty(),
		"Dict without biome key should return empty",
	)
	assert_false(
		FileAccess.file_exists(path),
		"Invalid file should be deleted after failed load",
	)


# --- has_tile ---


func test_has_tile_false_when_not_saved() -> void:
	assert_false(_cp.has_tile(Vector2i(88888, 88888)))


func test_has_tile_true_after_save() -> void:
	_cp.save_tile(_tile_a, {"biome": "test"})
	assert_true(_cp.has_tile(_tile_a))


func test_has_tile_false_after_delete() -> void:
	_cp.save_tile(_tile_a, {"biome": "test"})
	_cp.delete_tile(_tile_a)
	assert_false(_cp.has_tile(_tile_a))


# --- delete_tile ---


func test_delete_tile_removes_file() -> void:
	_cp.save_tile(_tile_a, {"biome": "test"})
	_cp.delete_tile(_tile_a)
	assert_false(_cp.has_tile(_tile_a))


func test_delete_tile_nonexistent_no_error() -> void:
	# Should not crash when deleting a tile that doesn't exist
	_cp.delete_tile(Vector2i(77777, 77777))
	pass_test("delete_tile on nonexistent tile should not error")


func test_delete_tile_clears_dirty() -> void:
	_cp.mark_dirty(_tile_a, {"biome": "test"})
	assert_eq(_cp.dirty_count(), 1)
	_cp.delete_tile(_tile_a)
	assert_eq(
		_cp.dirty_count(),
		0,
		"delete_tile should also clear dirty entry",
	)


# --- mark_dirty / dirty_count ---


func test_dirty_count_starts_at_zero() -> void:
	assert_eq(_cp.dirty_count(), 0)


func test_mark_dirty_increments_count() -> void:
	_cp.mark_dirty(_tile_a, {"biome": "a"})
	assert_eq(_cp.dirty_count(), 1)
	_cp.mark_dirty(_tile_b, {"biome": "b"})
	assert_eq(_cp.dirty_count(), 2)


func test_mark_dirty_same_tile_overwrites() -> void:
	_cp.mark_dirty(_tile_a, {"biome": "first"})
	_cp.mark_dirty(_tile_a, {"biome": "second"})
	assert_eq(
		_cp.dirty_count(),
		1,
		"Marking same tile dirty again should not increase count",
	)


# --- flush_dirty ---


func test_flush_dirty_saves_all() -> void:
	_cp.mark_dirty(_tile_a, {"biome": "forest"})
	_cp.mark_dirty(_tile_b, {"biome": "desert"})
	_cp.flush_dirty()
	assert_eq(
		_cp.dirty_count(),
		0,
		"flush_dirty should clear all dirty entries",
	)
	var a: Dictionary = _cp.load_tile(_tile_a)
	var b: Dictionary = _cp.load_tile(_tile_b)
	assert_eq(a["biome"], "forest")
	assert_eq(b["biome"], "desert")


func test_flush_dirty_empty_is_safe() -> void:
	_cp.flush_dirty()
	assert_eq(_cp.dirty_count(), 0)
	pass_test("flush_dirty with nothing dirty should not error")


func test_flush_dirty_overwrites_existing() -> void:
	_cp.save_tile(_tile_a, {"biome": "old"})
	_cp.mark_dirty(_tile_a, {"biome": "new"})
	_cp.flush_dirty()
	var loaded: Dictionary = _cp.load_tile(_tile_a)
	assert_eq(loaded["biome"], "new")


# --- _tile_path ---


func test_tile_path_format() -> void:
	var path: String = _cp._tile_path(Vector2i(3, -7))
	assert_eq(path, "user://chunks/3_-7.dat")


func test_tile_path_zero() -> void:
	var path: String = _cp._tile_path(Vector2i(0, 0))
	assert_eq(path, "user://chunks/0_0.dat")


func test_tile_path_large_coords() -> void:
	var path: String = _cp._tile_path(Vector2i(1000, -2000))
	assert_eq(path, "user://chunks/1000_-2000.dat")


# --- Multiple independent instances ---


func test_two_instances_share_filesystem() -> void:
	var cp2: RefCounted = ChunkPersistenceScript.new()
	_cp.save_tile(_tile_a, {"biome": "shared"})
	var loaded: Dictionary = cp2.load_tile(_tile_a)
	assert_eq(
		loaded["biome"],
		"shared",
		"Second instance should read what first wrote",
	)


# --- File handle closed before delete (core/C3) ---


func test_load_tile_closes_file_before_delete() -> void:
	# C3: on Windows, deleting an open file fails silently; file must be set
	# to null (closed) before DirAccess.remove_absolute is called.
	var src: String = (ChunkPersistenceScript as GDScript).source_code
	# Find "file = null" before "remove_absolute" in load_tile
	var null_idx := src.find("file = null")
	var remove_idx := src.find("DirAccess.remove_absolute")
	assert_true(null_idx >= 0, "'file = null' should exist in source")
	assert_true(remove_idx >= 0, "'DirAccess.remove_absolute' should exist in source")
	assert_true(
		null_idx < remove_idx,
		"'file = null' must appear before 'DirAccess.remove_absolute'",
	)
