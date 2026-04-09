# gdlint:ignore = max-public-methods
extends GutTest
## Unit tests for vehicle_water_detector.gd — constants, initialization,
## sinking behavior, and bubble particle setup.

const _SCRIPT_PATH := "res://scenes/vehicles/vehicle_water_detector.gd"
const WaterScript = preload(_SCRIPT_PATH)


# Inner mock used by behavioral tests that need a node with named children.
class MockVehicle:
	extends RigidBody3D


class MockDeactivatable:
	extends Node

	var deactivated := false

	func deactivate() -> void:
		deactivated = true


class MockAudio:
	extends Node

	var stopped := false

	func stop() -> void:
		stopped = true


class MockBoundary:
	extends RefCounted

	var ground_height_return := 0.0

	func get_ground_height(_x: float, _z: float) -> float:
		return ground_height_return


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
	# When already sinking, _physics_process must not advance the timer.
	var parent := RigidBody3D.new()
	add_child_autofree(parent)
	var detector: Node = WaterScript.new()
	parent.add_child(detector)
	detector._sinking = true
	detector._timer = 0.0
	detector._physics_process(WaterScript.CHECK_INTERVAL + 0.1)
	assert_eq(detector._timer, 0.0, "Timer must not advance when already sinking")


func test_physics_process_checks_interval() -> void:
	# Timer below CHECK_INTERVAL must not trigger sinking — _sinking stays false.
	var parent := RigidBody3D.new()
	add_child_autofree(parent)
	# Put vehicle far below sea level so the check would fire if interval passed.
	parent.global_position = Vector3(0.0, WaterScript.SEA_LEVEL - 10.0, 0.0)
	var detector: Node = WaterScript.new()
	parent.add_child(detector)
	detector._timer = 0.0
	detector._physics_process(WaterScript.CHECK_INTERVAL * 0.5)
	assert_false(detector._sinking, "Should not sink before CHECK_INTERVAL elapses")


func test_physics_process_skips_non_rigidbody() -> void:
	# A non-RigidBody3D vehicle should not cause sinking regardless of position.
	var parent := Node3D.new()
	add_child_autofree(parent)
	parent.global_position = Vector3(0.0, WaterScript.SEA_LEVEL - 10.0, 0.0)
	var detector: Node = WaterScript.new()
	parent.add_child(detector)
	# Force timer past threshold so the RigidBody3D guard is the only thing
	# preventing sinking.
	detector._timer = WaterScript.CHECK_INTERVAL + 1.0
	detector._physics_process(0.0)
	assert_false(detector._sinking, "Should not sink when vehicle is not a RigidBody3D")


func test_physics_process_skips_when_above_sea_level() -> void:
	# A RigidBody3D above sea level must not trigger sinking.
	var parent := RigidBody3D.new()
	add_child_autofree(parent)
	# Place vehicle well above sea level.
	parent.global_position = Vector3(0.0, WaterScript.SEA_LEVEL + 10.0, 0.0)
	var detector: Node = WaterScript.new()
	parent.add_child(detector)
	detector._timer = WaterScript.CHECK_INTERVAL + 1.0
	detector._physics_process(0.0)
	assert_false(detector._sinking, "Should not sink when vehicle is above sea level")


func test_physics_process_checks_water_underneath() -> void:
	# Source inspection: verifies _is_over_water is called before sinking.
	# Full behavioral coverage needs a city_manager node with boundary meta,
	# which requires the physics world — kept as source inspection.
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
	# Behavioral: a child named "NPCVehicleController" with deactivate() is called.
	var parent := RigidBody3D.new()
	add_child_autofree(parent)
	var npc: Node = MockDeactivatable.new()
	npc.name = "NPCVehicleController"
	parent.add_child(npc)
	var detector: Node = WaterScript.new()
	parent.add_child(detector)
	detector._start_sinking()
	assert_true(
		(npc as MockDeactivatable).deactivated,
		"_start_sinking should call deactivate() on NPCVehicleController",
	)


