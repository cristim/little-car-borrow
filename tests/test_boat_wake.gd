extends GutTest
## Unit tests for boat_wake.gd — spray particles and foam trail.

var _script: GDScript
var _src: String


func before_all() -> void:
	_script = load("res://scenes/vehicles/boat_wake.gd")
	_src = _script.source_code


# ==========================================================================
# Constants
# ==========================================================================


func test_speed_threshold_is_2() -> void:
	assert_true(_src.contains("SPEED_THRESHOLD := 2.0"))


func test_max_spray_speed_is_15() -> void:
	assert_true(_src.contains("MAX_SPRAY_SPEED := 15.0"))


# ==========================================================================
# Initial state without RigidBody3D parent
# ==========================================================================


func test_vehicle_null_without_rigidbody_parent() -> void:
	var wake: Node3D = Node3D.new()
	wake.set_script(_script)
	add_child_autofree(wake)
	assert_null(wake._vehicle, "Should be null when parent is not RigidBody3D")


func test_no_particles_created_without_vehicle() -> void:
	var wake: Node3D = Node3D.new()
	wake.set_script(_script)
	add_child_autofree(wake)
	assert_null(wake._port_spray)
	assert_null(wake._starboard_spray)
	assert_null(wake._foam_trail)


# ==========================================================================
# Initialization with RigidBody3D parent
# ==========================================================================


func test_vehicle_set_with_rigidbody_parent() -> void:
	var body := RigidBody3D.new()
	var wake: Node3D = Node3D.new()
	wake.set_script(_script)
	body.add_child(wake)
	add_child_autofree(body)
	assert_eq(wake._vehicle, body)


func test_port_spray_created() -> void:
	var body := RigidBody3D.new()
	var wake: Node3D = Node3D.new()
	wake.set_script(_script)
	body.add_child(wake)
	add_child_autofree(body)
	assert_not_null(wake._port_spray, "Port spray should be created")
	assert_true(wake._port_spray is GPUParticles3D)


func test_starboard_spray_created() -> void:
	var body := RigidBody3D.new()
	var wake: Node3D = Node3D.new()
	wake.set_script(_script)
	body.add_child(wake)
	add_child_autofree(body)
	assert_not_null(wake._starboard_spray)
	assert_true(wake._starboard_spray is GPUParticles3D)


func test_foam_trail_created() -> void:
	var body := RigidBody3D.new()
	var wake: Node3D = Node3D.new()
	wake.set_script(_script)
	body.add_child(wake)
	add_child_autofree(body)
	assert_not_null(wake._foam_trail)
	assert_true(wake._foam_trail is GPUParticles3D)


func test_three_particle_children() -> void:
	var body := RigidBody3D.new()
	var wake: Node3D = Node3D.new()
	wake.set_script(_script)
	body.add_child(wake)
	add_child_autofree(body)
	var particle_count := 0
	for child in wake.get_children():
		if child is GPUParticles3D:
			particle_count += 1
	assert_eq(particle_count, 3, "Should have 3 particle system children")


func test_sprays_start_not_emitting() -> void:
	var body := RigidBody3D.new()
	var wake: Node3D = Node3D.new()
	wake.set_script(_script)
	body.add_child(wake)
	add_child_autofree(body)
	assert_false(wake._port_spray.emitting)
	assert_false(wake._starboard_spray.emitting)
	assert_false(wake._foam_trail.emitting)


# ==========================================================================
# Spray particle properties
# ==========================================================================


func test_spray_amount_is_20() -> void:
	var body := RigidBody3D.new()
	var wake: Node3D = Node3D.new()
	wake.set_script(_script)
	body.add_child(wake)
	add_child_autofree(body)
	assert_eq(wake._port_spray.amount, 20)
	assert_eq(wake._starboard_spray.amount, 20)


func test_spray_lifetime_is_05() -> void:
	var body := RigidBody3D.new()
	var wake: Node3D = Node3D.new()
	wake.set_script(_script)
	body.add_child(wake)
	add_child_autofree(body)
	assert_eq(wake._port_spray.lifetime, 0.5)


func test_port_spray_offset_is_left() -> void:
	var body := RigidBody3D.new()
	var wake: Node3D = Node3D.new()
	wake.set_script(_script)
	body.add_child(wake)
	add_child_autofree(body)
	assert_true(
		wake._port_spray.position.x < 0,
		"Port spray should be on the left (negative X)",
	)


func test_starboard_spray_offset_is_right() -> void:
	var body := RigidBody3D.new()
	var wake: Node3D = Node3D.new()
	wake.set_script(_script)
	body.add_child(wake)
	add_child_autofree(body)
	assert_true(
		wake._starboard_spray.position.x > 0,
		"Starboard spray should be on the right (positive X)",
	)


func test_spray_has_process_material() -> void:
	var body := RigidBody3D.new()
	var wake: Node3D = Node3D.new()
	wake.set_script(_script)
	body.add_child(wake)
	add_child_autofree(body)
	assert_not_null(wake._port_spray.process_material)
	assert_true(wake._port_spray.process_material is ParticleProcessMaterial)


func test_spray_has_sphere_mesh_draw_pass() -> void:
	var body := RigidBody3D.new()
	var wake: Node3D = Node3D.new()
	wake.set_script(_script)
	body.add_child(wake)
	add_child_autofree(body)
	assert_not_null(wake._port_spray.draw_pass_1)
	assert_true(wake._port_spray.draw_pass_1 is SphereMesh)


# ==========================================================================
# Foam trail properties
# ==========================================================================


func test_foam_amount_is_30() -> void:
	var body := RigidBody3D.new()
	var wake: Node3D = Node3D.new()
	wake.set_script(_script)
	body.add_child(wake)
	add_child_autofree(body)
	assert_eq(wake._foam_trail.amount, 30)


func test_foam_lifetime_is_15() -> void:
	var body := RigidBody3D.new()
	var wake: Node3D = Node3D.new()
	wake.set_script(_script)
	body.add_child(wake)
	add_child_autofree(body)
	assert_eq(wake._foam_trail.lifetime, 1.5)


func test_foam_uses_cylinder_mesh() -> void:
	var body := RigidBody3D.new()
	var wake: Node3D = Node3D.new()
	wake.set_script(_script)
	body.add_child(wake)
	add_child_autofree(body)
	assert_true(wake._foam_trail.draw_pass_1 is CylinderMesh)


func test_foam_disc_is_flat() -> void:
	var body := RigidBody3D.new()
	var wake: Node3D = Node3D.new()
	wake.set_script(_script)
	body.add_child(wake)
	add_child_autofree(body)
	var disc: CylinderMesh = wake._foam_trail.draw_pass_1
	assert_almost_eq(disc.height, 0.02, 0.001, "Foam disc should be very flat")


# ==========================================================================
# _process() intensity logic — source verification
# ==========================================================================


func test_intensity_uses_speed_threshold() -> void:
	assert_true(
		_src.contains("speed > SPEED_THRESHOLD"),
		"Should compare speed to SPEED_THRESHOLD",
	)


func test_foam_intensity_scaled_by_07() -> void:
	assert_true(
		_src.contains("intensity * 0.7"),
		"Foam trail intensity should be 70% of spray intensity",
	)


func test_process_guards_on_vehicle() -> void:
	assert_true(
		_src.contains("if not _vehicle"),
		"_process should return early without vehicle",
	)
