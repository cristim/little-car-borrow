extends RefCounted
## Resolves a tile's type and edge profiles by reading neighbor edges.
## Ensures edge matching: roads/rivers continue, heights match, biomes compatible.

const TileProfile = preload("res://src/tile_profile.gd")

var _cache: RefCounted  # tile_cache.gd
var _biome_map: RefCounted  # biome_map.gd
var _grid: RefCounted  # road_grid.gd
var _boundary: RefCounted  # city_boundary.gd
var _river_map: RefCounted  # river_map.gd (optional, added later)


func init(
	cache: RefCounted,
	biome_map: RefCounted,
	grid: RefCounted,
	boundary: RefCounted,
	river_map: RefCounted = null,
) -> void:
	_cache = cache
	_biome_map = biome_map
	_grid = grid
	_boundary = boundary
	_river_map = river_map


## Resolve tile data for a tile coordinate.
## Reads neighbor edges from cache, computes biome, builds edge profiles.
## Stores result in cache and returns it.
func resolve(tile: Vector2i) -> Dictionary:
	# Return cached if already resolved
	var existing: Dictionary = _cache.get_tile_data(tile)
	if not existing.is_empty():
		return existing

	var biome: String = _biome_map.get_biome(tile)
	biome = _adjust_biome_for_neighbors(tile, biome)

	var edges: Dictionary = _compute_edges(tile, biome)
	var seed_val: int = _tile_seed(tile)

	var data: Dictionary = {
		"biome": biome,
		"edges": edges,
		"seed": seed_val,
	}

	_cache.set_tile_data(tile, data)
	return data


## Adjust biome if it's incompatible with existing neighbors.
func _adjust_biome_for_neighbors(tile: Vector2i, biome: String) -> String:
	var adjusted := biome
	for dir in range(4):
		var neighbor_edge: Dictionary = _cache.get_neighbor_edge(tile, dir)
		if neighbor_edge.is_empty():
			continue
		var neighbor_biome: String = neighbor_edge.get("biome", "")
		if neighbor_biome == "":
			continue
		if not TileProfile.biomes_compatible(adjusted, neighbor_biome):
			adjusted = _find_compatible_biome(adjusted, neighbor_biome)
	return adjusted


## Find a biome compatible with the neighbor when the candidate isn't.
func _find_compatible_biome(
	candidate: String, neighbor_biome: String,
) -> String:
	# Try to find a biome that works as a bridge
	var candidate_neighbors: Array = TileProfile.BIOME_ADJACENCY.get(
		candidate, []
	)
	var neighbor_neighbors: Array = TileProfile.BIOME_ADJACENCY.get(
		neighbor_biome, []
	)
	# Find intersection
	for b: String in candidate_neighbors:
		if b in neighbor_neighbors:
			return b
	# Fallback: use the neighbor's biome
	return neighbor_biome


## Compute edge profiles for all 4 directions.
func _compute_edges(tile: Vector2i, biome: String) -> Dictionary:
	var edges: Dictionary = {}
	for dir in range(4):
		edges[dir] = _compute_edge(tile, biome, dir)
	return edges


## Compute a single edge profile.
func _compute_edge(tile: Vector2i, biome: String, dir: int) -> Dictionary:
	var neighbor_edge: Dictionary = _cache.get_neighbor_edge(tile, dir)

	# City biomes: flat, roads at grid positions
	if _biome_map.is_city_biome(biome):
		return _compute_city_edge(tile, biome, dir, neighbor_edge)

	# Terrain biomes: heights from boundary, roads from neighbors
	return _compute_terrain_edge(tile, biome, dir, neighbor_edge)


## City edge: flat height, roads at road_grid positions.
func _compute_city_edge(
	_tile: Vector2i, biome: String, _dir: int,
	neighbor_edge: Dictionary,
) -> Dictionary:
	# If neighbor already has an edge facing us, match it
	if not neighbor_edge.is_empty():
		# Return matching edge with our biome
		var heights: PackedFloat32Array = neighbor_edge.get(
			"heights", PackedFloat32Array()
		)
		var roads: Array = neighbor_edge.get("roads", [])
		var river: Dictionary = neighbor_edge.get("river", {})
		return TileProfile.create_edge(biome, roads, heights, river)

	# No neighbor: flat city edge
	return TileProfile.create_flat_edge(biome)


## Terrain edge: heights from terrain noise, roads from neighbors.
func _compute_terrain_edge(
	tile: Vector2i, biome: String, dir: int,
	neighbor_edge: Dictionary,
) -> Dictionary:
	# Heights: match neighbor if available, else sample from terrain
	var heights: PackedFloat32Array
	if (
		not neighbor_edge.is_empty()
		and neighbor_edge.get("heights", PackedFloat32Array()).size() > 0
	):
		heights = neighbor_edge["heights"]
	else:
		heights = _sample_edge_heights(tile, dir)

	# Roads: inherit from neighbor, or generate for road-bearing biomes
	var roads: Array = []
	if not neighbor_edge.is_empty():
		roads = neighbor_edge.get("roads", [])
	elif biome in ["village", "suburb"]:
		roads = _default_highway_roads()

	# River: from river_map if available
	var river: Dictionary = {}
	if _river_map:
		var river_data: Dictionary = _river_map.get_river_at(
			tile,
		)
		if not river_data.is_empty():
			# Check if river crosses this edge
			var entry_dir: int = river_data.get("entry_dir", -1)
			var exit_dir: int = river_data.get("exit_dir", -1)
			if dir == entry_dir or dir == exit_dir:
				river = {
					"position": river_data.get("position", 0.5),
					"width": river_data.get("width", 0.1),
				}

	return TileProfile.create_edge(biome, roads, heights, river)


## Sample terrain heights along an edge of a tile.
func _sample_edge_heights(tile: Vector2i, dir: int) -> PackedFloat32Array:
	var heights := PackedFloat32Array()
	heights.resize(TileProfile.HEIGHT_SAMPLES)

	var origin: Vector2 = _grid.get_chunk_origin(tile)
	var span: float = _grid.get_grid_span()
	var half_span: float = span * 0.5

	for i in range(TileProfile.HEIGHT_SAMPLES):
		var t: float = float(i) / float(TileProfile.HEIGHT_SAMPLES - 1)
		var wx: float
		var wz: float

		match dir:
			TileProfile.NORTH:  # -Z edge
				wx = origin.x - half_span + t * span
				wz = origin.y - half_span
			TileProfile.SOUTH:  # +Z edge
				wx = origin.x - half_span + t * span
				wz = origin.y + half_span
			TileProfile.EAST:  # +X edge
				wx = origin.x + half_span
				wz = origin.y - half_span + t * span
			TileProfile.WEST:  # -X edge
				wx = origin.x - half_span
				wz = origin.y - half_span + t * span
			_:
				wx = origin.x
				wz = origin.y

		heights[i] = _boundary.get_ground_height(wx, wz)

	return heights


## Default road entries at highway grid positions (indices 0 and 5).
func _default_highway_roads() -> Array:
	var span: float = _grid.get_grid_span()
	var roads: Array = []
	for hi: int in [0, 5]:
		var center_local: float = _grid.get_road_center_local(hi)
		var pos: float = (center_local + span * 0.5) / span
		var width: float = _grid.get_road_width(hi)
		roads.append({"position": pos, "width": width})
	return roads


## Deterministic seed for a tile coordinate.
func _tile_seed(tile: Vector2i) -> int:
	return hash(tile)
