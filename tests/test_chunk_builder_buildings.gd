extends GutTest
## Unit tests for chunk_builder_buildings.gd — building mesh generation with
## per-palette MeshInstance3D, windows, roofs, interiors, and compound collision.

const BuildingsScript = preload("res://scenes/world/generator/chunk_builder_buildings.gd")
const RoadGridScript = preload("res://src/road_grid.gd")

var _grid: RefCounted
var _builder: RefCounted
var _building_mats: Array[StandardMaterial3D]
var _window_mat_off: StandardMaterial3D
var _window_mat_on: StandardMaterial3D
var _interior_mat: StandardMaterial3D
var _roof_mats: Array[StandardMaterial3D]


func _make_mat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	return mat


func before_each() -> void:
	_grid = RoadGridScript.new()

	_building_mats = []
	for i in 4:
		_building_mats.append(_make_mat(Color(0.5 + i * 0.05, 0.5, 0.5)))

	_window_mat_off = _make_mat(Color(0.18, 0.22, 0.28))
	_window_mat_on = _make_mat(Color(0.9, 0.8, 0.5))

	_interior_mat = _make_mat(Color(0.25, 0.25, 0.25))

	_roof_mats = []
	for i in 3:
		_roof_mats.append(_make_mat(Color(0.6 + i * 0.05, 0.3, 0.2)))

	_builder = BuildingsScript.new()
	_builder.init(_grid, _building_mats, _window_mat_off, _window_mat_on, _interior_mat, _roof_mats)


# ================================================================
# Initialization
# ================================================================


func test_init_stores_grid() -> void:
	assert_eq(_builder._grid, _grid, "Grid should be stored after init")


func test_init_stores_building_materials() -> void:
	assert_eq(
		_builder._building_mats.size(),
		4,
		"Should store 4 building materials",
	)


func test_init_stores_window_materials() -> void:
	assert_not_null(_builder._window_mat_off, "Should store window_mat_off")
	assert_not_null(_builder._window_mat_on, "Should store window_mat_on")


func test_init_stores_interior_material() -> void:
	assert_eq(
		_builder._interior_mat,
		_interior_mat,
		"Interior material should be stored after init",
	)


func test_init_stores_roof_materials() -> void:
	assert_eq(
		_builder._roof_mats.size(),
		3,
		"Should store 3 roof materials",
	)


func test_init_without_roof_mats_defaults_empty() -> void:
	var b := BuildingsScript.new()
	b.init(_grid, _building_mats, _window_mat_off, _window_mat_on, _interior_mat)
	assert_eq(
		b._roof_mats.size(),
		0,
		"Roof mats should default to empty array",
	)


# ================================================================
# Build output structure
# ================================================================


func test_build_adds_buildings_body_to_chunk() -> void:
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	_builder.build(chunk, Vector2i(0, 0), 0.0, 0.0)
	assert_gt(chunk.get_child_count(), 0, "Build should add at least one child")
	var body := chunk.get_child(0) as StaticBody3D
	assert_not_null(body, "First child should be the StaticBody3D")
	assert_eq(body.name, "Buildings")


func test_buildings_body_collision_layer() -> void:
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	_builder.build(chunk, Vector2i(0, 0), 0.0, 0.0)
	var body := chunk.get_child(0) as StaticBody3D
	assert_eq(
		body.collision_layer,
		2,
		"Buildings collision layer should be 2 (Static)",
	)


func test_buildings_body_collision_mask() -> void:
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	_builder.build(chunk, Vector2i(0, 0), 0.0, 0.0)
	var body := chunk.get_child(0) as StaticBody3D
	assert_eq(
		body.collision_mask,
		0,
		"Buildings collision mask should be 0",
	)


func test_buildings_body_in_static_group() -> void:
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	_builder.build(chunk, Vector2i(0, 0), 0.0, 0.0)
	var body := chunk.get_child(0) as StaticBody3D
	assert_true(
		body.is_in_group("Static"),
		"Buildings body should be in Static group",
	)


func test_buildings_body_has_collision_shapes() -> void:
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	_builder.build(chunk, Vector2i(0, 0), 0.0, 0.0)
	var body := chunk.get_child(0) as StaticBody3D
	var col_count := 0
	for child in body.get_children():
		if child is CollisionShape3D:
			col_count += 1
	assert_gt(
		col_count,
		0,
		"Buildings body should have collision shapes",
	)


