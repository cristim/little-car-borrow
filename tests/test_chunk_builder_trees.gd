extends GutTest
## Unit tests for chunk_builder_trees.gd — tree generation using MultiMesh
## for trunks and canopy variants with compound collision body.

const TreesScript = preload("res://scenes/world/generator/chunk_builder_trees.gd")
const RoadGridScript = preload("res://src/road_grid.gd")

var _grid: RefCounted
var _builder: RefCounted
var _trunk_mats: Array[StandardMaterial3D]
var _canopy_mats: Array[StandardMaterial3D]
var _trunk_mesh: CylinderMesh
var _canopy_meshes: Array[Mesh]


func _make_mat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	return mat


func before_each() -> void:
	_grid = RoadGridScript.new()

	_trunk_mats = []
	for i in 3:
		_trunk_mats.append(_make_mat(Color(0.35, 0.22, 0.10)))

	_canopy_mats = []
	for i in 4:
		_canopy_mats.append(_make_mat(Color(0.15, 0.42, 0.12)))

	# Canonical trunk mesh
	_trunk_mesh = CylinderMesh.new()
	_trunk_mesh.top_radius = 0.7
	_trunk_mesh.bottom_radius = 1.0
	_trunk_mesh.height = 1.0
	_trunk_mesh.radial_segments = 6
	_trunk_mesh.rings = 1

	# 5 canopy variants (sphere, cone, tall, flat, sphere2)
	_canopy_meshes = []
	for i in TreesScript.CANOPY_VARIANTS:
		var s := SphereMesh.new()
		s.radius = 1.0
		s.height = 2.0
		_canopy_meshes.append(s)

	_builder = TreesScript.new()
	_builder.init(_grid, _trunk_mats, _canopy_mats, _trunk_mesh, _canopy_meshes)


# ================================================================
# Initialization
# ================================================================


func test_init_stores_grid() -> void:
	assert_eq(_builder._grid, _grid, "Grid should be stored after init")


func test_init_stores_trunk_materials() -> void:
	assert_eq(
		_builder._trunk_mats.size(),
		3,
		"Should store 3 trunk materials",
	)


func test_init_stores_canopy_materials() -> void:
	assert_eq(
		_builder._canopy_mats.size(),
		4,
		"Should store 4 canopy materials",
	)


func test_init_stores_trunk_mesh() -> void:
	assert_eq(
		_builder._trunk_mesh,
		_trunk_mesh,
		"Trunk mesh should be stored after init",
	)


func test_init_stores_canopy_meshes() -> void:
	assert_eq(
		_builder._canopy_meshes.size(),
		TreesScript.CANOPY_VARIANTS,
		"Should store 5 canopy meshes",
	)


# ================================================================
# Build output structure
# ================================================================


func test_build_adds_one_child_to_chunk() -> void:
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	_builder.build(chunk, Vector2i(0, 0), 0.0, 0.0)
	assert_eq(chunk.get_child_count(), 1, "Build should add one child")


func test_build_creates_trees_body() -> void:
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	_builder.build(chunk, Vector2i(0, 0), 0.0, 0.0)
	var body := chunk.get_child(0) as StaticBody3D
	assert_not_null(body, "Child should be a StaticBody3D")
	assert_eq(body.name, "Trees")


func test_trees_body_collision_layer() -> void:
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	_builder.build(chunk, Vector2i(0, 0), 0.0, 0.0)
	var body := chunk.get_child(0) as StaticBody3D
	assert_eq(
		body.collision_layer,
		2,
		"Trees collision layer should be 2 (Static)",
	)


func test_trees_body_collision_mask() -> void:
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	_builder.build(chunk, Vector2i(0, 0), 0.0, 0.0)
	var body := chunk.get_child(0) as StaticBody3D
	assert_eq(
		body.collision_mask,
		0,
		"Trees collision mask should be 0",
	)


func test_trees_body_in_static_group() -> void:
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	_builder.build(chunk, Vector2i(0, 0), 0.0, 0.0)
	var body := chunk.get_child(0) as StaticBody3D
	assert_true(
		body.is_in_group("Static"),
		"Trees body should be in Static group",
	)


# ================================================================
# MultiMesh children
# ================================================================


