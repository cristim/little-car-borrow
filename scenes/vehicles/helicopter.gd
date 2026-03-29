extends CharacterBody3D
## Player-pilotable helicopter. Builds all geometry procedurally in _ready().
## Parked helicopters fall under gravity; player-controlled ones use
## HelicopterController for flight physics.

const GRAVITY := 20.0

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

	var rotor_mat := StandardMaterial3D.new()
	rotor_mat.albedo_color = Color(0.1, 0.1, 0.1, 1.0)

	# Body node — tilts visually during flight via HelicopterController
	var body := Node3D.new()
	body.name = "Body"
	add_child(body)

	var fuselage := MeshInstance3D.new()
	fuselage.name = "Fuselage"
	fuselage.mesh = builder.build_fuselage()
	fuselage.material_override = body_mat
	body.add_child(fuselage)

	# Tail rotor at end of boom, offset to left side
	# Boom rear Z = FUSE_HL + TAIL_LEN = 2.0 + 3.0 = 5.0
	var tail_rotor := MeshInstance3D.new()
	tail_rotor.name = "TailRotor"
	tail_rotor.mesh = builder.build_tail_rotor()
	tail_rotor.material_override = rotor_mat
	tail_rotor.position = Vector3(-0.3, 0.0, 5.0)
	body.add_child(tail_rotor)

	# Main rotor hub at fuselage top (FUSE_HH = 0.75)
	var rotor := Node3D.new()
	rotor.name = "Rotor"
	rotor.position = Vector3(0.0, 0.75, 0.0)
	add_child(rotor)

	var rotor_blades := MeshInstance3D.new()
	rotor_blades.name = "RotorBlades"
	rotor_blades.mesh = builder.build_main_rotor()
	rotor_blades.material_override = rotor_mat
	rotor.add_child(rotor_blades)

	# Collision capsule aligned with fuselage body
	# Skid bottom Y = -(FUSE_HH + SKID_DROP + SKID_HEIGHT/2) = -(0.75+0.6+0.03) = -1.38
	# CapsuleShape3D: radius=0.8, height=1.0 → half_total = 0.5+0.8 = 1.3
	# Shape center Y so that bottom aligns with skids: y = -1.38 + 1.3 = -0.08
	var col := CollisionShape3D.new()
	col.name = "BodyCollision"
	var cap := CapsuleShape3D.new()
	cap.radius = 0.8
	cap.height = 1.0
	col.shape = cap
	col.position = Vector3(0.0, -0.08, 0.0)
	add_child(col)

	# Exit marker: player spawns to the left on dismount
	var marker := Marker3D.new()
	marker.name = "DoorMarker"
	marker.position = Vector3(-2.5, 0.0, 0.0)
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
	box.size = Vector3(3.5, 2.0, 5.0)
	shape.shape = box
	area.add_child(shape)
	add_child(area)
