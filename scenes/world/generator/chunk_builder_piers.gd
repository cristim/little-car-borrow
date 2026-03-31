extends RefCounted
## Generates piers on coastal terrain tiles and spawns interactive boats.

const SEA_LEVEL := -2.0
const PIER_CHANCE := 0.4
const PIER_WIDTH := 3.0
const PIER_LENGTH := 12.0
const PIER_HEIGHT := 0.5  # above sea level
const PILING_RADIUS := 0.15
const PILING_COUNT := 6
const BOAT_VARIANTS := ["speedboat", "fishing", "runabout"]

var _grid: RefCounted = null
var _boundary: RefCounted = null
var _boat_builder: RefCounted = null
var _wood_mat: StandardMaterial3D = null


func init(grid: RefCounted, boundary: RefCounted) -> void:
	_grid = grid
	_boundary = boundary
	_boat_builder = preload(
		"res://scenes/vehicles/boat_body_builder.gd"
	).new()

	_wood_mat = StandardMaterial3D.new()
	_wood_mat.albedo_color = Color(0.45, 0.30, 0.15)
	_wood_mat.roughness = 0.8


func build(chunk: Node3D, tile: Vector2i, ox: float, oz: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(tile) ^ 0xD13B

	var roll: float = rng.randf()
	if roll > PIER_CHANCE:
		return

	# Find a coastal edge: sample along chunk edges to find shore
	var span: float = _grid.get_grid_span()
	var hs := span * 0.5
	var shore_info: Dictionary = _find_shore_edge(ox, oz, hs)
	if shore_info.is_empty():
		return

	var shore_pos: Vector3 = shore_info["position"]
	var pier_dir: Vector3 = shore_info["direction"]  # points into water

	_build_pier_geometry(chunk, shore_pos, pier_dir)
	_spawn_boats(chunk, tile, shore_pos, pier_dir, rng)

	chunk.set_meta("has_pier", true)
	chunk.set_meta("pier_center", Vector2(shore_pos.x, shore_pos.z))


func _find_shore_edge(ox: float, oz: float, hs: float) -> Dictionary:
	# Scan a grid across the chunk to find shore: a point above sea level
	# with water nearby in some direction. Check further out for water
	# since the shore slope can be gradual.
	var grid := 8
	var step: float = (hs * 2.0) / float(grid)
	var dirs: Array[Vector3] = [
		Vector3(-1, 0, 0), Vector3(1, 0, 0),
		Vector3(0, 0, -1), Vector3(0, 0, 1),
	]
	var check_dist: float = PIER_LENGTH * 3.0  # look further for water

	for iz in range(grid + 1):
		for ix in range(grid + 1):
			var sx: float = ox - hs + float(ix) * step
			var sz: float = oz - hs + float(iz) * step

			var h: float = _boundary.get_ground_height(sx, sz)
			if h <= SEA_LEVEL or h > SEA_LEVEL + 30.0:
				continue

			# Found land — check each direction for water
			for d: Vector3 in dirs:
				var water_x: float = sx + d.x * check_dist
				var water_z: float = sz + d.z * check_dist
				var water_h: float = _boundary.get_ground_height(
					water_x, water_z,
				)
				if water_h < SEA_LEVEL:
					return {
						"position": Vector3(sx, h, sz),
						"direction": d,
					}

	return {}


func _build_pier_geometry(
	chunk: Node3D, shore_pos: Vector3, pier_dir: Vector3,
) -> void:
	var deck_y: float = SEA_LEVEL + PIER_HEIGHT

	# Pier body with collision
	var body := StaticBody3D.new()
	body.name = "Pier"
	body.collision_layer = 1  # Ground
	body.collision_mask = 0
	body.add_to_group("Road")

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Cross direction (perpendicular to pier direction)
	var cross := pier_dir.cross(Vector3.UP).normalized()
	var hw := PIER_WIDTH * 0.5

	# Deck quad
	var d0 := shore_pos + cross * hw
	var d1 := shore_pos - cross * hw
	var d2 := shore_pos - cross * hw + pier_dir * PIER_LENGTH
	var d3 := shore_pos + cross * hw + pier_dir * PIER_LENGTH
	d0.y = deck_y
	d1.y = deck_y
	d2.y = deck_y
	d3.y = deck_y

	# Top face
	var n_up := Vector3(0, 1, 0)
	st.set_normal(n_up)
	st.add_vertex(d0)
	st.set_normal(n_up)
	st.add_vertex(d1)
	st.set_normal(n_up)
	st.add_vertex(d2)
	st.set_normal(n_up)
	st.add_vertex(d0)
	st.set_normal(n_up)
	st.add_vertex(d2)
	st.set_normal(n_up)
	st.add_vertex(d3)

	# Bottom face
	var n_down := Vector3(0, -1, 0)
	st.set_normal(n_down)
	st.add_vertex(d0)
	st.set_normal(n_down)
	st.add_vertex(d2)
	st.set_normal(n_down)
	st.add_vertex(d1)
	st.set_normal(n_down)
	st.add_vertex(d0)
	st.set_normal(n_down)
	st.add_vertex(d3)
	st.set_normal(n_down)
	st.add_vertex(d2)

	# Pilings (vertical columns)
	for i in range(PILING_COUNT):
		var t: float = float(i + 1) / float(PILING_COUNT + 1)
		var base: Vector3 = shore_pos.lerp(
			shore_pos + pier_dir * PIER_LENGTH, t
		)
		for side in [-1.0, 1.0]:
			var piling_pos: Vector3 = base + cross * hw * 0.8 * side
			piling_pos.y = SEA_LEVEL - 1.5
			var piling_top: Vector3 = piling_pos
			piling_top.y = deck_y
			_add_piling(st, piling_pos, piling_top)

	var mesh := st.commit()
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.name = "PierMesh"
	mesh_inst.mesh = mesh
	mesh_inst.material_override = _wood_mat
	body.add_child(mesh_inst)

	# Deck collision
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(PIER_WIDTH, 0.15, PIER_LENGTH)
	col.shape = box
	var deck_center := shore_pos + pier_dir * PIER_LENGTH * 0.5
	deck_center.y = deck_y
	col.position = deck_center
	body.add_child(col)

	chunk.add_child(body)


func _add_piling(
	st: SurfaceTool, bottom: Vector3, top: Vector3,
) -> void:
	# Simple box column
	var r := PILING_RADIUS
	var n := Vector3.ZERO  # Let generate_normals handle it
	for dx in [-r, r]:
		for dz in [-r, r]:
			pass  # We'll do a simpler approach

	# Just use a thin box
	var cx := (bottom.x + top.x) * 0.5
	var cz := (bottom.z + top.z) * 0.5
	var cy := (bottom.y + top.y) * 0.5
	var h := top.y - bottom.y
	var hx := PILING_RADIUS
	var hz := PILING_RADIUS

	var v0 := Vector3(cx - hx, bottom.y, cz - hz)
	var v1 := Vector3(cx + hx, bottom.y, cz - hz)
	var v2 := Vector3(cx + hx, top.y, cz - hz)
	var v3 := Vector3(cx - hx, top.y, cz - hz)
	var v4 := Vector3(cx - hx, bottom.y, cz + hz)
	var v5 := Vector3(cx + hx, bottom.y, cz + hz)
	var v6 := Vector3(cx + hx, top.y, cz + hz)
	var v7 := Vector3(cx - hx, top.y, cz + hz)

	# 4 side faces
	st.add_vertex(v0); st.add_vertex(v2); st.add_vertex(v1)
	st.add_vertex(v0); st.add_vertex(v3); st.add_vertex(v2)
	st.add_vertex(v5); st.add_vertex(v6); st.add_vertex(v4)
	st.add_vertex(v4); st.add_vertex(v6); st.add_vertex(v7)
	st.add_vertex(v4); st.add_vertex(v7); st.add_vertex(v0)
	st.add_vertex(v0); st.add_vertex(v7); st.add_vertex(v3)
	st.add_vertex(v1); st.add_vertex(v2); st.add_vertex(v5)
	st.add_vertex(v5); st.add_vertex(v2); st.add_vertex(v6)


func _spawn_boats(
	chunk: Node3D, _tile: Vector2i,
	shore_pos: Vector3, pier_dir: Vector3,
	rng: RandomNumberGenerator,
) -> void:
	var cross := pier_dir.cross(Vector3.UP).normalized()
	var count := rng.randi_range(1, 2)

	for i in range(count):
		var variant: String = BOAT_VARIANTS[rng.randi() % BOAT_VARIANTS.size()]
		var result: Dictionary = _boat_builder.build(variant)

		# Position beyond the pier tip so boats can't get stuck under the dock.
		# PIER_LENGTH + 2.0 gives 2 m clearance past the pier end.
		# Cross offset of PIER_WIDTH * 0.5 + 3.5 keeps boats clear of the
		# pier side and of the shore on either side.
		var side: float = -1.0 if i == 0 else 1.0
		var boat_pos := shore_pos + pier_dir * (PIER_LENGTH + 2.0 + float(i) * 4.0)
		boat_pos += cross * (PIER_WIDTH * 0.5 + 3.5) * side
		boat_pos.y = SEA_LEVEL + 0.3

		var boat := _build_boat_node(result, variant, boat_pos, pier_dir)
		chunk.add_child(boat)


func _build_boat_node(
	mesh_data: Dictionary, variant: String,
	pos: Vector3, facing: Vector3,
) -> RigidBody3D:
	var boat := RigidBody3D.new()
	boat.name = "Boat"
	boat.mass = 800.0
	boat.gravity_scale = 1.0
	boat.collision_layer = 16  # NPC vehicles
	boat.collision_mask = 7    # ground + static + player
	boat.position = pos

	# Bow faces toward water (forward = -Z, so rotate so -Z aligns with facing)
	if facing.length() > 0.1:
		boat.rotation.y = atan2(-facing.x, -facing.z)

	# Collision shape
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = mesh_data["collision_size"]
	col.shape = box
	boat.add_child(col)

	# Body node with meshes
	var body := Node3D.new()
	body.name = "Body"
	var BoatBodyScript: GDScript = preload(
		"res://scenes/vehicles/boat_body_init.gd"
	)
	body.set_script(BoatBodyScript)
	body.set("variant", variant)

	var hull := MeshInstance3D.new()
	hull.name = "Hull"
	body.add_child(hull)
	var cabin := MeshInstance3D.new()
	cabin.name = "Cabin"
	body.add_child(cabin)
	var windshield := MeshInstance3D.new()
	windshield.name = "Windshield"
	body.add_child(windshield)
	boat.add_child(body)

	# Outboard engine — rotatable pivot at stern
	var stern_z: float = mesh_data.get("stern_z", 2.5)
	boat.set_meta("stern_z", stern_z)
	var engine_pivot := Node3D.new()
	engine_pivot.name = "EnginePivot"
	engine_pivot.position = Vector3(0.0, 0.0, stern_z)
	var engine_mesh := MeshInstance3D.new()
	engine_mesh.name = "EngineMesh"
	engine_mesh.mesh = mesh_data.get("engine")
	var engine_mat := StandardMaterial3D.new()
	engine_mat.albedo_color = Color(0.2, 0.2, 0.2)  # dark grey metal
	engine_mat.metallic = 0.6
	engine_mat.roughness = 0.4
	engine_mesh.material_override = engine_mat
	engine_pivot.add_child(engine_mesh)
	boat.add_child(engine_pivot)

	# Boat controller
	var BoatCtrlScript: GDScript = preload(
		"res://scenes/vehicles/boat_controller.gd"
	)
	var ctrl := Node.new()
	ctrl.name = "BoatController"
	ctrl.set_script(BoatCtrlScript)
	boat.add_child(ctrl)

	# Vehicle camera (reuse existing scene)
	# VehicleCamera created lazily when player boards (driving.gd)

	# Interaction zone
	var zone := Area3D.new()
	zone.name = "InteractionZone"
	zone.add_to_group("vehicle_interaction")
	zone.collision_layer = 256  # Interaction zones
	zone.collision_mask = 4     # Player
	var zone_col := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 4.0
	zone_col.shape = sphere
	zone.add_child(zone_col)
	boat.add_child(zone)

	# Door marker (port side at deck level)
	var marker := Marker3D.new()
	marker.name = "DoorMarker"
	marker.position = Vector3(-2.0, 0.5, 0.0)
	boat.add_child(marker)

	# Boat audio
	var BoatAudioScript = load(
		"res://scenes/vehicles/boat_audio.gd"
	)
	if BoatAudioScript:
		var audio := AudioStreamPlayer3D.new()
		audio.name = "BoatAudio"
		audio.set_script(BoatAudioScript)
		boat.add_child(audio)

	# Wake effects
	var BoatWakeScript = load(
		"res://scenes/vehicles/boat_wake.gd"
	)
	if BoatWakeScript:
		var wake := Node3D.new()
		wake.name = "BoatWake"
		wake.set_script(BoatWakeScript)
		boat.add_child(wake)

	return boat