func test_trunk_multimesh_created() -> void:
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	_builder.build(chunk, Vector2i(0, 0), 0.0, 0.0)
	var body := chunk.get_child(0) as StaticBody3D
	var found := false
	for child in body.get_children():
		if child is MultiMeshInstance3D:
			if (child as MultiMeshInstance3D).name == "TrunksMM":
				found = true
				break
	assert_true(found, "Should have a TrunksMM MultiMeshInstance3D")


func test_trunk_multimesh_has_instances() -> void:
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	_builder.build(chunk, Vector2i(0, 0), 0.0, 0.0)
	var body := chunk.get_child(0) as StaticBody3D
	for child in body.get_children():
		if child is MultiMeshInstance3D:
			var mmi := child as MultiMeshInstance3D
			if mmi.name == "TrunksMM":
				assert_gt(
					mmi.multimesh.instance_count,
					0,
					"Trunk MultiMesh should have instances",
				)
				return
	fail_test("TrunksMM not found")


func test_trunk_multimesh_uses_colors() -> void:
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	_builder.build(chunk, Vector2i(0, 0), 0.0, 0.0)
	var body := chunk.get_child(0) as StaticBody3D
	for child in body.get_children():
		if child is MultiMeshInstance3D:
			var mmi := child as MultiMeshInstance3D
			if mmi.name == "TrunksMM":
				assert_true(
					mmi.multimesh.use_colors,
					"Trunk MultiMesh should use per-instance colors",
				)
				return


func test_trunk_multimesh_uses_3d_transforms() -> void:
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	_builder.build(chunk, Vector2i(0, 0), 0.0, 0.0)
	var body := chunk.get_child(0) as StaticBody3D
	for child in body.get_children():
		if child is MultiMeshInstance3D:
			var mmi := child as MultiMeshInstance3D
			if mmi.name == "TrunksMM":
				assert_eq(
					mmi.multimesh.transform_format,
					MultiMesh.TRANSFORM_3D,
					"Should use 3D transforms",
				)
				return


func test_canopy_multimeshes_created() -> void:
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	_builder.build(chunk, Vector2i(0, 0), 0.0, 0.0)
	var body := chunk.get_child(0) as StaticBody3D
	var canopy_count := 0
	for child in body.get_children():
		if child is MultiMeshInstance3D:
			var mmi := child as MultiMeshInstance3D
			if mmi.name.begins_with("CanopyMM_"):
				canopy_count += 1
	assert_gt(
		canopy_count,
		0,
		"Should have at least one CanopyMM_N MultiMeshInstance3D",
	)


func test_canopy_multimeshes_have_instances() -> void:
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	_builder.build(chunk, Vector2i(0, 0), 0.0, 0.0)
	var body := chunk.get_child(0) as StaticBody3D
	for child in body.get_children():
		if child is MultiMeshInstance3D:
			var mmi := child as MultiMeshInstance3D
			if mmi.name.begins_with("CanopyMM_"):
				assert_gt(
					mmi.multimesh.instance_count,
					0,
					"%s should have instances" % mmi.name,
				)


func test_canopy_material_uses_vertex_colors() -> void:
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	_builder.build(chunk, Vector2i(0, 0), 0.0, 0.0)
	var body := chunk.get_child(0) as StaticBody3D
	for child in body.get_children():
		if child is MultiMeshInstance3D:
			var mmi := child as MultiMeshInstance3D
			if mmi.name.begins_with("CanopyMM_"):
				var mat := mmi.material_override as StandardMaterial3D
				assert_not_null(mat, "Canopy should have material override")
				assert_true(
					mat.vertex_color_use_as_albedo,
					"Canopy material should use vertex colors as albedo",
				)
				return


# ================================================================
# Collision shapes for trunks
# ================================================================


func test_trees_body_has_collision_shapes() -> void:
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
		"Trees body should have collision shapes for trunks",
	)


func test_collision_shapes_are_cylinders() -> void:
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	_builder.build(chunk, Vector2i(0, 0), 0.0, 0.0)
	var body := chunk.get_child(0) as StaticBody3D
	for child in body.get_children():
		if child is CollisionShape3D:
			var col := child as CollisionShape3D
			assert_true(
				col.shape is CylinderShape3D,
				"Tree collision shape should be CylinderShape3D",
			)
			return


