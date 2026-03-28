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


func _left_hip_pivot(model: Node3D) -> Node3D:
	return model.get_child(2) as Node3D


func _right_hip_pivot(model: Node3D) -> Node3D:
	return model.get_child(3) as Node3D


func _left_shoulder_pivot(model: Node3D) -> Node3D:
	return model.get_child(4) as Node3D


func _right_shoulder_pivot(model: Node3D) -> Node3D:
	return model.get_child(5) as Node3D


func _left_leg_mesh(model: Node3D) -> MeshInstance3D:
	return _left_hip_pivot(model).get_child(0) as MeshInstance3D


func _right_leg_mesh(model: Node3D) -> MeshInstance3D:
	return _right_hip_pivot(model).get_child(0) as MeshInstance3D


func _left_arm_mesh(model: Node3D) -> MeshInstance3D:
	return _left_shoulder_pivot(model).get_child(0) as MeshInstance3D


func _right_arm_mesh(model: Node3D) -> MeshInstance3D:
	return _right_shoulder_pivot(model).get_child(0) as MeshInstance3D


func _left_elbow_pivot(model: Node3D) -> Node3D:
	return _left_shoulder_pivot(model).get_child(1) as Node3D


func _right_elbow_pivot(model: Node3D) -> Node3D:
	return _right_shoulder_pivot(model).get_child(1) as Node3D


func _left_forearm_mesh(model: Node3D) -> MeshInstance3D:
	return _left_elbow_pivot(model).get_child(0) as MeshInstance3D


func _right_forearm_mesh(model: Node3D) -> MeshInstance3D:
	return _right_elbow_pivot(model).get_child(0) as MeshInstance3D


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


func test_walk_animation_constants_defined() -> void:
	assert_gt(PedestrianModelScript.WALK_AMPLITUDE, 0.0)
	assert_gt(PedestrianModelScript.FREQUENCY, 0.0)
	assert_gt(PedestrianModelScript.DECAY_SPEED, 0.0)


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


func test_hip_and_shoulder_pivots_are_node3d() -> void:
	var model := _make_model()
	add_child_autofree(model)
	await get_tree().process_frame

	for i in [2, 3, 4, 5]:
		var child := model.get_child(i)
		assert_true(child is Node3D, "Child %d should be Node3D" % i)
		assert_false(child is MeshInstance3D, "Child %d should not be MeshInstance3D" % i)


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

	assert_eq(_head_pivot(model).position, Vector3(0.0, 1.36, 0.0))


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
	for i in range(1, pivot.get_child_count()):
		assert_true(
			pivot.get_child(i) is MeshInstance3D,
			"Face detail %d should be MeshInstance3D" % i,
		)


func test_nose_protrudes_more_than_eyes() -> void:
	var model := _make_model()
	add_child_autofree(model)
	await get_tree().process_frame

	var pivot := _head_pivot(model)
	var nose := pivot.get_node("Nose") as MeshInstance3D
	var eye := pivot.get_node("EyeLeft") as MeshInstance3D
	assert_gt(nose.position.z, eye.position.z, "Nose should protrude more than eyes")


# ---------------------------------------------------------------------------
# Hip pivots (legs)
# ---------------------------------------------------------------------------

func test_hip_pivots_have_one_child_each() -> void:
	var model := _make_model()
	add_child_autofree(model)
	await get_tree().process_frame

	assert_eq(_left_hip_pivot(model).get_child_count(), 1)
	assert_eq(_right_hip_pivot(model).get_child_count(), 1)


func test_legs_use_cylinder_mesh() -> void:
	var model := _make_model()
	add_child_autofree(model)
	await get_tree().process_frame

	assert_true(_left_leg_mesh(model).mesh is CylinderMesh, "Left leg should use CylinderMesh")
	assert_true(_right_leg_mesh(model).mesh is CylinderMesh, "Right leg should use CylinderMesh")


func test_legs_share_same_mesh() -> void:
	var model := _make_model()
	add_child_autofree(model)
	await get_tree().process_frame

	assert_eq(
		_left_leg_mesh(model).mesh,
		_right_leg_mesh(model).mesh,
		"Both legs should share the same mesh",
	)


