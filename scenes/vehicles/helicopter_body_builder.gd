extends RefCounted
## Generates a procedural police helicopter mesh using SurfaceTool.
## Follows the same pattern as car_body_builder.gd — all geometry built
## with SurfaceTool.begin/add_vertex/commit, flat normals via _add_quad.

# Fuselage dimensions
const FUSE_HW := 1.0       # half-width
const FUSE_HH := 0.75      # half-height
const FUSE_HL := 2.0       # half-length (nose to rear of cabin)
const NOSE_TAPER := 0.6    # nose tapers to this fraction of full size

# Tail boom
const TAIL_LEN := 3.0
const TAIL_HW := 0.25
const TAIL_HH := 0.25

# Tail fin (vertical stabilizer)
const FIN_HEIGHT := 0.8
const FIN_LEN := 0.6
const FIN_THICKNESS := 0.05

# Skids
const SKID_DROP := 0.6     # how far below fuselage bottom
const SKID_WIDTH := 0.08
const SKID_HEIGHT := 0.06
const SKID_SPREAD := 0.7   # lateral offset from center
const STRUT_WIDTH := 0.06
const STRUT_DEPTH := 0.06

# Rotor
const ROTOR_RADIUS := 3.5
const ROTOR_BLADE_W := 0.18
const ROTOR_BLADE_H := 0.04

# Tail rotor
const TAIL_ROTOR_RADIUS := 0.5
const TAIL_ROTOR_BLADE_W := 0.1
const TAIL_ROTOR_BLADE_H := 0.03


func build_fuselage() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var yb := -FUSE_HH
	var yt := FUSE_HH
	var zf := -FUSE_HL  # front (nose)
	var zr := FUSE_HL   # rear

	# Tapered nose (front face is smaller)
	var nhw := FUSE_HW * NOSE_TAPER
	var nhh := FUSE_HH * NOSE_TAPER
	var nyb := -nhh
	var nyt := nhh

	# Main cabin: 6 faces (box), but front face uses tapered dimensions
	# Front face (tapered)
	_add_quad(st,
		Vector3(-nhw, nyb, zf), Vector3(nhw, nyb, zf),
		Vector3(nhw, nyt, zf), Vector3(-nhw, nyt, zf))
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
	# Left face
	_add_quad(st,
		Vector3(-FUSE_HW, yb, zr), Vector3(-nhw, nyb, zf),
		Vector3(-nhw, nyt, zf), Vector3(-FUSE_HW, yt, zr))
	# Right face
	_add_quad(st,
		Vector3(nhw, nyb, zf), Vector3(FUSE_HW, yb, zr),
		Vector3(FUSE_HW, yt, zr), Vector3(nhw, nyt, zf))

	# Tail boom: extends from fuselage rear
	var tz := zr + TAIL_LEN
	# Rear cap
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
		# Skid rail (horizontal bar)
		_add_box(st,
			Vector3(sx - SKID_WIDTH * 0.5, sy - SKID_HEIGHT * 0.5, szf),
			Vector3(sx + SKID_WIDTH * 0.5, sy + SKID_HEIGHT * 0.5, szr))
		# Front strut (vertical connecting fuselage bottom to skid)
		var strut_zf := szf + 0.3
		_add_box(st,
			Vector3(sx - STRUT_WIDTH * 0.5, sy, strut_zf - STRUT_DEPTH * 0.5),
			Vector3(sx + STRUT_WIDTH * 0.5, -FUSE_HH, strut_zf + STRUT_DEPTH * 0.5))
		# Rear strut
		var strut_zr := szr - 0.4
		_add_box(st,
			Vector3(sx - STRUT_WIDTH * 0.5, sy, strut_zr - STRUT_DEPTH * 0.5),
			Vector3(sx + STRUT_WIDTH * 0.5, -FUSE_HH, strut_zr + STRUT_DEPTH * 0.5))

	return st.commit()


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


func build_windshield() -> ArrayMesh:
	## Flat quad panels forming a two-pane windshield on the nose.
	## Thin depth so it sits flush with/just inside the tapered nose face.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var zf := -FUSE_HL + 0.02  # just inside the nose face
	var thickness := 0.03
	var nhw := FUSE_HW * NOSE_TAPER
	var nhh := FUSE_HH * NOSE_TAPER
	# Left pane (x: -nhw to -0.05, y: -nhh+0.1 to +nhh-0.05)
	_add_box(st,
		Vector3(-nhw + 0.05, -nhh + 0.1, zf - thickness),
		Vector3(-0.05, nhh - 0.05, zf))
	# Right pane (x: 0.05 to nhw-0.05, y: same)
	_add_box(st,
		Vector3(0.05, -nhh + 0.1, zf - thickness),
		Vector3(nhw - 0.05, nhh - 0.05, zf))
	return st.commit()


func build_cockpit_seat() -> ArrayMesh:
	## Simple bucket seat inside the cockpit (centered, forward section).
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Seat cushion: 0.4 wide, 0.1 tall, 0.45 deep; center at z=-0.5
	_add_box(st, Vector3(-0.2, -0.75, -0.75), Vector3(0.2, -0.65, -0.3))
	# Seat back: 0.4 wide, 0.55 tall, 0.08 deep; upright behind cushion
	_add_box(st, Vector3(-0.2, -0.65, -0.78), Vector3(0.2, -0.10, -0.70))
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
