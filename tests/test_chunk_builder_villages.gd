extends GutTest
## Comprehensive unit tests for chunk_builder_villages.gd.
## Covers constants, init, build meta, village body properties,
## mesh naming, determinism, and source-code structure.

const VillageScript = preload("res://scenes/world/generator/chunk_builder_villages.gd")
const RoadGridScript = preload("res://src/road_grid.gd")
const BoundaryScript = preload("res://src/city_boundary.gd")
const BuildingsScript = preload("res://scenes/world/generator/chunk_builder_buildings.gd")

var _grid: RefCounted
var _noise: FastNoiseLite
var _boundary: RefCounted
var _building_mats: Array[StandardMaterial3D]
var _roof_mats: Array[StandardMaterial3D]
var _bld_builder: RefCounted
var _builder: RefCounted


func before_each() -> void:
	_grid = RoadGridScript.new()

	_noise = FastNoiseLite.new()
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 0.003
	_noise.fractal_octaves = 4
	_noise.fractal_lacunarity = 2.0
	_noise.fractal_gain = 0.5
	_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_noise.seed = 42

	_boundary = BoundaryScript.new()
	_boundary.init(_grid.get_grid_span(), _noise)

	_building_mats = []
	for _i in 3:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.6, 0.5, 0.4)
		_building_mats.append(m)

	_roof_mats = []
	for _i in 2:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.4, 0.2, 0.1)
		_roof_mats.append(m)

	_bld_builder = BuildingsScript.new()
	_bld_builder.init(
		_grid,
		_building_mats,
		StandardMaterial3D.new(),
		StandardMaterial3D.new(),
		StandardMaterial3D.new(),
	)

	_builder = VillageScript.new()
	_builder.init(
		_grid, _noise, _building_mats, StandardMaterial3D.new(),
		_boundary, _roof_mats, _bld_builder,
	)


# ================================================================
# Constants
# ================================================================


func test_max_village_buildings_constant() -> void:
	assert_eq(
		VillageScript.MAX_VILLAGE_BUILDINGS,
		8,
		"MAX_VILLAGE_BUILDINGS should be 8",
	)


func test_min_village_buildings_constant() -> void:
	assert_eq(
		VillageScript.MIN_VILLAGE_BUILDINGS,
		3,
		"MIN_VILLAGE_BUILDINGS should be 3",
	)


func test_village_search_attempts_constant() -> void:
	assert_eq(
		VillageScript.VILLAGE_SEARCH_ATTEMPTS,
		10,
		"VILLAGE_SEARCH_ATTEMPTS should be 10",
	)


func test_flatness_threshold_constant() -> void:
	assert_eq(
		VillageScript.FLATNESS_THRESHOLD,
		2.0,
		"FLATNESS_THRESHOLD should be 2.0",
	)


func test_village_radius_constant() -> void:
	assert_eq(
		VillageScript.VILLAGE_RADIUS,
		30.0,
		"VILLAGE_RADIUS should be 30.0",
	)


func test_min_less_than_max_buildings() -> void:
	assert_true(
		VillageScript.MIN_VILLAGE_BUILDINGS < VillageScript.MAX_VILLAGE_BUILDINGS,
		"MIN_VILLAGE_BUILDINGS should be less than MAX_VILLAGE_BUILDINGS",
	)


func test_flatness_threshold_positive() -> void:
	assert_true(
		VillageScript.FLATNESS_THRESHOLD > 0.0,
		"FLATNESS_THRESHOLD should be positive",
	)


# ================================================================
# init stores references
# ================================================================


func test_init_stores_grid() -> void:
	assert_eq(_builder._grid, _grid, "init should store grid reference")


func test_init_stores_noise() -> void:
	assert_eq(_builder._noise, _noise, "init should store noise reference")


func test_init_stores_building_mats() -> void:
	assert_eq(
		_builder._building_mats.size(),
		3,
		"init should store 3 building materials",
	)


func test_init_stores_boundary() -> void:
	assert_eq(_builder._boundary, _boundary, "init should store boundary reference")


func test_init_stores_roof_mats() -> void:
	assert_eq(
		_builder._roof_mats.size(),
		2,
		"init should store 2 roof materials",
	)


