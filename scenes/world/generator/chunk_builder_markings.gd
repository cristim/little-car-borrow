extends RefCounted
## Builds lane markings and pedestrian crossings as a single merged mesh.
## Center lines, edge lines, lane dividers, and zebra crossings.

const MARKING_Y := 0.003
const DASH_LENGTH := 3.0
const DASH_GAP := 3.0
const MARKING_WIDTH := 0.15
const EDGE_LINE_WIDTH := 0.12
const CROSSING_BAR_WIDTH := 0.5
const CROSSING_BAR_LENGTH := 3.0
const CROSSING_BAR_GAP := 0.5
const CROSSING_SETBACK := 2.0

var _grid: RefCounted
var _marking_mat: StandardMaterial3D
var _city_script: GDScript = preload("res://scenes/world/city.gd")


func init(grid: RefCounted, marking_mat: StandardMaterial3D) -> void:
	_grid = grid
	_marking_mat = marking_mat


func build(chunk: Node3D, ox: float, oz: float, _span: float) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Set upward normal once — applies to all subsequent add_vertex calls.
	# Avoids generate_normals() which can fail on perfectly flat geometry.
	st.set_normal(Vector3.UP)

	_build_road_markings(st, ox, oz)
	_build_crossings(st, ox, oz)

	var mesh := st.commit()
	if mesh.get_surface_count() == 0:
		return

	var mesh_inst := MeshInstance3D.new()
	mesh_inst.name = "Markings"
	mesh_inst.mesh = mesh
	mesh_inst.material_override = _marking_mat
	mesh_inst.extra_cull_margin = 10.0
	chunk.add_child(mesh_inst)


func _build_road_markings(st: SurfaceTool, ox: float, oz: float) -> void:
	# N-S roads: markings run along Z between intersections
	for i in range(_grid.GRID_SIZE + 1):
		var rw: float = _grid.get_road_width(i)
		var cx: float = _grid.get_road_center_local(i) + ox
		for j in range(_grid.GRID_SIZE):
			var z_start: float = _grid.get_road_center_local(j) + _grid.get_road_width(j) * 0.5
			var z_end: float = (
				_grid.get_road_center_local(j + 1) - _grid.get_road_width(j + 1) * 0.5
			)
			_add_ns_road_markings(st, cx, z_start + oz, z_end + oz, rw, i)

	# E-W roads: markings run along X between intersections
	for j in range(_grid.GRID_SIZE + 1):
		var rw: float = _grid.get_road_width(j)
		var cz: float = _grid.get_road_center_local(j) + oz
		for i in range(_grid.GRID_SIZE):
			var x_start: float = _grid.get_road_center_local(i) + _grid.get_road_width(i) * 0.5
			var x_end: float = (
				_grid.get_road_center_local(i + 1) - _grid.get_road_width(i + 1) * 0.5
			)
			_add_ew_road_markings(st, cz, x_start + ox, x_end + ox, rw, j)


func _add_ns_road_markings(
	st: SurfaceTool, cx: float, z0: float, z1: float, rw: float, idx: int
) -> void:
	var hw := MARKING_WIDTH * 0.5
	var ehw := EDGE_LINE_WIDTH * 0.5

	if idx == _grid.BOULEVARD_INDEX:
		# Boulevard (12m): double center + 2 lane dividers + 2 edge lines
		_add_solid_line_z(st, cx - hw * 2.0, z0, z1, MARKING_WIDTH)
		_add_solid_line_z(st, cx + hw * 2.0, z0, z1, MARKING_WIDTH)
		_add_dashed_line_z(st, cx - rw * 0.25, z0, z1, MARKING_WIDTH)
		_add_dashed_line_z(st, cx + rw * 0.25, z0, z1, MARKING_WIDTH)
		_add_solid_line_z(st, cx - rw * 0.5 + ehw, z0, z1, EDGE_LINE_WIDTH)
		_add_solid_line_z(st, cx + rw * 0.5 - ehw, z0, z1, EDGE_LINE_WIDTH)
	elif idx == _grid.ALLEY_INDEX:
		# Alley (4m): dashed center only
		_add_dashed_line_z(st, cx, z0, z1, MARKING_WIDTH)
	else:
		# Standard (8m): dashed center + 2 edge lines
		_add_dashed_line_z(st, cx, z0, z1, MARKING_WIDTH)
		_add_solid_line_z(st, cx - rw * 0.5 + ehw, z0, z1, EDGE_LINE_WIDTH)
		_add_solid_line_z(st, cx + rw * 0.5 - ehw, z0, z1, EDGE_LINE_WIDTH)


