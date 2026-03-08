extends GutTest
## Unit tests for building interiors: door geometry, interior rooms,
## and collision decomposition.

const CityScript = preload("res://scenes/world/city.gd")
const BuilderScript = preload(
	"res://scenes/world/generator/chunk_builder_buildings.gd"
)
const RoadGridScript = preload("res://src/road_grid.gd")


# --- st_add_quad tests ---

func test_st_add_quad_emits_six_vertices() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bl := Vector3(0, 0, 0)
	var br := Vector3(1, 0, 0)
	var tr := Vector3(1, 1, 0)
	var tl := Vector3(0, 1, 0)
	CityScript.st_add_quad(st, bl, br, tr, tl)
	st.generate_normals()
	var mesh := st.commit()
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	assert_eq(
		verts.size(), 6,
		"st_add_quad should emit 6 vertices (2 triangles)",
	)


func test_st_add_quad_winding_order() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bl := Vector3(0, 0, 0)
	var br := Vector3(2, 0, 0)
	var tr := Vector3(2, 3, 0)
	var tl := Vector3(0, 3, 0)
	CityScript.st_add_quad(st, bl, br, tr, tl)
	st.generate_normals()
	var mesh := st.commit()
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	# Triangle 1: bl, tr, br (CCW for -Z normal)
	assert_eq(verts[0], bl, "Tri1 v0 should be bl")
	assert_eq(verts[1], tr, "Tri1 v1 should be tr")
	assert_eq(verts[2], br, "Tri1 v2 should be br")
	# Triangle 2: bl, tl, tr
	assert_eq(verts[3], bl, "Tri2 v0 should be bl")
	assert_eq(verts[4], tl, "Tri2 v1 should be tl")
	assert_eq(verts[5], tr, "Tri2 v2 should be tr")


# --- st_add_face_with_door tests ---

func test_face_with_door_emits_eighteen_vertices() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var face_center := Vector3(0, 5, -5)
	CityScript.st_add_face_with_door(
		st, face_center,
		10.0, 10.0,
		Vector3(0, 0, -1), Vector3(1, 0, 0),
		1.2, 2.2,
	)
	st.generate_normals()
	var mesh := st.commit()
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	assert_eq(
		verts.size(), 18,
		"Face with door should emit 18 vertices (3 quads x 6 verts)",
	)


func test_face_with_door_leaves_opening() -> void:
	# Verify no vertices exist within the door opening region
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var face_center := Vector3(0, 5, -5)
	var door_w := 1.2
	var door_h := 2.2
	CityScript.st_add_face_with_door(
		st, face_center,
		10.0, 10.0,
		Vector3(0, 0, -1), Vector3(1, 0, 0),
		door_w, door_h,
	)
	st.generate_normals()
	var mesh := st.commit()
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]

	# Door opening: x in [-0.6, 0.6], y in [0.0, 2.2]
	var door_half_w := door_w * 0.5
	var bottom_y := face_center.y - 5.0  # 0.0
	var door_top_y := bottom_y + door_h  # 2.2
	var margin := 0.01
	for v in verts:
		var in_door_x: bool = (
			v.x > -door_half_w + margin and v.x < door_half_w - margin
		)
		var in_door_y: bool = (
			v.y > bottom_y + margin and v.y < door_top_y - margin
		)
		assert_false(
			in_door_x and in_door_y,
			"No vertex should be strictly inside the door opening",
		)
