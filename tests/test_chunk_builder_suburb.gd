extends GutTest
## Unit tests for chunk_builder_suburb.gd suburb building generation.

const SuburbScript = preload(
	"res://scenes/world/generator/chunk_builder_suburb.gd"
)
const RoadGridScript = preload("res://src/road_grid.gd")
const BuildingsScript = preload(
	"res://scenes/world/generator/chunk_builder_buildings.gd"
)

var _grid: RefCounted
var _builder: RefCounted
var _building_mats: Array[StandardMaterial3D]
var _roof_mats: Array[StandardMaterial3D]
var _bld_builder: RefCounted


func before_each() -> void:
	_grid = RoadGridScript.new()

	_building_mats = []
	for _i in 3:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(
			randf_range(0.3, 0.8),
			randf_range(0.3, 0.8),
			randf_range(0.3, 0.8),
		)
		_building_mats.append(m)

	_roof_mats = []
	for _i in 2:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.6, 0.2, 0.1)
		_roof_mats.append(m)

	_bld_builder = BuildingsScript.new()

	_builder = SuburbScript.new()
	_builder.init(_grid, _building_mats, _roof_mats, _bld_builder)


# ================================================================
# Initialization
# ================================================================

func test_init_stores_grid() -> void:
	assert_eq(_builder._grid, _grid, "init should store grid reference")


func test_init_stores_building_mats() -> void:
	assert_eq(
		_builder._building_mats.size(), 3,
		"init should store building materials",
	)


func test_init_stores_roof_mats() -> void:
	assert_eq(
		_builder._roof_mats.size(), 2,
		"init should store roof materials",
	)


func test_init_stores_bld_builder() -> void:
	assert_eq(
		_builder._bld_builder, _bld_builder,
		"init should store building builder reference",
	)


# ================================================================
# Constants
# ================================================================

func test_max_buildings_per_block() -> void:
	assert_eq(
		SuburbScript.MAX_BUILDINGS_PER_BLOCK, 2,
		"MAX_BUILDINGS_PER_BLOCK should be 2",
	)


func test_height_range_valid() -> void:
	assert_true(
		SuburbScript.MIN_HEIGHT < SuburbScript.MAX_HEIGHT,
		"MIN_HEIGHT should be less than MAX_HEIGHT",
	)


func test_min_height_positive() -> void:
	assert_true(
		SuburbScript.MIN_HEIGHT > 0.0,
		"MIN_HEIGHT should be positive",
	)


# ================================================================
# _get_block_center
# ================================================================

func test_get_block_center_returns_vector2() -> void:
	var center: Vector2 = _builder._get_block_center(0, 0)
	assert_true(
		center is Vector2,
		"_get_block_center should return Vector2",
	)


func test_get_block_center_different_for_different_blocks() -> void:
	var c1: Vector2 = _builder._get_block_center(0, 0)
	var c2: Vector2 = _builder._get_block_center(5, 5)
	assert_ne(c1, c2, "Different blocks should have different centers")


func test_get_block_center_within_grid_span() -> void:
	var span: float = _grid.get_grid_span()
	for bx in range(_grid.GRID_SIZE):
		for bz in range(_grid.GRID_SIZE):
			var center: Vector2 = _builder._get_block_center(bx, bz)
			assert_true(
				absf(center.x) < span,
				"Block center X should be within grid span",
			)
			assert_true(
				absf(center.y) < span,
				"Block center Y should be within grid span",
			)


# ================================================================
# Build behavior
# ================================================================

func test_build_creates_suburb_body() -> void:
	var span: float = _grid.get_grid_span()
	# Try several tiles; ~50% block chance means most tiles produce something
	var found_body := false
	for tx in range(20):
		var tile := Vector2i(tx + 50, tx * 3)
		var chunk := Node3D.new()
		add_child_autofree(chunk)
		_builder.build(
			chunk, tile,
			span * float(tile.x), span * float(tile.y),
		)
		for child in chunk.get_children():
			if child is StaticBody3D and child.name == "SuburbBuildings":
				found_body = true
				assert_eq(
					child.collision_layer, 2,
					"Suburb body collision layer should be Static (2)",
				)
				assert_true(
					child.is_in_group("Static"),
					"Suburb body should be in Static group",
				)
				break
		if found_body:
			break
	assert_true(found_body, "At least one tile should produce SuburbBuildings")


func test_build_creates_material_meshes() -> void:
	var span: float = _grid.get_grid_span()
	var found_mesh := false
	for tx in range(20):
		var tile := Vector2i(tx + 50, tx * 3)
		var chunk := Node3D.new()
		add_child_autofree(chunk)
		_builder.build(
			chunk, tile,
			span * float(tile.x), span * float(tile.y),
		)
		for child in chunk.get_children():
			if child is StaticBody3D and child.name == "SuburbBuildings":
				for sub in child.get_children():
					if sub is MeshInstance3D and sub.name.begins_with("SuburbMat_"):
						found_mesh = true
						assert_not_null(
							sub.mesh, "Suburb mesh should not be null",
						)
						assert_not_null(
							sub.material_override,
							"Suburb mesh should have material override",
						)
				break
		if found_mesh:
			break
	assert_true(found_mesh, "At least one tile should produce SuburbMat_ meshes")


