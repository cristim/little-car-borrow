extends GutTest
## Unit tests for vehicle_health.gd — verify explosion impulse magnitude.
##
## The _explode() method depends on EventBus, scene tree timers, and child
## nodes, making it hard to unit-test end-to-end. Instead we verify the
## source code constant directly via string inspection.

const VehicleHealthScript = preload(
	"res://scenes/vehicles/vehicle_health.gd"
)


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
