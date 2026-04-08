extends GutTest
## Tests for scenes/world/city.gd — constants, static helpers, edge mismatch
## logic, and material/mesh initialization.

const CityScript = preload("res://scenes/world/city.gd")
const RoadGridScript = preload("res://src/road_grid.gd")

# ==========================================================================
# Constants
# ==========================================================================


func test_chunk_load_radius() -> void:
	assert_eq(
		CityScript.CHUNK_LOAD_RADIUS,
		2.0,
		"CHUNK_LOAD_RADIUS should be 2.0",
	)


func test_chunk_unload_radius() -> void:
	assert_eq(
		CityScript.CHUNK_UNLOAD_RADIUS,
		3.0,
		"CHUNK_UNLOAD_RADIUS should be 3.0",
	)


func test_unload_radius_greater_than_load_radius() -> void:
	assert_gt(
		CityScript.CHUNK_UNLOAD_RADIUS,
		CityScript.CHUNK_LOAD_RADIUS,
		"Unload radius must exceed load radius to prevent flicker",
	)


func test_update_interval() -> void:
	assert_eq(
		CityScript.UPDATE_INTERVAL,
		0.5,
		"UPDATE_INTERVAL should be 0.5 seconds",
	)


func test_scan_range() -> void:
	assert_eq(
		CityScript.SCAN_RANGE,
		5,
		"SCAN_RANGE should be 5",
	)


func test_lookahead_time() -> void:
	assert_eq(
		CityScript.LOOKAHEAD_TIME,
		3.0,
		"LOOKAHEAD_TIME should be 3.0 seconds",
	)


func test_flush_interval() -> void:
	assert_eq(
		CityScript.FLUSH_INTERVAL,
		5.0,
		"FLUSH_INTERVAL should be 5.0 seconds",
	)


func test_sea_level() -> void:
	assert_eq(
		CityScript.SEA_LEVEL,
		-2.0,
		"SEA_LEVEL should be -2.0",
	)


func test_edge_mismatch_threshold() -> void:
	assert_eq(
		CityScript.EDGE_MISMATCH_THRESHOLD,
		0.05,
		"EDGE_MISMATCH_THRESHOLD should be 0.05 meters",
	)


func test_max_cascading_repairs() -> void:
	assert_eq(
		CityScript.MAX_CASCADING_REPAIRS,
		12,
		"MAX_CASCADING_REPAIRS should be 12",
	)


func test_dir_offsets_has_four_directions() -> void:
	assert_eq(
		CityScript.DIR_OFFSETS.size(),
		4,
		"DIR_OFFSETS should have 4 entries",
	)


func test_dir_offsets_north() -> void:
	assert_eq(
		CityScript.DIR_OFFSETS[0],
		Vector2i(0, -1),
		"Direction 0 (NORTH) should be (0, -1)",
	)


func test_dir_offsets_east() -> void:
	assert_eq(
		CityScript.DIR_OFFSETS[1],
		Vector2i(1, 0),
		"Direction 1 (EAST) should be (1, 0)",
	)


func test_dir_offsets_south() -> void:
	assert_eq(
		CityScript.DIR_OFFSETS[2],
		Vector2i(0, 1),
		"Direction 2 (SOUTH) should be (0, 1)",
	)


func test_dir_offsets_west() -> void:
	assert_eq(
		CityScript.DIR_OFFSETS[3],
		Vector2i(-1, 0),
		"Direction 3 (WEST) should be (-1, 0)",
	)


func test_opposite_directions_cancel() -> void:
	for dir: int in CityScript.DIR_OFFSETS:
		var opposite: int = (dir + 2) % 4
		var sum: Vector2i = CityScript.DIR_OFFSETS[dir] + CityScript.DIR_OFFSETS[opposite]
		assert_eq(
			sum,
			Vector2i.ZERO,
			"Direction %d and its opposite %d should cancel" % [dir, opposite],
		)


# ==========================================================================
# Static helper: st_add_box
# ==========================================================================


func test_st_add_box_adds_36_vertices() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	CityScript.st_add_box(st, Vector3.ZERO, Vector3.ONE)
	var mesh: ArrayMesh = st.commit()
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	assert_eq(
		verts.size(),
		36,
		"st_add_box should emit 36 vertices (12 triangles)",
	)


