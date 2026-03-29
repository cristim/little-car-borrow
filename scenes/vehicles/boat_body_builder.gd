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

	var engine := _build_engine(profiles)
	# Stern Z for engine placement
	var stern_z: float = float(profiles[profiles.size() - 1]["z"])

	return {
		"hull": hull,
		"cabin": cabin,
		"windshield": windshield,
		"engine": engine,
		"waterline_cap": _build_waterline_cap(profiles),
		"stern_z": stern_z,
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

	# Loft between adjacent rings — exterior hull
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
		# Deck removed — hull is open-top (hollow)

	# Interior walls (reversed winding so faces point inward)
	for i in range(rings.size() - 1):
		var ra: PackedVector3Array = rings[i]
		var rb: PackedVector3Array = rings[i + 1]
		# Port interior (gunwale -> waterline, reversed)
		_add_loft_quad(st, rb[2], ra[2], rb[1], ra[1])
		# Starboard interior (gunwale -> waterline, reversed)
		_add_loft_quad(st, ra[3], rb[3], ra[4], rb[4])

	# Interior floor plane raised above waterline so boat doesn't look flooded
	var floor_y := 0.12
	for i in range(rings.size() - 1):
		var pa: Dictionary = profiles[i]
		var pb: Dictionary = profiles[i + 1]
		var za: float = pa["z"]
		var zb: float = pb["z"]
		var fhw_a: float = float(pa["hw"]) * 0.85
		var fhw_b: float = float(pb["hw"]) * 0.85
		_add_quad(
			st,
			Vector3(-fhw_a, floor_y, za),
			Vector3(fhw_a, floor_y, za),
			Vector3(fhw_b, floor_y, zb),
			Vector3(-fhw_b, floor_y, zb),
		)

	# Bow cap (exterior)
	var bow: PackedVector3Array = rings[0]
	_add_fan(st, bow)
	# Stern cap (exterior)
	var stern: PackedVector3Array = rings[rings.size() - 1]
	_add_fan_reversed(st, stern)

	# Interior stern wall (faces inward toward bow)
	var s_hw: float = float(profiles[profiles.size() - 1]["hw"]) * 0.95
	var s_fb: float = float(profiles[profiles.size() - 1]["fb"])
	var s_z: float = float(profiles[profiles.size() - 1]["z"])
	_add_quad(
		st,
		Vector3(s_hw, floor_y, s_z),
		Vector3(-s_hw, floor_y, s_z),
		Vector3(-s_hw, s_fb, s_z),
		Vector3(s_hw, s_fb, s_z),
	)
	# Interior bow wall
	var b_hw: float = float(profiles[0]["hw"]) * 0.95
	var b_fb: float = float(profiles[0]["fb"])
	var b_z: float = float(profiles[0]["z"])
	_add_quad(
		st,
		Vector3(-b_hw, floor_y, b_z),
		Vector3(b_hw, floor_y, b_z),
		Vector3(b_hw, b_fb, b_z),
		Vector3(-b_hw, b_fb, b_z),
	)

	# Seat bench near stern (close to engine tiller)
	var last_z: float = float(profiles[profiles.size() - 1]["z"])
	var seat_x: float = 0.40
	var seat_z_front: float = last_z - 1.0
	var seat_z_rear: float = last_z - 0.6
	var seat_y_bottom: float = 0.05
	var seat_y_top: float = 0.30
	# Front face
	_add_quad(
		st,
		Vector3(-seat_x, seat_y_bottom, seat_z_front),
		Vector3(seat_x, seat_y_bottom, seat_z_front),
		Vector3(seat_x, seat_y_top, seat_z_front),
		Vector3(-seat_x, seat_y_top, seat_z_front),
	)
	# Rear face
	_add_quad(
		st,
		Vector3(seat_x, seat_y_bottom, seat_z_rear),
		Vector3(-seat_x, seat_y_bottom, seat_z_rear),
		Vector3(-seat_x, seat_y_top, seat_z_rear),
		Vector3(seat_x, seat_y_top, seat_z_rear),
	)
	# Left face
	_add_quad(
		st,
		Vector3(-seat_x, seat_y_bottom, seat_z_rear),
		Vector3(-seat_x, seat_y_bottom, seat_z_front),
		Vector3(-seat_x, seat_y_top, seat_z_front),
		Vector3(-seat_x, seat_y_top, seat_z_rear),
	)
	# Right face
	_add_quad(
		st,
		Vector3(seat_x, seat_y_bottom, seat_z_front),
		Vector3(seat_x, seat_y_bottom, seat_z_rear),
		Vector3(seat_x, seat_y_top, seat_z_rear),
		Vector3(seat_x, seat_y_top, seat_z_front),
	)
	# Top face
	_add_quad(
		st,
		Vector3(-seat_x, seat_y_top, seat_z_front),
		Vector3(seat_x, seat_y_top, seat_z_front),
		Vector3(seat_x, seat_y_top, seat_z_rear),
		Vector3(-seat_x, seat_y_top, seat_z_rear),
	)

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


## Flat opaque plane at y=0.05, spanning the hull cross-section.
## Occludes the water surface mesh from appearing inside the hull.
func _build_waterline_cap(profiles: Array) -> ArrayMesh:
	var cap_y := 0.05  # just above local waterline (y=0), beats wave crests
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(profiles.size() - 1):
		var pa: Dictionary = profiles[i]
		var pb: Dictionary = profiles[i + 1]
		var za: float = float(pa["z"])
		var zb: float = float(pb["z"])
		var hw_a: float = float(pa["hw"]) * 0.95
		var hw_b: float = float(pb["hw"]) * 0.95
		_add_quad(
			st,
			Vector3(-hw_a, cap_y, za), Vector3(hw_a, cap_y, za),
			Vector3(hw_b, cap_y, zb), Vector3(-hw_b, cap_y, zb),
		)
	st.generate_normals()
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


## Build outboard motor mesh: cowling (main body) + shaft + tiller handle.
## Origin at mount point (stern transom, waterline height) so the engine
## node can be rotated around Y for steering.
func _build_engine(_profiles: Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Motor cowling (the big part that sits above waterline at stern)
	var cw := 0.15  # half width
	var cd := 0.12  # half depth
	var ch := 0.35  # height
	var cy := 0.0   # bottom at mount point
	_add_box(st, Vector3(0.0, cy + ch * 0.5, 0.15), Vector3(cw * 2, ch, cd * 2))

	# Shaft going down into water
	var sw := 0.04
	var sh := 0.5
	_add_box(st, Vector3(0.0, -sh * 0.5, 0.15), Vector3(sw * 2, sh, sw * 2))

	# Propeller housing at bottom of shaft
	var pw := 0.08
	var ph := 0.1
	_add_box(st, Vector3(0.0, -sh - ph * 0.5, 0.15), Vector3(pw * 2, ph, pw * 2 + 0.04))

	# Tiller handle extending forward (the part the player grabs)
	var th := 0.03  # half height
	var tl := 0.6   # length
	_add_box(
		st,
		Vector3(0.0, cy + ch * 0.7, 0.15 - cd - tl * 0.5),
		Vector3(th * 2, th * 2, tl),
	)

	st.generate_normals()
	return st.commit()


func _add_box(st: SurfaceTool, center: Vector3, size: Vector3) -> void:
	var hx: float = size.x * 0.5
	var hy: float = size.y * 0.5
	var hz: float = size.z * 0.5
	var cx: float = center.x
	var cy: float = center.y
	var cz: float = center.z
	# 6 faces
	# Front (-Z)
	_add_quad(
		st,
		Vector3(cx - hx, cy - hy, cz - hz),
		Vector3(cx + hx, cy - hy, cz - hz),
		Vector3(cx + hx, cy + hy, cz - hz),
		Vector3(cx - hx, cy + hy, cz - hz),
	)
	# Back (+Z)
	_add_quad(
		st,
		Vector3(cx + hx, cy - hy, cz + hz),
		Vector3(cx - hx, cy - hy, cz + hz),
		Vector3(cx - hx, cy + hy, cz + hz),
		Vector3(cx + hx, cy + hy, cz + hz),
	)
	# Left (-X)
	_add_quad(
		st,
		Vector3(cx - hx, cy - hy, cz + hz),
		Vector3(cx - hx, cy - hy, cz - hz),
		Vector3(cx - hx, cy + hy, cz - hz),
		Vector3(cx - hx, cy + hy, cz + hz),
	)
	# Right (+X)
	_add_quad(
		st,
		Vector3(cx + hx, cy - hy, cz - hz),
		Vector3(cx + hx, cy - hy, cz + hz),
		Vector3(cx + hx, cy + hy, cz + hz),
		Vector3(cx + hx, cy + hy, cz - hz),
	)
	# Top (+Y)
	_add_quad(
		st,
		Vector3(cx - hx, cy + hy, cz - hz),
		Vector3(cx + hx, cy + hy, cz - hz),
		Vector3(cx + hx, cy + hy, cz + hz),
		Vector3(cx - hx, cy + hy, cz + hz),
	)
	# Bottom (-Y)
	_add_quad(
		st,
		Vector3(cx + hx, cy - hy, cz - hz),
		Vector3(cx - hx, cy - hy, cz - hz),
		Vector3(cx - hx, cy - hy, cz + hz),
		Vector3(cx + hx, cy - hy, cz + hz),
	)
