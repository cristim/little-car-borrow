extends GutTest
## Unit tests for chunk_builder_markings.gd — lane markings, edge lines,
## and pedestrian crossings as a single merged MeshInstance3D.

const MarkingsScript = preload("res://scenes/world/generator/chunk_builder_markings.gd")
const RoadGridScript = preload("res://src/road_grid.gd")

var _grid: RefCounted
var _builder: RefCounted
var _marking_mat: StandardMaterial3D


func before_each() -> void:
	_grid = RoadGridScript.new()
	_marking_mat = StandardMaterial3D.new()
	_marking_mat.albedo_color = Color(1.0, 1.0, 1.0, 1.0)

	_builder = MarkingsScript.new()
	_builder.init(_grid, _marking_mat)


# ================================================================
# Initialization
# ================================================================


func test_init_stores_grid() -> void:
	assert_eq(_builder._grid, _grid, "Grid should be stored after init")


func test_init_stores_marking_material() -> void:
	assert_eq(
		_builder._marking_mat,
		_marking_mat,
		"Marking material should be stored after init",
	)


# ================================================================
# Build output structure
# ================================================================


func test_build_adds_one_child_to_chunk() -> void:
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	_builder.build(chunk, 0.0, 0.0, _grid.get_grid_span())
	assert_eq(
		chunk.get_child_count(),
		1,
		"Build should add exactly one MeshInstance3D",
	)


func test_build_creates_markings_mesh_instance() -> void:
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	_builder.build(chunk, 0.0, 0.0, _grid.get_grid_span())
	var inst := chunk.get_child(0) as MeshInstance3D
	assert_not_null(inst, "Child should be a MeshInstance3D")
	assert_eq(inst.name, "Markings")


func test_markings_mesh_not_null() -> void:
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	_builder.build(chunk, 0.0, 0.0, _grid.get_grid_span())
	var inst := chunk.get_child(0) as MeshInstance3D
	assert_not_null(inst.mesh, "Markings mesh should not be null")


func test_markings_has_material_override() -> void:
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	_builder.build(chunk, 0.0, 0.0, _grid.get_grid_span())
	var inst := chunk.get_child(0) as MeshInstance3D
	assert_eq(
		inst.material_override,
		_marking_mat,
		"Markings should use marking material",
	)


func test_markings_has_extra_cull_margin() -> void:
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	_builder.build(chunk, 0.0, 0.0, _grid.get_grid_span())
	var inst := chunk.get_child(0) as MeshInstance3D
	assert_eq(
		inst.extra_cull_margin,
		10.0,
		"Markings should have extra_cull_margin of 10.0",
	)


# ================================================================
# No collision — markings are visual only
# ================================================================


func test_markings_has_no_static_body() -> void:
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	_builder.build(chunk, 0.0, 0.0, _grid.get_grid_span())
	for child in chunk.get_children():
		assert_false(
			child is StaticBody3D,
			"Markings should not have a StaticBody3D",
		)


# ================================================================
# Offset positioning
# ================================================================


func test_build_with_offset() -> void:
	var span: float = _grid.get_grid_span()
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	_builder.build(chunk, span, span, span)
	assert_eq(
		chunk.get_child_count(),
		1,
		"Build with offset should still produce one child",
	)
	var inst := chunk.get_child(0) as MeshInstance3D
	assert_not_null(inst.mesh, "Mesh should not be null with offset")


func test_build_with_negative_offset() -> void:
	var span: float = _grid.get_grid_span()
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	_builder.build(chunk, -span, -span, span)
	assert_eq(
		chunk.get_child_count(),
		1,
		"Build with negative offset should still produce one child",
	)


# ================================================================
# Determinism
# ================================================================


func test_build_is_deterministic() -> void:
	var span: float = _grid.get_grid_span()

	var chunk_a := Node3D.new()
	add_child_autofree(chunk_a)
	_builder.build(chunk_a, 0.0, 0.0, span)

	var chunk_b := Node3D.new()
	add_child_autofree(chunk_b)
	_builder.build(chunk_b, 0.0, 0.0, span)

	var mesh_a := (chunk_a.get_child(0) as MeshInstance3D).mesh
	var mesh_b := (chunk_b.get_child(0) as MeshInstance3D).mesh
	# Both should produce meshes with same surface count
	assert_eq(
		mesh_a.get_surface_count(),
		mesh_b.get_surface_count(),
		"Two builds should produce meshes with same surface count",
	)


# ================================================================
# Constants sanity
# ================================================================


func test_marking_y_above_road_surface() -> void:
	assert_gt(
		MarkingsScript.MARKING_Y,
		0.0,
		"Marking Y should be above road surface",
	)
	# Road top = Y 0.0; markings must not float visibly (>= 1 cm is too high).
	assert_lt(
		MarkingsScript.MARKING_Y,
		0.01,
		"Marking Y should be < 1 cm (just enough to avoid z-fighting)",
	)


