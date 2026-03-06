extends RefCounted
## Generates car body meshes by lofting between cross-section profiles.
## Each profile is a 12-vertex ring that varies along the Z axis
## to create hood slopes, cabin shapes, and trunk curves.

# Sedan base profiles: z, half_width, y_bottom, y_top, top_inset
const BASE_PROFILES := [
	{"z": -2.0, "hw": 0.70, "yb": -0.35, "yt": 0.00, "inset": 0.0},
	{"z": -1.7, "hw": 0.85, "yb": -0.35, "yt": 0.05, "inset": 0.0},
	{"z": -1.2, "hw": 0.90, "yb": -0.35, "yt": 0.10, "inset": 0.0},
	{"z": -0.7, "hw": 0.90, "yb": -0.35, "yt": 0.15, "inset": 0.0},
	{"z": -0.3, "hw": 0.75, "yb": -0.35, "yt": 0.50, "inset": 0.10},
	{"z": 0.2, "hw": 0.75, "yb": -0.35, "yt": 0.50, "inset": 0.10},
	{"z": 0.8, "hw": 0.75, "yb": -0.35, "yt": 0.50, "inset": 0.10},
	{"z": 1.1, "hw": 0.80, "yb": -0.35, "yt": 0.45, "inset": 0.05},
	{"z": 1.5, "hw": 0.85, "yb": -0.35, "yt": 0.10, "inset": 0.0},
	{"z": 2.0, "hw": 0.70, "yb": -0.35, "yt": -0.05, "inset": 0.0},
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

# Ring vertex count
const RING_VERTS := 12

# Edge i connects V[i] to V[(i+1)%12].
# Side windows: edges 3 (right shoulder->sill) and 10 (left sill->shoulder).
const SIDE_WINDOW_EDGES := [3, 10]
# Windshield/rear window: edges 0 and 1 (roof top edges).
const GLASS_TOP_EDGES := [0, 1]

# Body panel edges to skip for door openings:
# Edge 4: right sill->right lower (V4->V5)
# Edge 5: right lower->right bottom (V5->V6)
# Edge 8: left bottom->left lower (V8->V9)
# Edge 9: left lower->left sill (V9->V10)
const DOOR_BODY_EDGES := [4, 5, 8, 9]

# Door frame inset depth
const FRAME_DEPTH := 0.04


func build_body(variant_name: String) -> ArrayMesh:
	var profiles := _generate_profiles(variant_name)
	var rings: Array[PackedVector3Array] = []
	for p in profiles:
		rings.append(_profile_to_ring(p))

	var cabin_flags: Array[bool] = []
	for p in profiles:
		cabin_flags.append(float(p.inset) > 0.01)

	var mesh := ArrayMesh.new()

	# Surface 0: Loft panels — smooth normals via generate_normals()
	var st_loft := SurfaceTool.new()
	st_loft.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cabin_seg_count := 0
	for i in range(rings.size() - 1):
		var skip: Array = []
		var a_cab: bool = cabin_flags[i]
		var b_cab: bool = cabin_flags[i + 1]
		if a_cab and b_cab:
			cabin_seg_count += 1
			if cabin_seg_count == 1:
				# First cabin-to-cabin segment: front door opening
				skip = SIDE_WINDOW_EDGES + DOOR_BODY_EDGES
			else:
				skip = SIDE_WINDOW_EDGES
		elif a_cab != b_cab:
			skip = GLASS_TOP_EDGES
		_loft_smooth(st_loft, rings[i], rings[i + 1], skip)
	st_loft.generate_normals()
	mesh = st_loft.commit(mesh)

	# Surface 1: Caps, bumpers, door frames — flat normals (no averaging)
	var st_flat := SurfaceTool.new()
	st_flat.begin(Mesh.PRIMITIVE_TRIANGLES)
	_cap_double_sided(st_flat, rings[0], true)
	_cap_double_sided(st_flat, rings[rings.size() - 1], false)
	_add_bumpers(st_flat, profiles)
	_add_door_frames(st_flat, profiles, rings, cabin_flags)
	mesh = st_flat.commit(mesh)

	return mesh


func build_windows(variant_name: String) -> Dictionary:
	var profiles := _generate_profiles(variant_name)
	var result := {}

	var cabin_indices: Array[int] = []
	for i in range(profiles.size()):
		if profiles[i].inset > 0.01:
			cabin_indices.append(i)

	if cabin_indices.is_empty():
		return result

	var first_cabin: int = cabin_indices[0]
	var last_cabin: int = cabin_indices[cabin_indices.size() - 1]

	if first_cabin > 0:
		result["Windshield"] = _build_window_quad(
			profiles[first_cabin - 1], profiles[first_cabin], true
		)

	if last_cabin < profiles.size() - 1:
		result["RearWindow"] = _build_window_quad(
			profiles[last_cabin], profiles[last_cabin + 1], false
		)

	if cabin_indices.size() >= 2:
		result["LeftWindow"] = _build_side_window(profiles, cabin_indices, true)
		result["RightWindow"] = _build_side_window(
			profiles, cabin_indices, false
		)

	return result


func build_interior(variant_name: String) -> ArrayMesh:
	var profiles := _generate_profiles(variant_name)

	var cabin_indices: Array[int] = []
	for i in range(profiles.size()):
		if float(profiles[i].inset) > 0.01:
			cabin_indices.append(i)

	if cabin_indices.size() < 2:
		return ArrayMesh.new()

	var first_cab: int = cabin_indices[0]
	var last_cab: int = cabin_indices[cabin_indices.size() - 1]
	var p_first: Dictionary = profiles[first_cab]
	var p_last: Dictionary = profiles[last_cab]

	var z_front: float = float(p_first.z)
	var z_rear: float = float(p_last.z)
	var cab_len: float = z_rear - z_front

	var min_hw: float = float(p_first.hw)
	var min_yt: float = float(p_first.yt)
	for ci in cabin_indices:
		min_hw = minf(min_hw, float(profiles[ci].hw))
		min_yt = minf(min_yt, float(profiles[ci].yt))

	var cab_hw: float = min_hw - FRAME_DEPTH
	var yb: float = float(p_first.yb) + 0.02
	var yt: float = min_yt - 0.03
	var height: float = float(p_first.yt) - float(p_first.yb)
	var sill_y: float = float(p_first.yb) + height * 0.55

	# Dashboard and rear shelf heights — raised to sill_y to close gap to windows
	var dash_depth: float = cab_len * 0.18
	var dash_z_rear: float = z_front + dash_depth
	var dash_top: float = sill_y
	var rear_shelf_top: float = sill_y

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# -- Cabin shell --
	# Dashboard wall (only up to dash height, not roof)
	_add_quad(
		st,
		Vector3(-cab_hw, yb, z_front),
		Vector3(cab_hw, yb, z_front),
		Vector3(cab_hw, dash_top, z_front),
		Vector3(-cab_hw, dash_top, z_front),
	)
	# Rear panel (only up to shelf height, not roof)
	_add_quad(
		st,
		Vector3(cab_hw, yb, z_rear),
		Vector3(-cab_hw, yb, z_rear),
		Vector3(-cab_hw, rear_shelf_top, z_rear),
		Vector3(cab_hw, rear_shelf_top, z_rear),
	)
	# Left door panel (floor to sill)
	_add_quad(
		st,
		Vector3(-cab_hw, yb, z_rear),
		Vector3(-cab_hw, yb, z_front),
		Vector3(-cab_hw, sill_y, z_front),
		Vector3(-cab_hw, sill_y, z_rear),
	)
	# Right door panel (floor to sill)
	_add_quad(
		st,
		Vector3(cab_hw, yb, z_front),
		Vector3(cab_hw, yb, z_rear),
		Vector3(cab_hw, sill_y, z_rear),
		Vector3(cab_hw, sill_y, z_front),
	)
	# Headliner
	_add_quad(
		st,
		Vector3(-cab_hw, yt, z_front),
		Vector3(cab_hw, yt, z_front),
		Vector3(cab_hw, yt, z_rear),
		Vector3(-cab_hw, yt, z_rear),
	)
	# Cabin floor
	_add_quad(
		st,
		Vector3(-cab_hw, yb, z_rear),
		Vector3(cab_hw, yb, z_rear),
		Vector3(cab_hw, yb, z_front),
		Vector3(-cab_hw, yb, z_front),
	)

	# -- Dashboard slab --
	# Dashboard top surface
	_add_quad(
		st,
		Vector3(-cab_hw, dash_top, z_front),
		Vector3(cab_hw, dash_top, z_front),
		Vector3(cab_hw, dash_top, dash_z_rear),
		Vector3(-cab_hw, dash_top, dash_z_rear),
	)
	# Dashboard rear face (faces passengers)
	_add_quad(
		st,
		Vector3(-cab_hw, yb, dash_z_rear),
		Vector3(cab_hw, yb, dash_z_rear),
		Vector3(cab_hw, dash_top, dash_z_rear),
		Vector3(-cab_hw, dash_top, dash_z_rear),
	)

	# -- Front seats --
	var seat_y: float = yb + 0.10
	var seat_inset: float = 0.08
	var seat_gap: float = 0.06
	var seat_z_front: float = dash_z_rear + 0.05
	var seat_z_rear: float = z_front + cab_len * 0.45
	var back_lean: float = 0.06
	var back_top: float = sill_y + 0.05
	for x_sign in [-1.0, 1.0]:
		var sx_outer: float = (cab_hw - seat_inset) * x_sign
		var sx_inner: float = seat_gap * x_sign
		var sl: float = minf(sx_outer, sx_inner)
		var sr: float = maxf(sx_outer, sx_inner)
		# Seat cushion top
		_add_quad(
			st,
			Vector3(sl, seat_y, seat_z_front),
			Vector3(sr, seat_y, seat_z_front),
			Vector3(sr, seat_y, seat_z_rear),
			Vector3(sl, seat_y, seat_z_rear),
		)
		# Seat cushion front face
		_add_quad(
			st,
			Vector3(sl, yb, seat_z_front),
			Vector3(sr, yb, seat_z_front),
			Vector3(sr, seat_y, seat_z_front),
			Vector3(sl, seat_y, seat_z_front),
		)
		# Seat backrest (angled back slightly)
		_add_quad(
			st,
			Vector3(sl, seat_y, seat_z_rear),
			Vector3(sr, seat_y, seat_z_rear),
			Vector3(sr, back_top, seat_z_rear - back_lean),
			Vector3(sl, back_top, seat_z_rear - back_lean),
		)
		# Headrest
		var hr_inset: float = 0.06
		var hr_sl: float = sl + hr_inset
		var hr_sr: float = sr - hr_inset
		var hr_top: float = back_top + 0.12
		_add_quad(
			st,
			Vector3(hr_sl, back_top, seat_z_rear - back_lean),
			Vector3(hr_sr, back_top, seat_z_rear - back_lean),
			Vector3(hr_sr, hr_top, seat_z_rear - back_lean - 0.02),
			Vector3(hr_sl, hr_top, seat_z_rear - back_lean - 0.02),
		)

	# -- Rear bench seat --
	var bench_z_front: float = seat_z_rear + 0.15
	var bench_z_rear: float = z_rear - 0.08
	var bench_hw: float = cab_hw - seat_inset
	var bench_back_top: float = sill_y + 0.03
	# Bench cushion top
	_add_quad(
		st,
		Vector3(-bench_hw, seat_y, bench_z_front),
		Vector3(bench_hw, seat_y, bench_z_front),
		Vector3(bench_hw, seat_y, bench_z_rear),
		Vector3(-bench_hw, seat_y, bench_z_rear),
	)
	# Bench cushion front face
	_add_quad(
		st,
		Vector3(-bench_hw, yb, bench_z_front),
		Vector3(bench_hw, yb, bench_z_front),
		Vector3(bench_hw, seat_y, bench_z_front),
		Vector3(-bench_hw, seat_y, bench_z_front),
	)
	# Bench backrest
	_add_quad(
		st,
		Vector3(-bench_hw, seat_y, bench_z_rear),
		Vector3(bench_hw, seat_y, bench_z_rear),
		Vector3(bench_hw, bench_back_top, bench_z_rear - 0.04),
		Vector3(-bench_hw, bench_back_top, bench_z_rear - 0.04),
	)

	# Rear parcel shelf (horizontal surface behind rear bench)
	_add_quad(
		st,
		Vector3(-cab_hw, rear_shelf_top, bench_z_rear),
		Vector3(cab_hw, rear_shelf_top, bench_z_rear),
		Vector3(cab_hw, rear_shelf_top, z_rear),
		Vector3(-cab_hw, rear_shelf_top, z_rear),
	)

	# -- Center console --
	var con_hw: float = 0.06
	var con_top: float = seat_y + 0.06
	var con_z_start: float = dash_z_rear
	var con_z_end: float = seat_z_rear
	# Console top
	_add_quad(
		st,
		Vector3(-con_hw, con_top, con_z_start),
		Vector3(con_hw, con_top, con_z_start),
		Vector3(con_hw, con_top, con_z_end),
		Vector3(-con_hw, con_top, con_z_end),
	)
	# Console left side
	_add_quad(
		st,
		Vector3(-con_hw, yb, con_z_end),
		Vector3(-con_hw, yb, con_z_start),
		Vector3(-con_hw, con_top, con_z_start),
		Vector3(-con_hw, con_top, con_z_end),
	)
	# Console right side
	_add_quad(
		st,
		Vector3(con_hw, yb, con_z_start),
		Vector3(con_hw, yb, con_z_end),
		Vector3(con_hw, con_top, con_z_end),
		Vector3(con_hw, con_top, con_z_start),
	)

	return st.commit()


func build_floor(variant_name: String) -> ArrayMesh:
	var profiles := _generate_profiles(variant_name)
	var first_z: float = float(profiles[0].z)
	var last_z: float = float(profiles[profiles.size() - 1].z)
	var yb: float = float(profiles[0].yb)
	var max_hw: float = 0.0
	for p in profiles:
		max_hw = maxf(max_hw, float(p.hw))

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Floor quad — offset slightly above loft bottom to avoid Z-fighting.
	# Uses both upward and downward facing triangles for visibility from all angles.
	var floor_y: float = yb + 0.005
	var n_up := Vector3(0.0, 1.0, 0.0)
	var n_down := Vector3(0.0, -1.0, 0.0)

	# Top face (visible from above)
	st.set_normal(n_up)
	st.add_vertex(Vector3(-max_hw, floor_y, first_z))
	st.set_normal(n_up)
	st.add_vertex(Vector3(max_hw, floor_y, first_z))
	st.set_normal(n_up)
	st.add_vertex(Vector3(-max_hw, floor_y, last_z))

	st.set_normal(n_up)
	st.add_vertex(Vector3(max_hw, floor_y, first_z))
	st.set_normal(n_up)
	st.add_vertex(Vector3(max_hw, floor_y, last_z))
	st.set_normal(n_up)
	st.add_vertex(Vector3(-max_hw, floor_y, last_z))

	# Bottom face (visible from below)
	st.set_normal(n_down)
	st.add_vertex(Vector3(-max_hw, floor_y, first_z))
	st.set_normal(n_down)
	st.add_vertex(Vector3(-max_hw, floor_y, last_z))
	st.set_normal(n_down)
	st.add_vertex(Vector3(max_hw, floor_y, first_z))

	st.set_normal(n_down)
	st.add_vertex(Vector3(max_hw, floor_y, first_z))
	st.set_normal(n_down)
	st.add_vertex(Vector3(-max_hw, floor_y, last_z))
	st.set_normal(n_down)
	st.add_vertex(Vector3(max_hw, floor_y, last_z))

	return st.commit()


func build_details(variant_name: String) -> ArrayMesh:
	var profiles := _generate_profiles(variant_name)
	var p_front: Dictionary = profiles[0]
	var p_rear: Dictionary = profiles[profiles.size() - 1]

	var front_z: float = float(p_front.z)
	var rear_z: float = float(p_rear.z)
	var front_hw: float = float(p_front.hw)
	var rear_hw: float = float(p_rear.hw)
	var yb: float = float(p_front.yb)
	var front_yt: float = float(p_front.yt)
	var rear_yt: float = float(p_rear.yt)
	var front_mid_y: float = yb + (front_yt - yb) * 0.45
	var rear_mid_y: float = yb + (rear_yt - yb) * 0.45

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Front grille (recessed dark rectangle)
	var grille_hw: float = front_hw * 0.55
	var grille_yb: float = yb + (front_mid_y - yb) * 0.15
	var grille_yt: float = front_mid_y - 0.02
	var grille_z: float = front_z - 0.005
	_add_quad(
		st,
		Vector3(-grille_hw, grille_yb, grille_z),
		Vector3(grille_hw, grille_yb, grille_z),
		Vector3(grille_hw, grille_yt, grille_z),
		Vector3(-grille_hw, grille_yt, grille_z),
	)

	# Front license plate
	var plate_hw: float = 0.14
	var plate_hh: float = 0.04
	var plate_cy: float = grille_yb - 0.06
	_add_quad(
		st,
		Vector3(-plate_hw, plate_cy - plate_hh, front_z - 0.005),
		Vector3(plate_hw, plate_cy - plate_hh, front_z - 0.005),
		Vector3(plate_hw, plate_cy + plate_hh, front_z - 0.005),
		Vector3(-plate_hw, plate_cy + plate_hh, front_z - 0.005),
	)

	# Rear license plate
	var rear_plate_cy: float = yb + (rear_mid_y - yb) * 0.4
	_add_quad(
		st,
		Vector3(plate_hw, rear_plate_cy - plate_hh, rear_z + 0.005),
		Vector3(-plate_hw, rear_plate_cy - plate_hh, rear_z + 0.005),
		Vector3(-plate_hw, rear_plate_cy + plate_hh, rear_z + 0.005),
		Vector3(plate_hw, rear_plate_cy + plate_hh, rear_z + 0.005),
	)

	return st.commit()


func build_doors(variant_name: String) -> Dictionary:
	var profiles := _generate_profiles(variant_name)
	var rings: Array[PackedVector3Array] = []
	for p in profiles:
		rings.append(_profile_to_ring(p))

	var cabin_flags: Array[bool] = []
	for p in profiles:
		cabin_flags.append(float(p.inset) > 0.01)

	# Find the first cabin-to-cabin segment (front door)
	var door_front_idx := -1
	var door_rear_idx := -1
	var cabin_seg_count := 0
	for i in range(rings.size() - 1):
		if cabin_flags[i] and cabin_flags[i + 1]:
			cabin_seg_count += 1
			if cabin_seg_count == 1:
				door_front_idx = i
				door_rear_idx = i + 1
				break

	if door_front_idx < 0:
		return {}

	var p_front: Dictionary = profiles[door_front_idx]
	var p_rear: Dictionary = profiles[door_rear_idx]
	var ring_f: PackedVector3Array = rings[door_front_idx]
	var ring_r: PackedVector3Array = rings[door_rear_idx]
	var hw: float = float(p_front.hw)
	var yb: float = float(p_front.yb)
	var height: float = float(p_front.yt) - yb
	var sill_y: float = yb + height * 0.55
	var z_front: float = float(p_front.z)

	# Pivot at the A-pillar (front edge of door), vertically centered on door
	var pivot_y: float = (yb + sill_y) / 2.0
	var left_pivot := Vector3(-hw, pivot_y, z_front)
	var right_pivot := Vector3(hw, pivot_y, z_front)

	var left_result := _build_single_door(
		ring_f, ring_r, p_front, p_rear, left_pivot, true
	)
	var right_result := _build_single_door(
		ring_f, ring_r, p_front, p_rear, right_pivot, false
	)

	return {
		"LeftDoor": left_result.body,
		"RightDoor": right_result.body,
		"LeftDoorInner": left_result.inner,
		"RightDoorInner": right_result.inner,
		"LeftDoorWindow": left_result.window,
		"RightDoorWindow": right_result.window,
		"left_pivot": left_pivot,
		"right_pivot": right_pivot,
	}


func _build_single_door(
	ring_f: PackedVector3Array,
	ring_r: PackedVector3Array,
	p_front: Dictionary,
	p_rear: Dictionary,
	pivot: Vector3,
	is_left: bool,
) -> Dictionary:
	var hw_f: float = float(p_front.hw)
	var hw_r: float = float(p_rear.hw)
	var yb: float = float(p_front.yb)
	var height_f: float = float(p_front.yt) - yb
	var height_r: float = float(p_rear.yt) - float(p_rear.yb)
	# Door body only goes up to sill (window base), not shoulder (window top)
	var sill_y_f: float = yb + height_f * 0.55
	var sill_y_r: float = float(p_rear.yb) + height_r * 0.55
	var z_f: float = float(p_front.z)
	var z_r: float = float(p_rear.z)

	# Body panel edges (below window) to reproduce on the door
	# Left door: edges 8 (V8->V9), 9 (V9->V10)
	# Right door: edges 4 (V4->V5), 5 (V5->V6)
	var outer_edges: Array[int]
	var window_edge: int
	if is_left:
		outer_edges = [8, 9]
		window_edge = 10
	else:
		outer_edges = [4, 5]
		window_edge = 3

	# --- Door body mesh (metal panels) ---
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Outer surface — reproduce loft quads (smooth normals)
	for edge_i in outer_edges:
		var next_i: int = (edge_i + 1) % RING_VERTS
		var af := ring_f[edge_i] - pivot
		var bf := ring_f[next_i] - pivot
		var ar := ring_r[edge_i] - pivot
		var br := ring_r[next_i] - pivot
		st.add_vertex(af)
		st.add_vertex(bf)
		st.add_vertex(ar)
		st.add_vertex(bf)
		st.add_vertex(br)
		st.add_vertex(ar)

	st.generate_normals()
	var body_mesh := st.commit()

	# Edge strips (flat normals, body color)
	var st2 := SurfaceTool.new()
	st2.begin(Mesh.PRIMITIVE_TRIANGLES)

	var x_sign: float = -1.0 if is_left else 1.0
	var inner_x: float = x_sign * (hw_f - FRAME_DEPTH)
	var outer_x_f: float = x_sign * hw_f
	var outer_x_r: float = x_sign * hw_r

	# Front edge strip (at z_f, up to sill)
	var fe0 := Vector3(outer_x_f, yb, z_f) - pivot
	var fe1 := Vector3(inner_x, yb, z_f) - pivot
	var fe2 := Vector3(inner_x, sill_y_f, z_f) - pivot
	var fe3 := Vector3(outer_x_f, sill_y_f, z_f) - pivot
	if is_left:
		_add_quad(st2, fe0, fe1, fe2, fe3)
	else:
		_add_quad(st2, fe1, fe0, fe3, fe2)

	# Rear edge strip (at z_r, up to sill)
	var re0 := Vector3(outer_x_r, yb, z_r) - pivot
	var re1 := Vector3(inner_x, yb, z_r) - pivot
	var re2 := Vector3(inner_x, sill_y_r, z_r) - pivot
	var re3 := Vector3(outer_x_r, sill_y_r, z_r) - pivot
	if is_left:
		_add_quad(st2, re1, re0, re3, re2)
	else:
		_add_quad(st2, re0, re1, re2, re3)

	# Bottom edge strip (at yb)
	var be0 := Vector3(outer_x_f, yb, z_f) - pivot
	var be1 := Vector3(outer_x_r, yb, z_r) - pivot
	var be2 := Vector3(inner_x, yb, z_r) - pivot
	var be3 := Vector3(inner_x, yb, z_f) - pivot
	if is_left:
		_add_quad(st2, be0, be1, be2, be3)
	else:
		_add_quad(st2, be1, be0, be3, be2)

	# Top edge strip (at sill — window base)
	var te0 := Vector3(outer_x_f, sill_y_f, z_f) - pivot
	var te1 := Vector3(outer_x_r, sill_y_r, z_r) - pivot
	var te2 := Vector3(inner_x, sill_y_r, z_r) - pivot
	var te3 := Vector3(inner_x, sill_y_f, z_f) - pivot
	if is_left:
		_add_quad(st2, te1, te0, te3, te2)
	else:
		_add_quad(st2, te0, te1, te2, te3)

	body_mesh = st2.commit(body_mesh)

	# --- Door inner mesh (interior/black) ---
	# Duplicate outer loft quads with reversed winding so they face inward.
	# Offset slightly inward to avoid Z-fighting with outer surface.
	var st_inner := SurfaceTool.new()
	st_inner.begin(Mesh.PRIMITIVE_TRIANGLES)
	var inward := Vector3(x_sign * -0.005, 0.0, 0.0)
	for edge_i in outer_edges:
		var next_i: int = (edge_i + 1) % RING_VERTS
		var af := ring_f[edge_i] - pivot + inward
		var bf := ring_f[next_i] - pivot + inward
		var ar := ring_r[edge_i] - pivot + inward
		var br := ring_r[next_i] - pivot + inward
		# Reversed winding (swap second and third vertex of each triangle)
		st_inner.add_vertex(af)
		st_inner.add_vertex(ar)
		st_inner.add_vertex(bf)
		st_inner.add_vertex(bf)
		st_inner.add_vertex(ar)
		st_inner.add_vertex(br)
	st_inner.generate_normals()
	var inner_mesh := st_inner.commit()

	# --- Door window mesh (glass) ---
	var st_win := SurfaceTool.new()
	st_win.begin(Mesh.PRIMITIVE_TRIANGLES)
	var win_next: int = (window_edge + 1) % RING_VERTS
	var waf := ring_f[window_edge] - pivot
	var wbf := ring_f[win_next] - pivot
	var war := ring_r[window_edge] - pivot
	var wbr := ring_r[win_next] - pivot
	st_win.add_vertex(waf)
	st_win.add_vertex(wbf)
	st_win.add_vertex(war)
	st_win.add_vertex(wbf)
	st_win.add_vertex(wbr)
	st_win.add_vertex(war)
	st_win.generate_normals()
	var window_mesh := st_win.commit()

	return {"body": body_mesh, "inner": inner_mesh, "window": window_mesh}


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

		var is_cabin: bool = float(base.inset) > 0.01
		if is_cabin:
			if float(base.z) < cabin_start_z or float(base.z) > cabin_end_z:
				p.yt = float(base.yt) * height_mult * 0.3
				p.inset = 0.0
			else:
				p.yt = float(base.yt) * height_mult * cabin_height_mult
				p.inset = float(base.inset) + cabin_inset_add
		else:
			p.yt = float(base.yt) * height_mult
			p.inset = float(base.inset)

		if float(base.z) >= bed_start_z and not is_cabin:
			p.yt = maxf(p.yt, float(base.yt) * height_mult * 0.5)
			p.yb = float(base.yb) * height_mult + ground_offset

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
	var inset: float = profile.inset

	var top_hw: float = hw - inset
	var height: float = yt - yb
	var shoulder_y: float = yt - height * 0.12
	var sill_y: float = yb + height * 0.55
	var lower_y: float = yb + height * 0.15

	# 12 vertices clockwise when viewed from front
	ring.append(Vector3(-top_hw, yt, z))         # V0:  top-left
	ring.append(Vector3(0.0, yt, z))             # V1:  top-center
	ring.append(Vector3(top_hw, yt, z))          # V2:  top-right
	ring.append(Vector3(top_hw, shoulder_y, z))  # V3:  right shoulder
	ring.append(Vector3(hw, sill_y, z))          # V4:  right sill
	ring.append(Vector3(hw, lower_y, z))         # V5:  right lower
	ring.append(Vector3(hw, yb, z))              # V6:  bottom-right
	ring.append(Vector3(0.0, yb, z))             # V7:  bottom-center
	ring.append(Vector3(-hw, yb, z))             # V8:  bottom-left
	ring.append(Vector3(-hw, lower_y, z))        # V9:  left lower
	ring.append(Vector3(-hw, sill_y, z))         # V10: left sill
	ring.append(Vector3(-top_hw, shoulder_y, z)) # V11: left shoulder

	return ring


func _loft_smooth(
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
		st.add_vertex(ring_a[i])
		st.add_vertex(ring_a[next_i])
		st.add_vertex(ring_b[i])

		st.add_vertex(ring_a[next_i])
		st.add_vertex(ring_b[next_i])
		st.add_vertex(ring_b[i])


func _cap_double_sided(
	st: SurfaceTool, ring: PackedVector3Array, front: bool
) -> void:
	var center := Vector3.ZERO
	for v in ring:
		center += v
	center /= float(ring.size())

	var n_out := Vector3(0.0, 0.0, -1.0) if front else Vector3(0.0, 0.0, 1.0)
	var n_in := -n_out
	var count: int = ring.size()
	for i in range(count):
		var next_i: int = (i + 1) % count
		# Outward-facing triangle
		if front:
			st.set_normal(n_out)
			st.add_vertex(center)
			st.set_normal(n_out)
			st.add_vertex(ring[i])
			st.set_normal(n_out)
			st.add_vertex(ring[next_i])
		else:
			st.set_normal(n_out)
			st.add_vertex(center)
			st.set_normal(n_out)
			st.add_vertex(ring[next_i])
			st.set_normal(n_out)
			st.add_vertex(ring[i])
		# Inward-facing triangle (opposite winding)
		if front:
			st.set_normal(n_in)
			st.add_vertex(center)
			st.set_normal(n_in)
			st.add_vertex(ring[next_i])
			st.set_normal(n_in)
			st.add_vertex(ring[i])
		else:
			st.set_normal(n_in)
			st.add_vertex(center)
			st.set_normal(n_in)
			st.add_vertex(ring[i])
			st.set_normal(n_in)
			st.add_vertex(ring[next_i])


func _add_floor(st: SurfaceTool, profiles: Array[Dictionary]) -> void:
	var first_z: float = float(profiles[0].z)
	var last_z: float = float(profiles[profiles.size() - 1].z)
	var yb: float = float(profiles[0].yb)
	var max_hw: float = 0.0
	for p in profiles:
		max_hw = maxf(max_hw, float(p.hw))

	var n := Vector3(0.0, -1.0, 0.0)
	st.set_normal(n)
	st.add_vertex(Vector3(-max_hw, yb, first_z))
	st.set_normal(n)
	st.add_vertex(Vector3(max_hw, yb, first_z))
	st.set_normal(n)
	st.add_vertex(Vector3(-max_hw, yb, last_z))

	st.set_normal(n)
	st.add_vertex(Vector3(max_hw, yb, first_z))
	st.set_normal(n)
	st.add_vertex(Vector3(max_hw, yb, last_z))
	st.set_normal(n)
	st.add_vertex(Vector3(-max_hw, yb, last_z))


func _add_bumpers(st: SurfaceTool, profiles: Array[Dictionary]) -> void:
	var p_front: Dictionary = profiles[0]
	var p_rear: Dictionary = profiles[profiles.size() - 1]
	var front_z: float = float(p_front.z)
	var rear_z: float = float(p_rear.z)
	var front_hw: float = float(p_front.hw)
	var rear_hw: float = float(p_rear.hw)
	var yb: float = float(p_front.yb)
	var front_yt: float = float(p_front.yt)
	var rear_yt: float = float(p_rear.yt)
	var bump_d: float = 0.08
	var front_bump_top: float = yb + (front_yt - yb) * 0.45
	var rear_bump_top: float = yb + (rear_yt - yb) * 0.45

	# Front bumper — box protruding forward
	# Front face
	_add_quad(
		st,
		Vector3(-front_hw, yb, front_z - bump_d),
		Vector3(front_hw, yb, front_z - bump_d),
		Vector3(front_hw, front_bump_top, front_z - bump_d),
		Vector3(-front_hw, front_bump_top, front_z - bump_d),
	)
	# Bottom face
	_add_quad(
		st,
		Vector3(-front_hw, yb, front_z),
		Vector3(front_hw, yb, front_z),
		Vector3(front_hw, yb, front_z - bump_d),
		Vector3(-front_hw, yb, front_z - bump_d),
	)
	# Top face
	_add_quad(
		st,
		Vector3(-front_hw, front_bump_top, front_z - bump_d),
		Vector3(front_hw, front_bump_top, front_z - bump_d),
		Vector3(front_hw, front_bump_top, front_z),
		Vector3(-front_hw, front_bump_top, front_z),
	)
	# Left side
	_add_quad(
		st,
		Vector3(-front_hw, yb, front_z - bump_d),
		Vector3(-front_hw, front_bump_top, front_z - bump_d),
		Vector3(-front_hw, front_bump_top, front_z),
		Vector3(-front_hw, yb, front_z),
	)
	# Right side
	_add_quad(
		st,
		Vector3(front_hw, yb, front_z),
		Vector3(front_hw, front_bump_top, front_z),
		Vector3(front_hw, front_bump_top, front_z - bump_d),
		Vector3(front_hw, yb, front_z - bump_d),
	)

	# Rear bumper — box protruding backward
	# Rear face
	_add_quad(
		st,
		Vector3(rear_hw, yb, rear_z + bump_d),
		Vector3(-rear_hw, yb, rear_z + bump_d),
		Vector3(-rear_hw, rear_bump_top, rear_z + bump_d),
		Vector3(rear_hw, rear_bump_top, rear_z + bump_d),
	)
	# Bottom face
	_add_quad(
		st,
		Vector3(rear_hw, yb, rear_z),
		Vector3(-rear_hw, yb, rear_z),
		Vector3(-rear_hw, yb, rear_z + bump_d),
		Vector3(rear_hw, yb, rear_z + bump_d),
	)
	# Top face
	_add_quad(
		st,
		Vector3(rear_hw, rear_bump_top, rear_z + bump_d),
		Vector3(-rear_hw, rear_bump_top, rear_z + bump_d),
		Vector3(-rear_hw, rear_bump_top, rear_z),
		Vector3(rear_hw, rear_bump_top, rear_z),
	)
	# Left side
	_add_quad(
		st,
		Vector3(-rear_hw, yb, rear_z),
		Vector3(-rear_hw, rear_bump_top, rear_z),
		Vector3(-rear_hw, rear_bump_top, rear_z + bump_d),
		Vector3(-rear_hw, yb, rear_z + bump_d),
	)
	# Right side
	_add_quad(
		st,
		Vector3(rear_hw, yb, rear_z + bump_d),
		Vector3(rear_hw, rear_bump_top, rear_z + bump_d),
		Vector3(rear_hw, rear_bump_top, rear_z),
		Vector3(rear_hw, yb, rear_z),
	)


func _add_door_frames(
	st: SurfaceTool,
	_profiles: Array[Dictionary],
	rings: Array[PackedVector3Array],
	cabin_flags: Array[bool],
) -> void:
	for i in range(rings.size() - 1):
		if not (cabin_flags[i] and cabin_flags[i + 1]):
			continue
		# Right side frame (edge 3: V3 shoulder -> V4 sill)
		_add_window_frame(st, rings[i], rings[i + 1], 3, 4, true)
		# Left side frame (edge 10: V10 sill -> V11 shoulder)
		_add_window_frame(st, rings[i], rings[i + 1], 11, 10, false)


func _add_window_frame(
	st: SurfaceTool,
	ring_a: PackedVector3Array,
	ring_b: PackedVector3Array,
	shoulder_idx: int,
	sill_idx: int,
	is_right: bool,
) -> void:
	var x_inset: float = -FRAME_DEPTH if is_right else FRAME_DEPTH
	var inset := Vector3(x_inset, 0.0, 0.0)

	var tf := ring_a[shoulder_idx]
	var tr := ring_b[shoulder_idx]
	var bf := ring_a[sill_idx]
	var br := ring_b[sill_idx]

	var itf := tf + inset
	var itr := tr + inset
	var ibf := bf + inset
	var ibr := br + inset

	if is_right:
		_add_quad(st, tf, tr, itr, itf)   # top sill (faces down)
		_add_quad(st, br, bf, ibf, ibr)    # bottom sill (faces up)
		_add_quad(st, tf, itf, ibf, bf)    # front pillar (faces +Z)
		_add_quad(st, itr, tr, br, ibr)    # rear pillar (faces -Z)
	else:
		_add_quad(st, tr, tf, itf, itr)    # top sill (faces down)
		_add_quad(st, bf, br, ibr, ibf)    # bottom sill (faces up)
		_add_quad(st, itf, tf, bf, ibf)    # front pillar (faces +Z)
		_add_quad(st, tr, itr, ibr, br)    # rear pillar (faces -Z)


func _add_quad(
	st: SurfaceTool, v0: Vector3, v1: Vector3, v2: Vector3, v3: Vector3
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


func _build_window_quad(
	profile_a: Dictionary, profile_b: Dictionary, _is_front: bool
) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var z_a: float = profile_a.z
	var z_b: float = profile_b.z
	var hw_a: float = float(profile_a.hw) - float(profile_a.get("inset", 0.0))
	var hw_b: float = float(profile_b.hw) - float(profile_b.get("inset", 0.0))
	var yt_a: float = profile_a.yt
	var yt_b: float = profile_b.yt

	# Trapezoidal quad matching the exact gap left by skipped roof edges.
	var va := Vector3(-hw_a, yt_a, z_a)
	var vb := Vector3(-hw_b, yt_b, z_b)
	var vc := Vector3(hw_a, yt_a, z_a)
	var vd := Vector3(hw_b, yt_b, z_b)
	var n: Vector3 = (vb - va).cross(vc - va).normalized()

	st.set_normal(n)
	st.add_vertex(va)
	st.set_normal(n)
	st.add_vertex(vb)
	st.set_normal(n)
	st.add_vertex(vc)

	st.set_normal(n)
	st.add_vertex(vc)
	st.set_normal(n)
	st.add_vertex(vb)
	st.set_normal(n)
	st.add_vertex(vd)

	return st.commit()


func _build_side_window(
	profiles: Array[Dictionary], cabin_indices: Array[int], is_left: bool
) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Skip idx=0 (first cabin segment) — that window is part of the door mesh
	for idx in range(1, cabin_indices.size() - 1):
		var i_a: int = cabin_indices[idx]
		var i_b: int = cabin_indices[idx + 1]
		var p_a: Dictionary = profiles[i_a]
		var p_b: Dictionary = profiles[i_b]

		var x_sign: float = -1.0 if is_left else 1.0
		var top_hw_a: float = float(p_a.hw) - float(p_a.inset)
		var top_hw_b: float = float(p_b.hw) - float(p_b.inset)
		var hw_a: float = float(p_a.hw)
		var hw_b: float = float(p_b.hw)

		var height_a: float = float(p_a.yt) - float(p_a.yb)
		var height_b: float = float(p_b.yt) - float(p_b.yb)
		var shoulder_y_a: float = float(p_a.yt) - height_a * 0.12
		var shoulder_y_b: float = float(p_b.yt) - height_b * 0.12
		var sill_y_a: float = float(p_a.yb) + height_a * 0.55
		var sill_y_b: float = float(p_b.yb) + height_b * 0.55

		var tl := Vector3(x_sign * top_hw_a, shoulder_y_a, float(p_a.z))
		var bl := Vector3(x_sign * hw_a, sill_y_a, float(p_a.z))
		var tr := Vector3(x_sign * top_hw_b, shoulder_y_b, float(p_b.z))
		var br := Vector3(x_sign * hw_b, sill_y_b, float(p_b.z))

		if is_left:
			var n: Vector3 = (br - bl).cross(tl - bl).normalized()
			st.set_normal(n)
			st.add_vertex(bl)
			st.set_normal(n)
			st.add_vertex(br)
			st.set_normal(n)
			st.add_vertex(tl)

			st.set_normal(n)
			st.add_vertex(tl)
			st.set_normal(n)
			st.add_vertex(br)
			st.set_normal(n)
			st.add_vertex(tr)
		else:
			var n: Vector3 = (tl - bl).cross(br - bl).normalized()
			st.set_normal(n)
			st.add_vertex(bl)
			st.set_normal(n)
			st.add_vertex(tl)
			st.set_normal(n)
			st.add_vertex(br)

			st.set_normal(n)
			st.add_vertex(tl)
			st.set_normal(n)
			st.add_vertex(tr)
			st.set_normal(n)
			st.add_vertex(br)

	return st.commit()
