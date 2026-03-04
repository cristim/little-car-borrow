extends RefCounted
## Generates curved car body meshes by lofting between cross-section profiles.
## Each profile is a 12-vertex rounded rectangle that varies along the Z axis
## to create hood slopes, cabin shapes, and trunk curves.

# Sedan base profiles: z, half_width, y_bottom, y_top, corner_radius, top_inset
const BASE_PROFILES := [
	{"z": -2.0, "hw": 0.70, "yb": -0.35, "yt": 0.00, "r": 0.25, "inset": 0.0},
	{"z": -1.7, "hw": 0.85, "yb": -0.35, "yt": 0.05, "r": 0.15, "inset": 0.0},
	{"z": -1.2, "hw": 0.90, "yb": -0.35, "yt": 0.10, "r": 0.10, "inset": 0.0},
	{"z": -0.7, "hw": 0.90, "yb": -0.35, "yt": 0.15, "r": 0.08, "inset": 0.0},
	{"z": -0.3, "hw": 0.75, "yb": -0.35, "yt": 0.50, "r": 0.06, "inset": 0.10},
	{"z": 0.2, "hw": 0.75, "yb": -0.35, "yt": 0.50, "r": 0.06, "inset": 0.10},
	{"z": 0.8, "hw": 0.75, "yb": -0.35, "yt": 0.50, "r": 0.06, "inset": 0.10},
	{"z": 1.1, "hw": 0.80, "yb": -0.35, "yt": 0.45, "r": 0.06, "inset": 0.05},
	{"z": 1.5, "hw": 0.85, "yb": -0.35, "yt": 0.10, "r": 0.10, "inset": 0.0},
	{"z": 2.0, "hw": 0.70, "yb": -0.35, "yt": -0.05, "r": 0.20, "inset": 0.0},
]

# Variant overrides applied to base profiles
const VARIANT_OVERRIDES := {
	"sedan": {},
	"sports": {
		"height_mult": 0.80,
		"width_mult": 1.05,
		"cabin_height_mult": 0.75,
		"cabin_inset_add": 0.05,
		"ground_offset": 0.0,
	},
	"suv": {
		"height_mult": 1.15,
		"width_mult": 1.10,
		"cabin_height_mult": 1.30,
		"cabin_inset_add": -0.03,
		"ground_offset": 0.05,
	},
	"hatchback": {
		"length_mult": 0.88,
		"rear_slope": true,
	},
	"van": {
		"height_mult": 1.30,
		"cabin_height_mult": 1.50,
		"cabin_start_z": -1.0,
		"cabin_inset_add": -0.05,
	},
	"pickup": {
		"length_mult": 1.20,
		"cabin_end_z": 0.0,
		"bed_start_z": 0.2,
	},
}

# Ring vertex count: 3 per corner (4 corners) = 12 vertices
const RING_VERTS := 12

# Edge indices to skip when lofting, creating gaps for window glass.
# Edge i connects ring vertex i to (i+1)%12.
# Side windows: skip upper-left (1) and upper-right (8) side edges.
const SIDE_WINDOW_EDGES := [1, 8]
# Windshield/rear window: skip the top row edges (corners + top surface).
const GLASS_TOP_EDGES := [0, 9, 10, 11]


func build_body(variant_name: String) -> ArrayMesh:
	var profiles := _generate_profiles(variant_name)
	var rings: Array[PackedVector3Array] = []
	for p in profiles:
		rings.append(_profile_to_ring(p))

	# Track which profiles are cabin profiles (have window inset)
	var cabin_flags: Array[bool] = []
	for p in profiles:
		cabin_flags.append(float(p.inset) > 0.01)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Loft between adjacent rings, skipping edges where windows go
	for i in range(rings.size() - 1):
		var skip: Array = []
		var a_cab: bool = cabin_flags[i]
		var b_cab: bool = cabin_flags[i + 1]
		if a_cab and b_cab:
			# Between two cabin profiles: leave side window gaps
			skip = SIDE_WINDOW_EDGES
		elif a_cab != b_cab:
			# Hood-to-cabin or cabin-to-trunk: leave windshield/rear gap
			skip = GLASS_TOP_EDGES

		_loft(st, rings[i], rings[i + 1], skip)

	# Cap front and rear
	_cap(st, rings[0], true)
	_cap(st, rings[rings.size() - 1], false)

	st.generate_normals()
	return st.commit()


