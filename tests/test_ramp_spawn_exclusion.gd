extends GutTest
## Verify that road_grid.is_on_ramp() correctly identifies ramp exclusion zones,
## and that traffic_manager.gd and police_manager.gd use the check.

const RoadGridScript = preload("res://src/road_grid.gd")

var _grid: RefCounted


func before_each() -> void:
	_grid = RoadGridScript.new()


func test_ramp0_center_is_excluded() -> void:
	assert_true(
		_grid.is_on_ramp(-2.0, -80.0),
		"Ramp 0 center should be excluded",
	)


func test_ramp1_center_is_excluded() -> void:
	assert_true(
		_grid.is_on_ramp(-2.0, 80.0),
		"Ramp 1 center should be excluded",
	)


func test_ramp2_center_is_excluded() -> void:
	assert_true(
		_grid.is_on_ramp(-60.0, 96.0),
		"Ramp 2 center should be excluded",
	)


func test_ramp3_center_is_excluded() -> void:
	assert_true(
		_grid.is_on_ramp(60.0, -100.0),
		"Ramp 3 center should be excluded",
	)


func test_road_away_from_ramp_is_not_excluded() -> void:
	assert_false(
		_grid.is_on_ramp(-240.0, 0.0),
		"Position on road 0 far from ramps should not be excluded",
	)


func test_boulevard_away_from_ramp_z_is_not_excluded() -> void:
	assert_false(
		_grid.is_on_ramp(-2.0, 0.0),
		"Boulevard at Z=0 should not be excluded (ramps are at Z=+/-80)",
	)


func test_exclusion_edge_inside() -> void:
	assert_true(
		_grid.is_on_ramp(-2.0 + 4.9, -80.0),
		"4.9m from ramp 0 X center should still be excluded",
	)


func test_exclusion_edge_outside() -> void:
	assert_false(
		_grid.is_on_ramp(-2.0 + 5.1, -80.0),
		"5.1m from ramp 0 X center should not be excluded",
	)


func test_tiling_far_chunk() -> void:
	var ox := 3.0 * 488.0
	var oz := -2.0 * 488.0
	assert_true(
		_grid.is_on_ramp(-2.0 + ox, -80.0 + oz),
		"Ramp 0 center in chunk (3,-2) should be excluded",
	)
	assert_false(
		_grid.is_on_ramp(-240.0 + ox, 0.0 + oz),
		"Road 0 in chunk (3,-2) far from ramps should not be excluded",
	)


func test_traffic_manager_calls_is_on_ramp() -> void:
	var script: GDScript = load("res://scenes/world/traffic_manager.gd")
	assert_true(
		script.source_code.contains("is_on_ramp"),
		"traffic_manager should call is_on_ramp to skip ramp positions",
	)


func test_police_manager_calls_is_on_ramp() -> void:
	var script: GDScript = load("res://scenes/world/police_manager.gd")
	assert_true(
		script.source_code.contains("is_on_ramp"),
		"police_manager should call is_on_ramp to skip ramp positions",
	)