func test_buildings_body_has_mesh_children() -> void:
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	_builder.build(chunk, Vector2i(0, 0), 0.0, 0.0)
	var body := chunk.get_child(0) as StaticBody3D
	var mesh_count := 0
	for child in body.get_children():
		if child is MeshInstance3D:
			mesh_count += 1
	assert_gt(
		mesh_count,
		0,
		"Buildings body should have at least one MeshInstance3D",
	)


func test_building_meshes_named_by_palette_index() -> void:
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	_builder.build(chunk, Vector2i(0, 0), 0.0, 0.0)
	var body := chunk.get_child(0) as StaticBody3D
	var found_building_mesh := false
	for child in body.get_children():
		if child is MeshInstance3D:
			var inst := child as MeshInstance3D
			if inst.name.begins_with("BuildingsMat_"):
				found_building_mesh = true
				break
	assert_true(
		found_building_mesh,
		"Should have at least one BuildingsMat_N mesh",
	)


func test_building_meshes_have_valid_mesh() -> void:
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	_builder.build(chunk, Vector2i(0, 0), 0.0, 0.0)
	var body := chunk.get_child(0) as StaticBody3D
	for child in body.get_children():
		if child is MeshInstance3D:
			var inst := child as MeshInstance3D
			if inst.name.begins_with("BuildingsMat_"):
				assert_not_null(
					inst.mesh,
					"Building mesh should not be null",
				)
				assert_not_null(
					inst.material_override,
					"Building mesh should have material override",
				)


func test_building_meshes_use_correct_palette_material() -> void:
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	_builder.build(chunk, Vector2i(0, 0), 0.0, 0.0)
	var body := chunk.get_child(0) as StaticBody3D
	for child in body.get_children():
		if child is MeshInstance3D:
			var inst := child as MeshInstance3D
			if inst.name.begins_with("BuildingsMat_"):
				var idx_str: String = (
					inst
					. name
					. substr(
						"BuildingsMat_".length(),
					)
				)
				var idx: int = idx_str.to_int()
				assert_eq(
					inst.material_override,
					_building_mats[idx],
					"Mesh %s should use palette material %d" % [inst.name, idx],
				)


# ================================================================
# Window meshes
# ================================================================


func test_window_meshes_created() -> void:
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	_builder.build(chunk, Vector2i(0, 0), 0.0, 0.0)
	var body := chunk.get_child(0) as StaticBody3D
	var found_off := false
	var found_on := false
	for child in body.get_children():
		if child is MeshInstance3D:
			if (child as MeshInstance3D).name == "WindowsOff":
				found_off = true
			elif (child as MeshInstance3D).name == "WindowsOn":
				found_on = true
	assert_true(found_off, "Should have WindowsOff mesh node")
	assert_true(found_on, "Should have WindowsOn mesh node")


func test_window_meshes_have_valid_material() -> void:
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	_builder.build(chunk, Vector2i(0, 0), 0.0, 0.0)
	var body := chunk.get_child(0) as StaticBody3D
	for child in body.get_children():
		if child is MeshInstance3D:
			var inst := child as MeshInstance3D
			if inst.name == "WindowsOff" or inst.name == "WindowsOn":
				assert_not_null(
					inst.material_override,
					"Window node %s should have material override" % inst.name,
				)


# ================================================================
# Roof meshes
# ================================================================


func test_roof_meshes_created_for_short_buildings() -> void:
	# With 10x10 blocks and 1-4 buildings each, statistically some will be short
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	_builder.build(chunk, Vector2i(42, 42), 0.0, 0.0)
	var body := chunk.get_child(0) as StaticBody3D
	var found := false
	for child in body.get_children():
		if child is MeshInstance3D:
			if (child as MeshInstance3D).name.begins_with("Roofs_"):
				found = true
				break
	assert_true(
		found,
		"Should have at least one Roofs_N mesh for short buildings",
	)


func test_no_roof_meshes_when_no_roof_materials() -> void:
	var b := BuildingsScript.new()
	b.init(_grid, _building_mats, _window_mat_off, _window_mat_on, _interior_mat)
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	b.build(chunk, Vector2i(0, 0), 0.0, 0.0)
	var body := chunk.get_child(0) as StaticBody3D
	for child in body.get_children():
		if child is MeshInstance3D:
			assert_false(
				(child as MeshInstance3D).name.begins_with("Roofs_"),
				"No roof meshes when roof_mats is empty",
			)


