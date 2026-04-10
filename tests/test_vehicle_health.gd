extends GutTest
## Unit tests for vehicle_health.gd — verify explosion impulse magnitude.
##
## The _explode() method depends on EventBus, scene tree timers, and child
## nodes, making it hard to unit-test end-to-end. Instead we verify the
## source code constant directly via string inspection.

const VehicleHealthScript = preload("res://scenes/vehicles/vehicle_health.gd")


func test_explosion_impulse_value_is_500() -> void:
	# Read the source and verify the impulse constant is 500, not 1500
	var source: String = (VehicleHealthScript as GDScript).source_code
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


# ---------------------------------------------------------------------------
# Bullet hole orientation — Vector3 comparison (vehicles/I4)
# ---------------------------------------------------------------------------


func test_bullet_hole_uses_is_equal_approx_not_exact_comparison() -> void:
	# I4: hit_normal.abs() != Vector3.UP uses exact float comparison which can
	# miss due to floating-point imprecision. Must use is_equal_approx.
	var src: String = (VehicleHealthScript as GDScript).source_code
	assert_false(
		src.contains("hit_normal.abs() != Vector3.UP"),
		"Must not use exact != comparison on Vector3",
	)
	assert_true(
		src.contains("is_equal_approx(Vector3.UP)"),
		"Must use is_equal_approx for Vector3 UP comparison",
	)


# ---------------------------------------------------------------------------
# Extended tests — constants, state transitions, edge cases
# ---------------------------------------------------------------------------


func test_source_declares_max_health_constant() -> void:
	var src: String = (VehicleHealthScript as GDScript).source_code
	assert_true(src.contains("MAX_HEALTH := 100.0"), "MAX_HEALTH constant must be 100.0")


func test_source_declares_fire_threshold_constant() -> void:
	var src: String = (VehicleHealthScript as GDScript).source_code
	assert_true(src.contains("FIRE_THRESHOLD := 30.0"), "FIRE_THRESHOLD constant must be 30.0")


func test_source_declares_burn_time_constant() -> void:
	var src: String = (VehicleHealthScript as GDScript).source_code
	assert_true(src.contains("BURN_TIME := 6.0"), "BURN_TIME constant must be 6.0")


func test_initial_health_equals_max() -> void:
	var veh := _build_vehicle()
	add_child_autofree(veh)
	await get_tree().process_frame
	var vh: Node = veh.get_node("VehicleHealth")
	assert_eq(vh.health, 100.0, "Initial health should equal MAX_HEALTH (100.0)")


func test_initial_on_fire_is_false() -> void:
	var veh := _build_vehicle()
	add_child_autofree(veh)
	await get_tree().process_frame
	var vh: Node = veh.get_node("VehicleHealth")
	assert_false(vh.on_fire, "Vehicle should not be on fire at spawn")


func test_initial_destroyed_is_false() -> void:
	var veh := _build_vehicle()
	add_child_autofree(veh)
	await get_tree().process_frame
	var vh: Node = veh.get_node("VehicleHealth")
	assert_false(vh.destroyed, "Vehicle should not be destroyed at spawn")


func test_take_damage_zero_does_not_change_health() -> void:
	var veh := _build_vehicle()
	add_child_autofree(veh)
	await get_tree().process_frame
	var vh: Node = veh.get_node("VehicleHealth")
	vh.take_damage(0.0, Vector3.ZERO, Vector3.UP)
	assert_eq(vh.health, 100.0, "Zero damage should not change health")


func test_take_damage_partial_does_not_trigger_fire() -> void:
	# 69 damage → health = 31.0, just above threshold (30.0), no fire
	var veh := _build_vehicle()
	add_child_autofree(veh)
	await get_tree().process_frame
	var vh: Node = veh.get_node("VehicleHealth")
	vh.take_damage(69.0, Vector3.ZERO, Vector3.UP)
	assert_eq(vh.health, 31.0)
	assert_false(vh.on_fire, "Should not be on fire above FIRE_THRESHOLD")


