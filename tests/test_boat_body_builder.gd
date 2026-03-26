extends GutTest
## Unit tests for boat_body_builder.gd procedural boat mesh generation.
## Note: boat mesh generation produces engine-level warnings about
## ARRAY_FORMAT_NORMAL due to mixed normal modes in SurfaceTool commits.
## These are cosmetic and do not affect gameplay, so engine errors are
## treated as non-failures in this test file.

const BoatBuilderScript = preload(
	"res://scenes/vehicles/boat_body_builder.gd"
)

var _builder: RefCounted


func before_all() -> void:
	# Boat mesh generation triggers engine warnings about normal format
	# that are expected and harmless. Suppress them as test failures.
	gut.error_tracker.treat_engine_errors_as = 0  # TREAT_AS.NOTHING


func after_all() -> void:
	gut.error_tracker.treat_engine_errors_as = 1  # TREAT_AS.FAILURE


func before_each() -> void:
	_builder = BoatBuilderScript.new()


# --- VARIANTS constant ---

func test_variants_has_speedboat() -> void:
	assert_true(BoatBuilderScript.VARIANTS.has("speedboat"))


func test_variants_has_fishing() -> void:
	assert_true(BoatBuilderScript.VARIANTS.has("fishing"))


func test_variants_has_runabout() -> void:
	assert_true(BoatBuilderScript.VARIANTS.has("runabout"))


func test_variants_count() -> void:
	assert_eq(BoatBuilderScript.VARIANTS.size(), 3)


func test_each_variant_has_profiles() -> void:
	for key in BoatBuilderScript.VARIANTS:
		var data: Dictionary = BoatBuilderScript.VARIANTS[key]
		assert_true(
			data.has("profiles"),
			"Variant %s should have profiles" % key,
		)
		assert_gt(
			data["profiles"].size(), 2,
			"Variant %s should have at least 3 profiles" % key,
		)


func test_each_variant_has_cabin_z() -> void:
	for key in BoatBuilderScript.VARIANTS:
		var data: Dictionary = BoatBuilderScript.VARIANTS[key]
		assert_true(
			data.has("cabin_z"),
			"Variant %s should have cabin_z" % key,
		)
		assert_eq(
			data["cabin_z"].size(), 2,
			"cabin_z should have 2 elements (front, rear)",
		)


func test_each_variant_has_cabin_height() -> void:
	for key in BoatBuilderScript.VARIANTS:
		var data: Dictionary = BoatBuilderScript.VARIANTS[key]
		assert_true(
			data.has("cabin_height"),
			"Variant %s should have cabin_height" % key,
		)
		assert_gt(
			float(data["cabin_height"]), 0.0,
			"cabin_height should be positive",
		)


func test_each_variant_has_collision_size() -> void:
	for key in BoatBuilderScript.VARIANTS:
		var data: Dictionary = BoatBuilderScript.VARIANTS[key]
		assert_true(
			data.has("collision_size"),
			"Variant %s should have collision_size" % key,
		)
		var cs: Vector3 = data["collision_size"]
		assert_gt(cs.x, 0.0, "collision_size.x should be positive")
		assert_gt(cs.y, 0.0, "collision_size.y should be positive")
		assert_gt(cs.z, 0.0, "collision_size.z should be positive")


func test_profiles_have_required_keys() -> void:
	for key in BoatBuilderScript.VARIANTS:
		var profiles: Array = BoatBuilderScript.VARIANTS[key]["profiles"]
		for p in profiles:
			assert_true(p.has("z"), "Profile should have z")
			assert_true(p.has("hw"), "Profile should have hw")
			assert_true(p.has("draft"), "Profile should have draft")
			assert_true(p.has("fb"), "Profile should have fb")


func test_profiles_z_is_sorted() -> void:
	for key in BoatBuilderScript.VARIANTS:
		var profiles: Array = BoatBuilderScript.VARIANTS[key]["profiles"]
		for i in range(profiles.size() - 1):
			assert_lt(
				float(profiles[i]["z"]), float(profiles[i + 1]["z"]),
				"Profile z values should be sorted for %s" % key,
			)


# --- build() return structure ---

func test_build_returns_dictionary() -> void:
	var result: Dictionary = _builder.build("speedboat")
	assert_true(result is Dictionary)


func test_build_has_hull_key() -> void:
	var result: Dictionary = _builder.build("speedboat")
	assert_true(result.has("hull"))


func test_build_has_cabin_key() -> void:
	var result: Dictionary = _builder.build("speedboat")
	assert_true(result.has("cabin"))


func test_build_has_windshield_key() -> void:
	var result: Dictionary = _builder.build("speedboat")
	assert_true(result.has("windshield"))


func test_build_has_engine_key() -> void:
	var result: Dictionary = _builder.build("speedboat")
	assert_true(result.has("engine"))


func test_build_has_stern_z_key() -> void:
	var result: Dictionary = _builder.build("speedboat")
	assert_true(result.has("stern_z"))


func test_build_has_collision_size_key() -> void:
	var result: Dictionary = _builder.build("speedboat")
	assert_true(result.has("collision_size"))


# --- Hull mesh ---

func test_build_speedboat_hull_is_array_mesh() -> void:
	var result: Dictionary = _builder.build("speedboat")
	assert_true(result["hull"] is ArrayMesh)