func test_st_add_box_no_bottom_adds_30_vertices() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	CityScript.st_add_box_no_bottom(st, Vector3.ZERO, Vector3.ONE)
	var mesh: ArrayMesh = st.commit()
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	assert_eq(
		verts.size(),
		30,
		"st_add_box_no_bottom should emit 30 vertices (10 triangles)",
	)


# ==========================================================================
# Static helper: st_add_quad
# ==========================================================================


func test_st_add_quad_adds_6_vertices() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	(
		CityScript
		. st_add_quad(
			st,
			Vector3(0, 0, 0),
			Vector3(1, 0, 0),
			Vector3(1, 1, 0),
			Vector3(0, 1, 0),
		)
	)
	var mesh: ArrayMesh = st.commit()
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	assert_eq(
		verts.size(),
		6,
		"st_add_quad should emit 6 vertices (2 triangles)",
	)


# ==========================================================================
# Static helper: st_add_quad_xz
# ==========================================================================


func test_st_add_quad_xz_adds_6_vertices() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	CityScript.st_add_quad_xz(st, 0.0, 0.0, 5.0, 5.0, 0.0)
	var mesh: ArrayMesh = st.commit()
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	assert_eq(
		verts.size(),
		6,
		"st_add_quad_xz should emit 6 vertices",
	)


func test_st_add_quad_xz_at_correct_y() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var y_level := 3.5
	CityScript.st_add_quad_xz(st, 0.0, 0.0, 1.0, 1.0, y_level)
	var mesh: ArrayMesh = st.commit()
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for v: Vector3 in verts:
		assert_almost_eq(
			v.y,
			y_level,
			0.001,
			"All XZ quad vertices should be at the specified y level",
		)


# ==========================================================================
# Static helper: add_box_collision
# ==========================================================================


func test_add_box_collision_creates_collision_shape() -> void:
	var body := StaticBody3D.new()
	add_child_autofree(body)
	CityScript.add_box_collision(body, Vector3.ZERO, Vector3(2, 3, 4))
	assert_eq(
		body.get_child_count(),
		1,
		"Should add one collision shape child",
	)
	var col: CollisionShape3D = body.get_child(0) as CollisionShape3D
	assert_not_null(col, "Child should be CollisionShape3D")
	var shape: BoxShape3D = col.shape as BoxShape3D
	assert_not_null(shape, "Shape should be BoxShape3D")
	assert_eq(
		shape.size,
		Vector3(2, 3, 4),
		"Box shape size should match",
	)


# ==========================================================================
# Static helper: add_cylinder_collision
# ==========================================================================


func test_add_cylinder_collision_creates_collision_shape() -> void:
	var body := StaticBody3D.new()
	add_child_autofree(body)
	CityScript.add_cylinder_collision(body, Vector3(1, 2, 3), 0.5, 4.0)
	var col: CollisionShape3D = body.get_child(0) as CollisionShape3D
	assert_not_null(col)
	var shape: CylinderShape3D = col.shape as CylinderShape3D
	assert_not_null(shape)
	assert_almost_eq(shape.radius, 0.5, 0.001, "Radius should be 0.5")
	assert_almost_eq(shape.height, 4.0, 0.001, "Height should be 4.0")
	assert_eq(
		col.position,
		Vector3(1, 2, 3),
		"Collision position should match center",
	)


# ==========================================================================
# Static helper: add_sidewalk_collision
# ==========================================================================


func test_add_sidewalk_collision_z_axis() -> void:
	var body := StaticBody3D.new()
	add_child_autofree(body)
	(
		CityScript
		. add_sidewalk_collision(
			body,
			Vector3.ZERO,
			2.5,
			10.0,
			0.1,
			1.0,
			"z",
		)
	)
	var col: CollisionShape3D = body.get_child(0) as CollisionShape3D
	assert_not_null(col)
	var shape: ConvexPolygonShape3D = col.shape as ConvexPolygonShape3D
	assert_not_null(shape, "Shape should be ConvexPolygonShape3D")
	assert_eq(
		shape.points.size(),
		8,
		"Sidewalk collision should have 8 points",
	)


func test_add_sidewalk_collision_x_axis() -> void:
	var body := StaticBody3D.new()
	add_child_autofree(body)
	(
		CityScript
		. add_sidewalk_collision(
			body,
			Vector3.ZERO,
			2.5,
			10.0,
			0.1,
			1.0,
			"x",
		)
	)
	var col: CollisionShape3D = body.get_child(0) as CollisionShape3D
	assert_not_null(col)
	var shape: ConvexPolygonShape3D = col.shape as ConvexPolygonShape3D
	assert_not_null(shape)
	assert_eq(shape.points.size(), 8)


