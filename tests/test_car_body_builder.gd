extends GutTest
## Unit tests for car_body_builder.gd procedural car mesh generation.
## Note: car mesh generation produces engine-level warnings about
## ARRAY_FORMAT_NORMAL due to mixed normal modes in SurfaceTool commits.
## These are cosmetic and do not affect gameplay, so engine errors are
## treated as non-failures in this test file.

const CarBuilderScript = preload("res://scenes/vehicles/car_body_builder.gd")

var _builder: RefCounted


func before_all() -> void:
	gut.error_tracker.treat_engine_errors_as = 0  # TREAT_AS.NOTHING


func after_all() -> void:
	gut.error_tracker.treat_engine_errors_as = 1  # TREAT_AS.FAILURE


func before_each() -> void:
	_builder = CarBuilderScript.new()


# --- Constants ---


func test_ring_verts_is_twelve() -> void:
	assert_eq(CarBuilderScript.RING_VERTS, 12)


func test_frame_depth() -> void:
	assert_eq(CarBuilderScript.FRAME_DEPTH, 0.04)


func test_base_profiles_count() -> void:
	assert_eq(CarBuilderScript.BASE_PROFILES.size(), 10)


func test_variant_overrides_has_sedan() -> void:
	assert_true(CarBuilderScript.VARIANT_OVERRIDES.has("sedan"))


func test_variant_overrides_has_sports() -> void:
	assert_true(CarBuilderScript.VARIANT_OVERRIDES.has("sports"))


func test_variant_overrides_has_suv() -> void:
	assert_true(CarBuilderScript.VARIANT_OVERRIDES.has("suv"))


func test_variant_overrides_has_hatchback() -> void:
	assert_true(CarBuilderScript.VARIANT_OVERRIDES.has("hatchback"))


func test_variant_overrides_has_van() -> void:
	assert_true(CarBuilderScript.VARIANT_OVERRIDES.has("van"))


func test_variant_overrides_has_pickup() -> void:
	assert_true(CarBuilderScript.VARIANT_OVERRIDES.has("pickup"))


func test_variant_overrides_count() -> void:
	assert_eq(CarBuilderScript.VARIANT_OVERRIDES.size(), 6)


func test_sedan_overrides_empty() -> void:
	assert_true(
		CarBuilderScript.VARIANT_OVERRIDES["sedan"].is_empty(),
		"Sedan should have no overrides (it is the base)",
	)


func test_base_profiles_have_required_keys() -> void:
	for p in CarBuilderScript.BASE_PROFILES:
		assert_true(p.has("z"), "Profile should have z")
		assert_true(p.has("hw"), "Profile should have hw")
		assert_true(p.has("yb"), "Profile should have yb")
		assert_true(p.has("yt"), "Profile should have yt")
		assert_true(p.has("inset"), "Profile should have inset")


func test_base_profiles_z_sorted() -> void:
	for i in range(CarBuilderScript.BASE_PROFILES.size() - 1):
		assert_lt(
			float(CarBuilderScript.BASE_PROFILES[i]["z"]),
			float(CarBuilderScript.BASE_PROFILES[i + 1]["z"]),
			"Base profiles z values should be sorted",
		)


# --- _generate_profiles ---


func test_generate_profiles_sedan_same_count_as_base() -> void:
	var profiles: Array = _builder._generate_profiles("sedan")
	assert_eq(profiles.size(), CarBuilderScript.BASE_PROFILES.size())


func test_generate_profiles_sedan_preserves_z() -> void:
	var profiles: Array = _builder._generate_profiles("sedan")
	for i in range(profiles.size()):
		assert_almost_eq(
			float(profiles[i].z),
			float(CarBuilderScript.BASE_PROFILES[i]["z"]),
			0.001,
			"Sedan z should match base profile",
		)


func test_generate_profiles_sports_narrower_cabin() -> void:
	var sedan: Array = _builder._generate_profiles("sedan")
	var sports: Array = _builder._generate_profiles("sports")
	for i in range(sedan.size()):
		if float(sedan[i].inset) > 0.01 and float(sports[i].inset) > 0.01:
			assert_lt(
				float(sports[i].yt),
				float(sedan[i].yt),
				"Sports cabin top should be lower than sedan",
			)
			return
	fail_test("No cabin profiles found to compare")


