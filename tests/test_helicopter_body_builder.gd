extends GutTest
## Unit tests for helicopter body builder mesh generation.

const BuilderScript = preload("res://scenes/vehicles/helicopter_body_builder.gd")

var _builder: RefCounted = null


func before_each() -> void:
	_builder = BuilderScript.new()


func test_build_fuselage_returns_mesh() -> void:
	var mesh: ArrayMesh = (_builder as BuilderScript).build_fuselage()
	assert_not_null(mesh, "build_fuselage should return a mesh")
	assert_true(mesh is ArrayMesh, "Should be an ArrayMesh")


func test_build_fuselage_has_vertices() -> void:
	var mesh: ArrayMesh = (_builder as BuilderScript).build_fuselage()
	var arrays: Array = mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	assert_gt(
		verts.size(), 0,
		"Fuselage mesh should have vertices",
	)


func test_build_main_rotor_returns_mesh() -> void:
	var mesh: ArrayMesh = (_builder as BuilderScript).build_main_rotor()
	assert_not_null(mesh, "build_main_rotor should return a mesh")
	assert_true(mesh is ArrayMesh, "Should be an ArrayMesh")


func test_build_main_rotor_has_vertices() -> void:
	var mesh: ArrayMesh = (_builder as BuilderScript).build_main_rotor()
	var arrays: Array = mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	assert_gt(
		verts.size(), 0,
		"Main rotor mesh should have vertices",
	)


func test_build_tail_rotor_returns_mesh() -> void:
	var mesh: ArrayMesh = (_builder as BuilderScript).build_tail_rotor()
	assert_not_null(mesh, "build_tail_rotor should return a mesh")
	assert_true(mesh is ArrayMesh, "Should be an ArrayMesh")


func test_build_tail_rotor_has_vertices() -> void:
	var mesh: ArrayMesh = (_builder as BuilderScript).build_tail_rotor()
	var arrays: Array = mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	assert_gt(
		verts.size(), 0,
		"Tail rotor mesh should have vertices",
	)


func test_fuselage_vertex_count_is_multiple_of_three() -> void:
	var mesh: ArrayMesh = (_builder as BuilderScript).build_fuselage()
	var arrays: Array = mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	assert_eq(
		verts.size() % 3, 0,
		"Triangle mesh vertex count should be multiple of 3",
	)


func test_main_rotor_vertex_count_is_multiple_of_three() -> void:
	var mesh: ArrayMesh = (_builder as BuilderScript).build_main_rotor()
	var arrays: Array = mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	assert_eq(
		verts.size() % 3, 0,
		"Triangle mesh vertex count should be multiple of 3",
	)


func test_build_cockpit_seat_returns_mesh() -> void:
	var mesh: ArrayMesh = (_builder as BuilderScript).build_cockpit_seat()
	assert_not_null(mesh, "build_cockpit_seat should return a mesh")
	assert_true(mesh is ArrayMesh, "Cockpit seat should be an ArrayMesh")


func test_build_cockpit_seat_has_vertices() -> void:
	var mesh: ArrayMesh = (_builder as BuilderScript).build_cockpit_seat()
	var arrays: Array = mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	assert_gt(verts.size(), 0, "Cockpit seat mesh should have vertices")


func test_fuselage_has_two_surfaces() -> void:
	var mesh: ArrayMesh = (_builder as BuilderScript).build_fuselage()
	assert_eq(
		mesh.get_surface_count(), 2,
		"Fuselage should have 2 surfaces (surface 0: solid, surface 1: glass)",
	)


func test_fuselage_glass_surface_has_vertices() -> void:
	var mesh: ArrayMesh = (_builder as BuilderScript).build_fuselage()
	var arrays: Array = mesh.surface_get_arrays(1)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	assert_gt(verts.size(), 0, "Fuselage glass surface (1) should have vertices")
