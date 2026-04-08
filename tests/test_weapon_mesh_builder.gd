extends GutTest
## Tests for WeaponMeshBuilder procedural weapon models.

const BuilderScript = preload("res://src/weapon_mesh_builder.gd")
const WeaponScript = preload("res://scenes/player/player_weapon.gd")
const WEAPON_NAMES := ["Pistol", "SMG", "Shotgun", "Rifle"]


func _build(weapon_name: String, sf: float = 1.0) -> Node3D:
	var builder: RefCounted = BuilderScript.new()
	return builder.build(weapon_name, sf)


func test_build_returns_node3d_for_each_weapon() -> void:
	for wname in WEAPON_NAMES:
		var root: Node3D = _build(wname)
		assert_not_null(root, "%s should return non-null" % wname)
		assert_is(root, Node3D, "%s should be Node3D" % wname)
		assert_gt(
			root.get_child_count(),
			0,
			"%s should have children" % wname,
		)
		root.free()


func test_build_unknown_returns_empty() -> void:
	var root: Node3D = _build("BFG9000")
	assert_not_null(root)
	assert_eq(root.get_child_count(), 0, "Unknown weapon has no children")
	root.free()


func test_pistol_has_expected_parts() -> void:
	var root: Node3D = _build("Pistol")
	for part in ["Barrel", "Slide", "Frame", "Grip", "TriggerGuard"]:
		assert_not_null(
			root.find_child(part, false, false),
			"Pistol missing %s" % part,
		)
	root.free()


func test_smg_has_expected_parts() -> void:
	var root: Node3D = _build("SMG")
	for part in [
		"Barrel",
		"BarrelShroud",
		"Receiver",
		"Grip",
		"Magazine",
		"StockStub",
	]:
		assert_not_null(
			root.find_child(part, false, false),
			"SMG missing %s" % part,
		)
	root.free()


func test_shotgun_has_expected_parts() -> void:
	var root: Node3D = _build("Shotgun")
	for part in [
		"Barrel",
		"PumpTube",
		"PumpGrip",
		"Receiver",
		"Stock",
		"StockEnd",
		"TriggerGuard",
	]:
		assert_not_null(
			root.find_child(part, false, false),
			"Shotgun missing %s" % part,
		)
	root.free()


func test_rifle_has_expected_parts() -> void:
	var root: Node3D = _build("Rifle")
	for part in [
		"Barrel",
		"Handguard",
		"Receiver",
		"Scope",
		"ScopeMount1",
		"ScopeMount2",
		"Magazine",
		"Grip",
		"Stock",
		"StockPad",
	]:
		assert_not_null(
			root.find_child(part, false, false),
			"Rifle missing %s" % part,
		)
	root.free()


func test_barrel_is_cylinder_mesh() -> void:
	for wname in WEAPON_NAMES:
		var root: Node3D = _build(wname)
		var barrel: MeshInstance3D = root.find_child("Barrel", false, false)
		assert_not_null(barrel, "%s barrel exists" % wname)
		assert_is(
			barrel.mesh,
			CylinderMesh,
			"%s barrel should be CylinderMesh" % wname,
		)
		root.free()


func test_barrel_oriented_along_z() -> void:
	for wname in WEAPON_NAMES:
		var root: Node3D = _build(wname)
		var barrel: MeshInstance3D = root.find_child("Barrel", false, false)
		assert_almost_eq(
			barrel.rotation.x,
			PI / 2.0,
			0.01,
			"%s barrel rotation.x ~= PI/2" % wname,
		)
		root.free()


func test_each_weapon_has_muzzle_meta() -> void:
	for wname in WEAPON_NAMES:
		var root: Node3D = _build(wname)
		assert_true(
			root.has_meta("muzzle_local_pos"),
			"%s should have muzzle_local_pos meta" % wname,
		)
		root.free()


func test_muzzle_z_matches_weapon_data() -> void:
	for i in range(WeaponScript.WEAPONS.size()):
		var w: Dictionary = WeaponScript.WEAPONS[i]
		var wname: String = w["name"]
		var expected_z: float = w["muzzle_z"] + 0.08
		var root: Node3D = _build(wname)
		var muzzle_pos: Vector3 = root.get_meta("muzzle_local_pos")
		assert_almost_eq(
			muzzle_pos.z,
			expected_z,
			0.001,
			"%s muzzle_z should match weapon data" % wname,
		)
		root.free()


func test_scale_factor_applies() -> void:
	var root: Node3D = _build("Pistol", 3.0)
	assert_almost_eq(root.scale.x, 3.0, 0.001, "Scale x = 3")
	assert_almost_eq(root.scale.y, 3.0, 0.001, "Scale y = 3")
	assert_almost_eq(root.scale.z, 3.0, 0.001, "Scale z = 3")
	root.free()


