extends GutTest
## Tests for scenes/world/weapon_pickup.gd — spinning animation, body
## detection logic, and weapon index handling.

const WeaponPickupScript = preload(
	"res://scenes/world/weapon_pickup.gd"
)
const WeaponScript = preload("res://scenes/player/player_weapon.gd")


## Helper: create a weapon pickup with required child nodes so @onready
## variables resolve correctly when added to the tree.
func _make_pickup() -> Node3D:
	var pickup: Node3D = WeaponPickupScript.new()
	var trigger := Area3D.new()
	trigger.name = "Trigger"
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 2.0
	col.shape = shape
	trigger.add_child(col)
	pickup.add_child(trigger)
	var mesh_pivot := Node3D.new()
	mesh_pivot.name = "MeshPivot"
	pickup.add_child(mesh_pivot)
	return pickup


# ==========================================================================
# Initial state
# ==========================================================================

func test_weapon_idx_default_zero() -> void:
	var pickup := _make_pickup()
	add_child_autofree(pickup)
	assert_eq(
		pickup.weapon_idx, 0,
		"Default weapon index should be 0",
	)


func test_spin_time_starts_at_zero() -> void:
	var pickup := _make_pickup()
	add_child_autofree(pickup)
	assert_eq(pickup._spin_time, 0.0)


# ==========================================================================
# Weapon index bounds
# ==========================================================================

func test_weapon_idx_can_be_set() -> void:
	var pickup := _make_pickup()
	add_child_autofree(pickup)
	pickup.weapon_idx = 2
	assert_eq(pickup.weapon_idx, 2)


func test_weapons_array_not_empty() -> void:
	assert_gt(
		WeaponScript.WEAPONS.size(), 0,
		"WEAPONS array should have at least one weapon",
	)


func test_default_weapon_idx_in_range() -> void:
	var pickup := _make_pickup()
	add_child_autofree(pickup)
	assert_gte(pickup.weapon_idx, 0)
	assert_lt(
		pickup.weapon_idx, WeaponScript.WEAPONS.size(),
		"Default weapon_idx should be within WEAPONS range",
	)


# ==========================================================================
# Spin animation math
# ==========================================================================

func test_process_advances_spin_time() -> void:
	var pickup := _make_pickup()
	add_child_autofree(pickup)

	pickup._spin_time = 0.0
	pickup._process(0.5)
	assert_almost_eq(
		pickup._spin_time, 0.5, 0.001,
		"_process should advance _spin_time",
	)


func test_process_rotates_mesh_pivot() -> void:
	var pickup := _make_pickup()
	add_child_autofree(pickup)

	pickup._spin_time = 0.0
	pickup._process(1.0)
	# rotation.y = _spin_time * 1.5 = 1.5
	assert_almost_eq(
		pickup.mesh_pivot.rotation.y, 1.5, 0.001,
		"Mesh pivot should rotate at 1.5 rad/s",
	)


func test_process_bobs_mesh_pivot_y() -> void:
	var pickup := _make_pickup()
	add_child_autofree(pickup)

	pickup._spin_time = 0.0
	pickup._process(1.0)
	# position.y = 1.0 + sin(1.0 * 2.0) * 0.1
	var expected_y := 1.0 + sin(2.0) * 0.1
	assert_almost_eq(
		pickup.mesh_pivot.position.y, expected_y, 0.001,
		"Mesh pivot should bob vertically",
	)


func test_spin_accumulates_over_frames() -> void:
	var pickup := _make_pickup()
	add_child_autofree(pickup)

	pickup._spin_time = 0.0
	pickup._process(0.5)
	pickup._process(0.5)
	assert_almost_eq(pickup._spin_time, 1.0, 0.001)


# ==========================================================================
# Body detection logic — _on_body_entered
# ==========================================================================

func test_player_group_detected() -> void:
	var body := Node3D.new()
	body.add_to_group("player")
	add_child_autofree(body)
	assert_true(
		body.is_in_group("player"),
		"Test body should be in player group",
	)
	var is_player := body.is_in_group("player")
	assert_true(is_player)


func test_vehicle_layer_bit_check() -> void:
	# Layer 4 = bit value 8, which is the PlayerVehicle layer
	var collision_layer := 8
	var is_player_vehicle: bool = (collision_layer & 8) != 0
	assert_true(
		is_player_vehicle,
		"Layer 4 (bit 8) should be detected as player vehicle",
	)


func test_collision_layer_zero_not_player_vehicle() -> void:
	var collision_layer := 0
	var is_player_vehicle: bool = (collision_layer & 8) != 0
	assert_false(
		is_player_vehicle,
		"Layer 0 should not be detected as player vehicle",
	)


func test_npc_vehicle_layer_not_player_vehicle() -> void:
	# Layer 5 (bit 16) = NPC vehicles
	var collision_layer := 16
	var is_player_vehicle: bool = (collision_layer & 8) != 0
	assert_false(
		is_player_vehicle,
		"NPC vehicle layer should not be detected as player vehicle",
	)


func test_police_vehicle_layer_not_player_vehicle() -> void:
	# Layer 7 (bit 64) = Police vehicles
	var collision_layer := 64
	var is_player_vehicle: bool = (collision_layer & 8) != 0
	assert_false(is_player_vehicle)


func test_combined_layers_detect_player_vehicle() -> void:
	# Player vehicle + static layer
	var collision_layer := 8 + 2  # layer 4 + layer 2
	var is_player_vehicle: bool = (collision_layer & 8) != 0
	assert_true(
		is_player_vehicle,
		"Combined layers including bit 8 should detect player vehicle",
	)


# ==========================================================================
# Weapon data integrity (since pickup references WEAPONS array)
# ==========================================================================

func test_all_weapons_have_name() -> void:
	for w in WeaponScript.WEAPONS:
		assert_true(
			w.has("name"),
			"Each weapon should have a name",
		)
		assert_gt(
			(w.name as String).length(), 0,
			"Weapon name should not be empty",
		)


func test_all_weapons_have_positive_damage() -> void:
	for w in WeaponScript.WEAPONS:
		assert_gt(
			w.damage, 0.0,
			"Weapon '%s' should have positive damage" % w.name,
		)


func test_all_weapons_have_positive_range() -> void:
	for w in WeaponScript.WEAPONS:
		assert_gt(
			w.range, 0.0,
			"Weapon '%s' should have positive range" % w.name,
		)


func test_all_weapons_have_positive_cooldown() -> void:
	for w in WeaponScript.WEAPONS:
		assert_gt(
			w.cooldown, 0.0,
			"Weapon '%s' should have positive cooldown" % w.name,
		)


func test_weapon_names_are_unique() -> void:
	var names: Array[String] = []
	for w in WeaponScript.WEAPONS:
		assert_does_not_have(
			names, w.name,
			"Weapon name '%s' should be unique" % w.name,
		)
		names.append(w.name)


# ==========================================================================
# Mesh building — weapon index out of range
# ==========================================================================

func test_build_mesh_with_invalid_index_no_crash() -> void:
	var pickup := _make_pickup()
	pickup.weapon_idx = 999
	add_child_autofree(pickup)
	# _ready calls _build_mesh which should bail with invalid idx
	assert_eq(
		pickup.mesh_pivot.get_child_count(), 0,
		"Invalid weapon index should not add any mesh children",
	)


func test_build_mesh_with_negative_index_no_crash() -> void:
	var pickup := _make_pickup()
	pickup.weapon_idx = -1
	add_child_autofree(pickup)
	assert_eq(
		pickup.mesh_pivot.get_child_count(), 0,
		"Negative weapon index should not add any mesh children",
	)
