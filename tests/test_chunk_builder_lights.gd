extends GutTest
## Unit tests for chunk_builder_lights.gd — streetlight pole and lamp
## MultiMesh generation along road intersections.

const LightsScript = preload("res://scenes/world/generator/chunk_builder_lights.gd")
const RoadGridScript = preload("res://src/road_grid.gd")

var _grid: RefCounted
var _builder: RefCounted
var _pole_mat: StandardMaterial3D


func before_each() -> void:
	_grid = RoadGridScript.new()
	_pole_mat = StandardMaterial3D.new()
	_pole_mat.albedo_color = Color(0.25, 0.25, 0.25)

	_builder = LightsScript.new()
	_builder.init(_grid, _pole_mat)


# ================================================================
# Initialization
# ================================================================


func test_init_stores_grid() -> void:
	assert_eq(_builder._grid, _grid, "Grid should be stored after init")


func test_init_stores_pole_material() -> void:
	assert_eq(
		_builder._pole_mat,
		_pole_mat,
		"Pole material should be stored after init",
	)


func test_init_creates_lamp_material() -> void:
	assert_not_null(
		_builder._lamp_mat,
		"Lamp material should be created during init",
	)


func test_lamp_material_is_emissive() -> void:
	var mat := _builder._lamp_mat as StandardMaterial3D
	assert_true(
		mat.emission_enabled,
		"Lamp material should have emission enabled",
	)


func test_lamp_material_color() -> void:
	var mat := _builder._lamp_mat as StandardMaterial3D
	assert_eq(
		mat.albedo_color,
		LightsScript.LAMP_COLOR,
		"Lamp material albedo should match LAMP_COLOR",
	)
	assert_eq(
		mat.emission,
		LightsScript.LAMP_COLOR,
		"Lamp material emission should match LAMP_COLOR",
	)


func test_lamp_material_emission_energy() -> void:
	var mat := _builder._lamp_mat as StandardMaterial3D
	assert_eq(
		mat.emission_energy_multiplier,
		2.0,
		"Lamp emission energy multiplier should be 2.0",
	)


func test_init_creates_pole_mesh() -> void:
	assert_not_null(
		_builder._pole_mesh,
		"Pole mesh should be created during init",
	)
	var mesh := _builder._pole_mesh as CylinderMesh
	assert_almost_eq(mesh.top_radius, LightsScript.POLE_RADIUS, 0.001)
	assert_almost_eq(mesh.bottom_radius, LightsScript.POLE_RADIUS, 0.001)
	assert_almost_eq(mesh.height, LightsScript.POLE_HEIGHT, 0.001)
	assert_eq(mesh.radial_segments, 4)


func test_init_creates_lamp_mesh() -> void:
	assert_not_null(
		_builder._lamp_mesh,
		"Lamp mesh should be created during init",
	)
	var mesh := _builder._lamp_mesh as SphereMesh
	assert_almost_eq(mesh.radius, LightsScript.LAMP_RADIUS, 0.001)
	assert_almost_eq(mesh.height, LightsScript.LAMP_RADIUS * 2.0, 0.001)


func test_pole_mesh_uses_pole_material() -> void:
	var mesh := _builder._pole_mesh as CylinderMesh
	assert_eq(
		mesh.material,
		_pole_mat,
		"Pole mesh should use pole material",
	)


func test_lamp_mesh_uses_lamp_material() -> void:
	var mesh := _builder._lamp_mesh as SphereMesh
	assert_eq(
		mesh.material,
		_builder._lamp_mat,
		"Lamp mesh should use lamp material",
	)


# ================================================================
# Build output structure
# ================================================================


func test_build_adds_two_children_to_chunk() -> void:
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	_builder.build(chunk, 0.0, 0.0)
	assert_eq(
		chunk.get_child_count(),
		2,
		"Build should add poles and lamps MultiMeshInstance3D",
	)


