extends RefCounted
## Generates a procedural police helicopter mesh using SurfaceTool.
## Follows the same pattern as car_body_builder.gd — all geometry built
## with SurfaceTool.begin/add_vertex/commit, flat normals via _add_quad.

# Fuselage dimensions — scaled up so the pilot fits inside the cabin
const FUSE_HW := 1.3       # half-width  (was 1.0)
const FUSE_HH := 1.1       # half-height (was 0.75) — cabin top at y=1.1, above pilot head
const FUSE_HL := 2.5       # half-length (was 2.0)
const NOSE_TAPER := 0.6    # nose tapers to this fraction of full size

# Tail boom
const TAIL_LEN := 3.5      # (was 3.0)
const TAIL_HW := 0.3       # (was 0.25)
const TAIL_HH := 0.3       # (was 0.25)

# Tail fin (vertical stabilizer)
const FIN_HEIGHT := 0.9
const FIN_LEN := 0.7
const FIN_THICKNESS := 0.06

# Skids
const SKID_DROP := 0.7     # how far below fuselage bottom (was 0.6)
const SKID_WIDTH := 0.1
const SKID_HEIGHT := 0.06
const SKID_SPREAD := 0.9   # lateral offset from center (was 0.7)
const STRUT_WIDTH := 0.07
const STRUT_DEPTH := 0.07

# Rotor
const ROTOR_RADIUS := 4.5  # (was 3.5)
const ROTOR_BLADE_W := 0.22
const ROTOR_BLADE_H := 0.05

# Tail rotor
const TAIL_ROTOR_RADIUS := 0.5
const TAIL_ROTOR_BLADE_W := 0.1
const TAIL_ROTOR_BLADE_H := 0.03


