extends GutTest
## Unit tests for scenes/world/building_door.gd and the
## _create_door_node() helper in chunk_builder_buildings.gd.

const DoorScript = preload("res://scenes/world/building_door.gd")
const BuilderScript = preload(
	"res://scenes/world/generator/chunk_builder_buildings.gd"
)
const RoadGridScript = preload("res://src/road_grid.gd")


## Bare door node with no children — safe because _ready uses get_node_or_null.
func _make_door() -> Node3D:
	var door := Node3D.new()
	door.set_script(DoorScript)
	add_child_autofree(door)
	return door


func _make_builder() -> RefCounted:
	var builder := BuilderScript.new()
	var grid := RoadGridScript.new()
	var mats: Array[StandardMaterial3D] = []
	for _i in 3:
		mats.append(StandardMaterial3D.new())
	var win_mats: Array[StandardMaterial3D] = []
	for _i in 4:
		win_mats.append(StandardMaterial3D.new())
	builder.init(grid, mats, win_mats, StandardMaterial3D.new())
	return builder


# ==========================================================================
# Constants
# ==========================================================================

func test_open_angle_is_negative() -> void:
	assert_lt(
		DoorScript.OPEN_ANGLE, 0.0,
		"OPEN_ANGLE should be negative (swing inward)",
	)


func test_anim_duration_is_positive() -> void:
	assert_gt(
		DoorScript.ANIM_DURATION, 0.0,
		"ANIM_DURATION should be positive",
	)


# ==========================================================================
# Initial state
# ==========================================================================

func test_door_starts_closed() -> void:
	var door := _make_door()
	assert_false(door._is_open, "Door should start closed")


func test_player_near_starts_false() -> void:
	var door := _make_door()
	assert_false(door._player_near, "_player_near should start false")


func test_base_rot_y_set_from_node_rotation() -> void:
	var door := Node3D.new()
	door.set_script(DoorScript)
	door.rotation.y = PI / 2.0
	add_child_autofree(door)
	assert_almost_eq(
		door._base_rot_y, PI / 2.0, 0.001,
		"_base_rot_y should be initialized from rotation.y in _ready",
	)


# ==========================================================================
# _toggle()
# ==========================================================================

func test_toggle_opens_closed_door() -> void:
	var door := _make_door()
	door._toggle()
	assert_true(door._is_open, "_toggle should open a closed door")


func test_toggle_closes_open_door() -> void:
	var door := _make_door()
	door._toggle()
	door._toggle()
	assert_false(door._is_open, "Second _toggle should close the door")


func test_toggle_rotation_reaches_open_angle() -> void:
	var door := _make_door()
	var base_y := door.rotation.y
	door._toggle()
	await get_tree().create_timer(DoorScript.ANIM_DURATION + 0.1).timeout
	assert_almost_eq(
		door.rotation.y,
		base_y + DoorScript.OPEN_ANGLE,
		0.02,
		"After open tween rotation.y should equal base + OPEN_ANGLE",
	)


func test_toggle_back_restores_base_rotation() -> void:
	var door := _make_door()
	var base_y := door.rotation.y
	door._toggle()
	await get_tree().create_timer(DoorScript.ANIM_DURATION + 0.1).timeout
	door._toggle()
	await get_tree().create_timer(DoorScript.ANIM_DURATION + 0.1).timeout
	assert_almost_eq(
		door.rotation.y, base_y, 0.02,
		"After close tween rotation.y should return to base",
	)


func test_toggle_respects_nonzero_base_rotation() -> void:
	# Simulate a face-1 door (base rot = PI)
	var door := Node3D.new()
	door.set_script(DoorScript)
	door.rotation.y = PI
	add_child_autofree(door)
	door._toggle()
	await get_tree().create_timer(DoorScript.ANIM_DURATION + 0.1).timeout
	assert_almost_eq(
		door.rotation.y,
		PI + DoorScript.OPEN_ANGLE,
		0.02,
		"Open target must be base_rot_y + OPEN_ANGLE regardless of face",
	)


# ==========================================================================
# _create_door_node()
# ==========================================================================

func test_create_door_node_adds_child_to_chunk() -> void:
	var builder := _make_builder()
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	builder._create_door_node(
		chunk, Vector3(0, 5, 0), Vector3(10, 10, 10), 0,
	)
	assert_gt(chunk.get_child_count(), 0, "Should add a door node to chunk")


