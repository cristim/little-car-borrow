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


func _head_pivot(model: Node3D) -> Node3D:
	return model.get_child(1) as Node3D


func _head_base(model: Node3D) -> MeshInstance3D:
	return _head_pivot(model).get_child(0) as MeshInstance3D


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

func test_shirt_colors_count() -> void:
	assert_gte(
		PedestrianModelScript.SHIRT_COLORS.size(), 8,
		"Should have at least 8 shirt colour options",
	)


func test_pant_colors_count() -> void:
	assert_gte(
		PedestrianModelScript.PANT_COLORS.size(), 4,
		"Should have at least 4 pant colour options",
	)


func test_skin_colors_count() -> void:
	assert_eq(
		PedestrianModelScript.SKIN_COLORS.size(), 4,
		"Should have 4 skin colour options",
	)


func test_hair_colors_count() -> void:
	assert_gte(
		PedestrianModelScript.HAIR_COLORS.size(), 4,
		"Should have at least 4 hair colour options",
	)


func test_eye_colors_count() -> void:
	assert_gte(
		PedestrianModelScript.EYE_COLORS.size(), 2,
		"Should have at least 2 eye colour options",
	)


func test_all_palettes_contain_valid_colors() -> void:
	var all_palettes: Array = [
		PedestrianModelScript.SHIRT_COLORS,
		PedestrianModelScript.PANT_COLORS,
		PedestrianModelScript.SKIN_COLORS,
		PedestrianModelScript.HAIR_COLORS,
		PedestrianModelScript.EYE_COLORS,
	]
	for palette in all_palettes:
		for color in palette:
			assert_true(color is Color)
			assert_gte(color.r, 0.0)
			assert_lte(color.r, 1.0)


# ---------------------------------------------------------------------------
# _ready — direct child structure (6 children)
# ---------------------------------------------------------------------------

func test_ready_creates_six_direct_children() -> void:
	var model := _make_model()
	add_child_autofree(model)
	await get_tree().process_frame

	assert_eq(model.get_child_count(), 6, "Should have 6 direct body-part children")


func test_torso_is_mesh_instance() -> void:
	var model := _make_model()
	add_child_autofree(model)
	await get_tree().process_frame

	assert_true(model.get_child(0) is MeshInstance3D, "Child 0 (torso) should be MeshInstance3D")


func test_head_pivot_is_node3d() -> void:
	var model := _make_model()
	add_child_autofree(model)
	await get_tree().process_frame

	assert_true(model.get_child(1) is Node3D, "Child 1 (head pivot) should be Node3D")
	assert_false(model.get_child(1) is MeshInstance3D, "Head pivot must NOT be a MeshInstance3D")


func test_legs_and_arms_are_mesh_instances() -> void:
	var model := _make_model()
	add_child_autofree(model)
	await get_tree().process_frame

	for i in [2, 3, 4, 5]:
		assert_true(model.get_child(i) is MeshInstance3D, "Child %d should be MeshInstance3D" % i)


# ---------------------------------------------------------------------------
# Torso
# ---------------------------------------------------------------------------

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


# ---------------------------------------------------------------------------
# Head pivot and base mesh
# ---------------------------------------------------------------------------

func test_head_pivot_position() -> void:
	var model := _make_model()
	add_child_autofree(model)
	await get_tree().process_frame

	var pivot := _head_pivot(model)
	assert_eq(pivot.position, Vector3(0.0, 1.36, 0.0))


func test_head_base_uses_box_mesh() -> void:
	var model := _make_model()
	add_child_autofree(model)
	await get_tree().process_frame

	assert_true(_head_base(model).mesh is BoxMesh, "HeadBase should use BoxMesh")


func test_head_base_dimensions() -> void:
	var model := _make_model()
	add_child_autofree(model)
	await get_tree().process_frame

	var box := _head_base(model).mesh as BoxMesh
	assert_eq(box.size, Vector3(0.22, 0.22, 0.22))


func test_head_base_at_pivot_centre() -> void:
	var model := _make_model()
	add_child_autofree(model)
	await get_tree().process_frame

	assert_eq(_head_base(model).position, Vector3.ZERO)


# ---------------------------------------------------------------------------
# Face details
# ---------------------------------------------------------------------------

func test_head_pivot_has_thirteen_children() -> void:
	var model := _make_model()
	add_child_autofree(model)
	await get_tree().process_frame

	# HeadBase + 12 face-detail boxes
	assert_eq(_head_pivot(model).get_child_count(), 13, "Head pivot should have 13 children")


