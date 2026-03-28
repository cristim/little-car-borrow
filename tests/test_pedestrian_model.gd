extends GutTest
## Tests for PedestrianModel procedural mesh (scenes/pedestrians/pedestrian_model.gd).

const PedestrianModelScript = preload(
	"res://scenes/pedestrians/pedestrian_model.gd"
)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _make_model() -> Node3D:
	var model := Node3D.new()
	model.set_script(PedestrianModelScript)
	return model


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

func test_clothing_colors_count() -> void:
	assert_eq(
		PedestrianModelScript.CLOTHING_COLORS.size(), 8,
		"Should have 8 clothing color options",
	)


func test_skin_colors_count() -> void:
	assert_eq(
		PedestrianModelScript.SKIN_COLORS.size(), 4,
		"Should have 4 skin color options",
	)


func test_clothing_colors_are_valid() -> void:
	for color in PedestrianModelScript.CLOTHING_COLORS:
		assert_true(color is Color, "Each clothing entry should be a Color")
		assert_gte(color.r, 0.0)
		assert_lte(color.r, 1.0)


func test_skin_colors_are_valid() -> void:
	for color in PedestrianModelScript.SKIN_COLORS:
		assert_true(color is Color, "Each skin entry should be a Color")
		assert_gte(color.r, 0.0)
		assert_lte(color.r, 1.0)


# ---------------------------------------------------------------------------
# _ready — mesh generation
# ---------------------------------------------------------------------------

func test_ready_creates_six_children() -> void:
	var model := _make_model()
	add_child_autofree(model)
	await get_tree().process_frame

	# Torso, head, left leg, right leg, left arm, right arm = 6
	assert_eq(model.get_child_count(), 6, "Should create 6 body parts")


func test_all_children_are_mesh_instances() -> void:
	var model := _make_model()
	add_child_autofree(model)
	await get_tree().process_frame

	for i in range(model.get_child_count()):
		var child := model.get_child(i)
		assert_true(child is MeshInstance3D, "Child %d should be MeshInstance3D" % i)


func test_all_children_have_material_override() -> void:
	var model := _make_model()
	add_child_autofree(model)
	await get_tree().process_frame

	for i in range(model.get_child_count()):
		var child := model.get_child(i) as MeshInstance3D
		assert_not_null(
			child.material_override,
			"Child %d should have a material override" % i,
		)


func test_torso_uses_box_mesh() -> void:
	var model := _make_model()
	add_child_autofree(model)
	await get_tree().process_frame

	var torso := model.get_child(0) as MeshInstance3D
	assert_true(torso.mesh is BoxMesh, "Torso should use BoxMesh")


func test_torso_dimensions() -> void:
	var model := _make_model()
	add_child_autofree(model)
	await get_tree().process_frame

	var torso := model.get_child(0) as MeshInstance3D
	var box := torso.mesh as BoxMesh
	assert_eq(box.size, Vector3(0.35, 0.5, 0.2))


func test_torso_position() -> void:
	var model := _make_model()
	add_child_autofree(model)
	await get_tree().process_frame

	var torso := model.get_child(0) as MeshInstance3D
	assert_eq(torso.position, Vector3(0.0, 1.0, 0.0))


func test_head_uses_box_mesh() -> void:
	var model := _make_model()
	add_child_autofree(model)
	await get_tree().process_frame

	var head := model.get_child(1) as MeshInstance3D
	assert_true(head.mesh is BoxMesh, "Head should use BoxMesh")


func test_head_dimensions() -> void:
	var model := _make_model()
	add_child_autofree(model)
	await get_tree().process_frame

	var head := model.get_child(1) as MeshInstance3D
	var box := head.mesh as BoxMesh
	assert_eq(box.size, Vector3(0.22, 0.22, 0.22))


func test_head_position() -> void:
	var model := _make_model()
	add_child_autofree(model)
	await get_tree().process_frame

	var head := model.get_child(1) as MeshInstance3D
	assert_eq(head.position, Vector3(0.0, 1.36, 0.0))


func test_legs_use_cylinder_mesh() -> void:
	var model := _make_model()
	add_child_autofree(model)
	await get_tree().process_frame

	# Children 2 and 3 are left and right legs
	for i in [2, 3]:
		var leg := model.get_child(i) as MeshInstance3D
		assert_true(leg.mesh is CylinderMesh, "Leg %d should use CylinderMesh" % i)


func test_legs_share_same_mesh() -> void:
	var model := _make_model()
	add_child_autofree(model)
	await get_tree().process_frame

	var left_leg := model.get_child(2) as MeshInstance3D
	var right_leg := model.get_child(3) as MeshInstance3D
	assert_eq(left_leg.mesh, right_leg.mesh, "Both legs should share the same mesh")


