extends RefCounted
## Builds streetlights along roads in each chunk.
## One light per road segment at every other intersection.
## All lights added to "streetlight" group for day-night toggling.

const POLE_HEIGHT := 3.5
const POLE_RADIUS := 0.075
const LIGHT_RANGE := 12.0
const LIGHT_ENERGY := 0.6
const LIGHT_COLOR := Color(1.0, 0.9, 0.6)

var _grid: RefCounted
var _pole_mat: StandardMaterial3D


func init(grid: RefCounted, pole_mat: StandardMaterial3D) -> void:
	_grid = grid
	_pole_mat = pole_mat


func build(chunk: Node3D, ox: float, oz: float) -> void:
	var span: float = _grid.get_grid_span()
	var half_span := span * 0.5

	# Place lights along N-S roads (every other intersection)
	for ri in range(_grid.GRID_SIZE + 1):
		var rx: float = _grid.get_road_center_local(ri) + ox
		var rw: float = _grid.get_road_width(ri)
		var offset: float = rw * 0.5 + 1.0

		for ci in range(0, _grid.GRID_SIZE + 1, 2):
			var cz: float = (
				_grid.get_road_center_local(ci) + oz
			)
			_add_light(chunk, rx + offset, cz)

	# Place lights along E-W roads (every other intersection)
	for ri in range(_grid.GRID_SIZE + 1):
		var rz: float = _grid.get_road_center_local(ri) + oz
		var rw: float = _grid.get_road_width(ri)
		var offset: float = rw * 0.5 + 1.0

		for ci in range(1, _grid.GRID_SIZE + 1, 2):
			var cx: float = (
				_grid.get_road_center_local(ci) + ox
			)
			_add_light(chunk, cx, rz + offset)


func _add_light(chunk: Node3D, x: float, z: float) -> void:
	var root := Node3D.new()
	root.name = "Streetlight"
	root.position = Vector3(x, 0.0, z)
	root.visible = false  # starts hidden; day_night_environment toggles
	root.add_to_group("streetlight")

	# Pole mesh
	var pole := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = POLE_RADIUS
	cyl.bottom_radius = POLE_RADIUS
	cyl.height = POLE_HEIGHT
	cyl.radial_segments = 4
	cyl.rings = 1
	cyl.material = _pole_mat
	pole.mesh = cyl
	pole.position.y = POLE_HEIGHT * 0.5
	root.add_child(pole)

	# OmniLight at top
	var light := OmniLight3D.new()
	light.light_color = LIGHT_COLOR
	light.light_energy = LIGHT_ENERGY
	light.omni_range = LIGHT_RANGE
	light.shadow_enabled = false
	light.position.y = POLE_HEIGHT
	root.add_child(light)

	chunk.add_child(root)