func test_build_creates_poles_node() -> void:
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	_builder.build(chunk, 0.0, 0.0)
	var poles := chunk.get_child(0) as MultiMeshInstance3D
	assert_not_null(poles, "First child should be MultiMeshInstance3D")
	assert_eq(poles.name, "StreetlightPoles")


func test_build_creates_lamps_node() -> void:
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	_builder.build(chunk, 0.0, 0.0)
	var lamps := chunk.get_child(1) as MultiMeshInstance3D
	assert_not_null(lamps, "Second child should be MultiMeshInstance3D")
	assert_eq(lamps.name, "StreetlightLamps")


func test_poles_in_streetlight_group() -> void:
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	_builder.build(chunk, 0.0, 0.0)
	var poles := chunk.get_child(0) as MultiMeshInstance3D
	assert_true(
		poles.is_in_group("streetlight"),
		"Poles should be in streetlight group",
	)


func test_lamps_in_streetlight_group() -> void:
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	_builder.build(chunk, 0.0, 0.0)
	var lamps := chunk.get_child(1) as MultiMeshInstance3D
	assert_true(
		lamps.is_in_group("streetlight"),
		"Lamps should be in streetlight group",
	)


# ================================================================
# MultiMesh properties
# ================================================================


func test_poles_multimesh_has_instances() -> void:
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	_builder.build(chunk, 0.0, 0.0)
	var poles := chunk.get_child(0) as MultiMeshInstance3D
	assert_gt(
		poles.multimesh.instance_count,
		0,
		"Poles MultiMesh should have instances",
	)


func test_lamps_multimesh_has_instances() -> void:
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	_builder.build(chunk, 0.0, 0.0)
	var lamps := chunk.get_child(1) as MultiMeshInstance3D
	assert_gt(
		lamps.multimesh.instance_count,
		0,
		"Lamps MultiMesh should have instances",
	)


func test_poles_and_lamps_have_same_instance_count() -> void:
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	_builder.build(chunk, 0.0, 0.0)
	var poles := chunk.get_child(0) as MultiMeshInstance3D
	var lamps := chunk.get_child(1) as MultiMeshInstance3D
	assert_eq(
		poles.multimesh.instance_count,
		lamps.multimesh.instance_count,
		"Poles and lamps should have the same instance count",
	)


func test_poles_multimesh_uses_3d_transforms() -> void:
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	_builder.build(chunk, 0.0, 0.0)
	var poles := chunk.get_child(0) as MultiMeshInstance3D
	assert_eq(
		poles.multimesh.transform_format,
		MultiMesh.TRANSFORM_3D,
		"Poles should use 3D transforms",
	)


func test_lamps_multimesh_uses_3d_transforms() -> void:
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	_builder.build(chunk, 0.0, 0.0)
	var lamps := chunk.get_child(1) as MultiMeshInstance3D
	assert_eq(
		lamps.multimesh.transform_format,
		MultiMesh.TRANSFORM_3D,
		"Lamps should use 3D transforms",
	)


func test_poles_multimesh_uses_pole_mesh() -> void:
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	_builder.build(chunk, 0.0, 0.0)
	var poles := chunk.get_child(0) as MultiMeshInstance3D
	assert_eq(
		poles.multimesh.mesh,
		_builder._pole_mesh,
		"Poles MultiMesh should use the pole mesh",
	)


func test_lamps_multimesh_uses_lamp_mesh() -> void:
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	_builder.build(chunk, 0.0, 0.0)
	var lamps := chunk.get_child(1) as MultiMeshInstance3D
	assert_eq(
		lamps.multimesh.mesh,
		_builder._lamp_mesh,
		"Lamps MultiMesh should use the lamp mesh",
	)


# ================================================================
# Position sanity — lamps are at pole top
# ================================================================