func build_windows(variant_name: String) -> Dictionary:
	var profiles := _generate_profiles(variant_name)
	var result := {}

	# Find cabin profiles (those with top_inset > 0)
	var cabin_indices: Array[int] = []
	for i in range(profiles.size()):
		if profiles[i].inset > 0.01:
			cabin_indices.append(i)

	if cabin_indices.is_empty():
		return result

	var first_cabin: int = cabin_indices[0]
	var last_cabin: int = cabin_indices[cabin_indices.size() - 1]

	# Windshield: quad between profile just before cabin and first cabin profile
	if first_cabin > 0:
		result["Windshield"] = _build_window_quad(
			profiles[first_cabin - 1], profiles[first_cabin], true
		)

	# Rear window: quad between last cabin profile and profile after
	if last_cabin < profiles.size() - 1:
		result["RearWindow"] = _build_window_quad(
			profiles[last_cabin], profiles[last_cabin + 1], false
		)

	# Side windows: strip along cabin profiles
	if cabin_indices.size() >= 2:
		result["LeftWindow"] = _build_side_window(profiles, cabin_indices, true)
		result["RightWindow"] = _build_side_window(profiles, cabin_indices, false)

	return result


func _generate_profiles(variant_name: String) -> Array[Dictionary]:
	var overrides: Dictionary = VARIANT_OVERRIDES.get(variant_name, {})
	var result: Array[Dictionary] = []

	var length_mult: float = overrides.get("length_mult", 1.0)
	var height_mult: float = overrides.get("height_mult", 1.0)
	var width_mult: float = overrides.get("width_mult", 1.0)
	var cabin_height_mult: float = overrides.get("cabin_height_mult", 1.0)
	var cabin_inset_add: float = overrides.get("cabin_inset_add", 0.0)
	var ground_offset: float = overrides.get("ground_offset", 0.0)
	var cabin_start_z: float = overrides.get("cabin_start_z", -99.0)
	var cabin_end_z: float = overrides.get("cabin_end_z", 99.0)
	var rear_slope: bool = overrides.get("rear_slope", false)
	var bed_start_z: float = overrides.get("bed_start_z", 99.0)

	for base in BASE_PROFILES:
		var p := {}
		p.z = float(base.z) * length_mult
		p.hw = float(base.hw) * width_mult
		p.yb = float(base.yb) * height_mult + ground_offset
		p.r = float(base.r)

		var is_cabin: bool = float(base.inset) > 0.01
		if is_cabin:
			# Check if this cabin profile is within variant cabin range
			if float(base.z) < cabin_start_z or float(base.z) > cabin_end_z:
				# Outside cabin range — collapse to body height
				p.yt = float(base.yt) * height_mult * 0.3
				p.inset = 0.0
			else:
				p.yt = float(base.yt) * height_mult * cabin_height_mult
				p.inset = float(base.inset) + cabin_inset_add
		else:
			p.yt = float(base.yt) * height_mult
			p.inset = float(base.inset)

		# Pickup bed: lower the body top behind cabin
		if float(base.z) >= bed_start_z and not is_cabin:
			p.yt = maxf(p.yt, float(base.yt) * height_mult * 0.5)
			p.yb = float(base.yb) * height_mult + ground_offset

		# Hatchback rear slope: steepen the transition after cabin
		if rear_slope and float(base.z) > 0.9:
			var t: float = clampf((float(base.z) - 0.9) / 1.1, 0.0, 1.0)
			p.yt = lerpf(p.yt, float(base.yb) * height_mult + 0.05, t * 0.7)

		result.append(p)

	return result


func _profile_to_ring(profile: Dictionary) -> PackedVector3Array:
	var ring := PackedVector3Array()
	var z: float = profile.z
	var hw: float = profile.hw
	var yb: float = profile.yb
	var yt: float = profile.yt
	var r: float = profile.r
	var inset: float = profile.inset

	var top_hw: float = hw - inset

	# 12 vertices: 3 per corner, going clockwise when viewed from front
	# Top-left corner
	ring.append(Vector3(-top_hw + r, yt, z))
	ring.append(Vector3(-top_hw, yt - r, z))
	ring.append(Vector3(-top_hw, (yt + yb) * 0.5, z))

	# Bottom-left corner
	ring.append(Vector3(-hw, yb + r, z))
	ring.append(Vector3(-hw + r, yb, z))
	ring.append(Vector3(0.0, yb, z))

	# Bottom-right corner
	ring.append(Vector3(hw - r, yb, z))
	ring.append(Vector3(hw, yb + r, z))
	ring.append(Vector3(hw, (yt + yb) * 0.5, z))

	# Top-right corner
	ring.append(Vector3(top_hw, yt - r, z))
	ring.append(Vector3(top_hw - r, yt, z))
	ring.append(Vector3(0.0, yt, z))

	return ring