func _add_ew_road_markings(
	st: SurfaceTool, cz: float, x0: float, x1: float, rw: float, idx: int
) -> void:
	var hw := MARKING_WIDTH * 0.5
	var ehw := EDGE_LINE_WIDTH * 0.5

	if idx == _grid.BOULEVARD_INDEX:
		_add_solid_line_x(st, cz - hw * 2.0, x0, x1, MARKING_WIDTH)
		_add_solid_line_x(st, cz + hw * 2.0, x0, x1, MARKING_WIDTH)
		_add_dashed_line_x(st, cz - rw * 0.25, x0, x1, MARKING_WIDTH)
		_add_dashed_line_x(st, cz + rw * 0.25, x0, x1, MARKING_WIDTH)
		_add_solid_line_x(st, cz - rw * 0.5 + ehw, x0, x1, EDGE_LINE_WIDTH)
		_add_solid_line_x(st, cz + rw * 0.5 - ehw, x0, x1, EDGE_LINE_WIDTH)
	elif idx == _grid.ALLEY_INDEX:
		_add_dashed_line_x(st, cz, x0, x1, MARKING_WIDTH)
	else:
		_add_dashed_line_x(st, cz, x0, x1, MARKING_WIDTH)
		_add_solid_line_x(st, cz - rw * 0.5 + ehw, x0, x1, EDGE_LINE_WIDTH)
		_add_solid_line_x(st, cz + rw * 0.5 - ehw, x0, x1, EDGE_LINE_WIDTH)


# --- Pedestrian crossings ---


func _build_crossings(st: SurfaceTool, ox: float, oz: float) -> void:
	# At every NS/EW road intersection, add 4 zebra crossings
	for i in range(_grid.GRID_SIZE + 1):
		var ns_cx: float = _grid.get_road_center_local(i) + ox
		var ns_rw: float = _grid.get_road_width(i)
		for j in range(_grid.GRID_SIZE + 1):
			var ew_cz: float = _grid.get_road_center_local(j) + oz
			var ew_rw: float = _grid.get_road_width(j)
			# North approach (crossing spans NS road width, set back in -Z)
			_add_zebra_x(st, ns_cx, ew_cz - ew_rw * 0.5 - CROSSING_SETBACK, ns_rw)
			# South approach
			_add_zebra_x(st, ns_cx, ew_cz + ew_rw * 0.5 + CROSSING_SETBACK, ns_rw)
			# West approach (crossing spans EW road width, set back in -X)
			_add_zebra_z(st, ns_cx - ns_rw * 0.5 - CROSSING_SETBACK, ew_cz, ew_rw)
			# East approach
			_add_zebra_z(st, ns_cx + ns_rw * 0.5 + CROSSING_SETBACK, ew_cz, ew_rw)


# --- Line helpers ---


func _add_dashed_line_z(st: SurfaceTool, x: float, z0: float, z1: float, width: float) -> void:
	var hw := width * 0.5
	var z := z0 + 1.0  # small offset from intersection
	while z + DASH_LENGTH < z1 - 1.0:
		_city_script.st_add_quad_xz(st, x, z + DASH_LENGTH * 0.5, hw, DASH_LENGTH * 0.5, MARKING_Y)
		z += DASH_LENGTH + DASH_GAP


func _add_dashed_line_x(st: SurfaceTool, z: float, x0: float, x1: float, width: float) -> void:
	var hw := width * 0.5
	var x := x0 + 1.0
	while x + DASH_LENGTH < x1 - 1.0:
		_city_script.st_add_quad_xz(st, x + DASH_LENGTH * 0.5, z, DASH_LENGTH * 0.5, hw, MARKING_Y)
		x += DASH_LENGTH + DASH_GAP


func _add_solid_line_z(st: SurfaceTool, x: float, z0: float, z1: float, width: float) -> void:
	var hw := width * 0.5
	var len := z1 - z0 - 2.0  # small margin
	if len <= 0.0:
		return
	var cz := (z0 + z1) * 0.5
	_city_script.st_add_quad_xz(st, x, cz, hw, len * 0.5, MARKING_Y)


func _add_solid_line_x(st: SurfaceTool, z: float, x0: float, x1: float, width: float) -> void:
	var hw := width * 0.5
	var len := x1 - x0 - 2.0
	if len <= 0.0:
		return
	var cx := (x0 + x1) * 0.5
	_city_script.st_add_quad_xz(st, cx, z, len * 0.5, hw, MARKING_Y)


# --- Zebra crossing helpers ---


func _add_zebra_x(st: SurfaceTool, cx: float, cz: float, road_width: float) -> void:
	# Bars perpendicular to NS traffic (running along X), spanning road width
	var bar_hw := road_width * 0.5 - 0.5  # slight inset from road edge
	var bar_hh := CROSSING_BAR_WIDTH * 0.5
	var total := CROSSING_BAR_LENGTH
	var bar_step := CROSSING_BAR_WIDTH + CROSSING_BAR_GAP
	var num_bars := int(total / bar_step)
	var start_z := cz - (num_bars - 1) * bar_step * 0.5

	for b in range(num_bars):
		var bz := start_z + b * bar_step
		_city_script.st_add_quad_xz(st, cx, bz, bar_hw, bar_hh, MARKING_Y)


func _add_zebra_z(st: SurfaceTool, cx: float, cz: float, road_width: float) -> void:
	# Bars perpendicular to EW traffic (running along Z), spanning road width
	var bar_hw := CROSSING_BAR_WIDTH * 0.5
	var bar_hh := road_width * 0.5 - 0.5
	var total := CROSSING_BAR_LENGTH
	var bar_step := CROSSING_BAR_WIDTH + CROSSING_BAR_GAP
	var num_bars := int(total / bar_step)
	var start_x := cx - (num_bars - 1) * bar_step * 0.5

	for b in range(num_bars):
		var bx := start_x + b * bar_step
		_city_script.st_add_quad_xz(st, bx, cz, bar_hw, bar_hh, MARKING_Y)
