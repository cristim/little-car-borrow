extends GutTest
## Unit tests for chunk_builder_bridge.gd bridge deck and railing generation.

const BridgeScript = preload("res://scenes/world/generator/chunk_builder_bridge.gd")
const RoadGridScript = preload("res://src/road_grid.gd")
const BoundaryScript = preload("res://src/city_boundary.gd")

var _grid: RefCounted
var _noise: FastNoiseLite
var _boundary: RefCounted
var _builder: RefCounted
var _road_mat: StandardMaterial3D


func before_each() -> void:
	_grid = RoadGridScript.new()
	_noise = FastNoiseLite.new()
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 0.003
	_noise.fractal_octaves = 4
	_noise.fractal_lacunarity = 2.0
	_noise.fractal_gain = 0.5
	_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_noise.seed = 42

	_boundary = BoundaryScript.new()
	_boundary.init(_grid.get_grid_span(), _noise)

	_road_mat = StandardMaterial3D.new()
	_road_mat.albedo_color = Color(0.3, 0.3, 0.3)

	_builder = BridgeScript.new()
	_builder.init(_grid, _boundary, _road_mat)


# ================================================================
# Initialization
# ================================================================


func test_init_sets_grid() -> void:
	assert_not_null(_builder._grid, "init should set _grid")


func test_init_sets_boundary() -> void:
	assert_not_null(_builder._boundary, "init should set _boundary")


func test_init_sets_road_mat() -> void:
	assert_eq(
		_builder._road_mat,
		_road_mat,
		"init should store the provided road material",
	)


# ================================================================
# Constants
# ================================================================


func test_deck_width_constant() -> void:
	assert_eq(
		BridgeScript.DECK_WIDTH,
		10.0,
		"DECK_WIDTH should be 10.0",
	)


func test_deck_thickness_constant() -> void:
	assert_eq(
		BridgeScript.DECK_THICKNESS,
		0.4,
		"DECK_THICKNESS should be 0.4",
	)


func test_railing_height_constant() -> void:
	assert_eq(
		BridgeScript.RAILING_HEIGHT,
		1.0,
		"RAILING_HEIGHT should be 1.0",
	)


func test_highway_indices_constant() -> void:
	assert_eq(
		BridgeScript.HIGHWAY_INDICES,
		[0, 5],
		"HIGHWAY_INDICES should be [0, 5]",
	)


# ================================================================
# Build with empty river_data (early return)
# ================================================================


func test_build_empty_river_data_produces_no_children() -> void:
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	_builder.build(chunk, Vector2i(0, 0), 0.0, 0.0, {})

	assert_eq(
		chunk.get_child_count(),
		0,
		"Empty river_data should produce no children",
	)


# ================================================================
# Build on city tile (flat, ground height 0 - below 0.5 threshold)
# ================================================================


func test_build_no_bridge_on_flat_tile() -> void:
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	# City tile at origin: ground height is 0, which is < 0.5 threshold
	var river := {"entry_dir": 0, "exit_dir": 2, "width": 6.0}
	_builder.build(chunk, Vector2i(0, 0), 0.0, 0.0, river)

	assert_eq(
		chunk.get_child_count(),
		0,
		"Flat tile (h=0 < 0.5) should not produce bridge",
	)


# ================================================================
# Build on elevated tile (bridge expected)
# ================================================================


func test_build_creates_bridge_on_elevated_tile() -> void:
	var span: float = _grid.get_grid_span()
	var found_bridge := false
	var river := {"entry_dir": 0, "exit_dir": 2, "width": 6.0}

	for tx in range(4, 15):
		for tz in [-2, 0, 2]:
			var chunk := Node3D.new()
			add_child_autofree(chunk)
			var tile := Vector2i(tx, tz)
			(
				_builder
				. build(
					chunk,
					tile,
					span * float(tx),
					span * float(tz),
					river,
				)
			)
			for child in chunk.get_children():
				if child is StaticBody3D and child.name == "Bridges":
					found_bridge = true
					break
			if found_bridge:
				break
		if found_bridge:
			break

	assert_true(
		found_bridge,
		"At least one elevated tile should produce a Bridges body",
	)


func test_bridge_body_in_road_group() -> void:
	var span: float = _grid.get_grid_span()
	var river := {"entry_dir": 0, "exit_dir": 2, "width": 6.0}

	for tx in range(4, 15):
		for tz in [-2, 0, 2]:
			var chunk := Node3D.new()
			add_child_autofree(chunk)
			var tile := Vector2i(tx, tz)
			(
				_builder
				. build(
					chunk,
					tile,
					span * float(tx),
					span * float(tz),
					river,
				)
			)
			for child in chunk.get_children():
				if child is StaticBody3D and child.name == "Bridges":
					assert_true(
						child.is_in_group("Road"),
						"Bridges body should be in Road group for GEVP",
					)
					return

	pass_test("No elevated tile found in range")