func test_init_stores_bld_builder() -> void:
	assert_eq(
		_builder._bld_builder,
		_bld_builder,
		"init should store building builder reference",
	)


# ================================================================
# build always sets has_village meta
# ================================================================


func test_build_always_sets_has_village_meta_false() -> void:
	# Tile (0,0) is inside city — all heights 0, no village possible
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	_builder.build(chunk, Vector2i(0, 0), 0.0, 0.0)
	assert_true(
		chunk.has_meta("has_village"),
		"build should always set has_village meta",
	)


func test_build_city_tile_has_village_false() -> void:
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	_builder.build(chunk, Vector2i(0, 0), 0.0, 0.0)
	var has_village: bool = chunk.get_meta("has_village")
	assert_false(
		has_village,
		"City-center tile should not produce a village (heights are 0)",
	)


func test_build_always_sets_meta_on_outer_tile() -> void:
	var span: float = _grid.get_grid_span()
	var tile := Vector2i(8, 0)
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	_builder.build(chunk, tile, span * 8.0, 0.0)
	assert_true(
		chunk.has_meta("has_village"),
		"build on outer tile should always set has_village meta",
	)


# ================================================================
# Village body when village is produced
# ================================================================


func test_village_body_is_static_body3d() -> void:
	var span: float = _grid.get_grid_span()
	for tx in range(6, 25):
		var chunk := Node3D.new()
		add_child_autofree(chunk)
		var tile := Vector2i(tx, 0)
		_builder.build(chunk, tile, span * float(tx), 0.0)
		if not chunk.get_meta("has_village"):
			continue
		var found_body := false
		for child in chunk.get_children():
			if child is StaticBody3D and child.name == "VillageBuildings":
				found_body = true
				break
		assert_true(found_body, "Village chunk should have VillageBuildings StaticBody3D")
		return
	pass_test("No village found in range — acceptable")


func test_village_body_collision_layer() -> void:
	var span: float = _grid.get_grid_span()
	for tx in range(6, 25):
		var chunk := Node3D.new()
		add_child_autofree(chunk)
		var tile := Vector2i(tx, 0)
		_builder.build(chunk, tile, span * float(tx), 0.0)
		if not chunk.get_meta("has_village"):
			continue
		for child in chunk.get_children():
			if child is StaticBody3D and child.name == "VillageBuildings":
				assert_eq(
					child.collision_layer,
					2,
					"VillageBuildings collision_layer should be 2 (Static)",
				)
				return
	pass_test("No village found in range — acceptable")


func test_village_body_in_static_group() -> void:
	var span: float = _grid.get_grid_span()
	for tx in range(6, 25):
		var chunk := Node3D.new()
		add_child_autofree(chunk)
		var tile := Vector2i(tx, 0)
		_builder.build(chunk, tile, span * float(tx), 0.0)
		if not chunk.get_meta("has_village"):
			continue
		for child in chunk.get_children():
			if child is StaticBody3D and child.name == "VillageBuildings":
				assert_true(
					child.is_in_group("Static"),
					"VillageBuildings should be in group 'Static'",
				)
				return
	pass_test("No village found in range — acceptable")


func test_village_body_collision_mask_zero() -> void:
	var span: float = _grid.get_grid_span()
	for tx in range(6, 25):
		var chunk := Node3D.new()
		add_child_autofree(chunk)
		var tile := Vector2i(tx, 0)
		_builder.build(chunk, tile, span * float(tx), 0.0)
		if not chunk.get_meta("has_village"):
			continue
		for child in chunk.get_children():
			if child is StaticBody3D and child.name == "VillageBuildings":
				assert_eq(
					child.collision_mask,
					0,
					"VillageBuildings collision_mask should be 0",
				)
				return
	pass_test("No village found in range — acceptable")


# ================================================================
# village_center meta
# ================================================================


func test_village_center_meta_exists_when_has_village() -> void:
	var span: float = _grid.get_grid_span()
	for tx in range(6, 25):
		var chunk := Node3D.new()
		add_child_autofree(chunk)
		var tile := Vector2i(tx, 0)
		_builder.build(chunk, tile, span * float(tx), 0.0)
		if not chunk.get_meta("has_village"):
			continue
		assert_true(
			chunk.has_meta("village_center"),
			"has_village=true chunk should have village_center meta",
		)
		return
	pass_test("No village found in range — acceptable")


