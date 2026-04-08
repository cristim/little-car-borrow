extends GutTest
## Tests for chunk_builder_helipad.gd

const HelipadBuilder := preload("res://scenes/world/generator/chunk_builder_helipad.gd")
const RoadGrid := preload("res://src/road_grid.gd")

var _builder: RefCounted = null
var _chunk: Node3D = null
var _grid: RefCounted = null


func before_each() -> void:
	_grid = RoadGrid.new()
	_builder = HelipadBuilder.new()
	var pad_mat := StandardMaterial3D.new()
	pad_mat.albedo_color = Color(0.5, 0.5, 0.5)
	var marking_mat := StandardMaterial3D.new()
	marking_mat.albedo_color = Color(1.0, 1.0, 1.0)
	_builder.init(_grid, pad_mat, marking_mat)

	_chunk = Node3D.new()
	add_child_autofree(_chunk)


func test_builder_is_ref_counted() -> void:
	assert_true(
		_builder is RefCounted,
		"HelipadBuilder should extend RefCounted",
	)


func test_build_adds_children_to_chunk() -> void:
	_builder.build(_chunk, Vector2i(0, 0), 0.0, 0.0)
	await get_tree().process_frame
	assert_gt(
		_chunk.get_child_count(),
		0,
		"build() should add at least one child to the chunk",
	)


func test_build_adds_static_body_pad() -> void:
	_builder.build(_chunk, Vector2i(0, 0), 0.0, 0.0)
	await get_tree().process_frame
	var found := false
	for child in _chunk.get_children():
		if child is StaticBody3D and child.is_in_group("Road"):
			found = true
			break
	assert_true(found, "build() should create a helipad StaticBody3D in the Road group")


func test_helipad_on_ground_layer() -> void:
	_builder.build(_chunk, Vector2i(0, 0), 0.0, 0.0)
	await get_tree().process_frame
	for child in _chunk.get_children():
		if child is StaticBody3D and child.is_in_group("Road"):
			assert_eq(
				child.collision_layer,
				1,
				"Helipad pad should be on ground collision layer (1)",
			)
			return
	fail_test("No helipad StaticBody3D found")


func test_helipad_in_road_group() -> void:
	_builder.build(_chunk, Vector2i(0, 0), 0.0, 0.0)
	await get_tree().process_frame
	var found := false
	for child in _chunk.get_children():
		if child is StaticBody3D and child.is_in_group("Road"):
			found = true
			break
	assert_true(found, "Helipad pads should be in the 'Road' group")


func test_build_spawns_helicopter() -> void:
	_builder.build(_chunk, Vector2i(0, 0), 0.0, 0.0)
	await get_tree().process_frame
	var found := false
	for child in _chunk.get_children():
		if child is CharacterBody3D and child.is_in_group("helicopter"):
			found = true
			break
	assert_true(found, "build() should spawn at least one helicopter in the chunk")


func test_helicopter_spawned_above_ground() -> void:
	_builder.build(_chunk, Vector2i(0, 0), 0.0, 0.0)
	await get_tree().process_frame
	for child in _chunk.get_children():
		if child is CharacterBody3D and child.is_in_group("helicopter"):
			assert_gt(
				child.position.y,
				0.0,
				"Helicopter should spawn above ground level (Y > 0)",
			)
			return
	fail_test("No helicopter found in chunk")


func test_h_marking_node_created() -> void:
	_builder.build(_chunk, Vector2i(0, 0), 0.0, 0.0)
	await get_tree().process_frame
	var found := false
	for child in _chunk.get_children():
		if child.name == "HelipadH":
			found = true
			break
	assert_true(found, "build() should create an 'HelipadH' marking node")


func test_helipads_per_chunk_count() -> void:
	_builder.build(_chunk, Vector2i(0, 0), 0.0, 0.0)
	await get_tree().process_frame
	var pad_count := 0
	for child in _chunk.get_children():
		if child is StaticBody3D and child.is_in_group("Road"):
			pad_count += 1
	assert_eq(
		pad_count,
		HelipadBuilder.HELIPADS_PER_CHUNK,
		"build() should create exactly HELIPADS_PER_CHUNK pads",
	)


func test_different_tiles_produce_different_positions() -> void:
	var chunk_a := Node3D.new()
	add_child_autofree(chunk_a)
	var chunk_b := Node3D.new()
	add_child_autofree(chunk_b)

	_builder.build(chunk_a, Vector2i(0, 0), 0.0, 0.0)
	_builder.build(chunk_b, Vector2i(1, 1), 0.0, 0.0)
	await get_tree().process_frame

	var pos_a := Vector3.ZERO
	var pos_b := Vector3.ZERO
	for child in chunk_a.get_children():
		if child is CharacterBody3D and child.is_in_group("helicopter"):
			pos_a = child.global_position
			break
	for child in chunk_b.get_children():
		if child is CharacterBody3D and child.is_in_group("helicopter"):
			pos_b = child.global_position
			break

	assert_ne(
		pos_a,
		pos_b,
		"Helicopters in different tiles should spawn at different positions",
	)


func test_helipad_pad_in_helipad_group() -> void:
	_builder.build(_chunk, Vector2i(0, 0), 0.0, 0.0)
	await get_tree().process_frame
	var found := false
	for child in _chunk.get_children():
		if child is StaticBody3D and child.is_in_group("helipad"):
			found = true
			break
	assert_true(found, "Helipad pad should be in the 'helipad' group for minimap detection")


func test_helipad_pad_has_center_metadata() -> void:
	_builder.build(_chunk, Vector2i(0, 0), 0.0, 0.0)
	await get_tree().process_frame
	for child in _chunk.get_children():
		if child is StaticBody3D and child.is_in_group("helipad"):
			assert_true(
				child.has_meta("helipad_center"),
				"Helipad pad should have 'helipad_center' metadata for minimap positioning",
			)
			return
	fail_test("No helipad StaticBody3D found")


func test_helipad_center_metadata_is_vector3() -> void:
	_builder.build(_chunk, Vector2i(0, 0), 0.0, 0.0)
	await get_tree().process_frame
	for child in _chunk.get_children():
		if child is StaticBody3D and child.is_in_group("helipad"):
			var center: Vector3 = child.get_meta("helipad_center")
			assert_true(
				center is Vector3,
				"helipad_center metadata should be a Vector3",
			)
			return
	fail_test("No helipad StaticBody3D found")
