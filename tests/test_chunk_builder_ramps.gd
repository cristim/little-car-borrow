extends GutTest
## Unit tests for chunk_builder_ramps.gd stunt park generation.

const RampsScript = preload(
	"res://scenes/world/generator/chunk_builder_ramps.gd"
)
const RoadGridScript = preload("res://src/road_grid.gd")

var _grid: RefCounted
var _builder: RefCounted
var _ramp_mat: StandardMaterial3D


func before_each() -> void:
	_grid = RoadGridScript.new()
	_ramp_mat = StandardMaterial3D.new()
	_ramp_mat.albedo_color = Color(0.8, 0.3, 0.1)
	_builder = RampsScript.new()
	_builder.init(_grid, _ramp_mat)


# ================================================================
# Initialization
# ================================================================

func test_init_stores_grid() -> void:
	assert_eq(_builder._grid, _grid, "init should store grid reference")


func test_init_stores_ramp_mat() -> void:
	assert_eq(
		_builder._ramp_mat, _ramp_mat,
		"init should store ramp material",
	)


# ================================================================
# Determinism -- same tile always produces same output
# ================================================================

func test_build_deterministic_for_same_tile() -> void:
	var tile := Vector2i(3, 7)
	var ox: float = _grid.get_grid_span() * 3.0
	var oz: float = _grid.get_grid_span() * 7.0

	var chunk1 := Node3D.new()
	add_child_autofree(chunk1)
	_builder.build(chunk1, tile, ox, oz)

	var chunk2 := Node3D.new()
	add_child_autofree(chunk2)
	_builder.build(chunk2, tile, ox, oz)

	assert_eq(
		chunk1.get_child_count(), chunk2.get_child_count(),
		"Same tile should produce same child count",
	)

	var meta1: bool = chunk1.has_meta("has_stunt_park")
	var meta2: bool = chunk2.has_meta("has_stunt_park")
	assert_eq(meta1, meta2, "Same tile should produce same stunt park decision")


func test_different_tiles_can_differ() -> void:
	var span: float = _grid.get_grid_span()
	var results: Array[bool] = []
	for tx in range(50):
		var tile := Vector2i(tx + 200, tx * 5)
		var chunk := Node3D.new()
		add_child_autofree(chunk)
		_builder.build(chunk, tile, span * float(tile.x), span * float(tile.y))
		results.append(chunk.has_meta("has_stunt_park"))

	var all_same := true
	for r: bool in results:
		if r != results[0]:
			all_same = false
			break
	assert_false(
		all_same,
		"50 different tiles should not all produce the same result",
	)


# ================================================================
# ~90% of tiles produce no stunt park (probabilistic check)
# ================================================================

func test_most_tiles_have_no_stunt_park() -> void:
	var park_count := 0
	var total := 200
	var span: float = _grid.get_grid_span()
	for tx in range(total):
		var chunk := Node3D.new()
		add_child_autofree(chunk)
		var tile := Vector2i(tx + 100, tx * 3 + 50)
		_builder.build(chunk, tile, span * float(tile.x), span * float(tile.y))
		if chunk.has_meta("has_stunt_park"):
			park_count += 1

	assert_true(
		park_count < 50,
		"Too many stunt parks: %d / %d (expected ~10%%)" % [park_count, total],
	)
	assert_true(
		park_count > 0,
		"No stunt parks in %d tiles -- highly unlikely" % total,
	)


# ================================================================
# When a stunt park IS placed, verify structure
# ================================================================

func _find_stunt_park_tile() -> Vector2i:
	var span: float = _grid.get_grid_span()
	for tx in range(500):
		var tile := Vector2i(tx, tx * 7)
		var chunk := Node3D.new()
		add_child_autofree(chunk)
		_builder.build(chunk, tile, span * float(tile.x), span * float(tile.y))
		if chunk.has_meta("has_stunt_park"):
			return tile
	return Vector2i(-99999, -99999)


func test_stunt_park_has_fence_child() -> void:
	var tile := _find_stunt_park_tile()
	if tile == Vector2i(-99999, -99999):
		pass_test("No stunt park tile found")
		return

	var span: float = _grid.get_grid_span()
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	_builder.build(chunk, tile, span * float(tile.x), span * float(tile.y))

	var found_fence := false
	for child in chunk.get_children():
		if child is MeshInstance3D and child.name == "StuntParkFence":
			found_fence = true
			break
	assert_true(found_fence, "Stunt park should have a StuntParkFence mesh")


func test_stunt_park_has_ramp_children() -> void:
	var tile := _find_stunt_park_tile()
	if tile == Vector2i(-99999, -99999):
		pass_test("No stunt park tile found")
		return

	var span: float = _grid.get_grid_span()
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	_builder.build(chunk, tile, span * float(tile.x), span * float(tile.y))

	var ramp_count := 0
	for child in chunk.get_children():
		if child is StaticBody3D and child.name.begins_with("Ramp_"):
			ramp_count += 1
	assert_true(
		ramp_count >= 3 and ramp_count <= 6,
		"Stunt park should have 3-6 ramps, got %d" % ramp_count,
	)