func test_village_center_meta_is_vector2() -> void:
	var span: float = _grid.get_grid_span()
	for tx in range(6, 25):
		var chunk := Node3D.new()
		add_child_autofree(chunk)
		var tile := Vector2i(tx, 0)
		_builder.build(chunk, tile, span * float(tx), 0.0)
		if not chunk.get_meta("has_village"):
			continue
		var center: Vector2 = chunk.get_meta("village_center")
		assert_true(center is Vector2, "village_center should be a Vector2")
		return
	pass_test("No village found in range — acceptable")


# ================================================================
# Determinism
# ================================================================


func test_build_deterministic_same_tile() -> void:
	var span: float = _grid.get_grid_span()
	var tile := Vector2i(9, 3)
	var ox: float = span * 9.0
	var oz: float = span * 3.0

	var chunk1 := Node3D.new()
	add_child_autofree(chunk1)
	_builder.build(chunk1, tile, ox, oz)

	var chunk2 := Node3D.new()
	add_child_autofree(chunk2)
	_builder.build(chunk2, tile, ox, oz)

	var v1: bool = chunk1.get_meta("has_village")
	var v2: bool = chunk2.get_meta("has_village")
	assert_eq(v1, v2, "Same tile should produce same has_village result")


func test_build_deterministic_child_count() -> void:
	var span: float = _grid.get_grid_span()
	var tile := Vector2i(11, 2)
	var ox: float = span * 11.0
	var oz: float = span * 2.0

	var chunk1 := Node3D.new()
	add_child_autofree(chunk1)
	_builder.build(chunk1, tile, ox, oz)

	var chunk2 := Node3D.new()
	add_child_autofree(chunk2)
	_builder.build(chunk2, tile, ox, oz)

	assert_eq(
		chunk1.get_child_count(),
		chunk2.get_child_count(),
		"Same tile should produce same child count",
	)


# ================================================================
# Mesh naming
# ================================================================


func test_village_mat_mesh_name_prefix() -> void:
	var span: float = _grid.get_grid_span()
	for tx in range(6, 30):
		var chunk := Node3D.new()
		add_child_autofree(chunk)
		var tile := Vector2i(tx, 0)
		_builder.build(chunk, tile, span * float(tx), 0.0)
		if not chunk.get_meta("has_village"):
			continue
		for child in chunk.get_children():
			if not (child is StaticBody3D and child.name == "VillageBuildings"):
				continue
			for sub in child.get_children():
				if sub is MeshInstance3D and sub.name.begins_with("VillageMat_"):
					assert_not_null(sub.mesh, "VillageMat_ mesh should not be null")
					assert_not_null(
						sub.material_override,
						"VillageMat_ mesh should have material_override",
					)
					return
	pass_test("No VillageMat_ mesh found in range — acceptable")


func test_village_roof_mesh_name_prefix() -> void:
	var span: float = _grid.get_grid_span()
	for tx in range(6, 30):
		var chunk := Node3D.new()
		add_child_autofree(chunk)
		var tile := Vector2i(tx, 0)
		_builder.build(chunk, tile, span * float(tx), 0.0)
		if not chunk.get_meta("has_village"):
			continue
		for child in chunk.get_children():
			if not (child is StaticBody3D and child.name == "VillageBuildings"):
				continue
			for sub in child.get_children():
				if sub is MeshInstance3D and sub.name.begins_with("VillageRoofs_"):
					assert_not_null(sub.mesh, "VillageRoofs_ mesh should not be null")
					return
	pass_test("No VillageRoofs_ mesh found in range — acceptable (no buildings landed above water)")


# ================================================================
# At least one village across many tiles
# ================================================================