func build_fuselage() -> ArrayMesh:
	## Returns a two-surface mesh:
	##   surface 0 — opaque body (roof, floor, rear, tail boom, fin, skids)
	##   surface 1 — glass (front/windshield face, left side, right side)
	var arr_mesh := ArrayMesh.new()

	var st := SurfaceTool.new()   # surface 0: solid
	var stg := SurfaceTool.new()  # surface 1: glass
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	stg.begin(Mesh.PRIMITIVE_TRIANGLES)

	var yb := -FUSE_HH
	var yt := FUSE_HH
	var zf := -FUSE_HL  # front (nose)
	var zr := FUSE_HL   # rear

	var nhw := FUSE_HW * NOSE_TAPER
	var nhh := FUSE_HH * NOSE_TAPER
	var nyb := -nhh
	var nyt := nhh

	# ── GLASS faces (front + left + right) ───────────────────────────────────
	# Front face (windshield — tapered nose)
	_add_quad(stg,
		Vector3(-nhw, nyb, zf), Vector3(nhw, nyb, zf),
		Vector3(nhw, nyt, zf), Vector3(-nhw, nyt, zf))
	# Left face (full trapezoidal side panel)
	_add_quad(stg,
		Vector3(-FUSE_HW, yb, zr), Vector3(-nhw, nyb, zf),
		Vector3(-nhw, nyt, zf), Vector3(-FUSE_HW, yt, zr))
	# Right face
	_add_quad(stg,
		Vector3(nhw, nyb, zf), Vector3(FUSE_HW, yb, zr),
		Vector3(FUSE_HW, yt, zr), Vector3(nhw, nyt, zf))

	# ── SOLID faces ───────────────────────────────────────────────────────────
	# Rear face
	_add_quad(st,
		Vector3(FUSE_HW, yb, zr), Vector3(-FUSE_HW, yb, zr),
		Vector3(-FUSE_HW, yt, zr), Vector3(FUSE_HW, yt, zr))
	# Top face (trapezoid: narrow at nose, wide at rear)
	_add_quad(st,
		Vector3(-nhw, nyt, zf), Vector3(nhw, nyt, zf),
		Vector3(FUSE_HW, yt, zr), Vector3(-FUSE_HW, yt, zr))
	# Bottom face
	_add_quad(st,
		Vector3(-nhw, nyb, zf), Vector3(-FUSE_HW, yb, zr),
		Vector3(FUSE_HW, yb, zr), Vector3(nhw, nyb, zf))

	# Tail boom: extends from fuselage rear
	var tz := zr + TAIL_LEN
	_add_quad(st,
		Vector3(TAIL_HW, -TAIL_HH, tz), Vector3(-TAIL_HW, -TAIL_HH, tz),
		Vector3(-TAIL_HW, TAIL_HH, tz), Vector3(TAIL_HW, TAIL_HH, tz))
	_add_quad(st,
		Vector3(-TAIL_HW, TAIL_HH, zr), Vector3(TAIL_HW, TAIL_HH, zr),
		Vector3(TAIL_HW, TAIL_HH, tz), Vector3(-TAIL_HW, TAIL_HH, tz))
	_add_quad(st,
		Vector3(-TAIL_HW, -TAIL_HH, tz), Vector3(TAIL_HW, -TAIL_HH, tz),
		Vector3(TAIL_HW, -TAIL_HH, zr), Vector3(-TAIL_HW, -TAIL_HH, zr))
	_add_quad(st,
		Vector3(-TAIL_HW, -TAIL_HH, tz), Vector3(-TAIL_HW, -TAIL_HH, zr),
		Vector3(-TAIL_HW, TAIL_HH, zr), Vector3(-TAIL_HW, TAIL_HH, tz))
	_add_quad(st,
		Vector3(TAIL_HW, -TAIL_HH, zr), Vector3(TAIL_HW, -TAIL_HH, tz),
		Vector3(TAIL_HW, TAIL_HH, tz), Vector3(TAIL_HW, TAIL_HH, zr))

	# Tail fin (vertical stabilizer at end of boom)
	var fin_zf := tz - FIN_LEN
	_add_quad(st,
		Vector3(-FIN_THICKNESS, TAIL_HH, fin_zf),
		Vector3(FIN_THICKNESS, TAIL_HH, fin_zf),
		Vector3(FIN_THICKNESS, TAIL_HH + FIN_HEIGHT, tz),
		Vector3(-FIN_THICKNESS, TAIL_HH + FIN_HEIGHT, tz))
	_add_quad(st,
		Vector3(FIN_THICKNESS, TAIL_HH, fin_zf),
		Vector3(-FIN_THICKNESS, TAIL_HH, fin_zf),
		Vector3(-FIN_THICKNESS, TAIL_HH + FIN_HEIGHT, tz),
		Vector3(FIN_THICKNESS, TAIL_HH + FIN_HEIGHT, tz))

	# Landing skids (two parallel rails + two vertical struts each)
	for x_sign: float in [-1.0, 1.0]:
		var sx := x_sign * SKID_SPREAD
		var sy := -FUSE_HH - SKID_DROP
		var szf := -FUSE_HL * 0.8
		var szr := FUSE_HL * 0.5
		_add_box(st,
			Vector3(sx - SKID_WIDTH * 0.5, sy - SKID_HEIGHT * 0.5, szf),
			Vector3(sx + SKID_WIDTH * 0.5, sy + SKID_HEIGHT * 0.5, szr))
		var strut_zf := szf + 0.3
		_add_box(st,
			Vector3(sx - STRUT_WIDTH * 0.5, sy, strut_zf - STRUT_DEPTH * 0.5),
			Vector3(sx + STRUT_WIDTH * 0.5, -FUSE_HH, strut_zf + STRUT_DEPTH * 0.5))
		var strut_zr := szr - 0.4
		_add_box(st,
			Vector3(sx - STRUT_WIDTH * 0.5, sy, strut_zr - STRUT_DEPTH * 0.5),
			Vector3(sx + STRUT_WIDTH * 0.5, -FUSE_HH, strut_zr + STRUT_DEPTH * 0.5))

	st.generate_normals()
	stg.generate_normals()
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, st.commit_to_arrays())
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, stg.commit_to_arrays())
	return arr_mesh