func test_dash_length_positive() -> void:
	assert_gt(
		MarkingsScript.DASH_LENGTH,
		0.0,
		"Dash length should be positive",
	)


func test_dash_gap_positive() -> void:
	assert_gt(
		MarkingsScript.DASH_GAP,
		0.0,
		"Dash gap should be positive",
	)


func test_marking_width_positive() -> void:
	assert_gt(
		MarkingsScript.MARKING_WIDTH,
		0.0,
		"Marking width should be positive",
	)


func test_edge_line_width_less_than_marking_width() -> void:
	assert_lt(
		MarkingsScript.EDGE_LINE_WIDTH,
		MarkingsScript.MARKING_WIDTH,
		"Edge line should be thinner than center marking",
	)


func test_crossing_bar_dimensions_positive() -> void:
	assert_gt(
		MarkingsScript.CROSSING_BAR_WIDTH,
		0.0,
		"Crossing bar width should be positive",
	)
	assert_gt(
		MarkingsScript.CROSSING_BAR_LENGTH,
		0.0,
		"Crossing bar length should be positive",
	)


func test_crossing_setback_positive() -> void:
	assert_gt(
		MarkingsScript.CROSSING_SETBACK,
		0.0,
		"Crossing setback should be positive",
	)


# ================================================================
# Road marking type coverage (boulevard, alley, standard)
# ================================================================


func test_boulevard_index_matches_grid() -> void:
	assert_eq(
		_grid.BOULEVARD_INDEX,
		5,
		"Boulevard index should be 5",
	)


func test_alley_index_matches_grid() -> void:
	assert_eq(
		_grid.ALLEY_INDEX,
		2,
		"Alley index should be 2",
	)


func test_solid_line_z_skips_short_segments() -> void:
	# If z1 - z0 <= 2.0, no line should be emitted (len <= 0)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	# Call with z range too short to produce a line
	_builder._add_solid_line_z(st, 0.0, 0.0, 1.5, 0.15)
	var mesh := st.commit()
	# A mesh with 0 vertices should have 0 surfaces or empty surface
	if mesh.get_surface_count() > 0:
		var verts: int = mesh.surface_get_array_len(0)
		assert_eq(verts, 0, "Short segment should produce no vertices")
	else:
		assert_eq(
			mesh.get_surface_count(),
			0,
			"Short segment should produce no surfaces",
		)


func test_solid_line_x_skips_short_segments() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	_builder._add_solid_line_x(st, 0.0, 0.0, 1.5, 0.15)
	var mesh := st.commit()
	if mesh.get_surface_count() > 0:
		var verts: int = mesh.surface_get_array_len(0)
		assert_eq(verts, 0, "Short segment should produce no vertices")
	else:
		assert_eq(
			mesh.get_surface_count(),
			0,
			"Short segment should produce no surfaces",
		)


func test_solid_line_z_produces_vertices_for_long_segment() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	_builder._add_solid_line_z(st, 0.0, 0.0, 50.0, 0.15)
	var mesh := st.commit()
	assert_gt(
		mesh.get_surface_count(),
		0,
		"Long segment should produce at least one surface",
	)
	var verts: int = mesh.surface_get_array_len(0)
	assert_eq(verts, 6, "Solid line should produce one quad (6 vertices)")


func test_dashed_line_z_produces_vertices() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	_builder._add_dashed_line_z(st, 0.0, 0.0, 50.0, 0.15)
	var mesh := st.commit()
	assert_gt(
		mesh.get_surface_count(),
		0,
		"Dashed line should produce surfaces",
	)
	var verts: int = mesh.surface_get_array_len(0)
	# Each dash = 1 quad = 6 vertices, 50m span should fit several dashes
	assert_gt(verts, 6, "Dashed line should produce multiple dashes")


func test_dashed_line_z_no_vertices_for_short_segment() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	# z range of 3.0 with 1.0 offset leaves only 1.0m, too short for a dash
	_builder._add_dashed_line_z(st, 0.0, 0.0, 3.0, 0.15)
	var mesh := st.commit()
	if mesh.get_surface_count() > 0:
		var verts: int = mesh.surface_get_array_len(0)
		assert_eq(
			verts,
			0,
			"Very short segment should not fit any dashes",
		)
	else:
		assert_eq(
			mesh.get_surface_count(),
			0,
			"Very short segment should produce no surfaces",
		)


# ================================================================
# IMP-10 — empty mesh guard prevents adding a node
# ================================================================


func test_empty_mesh_guard_present_in_source() -> void:
	var src: String = (MarkingsScript as GDScript).source_code
	assert_true(
		src.contains("get_surface_count() == 0"),
		"Markings builder must guard against adding an empty mesh node",
	)
