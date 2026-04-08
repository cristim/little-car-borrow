# gdlint:ignore = max-public-methods
extends GutTest
## Unit tests for vehicle_water_detector.gd — constants, initialization,
## sinking behavior, and bubble particle setup.

const _SCRIPT_PATH := "res://scenes/vehicles/vehicle_water_detector.gd"
const WaterScript = preload(_SCRIPT_PATH)

# ==========================================================================
# Constants
# ==========================================================================


func test_sea_level_constant() -> void:
	assert_eq(WaterScript.SEA_LEVEL, -2.0)


func test_check_interval_constant() -> void:
	assert_eq(WaterScript.CHECK_INTERVAL, 0.1)


func test_sink_linear_damp_constant() -> void:
	assert_eq(WaterScript.SINK_LINEAR_DAMP, 2.0)


func test_sink_angular_damp_constant() -> void:
	assert_eq(WaterScript.SINK_ANGULAR_DAMP, 3.0)


func test_angular_damp_greater_than_linear() -> void:
	assert_true(
		WaterScript.SINK_ANGULAR_DAMP > WaterScript.SINK_LINEAR_DAMP,
		"Angular damp should be higher to stabilize sinking vehicle rotation",
	)


# ==========================================================================
# Default state
# ==========================================================================


func test_default_timer_zero() -> void:
	var detector: Node = WaterScript.new()
	add_child_autofree(detector)
	assert_eq(detector._timer, 0.0)


func test_default_sinking_false() -> void:
	var detector: Node = WaterScript.new()
	add_child_autofree(detector)
	assert_false(detector._sinking)


# ==========================================================================
# _ready — vehicle reference and boat check
# ==========================================================================


func test_ready_gets_parent_as_vehicle() -> void:
	var parent := Node3D.new()
	add_child_autofree(parent)
	var detector: Node = WaterScript.new()
	parent.add_child(detector)
	assert_eq(detector._vehicle, parent)


func test_ready_disables_for_boats() -> void:
	var parent := Node3D.new()
	add_child_autofree(parent)
	# Add a BoatController child to simulate a boat
	var boat_ctrl := Node.new()
	boat_ctrl.name = "BoatController"
	parent.add_child(boat_ctrl)
	var detector: Node = WaterScript.new()
	parent.add_child(detector)
	assert_false(
		detector.is_physics_processing(),
		"Should disable physics processing for boats",
	)


func test_ready_enabled_for_non_boats() -> void:
	var parent := Node3D.new()
	add_child_autofree(parent)
	var detector: Node = WaterScript.new()
	parent.add_child(detector)
	assert_true(
		detector.is_physics_processing(),
		"Should keep physics processing for non-boats",
	)


# ==========================================================================
# _physics_process guards
# ==========================================================================


func test_physics_process_skips_when_sinking() -> void:
	var src: String = (load(_SCRIPT_PATH) as GDScript).source_code
	assert_true(
		src.contains("if _sinking or not _vehicle"),
		"Should early-return when already sinking or no vehicle",
	)


func test_physics_process_checks_interval() -> void:
	var src: String = (load(_SCRIPT_PATH) as GDScript).source_code
	assert_true(
		src.contains("_timer < CHECK_INTERVAL"),
		"Should throttle checks by CHECK_INTERVAL",
	)


func test_physics_process_checks_rigidbody() -> void:
	var src: String = (load(_SCRIPT_PATH) as GDScript).source_code
	assert_true(
		src.contains("not _vehicle is RigidBody3D"),
		"Should only process RigidBody3D vehicles",
	)


func test_physics_process_checks_sea_level() -> void:
	var src: String = (load(_SCRIPT_PATH) as GDScript).source_code
	assert_true(
		src.contains("_vehicle.global_position.y > SEA_LEVEL"),
		"Should skip if vehicle is above sea level",
	)


func test_physics_process_checks_water_underneath() -> void:
	var src: String = (load(_SCRIPT_PATH) as GDScript).source_code
	assert_true(
		src.contains("_is_over_water"),
		"Should verify water underneath before sinking",
	)


# ==========================================================================
# _start_sinking — behavior
# ==========================================================================


func test_start_sinking_sets_flag() -> void:
	var parent := RigidBody3D.new()
	add_child_autofree(parent)
	var detector: Node = WaterScript.new()
	parent.add_child(detector)
	detector._start_sinking()
	assert_true(detector._sinking)


func test_start_sinking_applies_linear_damp() -> void:
	var parent := RigidBody3D.new()
	add_child_autofree(parent)
	var detector: Node = WaterScript.new()
	parent.add_child(detector)
	detector._start_sinking()
	assert_eq(parent.linear_damp, WaterScript.SINK_LINEAR_DAMP)


