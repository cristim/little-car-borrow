extends GutTest
## Unit tests for vehicle_lights.gd — verify night mode toggling and
## time_changed signal signature.

const VehicleLightsScript = preload(
	"res://scenes/vehicles/vehicle_lights.gd"
)


func test_set_night_mode_true_shows_headlights_and_taillights() -> void:
	var lights: Node3D = VehicleLightsScript.new()
	add_child_autofree(lights)
	# After _ready, lights default to day (unless DayNightManager says night)
	# Force night mode on
	lights._set_night_mode(true)
	for hl in lights._headlights:
		assert_true(hl.visible, "Headlight should be visible at night")
	for tl in lights._taillights:
		assert_true(tl.visible, "Taillight should be visible at night")


func test_set_night_mode_false_hides_all_lights() -> void:
	var lights: Node3D = VehicleLightsScript.new()
	add_child_autofree(lights)
	# Turn on then off
	lights._set_night_mode(true)
	lights._set_night_mode(false)
	for hl in lights._headlights:
		assert_false(hl.visible, "Headlight should be hidden during day")
	for tl in lights._taillights:
		assert_false(tl.visible, "Taillight should be hidden during day")
	for rl in lights._reverse_lights:
		assert_false(rl.visible, "Reverse light should be hidden during day")


func test_on_time_changed_accepts_float_parameter() -> void:
	# Verify the _on_time_changed method signature accepts a float,
	# matching EventBus.time_of_day_changed(hour: float).
	var source := VehicleLightsScript.source_code
	assert_true(
		source.contains("func _on_time_changed(_hour: float)"),
		"_on_time_changed should accept a float parameter",
	)


func test_light_counts() -> void:
	var lights: Node3D = VehicleLightsScript.new()
	add_child_autofree(lights)
	assert_eq(
		lights._headlights.size(), 2,
		"Should have 2 headlights",
	)
	assert_eq(
		lights._taillights.size(), 2,
		"Should have 2 taillights",
	)
	assert_eq(
		lights._reverse_lights.size(), 2,
		"Should have 2 reverse lights",
	)


func test_headlights_are_spotlights() -> void:
	var lights: Node3D = VehicleLightsScript.new()
	add_child_autofree(lights)
	for hl in lights._headlights:
		assert_true(
			hl is SpotLight3D,
			"Headlights should be SpotLight3D",
		)


func test_taillights_are_omni() -> void:
	var lights: Node3D = VehicleLightsScript.new()
	add_child_autofree(lights)
	for tl in lights._taillights:
		assert_true(
			tl is OmniLight3D,
			"Taillights should be OmniLight3D",
		)


func test_no_shadows_enabled() -> void:
	var lights: Node3D = VehicleLightsScript.new()
	add_child_autofree(lights)
	for hl in lights._headlights:
		assert_false(hl.shadow_enabled, "Headlight shadows should be off")
	for tl in lights._taillights:
		assert_false(tl.shadow_enabled, "Taillight shadows should be off")
	for rl in lights._reverse_lights:
		assert_false(rl.shadow_enabled, "Reverse light shadows should be off")