func test_bridge_body_collision_layer() -> void:
	var span: float = _grid.get_grid_span()
	var river := {"entry_dir": 0, "exit_dir": 2, "width": 6.0}

	for tx in range(4, 15):
		for tz in [-2, 0, 2]:
			var chunk := Node3D.new()
			add_child_autofree(chunk)
			var tile := Vector2i(tx, tz)
			(
				_builder
				. build(
					chunk,
					tile,
					span * float(tx),
					span * float(tz),
					river,
				)
			)
			for child in chunk.get_children():
				if child is StaticBody3D and child.name == "Bridges":
					assert_eq(
						child.collision_layer,
						1,
						"Bridges collision_layer should be 1 (Ground)",
					)
					assert_eq(
						child.collision_mask,
						0,
						"Bridges collision_mask should be 0",
					)
					return

	pass_test("No elevated tile found in range")


func test_bridge_has_mesh_child() -> void:
	var span: float = _grid.get_grid_span()
	var river := {"entry_dir": 0, "exit_dir": 2, "width": 6.0}

	for tx in range(4, 15):
		for tz in [-2, 0, 2]:
			var chunk := Node3D.new()
			add_child_autofree(chunk)
			var tile := Vector2i(tx, tz)
			(
				_builder
				. build(
					chunk,
					tile,
					span * float(tx),
					span * float(tz),
					river,
				)
			)
			for child in chunk.get_children():
				if child is StaticBody3D and child.name == "Bridges":
					var found_deck := false
					for sub in child.get_children():
						if sub is MeshInstance3D and sub.name == "BridgeDeck":
							found_deck = true
							break
					assert_true(
						found_deck,
						"Bridges body should contain BridgeDeck mesh",
					)
					return

	pass_test("No elevated tile found in range")


func test_bridge_deck_uses_road_material() -> void:
	var span: float = _grid.get_grid_span()
	var river := {"entry_dir": 0, "exit_dir": 2, "width": 6.0}

	for tx in range(4, 15):
		for tz in [-2, 0, 2]:
			var chunk := Node3D.new()
			add_child_autofree(chunk)
			var tile := Vector2i(tx, tz)
			(
				_builder
				. build(
					chunk,
					tile,
					span * float(tx),
					span * float(tz),
					river,
				)
			)
			for child in chunk.get_children():
				if child is StaticBody3D and child.name == "Bridges":
					for sub in child.get_children():
						if sub is MeshInstance3D and sub.name == "BridgeDeck":
							assert_eq(
								sub.material_override,
								_road_mat,
								"BridgeDeck should use road material",
							)
							return

	pass_test("No elevated tile found in range")


# ================================================================
# Determinism
# ================================================================


func test_build_deterministic_same_tile() -> void:
	var span: float = _grid.get_grid_span()
	var tile := Vector2i(8, 2)
	var ox: float = span * 8.0
	var oz: float = span * 2.0
	var river := {"entry_dir": 0, "exit_dir": 2, "width": 6.0}

	var chunk1 := Node3D.new()
	add_child_autofree(chunk1)
	_builder.build(chunk1, tile, ox, oz, river)

	var chunk2 := Node3D.new()
	add_child_autofree(chunk2)
	_builder.build(chunk2, tile, ox, oz, river)

	assert_eq(
		chunk1.get_child_count(),
		chunk2.get_child_count(),
		"Same tile should produce same child count",
	)


# ================================================================
# CRIT-02/03 — Bridge uses river position data; old h_ns > 0.5 block removed
# ================================================================


func test_bridge_reads_river_position_field() -> void:
	var src: String = (BridgeScript as GDScript).source_code
	assert_true(
		src.contains('river_data.get("position"'),
		"Bridge must read river position from river_data",
	)


func test_bridge_uses_river_orientation_booleans() -> void:
	var src: String = (BridgeScript as GDScript).source_code
	assert_true(
		src.contains("river_ns") and src.contains("river_ew"),
		"Bridge must use river_ns/river_ew booleans to select crossing type",
	)


func test_bridge_no_longer_uses_arbitrary_height_threshold() -> void:
	var src: String = (BridgeScript as GDScript).source_code
	assert_false(
		src.contains("h_ns > 0.5") or src.contains("h_ew > 0.5"),
		"Old arbitrary height threshold must be removed",
	)


func test_bridge_has_sea_level_constant() -> void:
	assert_true(
		BridgeScript.SEA_LEVEL < 0.0,
		"Bridge builder must define a negative SEA_LEVEL constant",
	)
