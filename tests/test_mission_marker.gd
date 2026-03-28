extends GutTest
## Unit tests for scenes/missions/mission_marker.gd
## Tests Area3D setup, signal connections, collision detection, pulse animation,
## and marker color setting.

const MarkerScene = preload("res://scenes/missions/mission_marker.tscn")
const MarkerScript = preload("res://scenes/missions/mission_marker.gd")


var _marker: Node3D


func before_each() -> void:
	_marker = MarkerScene.instantiate()
	add_child_autofree(_marker)


# ================================================================
# Initial state and defaults
# ================================================================

func test_default_mission_id_empty() -> void:
	assert_eq(_marker.mission_id, "", "Default mission_id should be empty")


func test_default_marker_type_start() -> void:
	assert_eq(
		_marker.marker_type, "start",
		"Default marker_type should be 'start'",
	)


func test_added_to_mission_marker_group() -> void:
	assert_true(
		_marker.is_in_group("mission_marker"),
		"Marker should be in 'mission_marker' group after _ready",
	)


# ================================================================
# Scene structure
# ================================================================

func test_has_column_child() -> void:
	var col := _marker.get_node_or_null("Column")
	assert_not_null(col, "Marker should have a Column child")
	assert_true(col is MeshInstance3D, "Column should be MeshInstance3D")


func test_has_trigger_child() -> void:
	var trigger := _marker.get_node_or_null("Trigger")
	assert_not_null(trigger, "Marker should have a Trigger child")
	assert_true(trigger is Area3D, "Trigger should be Area3D")


func test_has_light_child() -> void:
	var light := _marker.get_node_or_null("Light")
	assert_not_null(light, "Marker should have a Light child")
	assert_true(light is OmniLight3D, "Light should be OmniLight3D")


func test_trigger_has_collision_shape() -> void:
	var trigger := _marker.get_node_or_null("Trigger") as Area3D
	assert_not_null(trigger, "Trigger should exist")
	var shape := trigger.get_node_or_null("Shape")
	assert_not_null(shape, "Trigger should have a Shape child")
	assert_true(
		shape is CollisionShape3D,
		"Shape should be CollisionShape3D",
	)


# ================================================================
# Trigger collision layers
# ================================================================

func test_trigger_collision_layer() -> void:
	var trigger := _marker.get_node_or_null("Trigger") as Area3D
	assert_not_null(trigger)
	# Layer 9 = 256
	assert_eq(
		trigger.collision_layer, 256,
		"Trigger collision_layer should be 256 (layer 9)",
	)


func test_trigger_collision_mask_detects_player_and_vehicle() -> void:
	var trigger := _marker.get_node_or_null("Trigger") as Area3D
	assert_not_null(trigger)
	# Mask 12 = layer 3 (4=player) + layer 4 (8=player vehicle)
	assert_eq(
		trigger.collision_mask, 12,
		"Trigger collision_mask should be 12 (player + player vehicle)",
	)


# ================================================================
# Signal connection
# ================================================================

func test_body_entered_signal_connected() -> void:
	var trigger := _marker.get_node_or_null("Trigger") as Area3D
	assert_not_null(trigger)
	assert_true(
		trigger.body_entered.is_connected(_marker._on_body_entered),
		"body_entered should be connected to _on_body_entered",
	)


# ================================================================
# set_marker_color
# ================================================================

func test_set_marker_color_changes_column_material() -> void:
	var test_color := Color(1.0, 0.0, 0.0)
	_marker.set_marker_color(test_color)

	var col := _marker.get_node("Column") as MeshInstance3D
	var mat := col.material_override as StandardMaterial3D
	assert_not_null(mat, "Column should have material_override")
	assert_eq(
		mat.albedo_color, test_color,
		"Albedo color should match set color",
	)


func test_set_marker_color_enables_emission() -> void:
	var test_color := Color(0.5, 0.5, 1.0)
	_marker.set_marker_color(test_color)

	var col := _marker.get_node("Column") as MeshInstance3D
	var mat := col.material_override as StandardMaterial3D
	assert_true(
		mat.emission_enabled,
		"Emission should be enabled",
	)
	assert_eq(
		mat.emission, test_color,
		"Emission color should match set color",
	)


func test_set_marker_color_emission_energy() -> void:
	_marker.set_marker_color(Color.RED)

	var col := _marker.get_node("Column") as MeshInstance3D
	var mat := col.material_override as StandardMaterial3D
	assert_almost_eq(
		mat.emission_energy_multiplier, 0.8, 0.001,
		"Emission energy should be 0.8",
	)