func build_main_rotor() -> ArrayMesh:
	## Two crossed blades (4 blades total, as 2 planks)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Blade 1: along X axis
	_add_box(st,
		Vector3(-ROTOR_RADIUS, -ROTOR_BLADE_H * 0.5, -ROTOR_BLADE_W * 0.5),
		Vector3(ROTOR_RADIUS, ROTOR_BLADE_H * 0.5, ROTOR_BLADE_W * 0.5))
	# Blade 2: along Z axis
	_add_box(st,
		Vector3(-ROTOR_BLADE_W * 0.5, -ROTOR_BLADE_H * 0.5, -ROTOR_RADIUS),
		Vector3(ROTOR_BLADE_W * 0.5, ROTOR_BLADE_H * 0.5, ROTOR_RADIUS))
	return st.commit()


func build_tail_rotor() -> ArrayMesh:
	## Two crossed blades, smaller, oriented for side-facing rotation
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r := TAIL_ROTOR_RADIUS
	var w := TAIL_ROTOR_BLADE_W
	var h := TAIL_ROTOR_BLADE_H
	# Blade 1: along Y axis
	_add_box(st,
		Vector3(-h * 0.5, -r, -w * 0.5),
		Vector3(h * 0.5, r, w * 0.5))
	# Blade 2: along Z axis
	_add_box(st,
		Vector3(-h * 0.5, -w * 0.5, -r),
		Vector3(h * 0.5, w * 0.5, r))
	return st.commit()


func build_cockpit_seat() -> ArrayMesh:
	## Simple bucket seat inside the cockpit (centered, forward section).
	## Positioned at the new cabin floor y = -FUSE_HH = -1.1.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Seat cushion: 0.44 wide, 0.15 tall, 0.6 deep; at cabin floor
	_add_box(st, Vector3(-0.22, -1.1, -1.0), Vector3(0.22, -0.95, -0.4))
	# Seat back: 0.44 wide, 0.7 tall, 0.1 deep; upright behind cushion
	_add_box(st, Vector3(-0.22, -0.95, -1.05), Vector3(0.22, -0.25, -0.95))
	return st.commit()


func _add_box(st: SurfaceTool, min_pt: Vector3, max_pt: Vector3) -> void:
	var x0 := min_pt.x
	var y0 := min_pt.y
	var z0 := min_pt.z
	var x1 := max_pt.x
	var y1 := max_pt.y
	var z1 := max_pt.z
	# Front (-Z)
	_add_quad(st,
		Vector3(x0, y0, z0), Vector3(x1, y0, z0),
		Vector3(x1, y1, z0), Vector3(x0, y1, z0))
	# Back (+Z)
	_add_quad(st,
		Vector3(x1, y0, z1), Vector3(x0, y0, z1),
		Vector3(x0, y1, z1), Vector3(x1, y1, z1))
	# Top (+Y)
	_add_quad(st,
		Vector3(x0, y1, z0), Vector3(x1, y1, z0),
		Vector3(x1, y1, z1), Vector3(x0, y1, z1))
	# Bottom (-Y)
	_add_quad(st,
		Vector3(x0, y0, z1), Vector3(x1, y0, z1),
		Vector3(x1, y0, z0), Vector3(x0, y0, z0))
	# Left (-X)
	_add_quad(st,
		Vector3(x0, y0, z1), Vector3(x0, y0, z0),
		Vector3(x0, y1, z0), Vector3(x0, y1, z1))
	# Right (+X)
	_add_quad(st,
		Vector3(x1, y0, z0), Vector3(x1, y0, z1),
		Vector3(x1, y1, z1), Vector3(x1, y1, z0))


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
