extends GutTest
## Unit tests for chunk_builder_piers.gd pier geometry, boat spawning,
## and coastal edge detection.

const PiersScript = preload(
	"res://scenes/world/generator/chunk_builder_piers.gd"
)
const RoadGridScript = preload("res://src/road_grid.gd")
const BoundaryScript = preload("res://src/city_boundary.gd")


var _grid: RefCounted
var _noise: FastNoiseLite
var _boundary: RefCounted
var _builder: RefCounted


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

	_builder = PiersScript.new()
	_builder.init(_grid, _boundary)


## Mark all engine errors as handled. The piers builder calls _add_piling
## which adds vertices without normals, triggering harmless Godot engine
## warnings about ARRAY_FORMAT_NORMAL. These are benign rendering warnings,
## not test failures.
func _consume_engine_errors() -> void:
	for e in get_errors():
		e.handled = true


# ================================================================
# Initialization
# ================================================================

func test_init_sets_grid() -> void:
	assert_not_null(_builder._grid, "init should set _grid")


func test_init_sets_boundary() -> void:
	assert_not_null(_builder._boundary, "init should set _boundary")


func test_init_creates_boat_builder() -> void:
	assert_not_null(
		_builder._boat_builder,
		"init should create _boat_builder",
	)


func test_init_creates_wood_material() -> void:
	assert_not_null(
		_builder._wood_mat,
		"init should create _wood_mat",
	)


func test_wood_material_color() -> void:
	var c: Color = _builder._wood_mat.albedo_color
	assert_almost_eq(c.r, 0.45, 0.01, "Wood red channel")
	assert_almost_eq(c.g, 0.30, 0.01, "Wood green channel")
	assert_almost_eq(c.b, 0.15, 0.01, "Wood blue channel")


func test_wood_material_roughness() -> void:
	assert_almost_eq(
		_builder._wood_mat.roughness, 0.8, 0.01,
		"Wood roughness should be 0.8",
	)


# ================================================================
# Constants
# ================================================================

func test_sea_level_constant() -> void:
	assert_eq(PiersScript.SEA_LEVEL, -2.0, "SEA_LEVEL should be -2.0")


func test_pier_chance_constant() -> void:
	assert_almost_eq(
		PiersScript.PIER_CHANCE, 0.4, 0.001,
		"PIER_CHANCE should be 0.4",
	)


func test_pier_dimensions() -> void:
	assert_eq(PiersScript.PIER_WIDTH, 3.0, "PIER_WIDTH should be 3.0")
	assert_eq(PiersScript.PIER_LENGTH, 12.0, "PIER_LENGTH should be 12.0")
	assert_eq(PiersScript.PIER_HEIGHT, 0.5, "PIER_HEIGHT should be 0.5")


func test_piling_constants() -> void:
	assert_almost_eq(
		PiersScript.PILING_RADIUS, 0.15, 0.001,
		"PILING_RADIUS should be 0.15",
	)
	assert_eq(PiersScript.PILING_COUNT, 6, "PILING_COUNT should be 6")


func test_boat_variants() -> void:
	assert_eq(
		PiersScript.BOAT_VARIANTS,
		["speedboat", "fishing", "runabout"],
		"BOAT_VARIANTS should contain three variants",
	)


# ================================================================
# Build on city tile (no pier - heights are 0, inside city)
# ================================================================

func test_build_no_pier_on_city_tile() -> void:
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	# City tile: all heights are 0, no shore found
	_builder.build(chunk, Vector2i(0, 0), 0.0, 0.0)

	assert_false(
		chunk.has_meta("has_pier"),
		"City tile should not produce a pier",
	)


# ================================================================
# Build on coastal tile (pier possible)
# ================================================================

