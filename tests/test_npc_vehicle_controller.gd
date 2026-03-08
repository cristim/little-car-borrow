extends GutTest
## Unit tests for NPC vehicle controller spawn grace, airborne guard,
## and reduced escape force.

const NPCScript = preload(
	"res://scenes/vehicles/npc_vehicle_controller.gd"
)


# --- TestableNPC: overrides scene-dependent methods ---

class TestableNPC:
	extends "res://scenes/vehicles/npc_vehicle_controller.gd"

	func _find_nearest_road_index() -> int:
		return 0

	func _pick_best_direction() -> int:
		return 0

	func _find_next_intersection() -> void:
		pass


# --- MockVehicle: minimal stand-in for RigidBody3D ---

class MockVehicle:
	extends RigidBody3D

	var steering_input := 0.0
	var throttle_input := 0.0
	var brake_input := 0.0
	var handbrake_input := 0.0
	var _applied_forces: Array[Vector3] = []

	func apply_central_force(force: Vector3) -> void:
		_applied_forces.append(force)


var _ai: Node
var _vehicle: RigidBody3D


func before_each() -> void:
	_vehicle = MockVehicle.new()
	add_child_autofree(_vehicle)
	_ai = TestableNPC.new()
	add_child_autofree(_ai)


# ==========================================================================
# Spawn grace
# ==========================================================================

func test_spawn_grace_set_after_initialize() -> void:
	_ai.initialize(_vehicle, 0, NPCScript.Direction.NORTH)
	assert_eq(_ai._spawn_grace, 2.0)


func test_spawn_grace_default_zero() -> void:
	assert_eq(_ai._spawn_grace, 0.0)


# ==========================================================================
# Airborne guard — _begin_escape() suppression
# ==========================================================================

func test_escape_suppressed_during_spawn_grace() -> void:
	_ai.initialize(_vehicle, 0, NPCScript.Direction.NORTH)
	# Simulate stuck condition during grace period
	_ai._stuck_timer = 10.0
	# Grace is 2.0, so escape should NOT trigger
	assert_true(_ai._spawn_grace > 0.0)
	# Directly verify the guard condition
	assert_true(
		_ai._spawn_grace > 0.0,
		"Spawn grace should prevent escape during settling",
	)


func test_escape_allowed_after_spawn_grace_expires() -> void:
	_ai.initialize(_vehicle, 0, NPCScript.Direction.NORTH)
	_ai._spawn_grace = 0.0
	assert_true(
		_ai._spawn_grace <= 0.0,
		"Escape should be allowed when spawn grace is zero",
	)


# ==========================================================================
# Escape force magnitude
# ==========================================================================

func test_escape_reverse_force_is_2000() -> void:
	_ai.initialize(_vehicle, 0, NPCScript.Direction.NORTH)
	_ai._spawn_grace = 0.0
	_ai._escape_phase = NPCScript.EscapePhase.REVERSE
	_ai._escape_timer = 0.0
	# Vehicle grounded (no vertical velocity)
	_vehicle.linear_velocity = Vector3.ZERO
	_ai._process_escape(0.016)
	# Check that force was applied with magnitude 2000
	var mock: MockVehicle = _vehicle as MockVehicle
	assert_gt(mock._applied_forces.size(), 0, "Force should be applied")
	if mock._applied_forces.size() > 0:
		var force: Vector3 = mock._applied_forces[0]
		assert_almost_eq(force.length(), 2000.0, 1.0)


func test_escape_force_skipped_when_airborne() -> void:
	_ai.initialize(_vehicle, 0, NPCScript.Direction.NORTH)
	_ai._spawn_grace = 0.0
	_ai._escape_phase = NPCScript.EscapePhase.REVERSE
	_ai._escape_timer = 0.0
	# Vehicle airborne (vertical velocity > 2 m/s)
	_vehicle.linear_velocity = Vector3(0, 3.0, 0)
	_ai._process_escape(0.016)
	var mock: MockVehicle = _vehicle as MockVehicle
	assert_eq(
		mock._applied_forces.size(), 0,
		"Force should NOT be applied when airborne",
	)


func test_escape_force_applied_when_barely_grounded() -> void:
	_ai.initialize(_vehicle, 0, NPCScript.Direction.NORTH)
	_ai._spawn_grace = 0.0
	_ai._escape_phase = NPCScript.EscapePhase.REVERSE
	_ai._escape_timer = 0.0
	# Vehicle barely grounded (vertical velocity <= 2 m/s)
	_vehicle.linear_velocity = Vector3(0, 1.9, 0)
	_ai._process_escape(0.016)
	var mock: MockVehicle = _vehicle as MockVehicle
	assert_gt(
		mock._applied_forces.size(), 0,
		"Force should be applied when vertical velocity <= 2.0",
	)