func test_build_creates_roof_meshes() -> void:
	var span: float = _grid.get_grid_span()
	var found_roof := false
	for tx in range(20):
		var tile := Vector2i(tx + 50, tx * 3)
		var chunk := Node3D.new()
		add_child_autofree(chunk)
		_builder.build(
			chunk, tile,
			span * float(tile.x), span * float(tile.y),
		)
		for child in chunk.get_children():
			if child is StaticBody3D and child.name == "SuburbBuildings":
				for sub in child.get_children():
					if sub is MeshInstance3D and sub.name.begins_with("SuburbRoofs_"):
						found_roof = true
						assert_not_null(
							sub.mesh, "Roof mesh should not be null",
						)
				break
		if found_roof:
			break
	assert_true(found_roof, "At least one tile should produce SuburbRoofs_ meshes")


func test_build_has_collision_shapes() -> void:
	var span: float = _grid.get_grid_span()
	for tx in range(20):
		var tile := Vector2i(tx + 50, tx * 3)
		var chunk := Node3D.new()
		add_child_autofree(chunk)
		_builder.build(
			chunk, tile,
			span * float(tile.x), span * float(tile.y),
		)
		for child in chunk.get_children():
			if child is StaticBody3D and child.name == "SuburbBuildings":
				var col_count := 0
				for sub in child.get_children():
					if sub is CollisionShape3D:
						col_count += 1
						assert_true(
							sub.shape is BoxShape3D,
							"Building collision should be BoxShape3D",
						)
				assert_true(
					col_count > 0,
					"SuburbBuildings should have collision shapes",
				)
				return
	pass_test("No suburb buildings found in range")


# ================================================================
# Determinism
# ================================================================

func test_build_deterministic() -> void:
	var span: float = _grid.get_grid_span()
	var tile := Vector2i(55, 10)
	var ox: float = span * 55.0
	var oz: float = span * 10.0

	var chunk1 := Node3D.new()
	add_child_autofree(chunk1)
	_builder.build(chunk1, tile, ox, oz)

	var chunk2 := Node3D.new()
	add_child_autofree(chunk2)
	_builder.build(chunk2, tile, ox, oz)

	assert_eq(
		chunk1.get_child_count(), chunk2.get_child_count(),
		"Same tile should produce same child count",
	)

	# Compare collision shape counts
	var cols1 := _count_collision_shapes(chunk1)
	var cols2 := _count_collision_shapes(chunk2)
	assert_eq(cols1, cols2, "Same tile should produce same collision count")


func _count_collision_shapes(chunk: Node3D) -> int:
	var count := 0
	for child in chunk.get_children():
		if child is StaticBody3D:
			for sub in child.get_children():
				if sub is CollisionShape3D:
					count += 1
	return count


# ================================================================
# ~50% block occupancy (probabilistic)
# ================================================================

func test_roughly_half_blocks_have_buildings() -> void:
	# With GRID_SIZE=10 -> 100 blocks, ~50% = ~50 occupied
	# Across a few tiles we can check collision shape counts are reasonable
	var span: float = _grid.get_grid_span()
	var total_cols := 0
	var tile_count := 5
	for tx in range(tile_count):
		var tile := Vector2i(tx + 100, tx * 7)
		var chunk := Node3D.new()
		add_child_autofree(chunk)
		_builder.build(
			chunk, tile,
			span * float(tile.x), span * float(tile.y),
		)
		total_cols += _count_collision_shapes(chunk)

	# 5 tiles * ~50 blocks * ~1.5 buildings avg = ~375 expected
	# Allow wide range [10, 1000]
	assert_true(
		total_cols > 10,
		"5 tiles should produce more than 10 collision shapes, got %d" % total_cols,
	)
	assert_true(
		total_cols < 1000,
		"5 tiles should produce fewer than 1000 collision shapes, got %d" % total_cols,
	)


# ================================================================
# No buildings without materials
# ================================================================

func test_build_with_no_roof_mats() -> void:
	var no_roof_builder := SuburbScript.new()
	var empty_roof_mats: Array[StandardMaterial3D] = []
	no_roof_builder.init(_grid, _building_mats, empty_roof_mats, _bld_builder)

	var span: float = _grid.get_grid_span()
	var tile := Vector2i(55, 10)
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	no_roof_builder.build(chunk, tile, span * 55.0, span * 10.0)

	# Should still work, just no roof meshes
	var found_roof := false
	for child in chunk.get_children():
		if child is StaticBody3D:
			for sub in child.get_children():
				if sub is MeshInstance3D and sub.name.begins_with("SuburbRoofs_"):
					found_roof = true
	assert_false(found_roof, "No roof mats should produce no roof meshes")


func test_build_with_null_bld_builder() -> void:
	var null_builder := SuburbScript.new()
	null_builder.init(_grid, _building_mats, _roof_mats, null)

	var span: float = _grid.get_grid_span()
	var tile := Vector2i(55, 10)
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	null_builder.build(chunk, tile, span * 55.0, span * 10.0)

	# Should still produce buildings, just no roofs
	# (the code checks `if roof_count > 0 and _bld_builder:`)
	var found_roof := false
	for child in chunk.get_children():
		if child is StaticBody3D:
			for sub in child.get_children():
				if sub is MeshInstance3D and sub.name.begins_with("SuburbRoofs_"):
					found_roof = true
	assert_false(
		found_roof,
		"Null bld_builder should produce no roof meshes",
	)
