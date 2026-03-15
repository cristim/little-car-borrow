extends RefCounted
## Generates procedural boat hull, cabin, and windshield meshes
## by lofting V-shaped cross-section profiles along the Z axis.

# Variant profiles: z, half_width, draft (below waterline), freeboard (above)
const VARIANTS := {
	"speedboat": {
		"profiles": [
			{"z": -3.0, "hw": 0.2, "draft": 0.15, "fb": 0.10},
			{"z": -2.5, "hw": 0.5, "draft": 0.25, "fb": 0.30},
			{"z": -1.5, "hw": 0.8, "draft": 0.30, "fb": 0.45},
			{"z": -0.5, "hw": 0.9, "draft": 0.30, "fb": 0.50},
			{"z": 0.5, "hw": 0.95, "draft": 0.30, "fb": 0.50},
			{"z": 1.5, "hw": 0.95, "draft": 0.28, "fb": 0.45},
			{"z": 2.5, "hw": 0.85, "draft": 0.25, "fb": 0.40},
			{"z": 3.0, "hw": 0.70, "draft": 0.20, "fb": 0.35},
		],
		"cabin_z": [-1.0, 0.5],
		"cabin_height": 0.6,
		"collision_size": Vector3(2.0, 0.8, 6.0),
	},
	"fishing": {
		"profiles": [
			{"z": -3.5, "hw": 0.3, "draft": 0.20, "fb": 0.15},
			{"z": -2.8, "hw": 0.7, "draft": 0.30, "fb": 0.45},
			{"z": -1.5, "hw": 1.0, "draft": 0.35, "fb": 0.60},
			{"z": -0.5, "hw": 1.15, "draft": 0.35, "fb": 0.65},
			{"z": 0.5, "hw": 1.20, "draft": 0.35, "fb": 0.65},
			{"z": 1.5, "hw": 1.15, "draft": 0.32, "fb": 0.60},
			{"z": 2.5, "hw": 1.05, "draft": 0.28, "fb": 0.50},
			{"z": 3.5, "hw": 0.85, "draft": 0.22, "fb": 0.40},
		],
		"cabin_z": [-0.5, 0.8],
		"cabin_height": 0.9,
		"collision_size": Vector3(2.5, 1.0, 7.0),
	},
	"runabout": {
		"profiles": [
			{"z": -2.5, "hw": 0.2, "draft": 0.15, "fb": 0.10},
			{"z": -2.0, "hw": 0.5, "draft": 0.22, "fb": 0.30},
			{"z": -1.0, "hw": 0.75, "draft": 0.28, "fb": 0.45},
			{"z": 0.0, "hw": 0.85, "draft": 0.28, "fb": 0.48},
			{"z": 1.0, "hw": 0.85, "draft": 0.26, "fb": 0.45},
			{"z": 2.0, "hw": 0.75, "draft": 0.22, "fb": 0.38},
			{"z": 2.5, "hw": 0.60, "draft": 0.18, "fb": 0.30},
		],
		"cabin_z": [-0.5, 0.5],
		"cabin_height": 0.55,
		"collision_size": Vector3(1.8, 0.7, 5.0),
	},
}


func build(variant: String) -> Dictionary:
	var data: Dictionary = VARIANTS.get(variant, VARIANTS["speedboat"])
	var profiles: Array = data["profiles"]

	var hull := _build_hull(profiles)
	var cabin := _build_cabin(profiles, data)
	var windshield := _build_windshield(data)
	var col_size: Vector3 = data["collision_size"]

	return {
		"hull": hull,
		"cabin": cabin,
		"windshield": windshield,
		"collision_size": col_size,
	}


