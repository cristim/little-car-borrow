extends GutTest
## Source-inspection tests for scenes/player/states/driving.gd.

const DrivingScript = preload("res://scenes/player/states/driving.gd")

var _src: String


func before_all() -> void:
	_src = (DrivingScript as GDScript).source_code


# ==========================================================================
# Boat camera cleanup (M6 fix)
# ==========================================================================


func test_created_vcam_flag_declared() -> void:
	assert_true(
		_src.contains("var _created_vcam"),
		"_created_vcam member var must be declared in driving.gd",
	)


func test_created_vcam_set_true_on_create() -> void:
	assert_true(
		_src.contains("_created_vcam = true"),
		"_created_vcam must be set true when VehicleCamera is instantiated",
	)


func test_created_vcam_set_false_on_existing() -> void:
	assert_true(
		_src.contains("_created_vcam = false"),
		"_created_vcam must be reset to false in the else branch and in exit()",
	)


func test_exit_frees_created_vcam() -> void:
	assert_true(
		_src.contains("old_cam.queue_free()"),
		"exit() must call queue_free() on the camera it created",
	)


# ==========================================================================
# Boat tiller InputManager guard (L3 fix)
# ==========================================================================


func test_tiller_input_guarded_by_is_vehicle() -> void:
	assert_true(
		_src.contains("InputManager.is_vehicle()"),
		"Boat tiller input must be guarded by InputManager.is_vehicle()",
	)