func test_face_has_eye_nodes() -> void:
	var model := _make_model()
	add_child_autofree(model)
	await get_tree().process_frame

	var pivot := _head_pivot(model)
	assert_not_null(pivot.get_node_or_null("EyeLeft"),  "EyeLeft should exist")
	assert_not_null(pivot.get_node_or_null("EyeRight"), "EyeRight should exist")


func test_face_has_brow_nodes() -> void:
	var model := _make_model()
	add_child_autofree(model)
	await get_tree().process_frame

	var pivot := _head_pivot(model)
	assert_not_null(pivot.get_node_or_null("BrowLeft"),  "BrowLeft should exist")
	assert_not_null(pivot.get_node_or_null("BrowRight"), "BrowRight should exist")


func test_face_has_nose_mouth() -> void:
	var model := _make_model()
	add_child_autofree(model)
	await get_tree().process_frame

	var pivot := _head_pivot(model)
	assert_not_null(pivot.get_node_or_null("Nose"),  "Nose should exist")
	assert_not_null(pivot.get_node_or_null("Mouth"), "Mouth should exist")


func test_face_has_ears() -> void:
	var model := _make_model()
	add_child_autofree(model)
	await get_tree().process_frame

	var pivot := _head_pivot(model)
	assert_not_null(pivot.get_node_or_null("EarLeft"),  "EarLeft should exist")
	assert_not_null(pivot.get_node_or_null("EarRight"), "EarRight should exist")


func test_face_has_hair_parts() -> void:
	var model := _make_model()
	add_child_autofree(model)
	await get_tree().process_frame

	var pivot := _head_pivot(model)
	assert_not_null(pivot.get_node_or_null("HairTop"),       "HairTop should exist")
	assert_not_null(pivot.get_node_or_null("HairSideLeft"),  "HairSideLeft should exist")
	assert_not_null(pivot.get_node_or_null("HairSideRight"), "HairSideRight should exist")
	assert_not_null(pivot.get_node_or_null("HairBack"),      "HairBack should exist")


func test_face_details_are_mesh_instances() -> void:
	var model := _make_model()
	add_child_autofree(model)
	await get_tree().process_frame

	var pivot := _head_pivot(model)
	# Skip index 0 (HeadBase already tested separately)
	for i in range(1, pivot.get_child_count()):
		assert_true(pivot.get_child(i) is MeshInstance3D, "Face detail %d should be MeshInstance3D" % i)


func test_nose_protrudes_more_than_eyes() -> void:
	var model := _make_model()
	add_child_autofree(model)
	await get_tree().process_frame

	var pivot := _head_pivot(model)
	var nose := pivot.get_node("Nose") as MeshInstance3D
	var eye := pivot.get_node("EyeLeft") as MeshInstance3D
	assert_gt(nose.position.z, eye.position.z, "Nose should protrude more than eyes")


# ---------------------------------------------------------------------------
# Legs
# ---------------------------------------------------------------------------

func test_legs_use_cylinder_mesh() -> void:
	var model := _make_model()
	add_child_autofree(model)
	await get_tree().process_frame

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


# ---------------------------------------------------------------------------
# Arms
# ---------------------------------------------------------------------------

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
# Material assignment
# ---------------------------------------------------------------------------

func test_torso_and_arms_share_shirt_material() -> void:
	var model := _make_model()
	add_child_autofree(model)
	await get_tree().process_frame

	var torso := model.get_child(0) as MeshInstance3D
	var left_arm := model.get_child(4) as MeshInstance3D
	var right_arm := model.get_child(5) as MeshInstance3D
	assert_eq(torso.material_override, left_arm.material_override,
		"Torso and left arm share shirt mat")
	assert_eq(torso.material_override, right_arm.material_override,
		"Torso and right arm share shirt mat")


func test_legs_share_pant_material() -> void:
	var model := _make_model()
	add_child_autofree(model)
	await get_tree().process_frame

	var left_leg := model.get_child(2) as MeshInstance3D
	var right_leg := model.get_child(3) as MeshInstance3D
	assert_eq(left_leg.material_override, right_leg.material_override, "Both legs share pant material")


func test_shirt_and_pant_are_different_materials() -> void:
	var model := _make_model()
	add_child_autofree(model)
	await get_tree().process_frame

	var torso := model.get_child(0) as MeshInstance3D
	var left_leg := model.get_child(2) as MeshInstance3D
	assert_ne(torso.material_override, left_leg.material_override,
		"Shirt and pant materials should differ")


func test_head_base_uses_skin_material() -> void:
	var model := _make_model()
	add_child_autofree(model)
	await get_tree().process_frame

	var head_base := _head_base(model)
	assert_not_null(head_base.material_override, "HeadBase should have a material_override")
	assert_true(head_base.material_override is StandardMaterial3D)


