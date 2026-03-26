extends GutTest
## Unit tests for chunk_builder_roads.gd — road, block ground, and sidewalk
## mesh generation with merged MeshInstance3D + compound StaticBody3D.

const RoadsScript = preload(
	"res://scenes/world/generator/chunk_builder_roads.gd"
)
const RoadGridScript = preload("res://src/road_grid.gd")

var _grid: RefCounted
var _builder: RefCounted
var _road_mat: StandardMaterial3D
var _sidewalk_mat: StandardMaterial3D
var _ground_mat: StandardMaterial3D


func before_each() -> void:
	_grid = RoadGridScript.new()
	_road_mat = StandardMaterial3D.new()
	_road_mat.albedo_color = Color(0.2, 0.2, 0.22)
	_sidewalk_mat = StandardMaterial3D.new()
	_sidewalk_mat.albedo_color = Color(0.55, 0.55, 0.53)
	_ground_mat = StandardMaterial3D.new()
	_ground_mat.albedo_color = Color(0.45, 0.45, 0.43)

	_builder = RoadsScript.new()
	_builder.init(_grid, _road_mat, _sidewalk_mat, _ground_mat)


# ================================================================
# Initialization
# ================================================================

func test_init_stores_grid() -> void:
	assert_eq(_builder._grid, _grid, "Grid should be stored after init")


func test_init_stores_road_material() -> void:
	assert_eq(
		_builder._road_mat, _road_mat,
		"Road material should be stored after init",
	)


func test_init_stores_sidewalk_material() -> void:
	assert_eq(
		_builder._sidewalk_mat, _sidewalk_mat,
		"Sidewalk material should be stored after init",
	)


func test_init_stores_ground_material() -> void:
	assert_eq(
		_builder._ground_mat, _ground_mat,
		"Ground material should be stored after init",
	)


# ================================================================
# Build output structure
# ================================================================

func test_build_adds_three_children_to_chunk() -> void:
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	var span: float = _grid.get_grid_span()
	_builder.build(chunk, 0.0, 0.0, span)
	assert_eq(
		chunk.get_child_count(), 3,
		"Build should add Roads, BlockGround, and Sidewalks",
	)


func test_build_creates_roads_body() -> void:
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	_builder.build(chunk, 0.0, 0.0, _grid.get_grid_span())
	var roads := chunk.get_child(0) as StaticBody3D
	assert_not_null(roads, "First child should be a StaticBody3D")
	assert_eq(roads.name, "Roads", "First child should be named Roads")


func test_roads_body_collision_layer() -> void:
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	_builder.build(chunk, 0.0, 0.0, _grid.get_grid_span())
	var roads := chunk.get_child(0) as StaticBody3D
	assert_eq(
		roads.collision_layer, 1,
		"Roads collision layer should be 1 (Ground)",
	)


func test_roads_body_collision_mask() -> void:
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	_builder.build(chunk, 0.0, 0.0, _grid.get_grid_span())
	var roads := chunk.get_child(0) as StaticBody3D
	assert_eq(
		roads.collision_mask, 0,
		"Roads collision mask should be 0",
	)


func test_roads_body_in_road_group() -> void:
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	_builder.build(chunk, 0.0, 0.0, _grid.get_grid_span())
	var roads := chunk.get_child(0) as StaticBody3D
	assert_true(
		roads.is_in_group("Road"),
		"Roads body should be in Road group",
	)


func test_roads_body_has_mesh_child() -> void:
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	_builder.build(chunk, 0.0, 0.0, _grid.get_grid_span())
	var roads := chunk.get_child(0) as StaticBody3D
	var mesh_inst: MeshInstance3D = null
	for child in roads.get_children():
		if child is MeshInstance3D:
			mesh_inst = child as MeshInstance3D
			break
	assert_not_null(mesh_inst, "Roads body should have a MeshInstance3D child")
	assert_eq(mesh_inst.name, "RoadsMesh", "Mesh child should be named RoadsMesh")


