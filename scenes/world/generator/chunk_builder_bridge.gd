extends RefCounted
## Builds bridges where roads cross rivers.
## Flat road deck + simple railings, deck in "Road" group for vehicles.

const SEA_LEVEL := -2.0
const MIN_BRIDGE_HEIGHT := 0.5  # bridges only on elevated terrain, not flat city ground
const DECK_WIDTH := 10.0
const DECK_THICKNESS := 0.4
const RAILING_HEIGHT := 1.0
const RAILING_THICKNESS := 0.15
const HIGHWAY_INDICES := [0, 5]

var _grid: RefCounted
var _boundary: RefCounted
var _road_mat: StandardMaterial3D
var _city_script: GDScript = preload("res://scenes/world/city.gd")


func init(
	grid: RefCounted,
	boundary: RefCounted,
	road_mat: StandardMaterial3D,
) -> void:
	_grid = grid
	_boundary = boundary
	_road_mat = road_mat


func build(
	chunk: Node3D,
	_tile: Vector2i,
	ox: float,
	oz: float,
	river_data: Dictionary,
) -> void:
	if river_data.is_empty():
		return

	var span: float = _grid.get_grid_span()
	var r_pos: float = river_data.get("position", 0.5)
	var entry_dir: int = river_data.get("entry_dir", 0)
	var exit_dir: int = river_data.get("exit_dir", 2)
	var offset: float = (r_pos - 0.5) * span
	var river_ns: bool = entry_dir in [0, 2] and exit_dir in [0, 2]
	var river_ew: bool = entry_dir in [1, 3] and exit_dir in [1, 3]

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var has_verts := false

	var body := StaticBody3D.new()
	body.name = "Bridges"
	body.collision_layer = 1  # Ground layer
	body.collision_mask = 0
	body.add_to_group("Road")

	# Check each highway for river crossings
	for hi in HIGHWAY_INDICES:
		var rw: float = _grid.get_road_width(hi)
		var road_cx: float = _grid.get_road_center_local(hi) + ox
		var road_cz: float = _grid.get_road_center_local(hi) + oz

		# N-S road crossing an E-W river
		if river_ew:
			var river_z: float = oz + offset
			var h: float = _boundary.get_ground_height(road_cx, river_z)
			if h > MIN_BRIDGE_HEIGHT:
				var bridge_len: float = rw * 2.0
				var center := Vector3(road_cx, h + DECK_THICKNESS * 0.5, river_z)
				var deck_size := Vector3(DECK_WIDTH, DECK_THICKNESS, bridge_len)
				_city_script.st_add_box(st, center, deck_size)
				_city_script.add_box_collision(body, center, deck_size)
				has_verts = true

				var rail_y: float = h + DECK_THICKNESS + RAILING_HEIGHT * 0.5
				_city_script.st_add_box(
					st,
					Vector3(road_cx - DECK_WIDTH * 0.5, rail_y, river_z),
					Vector3(RAILING_THICKNESS, RAILING_HEIGHT, bridge_len),
				)
				_city_script.st_add_box(
					st,
					Vector3(road_cx + DECK_WIDTH * 0.5, rail_y, river_z),
					Vector3(RAILING_THICKNESS, RAILING_HEIGHT, bridge_len),
				)

		# E-W road crossing a N-S river
		if river_ns:
			var river_x: float = ox + offset
			var h: float = _boundary.get_ground_height(river_x, road_cz)
			if h > MIN_BRIDGE_HEIGHT:
				var bridge_len: float = rw * 2.0
				var center := Vector3(river_x, h + DECK_THICKNESS * 0.5, road_cz)
				var deck_size := Vector3(bridge_len, DECK_THICKNESS, DECK_WIDTH)
				_city_script.st_add_box(st, center, deck_size)
				_city_script.add_box_collision(body, center, deck_size)
				has_verts = true

				var rail_y: float = h + DECK_THICKNESS + RAILING_HEIGHT * 0.5
				_city_script.st_add_box(
					st,
					Vector3(river_x, rail_y, road_cz - DECK_WIDTH * 0.5),
					Vector3(bridge_len, RAILING_HEIGHT, RAILING_THICKNESS),
				)
				_city_script.st_add_box(
					st,
					Vector3(river_x, rail_y, road_cz + DECK_WIDTH * 0.5),
					Vector3(bridge_len, RAILING_HEIGHT, RAILING_THICKNESS),
				)

	if not has_verts:
		body.queue_free()
		return

	st.generate_normals()
	var mesh := st.commit()
	var inst := MeshInstance3D.new()
	inst.name = "BridgeDeck"
	inst.mesh = mesh
	inst.material_override = _road_mat
	body.add_child(inst)
	chunk.add_child(body)
