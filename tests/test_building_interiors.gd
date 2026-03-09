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


# --- _add_building_with_door exterior tests ---

func _make_builder() -> RefCounted:
	var builder = BuilderScript.new()
	var grid = RoadGridScript.new()
	var mats: Array[StandardMaterial3D] = []
	for _i in 3:
		mats.append(StandardMaterial3D.new())
	var win_mats: Array[StandardMaterial3D] = []
	for _i in 4:
		win_mats.append(StandardMaterial3D.new())
	builder.init(grid, mats, win_mats, StandardMaterial3D.new())
	return builder


func test_door_building_exterior_vertex_count() -> void:
	# Door building exterior: 3 solid faces (6 verts each = 18) +
	# 1 door face (18 verts) + top face (6 verts) = 42 verts total
	var builder = _make_builder()
	var ext_st := SurfaceTool.new()
	ext_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var int_st := SurfaceTool.new()
	int_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var center := Vector3(0, 5, 0)
	var size := Vector3(10, 10, 10)
	builder._add_building_with_door(ext_st, int_st, center, size, 0)
	ext_st.generate_normals()
	var mesh := ext_st.commit()
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	assert_eq(
		verts.size(), 42,
		"Door building exterior should emit 42 vertices",
	)


func test_door_building_all_faces_produce_geometry() -> void:
	# Test that all 4 door face indices produce valid geometry
	var builder = _make_builder()
	for face_idx in range(4):
		var ext_st := SurfaceTool.new()
		ext_st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var int_st := SurfaceTool.new()
		int_st.begin(Mesh.PRIMITIVE_TRIANGLES)
		builder._add_building_with_door(
			ext_st, int_st,
			Vector3(0, 5, 0), Vector3(10, 10, 10),
			face_idx,
		)
		ext_st.generate_normals()
		var mesh := ext_st.commit()
		var arrays := mesh.surface_get_arrays(0)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		assert_eq(
			verts.size(), 42,
			"Face %d should emit 42 exterior vertices" % face_idx,
		)


# --- Interior room tests ---

func test_interior_room_vertex_count() -> void:
	# Interior: floor (6) + ceiling (6) + 3 solid walls (6 each = 18) +
	# 1 door wall (18) = 48 vertices total
	var builder = _make_builder()
	var ext_st := SurfaceTool.new()
	ext_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var int_st := SurfaceTool.new()
	int_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	builder._add_building_with_door(
		ext_st, int_st,
		Vector3(0, 5, 0), Vector3(10, 10, 10), 0,
	)
	int_st.generate_normals()
	var mesh := int_st.commit()
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	assert_eq(
		verts.size(), 48,
		"Interior room should emit 48 vertices",
	)


func test_interior_floor_above_ground() -> void:
	# Verify interior floor Y is above building bottom (z-fight avoidance)
	var builder = _make_builder()
	var ext_st := SurfaceTool.new()
	ext_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var int_st := SurfaceTool.new()
	int_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var center := Vector3(0, 5, 0)
	var size := Vector3(10, 10, 10)
	builder._add_building_with_door(
		ext_st, int_st, center, size, 0,
	)
	int_st.generate_normals()
	var mesh := int_st.commit()
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var building_bottom: float = center.y - size.y * 0.5
	var min_y := 999.0
	for v in verts:
		if v.y < min_y:
			min_y = v.y
	assert_gt(
		min_y, building_bottom,
		"Interior floor should be above building bottom (z-fight)",
	)


# --- Collision shape tests ---

func test_door_building_collision_shape_count() -> void:
	# Door building collision: 3 solid walls + 3 split door wall pieces
	# + 1 ceiling + 1 floor = 8 CollisionShape3D nodes
	var builder = _make_builder()
	var body := StaticBody3D.new()
	add_child_autofree(body)
	var center := Vector3(0, 5, 0)
	var size := Vector3(10, 10, 10)
	builder._add_building_collision_with_door(body, center, size, 0)
	var shape_count := 0
	for i in body.get_child_count():
		if body.get_child(i) is CollisionShape3D:
			shape_count += 1
	assert_eq(
		shape_count, 8,
		"Door building should have 8 collision shapes",
	)


func test_build_creates_interiors_mesh() -> void:
	# Building a full chunk should create an Interiors MeshInstance3D
	var builder = _make_builder()
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	builder.build(chunk, Vector2i(0, 0), 0.0, 0.0)
	var body: Node = chunk.get_child(0)
	var found_interiors := false
	for i in body.get_child_count():
		if body.get_child(i).name == &"Interiors":
			found_interiors = true
			break
	assert_true(
		found_interiors,
		"Chunk should have an Interiors MeshInstance3D",
	)


func test_build_deterministic_with_interiors() -> void:
	var builder = _make_builder()
	var chunk1 := Node3D.new()
	add_child_autofree(chunk1)
	builder.build(chunk1, Vector2i(3, 7), 0.0, 0.0)
	var chunk2 := Node3D.new()
	add_child_autofree(chunk2)
	builder.build(chunk2, Vector2i(3, 7), 0.0, 0.0)

	var body1: Node = chunk1.get_child(0)
	var body2: Node = chunk2.get_child(0)
	var names1: Array[String] = []
	var names2: Array[String] = []
	for i in body1.get_child_count():
		names1.append(_strip_id(body1.get_child(i).name))
	for i in body2.get_child_count():
		names2.append(_strip_id(body2.get_child(i).name))
	assert_eq(
		names1, names2,
		"Same tile should produce deterministic child list",
	)


## Strip Godot's auto-appended @ID suffix from node names for comparison.
static func _strip_id(n: StringName) -> String:
	var s := String(n)
	var at := s.rfind("@")
	if at > 0:
		return s.left(at)
	return s