func test_ramps_are_in_road_group() -> void:
	var tile := _find_stunt_park_tile()
	if tile == Vector2i(-99999, -99999):
		pass_test("No stunt park tile found")
		return

	var span: float = _grid.get_grid_span()
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	_builder.build(chunk, tile, span * float(tile.x), span * float(tile.y))

	for child in chunk.get_children():
		if child is StaticBody3D and child.name.begins_with("Ramp_"):
			assert_true(
				child.is_in_group("Road"),
				"Ramp %s should be in Road group" % child.name,
			)


func test_ramps_have_collision_shape() -> void:
	var tile := _find_stunt_park_tile()
	if tile == Vector2i(-99999, -99999):
		pass_test("No stunt park tile found")
		return

	var span: float = _grid.get_grid_span()
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	_builder.build(chunk, tile, span * float(tile.x), span * float(tile.y))

	for child in chunk.get_children():
		if child is StaticBody3D and child.name.begins_with("Ramp_"):
			var has_col := false
			for sub in child.get_children():
				if sub is CollisionShape3D:
					has_col = true
					assert_not_null(
						sub.shape, "CollisionShape3D should have a shape",
					)
			assert_true(
				has_col,
				"Ramp %s should have CollisionShape3D" % child.name,
			)


func test_ramps_have_mesh_instance() -> void:
	var tile := _find_stunt_park_tile()
	if tile == Vector2i(-99999, -99999):
		pass_test("No stunt park tile found")
		return

	var span: float = _grid.get_grid_span()
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	_builder.build(chunk, tile, span * float(tile.x), span * float(tile.y))

	for child in chunk.get_children():
		if child is StaticBody3D and child.name.begins_with("Ramp_"):
			var has_mesh := false
			for sub in child.get_children():
				if sub is MeshInstance3D:
					has_mesh = true
			assert_true(
				has_mesh,
				"Ramp %s should have MeshInstance3D" % child.name,
			)


func test_ramp_collision_tilted() -> void:
	var tile := _find_stunt_park_tile()
	if tile == Vector2i(-99999, -99999):
		pass_test("No stunt park tile found")
		return

	var span: float = _grid.get_grid_span()
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	_builder.build(chunk, tile, span * float(tile.x), span * float(tile.y))

	for child in chunk.get_children():
		if child is StaticBody3D and child.name.begins_with("Ramp_"):
			for sub in child.get_children():
				if sub is CollisionShape3D:
					assert_almost_eq(
						sub.rotation.x,
						deg_to_rad(-15.0),
						0.001,
						"Ramp collision should be tilted -15 degrees",
					)
			break


func test_stunt_park_sets_center_meta() -> void:
	var tile := _find_stunt_park_tile()
	if tile == Vector2i(-99999, -99999):
		pass_test("No stunt park tile found")
		return

	var span: float = _grid.get_grid_span()
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	_builder.build(chunk, tile, span * float(tile.x), span * float(tile.y))

	assert_true(
		chunk.has_meta("stunt_park_center"),
		"Stunt park chunk should have stunt_park_center meta",
	)
	var center: Vector2 = chunk.get_meta("stunt_park_center")
	assert_true(
		center != Vector2.ZERO,
		"Stunt park center should be non-zero for non-origin tile",
	)


func test_fence_has_material_override() -> void:
	var tile := _find_stunt_park_tile()
	if tile == Vector2i(-99999, -99999):
		pass_test("No stunt park tile found")
		return

	var span: float = _grid.get_grid_span()
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	_builder.build(chunk, tile, span * float(tile.x), span * float(tile.y))

	for child in chunk.get_children():
		if child is MeshInstance3D and child.name == "StuntParkFence":
			assert_not_null(
				child.material_override,
				"Fence should have a material override",
			)
			var mat: StandardMaterial3D = child.material_override
			assert_eq(
				mat.albedo_color, Color(0.5, 0.5, 0.5),
				"Fence material should be grey",
			)
			break


# ================================================================
# Tile without stunt park produces no children
# ================================================================

func test_no_park_tile_produces_empty_chunk() -> void:
	var span: float = _grid.get_grid_span()
	for tx in range(500):
		var tile := Vector2i(tx, tx * 3)
		var chunk := Node3D.new()
		add_child_autofree(chunk)
		_builder.build(chunk, tile, span * float(tile.x), span * float(tile.y))
		if not chunk.has_meta("has_stunt_park"):
			assert_eq(
				chunk.get_child_count(), 0,
				"Non-park tile should produce no children",
			)
			return
	pass_test("All tiles produced parks -- extremely unlikely")


# ================================================================
# Constants sanity
# ================================================================

func test_fence_height_positive() -> void:
	assert_true(
		RampsScript.FENCE_HEIGHT > 0.0,
		"FENCE_HEIGHT should be positive",
	)


func test_ramp_height_positive() -> void:
	assert_true(
		RampsScript.RAMP_HEIGHT > 0.0,
		"RAMP_HEIGHT should be positive",
	)


func test_collision_layer_is_ground() -> void:
	var tile := _find_stunt_park_tile()
	if tile == Vector2i(-99999, -99999):
		pass_test("No stunt park tile found")
		return

	var span: float = _grid.get_grid_span()
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	_builder.build(chunk, tile, span * float(tile.x), span * float(tile.y))

	for child in chunk.get_children():
		if child is StaticBody3D and child.name.begins_with("Ramp_"):
			assert_eq(
				child.collision_layer, 1,
				"Ramp collision layer should be ground (1)",
			)
			assert_eq(
				child.collision_mask, 0,
				"Ramp collision mask should be 0",
			)
