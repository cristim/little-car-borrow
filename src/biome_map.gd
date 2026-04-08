extends RefCounted
## Noise-based biome assignment per tile.
## Reuses city_boundary shape for city biomes; noise-driven for rural areas.

const TileProfile = preload("res://src/tile_profile.gd")

const CITY_CENTER_RATIO := 0.6  # inner 60% of boundary radius = city_center
const SUBURB_RANGE := 1  # tiles outside boundary that count as suburb
const OCEAN_WEST_THRESHOLD := -2.5  # grid_span multiplier for ocean start

var _grid_span: float
var _terrain_noise: FastNoiseLite
var _boundary: RefCounted
var _biome_noise: FastNoiseLite


func init(
	grid_span: float,
	terrain_noise: FastNoiseLite,
	boundary: RefCounted,
) -> void:
	_grid_span = grid_span
	_terrain_noise = terrain_noise
	_boundary = boundary

	_biome_noise = FastNoiseLite.new()
	_biome_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_biome_noise.seed = 123
	_biome_noise.frequency = 0.08
	_biome_noise.fractal_octaves = 2


## Return the biome string for a given tile coordinate.
func get_biome(tile: Vector2i) -> String:
	var center_x: float = float(tile.x) * _grid_span
	var center_z: float = float(tile.y) * _grid_span
	var dist: float = sqrt(center_x * center_x + center_z * center_z)
	var angle: float = atan2(center_z, center_x)
	var boundary_r: float = _boundary.get_boundary_radius_at_angle(angle)

	# Inside city boundary
	if dist < boundary_r:
		if dist < boundary_r * CITY_CENTER_RATIO:
			return "city_center"
		return "residential"

	# Suburb ring: 1-2 tiles outside boundary
	var tiles_outside: float = (dist - boundary_r) / _grid_span
	if tiles_outside < SUBURB_RANGE:
		return "suburb"

	# Ocean: far west
	if center_x < OCEAN_WEST_THRESHOLD * _grid_span:
		return "ocean"

	# Rural biomes: noise-driven
	return _get_rural_biome(center_x, center_z, tiles_outside)


## Return true if the biome is a city biome (has road grid).
func is_city_biome(biome: String) -> bool:
	return biome in TileProfile.CITY_BIOMES


## Backward-compatible: returns true if tile is a city tile.
## Matches the old city_boundary.is_city_tile() output exactly for
## city_center and residential (inside boundary).
## Suburb is also treated as city for road grid purposes.
func is_city_tile(tile: Vector2i) -> bool:
	return is_city_biome(get_biome(tile))


func _get_rural_biome(
	wx: float,
	wz: float,
	tiles_outside: float,
) -> String:
	var raw: float = _biome_noise.get_noise_2d(wx * 0.01, wz * 0.01)

	# Higher terrain = more likely mountain/forest
	var ground_h: float = 0.0
	if _terrain_noise:
		ground_h = (_terrain_noise.get_noise_2d(wx, wz) + 1.0) * 0.5

	# Distance from city affects biome distribution
	var far_factor: float = clampf(tiles_outside / 6.0, 0.0, 1.0)

	# Combine noise and terrain for biome selection
	var score: float = raw + ground_h * 0.5 + far_factor * 0.3

	var biome := "farmland"
	if score > 0.9:
		biome = "mountain"
	elif score > 0.5:
		biome = "forest"
	elif score > -0.2:
		# Villages appear in farmland areas, spotted by secondary noise
		var village_n: float = (
			_biome_noise
			. get_noise_2d(
				wx * 0.03 + 500.0,
				wz * 0.03 + 500.0,
			)
		)
		if score <= 0.1 and village_n > 0.3:
			biome = "village"
	elif _terrain_noise:
		var h: float = _boundary.get_ground_height(wx, wz)
		if h < -2.0:
			biome = "ocean"

	return biome
