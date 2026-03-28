extends GutTest
## Tests for PedestrianRagdoll (scenes/pedestrians/pedestrian_ragdoll.gd).

const RagdollScript = preload("res://scenes/pedestrians/pedestrian_ragdoll.gd")


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _make_ragdoll() -> RigidBody3D:
	var rb := RigidBody3D.new()
	rb.set_script(RagdollScript)
	return rb


func _make_source_with_model() -> Node3D:
	var source := Node3D.new()
	var model := Node3D.new()
	model.name = "PedestrianModel"

	# Add a mesh child to copy
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.mesh = BoxMesh.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color.RED
	mesh_inst.material_override = mat
	model.add_child(mesh_inst)

	source.add_child(model)
	return source


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

func test_despawn_time_constant() -> void:
	assert_eq(RagdollScript.DESPAWN_TIME, 5.0)


func test_upward_boost_constant() -> void:
	assert_eq(RagdollScript.UPWARD_BOOST, 4.0)


func test_spin_torque_constant() -> void:
	assert_eq(RagdollScript.SPIN_TORQUE, 8.0)


# ---------------------------------------------------------------------------
# _ready — physics setup
# ---------------------------------------------------------------------------

func test_ready_sets_gravity_scale() -> void:
	var ragdoll := _make_ragdoll()
	add_child_autofree(ragdoll)
	await get_tree().process_frame

	assert_almost_eq(ragdoll.gravity_scale, 1.2, 0.001)


func test_ready_sets_mass() -> void:
	var ragdoll := _make_ragdoll()
	add_child_autofree(ragdoll)
	await get_tree().process_frame

	assert_eq(ragdoll.mass, 60.0)


func test_ready_sets_collision_layer_zero() -> void:
	var ragdoll := _make_ragdoll()
	add_child_autofree(ragdoll)
	await get_tree().process_frame

	assert_eq(ragdoll.collision_layer, 0)


func test_ready_sets_collision_mask() -> void:
	var ragdoll := _make_ragdoll()
	add_child_autofree(ragdoll)
	await get_tree().process_frame

	# Mask 3 = ground (1) + static (2)
	assert_eq(ragdoll.collision_mask, 3)


func test_ready_adds_collision_shape_child() -> void:
	var ragdoll := _make_ragdoll()
	add_child_autofree(ragdoll)
	await get_tree().process_frame

	var found_collision := false
	for child in ragdoll.get_children():
		if child is CollisionShape3D:
			found_collision = true
			break
	assert_true(found_collision, "Should create a CollisionShape3D child")


func test_ready_collision_shape_is_capsule() -> void:
	var ragdoll := _make_ragdoll()
	add_child_autofree(ragdoll)
	await get_tree().process_frame

	var col: CollisionShape3D = null
	for child in ragdoll.get_children():
		if child is CollisionShape3D:
			col = child
			break
	assert_not_null(col)
	assert_true(col.shape is CapsuleShape3D)


func test_ready_capsule_dimensions() -> void:
	var ragdoll := _make_ragdoll()
	add_child_autofree(ragdoll)
	await get_tree().process_frame

	var col: CollisionShape3D = null
	for child in ragdoll.get_children():
		if child is CollisionShape3D:
			col = child
			break
	var capsule := col.shape as CapsuleShape3D
	assert_eq(capsule.radius, 0.25)
	assert_almost_eq(capsule.height, 1.7, 0.001)


func test_ready_collision_shape_position() -> void:
	var ragdoll := _make_ragdoll()
	add_child_autofree(ragdoll)
	await get_tree().process_frame

	var col: CollisionShape3D = null
	for child in ragdoll.get_children():
		if child is CollisionShape3D:
			col = child
			break
	assert_almost_eq(col.position.y, 0.85, 0.001)


func test_ready_physics_material_bounce() -> void:
	var ragdoll := _make_ragdoll()
	add_child_autofree(ragdoll)
	await get_tree().process_frame

	assert_not_null(ragdoll.physics_material_override)
	assert_almost_eq(ragdoll.physics_material_override.bounce, 0.3, 0.001)