func test_hip_pivot_positions_are_at_hip_height() -> void:
	var model := _make_model()
	add_child_autofree(model)
	await get_tree().process_frame

	assert_almost_eq(_left_hip_pivot(model).position.y, 0.75, 0.001)
	assert_almost_eq(_right_hip_pivot(model).position.y, 0.75, 0.001)


func test_hip_pivot_positions_are_symmetric() -> void:
	var model := _make_model()
	add_child_autofree(model)
	await get_tree().process_frame

	assert_almost_eq(_left_hip_pivot(model).position.x, -0.10, 0.001)
	assert_almost_eq(_right_hip_pivot(model).position.x, 0.10, 0.001)


func test_leg_mesh_hangs_below_hip_pivot() -> void:
	var model := _make_model()
	add_child_autofree(model)
	await get_tree().process_frame

	assert_lt(_left_leg_mesh(model).position.y, 0.0, "Leg mesh should be below hip pivot")


# ---------------------------------------------------------------------------
# Shoulder pivots (arms)
# ---------------------------------------------------------------------------

func test_shoulder_pivots_have_two_children_each() -> void:
	# Upper arm mesh (child 0) + ElbowPivot (child 1)
	var model := _make_model()
	add_child_autofree(model)
	await get_tree().process_frame

	assert_eq(_left_shoulder_pivot(model).get_child_count(), 2)
	assert_eq(_right_shoulder_pivot(model).get_child_count(), 2)


func test_arms_use_cylinder_mesh() -> void:
	var model := _make_model()
	add_child_autofree(model)
	await get_tree().process_frame

	assert_true(_left_arm_mesh(model).mesh is CylinderMesh, "Left arm should use CylinderMesh")
	assert_true(_right_arm_mesh(model).mesh is CylinderMesh, "Right arm should use CylinderMesh")


func test_arms_share_same_mesh() -> void:
	var model := _make_model()
	add_child_autofree(model)
	await get_tree().process_frame

	assert_eq(
		_left_arm_mesh(model).mesh,
		_right_arm_mesh(model).mesh,
		"Both arms should share the same mesh",
	)


func test_shoulder_pivot_positions_are_at_shoulder_height() -> void:
	var model := _make_model()
	add_child_autofree(model)
	await get_tree().process_frame

	assert_almost_eq(_left_shoulder_pivot(model).position.y, 1.25, 0.001)
	assert_almost_eq(_right_shoulder_pivot(model).position.y, 1.25, 0.001)


func test_shoulder_pivot_positions_are_symmetric() -> void:
	var model := _make_model()
	add_child_autofree(model)
	await get_tree().process_frame

	assert_almost_eq(_left_shoulder_pivot(model).position.x, -0.24, 0.001)
	assert_almost_eq(_right_shoulder_pivot(model).position.x, 0.24, 0.001)


func test_arm_mesh_hangs_below_shoulder_pivot() -> void:
	var model := _make_model()
	add_child_autofree(model)
	await get_tree().process_frame

	assert_lt(_left_arm_mesh(model).position.y, 0.0, "Arm mesh should be below shoulder pivot")


# ---------------------------------------------------------------------------
# Material assignment
# ---------------------------------------------------------------------------

func test_torso_and_arms_share_shirt_material() -> void:
	var model := _make_model()
	add_child_autofree(model)
	await get_tree().process_frame

	var torso_mat := (model.get_child(0) as MeshInstance3D).material_override
	assert_eq(torso_mat, _left_arm_mesh(model).material_override,
		"Torso and left arm share shirt mat")
	assert_eq(torso_mat, _right_arm_mesh(model).material_override,
		"Torso and right arm share shirt mat")


func test_legs_share_pant_material() -> void:
	var model := _make_model()
	add_child_autofree(model)
	await get_tree().process_frame

	assert_eq(
		_left_leg_mesh(model).material_override,
		_right_leg_mesh(model).material_override,
		"Both legs share pant material",
	)


