extends RigidBody3D
## Ragdoll body spawned when a pedestrian is hit by a vehicle.
## Copies the visual model, launches with vehicle velocity, auto-despawns.

const DESPAWN_TIME := 5.0
const UPWARD_BOOST := 4.0
const SPIN_TORQUE := 8.0

var _timer := 0.0


func _ready() -> void:
	gravity_scale = 1.2
	mass = 60.0
	collision_layer = 0  # doesn't collide with anything as a layer
	collision_mask = 3   # bounces off ground + static

	# Add a capsule collision shape matching pedestrian
	var col := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.25
	shape.height = 1.7
	col.shape = shape
	col.position.y = 0.85
	add_child(col)

	# Physics material for bounce
	var mat := PhysicsMaterial.new()
	mat.bounce = 0.3
	mat.friction = 0.8
	physics_material_override = mat


func _process(delta: float) -> void:
	_timer += delta
	# Fade out in last second
	if _timer > DESPAWN_TIME - 1.0:
		var fade := 1.0 - (_timer - (DESPAWN_TIME - 1.0))
		_set_alpha(maxf(fade, 0.0))
	if _timer >= DESPAWN_TIME:
		queue_free()


func launch(vehicle_velocity: Vector3) -> void:
	# Launch in the vehicle's direction with upward boost
	var impulse := vehicle_velocity * 1.2
	impulse.y = absf(vehicle_velocity.length()) * 0.5 + UPWARD_BOOST
	apply_central_impulse(impulse * mass)

	# Random spin for tumbling
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	apply_torque_impulse(Vector3(
		rng.randf_range(-1.0, 1.0) * SPIN_TORQUE,
		rng.randf_range(-1.0, 1.0) * SPIN_TORQUE,
		rng.randf_range(-1.0, 1.0) * SPIN_TORQUE,
	) * mass)


func copy_visual_from(source: Node3D) -> void:
	var model := source.get_node_or_null("PedestrianModel")
	if not model:
		model = source.get_node_or_null("OfficerModel")
	if not model:
		return
	# Clone each mesh child from the model
	for child in model.get_children():
		if child is MeshInstance3D:
			var mesh_copy := MeshInstance3D.new()
			mesh_copy.mesh = (child as MeshInstance3D).mesh
			mesh_copy.material_override = (
				(child as MeshInstance3D).material_override
			)
			mesh_copy.position = child.position
			mesh_copy.rotation = child.rotation
			mesh_copy.scale = child.scale
			add_child(mesh_copy)


func _set_alpha(alpha: float) -> void:
	for child in get_children():
		if child is MeshInstance3D:
			var mat = (child as MeshInstance3D).material_override
			if mat is StandardMaterial3D:
				(mat as StandardMaterial3D).transparency = (
					BaseMaterial3D.TRANSPARENCY_ALPHA
				)
				var c: Color = (mat as StandardMaterial3D).albedo_color
				c.a = alpha
				(mat as StandardMaterial3D).albedo_color = c