func test_roads_mesh_has_road_material() -> void:
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	_builder.build(chunk, 0.0, 0.0, _grid.get_grid_span())
	var roads := chunk.get_child(0) as StaticBody3D
	var mesh_inst: MeshInstance3D = null
	for child in roads.get_children():
		if child is MeshInstance3D:
			mesh_inst = child as MeshInstance3D
			break
	assert_eq(
		mesh_inst.material_override, _road_mat,
		"Road mesh should use road material",
	)


func test_roads_body_has_collision_shapes() -> void:
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	_builder.build(chunk, 0.0, 0.0, _grid.get_grid_span())
	var roads := chunk.get_child(0) as StaticBody3D
	var col_count := 0
	for child in roads.get_children():
		if child is CollisionShape3D:
			col_count += 1
	assert_gt(col_count, 0, "Roads body should have collision shapes")


func test_block_ground_body_created() -> void:
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	_builder.build(chunk, 0.0, 0.0, _grid.get_grid_span())
	var ground := chunk.get_child(1) as StaticBody3D
	assert_not_null(ground, "Second child should be a StaticBody3D")
	assert_eq(ground.name, "BlockGround", "Second child should be named BlockGround")


func test_block_ground_in_road_group() -> void:
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	_builder.build(chunk, 0.0, 0.0, _grid.get_grid_span())
	var ground := chunk.get_child(1) as StaticBody3D
	assert_true(
		ground.is_in_group("Road"),
		"BlockGround body should be in Road group",
	)


func test_block_ground_has_mesh_child() -> void:
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	_builder.build(chunk, 0.0, 0.0, _grid.get_grid_span())
	var ground := chunk.get_child(1) as StaticBody3D
	var mesh_inst: MeshInstance3D = null
	for child in ground.get_children():
		if child is MeshInstance3D:
			mesh_inst = child as MeshInstance3D
			break
	assert_not_null(mesh_inst, "BlockGround should have a MeshInstance3D child")
	assert_eq(mesh_inst.name, "BlockGroundMesh")


func test_block_ground_mesh_has_ground_material() -> void:
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	_builder.build(chunk, 0.0, 0.0, _grid.get_grid_span())
	var ground := chunk.get_child(1) as StaticBody3D
	var mesh_inst: MeshInstance3D = null
	for child in ground.get_children():
		if child is MeshInstance3D:
			mesh_inst = child as MeshInstance3D
			break
	assert_eq(
		mesh_inst.material_override, _ground_mat,
		"Block ground mesh should use ground material",
	)


func test_block_ground_has_correct_collision_count() -> void:
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	_builder.build(chunk, 0.0, 0.0, _grid.get_grid_span())
	var ground := chunk.get_child(1) as StaticBody3D
	var col_count := 0
	for child in ground.get_children():
		if child is CollisionShape3D:
			col_count += 1
	assert_eq(
		col_count, _grid.GRID_SIZE * _grid.GRID_SIZE,
		"BlockGround should have GRID_SIZE^2 collision shapes",
	)


func test_sidewalks_body_created() -> void:
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	_builder.build(chunk, 0.0, 0.0, _grid.get_grid_span())
	var sidewalks := chunk.get_child(2) as StaticBody3D
	assert_not_null(sidewalks, "Third child should be a StaticBody3D")
	assert_eq(sidewalks.name, "Sidewalks")


func test_sidewalks_in_road_group() -> void:
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	_builder.build(chunk, 0.0, 0.0, _grid.get_grid_span())
	var sidewalks := chunk.get_child(2) as StaticBody3D
	assert_true(
		sidewalks.is_in_group("Road"),
		"Sidewalks body should be in Road group",
	)


func test_sidewalks_has_mesh_child() -> void:
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	_builder.build(chunk, 0.0, 0.0, _grid.get_grid_span())
	var sidewalks := chunk.get_child(2) as StaticBody3D
	var mesh_inst: MeshInstance3D = null
	for child in sidewalks.get_children():
		if child is MeshInstance3D:
			mesh_inst = child as MeshInstance3D
			break
	assert_not_null(mesh_inst, "Sidewalks should have a MeshInstance3D child")
	assert_eq(mesh_inst.name, "SidewalksMesh")


