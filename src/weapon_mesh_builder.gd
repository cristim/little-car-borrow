extends RefCounted
## Builds procedural 3D weapon models from primitive meshes.
## Shared by player_weapon.gd (scale 1.0) and weapon_pickup.gd (scale 3.0).


func build(weapon_name: String, scale_factor: float = 1.0) -> Node3D:
	var root := Node3D.new()
	root.name = weapon_name

	match weapon_name:
		"Pistol":
			_build_pistol(root)
		"SMG":
			_build_smg(root)
		"Shotgun":
			_build_shotgun(root)
		"Rifle":
			_build_rifle(root)

	if scale_factor != 1.0:
		root.scale = Vector3.ONE * scale_factor
	return root


func _build_pistol(root: Node3D) -> void:
	var metal_dark := _mat(Color(0.12, 0.12, 0.12), 0.7, 0.4)
	var metal_mid := _mat(Color(0.2, 0.2, 0.22), 0.7, 0.4)
	var grip := _mat(Color(0.08, 0.06, 0.04), 0.0, 0.8)

	# muzzle_local_z = -0.12 (muzzle_z=-0.2 + 0.08 = -0.12)
	root.set_meta("muzzle_local_pos", Vector3(0.0, 0.0, -0.12))

	_add_cylinder(
		root, "Barrel", 0.012, 0.14,
		Vector3(0.0, 0.01, -0.05), Vector3.ZERO, metal_dark
	)
	_add_box(
		root, "Slide", Vector3(0.05, 0.035, 0.16),
		Vector3(0.0, 0.0, -0.02), Vector3.ZERO, metal_mid
	)
	_add_box(
		root, "Frame", Vector3(0.045, 0.025, 0.1),
		Vector3(0.0, -0.02, 0.01), Vector3.ZERO, metal_dark
	)
	_add_box(
		root, "Grip", Vector3(0.04, 0.07, 0.035),
		Vector3(0.0, -0.06, 0.04), Vector3(0.2, 0.0, 0.0), grip
	)
	_add_box(
		root, "TriggerGuard", Vector3(0.01, 0.025, 0.04),
		Vector3(0.0, -0.04, 0.01), Vector3.ZERO, metal_dark
	)


func _build_smg(root: Node3D) -> void:
	var metal_dark := _mat(Color(0.12, 0.12, 0.12), 0.7, 0.4)
	var metal_mid := _mat(Color(0.2, 0.2, 0.22), 0.7, 0.4)
	var grip := _mat(Color(0.08, 0.06, 0.04), 0.0, 0.8)
	var mag := _mat(Color(0.15, 0.15, 0.15), 0.5, 0.5)

	# muzzle_local_z = -0.17 (muzzle_z=-0.25 + 0.08 = -0.17)
	root.set_meta("muzzle_local_pos", Vector3(0.0, 0.0, -0.17))

	_add_cylinder(
		root, "Barrel", 0.012, 0.12,
		Vector3(0.0, 0.0, -0.11), Vector3.ZERO, metal_dark
	)
	_add_box(
		root, "BarrelShroud", Vector3(0.045, 0.04, 0.1),
		Vector3(0.0, 0.0, -0.07), Vector3.ZERO, metal_mid
	)
	_add_box(
		root, "Receiver", Vector3(0.055, 0.06, 0.12),
		Vector3(0.0, 0.0, 0.01), Vector3.ZERO, metal_dark
	)
	_add_box(
		root, "Grip", Vector3(0.035, 0.06, 0.03),
		Vector3(0.0, -0.05, 0.04), Vector3(0.15, 0.0, 0.0), grip
	)
	_add_box(
		root, "Magazine", Vector3(0.035, 0.08, 0.02),
		Vector3(0.0, -0.06, 0.0), Vector3(0.1, 0.0, 0.0), mag
	)
	_add_box(
		root, "StockStub", Vector3(0.04, 0.035, 0.06),
		Vector3(0.0, -0.005, 0.1), Vector3.ZERO, metal_dark
	)


