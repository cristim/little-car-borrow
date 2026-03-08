extends RefCounted
## Shared road grid math with infinite tiling.
## One tile = GRID_SIZE blocks + (GRID_SIZE+1) roads, spanning _grid_span meters.
## For any world coordinate the nearest instance of road i is computed via
## roundf() so all math works at arbitrary positions.
##
## Usage:  var _grid = preload("res://src/road_grid.gd").new()

const GRID_SIZE := 10
const BLOCK_SIZE := 40.0
const ROAD_WIDTH := 8.0
const BOULEVARD_WIDTH := 12.0
const ALLEY_WIDTH := 4.0
const SIDEWALK_WIDTH := 2.5
const SIDEWALK_HEIGHT := 0.10
const ROAD_THICKNESS := 0.2
const BOULEVARD_INDEX := 5
const ALLEY_INDEX := 2
const CURB_RAMP_RUN := 1.0

var _grid_span: float = 0.0
## Road centers within one tile, centred around 0.
var _road_centers: Array[float] = []


func _init() -> void:
	# Compute grid span
	_grid_span = 0.0
	for i in range(GRID_SIZE + 1):
		_grid_span += get_road_width(i)
	_grid_span += BLOCK_SIZE * GRID_SIZE

	# Precompute local road centers (same math as the old city.gd)
	_road_centers.clear()
	for idx in range(GRID_SIZE + 1):
		var pos := 0.0
		for i in range(idx):
			pos += get_road_width(i) * 0.5 + BLOCK_SIZE + get_road_width(i + 1) * 0.5
		_road_centers.append(pos - _grid_span * 0.5 + get_road_width(0) * 0.5)


func get_road_width(index: int) -> float:
	if index == BOULEVARD_INDEX:
		return BOULEVARD_WIDTH
	if index == ALLEY_INDEX:
		return ALLEY_WIDTH
	return ROAD_WIDTH


func get_grid_span() -> float:
	return _grid_span


## Center of road `index` within the canonical tile (range approx [-span/2, span/2]).
func get_road_center_local(index: int) -> float:
	return _road_centers[index]


## Nearest world-space center of road `index` to `ref_coord`.
func get_road_center_near(index: int, ref_coord: float) -> float:
	var local := _road_centers[index]
	var tile := roundf((ref_coord - local) / _grid_span)
	return local + tile * _grid_span


## Which of the 0..GRID_SIZE roads is closest to `world_coord` (accounts for tiling).
func get_nearest_road_index(world_coord: float) -> int:
	var best_idx := 0
	var best_dist := INF
	for i in range(GRID_SIZE + 1):
		var c := get_road_center_near(i, world_coord)
		var d := absf(world_coord - c)
		if d < best_dist:
			best_dist = d
			best_idx = i
	return best_idx


## Which chunk (tile) a world position falls in. Returns Vector2i(tile_x, tile_z).
func get_chunk_coord(world_pos: Vector2) -> Vector2i:
	return Vector2i(
		floori(world_pos.x / _grid_span + 0.5),
		floori(world_pos.y / _grid_span + 0.5),
	)


## World-space origin (center) of a chunk.
func get_chunk_origin(chunk: Vector2i) -> Vector2:
	return Vector2(chunk.x * _grid_span, chunk.y * _grid_span)


## Returns true if world position (x, z) falls within a ramp exclusion zone.
## Ramp positions are deterministic per chunk -- 4 ramps per chunk at fixed offsets.
func is_on_ramp(world_x: float, world_z: float) -> bool:
	const HALF_X := 5.0
	const HALF_Z := 6.0

	var chunk := get_chunk_coord(Vector2(world_x, world_z))
	var origin := get_chunk_origin(chunk)
	var ox: float = origin.x
	var oz: float = origin.y

	var blvd_x: float = _road_centers[BOULEVARD_INDEX] + ox
	var road7_z: float = _road_centers[7] + oz
	var road3_z: float = _road_centers[3] + oz

	if absf(world_x - blvd_x) < HALF_X and absf(world_z - (-80.0 + oz)) < HALF_Z:
		return true
	if absf(world_x - blvd_x) < HALF_X and absf(world_z - (80.0 + oz)) < HALF_Z:
		return true
	if absf(world_x - (-60.0 + ox)) < HALF_X and absf(world_z - road7_z) < HALF_Z:
		return true
	if absf(world_x - (60.0 + ox)) < HALF_X and absf(world_z - road3_z) < HALF_Z:
		return true

	return false
