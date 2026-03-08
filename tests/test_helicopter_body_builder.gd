extends GutTest
## Unit tests for helicopter body builder mesh generation.

var _builder: RefCounted = null


func before_each() -> void:
	_builder = preload(
		"res://scenes/vehicles/helicopter_body_builder.gd"
	).new()


func test_build_fuselage_returns_mesh() -> void:
	var mesh := _builder.build_fuselage()
	assert_not_null(mesh, "build_fuselage should return a mesh")
	assert_true(mesh is ArrayMesh, "Should be an ArrayMesh")


func test_build_fuselage_has_vertices() -> void:
	var mesh := _builder.build_fuselage()
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	assert_gt(
		verts.size(), 0,
		"Fuselage mesh should have vertices",
	)


func test_build_main_rotor_returns_mesh() -> void:
	var mesh := _builder.build_main_rotor()
	assert_not_null(mesh, "build_main_rotor should return a mesh")
	assert_true(mesh is ArrayMesh, "Should be an ArrayMesh")


func test_build_main_rotor_has_vertices() -> void:
	var mesh := _builder.build_main_rotor()
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	assert_gt(
		verts.size(), 0,
		"Main rotor mesh should have vertices",
	)


func test_build_tail_rotor_returns_mesh() -> void:
	var mesh := _builder.build_tail_rotor()
	assert_not_null(mesh, "build_tail_rotor should return a mesh")
	assert_true(mesh is ArrayMesh, "Should be an ArrayMesh")


func test_build_tail_rotor_has_vertices() -> void:
	var mesh := _builder.build_tail_rotor()
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	assert_gt(
		verts.size(), 0,
		"Tail rotor mesh should have vertices",
	)


func test_fuselage_vertex_count_is_multiple_of_three() -> void:
	var mesh := _builder.build_fuselage()
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	assert_eq(
		verts.size() % 3, 0,
		"Triangle mesh vertex count should be multiple of 3",
	)


func test_main_rotor_vertex_count_is_multiple_of_three() -> void:
	var mesh := _builder.build_main_rotor()
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	assert_eq(
		verts.size() % 3, 0,
		"Triangle mesh vertex count should be multiple of 3",
	)