func test_start_sinking_applies_angular_damp() -> void:
	var parent := RigidBody3D.new()
	add_child_autofree(parent)
	var detector: Node = WaterScript.new()
	parent.add_child(detector)
	detector._start_sinking()
	assert_eq(parent.angular_damp, WaterScript.SINK_ANGULAR_DAMP)


func test_start_sinking_emits_force_exit_vehicle() -> void:
	var src: String = (load(_SCRIPT_PATH) as GDScript).source_code
	assert_true(
		src.contains("EventBus.force_exit_vehicle.emit(_vehicle)"),
		"Should emit force_exit_vehicle signal",
	)


func test_start_sinking_emits_vehicle_entered_water() -> void:
	var src: String = (load(_SCRIPT_PATH) as GDScript).source_code
	assert_true(
		src.contains("EventBus.vehicle_entered_water.emit(_vehicle)"),
		"Should emit vehicle_entered_water signal",
	)


func test_start_sinking_deactivates_npc_controller() -> void:
	var src: String = (load(_SCRIPT_PATH) as GDScript).source_code
	assert_true(
		src.contains('"NPCVehicleController"'),
		"Should look for NPCVehicleController to deactivate",
	)


func test_start_sinking_deactivates_police_controller() -> void:
	# C1: correct node name is PoliceAIController (was PoliceVehicleController)
	var src: String = (load(_SCRIPT_PATH) as GDScript).source_code
	assert_true(
		src.contains('"PoliceAIController"'),
		"Should look for PoliceAIController to deactivate (not PoliceVehicleController)",
	)
	assert_false(
		src.contains('"PoliceVehicleController"'),
		"PoliceVehicleController is the wrong node name — should not appear in source",
	)


func test_start_sinking_stops_engine_audio() -> void:
	var src: String = (load(_SCRIPT_PATH) as GDScript).source_code
	assert_true(
		src.contains('"EngineAudio"'),
		"Should look for EngineAudio to stop",
	)


func test_start_sinking_spawns_bubbles() -> void:
	var parent := RigidBody3D.new()
	add_child_autofree(parent)
	var detector: Node = WaterScript.new()
	parent.add_child(detector)
	detector._start_sinking()
	var bubbles := parent.get_node_or_null("SinkBubbles")
	assert_not_null(bubbles, "Should spawn SinkBubbles particle node")


# ==========================================================================
# _spawn_bubbles — particle setup
# ==========================================================================


func test_bubbles_are_gpu_particles() -> void:
	var parent := RigidBody3D.new()
	add_child_autofree(parent)
	var detector: Node = WaterScript.new()
	parent.add_child(detector)
	detector._spawn_bubbles()
	var bubbles := parent.get_node_or_null("SinkBubbles")
	assert_true(bubbles is GPUParticles3D)


func test_bubbles_amount() -> void:
	var parent := RigidBody3D.new()
	add_child_autofree(parent)
	var detector: Node = WaterScript.new()
	parent.add_child(detector)
	detector._spawn_bubbles()
	var bubbles := parent.get_node("SinkBubbles") as GPUParticles3D
	assert_eq(bubbles.amount, 30)


func test_bubbles_lifetime() -> void:
	var parent := RigidBody3D.new()
	add_child_autofree(parent)
	var detector: Node = WaterScript.new()
	parent.add_child(detector)
	detector._spawn_bubbles()
	var bubbles := parent.get_node("SinkBubbles") as GPUParticles3D
	assert_eq(bubbles.lifetime, 2.0)


func test_bubbles_emitting() -> void:
	var parent := RigidBody3D.new()
	add_child_autofree(parent)
	var detector: Node = WaterScript.new()
	parent.add_child(detector)
	detector._spawn_bubbles()
	var bubbles := parent.get_node("SinkBubbles") as GPUParticles3D
	assert_true(bubbles.emitting)


func test_bubbles_not_one_shot() -> void:
	var parent := RigidBody3D.new()
	add_child_autofree(parent)
	var detector: Node = WaterScript.new()
	parent.add_child(detector)
	detector._spawn_bubbles()
	var bubbles := parent.get_node("SinkBubbles") as GPUParticles3D
	assert_false(bubbles.one_shot)