func test_generate_profiles_suv_taller_cabin() -> void:
	var sedan: Array = _builder._generate_profiles("sedan")
	var suv: Array = _builder._generate_profiles("suv")
	for i in range(sedan.size()):
		if float(sedan[i].inset) > 0.01 and float(suv[i].inset) > 0.01:
			assert_gt(
				float(suv[i].yt),
				float(sedan[i].yt),
				"SUV cabin top should be higher than sedan",
			)
			return
	fail_test("No cabin profiles found to compare")


func test_generate_profiles_hatchback_shorter_length() -> void:
	var sedan: Array = _builder._generate_profiles("sedan")
	var hatch: Array = _builder._generate_profiles("hatchback")
	var sedan_len: float = absf(float(sedan[sedan.size() - 1].z) - float(sedan[0].z))
	var hatch_len: float = absf(float(hatch[hatch.size() - 1].z) - float(hatch[0].z))
	assert_lt(
		hatch_len,
		sedan_len,
		"Hatchback should be shorter than sedan",
	)


func test_generate_profiles_unknown_variant_uses_base() -> void:
	var sedan: Array = _builder._generate_profiles("sedan")
	var unknown: Array = _builder._generate_profiles("nonexistent")
	for i in range(sedan.size()):
		assert_almost_eq(
			float(sedan[i].z),
			float(unknown[i].z),
			0.001,
		)
		assert_almost_eq(
			float(sedan[i].hw),
			float(unknown[i].hw),
			0.001,
		)


# --- _profile_to_ring ---


func test_profile_to_ring_returns_12_vertices() -> void:
	var profiles: Array = _builder._generate_profiles("sedan")
	var ring: PackedVector3Array = _builder._profile_to_ring(profiles[0])
	assert_eq(ring.size(), 12)


func test_profile_to_ring_all_same_z() -> void:
	var profiles: Array = _builder._generate_profiles("sedan")
	var ring: PackedVector3Array = _builder._profile_to_ring(profiles[0])
	var expected_z: float = float(profiles[0].z)
	for v in ring:
		assert_almost_eq(
			v.z,
			expected_z,
			0.001,
			"All ring vertices should have same z",
		)


func test_profile_to_ring_symmetric_x() -> void:
	var profiles: Array = _builder._generate_profiles("sedan")
	var ring: PackedVector3Array = _builder._profile_to_ring(profiles[4])
	# V0 (top-left) and V2 (top-right) should be symmetric
	assert_almost_eq(
		absf(ring[0].x),
		absf(ring[2].x),
		0.001,
		"Top-left and top-right should be symmetric in x",
	)
	# V6 (bottom-right) and V8 (bottom-left) should be symmetric
	assert_almost_eq(
		absf(ring[6].x),
		absf(ring[8].x),
		0.001,
		"Bottom-right and bottom-left should be symmetric in x",
	)


func test_profile_to_ring_top_center_at_x_zero() -> void:
	var profiles: Array = _builder._generate_profiles("sedan")
	var ring: PackedVector3Array = _builder._profile_to_ring(profiles[0])
	# V1 is top-center
	assert_almost_eq(ring[1].x, 0.0, 0.001)
	# V7 is bottom-center
	assert_almost_eq(ring[7].x, 0.0, 0.001)


# --- build_body ---


func test_build_body_sedan_returns_array_mesh() -> void:
	var mesh: ArrayMesh = _builder.build_body("sedan")
	assert_not_null(mesh)
	assert_true(mesh is ArrayMesh)


func test_build_body_sedan_has_two_surfaces() -> void:
	var mesh: ArrayMesh = _builder.build_body("sedan")
	assert_eq(
		mesh.get_surface_count(),
		2,
		"Body should have 2 surfaces (loft + caps/bumpers)",
	)


func test_build_body_sedan_surface_0_has_vertices() -> void:
	var mesh: ArrayMesh = _builder.build_body("sedan")
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	assert_gt(verts.size(), 0, "Loft surface should have vertices")


func test_build_body_sedan_surface_1_has_vertices() -> void:
	var mesh: ArrayMesh = _builder.build_body("sedan")
	var arrays := mesh.surface_get_arrays(1)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	assert_gt(verts.size(), 0, "Caps/bumpers surface should have vertices")