func test_all_children_are_mesh_instances() -> void:
	for wname in WEAPON_NAMES:
		var root: Node3D = _build(wname)
		for child in root.get_children():
			assert_is(
				child,
				MeshInstance3D,
				"%s child %s should be MeshInstance3D" % [wname, child.name],
			)
		root.free()


func test_all_meshes_have_material() -> void:
	for wname in WEAPON_NAMES:
		var root: Node3D = _build(wname)
		for child in root.get_children():
			var mi: MeshInstance3D = child as MeshInstance3D
			if mi:
				assert_not_null(
					mi.mesh.material,
					"%s/%s should have material" % [wname, mi.name],
				)
		root.free()


# ==========================================================================
# Iron sights and detail parts added per weapon
# ==========================================================================


func test_pistol_has_iron_sights() -> void:
	var root: Node3D = _build("Pistol")
	for part in ["FrontSight", "RearSightL", "RearSightR"]:
		assert_not_null(
			root.find_child(part, false, false),
			"Pistol should have %s" % part,
		)
	root.free()


func test_pistol_front_sight_above_slide() -> void:
	var root: Node3D = _build("Pistol")
	var slide: MeshInstance3D = root.find_child("Slide", false, false)
	var front: MeshInstance3D = root.find_child("FrontSight", false, false)
	assert_gt(
		front.position.y,
		slide.position.y,
		"FrontSight Y should be above Slide Y",
	)
	root.free()


func test_pistol_rear_sights_are_symmetric() -> void:
	var root: Node3D = _build("Pistol")
	var sl: MeshInstance3D = root.find_child("RearSightL", false, false)
	var sr: MeshInstance3D = root.find_child("RearSightR", false, false)
	assert_almost_eq(
		sl.position.x,
		-sr.position.x,
		0.001,
		"Rear sight posts should be symmetric about X = 0",
	)
	assert_almost_eq(
		sl.position.y,
		sr.position.y,
		0.001,
		"Rear sight posts should be at the same height",
	)
	root.free()


func test_smg_has_front_sight_and_charging_handle() -> void:
	var root: Node3D = _build("SMG")
	for part in ["FrontSight", "ChargingHandle"]:
		assert_not_null(
			root.find_child(part, false, false),
			"SMG should have %s" % part,
		)
	root.free()


func test_smg_charging_handle_is_offset_to_side() -> void:
	var root: Node3D = _build("SMG")
	var handle: MeshInstance3D = root.find_child("ChargingHandle", false, false)
	assert_gt(
		absf(handle.position.x),
		0.02,
		"ChargingHandle should be laterally offset from centre",
	)
	root.free()


func test_shotgun_has_front_bead_and_ejection_port() -> void:
	var root: Node3D = _build("Shotgun")
	for part in ["FrontBead", "EjectionPort"]:
		assert_not_null(
			root.find_child(part, false, false),
			"Shotgun should have %s" % part,
		)
	root.free()


func test_shotgun_front_bead_near_muzzle() -> void:
	var root: Node3D = _build("Shotgun")
	var bead: MeshInstance3D = root.find_child("FrontBead", false, false)
	var muzzle_z: float = (root.get_meta("muzzle_local_pos") as Vector3).z
	# Bead Z should be within 0.05 of the muzzle end
	assert_lt(
		bead.position.z,
		muzzle_z + 0.05,
		"FrontBead should be near the muzzle end of the barrel",
	)
	root.free()


func test_rifle_has_detail_parts() -> void:
	var root: Node3D = _build("Rifle")
	for part in ["ChargingHandle", "MuzzleDevice", "ScopeEyepiece"]:
		assert_not_null(
			root.find_child(part, false, false),
			"Rifle should have %s" % part,
		)
	root.free()


func test_rifle_muzzle_device_at_barrel_end() -> void:
	var root: Node3D = _build("Rifle")
	var muzzle_dev: MeshInstance3D = root.find_child("MuzzleDevice", false, false)
	var barrel: MeshInstance3D = root.find_child("Barrel", false, false)
	# Muzzle device Z should be more negative than barrel center (closer to tip)
	assert_lt(
		muzzle_dev.position.z,
		barrel.position.z,
		"MuzzleDevice should be further toward barrel tip than barrel centre",
	)
	root.free()


func test_rifle_scope_eyepiece_behind_scope_body() -> void:
	var root: Node3D = _build("Rifle")
	var scope: MeshInstance3D = root.find_child("Scope", false, false)
	var eyepiece: MeshInstance3D = root.find_child("ScopeEyepiece", false, false)
	# Eyepiece is at the rear (higher Z) of the scope tube
	assert_gt(
		eyepiece.position.z,
		scope.position.z,
		"ScopeEyepiece should be at the rear (larger Z) of the scope",
	)
	root.free()