func test_create_door_node_is_node3d() -> void:
	var builder := _make_builder()
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	builder._create_door_node(
		chunk, Vector3(0, 5, 0), Vector3(10, 10, 10), 0,
	)
	assert_true(chunk.get_child(0) is Node3D, "Door node should be a Node3D")


func test_create_door_node_has_interaction_zone() -> void:
	var builder := _make_builder()
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	builder._create_door_node(
		chunk, Vector3(0, 5, 0), Vector3(10, 10, 10), 0,
	)
	var door: Node = chunk.get_child(0)
	var zone: Node = door.get_node_or_null("InteractionZone")
	assert_not_null(zone, "Door should have an InteractionZone child")
	assert_true(zone is Area3D, "InteractionZone should be Area3D")


func test_create_door_node_zone_collision_mask_is_player_layer() -> void:
	var builder := _make_builder()
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	builder._create_door_node(
		chunk, Vector3(0, 5, 0), Vector3(10, 10, 10), 0,
	)
	var door: Node = chunk.get_child(0)
	var zone: Area3D = door.get_node_or_null("InteractionZone") as Area3D
	assert_eq(
		zone.collision_mask, 4,
		"InteractionZone must mask player layer (bit 3 = value 4)",
	)


func test_create_door_node_has_door_mesh() -> void:
	var builder := _make_builder()
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	builder._create_door_node(
		chunk, Vector3(0, 5, 0), Vector3(10, 10, 10), 0,
	)
	var door: Node = chunk.get_child(0)
	var mesh: Node = door.get_node_or_null("DoorMesh")
	assert_not_null(mesh, "Door should have a DoorMesh child")
	assert_true(mesh is MeshInstance3D, "DoorMesh should be MeshInstance3D")


func test_create_door_node_at_ground_level() -> void:
	# Building center y=5, size.y=10 → ground at y=0
	var builder := _make_builder()
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	builder._create_door_node(
		chunk, Vector3(10, 5, 10), Vector3(10, 10, 10), 0,
	)
	var door: Node3D = chunk.get_child(0) as Node3D
	assert_almost_eq(
		door.position.y, 0.0, 0.01,
		"Hinge should be at ground level (center.y - size.y/2)",
	)


func test_create_door_node_all_four_faces_succeed() -> void:
	var builder := _make_builder()
	for face in range(4):
		var chunk := Node3D.new()
		add_child_autofree(chunk)
		builder._create_door_node(
			chunk, Vector3(0, 5, 0), Vector3(10, 10, 10), face,
		)
		assert_gt(
			chunk.get_child_count(), 0,
			"Face %d should produce a door node" % face,
		)


func test_create_door_face0_rotation_is_zero() -> void:
	var builder := _make_builder()
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	builder._create_door_node(
		chunk, Vector3(0, 5, 0), Vector3(10, 10, 10), 0,
	)
	var door: Node3D = chunk.get_child(0) as Node3D
	assert_almost_eq(
		door.rotation.y, 0.0, 0.001,
		"Face 0 door rotation.y should be 0",
	)


func test_create_door_face1_rotation_is_pi() -> void:
	var builder := _make_builder()
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	builder._create_door_node(
		chunk, Vector3(0, 5, 0), Vector3(10, 10, 10), 1,
	)
	var door: Node3D = chunk.get_child(0) as Node3D
	assert_almost_eq(
		door.rotation.y, PI, 0.001,
		"Face 1 door rotation.y should be PI",
	)


func test_create_door_mesh_has_box_shape() -> void:
	var builder := _make_builder()
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	builder._create_door_node(
		chunk, Vector3(0, 5, 0), Vector3(10, 10, 10), 0,
	)
	var door: Node = chunk.get_child(0)
	var mesh_inst: MeshInstance3D = door.get_node_or_null("DoorMesh") as MeshInstance3D
	assert_not_null(mesh_inst.mesh, "DoorMesh should have a mesh assigned")
	assert_true(mesh_inst.mesh is BoxMesh, "Door mesh should be a BoxMesh")


# ==========================================================================
# build() integration — door nodes appear as chunk children
# ==========================================================================

func test_build_adds_door_nodes_to_chunk() -> void:
	var builder := _make_builder()
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	builder.build(chunk, Vector2i(0, 0), 0.0, 0.0)
	var door_count := 0
	for i in chunk.get_child_count():
		if chunk.get_child(i).name.begins_with("Door"):
			door_count += 1
	assert_gt(door_count, 0, "build() should add at least one Door node to chunk")
