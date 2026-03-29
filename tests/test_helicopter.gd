extends GutTest
## Tests for helicopter.gd and helicopter_controller.gd

const HelicopterScene := preload("res://scenes/vehicles/helicopter.tscn")

var _heli: CharacterBody3D = null


func before_each() -> void:
	_heli = HelicopterScene.instantiate() as CharacterBody3D
	add_child_autofree(_heli)
	await get_tree().process_frame


# --- Structure ---

func test_helicopter_is_character_body() -> void:
	assert_true(_heli is CharacterBody3D, "Helicopter should be a CharacterBody3D")


func test_helicopter_in_helicopter_group() -> void:
	assert_true(
		_heli.is_in_group("helicopter"),
		"Helicopter should be in the 'helicopter' group",
	)


func test_helicopter_has_body_node() -> void:
	var body := _heli.get_node_or_null("Body")
	assert_not_null(body, "Helicopter should have a Body node for visual tilt")


func test_helicopter_has_fuselage() -> void:
	var fuse := _heli.get_node_or_null("Body/Fuselage")
	assert_not_null(fuse, "Helicopter should have Body/Fuselage MeshInstance3D")


func test_helicopter_has_rotor() -> void:
	var rotor := _heli.get_node_or_null("Rotor")
	assert_not_null(rotor, "Helicopter should have a Rotor node")


func test_helicopter_has_tail_rotor() -> void:
	var tr := _heli.get_node_or_null("Body/TailRotor")
	assert_not_null(tr, "Helicopter should have a TailRotor MeshInstance3D")


func test_helicopter_has_collision_shape() -> void:
	var col := _heli.get_node_or_null("BodyCollision")
	assert_not_null(col, "Helicopter should have a BodyCollision CollisionShape3D")


func test_helicopter_has_door_marker() -> void:
	var marker := _heli.get_node_or_null("DoorMarker")
	assert_not_null(marker, "Helicopter should have a DoorMarker")


func test_door_marker_offset_to_left() -> void:
	var marker := _heli.get_node_or_null("DoorMarker") as Marker3D
	assert_not_null(marker)
	assert_lt(
		marker.position.x, 0.0,
		"DoorMarker should be to the left (negative X) of helicopter",
	)


func test_helicopter_has_interaction_area() -> void:
	var area := _heli.get_node_or_null("InteractionArea")
	assert_not_null(area, "Helicopter should have an InteractionArea")


func test_interaction_area_in_vehicle_interaction_group() -> void:
	var area := _heli.get_node_or_null("InteractionArea") as Area3D
	assert_not_null(area)
	assert_true(
		area.is_in_group("vehicle_interaction"),
		"InteractionArea should be in 'vehicle_interaction' group",
	)


func test_interaction_area_collision_layer_256() -> void:
	var area := _heli.get_node_or_null("InteractionArea") as Area3D
	assert_not_null(area)
	assert_eq(
		area.collision_layer, 256,
		"InteractionArea collision_layer should be 256",
	)


func test_helicopter_has_controller() -> void:
	var ctrl := _heli.get_node_or_null("HelicopterController")
	assert_not_null(
		ctrl, "Helicopter should have a HelicopterController child node"
	)


# --- Controller ---

func test_controller_inactive_by_default() -> void:
	var ctrl := _heli.get_node_or_null("HelicopterController")
	assert_not_null(ctrl)
	assert_false(ctrl.active, "HelicopterController should be inactive by default")


func test_controller_can_be_activated() -> void:
	var ctrl := _heli.get_node_or_null("HelicopterController")
	assert_not_null(ctrl)
	ctrl.active = true
	assert_true(ctrl.active, "HelicopterController should become active when set")
	ctrl.active = false


func test_controller_deactivate_clears_inputs() -> void:
	var ctrl := _heli.get_node_or_null("HelicopterController")
	assert_not_null(ctrl)
	ctrl.active = true
	ctrl.active = false
	assert_almost_eq(ctrl._fwd_input, 0.0, 0.001, "_fwd_input should be 0 after deactivation")
	assert_almost_eq(ctrl._yaw_input, 0.0, 0.001, "_yaw_input should be 0 after deactivation")
	assert_almost_eq(ctrl._asc_input, 0.0, 0.001, "_asc_input should be 0 after deactivation")


# --- Collision layers ---

func test_helicopter_collision_layer_is_npc_vehicles() -> void:
	assert_eq(_heli.collision_layer, 16, "Parked helicopter should be on NPC layer (16)")


func test_helicopter_collision_mask_includes_ground() -> void:
	assert_true(
		(_heli.collision_mask & 1) != 0,
		"Helicopter collision_mask should include ground layer (1)",
	)