func _loft(
	st: SurfaceTool,
	ring_a: PackedVector3Array,
	ring_b: PackedVector3Array,
	skip_edges: Array = [],
) -> void:
	var count: int = ring_a.size()
	for i in range(count):
		if skip_edges.has(i):
			continue
		var next_i: int = (i + 1) % count
		# Two triangles per quad
		st.add_vertex(ring_a[i])
		st.add_vertex(ring_b[i])
		st.add_vertex(ring_a[next_i])

		st.add_vertex(ring_a[next_i])
		st.add_vertex(ring_b[i])
		st.add_vertex(ring_b[next_i])


func _cap(st: SurfaceTool, ring: PackedVector3Array, front: bool) -> void:
	# Fan triangulation from center
	var center := Vector3.ZERO
	for v in ring:
		center += v
	center /= float(ring.size())

	var count: int = ring.size()
	for i in range(count):
		var next_i: int = (i + 1) % count
		if front:
			# Front cap faces -Z direction
			st.add_vertex(center)
			st.add_vertex(ring[next_i])
			st.add_vertex(ring[i])
		else:
			# Rear cap faces +Z direction
			st.add_vertex(center)
			st.add_vertex(ring[i])
			st.add_vertex(ring[next_i])


func _build_window_quad(
	profile_a: Dictionary, profile_b: Dictionary, is_front: bool
) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Window spans from top of lower profile to top of upper profile
	var z_a: float = profile_a.z
	var z_b: float = profile_b.z
	var hw_a: float = profile_a.hw - profile_a.get("inset", 0.0)
	var hw_b: float = profile_b.hw - profile_b.get("inset", 0.0)
	var yt_a: float = profile_a.yt
	var yt_b: float = profile_b.yt

	# Use the lower top as bottom edge of the glass
	var y_bottom: float = minf(yt_a, yt_b) * 0.5
	var hw: float = minf(hw_a, hw_b) * 0.85

	if is_front:
		# Windshield: angled quad from hood to cabin top
		st.add_vertex(Vector3(-hw, y_bottom, z_a))
		st.add_vertex(Vector3(hw, y_bottom, z_a))
		st.add_vertex(Vector3(-hw, yt_b, z_b))

		st.add_vertex(Vector3(hw, y_bottom, z_a))
		st.add_vertex(Vector3(hw, yt_b, z_b))
		st.add_vertex(Vector3(-hw, yt_b, z_b))
	else:
		# Rear window: angled quad from cabin top down to trunk
		st.add_vertex(Vector3(-hw, yt_a, z_a))
		st.add_vertex(Vector3(hw, yt_a, z_a))
		st.add_vertex(Vector3(-hw, y_bottom, z_b))

		st.add_vertex(Vector3(hw, yt_a, z_a))
		st.add_vertex(Vector3(hw, y_bottom, z_b))
		st.add_vertex(Vector3(-hw, y_bottom, z_b))

	st.generate_normals()
	var mesh := st.commit()
	return mesh


func _build_side_window(
	profiles: Array[Dictionary], cabin_indices: Array[int], is_left: bool
) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for idx in range(cabin_indices.size() - 1):
		var i_a: int = cabin_indices[idx]
		var i_b: int = cabin_indices[idx + 1]
		var p_a: Dictionary = profiles[i_a]
		var p_b: Dictionary = profiles[i_b]

		var x_sign: float = -1.0 if is_left else 1.0
		var hw_a: float = float(p_a.hw) - float(p_a.inset)
		var hw_b: float = float(p_b.hw) - float(p_b.inset)

		# Window strip: from mid-height to top, at the cabin edge
		var y_mid_a: float = (float(p_a.yt) + float(p_a.yb)) * 0.5 + 0.1
		var y_mid_b: float = (float(p_b.yt) + float(p_b.yb)) * 0.5 + 0.1
		var y_top_a: float = float(p_a.yt) - 0.03
		var y_top_b: float = float(p_b.yt) - 0.03

		var bl := Vector3(x_sign * hw_a, y_mid_a, float(p_a.z))
		var tl := Vector3(x_sign * hw_a, y_top_a, float(p_a.z))
		var br := Vector3(x_sign * hw_b, y_mid_b, float(p_b.z))
		var tr := Vector3(x_sign * hw_b, y_top_b, float(p_b.z))

		if is_left:
			# Face outward (-X)
			st.add_vertex(bl)
			st.add_vertex(br)
			st.add_vertex(tl)

			st.add_vertex(tl)
			st.add_vertex(br)
			st.add_vertex(tr)
		else:
			# Face outward (+X)
			st.add_vertex(bl)
			st.add_vertex(tl)
			st.add_vertex(br)

			st.add_vertex(tl)
			st.add_vertex(tr)
			st.add_vertex(br)

	st.generate_normals()
	return st.commit()