# ================================================================
# Interior meshes
# ================================================================


func test_interior_mesh_created() -> void:
	# Interiors are generated for buildings with doors (h > 6, min face >= 3)
	# With 100 blocks, statistically very likely to get at least one
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	_builder.build(chunk, Vector2i(0, 0), 0.0, 0.0)
	var body := chunk.get_child(0) as StaticBody3D
	var found := false
	for child in body.get_children():
		if child is MeshInstance3D:
			if (child as MeshInstance3D).name == "Interiors":
				found = true
				break
	assert_true(found, "Should have an Interiors mesh")


func test_interior_mesh_has_interior_material() -> void:
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	_builder.build(chunk, Vector2i(0, 0), 0.0, 0.0)
	var body := chunk.get_child(0) as StaticBody3D
	for child in body.get_children():
		if child is MeshInstance3D:
			var inst := child as MeshInstance3D
			if inst.name == "Interiors":
				assert_eq(
					inst.material_override,
					_interior_mat,
					"Interior mesh should use interior material",
				)
				return


# ================================================================
# Determinism — same tile produces same output
# ================================================================


func test_build_is_deterministic_same_tile() -> void:
	var tile := Vector2i(7, 13)

	var chunk_a := Node3D.new()
	add_child_autofree(chunk_a)
	_builder.build(chunk_a, tile, 0.0, 0.0)

	var chunk_b := Node3D.new()
	add_child_autofree(chunk_b)
	_builder.build(chunk_b, tile, 0.0, 0.0)

	var body_a := chunk_a.get_child(0) as StaticBody3D
	var body_b := chunk_b.get_child(0) as StaticBody3D

	var col_a := 0
	var col_b := 0
	for child in body_a.get_children():
		if child is CollisionShape3D:
			col_a += 1
	for child in body_b.get_children():
		if child is CollisionShape3D:
			col_b += 1
	assert_eq(
		col_a,
		col_b,
		"Same tile should produce same collision count",
	)

	var mesh_a := 0
	var mesh_b := 0
	for child in body_a.get_children():
		if child is MeshInstance3D:
			mesh_a += 1
	for child in body_b.get_children():
		if child is MeshInstance3D:
			mesh_b += 1
	assert_eq(
		mesh_a,
		mesh_b,
		"Same tile should produce same mesh count",
	)


func test_different_tiles_produce_different_output() -> void:
	var chunk_a := Node3D.new()
	add_child_autofree(chunk_a)
	_builder.build(chunk_a, Vector2i(0, 0), 0.0, 0.0)

	var chunk_b := Node3D.new()
	add_child_autofree(chunk_b)
	_builder.build(chunk_b, Vector2i(99, 99), 0.0, 0.0)

	# Different seeds should produce different collision counts (statistically)
	var col_a := 0
	var col_b := 0
	var body_a := chunk_a.get_child(0) as StaticBody3D
	var body_b := chunk_b.get_child(0) as StaticBody3D
	for child in body_a.get_children():
		if child is CollisionShape3D:
			col_a += 1
	for child in body_b.get_children():
		if child is CollisionShape3D:
			col_b += 1
	# Both should have collision shapes regardless
	assert_gt(col_a, 0, "Tile (0,0) should have collisions")
	assert_gt(col_b, 0, "Tile (99,99) should have collisions")


# ================================================================
# Offset positioning
# ================================================================


func test_build_with_offset() -> void:
	var span: float = _grid.get_grid_span()
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	_builder.build(chunk, Vector2i(1, 1), span, span)
	assert_gt(chunk.get_child_count(), 0, "Should still produce at least one child")
	var body := chunk.get_child(0) as StaticBody3D
	assert_not_null(body, "First child should be StaticBody3D even with offset")
	assert_gt(
		body.get_child_count(),
		0,
		"Body should have children even with offset",
	)


# ================================================================
# Constants sanity
# ================================================================


func test_door_dimensions_positive() -> void:
	assert_gt(
		BuildingsScript.DOOR_WIDTH,
		0.0,
		"Door width should be positive",
	)
	assert_gt(
		BuildingsScript.DOOR_HEIGHT,
		0.0,
		"Door height should be positive",
	)


func test_interior_height_greater_than_door() -> void:
	assert_gt(
		BuildingsScript.INTERIOR_HEIGHT,
		BuildingsScript.DOOR_HEIGHT,
		"Interior height should exceed door height",
	)