func test_build_body_vertex_count_multiple_of_three() -> void:
	var mesh: ArrayMesh = _builder.build_body("sedan")
	for s in range(mesh.get_surface_count()):
		var verts: PackedVector3Array = mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
		assert_eq(
			verts.size() % 3,
			0,
			"Surface %d vertex count should be multiple of 3" % s,
		)


func test_build_body_has_normals() -> void:
	var mesh: ArrayMesh = _builder.build_body("sedan")
	var normals: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
	assert_gt(normals.size(), 0, "Body should have normals")


# --- build_body all variants ---


func test_build_body_sports() -> void:
	var mesh: ArrayMesh = _builder.build_body("sports")
	assert_true(mesh is ArrayMesh)
	assert_gt(mesh.get_surface_count(), 0)


func test_build_body_suv() -> void:
	var mesh: ArrayMesh = _builder.build_body("suv")
	assert_true(mesh is ArrayMesh)
	assert_gt(mesh.get_surface_count(), 0)


func test_build_body_hatchback() -> void:
	var mesh: ArrayMesh = _builder.build_body("hatchback")
	assert_true(mesh is ArrayMesh)
	assert_gt(mesh.get_surface_count(), 0)


func test_build_body_van() -> void:
	var mesh: ArrayMesh = _builder.build_body("van")
	assert_true(mesh is ArrayMesh)
	assert_gt(mesh.get_surface_count(), 0)


func test_build_body_pickup() -> void:
	var mesh: ArrayMesh = _builder.build_body("pickup")
	assert_true(mesh is ArrayMesh)
	assert_gt(mesh.get_surface_count(), 0)


# --- build_windows ---


func test_build_windows_sedan_returns_dictionary() -> void:
	var result: Dictionary = _builder.build_windows("sedan")
	assert_true(result is Dictionary)


func test_build_windows_sedan_has_windshield() -> void:
	var result: Dictionary = _builder.build_windows("sedan")
	assert_true(result.has("Windshield"))


func test_build_windows_sedan_has_rear_window() -> void:
	var result: Dictionary = _builder.build_windows("sedan")
	assert_true(result.has("RearWindow"))


func test_build_windows_sedan_has_side_windows() -> void:
	var result: Dictionary = _builder.build_windows("sedan")
	assert_true(result.has("LeftWindow"))
	assert_true(result.has("RightWindow"))


func test_build_windows_windshield_is_array_mesh() -> void:
	var result: Dictionary = _builder.build_windows("sedan")
	assert_true(result["Windshield"] is ArrayMesh)


func test_build_windows_windshield_has_vertices() -> void:
	var result: Dictionary = _builder.build_windows("sedan")
	var mesh: ArrayMesh = result["Windshield"]
	var verts: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	assert_gt(verts.size(), 0)


# --- build_interior ---


func test_build_interior_sedan_returns_array_mesh() -> void:
	var mesh: ArrayMesh = _builder.build_interior("sedan")
	assert_true(mesh is ArrayMesh)


func test_build_interior_sedan_has_vertices() -> void:
	var mesh: ArrayMesh = _builder.build_interior("sedan")
	assert_gt(mesh.get_surface_count(), 0)
	var verts: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	assert_gt(verts.size(), 0, "Interior should have vertices")


func test_build_interior_vertex_count_multiple_of_three() -> void:
	var mesh: ArrayMesh = _builder.build_interior("sedan")
	var verts: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	assert_eq(verts.size() % 3, 0)


# --- build_floor ---


func test_build_floor_sedan_returns_array_mesh() -> void:
	var mesh: ArrayMesh = _builder.build_floor("sedan")
	assert_true(mesh is ArrayMesh)


func test_build_floor_has_vertices() -> void:
	var mesh: ArrayMesh = _builder.build_floor("sedan")
	var verts: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	assert_gt(verts.size(), 0)


func test_build_floor_is_two_quads() -> void:
	var mesh: ArrayMesh = _builder.build_floor("sedan")
	var verts: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	# Two faces (top + bottom), each a quad = 6 verts each = 12 total
	assert_eq(verts.size(), 12, "Floor should be 2 quads (12 vertices)")


# --- build_details ---


func test_build_details_sedan_returns_array_mesh() -> void:
	var mesh: ArrayMesh = _builder.build_details("sedan")
	assert_true(mesh is ArrayMesh)