func _build_shotgun(root: Node3D) -> void:
	var metal_dark := _mat(Color(0.12, 0.12, 0.12), 0.7, 0.4)
	var metal_mid := _mat(Color(0.2, 0.2, 0.22), 0.7, 0.4)
	var grip := _mat(Color(0.08, 0.06, 0.04), 0.0, 0.8)
	var wood := _mat(Color(0.35, 0.2, 0.1), 0.0, 0.8)

	# muzzle_local_z = -0.22 (muzzle_z=-0.3 + 0.08 = -0.22)
	root.set_meta("muzzle_local_pos", Vector3(0.0, 0.0, -0.22))

	_add_cylinder(
		root, "Barrel", 0.018, 0.25,
		Vector3(0.0, 0.01, -0.1), Vector3.ZERO, metal_dark
	)
	_add_cylinder(
		root, "PumpTube", 0.012, 0.12,
		Vector3(0.0, -0.02, -0.06), Vector3.ZERO, metal_mid
	)
	_add_box(
		root, "PumpGrip", Vector3(0.04, 0.035, 0.06),
		Vector3(0.0, -0.02, -0.06), Vector3.ZERO, grip
	)
	_add_box(
		root, "Receiver", Vector3(0.06, 0.05, 0.1),
		Vector3(0.0, 0.0, 0.03), Vector3.ZERO, metal_dark
	)
	_add_box(
		root, "Stock", Vector3(0.04, 0.05, 0.12),
		Vector3(0.0, -0.005, 0.14), Vector3(0.08, 0.0, 0.0), wood
	)
	_add_box(
		root, "StockEnd", Vector3(0.04, 0.06, 0.03),
		Vector3(0.0, -0.005, 0.21), Vector3.ZERO, wood
	)
	_add_box(
		root, "TriggerGuard", Vector3(0.01, 0.02, 0.04),
		Vector3(0.0, -0.035, 0.04), Vector3.ZERO, metal_dark
	)


func _build_rifle(root: Node3D) -> void:
	var metal_dark := _mat(Color(0.12, 0.12, 0.12), 0.7, 0.4)
	var metal_mid := _mat(Color(0.2, 0.2, 0.22), 0.7, 0.4)
	var grip := _mat(Color(0.08, 0.06, 0.04), 0.0, 0.8)
	var wood := _mat(Color(0.35, 0.2, 0.1), 0.0, 0.8)
	var mag := _mat(Color(0.15, 0.15, 0.15), 0.5, 0.5)

	# muzzle_local_z = -0.32 (muzzle_z=-0.4 + 0.08 = -0.32)
	root.set_meta("muzzle_local_pos", Vector3(0.0, 0.0, -0.32))

	_add_cylinder(
		root, "Barrel", 0.01, 0.3,
		Vector3(0.0, 0.0, -0.17), Vector3.ZERO, metal_dark
	)
	_add_box(
		root, "Handguard", Vector3(0.035, 0.03, 0.12),
		Vector3(0.0, 0.0, -0.08), Vector3.ZERO, metal_mid
	)
	_add_box(
		root, "Receiver", Vector3(0.04, 0.04, 0.14),
		Vector3(0.0, 0.0, 0.05), Vector3.ZERO, metal_dark
	)
	_add_cylinder(
		root, "Scope", 0.012, 0.1,
		Vector3(0.0, 0.035, 0.0), Vector3.ZERO, metal_mid
	)
	_add_box(
		root, "ScopeMount1", Vector3(0.008, 0.012, 0.008),
		Vector3(0.0, 0.025, -0.02), Vector3.ZERO, metal_dark
	)
	_add_box(
		root, "ScopeMount2", Vector3(0.008, 0.012, 0.008),
		Vector3(0.0, 0.025, 0.02), Vector3.ZERO, metal_dark
	)
	_add_box(
		root, "Magazine", Vector3(0.025, 0.06, 0.02),
		Vector3(0.0, -0.04, 0.04), Vector3(0.05, 0.0, 0.0), mag
	)
	_add_box(
		root, "Grip", Vector3(0.03, 0.05, 0.025),
		Vector3(0.0, -0.04, 0.08), Vector3(0.2, 0.0, 0.0), grip
	)
	_add_box(
		root, "Stock", Vector3(0.035, 0.04, 0.1),
		Vector3(0.0, -0.005, 0.17), Vector3.ZERO, wood
	)
	_add_box(
		root, "StockPad", Vector3(0.035, 0.05, 0.015),
		Vector3(0.0, -0.005, 0.225), Vector3.ZERO, grip
	)


func _add_box(
	parent: Node3D,
	part_name: String,
	size: Vector3,
	pos: Vector3,
	rot: Vector3,
	material: StandardMaterial3D,
) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = part_name
	var box := BoxMesh.new()
	box.size = size
	box.material = material
	mi.mesh = box
	mi.position = pos
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _add_cylinder(
	parent: Node3D,
	part_name: String,
	radius: float,
	height: float,
	pos: Vector3,
	extra_rot: Vector3,
	material: StandardMaterial3D,
) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = part_name
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = height
	cyl.material = material
	mi.mesh = cyl
	mi.position = pos
	# CylinderMesh height is along Y; rotate PI/2 around X to orient along Z
	mi.rotation = Vector3(PI / 2.0 + extra_rot.x, extra_rot.y, extra_rot.z)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _mat(
	color: Color, metallic: float, roughness: float
) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = roughness
	return m
