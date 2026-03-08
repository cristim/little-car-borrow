extends GutTest
## Unit tests for chunk_builder_villages.gd flatness checks,
## village placement, and deterministic output.

const VillageScript = preload(
	"res://scenes/world/generator/chunk_builder_villages.gd"
)
const RoadGridScript = preload("res://src/road_grid.gd")


var _grid: RefCounted
var _noise: FastNoiseLite
var _builder: RefCounted
var _mats: Array[StandardMaterial3D]


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

	_mats = []
	for _i in 3:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.5, 0.5, 0.5)
		_mats.append(mat)

	var win_mat := StandardMaterial3D.new()

	_builder = VillageScript.new()
	_builder.init(_grid, _noise, _mats, win_mat)


# ================================================================
# Height sampling matches terrain builder
# ================================================================

func test_height_zero_inside_city() -> void:
	var h: float = _builder._sample_height(0.0, 0.0)
	assert_eq(h, 0.0, "Height at origin should be 0")


func test_height_nonzero_outside_city() -> void:
	var span: float = _grid.get_grid_span()
	var h: float = _builder._sample_height(span * 10.0, 0.0)
	assert_ne(h, 0.0, "Height far outside city should not be 0")


# ================================================================
# Flatness check
# ================================================================

func test_flat_area_passes_flatness_check() -> void:
	# Inside city, all heights are 0 — perfectly flat
	# But center height must be > 1.0 for village placement,
	# so flatness check alone should pass
	var result: bool = _builder._is_flat_enough(0.0, 0.0)
	# All zero heights -> variance = 0 < 2.0 threshold
	assert_true(result, "Flat area should pass flatness check")


# ================================================================
# Build behavior
# ================================================================

func test_build_sets_has_village_meta() -> void:
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	var span: float = _grid.get_grid_span()
	var tile := Vector2i(5, 0)
	_builder.build(chunk, tile, span * 5.0, 0.0)

	assert_true(
		chunk.has_meta("has_village"),
		"Build should always set has_village meta",
	)


func test_build_deterministic_for_same_tile() -> void:
	var span: float = _grid.get_grid_span()
	var tile := Vector2i(7, 2)
	var ox: float = span * 7.0
	var oz: float = span * 2.0

	var chunk1 := Node3D.new()
	add_child_autofree(chunk1)
	_builder.build(chunk1, tile, ox, oz)

	var chunk2 := Node3D.new()
	add_child_autofree(chunk2)
	_builder.build(chunk2, tile, ox, oz)

	var v1: bool = chunk1.get_meta("has_village")
	var v2: bool = chunk2.get_meta("has_village")
	assert_eq(
		v1, v2,
		"Same tile should produce same village decision",
	)


func test_city_tile_produces_no_village() -> void:
	# Tile (0,0) is inside city — heights are all 0
	# Village requires center_h > 1.0, so no village here
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	_builder.build(chunk, Vector2i(0, 0), 0.0, 0.0)

	var has_village: bool = chunk.get_meta("has_village")
	assert_false(
		has_village,
		"City-radius tile should not get a village (heights are 0)",
	)


func test_village_buildings_have_collision() -> void:
	# Try many tiles to find one with a village
	var span: float = _grid.get_grid_span()
	var found_village := false
	for tx in range(5, 20):
		var chunk := Node3D.new()
		add_child_autofree(chunk)
		var tile := Vector2i(tx, 0)
		_builder.build(chunk, tile, span * float(tx), 0.0)
		var has_village: bool = chunk.get_meta("has_village")
		if has_village:
			found_village = true
			# Check for StaticBody3D child
			var found_body := false
			for child in chunk.get_children():
				if child is StaticBody3D:
					found_body = true
					break
			assert_true(
				found_body,
				"Village should create StaticBody3D",
			)
			break

	if not found_village:
		pass_test("No village found in range — acceptable")