func test_sidewalks_mesh_has_sidewalk_material() -> void:
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	_builder.build(chunk, 0.0, 0.0, _grid.get_grid_span())
	var sidewalks := chunk.get_child(2) as StaticBody3D
	var mesh_inst: MeshInstance3D = null
	for child in sidewalks.get_children():
		if child is MeshInstance3D:
			mesh_inst = child as MeshInstance3D
			break
	assert_eq(
		mesh_inst.material_override, _sidewalk_mat,
		"Sidewalk mesh should use sidewalk material",
	)


# ================================================================
# Offset positioning
# ================================================================

func test_build_with_offset_still_produces_children() -> void:
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	var span: float = _grid.get_grid_span()
	_builder.build(chunk, span, span, span)
	assert_eq(
		chunk.get_child_count(), 3,
		"Build with offset should still produce 3 children",
	)


func test_build_with_negative_offset() -> void:
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	var span: float = _grid.get_grid_span()
	_builder.build(chunk, -span, -span, span)
	assert_eq(
		chunk.get_child_count(), 3,
		"Build with negative offset should still produce 3 children",
	)


# ================================================================
# Determinism
# ================================================================

func test_build_is_deterministic() -> void:
	var span: float = _grid.get_grid_span()

	var chunk_a := Node3D.new()
	add_child_autofree(chunk_a)
	_builder.build(chunk_a, 0.0, 0.0, span)

	var chunk_b := Node3D.new()
	add_child_autofree(chunk_b)
	_builder.build(chunk_b, 0.0, 0.0, span)

	var count_a := 0
	var count_b := 0
	for child in chunk_a.get_child(0).get_children():
		if child is CollisionShape3D:
			count_a += 1
	for child in chunk_b.get_child(0).get_children():
		if child is CollisionShape3D:
			count_b += 1
	assert_eq(
		count_a, count_b,
		"Two builds with same params should produce same collision count",
	)


# ================================================================
# Road collision count sanity
# ================================================================

func test_roads_collision_count_exceeds_grid_size() -> void:
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	_builder.build(chunk, 0.0, 0.0, _grid.get_grid_span())
	var roads := chunk.get_child(0) as StaticBody3D
	var col_count := 0
	for child in roads.get_children():
		if child is CollisionShape3D:
			col_count += 1
	assert_gt(
		col_count, _grid.GRID_SIZE,
		"Roads should have more collision shapes than GRID_SIZE",
	)


# ================================================================
# Mesh validity
# ================================================================

func test_roads_mesh_not_null() -> void:
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	_builder.build(chunk, 0.0, 0.0, _grid.get_grid_span())
	var roads := chunk.get_child(0) as StaticBody3D
	for child in roads.get_children():
		if child is MeshInstance3D:
			assert_not_null(
				(child as MeshInstance3D).mesh,
				"Road mesh should not be null",
			)
			return
	fail_test("No MeshInstance3D found in Roads body")


func test_block_ground_mesh_not_null() -> void:
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	_builder.build(chunk, 0.0, 0.0, _grid.get_grid_span())
	var ground := chunk.get_child(1) as StaticBody3D
	for child in ground.get_children():
		if child is MeshInstance3D:
			assert_not_null(
				(child as MeshInstance3D).mesh,
				"Block ground mesh should not be null",
			)
			return
	fail_test("No MeshInstance3D found in BlockGround body")


func test_sidewalks_mesh_not_null() -> void:
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	_builder.build(chunk, 0.0, 0.0, _grid.get_grid_span())
	var sidewalks := chunk.get_child(2) as StaticBody3D
	for child in sidewalks.get_children():
		if child is MeshInstance3D:
			assert_not_null(
				(child as MeshInstance3D).mesh,
				"Sidewalks mesh should not be null",
			)
			return
	fail_test("No MeshInstance3D found in Sidewalks body")