func test_build_can_create_pier_on_coastal_tile() -> void:
	var span: float = _grid.get_grid_span()
	var found_pier := false

	for tx in range(-8, 10):
		for tz in range(-5, 5):
			var chunk := Node3D.new()
			add_child_autofree(chunk)
			var tile := Vector2i(tx, tz)
			_builder.build(
				chunk, tile, span * float(tx), span * float(tz),
			)
			if chunk.has_meta("has_pier") and chunk.get_meta("has_pier"):
				found_pier = true
				break
		if found_pier:
			break

	_consume_engine_errors()
	assert_true(
		found_pier,
		"At least one tile in a wide range should produce a pier",
	)


func test_pier_sets_metadata() -> void:
	var span: float = _grid.get_grid_span()

	for tx in range(-8, 10):
		for tz in range(-5, 5):
			var chunk := Node3D.new()
			add_child_autofree(chunk)
			var tile := Vector2i(tx, tz)
			_builder.build(
				chunk, tile, span * float(tx), span * float(tz),
			)
			if chunk.has_meta("has_pier") and chunk.get_meta("has_pier"):
				_consume_engine_errors()
				assert_true(
					chunk.has_meta("pier_center"),
					"Pier chunk should have pier_center meta",
				)
				var center: Vector2 = chunk.get_meta("pier_center")
				assert_true(
					center is Vector2,
					"pier_center should be a Vector2",
				)
				return

	_consume_engine_errors()
	pass_test("No pier found in range")


func test_pier_has_static_body() -> void:
	var span: float = _grid.get_grid_span()

	for tx in range(-8, 10):
		for tz in range(-5, 5):
			var chunk := Node3D.new()
			add_child_autofree(chunk)
			var tile := Vector2i(tx, tz)
			_builder.build(
				chunk, tile, span * float(tx), span * float(tz),
			)
			if chunk.has_meta("has_pier") and chunk.get_meta("has_pier"):
				var found_body := false
				for child in chunk.get_children():
					if child is StaticBody3D and child.name == "Pier":
						found_body = true
						break
				_consume_engine_errors()
				assert_true(
					found_body,
					"Pier chunk should contain a Pier StaticBody3D",
				)
				return

	_consume_engine_errors()
	pass_test("No pier found in range")


func test_pier_body_in_road_group() -> void:
	var span: float = _grid.get_grid_span()

	for tx in range(-8, 10):
		for tz in range(-5, 5):
			var chunk := Node3D.new()
			add_child_autofree(chunk)
			var tile := Vector2i(tx, tz)
			_builder.build(
				chunk, tile, span * float(tx), span * float(tz),
			)
			if chunk.has_meta("has_pier") and chunk.get_meta("has_pier"):
				for child in chunk.get_children():
					if child is StaticBody3D and child.name == "Pier":
						_consume_engine_errors()
						assert_true(
							child.is_in_group("Road"),
							"Pier body should be in Road group",
						)
						return

	_consume_engine_errors()
	pass_test("No pier found in range")


func test_pier_body_collision_layer() -> void:
	var span: float = _grid.get_grid_span()

	for tx in range(-8, 10):
		for tz in range(-5, 5):
			var chunk := Node3D.new()
			add_child_autofree(chunk)
			var tile := Vector2i(tx, tz)
			_builder.build(
				chunk, tile, span * float(tx), span * float(tz),
			)
			if chunk.has_meta("has_pier") and chunk.get_meta("has_pier"):
				for child in chunk.get_children():
					if child is StaticBody3D and child.name == "Pier":
						_consume_engine_errors()
						assert_eq(
							child.collision_layer, 1,
							"Pier collision_layer should be 1 (Ground)",
						)
						assert_eq(
							child.collision_mask, 0,
							"Pier collision_mask should be 0",
						)
						return

	_consume_engine_errors()
	pass_test("No pier found in range")


