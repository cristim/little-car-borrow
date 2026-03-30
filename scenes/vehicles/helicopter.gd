extends CharacterBody3D
## Player-pilotable helicopter. Builds all geometry procedurally in _ready().
## Parked helicopters fall under gravity; player-controlled ones use
## HelicopterController for flight physics.

const GRAVITY := 9.8

var _controller: Node = null


func _ready() -> void:
	add_to_group("helicopter")
	collision_layer = 16   # NPC vehicles layer (same as traffic NPC)
	collision_mask = 3     # ground (1) + static (2) — for landing
	_build_mesh()
	_setup_interaction()
	_controller = get_node_or_null("HelicopterController")


func _physics_process(delta: float) -> void:
	if _controller and _controller.active:
		_controller.physics_update(delta, self)
	else:
		velocity.y -= GRAVITY * delta
		move_and_slide()


func _build_mesh() -> void:
	var builder: RefCounted = preload(
		"res://scenes/vehicles/helicopter_body_builder.gd"
	).new()

	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.15, 0.15, 0.18, 1.0)
	body_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var rotor_mat := StandardMaterial3D.new()
	rotor_mat.albedo_color = Color(0.1, 0.1, 0.1, 1.0)

	# Body node — tilts visually during flight via HelicopterController
	var body := Node3D.new()
	body.name = "Body"
	add_child(body)

	# Fuselage surface 1 (front/sides): translucent glass, double-sided
	var glass_mat := StandardMaterial3D.new()
	glass_mat.albedo_color = Color(0.55, 0.75, 0.85, 0.35)
	glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	# Fuselage: surface 0 = opaque body, surface 1 = glass faces
	var fuselage := MeshInstance3D.new()
	fuselage.name = "Fuselage"
	var fuse_mesh: ArrayMesh = builder.build_fuselage() as ArrayMesh
	fuse_mesh.surface_set_material(0, body_mat)
	fuse_mesh.surface_set_material(1, glass_mat)
	fuselage.mesh = fuse_mesh
	body.add_child(fuselage)

	# Cockpit seat (inside cabin, forward section)
	var seat_mat := StandardMaterial3D.new()
	seat_mat.albedo_color = Color(0.25, 0.22, 0.18)
	var seat_mesh := MeshInstance3D.new()
	seat_mesh.name = "CockpitSeat"
	seat_mesh.mesh = builder.build_cockpit_seat()
	seat_mesh.material_override = seat_mat
	body.add_child(seat_mesh)

	# Tail rotor at end of boom, offset to left side
	# Boom rear Z = FUSE_HL + TAIL_LEN = 2.5 + 3.5 = 6.0
	var tail_rotor := MeshInstance3D.new()
	tail_rotor.name = "TailRotor"
	tail_rotor.mesh = builder.build_tail_rotor()
	tail_rotor.material_override = rotor_mat
	tail_rotor.position = Vector3(-0.35, 0.0, 6.0)
	body.add_child(tail_rotor)

	# Main rotor hub on mast above fuselage (y=1.5 clears cabin top at y=1.1)
	var rotor := Node3D.new()
	rotor.name = "Rotor"
	rotor.position = Vector3(0.0, 1.5, 0.0)
	add_child(rotor)

	var rotor_blades := MeshInstance3D.new()
	rotor_blades.name = "RotorBlades"
	rotor_blades.mesh = builder.build_main_rotor()
	rotor_blades.material_override = rotor_mat
	rotor.add_child(rotor_blades)

	# Collision capsule — scaled to the larger fuselage
	# Skid bottom Y = -(FUSE_HH + SKID_DROP + SKID_HEIGHT/2) = -(1.1+0.7+0.03) = -1.83
	# CapsuleShape3D: radius=1.1, height=1.5 → half_total = 0.75+1.1 = 1.85
	# Shape center Y = -1.83 + 1.85 = +0.02
	var col := CollisionShape3D.new()
	col.name = "BodyCollision"
	var cap := CapsuleShape3D.new()
	cap.radius = 1.1
	cap.height = 1.5
	col.shape = cap
	col.position = Vector3(0.0, 0.02, 0.0)
	add_child(col)

	# Exit marker: player spawns to the left on dismount
	var marker := Marker3D.new()
	marker.name = "DoorMarker"
	marker.position = Vector3(-3.5, 0.0, 0.0)
	add_child(marker)

	# Flight controller
	var CtrlScript: GDScript = preload(
		"res://scenes/vehicles/helicopter_controller.gd"
	)
	_controller = CtrlScript.new()
	_controller.name = "HelicopterController"
	add_child(_controller)


func _setup_interaction() -> void:
	var area := Area3D.new()
	area.name = "InteractionArea"
	area.collision_layer = 256
	area.collision_mask = 0
	area.add_to_group("vehicle_interaction")

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(5.0, 2.5, 7.0)
	shape.shape = box
	area.add_child(shape)
	add_child(area)