func test_leg_positions_are_symmetric() -> void:
	var model := _make_model()
	add_child_autofree(model)
	await get_tree().process_frame

	var left_leg := model.get_child(2) as MeshInstance3D
	var right_leg := model.get_child(3) as MeshInstance3D
	assert_almost_eq(left_leg.position.x, -0.1, 0.001)
	assert_almost_eq(right_leg.position.x, 0.1, 0.001)
	assert_eq(left_leg.position.y, right_leg.position.y)


func test_arms_use_cylinder_mesh() -> void:
	var model := _make_model()
	add_child_autofree(model)
	await get_tree().process_frame

	for i in [4, 5]:
		var arm := model.get_child(i) as MeshInstance3D
		assert_true(arm.mesh is CylinderMesh, "Arm %d should use CylinderMesh" % i)


func test_arms_share_same_mesh() -> void:
	var model := _make_model()
	add_child_autofree(model)
	await get_tree().process_frame

	var left_arm := model.get_child(4) as MeshInstance3D
	var right_arm := model.get_child(5) as MeshInstance3D
	assert_eq(left_arm.mesh, right_arm.mesh, "Both arms should share the same mesh")


func test_arm_positions_are_symmetric() -> void:
	var model := _make_model()
	add_child_autofree(model)
	await get_tree().process_frame

	var left_arm := model.get_child(4) as MeshInstance3D
	var right_arm := model.get_child(5) as MeshInstance3D
	assert_almost_eq(left_arm.position.x, -0.24, 0.001)
	assert_almost_eq(right_arm.position.x, 0.24, 0.001)
	assert_eq(left_arm.position.y, right_arm.position.y)


# ---------------------------------------------------------------------------
# Material assignment — clothing vs skin
# ---------------------------------------------------------------------------

func test_torso_and_legs_share_clothing_material() -> void:
	var model := _make_model()
	add_child_autofree(model)
	await get_tree().process_frame

	var torso := model.get_child(0) as MeshInstance3D
	var left_leg := model.get_child(2) as MeshInstance3D
	var right_leg := model.get_child(3) as MeshInstance3D

	assert_eq(torso.material_override, left_leg.material_override)
	assert_eq(torso.material_override, right_leg.material_override)


func test_head_and_arms_share_skin_material() -> void:
	var model := _make_model()
	add_child_autofree(model)
	await get_tree().process_frame

	var head := model.get_child(1) as MeshInstance3D
	var left_arm := model.get_child(4) as MeshInstance3D
	var right_arm := model.get_child(5) as MeshInstance3D

	assert_eq(head.material_override, left_arm.material_override)
	assert_eq(head.material_override, right_arm.material_override)


func test_clothing_and_skin_are_different_materials() -> void:
	var model := _make_model()
	add_child_autofree(model)
	await get_tree().process_frame

	var torso := model.get_child(0) as MeshInstance3D
	var head := model.get_child(1) as MeshInstance3D
	assert_ne(
		torso.material_override, head.material_override,
		"Clothing and skin materials should be distinct",
	)


func test_materials_are_standard_material_3d() -> void:
	var model := _make_model()
	add_child_autofree(model)
	await get_tree().process_frame

	var torso := model.get_child(0) as MeshInstance3D
	assert_true(torso.material_override is StandardMaterial3D)

	var head := model.get_child(1) as MeshInstance3D
	assert_true(head.material_override is StandardMaterial3D)


func test_clothing_color_from_palette() -> void:
	var model := _make_model()
	add_child_autofree(model)
	await get_tree().process_frame

	var torso := model.get_child(0) as MeshInstance3D
	var mat := torso.material_override as StandardMaterial3D
	assert_true(
		PedestrianModelScript.CLOTHING_COLORS.has(mat.albedo_color),
		"Clothing color should be from the palette",
	)


func test_skin_color_from_palette() -> void:
	var model := _make_model()
	add_child_autofree(model)
	await get_tree().process_frame

	var head := model.get_child(1) as MeshInstance3D
	var mat := head.material_override as StandardMaterial3D
	assert_true(
		PedestrianModelScript.SKIN_COLORS.has(mat.albedo_color),
		"Skin color should be from the palette",
	)


# ---------------------------------------------------------------------------
# Randomness — two instances should not always match
# ---------------------------------------------------------------------------

func test_two_models_can_differ() -> void:
	# With 8*4=32 combinations, two models are very likely to differ at least
	# once out of several attempts. We create multiple and check diversity.
	var colors_seen := {}
	for i in range(10):
		var model := _make_model()
		add_child_autofree(model)
		await get_tree().process_frame
		var torso := model.get_child(0) as MeshInstance3D
		var mat := torso.material_override as StandardMaterial3D
		colors_seen[mat.albedo_color] = true

	assert_gt(colors_seen.size(), 1, "Multiple models should produce variety")