func test_materials_are_standard_material_3d() -> void:
	var model := _make_model()
	add_child_autofree(model)
	await get_tree().process_frame

	var torso := model.get_child(0) as MeshInstance3D
	assert_true(torso.material_override is StandardMaterial3D)
	assert_true(_head_base(model).material_override is StandardMaterial3D)


# ---------------------------------------------------------------------------
# Colour palettes
# ---------------------------------------------------------------------------

func test_shirt_color_from_palette() -> void:
	var model := _make_model()
	add_child_autofree(model)
	await get_tree().process_frame

	var torso := model.get_child(0) as MeshInstance3D
	var mat := torso.material_override as StandardMaterial3D
	assert_true(
		PedestrianModelScript.SHIRT_COLORS.has(mat.albedo_color),
		"Shirt colour should come from SHIRT_COLORS",
	)


func test_pant_color_from_palette() -> void:
	var model := _make_model()
	add_child_autofree(model)
	await get_tree().process_frame

	var left_leg := model.get_child(2) as MeshInstance3D
	var mat := left_leg.material_override as StandardMaterial3D
	assert_true(
		PedestrianModelScript.PANT_COLORS.has(mat.albedo_color),
		"Pant colour should come from PANT_COLORS",
	)


func test_skin_color_from_palette() -> void:
	var model := _make_model()
	add_child_autofree(model)
	await get_tree().process_frame

	var mat := _head_base(model).material_override as StandardMaterial3D
	assert_true(
		PedestrianModelScript.SKIN_COLORS.has(mat.albedo_color),
		"Skin colour should come from SKIN_COLORS",
	)


func test_hair_color_from_palette() -> void:
	var model := _make_model()
	add_child_autofree(model)
	await get_tree().process_frame

	var hair_top := _head_pivot(model).get_node("HairTop") as MeshInstance3D
	var mat := hair_top.mesh.material as StandardMaterial3D
	assert_true(
		PedestrianModelScript.HAIR_COLORS.has(mat.albedo_color),
		"Hair colour should come from HAIR_COLORS",
	)


func test_eye_color_from_palette() -> void:
	var model := _make_model()
	add_child_autofree(model)
	await get_tree().process_frame

	var eye_left := _head_pivot(model).get_node("EyeLeft") as MeshInstance3D
	var mat := eye_left.mesh.material as StandardMaterial3D
	assert_true(
		PedestrianModelScript.EYE_COLORS.has(mat.albedo_color),
		"Eye colour should come from EYE_COLORS",
	)


# ---------------------------------------------------------------------------
# Scale / height variation
# ---------------------------------------------------------------------------

func test_scale_is_uniform() -> void:
	var model := _make_model()
	add_child_autofree(model)
	await get_tree().process_frame

	assert_almost_eq(model.scale.x, model.scale.y, 0.001, "Scale should be uniform (X == Y)")
	assert_almost_eq(model.scale.x, model.scale.z, 0.001, "Scale should be uniform (X == Z)")


func test_scale_within_range() -> void:
	var model := _make_model()
	add_child_autofree(model)
	await get_tree().process_frame

	assert_gte(model.scale.y, 0.80, "Scale should be at least 0.80")
	assert_lte(model.scale.y, 1.20, "Scale should be at most 1.20")


# ---------------------------------------------------------------------------
# Randomness
# ---------------------------------------------------------------------------

func test_two_models_produce_shirt_variety() -> void:
	var colors_seen := {}
	for _i in range(10):
		var model := _make_model()
		add_child_autofree(model)
		await get_tree().process_frame
		var torso := model.get_child(0) as MeshInstance3D
		var mat := torso.material_override as StandardMaterial3D
		colors_seen[mat.albedo_color] = true

	assert_gt(colors_seen.size(), 1, "Multiple models should produce shirt variety")


func test_two_models_produce_hair_variety() -> void:
	var colors_seen := {}
	for _i in range(15):
		var model := _make_model()
		add_child_autofree(model)
		await get_tree().process_frame
		var hair := _head_pivot(model).get_node("HairTop") as MeshInstance3D
		var mat := hair.mesh.material as StandardMaterial3D
		colors_seen[mat.albedo_color] = true

	assert_gt(colors_seen.size(), 1, "Multiple models should produce hair variety")


func test_two_models_can_have_different_scales() -> void:
	var scales_seen := {}
	for _i in range(15):
		var model := _make_model()
		add_child_autofree(model)
		await get_tree().process_frame
		# Round to 2 decimal places to group near-identical scales
		var rounded: float = snappedf(model.scale.y, 0.01)
		scales_seen[rounded] = true

	assert_gt(scales_seen.size(), 1, "Multiple models should produce height variety")