# ==========================================================================
# Static helper: st_add_face_with_door
# ==========================================================================


func test_st_add_face_with_door_creates_three_strips() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	(
		CityScript
		. st_add_face_with_door(
			st,
			Vector3(0, 2, 0),  # face_center
			10.0,
			4.0,  # face_width, face_height
			Vector3(0, 0, -1),  # normal
			Vector3(1, 0, 0),  # right
			2.0,
			2.5,  # door_width, door_height
		)
	)
	var mesh: ArrayMesh = st.commit()
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	# 3 quads = 3 * 6 = 18 vertices
	assert_eq(
		verts.size(),
		18,
		"Face with door should produce 3 quad strips (18 vertices)",
	)


# ==========================================================================
# Edge mismatch logic (tested via source code inspection since the method
# is not static but we can instantiate a bare script)
# ==========================================================================


func test_edges_mismatch_empty_same_size() -> void:
	var city: Node3D = CityScript.new()
	add_child_autofree(city)
	var a := PackedFloat32Array()
	var b := PackedFloat32Array()
	assert_false(
		city._edges_mismatch(a, b),
		"Two empty arrays should not mismatch",
	)


func test_edges_mismatch_different_sizes() -> void:
	var city: Node3D = CityScript.new()
	add_child_autofree(city)
	var a := PackedFloat32Array([1.0, 2.0])
	var b := PackedFloat32Array([1.0])
	assert_true(
		city._edges_mismatch(a, b),
		"Different sized arrays should mismatch",
	)


func test_edges_mismatch_identical() -> void:
	var city: Node3D = CityScript.new()
	add_child_autofree(city)
	var a := PackedFloat32Array([1.0, 2.0, 3.0])
	var b := PackedFloat32Array([1.0, 2.0, 3.0])
	assert_false(
		city._edges_mismatch(a, b),
		"Identical arrays should not mismatch",
	)


func test_edges_mismatch_within_threshold() -> void:
	var city: Node3D = CityScript.new()
	add_child_autofree(city)
	var a := PackedFloat32Array([1.0, 2.0, 3.0])
	var b := PackedFloat32Array([1.04, 2.04, 3.04])
	assert_false(
		city._edges_mismatch(a, b),
		"Values within 0.05 threshold should not mismatch",
	)


func test_edges_mismatch_exceeds_threshold() -> void:
	var city: Node3D = CityScript.new()
	add_child_autofree(city)
	var a := PackedFloat32Array([1.0, 2.0, 3.0])
	var b := PackedFloat32Array([1.0, 2.0, 3.6])
	assert_true(
		city._edges_mismatch(a, b),
		"Values exceeding 0.5 threshold should mismatch",
	)


# ==========================================================================
# Initialization defaults
# ==========================================================================


func test_chunks_dict_populated_after_ready() -> void:
	var city: Node3D = CityScript.new()
	add_child_autofree(city)
	# _ready calls _load_chunks_around(Vector3.ZERO), so chunks should exist
	assert_gt(
		city._chunks.size(),
		0,
		"_chunks should be populated after _ready loads around origin",
	)


func test_player_starts_null() -> void:
	var city: Node3D = CityScript.new()
	add_child_autofree(city)
	assert_null(city._player, "_player should be null initially")


func test_player_found_starts_false() -> void:
	var city: Node3D = CityScript.new()
	add_child_autofree(city)
	assert_false(
		city._player_found,
		"_player_found should be false initially",
	)


func test_repairing_starts_false() -> void:
	var city: Node3D = CityScript.new()
	add_child_autofree(city)
	assert_false(
		city._repairing,
		"_repairing should be false initially",
	)


# ==========================================================================
# Initial cache flush (M2 fix)
# ==========================================================================


func test_ready_calls_tile_cache_flush() -> void:
	var src: String = (CityScript as GDScript).source_code
	var ready_start: int = src.find("func _ready()")
	var ready_end: int = src.find("\nfunc ", ready_start + 1)
	var ready_body: String = src.substr(ready_start, ready_end - ready_start)
	assert_true(
		ready_body.contains("_tile_cache.flush()"),
		"_ready must call _tile_cache.flush() to persist initial generation",
	)