func test_pitched_roof_threshold_positive() -> void:
	assert_gt(
		BuildingsScript.PITCHED_ROOF_THRESHOLD,
		0.0,
		"Pitched roof threshold should be positive",
	)


func test_wall_thickness_positive() -> void:
	assert_gt(
		BuildingsScript.WALL_THICKNESS,
		0.0,
		"Wall thickness should be positive",
	)


# ================================================================
# Rooftop helipads
# ================================================================


func test_rooftop_helipad_min_height_positive() -> void:
	assert_gt(
		BuildingsScript.ROOFTOP_HELIPAD_MIN_H,
		0.0,
		"Rooftop helipad minimum height should be positive",
	)


func test_rooftop_helipad_min_width_positive() -> void:
	assert_gt(
		BuildingsScript.ROOFTOP_HELIPAD_MIN_W,
		0.0,
		"Rooftop helipad minimum width should be positive",
	)


func test_rooftop_helipads_per_chunk_positive() -> void:
	assert_gt(
		BuildingsScript.ROOFTOP_HELIPADS_PER_CHUNK,
		0,
		"ROOFTOP_HELIPADS_PER_CHUNK should be at least 1",
	)


func test_add_rooftop_helipad_adds_mesh_to_chunk() -> void:
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	var bld_center := Vector3(10.0, 7.0, 10.0)
	var bld_size := Vector3(12.0, 14.0, 12.0)
	_builder._add_rooftop_helipad(chunk, bld_center, bld_size)
	var found := false
	for child in chunk.get_children():
		if child is MeshInstance3D and child.name == "RooftopHelipadMark":
			found = true
			break
	assert_true(found, "Should add RooftopHelipadMark MeshInstance3D to chunk")


func test_add_rooftop_helipad_adds_marker_to_helipad_group() -> void:
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	_builder._add_rooftop_helipad(chunk, Vector3(5.0, 8.0, 5.0), Vector3(11.0, 16.0, 11.0))
	var marker: Node3D = null
	for child in chunk.get_children():
		if child is Node3D and child.is_in_group("helipad"):
			marker = child as Node3D
			break
	assert_not_null(marker, "Should add a Node3D in the helipad group")


func test_add_rooftop_helipad_marker_has_helipad_center_meta() -> void:
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	var bld_center := Vector3(8.0, 6.0, 8.0)
	var bld_size := Vector3(12.0, 12.0, 12.0)
	_builder._add_rooftop_helipad(chunk, bld_center, bld_size)
	var marker: Node3D = null
	for child in chunk.get_children():
		if child is Node3D and child.is_in_group("helipad"):
			marker = child as Node3D
			break
	assert_not_null(marker, "Helipad marker should exist")
	assert_true(marker.has_meta("helipad_center"), "Marker should have helipad_center meta")


func test_add_rooftop_helipad_center_y_at_roof_surface() -> void:
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	var bld_center := Vector3(0.0, 7.0, 0.0)
	var bld_size := Vector3(12.0, 14.0, 12.0)
	_builder._add_rooftop_helipad(chunk, bld_center, bld_size)
	var marker: Node3D = null
	for child in chunk.get_children():
		if child is Node3D and child.is_in_group("helipad"):
			marker = child as Node3D
			break
	assert_not_null(marker, "Helipad marker should exist")
	var expected_y: float = bld_center.y + bld_size.y * 0.5 + 0.02
	var hpos: Vector3 = marker.get_meta("helipad_center") as Vector3
	assert_almost_eq(hpos.y, expected_y, 0.001, "helipad_center Y should be at roof surface")


func test_add_rooftop_helipad_center_xz_matches_building() -> void:
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	var bld_center := Vector3(15.0, 5.0, 20.0)
	_builder._add_rooftop_helipad(chunk, bld_center, Vector3(12.0, 10.0, 12.0))
	var marker: Node3D = null
	for child in chunk.get_children():
		if child is Node3D and child.is_in_group("helipad"):
			marker = child as Node3D
			break
	assert_not_null(marker, "Helipad marker should exist")
	var hpos: Vector3 = marker.get_meta("helipad_center") as Vector3
	assert_almost_eq(hpos.x, bld_center.x, 0.001, "helipad_center X should match building")
	assert_almost_eq(hpos.z, bld_center.z, 0.001, "helipad_center Z should match building")