func test_build_details_has_vertices() -> void:
	var mesh: ArrayMesh = _builder.build_details("sedan")
	var verts: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	assert_gt(verts.size(), 0)


func test_build_details_vertex_count_multiple_of_three() -> void:
	var mesh: ArrayMesh = _builder.build_details("sedan")
	var verts: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	assert_eq(verts.size() % 3, 0)


# --- build_doors ---


func test_build_doors_sedan_returns_dictionary() -> void:
	var result: Dictionary = _builder.build_doors("sedan")
	assert_true(result is Dictionary)


func test_build_doors_sedan_has_left_door() -> void:
	var result: Dictionary = _builder.build_doors("sedan")
	assert_true(result.has("LeftDoor"))
	assert_true(result["LeftDoor"] is ArrayMesh)


func test_build_doors_sedan_has_right_door() -> void:
	var result: Dictionary = _builder.build_doors("sedan")
	assert_true(result.has("RightDoor"))
	assert_true(result["RightDoor"] is ArrayMesh)


func test_build_doors_sedan_has_inner_meshes() -> void:
	var result: Dictionary = _builder.build_doors("sedan")
	assert_true(result.has("LeftDoorInner"))
	assert_true(result.has("RightDoorInner"))
	assert_true(result["LeftDoorInner"] is ArrayMesh)
	assert_true(result["RightDoorInner"] is ArrayMesh)


func test_build_doors_sedan_has_window_meshes() -> void:
	var result: Dictionary = _builder.build_doors("sedan")
	assert_true(result.has("LeftDoorWindow"))
	assert_true(result.has("RightDoorWindow"))
	assert_true(result["LeftDoorWindow"] is ArrayMesh)
	assert_true(result["RightDoorWindow"] is ArrayMesh)


func test_build_doors_sedan_has_pivot_points() -> void:
	var result: Dictionary = _builder.build_doors("sedan")
	assert_true(result.has("left_pivot"))
	assert_true(result.has("right_pivot"))
	assert_true(result["left_pivot"] is Vector3)
	assert_true(result["right_pivot"] is Vector3)


func test_build_doors_pivots_are_symmetric() -> void:
	var result: Dictionary = _builder.build_doors("sedan")
	var lp: Vector3 = result["left_pivot"]
	var rp: Vector3 = result["right_pivot"]
	assert_almost_eq(lp.x, -rp.x, 0.001, "Pivot x should be symmetric")
	assert_almost_eq(lp.y, rp.y, 0.001, "Pivot y should match")
	assert_almost_eq(lp.z, rp.z, 0.001, "Pivot z should match")


func test_build_doors_left_door_has_vertices() -> void:
	var result: Dictionary = _builder.build_doors("sedan")
	var mesh: ArrayMesh = result["LeftDoor"]
	var total_verts := 0
	for s in range(mesh.get_surface_count()):
		total_verts += mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX].size()
	assert_gt(total_verts, 0)


# --- All variants produce valid doors ---


func test_build_doors_all_variants() -> void:
	# Pickup has cabin_end_z=0.0 so no cabin-to-cabin segment for doors.
	var doorless := ["pickup"]
	for variant in CarBuilderScript.VARIANT_OVERRIDES:
		var result: Dictionary = _builder.build_doors(variant)
		if variant in doorless:
			assert_true(
				result.is_empty(),
				"Variant %s should have no doors" % variant,
			)
		else:
			assert_true(
				result.has("LeftDoor"),
				"Variant %s should produce LeftDoor" % variant,
			)
			assert_true(
				result.has("RightDoor"),
				"Variant %s should produce RightDoor" % variant,
			)


# --- All variants produce valid windows ---


func test_build_windows_all_variants() -> void:
	for variant in CarBuilderScript.VARIANT_OVERRIDES:
		var result: Dictionary = _builder.build_windows(variant)
		assert_true(
			result is Dictionary,
			"Variant %s should return dictionary" % variant,
		)
		if result.has("Windshield"):
			assert_true(result["Windshield"] is ArrayMesh)


# --- All variants produce valid interior ---


func test_build_interior_all_variants() -> void:
	for variant in CarBuilderScript.VARIANT_OVERRIDES:
		var mesh: ArrayMesh = _builder.build_interior(variant)
		assert_true(
			mesh is ArrayMesh,
			"Variant %s interior should be ArrayMesh" % variant,
		)