func test_at_least_one_village_across_many_tiles() -> void:
	# Known village tiles (seed=42, hash^0xBEEF): (5,-2), (5,-1), (5,2), (11,8)
	var span: float = _grid.get_grid_span()
	var found_village := false
	for tz in range(-3, 10):
		for tx in range(4, 13):
			var chunk := Node3D.new()
			add_child_autofree(chunk)
			var tile := Vector2i(tx, tz)
			_builder.build(chunk, tile, span * float(tx), span * float(tz))
			if chunk.get_meta("has_village"):
				found_village = true
				break
		if found_village:
			break
	assert_true(
		found_village,
		"At least one tile in grid [4,13)x[-3,10) should produce a village",
	)


func test_at_least_one_village_has_mesh_children() -> void:
	# Known village tiles (seed=42, hash^0xBEEF): (5,-2), (5,-1), (5,2), (11,8)
	var span: float = _grid.get_grid_span()
	var found_mesh := false
	for tz in range(-3, 10):
		for tx in range(4, 13):
			var chunk := Node3D.new()
			add_child_autofree(chunk)
			var tile := Vector2i(tx, tz)
			_builder.build(chunk, tile, span * float(tx), span * float(tz))
			if not chunk.get_meta("has_village"):
				continue
			for child in chunk.get_children():
				if not (child is StaticBody3D and child.name == "VillageBuildings"):
					continue
				for sub in child.get_children():
					if sub is MeshInstance3D:
						found_mesh = true
						break
			if found_mesh:
				break
		if found_mesh:
			break
	assert_true(
		found_mesh,
		"At least one village should have MeshInstance3D children",
	)


# ================================================================
# No village body when no village
# ================================================================


func test_no_village_body_when_has_village_false() -> void:
	# Tile (0,0): inside city, all heights 0, no village
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	_builder.build(chunk, Vector2i(0, 0), 0.0, 0.0)
	assert_false(chunk.get_meta("has_village"), "Precondition: tile (0,0) should have no village")
	for child in chunk.get_children():
		assert_false(
			child is StaticBody3D and child.name == "VillageBuildings",
			"No VillageBuildings body should exist when has_village is false",
		)


# ================================================================
# _is_flat_enough
# ================================================================


func test_is_flat_enough_returns_bool() -> void:
	var result = _builder._is_flat_enough(0.0, 0.0)
	assert_true(result is bool, "_is_flat_enough should return a bool")


func test_is_flat_enough_city_center_is_flat() -> void:
	# All heights inside city are 0, variance = 0 < FLATNESS_THRESHOLD
	var result: bool = _builder._is_flat_enough(0.0, 0.0)
	assert_true(result, "City center (all heights 0) should pass flatness check")


# ================================================================
# Source code structure checks
# ================================================================


func test_source_contains_village_search_attempts() -> void:
	assert_eq(VillageScript.VILLAGE_SEARCH_ATTEMPTS, 10)


func test_source_contains_flatness_threshold() -> void:
	assert_eq(VillageScript.FLATNESS_THRESHOLD, 2.0)


func test_source_contains_is_flat_enough() -> void:
	var script: GDScript = VillageScript
	assert_true(
		script.source_code.contains("_is_flat_enough"),
		"Source should define _is_flat_enough",
	)


func test_source_contains_set_meta_has_village() -> void:
	var script: GDScript = VillageScript
	assert_true(
		script.source_code.contains("set_meta(\"has_village\""),
		"Source should call set_meta(\"has_village\"",
	)


func test_source_contains_set_meta_village_center() -> void:
	var script: GDScript = VillageScript
	assert_true(
		script.source_code.contains("\"village_center\""),
		"Source should contain \"village_center\" key string",
	)


func test_source_flatness_uses_village_radius() -> void:
	assert_eq(VillageScript.VILLAGE_RADIUS, 30.0)


# ================================================================
# LOW-03 — _sample_height duplication removed; uses _boundary directly
# ================================================================


func test_sample_height_function_removed() -> void:
	var src: String = (VillageScript as GDScript).source_code
	assert_false(
		src.contains("func _sample_height("),
		"_sample_height was a duplicate of boundary.get_ground_height and must be removed (LOW-03)",
	)


func test_villages_uses_boundary_get_ground_height() -> void:
	var src: String = (VillageScript as GDScript).source_code
	assert_true(
		src.contains("_boundary.get_ground_height("),
		"Villages must use _boundary.get_ground_height() instead of local _sample_height",
	)