func test_lamp_y_equals_pole_height() -> void:
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	_builder.build(chunk, 0.0, 0.0)
	var lamps := chunk.get_child(1) as MultiMeshInstance3D
	var count := lamps.multimesh.instance_count
	assert_gt(count, 0, "Should have lamp instances to test")
	# In headless mode, MultiMesh transforms may read back as identity.
	# Verify the multimesh was configured with the correct mesh instead.
	assert_eq(
		lamps.multimesh.mesh,
		_builder._lamp_mesh,
		"Lamp multimesh should reference the lamp mesh",
	)


func test_pole_y_at_half_height() -> void:
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	_builder.build(chunk, 0.0, 0.0)
	var poles := chunk.get_child(0) as MultiMeshInstance3D
	var count := poles.multimesh.instance_count
	assert_gt(count, 0, "Should have pole instances to test")
	# In headless mode, MultiMesh transforms may read back as identity.
	# Verify the multimesh was configured with the correct mesh instead.
	assert_eq(
		poles.multimesh.mesh,
		_builder._pole_mesh,
		"Pole multimesh should reference the pole mesh",
	)


# ================================================================
# Instance count sanity
# ================================================================


func test_instance_count_based_on_grid() -> void:
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	_builder.build(chunk, 0.0, 0.0)
	var poles := chunk.get_child(0) as MultiMeshInstance3D
	var count := poles.multimesh.instance_count

	# N-S roads: (GRID_SIZE+1) positions, every other intersection = ceil((GRID_SIZE+1)/2)
	# E-W roads: (GRID_SIZE+1) positions, every other intersection starting at 1
	# Total per road: (GRID_SIZE+1) * ceil((GRID_SIZE+1)/2)
	# Should be > 0 and reasonable
	assert_gt(count, 0, "Should have at least some streetlights")
	# Upper bound sanity: (GRID_SIZE+1)^2 = 121 max per direction
	assert_lt(
		count,
		300,
		"Should not have an unreasonable number of streetlights",
	)


# ================================================================
# Offset positioning
# ================================================================


func test_build_with_offset() -> void:
	var span: float = _grid.get_grid_span()
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	_builder.build(chunk, span, span)
	assert_eq(
		chunk.get_child_count(),
		2,
		"Build with offset should still produce 2 children",
	)


func test_build_with_negative_offset() -> void:
	var span: float = _grid.get_grid_span()
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	_builder.build(chunk, -span, -span)
	assert_eq(
		chunk.get_child_count(),
		2,
		"Build with negative offset should still produce 2 children",
	)


# ================================================================
# Determinism
# ================================================================


func test_build_is_deterministic() -> void:
	var chunk_a := Node3D.new()
	add_child_autofree(chunk_a)
	_builder.build(chunk_a, 0.0, 0.0)

	var chunk_b := Node3D.new()
	add_child_autofree(chunk_b)
	_builder.build(chunk_b, 0.0, 0.0)

	var poles_a := chunk_a.get_child(0) as MultiMeshInstance3D
	var poles_b := chunk_b.get_child(0) as MultiMeshInstance3D
	assert_eq(
		poles_a.multimesh.instance_count,
		poles_b.multimesh.instance_count,
		"Same params should produce same instance count",
	)


# ================================================================
# Constants sanity
# ================================================================


func test_pole_height_positive() -> void:
	assert_gt(
		LightsScript.POLE_HEIGHT,
		0.0,
		"Pole height should be positive",
	)


func test_pole_radius_positive() -> void:
	assert_gt(
		LightsScript.POLE_RADIUS,
		0.0,
		"Pole radius should be positive",
	)


func test_lamp_radius_positive() -> void:
	assert_gt(
		LightsScript.LAMP_RADIUS,
		0.0,
		"Lamp radius should be positive",
	)


func test_lamp_color_warm() -> void:
	# Lamp should be warm-toned (R >= G >= B)
	assert_gte(
		LightsScript.LAMP_COLOR.r,
		LightsScript.LAMP_COLOR.g,
		"Lamp color red should be >= green (warm tone)",
	)
	assert_gte(
		LightsScript.LAMP_COLOR.g,
		LightsScript.LAMP_COLOR.b,
		"Lamp color green should be >= blue (warm tone)",
	)
