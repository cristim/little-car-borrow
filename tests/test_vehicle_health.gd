extends GutTest
## Unit tests for vehicle_health.gd — verify explosion impulse magnitude.
##
## The _explode() method depends on EventBus, scene tree timers, and child
## nodes, making it hard to unit-test end-to-end. Instead we verify the
## source code constant directly via string inspection.

const VehicleHealthScript = preload("res://scenes/vehicles/vehicle_health.gd")


func test_explosion_impulse_value_is_500() -> void:
	# Read the source and verify the impulse constant is 500, not 1500
	var source := VehicleHealthScript.source_code
	assert_true(
		source.contains("apply_central_impulse(Vector3(0, 500.0, 0))"),
		"Explosion impulse should be 500.0",
	)
	assert_false(
		source.contains("apply_central_impulse(Vector3(0, 1500.0, 0))"),
		"Explosion impulse should NOT be 1500.0 (old value)",
	)


# ---------------------------------------------------------------------------
# take_damage — basic behavior
# ---------------------------------------------------------------------------


func _build_vehicle() -> RigidBody3D:
	var rb := RigidBody3D.new()
	var body := Node3D.new()
	body.name = "Body"
	var car_body := MeshInstance3D.new()
	car_body.name = "CarBody"
	var mesh := BoxMesh.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color.RED
	mesh.material = mat
	car_body.mesh = mesh
	body.add_child(car_body)
	rb.add_child(body)
	var health_node: Node = VehicleHealthScript.new()
	health_node.name = "VehicleHealth"
	rb.add_child(health_node)
	return rb


func test_take_damage_reduces_health() -> void:
	var veh := _build_vehicle()
	add_child_autofree(veh)
	await get_tree().process_frame
	var vh: Node = veh.get_node("VehicleHealth")
	vh.take_damage(25.0, Vector3.ZERO, Vector3.UP)
	assert_eq(vh.health, 75.0, "Health should be reduced by damage amount")


func test_take_damage_clamps_at_zero() -> void:
	var veh := _build_vehicle()
	add_child_autofree(veh)
	await get_tree().process_frame
	var vh: Node = veh.get_node("VehicleHealth")
	vh.take_damage(200.0, Vector3.ZERO, Vector3.UP)
	assert_eq(vh.health, 0.0, "Health should not go below 0")


func test_take_damage_ignored_when_destroyed() -> void:
	var veh := _build_vehicle()
	add_child_autofree(veh)
	await get_tree().process_frame
	var vh: Node = veh.get_node("VehicleHealth")
	vh.destroyed = true
	vh.take_damage(50.0, Vector3.ZERO, Vector3.UP)
	assert_eq(vh.health, 100.0, "Damage should be ignored when destroyed")


func test_take_damage_emits_vehicle_damaged() -> void:
	var veh := _build_vehicle()
	add_child_autofree(veh)
	await get_tree().process_frame
	var vh: Node = veh.get_node("VehicleHealth")
	watch_signals(EventBus)
	vh.take_damage(10.0, Vector3.ZERO, Vector3.UP)
	assert_signal_emitted(EventBus, "vehicle_damaged")


func test_take_damage_catches_fire_below_threshold() -> void:
	var veh := _build_vehicle()
	add_child_autofree(veh)
	await get_tree().process_frame
	var vh: Node = veh.get_node("VehicleHealth")
	vh.take_damage(75.0, Vector3.ZERO, Vector3.UP)
	assert_true(vh.on_fire, "Should catch fire when health drops below threshold")


func test_take_damage_no_fire_above_threshold() -> void:
	var veh := _build_vehicle()
	add_child_autofree(veh)
	await get_tree().process_frame
	var vh: Node = veh.get_node("VehicleHealth")
	vh.take_damage(10.0, Vector3.ZERO, Vector3.UP)
	assert_false(vh.on_fire, "Should not catch fire above threshold")


func test_take_damage_spawns_bullet_hole() -> void:
	var veh := _build_vehicle()
	add_child_autofree(veh)
	await get_tree().process_frame
	var vh: Node = veh.get_node("VehicleHealth")
	var body := veh.get_node("Body")
	var before_count := body.get_child_count()
	vh.take_damage(5.0, Vector3(0, 1, 0), Vector3.UP)
	assert_gt(body.get_child_count(), before_count, "Bullet hole should be added")