func test_set_marker_color_updates_light() -> void:
	var test_color := Color(0.0, 1.0, 0.0)
	_marker.set_marker_color(test_color)

	var light := _marker.get_node("Light") as OmniLight3D
	assert_eq(
		light.light_color, test_color,
		"Light color should match set color",
	)


# ================================================================
# Pulse animation (_process)
# ================================================================

func test_pulse_time_advances() -> void:
	var initial: float = _marker._pulse_time
	_marker._process(0.5)
	assert_gt(
		_marker._pulse_time, initial,
		"_pulse_time should advance after _process",
	)


func test_pulse_scales_column_x_and_z() -> void:
	# After some time, column scale should differ from 1.0
	_marker._pulse_time = 0.0
	_marker._process(1.0)
	var col := _marker.get_node("Column") as MeshInstance3D
	# pulse = 1.0 + 0.1 * sin(3.0) = approximately 1.01411
	var expected := 1.0 + 0.1 * sin(3.0)
	assert_almost_eq(
		col.scale.x, expected, 0.001,
		"Column scale.x should follow pulse formula",
	)
	assert_almost_eq(
		col.scale.z, expected, 0.001,
		"Column scale.z should follow pulse formula",
	)


# ================================================================
# _on_body_entered - signal emission
# ================================================================

func test_body_in_player_group_emits_signal() -> void:
	_marker.mission_id = "test_mission_1"
	_marker.marker_type = "start"

	var result := {"id": "", "type": ""}
	var handler := func(mid: String, mtype: String) -> void:
		result["id"] = mid
		result["type"] = mtype
	EventBus.mission_marker_reached.connect(handler)

	# Create a fake body in "player" group
	var body := CharacterBody3D.new()
	body.add_to_group("player")
	add_child_autofree(body)

	_marker._on_body_entered(body)

	assert_eq(result["id"], "test_mission_1")
	assert_eq(result["type"], "start")
	EventBus.mission_marker_reached.disconnect(handler)


func test_player_vehicle_layer_emits_signal() -> void:
	_marker.mission_id = "test_mission_2"
	_marker.marker_type = "dropoff"

	var result := {"id": "", "type": ""}
	var handler := func(mid: String, mtype: String) -> void:
		result["id"] = mid
		result["type"] = mtype
	EventBus.mission_marker_reached.connect(handler)

	# Create a fake vehicle body with layer 4 (bit 8)
	var body := RigidBody3D.new()
	body.collision_layer = 8  # PlayerVehicle layer
	add_child_autofree(body)

	_marker._on_body_entered(body)

	assert_eq(result["id"], "test_mission_2")
	assert_eq(result["type"], "dropoff")
	EventBus.mission_marker_reached.disconnect(handler)


func test_non_player_body_does_not_emit() -> void:
	_marker.mission_id = "test_mission_3"
	_marker.marker_type = "pickup"

	var result := {"received": false}
	var handler := func(_mid: String, _mtype: String) -> void:
		result["received"] = true
	EventBus.mission_marker_reached.connect(handler)

	# NPC vehicle body - not in player group, layer 16 (NPC)
	var body := RigidBody3D.new()
	body.collision_layer = 16
	add_child_autofree(body)

	_marker._on_body_entered(body)

	assert_false(result["received"], "Non-player body should not trigger signal")
	EventBus.mission_marker_reached.disconnect(handler)


func test_static_body_no_player_group_does_not_emit() -> void:
	_marker.mission_id = "test_mission_4"

	var result := {"received": false}
	var handler := func(_mid: String, _mtype: String) -> void:
		result["received"] = true
	EventBus.mission_marker_reached.connect(handler)

	var body := StaticBody3D.new()
	body.collision_layer = 1  # Ground
	add_child_autofree(body)

	_marker._on_body_entered(body)

	assert_false(result["received"], "Static body should not trigger signal")
	EventBus.mission_marker_reached.disconnect(handler)


# ================================================================
# Mission ID and marker type assignment
# ================================================================

func test_mission_id_settable() -> void:
	_marker.mission_id = "delivery_123"
	assert_eq(_marker.mission_id, "delivery_123")


func test_marker_type_settable() -> void:
	_marker.marker_type = "dropoff"
	assert_eq(_marker.marker_type, "dropoff")


# ================================================================
# _snap_to_ground — ground-level placement
# ================================================================

func test_snap_to_ground_is_called_in_ready() -> void:
	var src: String = MarkerScript.source_code
	assert_true(
		src.contains("_snap_to_ground"),
		"_ready should call _snap_to_ground to prevent rooftop spawns",
	)


func test_snap_to_ground_uses_ground_layer_only() -> void:
	var src: String = MarkerScript.source_code
	assert_true(
		src.contains("collision_mask = 1"),
		"_snap_to_ground raycast should use mask 1 (ground only, not buildings)",
	)
