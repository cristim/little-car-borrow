extends GutTest
## Unit tests for boat_body_init.gd — boat mesh initialization and materials.

var _script: GDScript
var _src: String


func before_all() -> void:
	_script = load("res://scenes/vehicles/boat_body_init.gd")
	_src = _script.source_code


# ==========================================================================
# Default state
# ==========================================================================

func test_default_variant_is_speedboat() -> void:
	var init: Node3D = Node3D.new()
	init.set_script(_script)
	add_child_autofree(init)
	assert_eq(init.variant, "speedboat")


# ==========================================================================
# Material initialization
# ==========================================================================

func test_hull_material_created_on_ready() -> void:
	var init: Node3D = Node3D.new()
	init.set_script(_script)
	add_child_autofree(init)
	assert_not_null(init._hull_mat, "Hull material should be initialized")
	assert_true(
		init._hull_mat is StandardMaterial3D,
		"Hull material should be StandardMaterial3D",
	)


func test_hull_material_color() -> void:
	var init: Node3D = Node3D.new()
	init.set_script(_script)
	add_child_autofree(init)
	var expected := Color(0.90, 0.92, 0.95)
	assert_eq(init._hull_mat.albedo_color, expected, "Hull should be off-white")


func test_hull_material_roughness() -> void:
	var init: Node3D = Node3D.new()
	init.set_script(_script)
	add_child_autofree(init)
	assert_almost_eq(init._hull_mat.roughness, 0.4, 0.01)


func test_cabin_material_created_on_ready() -> void:
	var init: Node3D = Node3D.new()
	init.set_script(_script)
	add_child_autofree(init)
	assert_not_null(init._cabin_mat, "Cabin material should be initialized")
	assert_true(
		init._cabin_mat is StandardMaterial3D,
		"Cabin material should be StandardMaterial3D",
	)


func test_cabin_material_color() -> void:
	var init: Node3D = Node3D.new()
	init.set_script(_script)
	add_child_autofree(init)
	var expected := Color(0.85, 0.87, 0.90)
	assert_eq(init._cabin_mat.albedo_color, expected)


func test_cabin_material_roughness() -> void:
	var init: Node3D = Node3D.new()
	init.set_script(_script)
	add_child_autofree(init)
	assert_eq(init._cabin_mat.roughness, 0.5)


func test_glass_material_created_on_ready() -> void:
	var init: Node3D = Node3D.new()
	init.set_script(_script)
	add_child_autofree(init)
	assert_not_null(init._glass_mat, "Glass material should be initialized")


func test_glass_material_has_alpha_transparency() -> void:
	var init: Node3D = Node3D.new()
	init.set_script(_script)
	add_child_autofree(init)
	assert_eq(
		init._glass_mat.transparency,
		BaseMaterial3D.TRANSPARENCY_ALPHA,
		"Glass should use alpha transparency",
	)


func test_glass_material_cull_disabled() -> void:
	var init: Node3D = Node3D.new()
	init.set_script(_script)
	add_child_autofree(init)
	assert_eq(
		init._glass_mat.cull_mode,
		BaseMaterial3D.CULL_DISABLED,
		"Glass should have culling disabled",
	)


func test_glass_material_color_has_alpha() -> void:
	var init: Node3D = Node3D.new()
	init.set_script(_script)
	add_child_autofree(init)
	var c: Color = init._glass_mat.albedo_color
	assert_almost_eq(c.a, 0.4, 0.02, "Glass alpha should be 0.4")


# ==========================================================================
# _ready() skips when Hull already has mesh
# ==========================================================================

func test_ready_skips_build_when_hull_has_mesh() -> void:
	var init: Node3D = Node3D.new()
	var hull := MeshInstance3D.new()
	hull.name = "Hull"
	hull.mesh = BoxMesh.new()
	init.add_child(hull)
	init.set_script(_script)
	add_child_autofree(init)
	assert_true(
		hull.mesh is BoxMesh,
		"Should not overwrite Hull mesh when already set",
	)


func test_ready_skips_when_no_hull_child() -> void:
	var init: Node3D = Node3D.new()
	init.set_script(_script)
	add_child_autofree(init)
	assert_not_null(init._hull_mat)


# ==========================================================================
# Source code structure verification
# ==========================================================================

func test_ready_calls_init_materials() -> void:
	assert_true(
		_src.contains("_init_materials()"),
		"_ready should call _init_materials",
	)


func test_preloads_boat_body_builder() -> void:
	assert_true(
		_src.contains("boat_body_builder.gd"),
		"Should preload boat_body_builder.gd",
	)


func test_assigns_cabin_and_windshield() -> void:
	assert_true(_src.contains('"Cabin"'), "Should look for Cabin child")
	assert_true(_src.contains('"Windshield"'), "Should look for Windshield child")