func _build_hull(profiles: Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Build rings: each profile -> 5 verts (keel, port waterline, port gunwale,
	# starboard gunwale, starboard waterline)
	var rings: Array[PackedVector3Array] = []
	for p in profiles:
		var ring := PackedVector3Array()
		var z: float = p["z"]
		var hw: float = p["hw"]
		var draft: float = p["draft"]
		var fb: float = p["fb"]
		# Keel (bottom center)
		ring.append(Vector3(0.0, -draft, z))
		# Port waterline
		ring.append(Vector3(-hw, 0.0, z))
		# Port gunwale
		ring.append(Vector3(-hw * 0.95, fb, z))
		# Starboard gunwale
		ring.append(Vector3(hw * 0.95, fb, z))
		# Starboard waterline
		ring.append(Vector3(hw, 0.0, z))
		rings.append(ring)

	# Loft between adjacent rings
	for i in range(rings.size() - 1):
		var ra: PackedVector3Array = rings[i]
		var rb: PackedVector3Array = rings[i + 1]
		# Port bottom (keel -> port waterline)
		_add_loft_quad(st, ra[0], ra[1], rb[0], rb[1])
		# Port side (port waterline -> port gunwale)
		_add_loft_quad(st, ra[1], ra[2], rb[1], rb[2])
		# Starboard side (starboard gunwale -> starboard waterline)
		_add_loft_quad(st, ra[3], ra[4], rb[3], rb[4])
		# Starboard bottom (starboard waterline -> keel)
		_add_loft_quad(st, ra[4], ra[0], rb[4], rb[0])
		# Deck (port gunwale -> starboard gunwale)
		_add_loft_quad(st, ra[2], ra[3], rb[2], rb[3])

	# Bow cap
	var bow: PackedVector3Array = rings[0]
	_add_fan(st, bow)
	# Stern cap (reversed winding)
	var stern: PackedVector3Array = rings[rings.size() - 1]
	_add_fan_reversed(st, stern)

	st.generate_normals()
	return st.commit()


func _build_cabin(profiles: Array, data: Dictionary) -> ArrayMesh:
	var cabin_z: Array = data["cabin_z"]
	var cabin_h: float = data["cabin_height"]
	var z_front: float = cabin_z[0]
	var z_rear: float = cabin_z[1]

	# Find deck height and width at cabin position
	var deck_h := 0.0
	var deck_hw := 0.0
	for p in profiles:
		if float(p["z"]) >= z_front and float(p["z"]) <= z_rear:
			deck_h = maxf(deck_h, float(p["fb"]))
			deck_hw = maxf(deck_hw, float(p["hw"]))

	var cab_hw: float = deck_hw * 0.6
	var cab_bottom: float = deck_h
	var cab_top: float = deck_h + cabin_h

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Front face
	_add_quad(
		st,
		Vector3(-cab_hw, cab_bottom, z_front),
		Vector3(cab_hw, cab_bottom, z_front),
		Vector3(cab_hw, cab_top, z_front),
		Vector3(-cab_hw, cab_top, z_front),
	)
	# Rear face
	_add_quad(
		st,
		Vector3(cab_hw, cab_bottom, z_rear),
		Vector3(-cab_hw, cab_bottom, z_rear),
		Vector3(-cab_hw, cab_top, z_rear),
		Vector3(cab_hw, cab_top, z_rear),
	)
	# Left face
	_add_quad(
		st,
		Vector3(-cab_hw, cab_bottom, z_rear),
		Vector3(-cab_hw, cab_bottom, z_front),
		Vector3(-cab_hw, cab_top, z_front),
		Vector3(-cab_hw, cab_top, z_rear),
	)
	# Right face
	_add_quad(
		st,
		Vector3(cab_hw, cab_bottom, z_front),
		Vector3(cab_hw, cab_bottom, z_rear),
		Vector3(cab_hw, cab_top, z_rear),
		Vector3(cab_hw, cab_top, z_front),
	)
	# Top face
	_add_quad(
		st,
		Vector3(-cab_hw, cab_top, z_front),
		Vector3(cab_hw, cab_top, z_front),
		Vector3(cab_hw, cab_top, z_rear),
		Vector3(-cab_hw, cab_top, z_rear),
	)

	return st.commit()


func _build_windshield(data: Dictionary) -> ArrayMesh:
	var cabin_z: Array = data["cabin_z"]
	var cabin_h: float = data["cabin_height"]
	var z_front: float = cabin_z[0]

	# Match cabin dimensions
	var deck_h: float = 0.5  # approximate
	var deck_hw: float = 0.8
	for p in data["profiles"]:
		if float(p["z"]) >= z_front:
			deck_h = maxf(deck_h, float(p["fb"]))
			deck_hw = maxf(deck_hw, float(p["hw"]))
			break

	var cab_hw: float = deck_hw * 0.6
	var cab_bottom: float = deck_h
	var cab_top: float = deck_h + cabin_h

	# Windshield: angled quad in front of cabin
	var ws_z: float = z_front - 0.02
	var ws_bottom: float = cab_bottom + cabin_h * 0.35
	var ws_top: float = cab_top

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_quad(
		st,
		Vector3(-cab_hw, ws_bottom, ws_z),
		Vector3(cab_hw, ws_bottom, ws_z),
		Vector3(cab_hw, ws_top, ws_z),
		Vector3(-cab_hw, ws_top, ws_z),
	)
	return st.commit()


func _add_loft_quad(
	st: SurfaceTool,
	a0: Vector3, a1: Vector3, b0: Vector3, b1: Vector3,
) -> void:
	st.add_vertex(a0)
	st.add_vertex(a1)
	st.add_vertex(b0)
	st.add_vertex(a1)
	st.add_vertex(b1)
	st.add_vertex(b0)


func _add_quad(
	st: SurfaceTool, v0: Vector3, v1: Vector3, v2: Vector3, v3: Vector3,
) -> void:
	var n: Vector3 = (v1 - v0).cross(v2 - v0).normalized()
	st.set_normal(n)
	st.add_vertex(v0)
	st.set_normal(n)
	st.add_vertex(v1)
	st.set_normal(n)
	st.add_vertex(v2)
	st.set_normal(n)
	st.add_vertex(v0)
	st.set_normal(n)
	st.add_vertex(v2)
	st.set_normal(n)
	st.add_vertex(v3)


func _add_fan(st: SurfaceTool, ring: PackedVector3Array) -> void:
	var center := Vector3.ZERO
	for v in ring:
		center += v
	center /= float(ring.size())
	for i in range(ring.size()):
		var next: int = (i + 1) % ring.size()
		st.add_vertex(center)
		st.add_vertex(ring[i])
		st.add_vertex(ring[next])


func _add_fan_reversed(st: SurfaceTool, ring: PackedVector3Array) -> void:
	var center := Vector3.ZERO
	for v in ring:
		center += v
	center /= float(ring.size())
	for i in range(ring.size()):
		var next: int = (i + 1) % ring.size()
		st.add_vertex(center)
		st.add_vertex(ring[next])
		st.add_vertex(ring[i])
