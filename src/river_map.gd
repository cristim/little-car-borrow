extends RefCounted
## Traces river paths from high terrain toward ocean using noise gradient.
## Rivers are an overlay on the base biome (any non-ocean biome can have a river).

const RIVER_SEED := 0x21FE
const MIN_SOURCE_HEIGHT := 25.0
const RIVER_WIDTH_MIN := 4.0
const RIVER_WIDTH_MAX := 12.0

var _grid_span: float
var _boundary: RefCounted
var _river_noise: FastNoiseLite
var _river_tiles: Dictionary = {}  # Vector2i -> Dictionary


func init(grid_span: float, boundary: RefCounted) -> void:
	_grid_span = grid_span
	_boundary = boundary
	_river_noise = FastNoiseLite.new()
	_river_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_river_noise.seed = 8421
	_river_noise.frequency = 0.15


## Get river data for a tile. Returns empty dict if no river.
## If river present, returns:
## { "entry_dir": int, "exit_dir": int, "position": float, "width": float }
func get_river_at(tile: Vector2i) -> Dictionary:
	if _river_tiles.has(tile):
		return _river_tiles[tile]

	# Check if this tile should have a river based on noise
	var center_x: float = float(tile.x) * _grid_span
	var center_z: float = float(tile.y) * _grid_span
	var n: float = _river_noise.get_noise_2d(
		float(tile.x), float(tile.y),
	)

	# Only ~15% of tiles get rivers
	if n < 0.3:
		_river_tiles[tile] = {}
		return {}

	var h: float = _boundary.get_ground_height(center_x, center_z)
	# Rivers only on land above sea level
	if h < 1.0:
		_river_tiles[tile] = {}
		return {}

	# Determine flow direction: downhill toward lower terrain
	var entry_dir := _find_uphill_dir(tile)
	var exit_dir := _find_downhill_dir(tile, entry_dir)

	if entry_dir == exit_dir:
		_river_tiles[tile] = {}
		return {}

	# Width increases with distance from source (lower height = wider)
	var width_t: float = clampf(1.0 - h / 60.0, 0.2, 1.0)
	var width: float = lerpf(RIVER_WIDTH_MIN, RIVER_WIDTH_MAX, width_t)

	# Position along edge (0-1, centered)
	var pos: float = 0.5 + _river_noise.get_noise_2d(
		float(tile.x) * 3.0, float(tile.y) * 3.0,
	) * 0.2

	var data: Dictionary = {
		"entry_dir": entry_dir,
		"exit_dir": exit_dir,
		"position": pos,
		"width": width,
	}
	_river_tiles[tile] = data
	return data


func _find_downhill_dir(tile: Vector2i, exclude_dir: int) -> int:
	var best_dir := -1
	var best_h := INF
	var offsets: Array[Vector2i] = [
		Vector2i(0, -1), Vector2i(1, 0),
		Vector2i(0, 1), Vector2i(-1, 0),
	]
	for dir in range(4):
		if dir == exclude_dir:
			continue
		var neighbor := tile + offsets[dir]
		var nx: float = float(neighbor.x) * _grid_span
		var nz: float = float(neighbor.y) * _grid_span
		var h: float = _boundary.get_ground_height(nx, nz)
		if h < best_h:
			best_h = h
			best_dir = dir
	return best_dir if best_dir >= 0 else (exclude_dir + 2) % 4


func _find_uphill_dir(tile: Vector2i) -> int:
	var best_dir := 0
	var best_h := -INF
	var offsets: Array[Vector2i] = [
		Vector2i(0, -1), Vector2i(1, 0),
		Vector2i(0, 1), Vector2i(-1, 0),
	]
	for dir in range(4):
		var neighbor := tile + offsets[dir]
		var nx: float = float(neighbor.x) * _grid_span
		var nz: float = float(neighbor.y) * _grid_span
		var h: float = _boundary.get_ground_height(nx, nz)
		if h > best_h:
			best_h = h
			best_dir = dir
	return best_dir
