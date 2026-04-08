extends RefCounted
## Builds bridges where roads cross rivers.
## Flat road deck + simple railings, deck in "Road" group for vehicles.

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

		# N-S road crossing
		var h_ns: float = _boundary.get_ground_height(road_cx, oz)
		if h_ns > 0.5:
			var bridge_len: float = rw * 2.0
			var center := Vector3(
				road_cx,
				h_ns + DECK_THICKNESS * 0.5,
				oz,
			)
			var deck_size := Vector3(
				DECK_WIDTH,
				DECK_THICKNESS,
				bridge_len,
			)
			_city_script.st_add_box(st, center, deck_size)
			_city_script.add_box_collision(body, center, deck_size)
			has_verts = true

			# Railings
			var rail_y: float = h_ns + DECK_THICKNESS + RAILING_HEIGHT * 0.5
			(
				_city_script
				. st_add_box(
					st,
					Vector3(
						road_cx - DECK_WIDTH * 0.5,
						rail_y,
						oz,
					),
					Vector3(
						RAILING_THICKNESS,
						RAILING_HEIGHT,
						bridge_len,
					),
				)
			)
			(
				_city_script
				. st_add_box(
					st,
					Vector3(
						road_cx + DECK_WIDTH * 0.5,
						rail_y,
						oz,
					),
					Vector3(
						RAILING_THICKNESS,
						RAILING_HEIGHT,
						bridge_len,
					),
				)
			)

		# E-W road crossing
		var h_ew: float = _boundary.get_ground_height(ox, road_cz)
		if h_ew > 0.5:
			var bridge_len: float = rw * 2.0
			var center := Vector3(
				ox,
				h_ew + DECK_THICKNESS * 0.5,
				road_cz,
			)
			var deck_size := Vector3(
				bridge_len,
				DECK_THICKNESS,
				DECK_WIDTH,
			)
			_city_script.st_add_box(st, center, deck_size)
			_city_script.add_box_collision(body, center, deck_size)
			has_verts = true

			# Railings
			var rail_y: float = h_ew + DECK_THICKNESS + RAILING_HEIGHT * 0.5
			(
				_city_script
				. st_add_box(
					st,
					Vector3(
						ox,
						rail_y,
						road_cz - DECK_WIDTH * 0.5,
					),
					Vector3(
						bridge_len,
						RAILING_HEIGHT,
						RAILING_THICKNESS,
					),
				)
			)
			(
				_city_script
				. st_add_box(
					st,
					Vector3(
						ox,
						rail_y,
						road_cz + DECK_WIDTH * 0.5,
					),
					Vector3(
						bridge_len,
						RAILING_HEIGHT,
						RAILING_THICKNESS,
					),
				)
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