func test_bubbles_have_process_material() -> void:
	var parent := RigidBody3D.new()
	add_child_autofree(parent)
	var detector: Node = WaterScript.new()
	parent.add_child(detector)
	detector._spawn_bubbles()
	var bubbles := parent.get_node("SinkBubbles") as GPUParticles3D
	assert_true(
		bubbles.process_material is ParticleProcessMaterial,
		"Should have ParticleProcessMaterial",
	)


func test_bubbles_direction_upward() -> void:
	var parent := RigidBody3D.new()
	add_child_autofree(parent)
	var detector: Node = WaterScript.new()
	parent.add_child(detector)
	detector._spawn_bubbles()
	var bubbles := parent.get_node("SinkBubbles") as GPUParticles3D
	var mat := bubbles.process_material as ParticleProcessMaterial
	assert_eq(mat.direction, Vector3(0, 1, 0))


func test_bubbles_zero_gravity() -> void:
	var parent := RigidBody3D.new()
	add_child_autofree(parent)
	var detector: Node = WaterScript.new()
	parent.add_child(detector)
	detector._spawn_bubbles()
	var bubbles := parent.get_node("SinkBubbles") as GPUParticles3D
	var mat := bubbles.process_material as ParticleProcessMaterial
	assert_eq(mat.gravity, Vector3(0, 0, 0))


func test_bubbles_have_draw_pass() -> void:
	var parent := RigidBody3D.new()
	add_child_autofree(parent)
	var detector: Node = WaterScript.new()
	parent.add_child(detector)
	detector._spawn_bubbles()
	var bubbles := parent.get_node("SinkBubbles") as GPUParticles3D
	assert_not_null(bubbles.draw_pass_1, "Should have a draw pass mesh")


func test_bubbles_draw_pass_is_sphere() -> void:
	var parent := RigidBody3D.new()
	add_child_autofree(parent)
	var detector: Node = WaterScript.new()
	parent.add_child(detector)
	detector._spawn_bubbles()
	var bubbles := parent.get_node("SinkBubbles") as GPUParticles3D
	assert_true(
		bubbles.draw_pass_1 is SphereMesh,
		"Draw pass should be SphereMesh",
	)


func test_bubbles_position_offset() -> void:
	var parent := RigidBody3D.new()
	add_child_autofree(parent)
	var detector: Node = WaterScript.new()
	parent.add_child(detector)
	detector._spawn_bubbles()
	var bubbles := parent.get_node("SinkBubbles") as GPUParticles3D
	assert_eq(bubbles.position, Vector3(0, 0.5, 0))


# ==========================================================================
# _is_over_water — source verification
# ==========================================================================


func test_is_over_water_checks_city_manager_group() -> void:
	var src: String = (load(_SCRIPT_PATH) as GDScript).source_code
	assert_true(
		src.contains('get_nodes_in_group("city_manager")'),
		"Should query city_manager group for boundary",
	)


func test_is_over_water_checks_city_boundary_meta() -> void:
	var src: String = (load(_SCRIPT_PATH) as GDScript).source_code
	assert_true(
		src.contains('get_meta("city_boundary")'),
		"Should get city_boundary from meta",
	)


func test_is_over_water_compares_ground_height() -> void:
	var src: String = (load(_SCRIPT_PATH) as GDScript).source_code
	assert_true(
		src.contains("ground_h < SEA_LEVEL"),
		"Should compare ground height against SEA_LEVEL",
	)


# ==========================================================================
# Vehicle lights are disabled on water entry
# ==========================================================================


func test_start_sinking_looks_for_vehicle_lights() -> void:
	var src: String = (load(_SCRIPT_PATH) as GDScript).source_code
	assert_true(
		src.contains('"Body/VehicleLights"'),
		"_start_sinking should look for Body/VehicleLights node",
	)


func test_start_sinking_calls_disable_on_lights() -> void:
	var src: String = (load(_SCRIPT_PATH) as GDScript).source_code
	assert_true(
		src.contains("lights.disable()"),
		"_start_sinking should call disable() on VehicleLights",
	)


func test_start_sinking_disables_vehicle_lights() -> void:
	var LightsScript: GDScript = preload("res://scenes/vehicles/vehicle_lights.gd")
	var parent := RigidBody3D.new()
	add_child_autofree(parent)

	var body := Node3D.new()
	body.name = "Body"
	parent.add_child(body)

	var lights: Node3D = LightsScript.new()
	lights.name = "VehicleLights"
	body.add_child(lights)
	lights.initialize(parent)
	lights._set_night_mode(true)

	var detector: Node = WaterScript.new()
	parent.add_child(detector)
	detector._start_sinking()

	assert_false(
		lights.is_physics_processing(),
		"VehicleLights should have physics processing disabled after sinking",
	)