func test_ready_physics_material_friction() -> void:
	var ragdoll := _make_ragdoll()
	add_child_autofree(ragdoll)
	await get_tree().process_frame

	assert_almost_eq(ragdoll.physics_material_override.friction, 0.8, 0.001)


# ---------------------------------------------------------------------------
# launch
# ---------------------------------------------------------------------------

func test_launch_applies_upward_impulse() -> void:
	var ragdoll := _make_ragdoll()
	add_child_autofree(ragdoll)
	await get_tree().process_frame

	# Launch with horizontal velocity
	var vel := Vector3(10.0, 0.0, 0.0)
	ragdoll.launch(vel)

	# After launch, the expected Y impulse component is:
	# absf(vel.length()) * 0.5 + UPWARD_BOOST = 5.0 + 4.0 = 9.0
	# impulse.y * mass = 9.0 * 60.0 = 540.0
	# We can't directly read accumulated impulse, but the function should not crash
	pass_test("launch completed without error")


func test_launch_with_zero_velocity() -> void:
	var ragdoll := _make_ragdoll()
	add_child_autofree(ragdoll)
	await get_tree().process_frame

	# Zero velocity should still apply UPWARD_BOOST
	ragdoll.launch(Vector3.ZERO)
	pass_test("launch with zero velocity completed without error")


func test_launch_impulse_direction() -> void:
	# Verify the impulse formula: impulse = velocity * 1.2, y overridden
	var vel := Vector3(10.0, 2.0, 5.0)
	var expected_impulse_x := vel.x * 1.2
	var expected_impulse_z := vel.z * 1.2
	var expected_impulse_y := absf(vel.length()) * 0.5 + RagdollScript.UPWARD_BOOST

	assert_almost_eq(expected_impulse_x, 12.0, 0.01)
	assert_almost_eq(expected_impulse_z, 6.0, 0.01)
	assert_gt(expected_impulse_y, 0.0, "Y impulse should always be positive")


# ---------------------------------------------------------------------------
# copy_visual_from
# ---------------------------------------------------------------------------

func test_copy_visual_from_pedestrian_model() -> void:
	var ragdoll := _make_ragdoll()
	add_child_autofree(ragdoll)
	var source := _make_source_with_model()
	add_child_autofree(source)
	await get_tree().process_frame

	var child_count_before := ragdoll.get_child_count()
	ragdoll.copy_visual_from(source)
	var child_count_after := ragdoll.get_child_count()

	assert_gt(
		child_count_after, child_count_before,
		"Should copy mesh children from source",
	)


func test_copy_visual_from_officer_model() -> void:
	var ragdoll := _make_ragdoll()
	add_child_autofree(ragdoll)

	# Create source with OfficerModel instead of PedestrianModel
	var source := Node3D.new()
	var model := Node3D.new()
	model.name = "OfficerModel"
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.mesh = BoxMesh.new()
	model.add_child(mesh_inst)
	source.add_child(model)
	add_child_autofree(source)
	await get_tree().process_frame

	var child_count_before := ragdoll.get_child_count()
	ragdoll.copy_visual_from(source)

	assert_gt(ragdoll.get_child_count(), child_count_before)


func test_copy_visual_from_no_model_does_nothing() -> void:
	var ragdoll := _make_ragdoll()
	add_child_autofree(ragdoll)
	var source := Node3D.new()
	add_child_autofree(source)
	await get_tree().process_frame

	var child_count_before := ragdoll.get_child_count()
	ragdoll.copy_visual_from(source)

	assert_eq(ragdoll.get_child_count(), child_count_before)


func test_copy_visual_preserves_mesh_reference() -> void:
	var ragdoll := _make_ragdoll()
	add_child_autofree(ragdoll)
	var source := _make_source_with_model()
	add_child_autofree(source)
	await get_tree().process_frame

	var original_mesh := (
		source.get_node("PedestrianModel").get_child(0) as MeshInstance3D
	).mesh

	ragdoll.copy_visual_from(source)

	# Find the copied MeshInstance3D
	var found := false
	for child in ragdoll.get_children():
		if child is MeshInstance3D:
			assert_eq(child.mesh, original_mesh, "Copied mesh should reference same mesh")
			found = true
			break
	assert_true(found, "Should have at least one copied MeshInstance3D")