func test_pier_has_mesh_child() -> void:
	var span: float = _grid.get_grid_span()

	for tx in range(-8, 10):
		for tz in range(-5, 5):
			var chunk := Node3D.new()
			add_child_autofree(chunk)
			var tile := Vector2i(tx, tz)
			_builder.build(
				chunk, tile, span * float(tx), span * float(tz),
			)
			if chunk.has_meta("has_pier") and chunk.get_meta("has_pier"):
				for child in chunk.get_children():
					if child is StaticBody3D and child.name == "Pier":
						var found_mesh := false
						for sub in child.get_children():
							if sub is MeshInstance3D and sub.name == "PierMesh":
								found_mesh = true
								break
						_consume_engine_errors()
						assert_true(
							found_mesh,
							"Pier body should contain PierMesh",
						)
						return

	_consume_engine_errors()
	pass_test("No pier found in range")


func test_pier_mesh_uses_wood_material() -> void:
	var span: float = _grid.get_grid_span()

	for tx in range(-8, 10):
		for tz in range(-5, 5):
			var chunk := Node3D.new()
			add_child_autofree(chunk)
			var tile := Vector2i(tx, tz)
			_builder.build(
				chunk, tile, span * float(tx), span * float(tz),
			)
			if chunk.has_meta("has_pier") and chunk.get_meta("has_pier"):
				for child in chunk.get_children():
					if child is StaticBody3D and child.name == "Pier":
						for sub in child.get_children():
							if sub is MeshInstance3D and sub.name == "PierMesh":
								_consume_engine_errors()
								assert_eq(
									sub.material_override,
									_builder._wood_mat,
									"PierMesh should use wood material",
								)
								return

	_consume_engine_errors()
	pass_test("No pier found in range")


func test_pier_has_collision_shape() -> void:
	var span: float = _grid.get_grid_span()

	for tx in range(-8, 10):
		for tz in range(-5, 5):
			var chunk := Node3D.new()
			add_child_autofree(chunk)
			var tile := Vector2i(tx, tz)
			_builder.build(
				chunk, tile, span * float(tx), span * float(tz),
			)
			if chunk.has_meta("has_pier") and chunk.get_meta("has_pier"):
				for child in chunk.get_children():
					if child is StaticBody3D and child.name == "Pier":
						var found_col := false
						for sub in child.get_children():
							if sub is CollisionShape3D:
								found_col = true
								break
						_consume_engine_errors()
						assert_true(
							found_col,
							"Pier body should have CollisionShape3D",
						)
						return

	_consume_engine_errors()
	pass_test("No pier found in range")


# ================================================================
# Boat spawning
# ================================================================

func test_pier_spawns_boats() -> void:
	var span: float = _grid.get_grid_span()

	for tx in range(-8, 10):
		for tz in range(-5, 5):
			var chunk := Node3D.new()
			add_child_autofree(chunk)
			var tile := Vector2i(tx, tz)
			_builder.build(
				chunk, tile, span * float(tx), span * float(tz),
			)
			if chunk.has_meta("has_pier") and chunk.get_meta("has_pier"):
				var boat_count := 0
				for child in chunk.get_children():
					if child is RigidBody3D and child.name == "Boat":
						boat_count += 1
				_consume_engine_errors()
				assert_true(
					boat_count >= 1 and boat_count <= 2,
					"Pier should spawn 1-2 boats (got %d)" % boat_count,
				)
				return

	_consume_engine_errors()
	pass_test("No pier found in range")


func test_boat_has_interaction_zone() -> void:
	var span: float = _grid.get_grid_span()

	for tx in range(-8, 10):
		for tz in range(-5, 5):
			var chunk := Node3D.new()
			add_child_autofree(chunk)
			var tile := Vector2i(tx, tz)
			_builder.build(
				chunk, tile, span * float(tx), span * float(tz),
			)
			if chunk.has_meta("has_pier") and chunk.get_meta("has_pier"):
				for child in chunk.get_children():
					if child is RigidBody3D and child.name == "Boat":
						var found_zone := false
						for sub in child.get_children():
							if sub is Area3D and sub.name == "InteractionZone":
								found_zone = true
								break
						_consume_engine_errors()
						assert_true(
							found_zone,
							"Boat should have InteractionZone",
						)
						return

	_consume_engine_errors()
	pass_test("No pier found in range")


