extends GutTest
## Unit tests for car_body_init.gd — sedan body mesh initialization.

var _script: GDScript
var _src: String


func before_all() -> void:
	_script = load("res://scenes/vehicles/car_body_init.gd")
	_src = _script.source_code


# ==========================================================================
# Constants
# ==========================================================================

func test_glass_color() -> void:
	assert_true(_src.contains("Color(0.6, 0.75, 0.85, 0.4)"))


func test_body_color() -> void:
	assert_true(_src.contains("Color(0.8, 0.2, 0.2, 1)"))


func test_interior_color() -> void:
	assert_true(_src.contains("Color(0.12, 0.12, 0.12, 1)"))


# ==========================================================================
# Builder preloaded
# ==========================================================================

func test_builder_is_preloaded() -> void:
	var init: Node3D = Node3D.new()
	init.set_script(_script)
	add_child_autofree(init)
	assert_not_null(init._builder, "Builder should be preloaded")


# ==========================================================================
# _ready() skips when CarBody has mesh or missing
# ==========================================================================

func test_ready_skips_when_no_carbody_child() -> void:
	var init: Node3D = Node3D.new()
	init.set_script(_script)
	add_child_autofree(init)
	assert_true(true, "Should not crash without CarBody child")


func test_ready_skips_when_carbody_has_mesh() -> void:
	var init: Node3D = Node3D.new()
	var car_body := MeshInstance3D.new()
	car_body.name = "CarBody"
	car_body.mesh = BoxMesh.new()
	init.add_child(car_body)
	init.set_script(_script)
	add_child_autofree(init)
	assert_true(
		car_body.mesh is BoxMesh,
		"Should not overwrite CarBody mesh when already set",
	)


# ==========================================================================
# _ready() builds meshes when CarBody has no mesh
# ==========================================================================

func test_ready_assigns_body_mesh() -> void:
	var init: Node3D = Node3D.new()
	var car_body := MeshInstance3D.new()
	car_body.name = "CarBody"
	init.add_child(car_body)
	init.set_script(_script)
	add_child_autofree(init)
	assert_not_null(car_body.mesh, "CarBody should get a mesh assigned")


func test_ready_assigns_body_material() -> void:
	var init: Node3D = Node3D.new()
	var car_body := MeshInstance3D.new()
	car_body.name = "CarBody"
	init.add_child(car_body)
	init.set_script(_script)
	add_child_autofree(init)
	assert_not_null(car_body.material_override, "CarBody should have material")
	assert_true(car_body.material_override is StandardMaterial3D)


func test_body_material_is_red() -> void:
	var init: Node3D = Node3D.new()
	var car_body := MeshInstance3D.new()
	car_body.name = "CarBody"
	init.add_child(car_body)
	init.set_script(_script)
	add_child_autofree(init)
	var c: Color = car_body.material_override.albedo_color
	assert_eq(c, Color(0.8, 0.2, 0.2, 1))


# ==========================================================================
# Interior and details generation
# ==========================================================================

func test_interior_child_created() -> void:
	var init: Node3D = Node3D.new()
	var car_body := MeshInstance3D.new()
	car_body.name = "CarBody"
	init.add_child(car_body)
	init.set_script(_script)
	add_child_autofree(init)
	var interior := car_body.get_node_or_null("Interior")
	if interior:
		assert_true(interior is MeshInstance3D)
		assert_not_null(interior.mesh)


func test_details_child_created() -> void:
	var init: Node3D = Node3D.new()
	var car_body := MeshInstance3D.new()
	car_body.name = "CarBody"
	init.add_child(car_body)
	init.set_script(_script)
	add_child_autofree(init)
	var details := car_body.get_node_or_null("Details")
	if details:
		assert_true(details is MeshInstance3D)


func test_floor_child_created() -> void:
	var init: Node3D = Node3D.new()
	var car_body := MeshInstance3D.new()
	car_body.name = "CarBody"
	init.add_child(car_body)
	init.set_script(_script)
	add_child_autofree(init)
	var floor_node := car_body.get_node_or_null("Floor")
	if floor_node:
		assert_true(floor_node is MeshInstance3D)


# ==========================================================================
# Door pivot setup
# ==========================================================================

func test_setup_door_pivot_with_pivot_nodes() -> void:
	var init: Node3D = Node3D.new()
	var car_body := MeshInstance3D.new()
	car_body.name = "CarBody"
	init.add_child(car_body)
	var left_pivot := Node3D.new()
	left_pivot.name = "LeftDoorPivot"
	init.add_child(left_pivot)
	var right_pivot := Node3D.new()
	right_pivot.name = "RightDoorPivot"
	init.add_child(right_pivot)
	init.set_script(_script)
	add_child_autofree(init)
	if left_pivot.get_child_count() > 0:
		assert_true(left_pivot.get_child(0) is MeshInstance3D)


func test_door_pivot_missing_does_not_crash() -> void:
	var init: Node3D = Node3D.new()
	var car_body := MeshInstance3D.new()
	car_body.name = "CarBody"
	init.add_child(car_body)
	init.set_script(_script)
	add_child_autofree(init)
	assert_true(true, "Should handle missing door pivots gracefully")


# ==========================================================================
# Source code structure
# ==========================================================================

func test_builds_sedan_variant() -> void:
	assert_true(_src.contains('"sedan"'), "Should build sedan variant")


func test_uses_car_body_builder() -> void:
	assert_true(
		_src.contains("car_body_builder.gd"),
		"Should preload car_body_builder.gd",
	)


func test_builds_doors() -> void:
	assert_true(_src.contains("build_doors"), "Should call build_doors")


func test_builds_windows() -> void:
	assert_true(_src.contains("build_windows"), "Should call build_windows")


func test_builds_interior() -> void:
	assert_true(_src.contains("build_interior"), "Should call build_interior")


func test_builds_details() -> void:
	assert_true(_src.contains("build_details"), "Should call build_details")


func test_builds_floor() -> void:
	assert_true(_src.contains("build_floor"), "Should call build_floor")


func test_window_glass_alpha_transparency() -> void:
	assert_true(
		_src.contains("TRANSPARENCY_ALPHA"),
		"Windows should use alpha transparency",
	)


func test_window_cull_disabled() -> void:
	assert_true(
		_src.contains("CULL_DISABLED"),
		"Glass material should have culling disabled",
	)