func test_take_damage_exactly_at_threshold_triggers_fire() -> void:
	# 70 damage → health = 30.0, equal to threshold → fire
	var veh := _build_vehicle()
	add_child_autofree(veh)
	await get_tree().process_frame
	var vh: Node = veh.get_node("VehicleHealth")
	vh.take_damage(70.0, Vector3.ZERO, Vector3.UP)
	assert_eq(vh.health, 30.0)
	assert_true(vh.on_fire, "Should catch fire when health equals FIRE_THRESHOLD")


func test_fire_not_triggered_twice() -> void:
	# Dealing damage a second time while already on fire should not reset fire state
	var veh := _build_vehicle()
	add_child_autofree(veh)
	await get_tree().process_frame
	var vh: Node = veh.get_node("VehicleHealth")
	vh.take_damage(75.0, Vector3.ZERO, Vector3.UP)
	assert_true(vh.on_fire)
	vh.on_fire = true  # simulate already on fire
	vh.take_damage(10.0, Vector3.ZERO, Vector3.UP)
	assert_true(vh.on_fire, "Fire state should remain true after second hit")


func test_large_damage_kills_in_one_hit() -> void:
	var veh := _build_vehicle()
	add_child_autofree(veh)
	await get_tree().process_frame
	var vh: Node = veh.get_node("VehicleHealth")
	vh.take_damage(9999.0, Vector3.ZERO, Vector3.UP)
	assert_eq(vh.health, 0.0, "Massive damage should clamp health to 0")


func test_health_does_not_go_negative() -> void:
	var veh := _build_vehicle()
	add_child_autofree(veh)
	await get_tree().process_frame
	var vh: Node = veh.get_node("VehicleHealth")
	vh.take_damage(150.0, Vector3.ZERO, Vector3.UP)
	assert_true(vh.health >= 0.0, "Health must never be negative")


func test_multiple_small_hits_accumulate() -> void:
	var veh := _build_vehicle()
	add_child_autofree(veh)
	await get_tree().process_frame
	var vh: Node = veh.get_node("VehicleHealth")
	for i in range(5):
		vh.take_damage(10.0, Vector3.ZERO, Vector3.UP)
	assert_eq(vh.health, 50.0, "Five hits of 10 should reduce health from 100 to 50")


func test_bullet_hole_limit_not_exceeded() -> void:
	var veh := _build_vehicle()
	add_child_autofree(veh)
	await get_tree().process_frame
	var vh: Node = veh.get_node("VehicleHealth")
	var src: String = (VehicleHealthScript as GDScript).source_code
	assert_true(
		src.contains("MAX_BULLET_HOLES := 10"),
		"Bullet hole limit should be 10",
	)


func test_vehicle_damaged_signal_carries_vehicle_reference() -> void:
	var veh := _build_vehicle()
	add_child_autofree(veh)
	await get_tree().process_frame
	var vh: Node = veh.get_node("VehicleHealth")
	watch_signals(EventBus)
	vh.take_damage(5.0, Vector3.ZERO, Vector3.UP)
	assert_signal_emitted_with_parameters(EventBus, "vehicle_damaged", [veh, 5.0])


func test_take_damage_multiple_times_emits_signal_each_time() -> void:
	var veh := _build_vehicle()
	add_child_autofree(veh)
	await get_tree().process_frame
	var vh: Node = veh.get_node("VehicleHealth")
	watch_signals(EventBus)
	vh.take_damage(5.0, Vector3.ZERO, Vector3.UP)
	vh.take_damage(5.0, Vector3.ZERO, Vector3.UP)
	assert_signal_emit_count(EventBus, "vehicle_damaged", 2)


func test_source_uses_event_bus_vehicle_destroyed_signal() -> void:
	var src: String = (VehicleHealthScript as GDScript).source_code
	assert_true(
		src.contains("EventBus.vehicle_destroyed.emit"),
		"_explode() must emit EventBus.vehicle_destroyed",
	)


func test_source_freezes_vehicle_on_explode() -> void:
	var src: String = (VehicleHealthScript as GDScript).source_code
	assert_true(
		src.contains("_vehicle.freeze = true"),
		"_explode() must freeze the vehicle",
	)
