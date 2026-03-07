extends RefCounted
## Builds streetlight poles along roads in each chunk using MultiMesh.
## Uses emissive material for glow effect instead of OmniLight3D (performance).
## Creates 2 MultiMeshInstance3D per chunk (poles + lamps) in "streetlight" group.

const POLE_HEIGHT := 3.5
const POLE_RADIUS := 0.075
const LAMP_RADIUS := 0.2
const LAMP_COLOR := Color(1.0, 0.9, 0.6)

var _grid: RefCounted
var _pole_mat: StandardMaterial3D
var _lamp_mat: StandardMaterial3D
var _pole_mesh: CylinderMesh
var _lamp_mesh: SphereMesh


func init(grid: RefCounted, pole_mat: StandardMaterial3D) -> void:
	_grid = grid
	_pole_mat = pole_mat

	# Emissive lamp material
	_lamp_mat = StandardMaterial3D.new()
	_lamp_mat.albedo_color = LAMP_COLOR
	_lamp_mat.emission_enabled = true
	_lamp_mat.emission = LAMP_COLOR
	_lamp_mat.emission_energy_multiplier = 2.0

	# Shared meshes for all instances
	_pole_mesh = CylinderMesh.new()
	_pole_mesh.top_radius = POLE_RADIUS
	_pole_mesh.bottom_radius = POLE_RADIUS
	_pole_mesh.height = POLE_HEIGHT
	_pole_mesh.radial_segments = 4
	_pole_mesh.rings = 1
	_pole_mesh.material = _pole_mat

	_lamp_mesh = SphereMesh.new()
	_lamp_mesh.radius = LAMP_RADIUS
	_lamp_mesh.height = LAMP_RADIUS * 2.0
	_lamp_mesh.radial_segments = 6
	_lamp_mesh.rings = 3
	_lamp_mesh.material = _lamp_mat


func build(chunk: Node3D, ox: float, oz: float) -> void:
	var positions: Array[Vector3] = []

	# Collect positions along N-S roads (every other intersection)
	for ri in range(_grid.GRID_SIZE + 1):
		var rx: float = _grid.get_road_center_local(ri) + ox
		var rw: float = _grid.get_road_width(ri)
		var offset: float = rw * 0.5 + 1.0

		for ci in range(0, _grid.GRID_SIZE + 1, 2):
			var cz: float = (
				_grid.get_road_center_local(ci) + oz
			)
			positions.append(Vector3(rx + offset, 0.0, cz))

	# Collect positions along E-W roads (every other intersection)
	for ri in range(_grid.GRID_SIZE + 1):
		var rz: float = _grid.get_road_center_local(ri) + oz
		var rw: float = _grid.get_road_width(ri)
		var offset: float = rw * 0.5 + 1.0

		for ci in range(1, _grid.GRID_SIZE + 1, 2):
			var cx: float = (
				_grid.get_road_center_local(ci) + ox
			)
			positions.append(Vector3(cx, 0.0, rz + offset))

	if positions.is_empty():
		return

	var count := positions.size()
	var show_lights := (
		DayNightManager.is_night() or DayNightManager.is_dusk_or_dawn()
	)

	# Poles MultiMesh
	var pole_mm := MultiMesh.new()
	pole_mm.transform_format = MultiMesh.TRANSFORM_3D
	pole_mm.instance_count = count
	pole_mm.mesh = _pole_mesh
	for i in range(count):
		var pos := positions[i]
		pole_mm.set_instance_transform(
			i, Transform3D(Basis.IDENTITY, Vector3(pos.x, POLE_HEIGHT * 0.5, pos.z))
		)
	var pole_node := MultiMeshInstance3D.new()
	pole_node.name = "StreetlightPoles"
	pole_node.multimesh = pole_mm
	pole_node.visible = show_lights
	pole_node.add_to_group("streetlight")
	chunk.add_child(pole_node)

	# Lamps MultiMesh
	var lamp_mm := MultiMesh.new()
	lamp_mm.transform_format = MultiMesh.TRANSFORM_3D
	lamp_mm.instance_count = count
	lamp_mm.mesh = _lamp_mesh
	for i in range(count):
		var pos := positions[i]
		lamp_mm.set_instance_transform(
			i, Transform3D(Basis.IDENTITY, Vector3(pos.x, POLE_HEIGHT, pos.z))
		)
	var lamp_node := MultiMeshInstance3D.new()
	lamp_node.name = "StreetlightLamps"
	lamp_node.multimesh = lamp_mm
	lamp_node.visible = show_lights
	lamp_node.add_to_group("streetlight")
	chunk.add_child(lamp_node)