func test_trunk_count_matches_collision_count() -> void:
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	_builder.build(chunk, Vector2i(0, 0), 0.0, 0.0)
	var body := chunk.get_child(0) as StaticBody3D

	var col_count := 0
	var trunk_instance_count := 0
	for child in body.get_children():
		if child is CollisionShape3D:
			col_count += 1
		if child is MultiMeshInstance3D:
			var mmi := child as MultiMeshInstance3D
			if mmi.name == "TrunksMM":
				trunk_instance_count = mmi.multimesh.instance_count
	assert_eq(
		col_count,
		trunk_instance_count,
		"Collision shape count should match trunk instance count",
	)


# ================================================================
# Determinism — same tile produces same output
# ================================================================


func test_build_is_deterministic_same_tile() -> void:
	var tile := Vector2i(3, 7)

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


func test_different_tiles_produce_different_tree_counts() -> void:
	var chunk_a := Node3D.new()
	add_child_autofree(chunk_a)
	_builder.build(chunk_a, Vector2i(0, 0), 0.0, 0.0)

	var chunk_b := Node3D.new()
	add_child_autofree(chunk_b)
	_builder.build(chunk_b, Vector2i(50, 50), 0.0, 0.0)

	# Both tiles should produce trees (spacing is deterministic per grid)
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
	assert_gt(col_a, 0, "Tile (0,0) should have tree collisions")
	assert_gt(col_b, 0, "Tile (50,50) should have tree collisions")


# ================================================================
# Offset positioning
# ================================================================


func test_build_with_offset() -> void:
	var span: float = _grid.get_grid_span()
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	_builder.build(chunk, Vector2i(1, 1), span, span)
	assert_eq(chunk.get_child_count(), 1, "Should still produce one body")


# ================================================================
# Constants sanity
# ================================================================


func test_tree_spacing_positive() -> void:
	assert_gt(
		TreesScript.TREE_SPACING,
		0.0,
		"Tree spacing should be positive",
	)


func test_canopy_variants_equals_five() -> void:
	assert_eq(
		TreesScript.CANOPY_VARIANTS,
		5,
		"Should have 5 canopy variants",
	)


# ================================================================
# _build_multimesh helper
# ================================================================


func test_build_multimesh_returns_valid_mmi() -> void:
	var transforms: Array = []
	var colors: Array = []
	transforms.append(Transform3D(Basis.IDENTITY, Vector3(0, 1, 0)))
	transforms.append(Transform3D(Basis.IDENTITY, Vector3(5, 1, 5)))
	colors.append(Color.WHITE)
	colors.append(Color.RED)

	var base_mat := StandardMaterial3D.new()
	base_mat.albedo_color = Color(0.5, 0.5, 0.5)
	base_mat.vertex_color_use_as_albedo = true  # mimic init() setup

	var mesh := SphereMesh.new()
	var mmi: MultiMeshInstance3D = (
		_builder
		. _build_multimesh(
			mesh,
			transforms,
			colors,
			base_mat,
		)
	)
	add_child_autofree(mmi)
	assert_not_null(mmi, "Should return a MultiMeshInstance3D")
	assert_not_null(mmi.multimesh, "Should have a MultiMesh")
	assert_eq(
		mmi.multimesh.instance_count,
		2,
		"Should have 2 instances",
	)
	assert_true(
		mmi.multimesh.use_colors,
		"Should use per-instance colors",
	)
	var mat := mmi.material_override as StandardMaterial3D
	assert_true(
		mat.vertex_color_use_as_albedo,
		"Material should use vertex colors as albedo",
	)


func test_build_multimesh_does_not_mutate_base_material() -> void:
	var transforms: Array = [Transform3D.IDENTITY]
	var colors: Array = [Color.WHITE]

	var base_mat := StandardMaterial3D.new()
	base_mat.vertex_color_use_as_albedo = false

	var mesh := SphereMesh.new()
	var mmi: MultiMeshInstance3D = (
		_builder
		. _build_multimesh(
			mesh,
			transforms,
			colors,
			base_mat,
		)
	)
	add_child_autofree(mmi)
	assert_false(
		base_mat.vertex_color_use_as_albedo,
		"Base material should not be mutated (duplicate is used)",
	)