func test_shirt_and_pant_are_different_materials() -> void:
	var model := _make_model()
	add_child_autofree(model)
	await get_tree().process_frame

	var torso_mat := (model.get_child(0) as MeshInstance3D).material_override
	assert_ne(torso_mat, _left_leg_mesh(model).material_override,
		"Shirt and pant materials should differ")


func test_head_base_uses_skin_material() -> void:
	var model := _make_model()
	add_child_autofree(model)
	await get_tree().process_frame

	assert_not_null(_head_base(model).material_override, "HeadBase should have a material_override")
	assert_true(_head_base(model).material_override is StandardMaterial3D)


func test_materials_are_standard_material_3d() -> void:
	var model := _make_model()
	add_child_autofree(model)
	await get_tree().process_frame

	assert_true((model.get_child(0) as MeshInstance3D).material_override is StandardMaterial3D)
	assert_true(_head_base(model).material_override is StandardMaterial3D)


# ---------------------------------------------------------------------------
# Colour palettes
# ---------------------------------------------------------------------------

func test_shirt_color_from_palette() -> void:
	var model := _make_model()
	add_child_autofree(model)
	await get_tree().process_frame

	var mat := (model.get_child(0) as MeshInstance3D).material_override as StandardMaterial3D
	assert_true(
		PedestrianModelScript.SHIRT_COLORS.has(mat.albedo_color),
		"Shirt colour should come from SHIRT_COLORS",
	)


func test_pant_color_from_palette() -> void:
	var model := _make_model()
	add_child_autofree(model)
	await get_tree().process_frame

	var mat := _left_leg_mesh(model).material_override as StandardMaterial3D
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
# Walk animation — functional
# ---------------------------------------------------------------------------

func test_shoulder_pivots_rotate_when_walking() -> void:
	var ped := CharacterBody3D.new()
	add_child_autofree(ped)
	ped.velocity = Vector3(0.0, 0.0, 1.4)  # standard walk speed

	var model := Node3D.new()
	model.set_script(PedestrianModelScript)
	ped.add_child(model)  # _ready fires here (ped is in tree)

	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	var left_shoulder := model.get_child(4) as Node3D
	var right_shoulder := model.get_child(5) as Node3D
	# After a few frames at walk speed the arm pivots must have rotated
	var arms_moved := (
		absf(left_shoulder.rotation.x) > 0.001
		or absf(right_shoulder.rotation.x) > 0.001
	)
	assert_true(arms_moved, "Shoulder pivots should rotate when walking")


func test_hip_pivots_rotate_when_walking() -> void:
	var ped := CharacterBody3D.new()
	add_child_autofree(ped)
	ped.velocity = Vector3(0.0, 0.0, 1.4)

	var model := Node3D.new()
	model.set_script(PedestrianModelScript)
	ped.add_child(model)

	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	var left_hip := model.get_child(2) as Node3D
	var right_hip := model.get_child(3) as Node3D
	var legs_moved := (
		absf(left_hip.rotation.x) > 0.001
		or absf(right_hip.rotation.x) > 0.001
	)
	assert_true(legs_moved, "Hip pivots should rotate when walking")


func test_pivots_decay_when_still() -> void:
	var ped := CharacterBody3D.new()
	add_child_autofree(ped)

	var model := Node3D.new()
	model.set_script(PedestrianModelScript)
	ped.add_child(model)

	# Manually set a large rotation on the shoulder pivot to simulate prior swing
	var left_shoulder := model.get_child(4) as Node3D
	left_shoulder.rotation.x = 0.5

	# Velocity = 0, so the decay branch should run
	ped.velocity = Vector3.ZERO
	await get_tree().process_frame
	await get_tree().process_frame

	assert_lt(
		absf(left_shoulder.rotation.x), 0.5,
		"Shoulder rotation should decay when pedestrian is still",
	)


# ---------------------------------------------------------------------------
# Randomness
# ---------------------------------------------------------------------------