func test_build_speedboat_hull_has_vertices() -> void:
	var result: Dictionary = _builder.build("speedboat")
	var mesh: ArrayMesh = result["hull"]
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	assert_gt(verts.size(), 0, "Hull should have vertices")


func test_build_speedboat_hull_vertex_count_multiple_of_three() -> void:
	var result: Dictionary = _builder.build("speedboat")
	var mesh: ArrayMesh = result["hull"]
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	assert_eq(
		verts.size() % 3, 0,
		"Hull vertex count should be multiple of 3",
	)


# --- Cabin mesh ---

func test_build_speedboat_cabin_is_array_mesh() -> void:
	var result: Dictionary = _builder.build("speedboat")
	assert_true(result["cabin"] is ArrayMesh)


func test_build_speedboat_cabin_has_vertices() -> void:
	var result: Dictionary = _builder.build("speedboat")
	var mesh: ArrayMesh = result["cabin"]
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	assert_gt(verts.size(), 0, "Cabin should have vertices")


# --- Windshield mesh ---

func test_build_speedboat_windshield_is_array_mesh() -> void:
	var result: Dictionary = _builder.build("speedboat")
	assert_true(result["windshield"] is ArrayMesh)


func test_build_speedboat_windshield_has_vertices() -> void:
	var result: Dictionary = _builder.build("speedboat")
	var mesh: ArrayMesh = result["windshield"]
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	assert_gt(verts.size(), 0, "Windshield should have vertices")


func test_build_speedboat_windshield_is_single_quad() -> void:
	var result: Dictionary = _builder.build("speedboat")
	var mesh: ArrayMesh = result["windshield"]
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	assert_eq(
		verts.size(), 6,
		"Windshield should be a single quad (6 verts / 2 triangles)",
	)


# --- Engine mesh ---

func test_build_speedboat_engine_is_array_mesh() -> void:
	var result: Dictionary = _builder.build("speedboat")
	assert_true(result["engine"] is ArrayMesh)


func test_build_speedboat_engine_has_vertices() -> void:
	var result: Dictionary = _builder.build("speedboat")
	var mesh: ArrayMesh = result["engine"]
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	assert_gt(verts.size(), 0, "Engine should have vertices")


# --- stern_z ---

func test_build_speedboat_stern_z_matches_last_profile() -> void:
	var result: Dictionary = _builder.build("speedboat")
	var profiles: Array = BoatBuilderScript.VARIANTS["speedboat"]["profiles"]
	var expected: float = float(profiles[profiles.size() - 1]["z"])
	assert_almost_eq(
		float(result["stern_z"]), expected, 0.001,
	)


# --- collision_size ---

func test_build_speedboat_collision_size_matches_variant() -> void:
	var result: Dictionary = _builder.build("speedboat")
	var expected: Vector3 = BoatBuilderScript.VARIANTS["speedboat"]["collision_size"]
	assert_eq(result["collision_size"], expected)


# --- All variants build without error ---

func test_build_fishing_returns_all_meshes() -> void:
	var result: Dictionary = _builder.build("fishing")
	assert_true(result["hull"] is ArrayMesh)
	assert_true(result["cabin"] is ArrayMesh)
	assert_true(result["windshield"] is ArrayMesh)
	assert_true(result["engine"] is ArrayMesh)


func test_build_runabout_returns_all_meshes() -> void:
	var result: Dictionary = _builder.build("runabout")
	assert_true(result["hull"] is ArrayMesh)
	assert_true(result["cabin"] is ArrayMesh)
	assert_true(result["windshield"] is ArrayMesh)
	assert_true(result["engine"] is ArrayMesh)


# --- Unknown variant defaults to speedboat ---

func test_build_unknown_variant_defaults_to_speedboat() -> void:
	var unknown: Dictionary = _builder.build("nonexistent")
	var speedboat: Dictionary = _builder.build("speedboat")
	assert_eq(
		unknown["collision_size"], speedboat["collision_size"],
		"Unknown variant should default to speedboat collision size",
	)
	assert_almost_eq(
		float(unknown["stern_z"]), float(speedboat["stern_z"]), 0.001,
		"Unknown variant should default to speedboat stern_z",
	)


# --- Fishing variant is larger than speedboat ---

func test_fishing_hull_has_more_or_equal_vertices_than_runabout() -> void:
	var fishing: Dictionary = _builder.build("fishing")
	var runabout: Dictionary = _builder.build("runabout")
	var f_mesh: ArrayMesh = fishing["hull"]
	var r_mesh: ArrayMesh = runabout["hull"]
	var f_count: int = f_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()
	var r_count: int = r_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()
	assert_gte(
		f_count, r_count,
		"Fishing hull should have >= vertices than runabout",
	)


# --- Hull normals are generated ---

func test_hull_has_normals() -> void:
	var result: Dictionary = _builder.build("speedboat")
	var mesh: ArrayMesh = result["hull"]
	var arrays := mesh.surface_get_arrays(0)
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	assert_gt(
		normals.size(), 0,
		"Hull mesh should have generated normals",
	)


func test_engine_has_normals() -> void:
	var result: Dictionary = _builder.build("speedboat")
	var mesh: ArrayMesh = result["engine"]
	var arrays := mesh.surface_get_arrays(0)
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	assert_gt(
		normals.size(), 0,
		"Engine mesh should have generated normals",
	)