func test_start_sinking_deactivates_police_controller() -> void:
	# Behavioral: correct node name is PoliceAIController (not PoliceVehicleController).
	var parent := RigidBody3D.new()
	add_child_autofree(parent)
	var police: Node = MockDeactivatable.new()
	police.name = "PoliceAIController"
	parent.add_child(police)
	var detector: Node = WaterScript.new()
	parent.add_child(detector)
	detector._start_sinking()
	assert_true(
		(police as MockDeactivatable).deactivated,
		"_start_sinking should call deactivate() on PoliceAIController",
	)
	# Source guard: wrong name must not appear in production code.
	var src: String = (load(_SCRIPT_PATH) as GDScript).source_code
	assert_false(
		src.contains('"PoliceVehicleController"'),
		"PoliceVehicleController is the wrong node name — should not appear in source",
	)


func test_start_sinking_stops_engine_audio() -> void:
	# Behavioral: a child named "EngineAudio" has stop() called on it.
	var parent := RigidBody3D.new()
	add_child_autofree(parent)
	var audio: Node = MockAudio.new()
	audio.name = "EngineAudio"
	parent.add_child(audio)
	var detector: Node = WaterScript.new()
	parent.add_child(detector)
	detector._start_sinking()
	assert_true(
		(audio as MockAudio).stopped,
		"_start_sinking should call stop() on EngineAudio",
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
# _is_over_water — behavior and source verification
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


func test_is_over_water_guards_with_has_meta() -> void:
	# I1: must call has_meta before get_meta to avoid crash when city not ready
	var src: String = (load(_SCRIPT_PATH) as GDScript).source_code
	assert_true(
		src.contains('has_meta("city_boundary")'),
		"_is_over_water should guard with has_meta before get_meta",
	)


func test_is_over_water_returns_false_without_city_manager() -> void:
	# _is_over_water with no city_manager group returns false (safe default)
	var detector: Node = WaterScript.new()
	add_child_autofree(detector)
	detector._vehicle = RigidBody3D.new()
	# city_manager group is empty in test — should return false
	var result: bool = detector._is_over_water(Vector3.ZERO)
	assert_false(result, "_is_over_water should return false when no city_manager in scene")


func test_is_over_water_true_when_ground_below_sea_level() -> void:
	# Behavioral: inject a cached boundary whose ground height is below SEA_LEVEL.
	var detector: Node = WaterScript.new()
	add_child_autofree(detector)
	detector._vehicle = RigidBody3D.new()
	var boundary: MockBoundary = MockBoundary.new()
	boundary.ground_height_return = WaterScript.SEA_LEVEL - 1.0
	detector._boundary = boundary
	var result: bool = detector._is_over_water(Vector3.ZERO)
	assert_true(result, "_is_over_water should return true when ground is below SEA_LEVEL")


func test_is_over_water_false_when_ground_at_sea_level() -> void:
	# Behavioral: ground height exactly at SEA_LEVEL — not over water.
	var detector: Node = WaterScript.new()
	add_child_autofree(detector)
	detector._vehicle = RigidBody3D.new()
	var boundary: MockBoundary = MockBoundary.new()
	boundary.ground_height_return = WaterScript.SEA_LEVEL
	detector._boundary = boundary
	var result: bool = detector._is_over_water(Vector3.ZERO)
	assert_false(result, "_is_over_water should return false when ground equals SEA_LEVEL")


func test_is_over_water_false_when_ground_above_sea_level() -> void:
	# Behavioral: ground height above SEA_LEVEL — solid land, not water.
	var detector: Node = WaterScript.new()
	add_child_autofree(detector)
	detector._vehicle = RigidBody3D.new()
	var boundary: MockBoundary = MockBoundary.new()
	boundary.ground_height_return = WaterScript.SEA_LEVEL + 5.0
	detector._boundary = boundary
	var result: bool = detector._is_over_water(Vector3.ZERO)
	assert_false(result, "_is_over_water should return false when ground is above SEA_LEVEL")


# ==========================================================================
# Vehicle lights are disabled on water entry
# ==========================================================================


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