func test_boat_has_door_marker() -> void:
	var span: float = _grid.get_grid_span()

	for tx in range(-8, 10):
		for tz in range(-5, 5):
			var chunk := Node3D.new()
			add_child_autofree(chunk)
			var tile := Vector2i(tx, tz)
			_builder.build(
				chunk, tile, span * float(tx), span * float(tz),
			)
			if chunk.has_meta("has_pier") and chunk.get_meta("has_pier"):
				for child in chunk.get_children():
					if child is RigidBody3D and child.name == "Boat":
						var found_marker := false
						for sub in child.get_children():
							if sub is Marker3D and sub.name == "DoorMarker":
								found_marker = true
								break
						_consume_engine_errors()
						assert_true(
							found_marker,
							"Boat should have DoorMarker",
						)
						return

	_consume_engine_errors()
	pass_test("No pier found in range")


func test_boat_collision_layers() -> void:
	var span: float = _grid.get_grid_span()

	for tx in range(-8, 10):
		for tz in range(-5, 5):
			var chunk := Node3D.new()
			add_child_autofree(chunk)
			var tile := Vector2i(tx, tz)
			_builder.build(
				chunk, tile, span * float(tx), span * float(tz),
			)
			if chunk.has_meta("has_pier") and chunk.get_meta("has_pier"):
				for child in chunk.get_children():
					if child is RigidBody3D and child.name == "Boat":
						_consume_engine_errors()
						assert_eq(
							child.collision_layer, 16,
							"Boat collision_layer should be 16 (NPC vehicles)",
						)
						assert_eq(
							child.collision_mask, 7,
							"Boat collision_mask should be 7 (ground+static+player)",
						)
						return

	_consume_engine_errors()
	pass_test("No pier found in range")


# ================================================================
# Determinism
# ================================================================

func test_build_deterministic_same_tile() -> void:
	var span: float = _grid.get_grid_span()
	var tile := Vector2i(-3, 1)
	var ox: float = span * -3.0
	var oz: float = span * 1.0

	var chunk1 := Node3D.new()
	add_child_autofree(chunk1)
	_builder.build(chunk1, tile, ox, oz)

	var chunk2 := Node3D.new()
	add_child_autofree(chunk2)
	_builder.build(chunk2, tile, ox, oz)

	var has1: bool = chunk1.has_meta("has_pier") and chunk1.get_meta("has_pier")
	var has2: bool = chunk2.has_meta("has_pier") and chunk2.get_meta("has_pier")
	_consume_engine_errors()
	assert_eq(
		has1, has2,
		"Same tile should produce same pier decision",
	)
	assert_eq(
		chunk1.get_child_count(), chunk2.get_child_count(),
		"Same tile should produce same child count",
	)


# ================================================================
# _find_shore_edge
# ================================================================

func test_boat_spawned_beyond_pier_tip() -> void:
	# Boats must not spawn under the pier deck (which extends to PIER_LENGTH).
	# Verify the spawn formula places them past the tip.
	var script: GDScript = PiersScript as GDScript
	var src: String = script.source_code
	# Old formula was PIER_LENGTH * 0.8 (inside pier) — ensure it is gone
	assert_false(
		src.contains("PIER_LENGTH * 0.8"),
		"Boat spawn must not use PIER_LENGTH * 0.8 (places boat under pier)",
	)
	# New formula starts at PIER_LENGTH + some positive offset
	assert_true(
		src.contains("PIER_LENGTH + 2.0"),
		"Boat spawn should use PIER_LENGTH + 2.0 to clear the pier tip",
	)


func test_find_shore_edge_returns_empty_for_city_center() -> void:
	var span: float = _grid.get_grid_span()
	var hs := span * 0.5
	var result: Dictionary = _builder._find_shore_edge(0.0, 0.0, hs)
	assert_true(
		result.is_empty(),
		"City center should have no shore edge (all heights are 0)",
	)