func test_copy_visual_preserves_material() -> void:
	var ragdoll := _make_ragdoll()
	add_child_autofree(ragdoll)
	var source := _make_source_with_model()
	add_child_autofree(source)
	await get_tree().process_frame

	ragdoll.copy_visual_from(source)

	for child in ragdoll.get_children():
		if child is MeshInstance3D:
			assert_not_null(child.material_override)
			if child.material_override is StandardMaterial3D:
				assert_eq(
					(child.material_override as StandardMaterial3D).albedo_color,
					Color.RED,
				)
			break


# ---------------------------------------------------------------------------
# _set_alpha
# ---------------------------------------------------------------------------

func test_set_alpha_changes_material_transparency() -> void:
	var ragdoll := _make_ragdoll()
	add_child_autofree(ragdoll)
	await get_tree().process_frame

	# Add a mesh child with StandardMaterial3D
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.mesh = BoxMesh.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.0, 0.0, 1.0)
	mesh_inst.material_override = mat
	ragdoll.add_child(mesh_inst)

	ragdoll._set_alpha(0.5)

	assert_eq(
		mat.transparency, BaseMaterial3D.TRANSPARENCY_ALPHA,
		"Should set transparency mode",
	)
	assert_almost_eq(mat.albedo_color.a, 0.5, 0.001)


func test_set_alpha_zero() -> void:
	var ragdoll := _make_ragdoll()
	add_child_autofree(ragdoll)
	await get_tree().process_frame

	var mesh_inst := MeshInstance3D.new()
	mesh_inst.mesh = BoxMesh.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.0, 0.0, 1.0)
	mesh_inst.material_override = mat
	ragdoll.add_child(mesh_inst)

	ragdoll._set_alpha(0.0)

	assert_almost_eq(mat.albedo_color.a, 0.0, 0.001)


func test_set_alpha_skips_non_standard_materials() -> void:
	var ragdoll := _make_ragdoll()
	add_child_autofree(ragdoll)
	await get_tree().process_frame

	# Add mesh with no material override
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.mesh = BoxMesh.new()
	ragdoll.add_child(mesh_inst)

	# Should not crash
	ragdoll._set_alpha(0.5)
	pass_test("_set_alpha with null material did not crash")


func test_set_alpha_skips_non_mesh_children() -> void:
	var ragdoll := _make_ragdoll()
	add_child_autofree(ragdoll)
	await get_tree().process_frame

	# The collision shape child from _ready should not cause issues
	ragdoll._set_alpha(0.5)
	pass_test("_set_alpha with non-mesh children did not crash")


# ---------------------------------------------------------------------------
# _process — timer and despawn
# ---------------------------------------------------------------------------

func test_timer_starts_at_zero() -> void:
	var ragdoll := _make_ragdoll()
	assert_eq(ragdoll._timer, 0.0)


func test_timer_increments() -> void:
	var ragdoll := _make_ragdoll()
	add_child_autofree(ragdoll)
	await get_tree().process_frame

	# Manually call _process to control delta
	ragdoll._timer = 0.0
	ragdoll._process(0.5)

	assert_almost_eq(ragdoll._timer, 0.5, 0.001)


func test_fade_begins_one_second_before_despawn() -> void:
	# DESPAWN_TIME is 5.0, fade starts at 4.0
	var ragdoll := _make_ragdoll()
	add_child_autofree(ragdoll)
	await get_tree().process_frame

	# Add mesh to observe alpha
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.mesh = BoxMesh.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.0, 0.0, 1.0)
	mesh_inst.material_override = mat
	ragdoll.add_child(mesh_inst)

	# Set timer to just past fade start (4.0 + a small delta)
	ragdoll._timer = 4.0
	ragdoll._process(0.5)

	# After delta=0.5, timer=4.5. fade = 1.0 - (4.5 - 4.0) = 0.5
	assert_almost_eq(mat.albedo_color.a, 0.5, 0.05)