func test_two_models_produce_shirt_variety() -> void:
	var colors_seen := {}
	for _i in range(10):
		var model := _make_model()
		add_child_autofree(model)
		await get_tree().process_frame
		var mat := (model.get_child(0) as MeshInstance3D).material_override as StandardMaterial3D
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
		var rounded: float = snappedf(model.scale.y, 0.01)
		scales_seen[rounded] = true

	assert_gt(scales_seen.size(), 1, "Multiple models should produce height variety")


# ---------------------------------------------------------------------------
# Elbow pivots
# ---------------------------------------------------------------------------

func test_elbow_pivots_exist() -> void:
	var model := _make_model()
	add_child_autofree(model)
	await get_tree().process_frame

	assert_not_null(_left_elbow_pivot(model), "LeftElbowPivot should exist")
	assert_not_null(_right_elbow_pivot(model), "RightElbowPivot should exist")


func test_elbow_pivot_is_node3d_not_mesh() -> void:
	var model := _make_model()
	add_child_autofree(model)
	await get_tree().process_frame

	assert_false(
		_left_elbow_pivot(model) is MeshInstance3D,
		"LeftElbowPivot should be a plain Node3D, not a MeshInstance3D",
	)


func test_elbow_pivot_position() -> void:
	var model := _make_model()
	add_child_autofree(model)
	await get_tree().process_frame

	assert_almost_eq(
		_left_elbow_pivot(model).position.y, -0.27, 0.001,
		"Elbow pivot should be at y=-0.27 from shoulder pivot",
	)
	assert_almost_eq(
		_right_elbow_pivot(model).position.y, -0.27, 0.001,
		"Right elbow pivot should be at y=-0.27 from shoulder pivot",
	)


func test_elbow_pivots_symmetric() -> void:
	var model := _make_model()
	add_child_autofree(model)
	await get_tree().process_frame

	assert_almost_eq(
		_left_elbow_pivot(model).position.x,
		-_right_elbow_pivot(model).position.x,
		0.001,
		"Elbow pivots should be symmetric on X",
	)


func test_forearm_uses_cylinder_mesh() -> void:
	var model := _make_model()
	add_child_autofree(model)
	await get_tree().process_frame

	assert_true(
		_left_forearm_mesh(model).mesh is CylinderMesh,
		"Left forearm should use CylinderMesh",
	)
	assert_true(
		_right_forearm_mesh(model).mesh is CylinderMesh,
		"Right forearm should use CylinderMesh",
	)


func test_forearm_hangs_below_elbow_pivot() -> void:
	var model := _make_model()
	add_child_autofree(model)
	await get_tree().process_frame

	assert_lt(
		_left_forearm_mesh(model).position.y, 0.0,
		"Forearm should hang below elbow pivot (y < 0)",
	)


func test_forearms_share_same_mesh() -> void:
	var model := _make_model()
	add_child_autofree(model)
	await get_tree().process_frame

	assert_eq(
		_left_forearm_mesh(model).mesh,
		_right_forearm_mesh(model).mesh,
		"Both forearms should share the same mesh",
	)


func test_elbow_rotates_when_walking() -> void:
	var ped := CharacterBody3D.new()
	add_child_autofree(ped)
	ped.velocity = Vector3(0.0, 0.0, 1.4)

	var model := Node3D.new()
	model.set_script(PedestrianModelScript)
	ped.add_child(model)

	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	var left_elbow := _left_elbow_pivot(model)
	assert_lt(
		left_elbow.rotation.x, -0.1,
		"Elbow should be bent (rotation.x < -0.1) when walking",
	)


func test_elbow_decays_when_still() -> void:
	var ped := CharacterBody3D.new()
	add_child_autofree(ped)

	var model := Node3D.new()
	model.set_script(PedestrianModelScript)
	ped.add_child(model)

	var left_elbow := _left_elbow_pivot(model)
	left_elbow.rotation.x = -0.8

	ped.velocity = Vector3.ZERO
	await get_tree().process_frame
	await get_tree().process_frame

	assert_gt(
		left_elbow.rotation.x, -0.8,
		"Elbow should decay toward 0 when still",
	)
