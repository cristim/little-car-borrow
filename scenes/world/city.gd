extends Node3D
## Infinite procedural city using chunk-based generation.
## Loads/unloads city tiles around the player as they move.
## One chunk = one full grid tile (~488m x 488m).
##
## Performance: meshes merged via SurfaceTool, compound collision bodies,
## shared material palette, MultiMesh trees. ~22 draw calls per chunk.

const CHUNK_LOAD_RADIUS := 2.5  # in grid_span units — loads 5x5 grid around player
const CHUNK_UNLOAD_RADIUS := 3.5
const UPDATE_INTERVAL := 0.5
const SCAN_RANGE := 5  # check -5..+5 tiles around player (boundary can extend ~4.6 tiles)
const LOOKAHEAD_TIME := 3.0  # seconds of velocity prediction
const FLUSH_INTERVAL := 5.0  # seconds between disk flushes
const SEA_LEVEL := -2.0
const EDGE_MISMATCH_THRESHOLD := 0.05  # meters — triggers neighbor rebuild
const MAX_CASCADING_REPAIRS := 12  # safety cap to prevent runaway rebuilds
const FALL_THRESHOLD := -15.0  # Y below which triggers self-repair
const REPAIR_COOLDOWN := 2.0  # seconds after self-repair before re-checking
const REPAIR_RADIUS := 1  # 3x3 grid around fall position
const DIR_OFFSETS := {
	0: Vector2i(0, -1),  # NORTH
	1: Vector2i(1, 0),   # EAST
	2: Vector2i(0, 1),   # SOUTH
	3: Vector2i(-1, 0),  # WEST
}

var _grid = preload("res://src/road_grid.gd").new()
var _boundary = preload("res://src/city_boundary.gd").new()

# Tile-matching subsystem
var _chunk_persistence = preload("res://src/chunk_persistence.gd").new()
var _tile_cache = preload("res://src/tile_cache.gd").new()
var _biome_map = preload("res://src/biome_map.gd").new()
var _tile_resolver = preload("res://src/tile_resolver.gd").new()

# Shared material palette — initialized once, reused across all chunks
var _road_mat: StandardMaterial3D
var _sidewalk_mat: StandardMaterial3D
var _ground_mat: StandardMaterial3D
var _marking_mat: StandardMaterial3D
var _ramp_mat: StandardMaterial3D
var _window_mats: Array[StandardMaterial3D] = []
var _building_mats: Array[StandardMaterial3D] = []
var _trunk_mats: Array[StandardMaterial3D] = []
var _canopy_mats: Array[StandardMaterial3D] = []
var _roof_mats: Array[StandardMaterial3D] = []
var _pole_mat: StandardMaterial3D
var _interior_mat: StandardMaterial3D
var _terrain_noise: FastNoiseLite
var _terrain_mat: StandardMaterial3D

# Canonical tree meshes for MultiMesh (created once in _ready)
var _trunk_mesh: CylinderMesh
var _canopy_meshes: Array[Mesh] = []  # 5 variants: sphere, cone, tall, flat, sphere2

# Builder scripts
var _road_builder = preload("res://scenes/world/generator/chunk_builder_roads.gd").new()
var _building_builder = preload("res://scenes/world/generator/chunk_builder_buildings.gd").new()
var _tree_builder = preload("res://scenes/world/generator/chunk_builder_trees.gd").new()
var _marking_builder = preload("res://scenes/world/generator/chunk_builder_markings.gd").new()
var _ramp_builder = preload("res://scenes/world/generator/chunk_builder_ramps.gd").new()
var _light_builder = preload("res://scenes/world/generator/chunk_builder_lights.gd").new()
var _terrain_builder = preload(
	"res://scenes/world/generator/chunk_builder_terrain.gd"
).new()
var _village_builder = preload(
	"res://scenes/world/generator/chunk_builder_villages.gd"
).new()
var _rural_road_builder = preload(
	"res://scenes/world/generator/chunk_builder_rural_roads.gd"
).new()
var _rural_tree_builder = preload(
	"res://scenes/world/generator/chunk_builder_rural_trees.gd"
).new()
var _suburb_builder = preload(
	"res://scenes/world/generator/chunk_builder_suburb.gd"
).new()
var _farmland_builder = preload(
	"res://scenes/world/generator/chunk_builder_farmland.gd"
).new()
var _mountain_builder = preload(
	"res://scenes/world/generator/chunk_builder_mountain.gd"
).new()
var _river_map = preload("res://src/river_map.gd").new()
var _river_builder = preload(
	"res://scenes/world/generator/chunk_builder_river.gd"
).new()
var _bridge_builder = preload(
	"res://scenes/world/generator/chunk_builder_bridge.gd"
).new()
var _pier_builder = preload(
	"res://scenes/world/generator/chunk_builder_piers.gd"
).new()

var _chunks: Dictionary = {}
var _update_timer := 0.0
var _flush_timer := 0.0
var _player: Node3D = null
var _player_found := false
var _repairing := false  # prevents recursive neighbor repair
var _repair_cooldown := 0.0


func _ready() -> void:
	add_to_group("city_manager")
	_init_materials()
	_init_tree_meshes()
	_init_terrain_noise()
	_boundary.init(_grid.get_grid_span(), _terrain_noise)
	set_meta("city_boundary", _boundary)
	_biome_map.init(_grid.get_grid_span(), _terrain_noise, _boundary)
	set_meta("biome_map", _biome_map)
	_tile_cache.init(_chunk_persistence)
	_init_builders()
	_build_safety_ground()
	_load_chunks_around(Vector3.ZERO, Vector3.ZERO)


func _process(delta: float) -> void:
	if not _player:
		_player = get_tree().get_first_node_in_group("player") as Node3D
		if not _player:
			return

	# First time we find the player, immediately load around them
	if not _player_found:
		_player_found = true
		_load_chunks_around(_player.global_position, Vector3.ZERO)

	# Self-repair: detect fall-through (must run every frame)
	if _repair_cooldown > 0.0:
		_repair_cooldown -= delta
	elif _player_found:
		var fall_pos := _get_tracking_position()
		if fall_pos.y < FALL_THRESHOLD:
			_self_repair(fall_pos)

	_update_timer += delta
	if _update_timer < UPDATE_INTERVAL:
		return
	_update_timer = 0.0

	var pos := _get_tracking_position()
	var vel := _get_player_velocity()
	_load_chunks_around(pos, vel)
	_unload_distant_chunks(pos)

	_flush_timer += UPDATE_INTERVAL
	if _flush_timer >= FLUSH_INTERVAL:
		_flush_timer = 0.0
		_tile_cache.flush()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_tile_cache.flush()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("regenerate_chunk"):
		var pos := _get_tracking_position()
		var tile := _grid.get_chunk_coord(Vector2(pos.x, pos.z))
		_regenerate_chunk(tile)


func _regenerate_chunk(tile: Vector2i) -> void:
	# Remove old chunk node
	if _chunks.has(tile):
		var old_node: Node3D = _chunks[tile]
		_chunks.erase(tile)
		old_node.queue_free()

	# Clear from cache (keeps neighbor edges intact)
	_tile_cache.clear_tile(tile)

	# Rebuild with fresh resolution
	var new_chunk := _build_chunk(tile)
	_chunks[tile] = new_chunk
	print("Regenerated chunk at tile %s" % str(tile))


func _load_chunks_around(pos: Vector3, velocity: Vector3) -> void:
	var span: float = _grid.get_grid_span()
	var load_dist := CHUNK_LOAD_RADIUS * span

	# Also load around predicted future position
	var predicted := pos + velocity * LOOKAHEAD_TIME
	var center_curr := _grid.get_chunk_coord(Vector2(pos.x, pos.z))
	var center_pred := _grid.get_chunk_coord(
		Vector2(predicted.x, predicted.z)
	)

	for dx in range(-SCAN_RANGE, SCAN_RANGE + 1):
		for dz in range(-SCAN_RANGE, SCAN_RANGE + 1):
			var tile := Vector2i(center_curr.x + dx, center_curr.y + dz)
			if _chunks.has(tile):
				continue
			var origin := _grid.get_chunk_origin(tile)
			# Load if near current position OR near predicted position
			var d_curr := Vector2(
				pos.x - origin.x, pos.z - origin.y
			).length()
			var d_pred := Vector2(
				predicted.x - origin.x, predicted.z - origin.y
			).length()
			if d_curr < load_dist or d_pred < load_dist:
				_chunks[tile] = _build_chunk(tile)


func _unload_distant_chunks(pos: Vector3) -> void:
	var span: float = _grid.get_grid_span()
	var unload_dist := CHUNK_UNLOAD_RADIUS * span
	var to_remove: Array[Vector2i] = []

	for tile: Vector2i in _chunks:
		var origin := _grid.get_chunk_origin(tile)
		var dist := Vector2(pos.x - origin.x, pos.z - origin.y).length()
		if dist > unload_dist:
			to_remove.append(tile)

	for tile in to_remove:
		var node: Node3D = _chunks[tile]
		_chunks.erase(tile)
		node.queue_free()


func _get_tracking_position() -> Vector3:
	var vehicle = _player.get("current_vehicle")
	if vehicle and vehicle is Node3D:
		return (vehicle as Node3D).global_position
	return _player.global_position


func _get_player_velocity() -> Vector3:
	# When driving, read velocity from the vehicle RigidBody3D
	var vehicle = _player.get("current_vehicle")
	if vehicle and vehicle is RigidBody3D:
		return (vehicle as RigidBody3D).linear_velocity
	# On foot, CharacterBody3D has a velocity property
	if _player is CharacterBody3D:
		return (_player as CharacterBody3D).velocity
	return Vector3.ZERO


func _self_repair(pos: Vector3) -> void:
	_repair_cooldown = REPAIR_COOLDOWN
	var center: Vector2i = _grid.get_chunk_coord(Vector2(pos.x, pos.z))

	# Suppress per-tile cascade to avoid 9x redundant BFS repairs
	_repairing = true

	# Regenerate 3x3 grid (outer ring first, center last)
	for dx in range(-REPAIR_RADIUS, REPAIR_RADIUS + 1):
		for dz in range(-REPAIR_RADIUS, REPAIR_RADIUS + 1):
			if dx == 0 and dz == 0:
				continue
			_regenerate_chunk(Vector2i(center.x + dx, center.y + dz))
	_regenerate_chunk(center)

	# Run one edge repair pass from center outward
	_repairing = false
	var center_data: Dictionary = _tile_cache.get_tile_data(center)
	var center_edges: Dictionary = center_data.get("edges", {})
	var actual: Dictionary = {}
	for dir: int in center_edges:
		var h: PackedFloat32Array = center_edges[dir].get(
			"heights", PackedFloat32Array(),
		)
		if h.size() > 0:
			actual[dir] = h
	if not actual.is_empty():
		_repair_neighbor_edges(center, actual)

	# Compute safe landing position
	var safe_y: float = maxf(
		_boundary.get_ground_height(pos.x, pos.z), 0.0,
	) + 2.0

	# Teleport player/vehicle
	var vehicle = _player.get("current_vehicle")
	if vehicle and vehicle is RigidBody3D:
		(vehicle as RigidBody3D).global_position = Vector3(
			pos.x, safe_y, pos.z,
		)
		(vehicle as RigidBody3D).linear_velocity = Vector3.ZERO
		(vehicle as RigidBody3D).angular_velocity = Vector3.ZERO
	else:
		_player.global_position = Vector3(pos.x, safe_y, pos.z)
		(_player as CharacterBody3D).velocity = Vector3.ZERO

	print(
		"Self-repair: regenerated 3x3 at %s, respawned at Y=%.1f"
		% [str(center), safe_y]
	)


func _build_chunk(tile: Vector2i) -> Node3D:
	var chunk := Node3D.new()
	chunk.name = "Chunk_%d_%d" % [tile.x, tile.y]
	chunk.set_meta("tile", tile)
	add_child(chunk)

	var origin := _grid.get_chunk_origin(tile)
	var ox := origin.x
	var oz := origin.y
	var span: float = _grid.get_grid_span()

	var tile_data: Dictionary = _tile_resolver.resolve(tile)
	var biome: String = tile_data.get("biome", "")
	chunk.set_meta("biome", biome)

	if _biome_map.is_city_biome(biome):
		chunk.set_meta("chunk_type", "city")
		_road_builder.build(chunk, ox, oz, span)
		if biome == "suburb":
			_suburb_builder.build(chunk, tile, ox, oz)
			_ramp_builder.build(chunk, tile, ox, oz)
		else:
			_building_builder.build(chunk, tile, ox, oz)
		_tree_builder.build(chunk, tile, ox, oz)
		_marking_builder.build(chunk, ox, oz, span)
		_light_builder.build(chunk, ox, oz)
		# Store flat edge heights so terrain tiles resolved later know to
		# blend to ground level (y=0) when adjacent to this city chunk.
		_store_city_edges(tile, tile_data)
		# Rebuild any already-loaded terrain neighbors that have a gap at
		# the city boundary (heights not near y=0).
		if not _repairing:
			_repair_city_boundary(tile)
	else:
		chunk.set_meta("chunk_type", "terrain")
		var river_data: Dictionary = _river_map.get_river_at(tile)
		var actual_edges: Dictionary = _terrain_builder.build(
			chunk, tile, ox, oz, tile_data, river_data,
		)
		_update_tile_edges(tile, tile_data, actual_edges)
		if not _repairing:
			_repair_neighbor_edges(tile, actual_edges)
		_build_terrain_biome(
			chunk, tile, ox, oz, biome, river_data, tile_data,
		)

	return chunk


## Update tile cache with actual edge heights from the terrain builder.
## This ensures neighbors read the exact heights the terrain was built with.
func _update_tile_edges(
	tile: Vector2i, tile_data: Dictionary,
	actual_edges: Dictionary,
) -> void:
	var edges: Dictionary = tile_data.get("edges", {})
	for dir: int in actual_edges:
		if edges.has(dir):
			edges[dir]["heights"] = actual_edges[dir]
	tile_data["edges"] = edges
	_tile_cache.set_tile_data(tile, tile_data)


## After building a terrain chunk, check loaded neighbors and cached-only
## neighbors for mismatched facing edges. Rebuilds loaded neighbors and
## invalidates cached-only ones. Cascades via BFS until all seams match
## or the safety cap is reached.
func _repair_neighbor_edges(
	tile: Vector2i, actual_edges: Dictionary,
) -> void:
	var queue: Array[Vector2i] = []
	var visited: Dictionary = {tile: true}

	_queue_mismatched_loaded(tile, actual_edges, queue, visited)
	_invalidate_cached_neighbors(tile, actual_edges)

	var repairs := 0
	while not queue.is_empty() and repairs < MAX_CASCADING_REPAIRS:
		var next: Vector2i = queue.pop_front()
		visited[next] = true
		var new_edges: Dictionary = _rebuild_neighbor(next)
		repairs += 1

		if not new_edges.is_empty():
			_queue_mismatched_loaded(next, new_edges, queue, visited)
			_invalidate_cached_neighbors(next, new_edges)


## Enqueue loaded terrain neighbors whose facing edge doesn't match.
func _queue_mismatched_loaded(
	tile: Vector2i, actual_edges: Dictionary,
	queue: Array[Vector2i], visited: Dictionary,
) -> void:
	for dir: int in actual_edges:
		var neighbor: Vector2i = tile + DIR_OFFSETS[dir]
		if visited.has(neighbor):
			continue
		if not _chunks.has(neighbor):
			continue
		var neighbor_node: Node3D = _chunks[neighbor]
		if neighbor_node.get_meta("chunk_type", "") != "terrain":
			continue

		if _shared_edge_mismatches(actual_edges[dir], neighbor, dir):
			queue.append(neighbor)


## Clear cache for unloaded neighbors whose pre-computed edges are stale.
## They will be re-resolved fresh when eventually loaded.
func _invalidate_cached_neighbors(
	tile: Vector2i, actual_edges: Dictionary,
) -> void:
	for dir: int in actual_edges:
		var neighbor: Vector2i = tile + DIR_OFFSETS[dir]
		if _chunks.has(neighbor):
			continue  # loaded neighbors handled by repair queue
		if not _tile_cache.has_tile(neighbor):
			continue
		if _shared_edge_mismatches(actual_edges[dir], neighbor, dir):
			_tile_cache.clear_tile(neighbor)


## Check if a neighbor's facing edge doesn't match the given edge heights.
func _shared_edge_mismatches(
	my_edge: PackedFloat32Array, neighbor: Vector2i, dir: int,
) -> bool:
	var opposite: int = (dir + 2) % 4
	var neighbor_data: Dictionary = _tile_cache.get_tile_data(neighbor)
	var neighbor_edges: Dictionary = neighbor_data.get("edges", {})
	if not neighbor_edges.has(opposite):
		# Missing edge means the neighbor was cached before edge-constraint data
		# was introduced.  Treat as mismatch so the tile gets rebuilt with fresh
		# constraints instead of inheriting stale (gap-producing) heights.
		return true
	var their_edge: PackedFloat32Array = neighbor_edges[opposite].get(
		"heights", PackedFloat32Array(),
	)
	return _edges_mismatch(my_edge, their_edge)


## Write flat (y=0) edge heights for a city tile into the cache.
## Terrain tiles resolved after this city chunk will read these heights
## and blend their edges down to ground level, preventing seams.
func _store_city_edges(tile: Vector2i, tile_data: Dictionary) -> void:
	var sample_count: int = _terrain_builder.SUBDIVISIONS + 1
	var flat: PackedFloat32Array = PackedFloat32Array()
	flat.resize(sample_count)
	flat.fill(0.0)
	var edges: Dictionary = tile_data.get("edges", {})
	for dir in DIR_OFFSETS:
		if not edges.has(dir):
			edges[dir] = {}
		edges[dir]["heights"] = flat
	tile_data["edges"] = edges
	_tile_cache.set_tile_data(tile, tile_data)


## After a city chunk is built, rebuild loaded terrain neighbors whose
## city-facing edge heights deviate from flat ground (y≈0.0).
## Reuses the existing terrain repair BFS via synthetic flat edge data.
func _repair_city_boundary(tile: Vector2i) -> void:
	var sample_count: int = _terrain_builder.SUBDIVISIONS + 1
	var flat: PackedFloat32Array = PackedFloat32Array()
	flat.resize(sample_count)
	flat.fill(0.0)
	var flat_edges: Dictionary = {}
	for dir in DIR_OFFSETS:
		flat_edges[dir] = flat
	_repair_neighbor_edges(tile, flat_edges)


func _edges_mismatch(a: PackedFloat32Array, b: PackedFloat32Array) -> bool:
	if a.size() != b.size() or a.size() == 0:
		return a.size() != b.size()
	for i in range(a.size()):
		if absf(a[i] - b[i]) > EDGE_MISMATCH_THRESHOLD:
			return true
	return false


## Rebuild a loaded terrain chunk and return its new actual edge heights.
func _rebuild_neighbor(tile: Vector2i) -> Dictionary:
	if _chunks.has(tile):
		var old_node: Node3D = _chunks[tile]
		_chunks.erase(tile)
		old_node.queue_free()

	_tile_cache.clear_tile(tile)

	_repairing = true
	_chunks[tile] = _build_chunk(tile)
	_repairing = false

	# Extract built edge heights for cascading checks
	var data: Dictionary = _tile_cache.get_tile_data(tile)
	var edges: Dictionary = data.get("edges", {})
	var result: Dictionary = {}
	for dir: int in edges:
		var h: PackedFloat32Array = edges[dir].get(
			"heights", PackedFloat32Array(),
		)
		if h.size() > 0:
			result[dir] = h
	return result


func _build_terrain_biome(
	chunk: Node3D, tile: Vector2i, ox: float, oz: float,
	biome: String, river_data: Dictionary = {},
	tile_data: Dictionary = {},
) -> void:
	# River overlay (any non-ocean biome can have a river)
	if not river_data.is_empty() and biome != "ocean":
		_river_builder.build(chunk, tile, ox, oz, river_data)
		_bridge_builder.build(chunk, tile, ox, oz, river_data)

	# Piers on coastal terrain tiles (has both water and land above sea level)
	var has_water: bool = chunk.get_meta("has_water", false)
	var max_h: float = chunk.get_meta("terrain_max_height", 0.0)
	if has_water and max_h > SEA_LEVEL:
		_pier_builder.build(chunk, tile, ox, oz)

	match biome:
		"village":
			_village_builder.build(chunk, tile, ox, oz)
			_rural_road_builder.build(chunk, tile, ox, oz, tile_data)
			_rural_tree_builder.build(chunk, tile, ox, oz, biome)
		"forest":
			_rural_tree_builder.build(chunk, tile, ox, oz, biome)
		"mountain":
			_mountain_builder.build(chunk, tile, ox, oz)
			_rural_tree_builder.build(chunk, tile, ox, oz, biome)
		"farmland":
			_farmland_builder.build(chunk, tile, ox, oz)
			_rural_tree_builder.build(chunk, tile, ox, oz, biome)
		"ocean":
			pass  # sea plane already handled by terrain builder
		_:
			# Default: roads + village + trees (backward compat)
			_village_builder.build(chunk, tile, ox, oz)
			_rural_road_builder.build(chunk, tile, ox, oz, tile_data)
			_rural_tree_builder.build(chunk, tile, ox, oz, biome)


# --- Material palette ---

func _load_tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null


func _apply_pbr(
	mat: StandardMaterial3D, base_path: String, tile: Vector3,
) -> void:
	var color := _load_tex(base_path + "_Color.jpg")
	if color:
		mat.albedo_texture = color
	var normal := _load_tex(base_path + "_NormalGL.jpg")
	if normal:
		mat.normal_enabled = true
		mat.normal_texture = normal
	var rough := _load_tex(base_path + "_Roughness.jpg")
	if rough:
		mat.roughness_texture = rough
		mat.roughness_texture_channel = (
			BaseMaterial3D.TEXTURE_CHANNEL_RED
		)
	var ao := _load_tex(base_path + "_AmbientOcclusion.jpg")
	if ao:
		mat.ao_enabled = true
		mat.ao_texture = ao
		mat.ao_texture_channel = (
			BaseMaterial3D.TEXTURE_CHANNEL_RED
		)
	# Use triplanar mapping — works without UVs on SurfaceTool meshes
	mat.uv1_triplanar = true
	mat.uv1_scale = tile
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


func _init_materials() -> void:
	_road_mat = StandardMaterial3D.new()
	_road_mat.albedo_color = Color(0.2, 0.2, 0.22)
	_apply_pbr(
		_road_mat,
		"res://assets/textures/road/Road007_1K-JPG",
		Vector3(8, 8, 1),
	)

	_sidewalk_mat = StandardMaterial3D.new()
	_sidewalk_mat.albedo_color = Color(0.55, 0.55, 0.53)
	_apply_pbr(
		_sidewalk_mat,
		"res://assets/textures/concrete/Concrete026_1K-JPG",
		Vector3(4, 4, 1),
	)

	_ground_mat = StandardMaterial3D.new()
	_ground_mat.albedo_color = Color(0.45, 0.45, 0.43)
	_apply_pbr(
		_ground_mat,
		"res://assets/textures/grass/Grass001_1K-JPG",
		Vector3(12, 12, 1),
	)

	_marking_mat = StandardMaterial3D.new()
	_marking_mat.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
	_marking_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_marking_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_marking_mat.render_priority = 1
	_marking_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	_ramp_mat = StandardMaterial3D.new()
	_ramp_mat.albedo_color = Color(0.6, 0.55, 0.2)

	for i in 8:
		var wmat := StandardMaterial3D.new()
		wmat.albedo_color = Color(0.18, 0.22, 0.28)
		wmat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_window_mats.append(wmat)

	# 12 building colors — cool-toned skyscraper schemes
	var bld_colors: Array[Color] = [
		Color(0.55, 0.58, 0.62), Color(0.48, 0.50, 0.55),
		Color(0.62, 0.64, 0.66), Color(0.38, 0.42, 0.50),
		Color(0.58, 0.56, 0.52), Color(0.42, 0.45, 0.52),
		Color(0.52, 0.55, 0.60), Color(0.45, 0.48, 0.42),
		Color(0.60, 0.58, 0.55), Color(0.35, 0.40, 0.48),
		Color(0.50, 0.52, 0.48), Color(0.44, 0.46, 0.54),
	]
	for idx in range(bld_colors.size()):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = bld_colors[idx]
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		# Apply brick texture to half the palette for variety
		if idx % 2 == 0:
			_apply_pbr(
				mat,
				"res://assets/textures/brick/Bricks018_1K-JPG",
				Vector3(3, 3, 1),
			)
		_building_mats.append(mat)

	# 5 trunk colors
	var trunk_colors: Array[Color] = [
		Color(0.35, 0.22, 0.10), Color(0.30, 0.18, 0.08),
		Color(0.40, 0.25, 0.12), Color(0.28, 0.20, 0.10),
		Color(0.38, 0.24, 0.14),
	]
	for c in trunk_colors:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = c
		_trunk_mats.append(mat)

	# 10 canopy colors — greens + seasonal autumn variants
	var canopy_colors: Array[Color] = [
		Color(0.15, 0.42, 0.12), Color(0.12, 0.48, 0.10),
		Color(0.18, 0.38, 0.14), Color(0.10, 0.45, 0.08),
		Color(0.20, 0.40, 0.15), Color(0.14, 0.50, 0.12),
		Color(0.85, 0.55, 0.10), Color(0.80, 0.70, 0.15),
		Color(0.65, 0.25, 0.10), Color(0.70, 0.45, 0.12),
	]
	for c in canopy_colors:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = c
		_canopy_mats.append(mat)

	# 6 roof tile colors: red/terracotta clay tile variations for random visual variety
	var roof_colors: Array[Color] = [
		Color(0.75, 0.22, 0.12),  # deep red
		Color(0.82, 0.30, 0.16),  # medium terracotta
		Color(0.68, 0.18, 0.10),  # dark clay red
		Color(0.78, 0.28, 0.14),  # warm red
		Color(0.85, 0.35, 0.18),  # bright terracotta
		Color(0.65, 0.20, 0.11),  # muted brick red
	]
	for c in roof_colors:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = c
		mat.roughness = 0.9
		mat.metallic = 0.0
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_roof_mats.append(mat)

	_pole_mat = StandardMaterial3D.new()
	_pole_mat.albedo_color = Color(0.25, 0.25, 0.25)

	_interior_mat = StandardMaterial3D.new()
	_interior_mat.albedo_color = Color(0.25, 0.25, 0.25)
	_interior_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_interior_mat.roughness = 0.9

	_terrain_mat = StandardMaterial3D.new()
	_terrain_mat.vertex_color_use_as_albedo = true
	_terrain_mat.cull_mode = BaseMaterial3D.CULL_DISABLED


func _init_tree_meshes() -> void:
	# Canonical trunk cylinder (unit size — scaled per instance via transform)
	_trunk_mesh = CylinderMesh.new()
	_trunk_mesh.top_radius = 0.7
	_trunk_mesh.bottom_radius = 1.0
	_trunk_mesh.height = 1.0
	_trunk_mesh.radial_segments = 6
	_trunk_mesh.rings = 1

	# 5 canopy shape variants
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 8
	sphere.rings = 4
	_canopy_meshes.append(sphere)

	var cone := CylinderMesh.new()
	cone.bottom_radius = 1.0
	cone.top_radius = 0.2
	cone.height = 1.0
	cone.radial_segments = 8
	cone.rings = 1
	_canopy_meshes.append(cone)

	var tall := SphereMesh.new()
	tall.radius = 1.0
	tall.height = 3.75
	tall.radial_segments = 8
	tall.rings = 4
	_canopy_meshes.append(tall)

	var flat := SphereMesh.new()
	flat.radius = 1.0
	flat.height = 0.667
	flat.radial_segments = 8
	flat.rings = 4
	_canopy_meshes.append(flat)

	var sphere2 := SphereMesh.new()
	sphere2.radius = 1.0
	sphere2.height = 2.0
	sphere2.radial_segments = 8
	sphere2.rings = 4
	_canopy_meshes.append(sphere2)

	# 5: Pine — narrow tall cone for mountain/forest biomes
	var pine := CylinderMesh.new()
	pine.bottom_radius = 1.0
	pine.top_radius = 0.05
	pine.height = 2.0
	pine.radial_segments = 6
	pine.rings = 1
	_canopy_meshes.append(pine)


func _init_terrain_noise() -> void:
	_terrain_noise = FastNoiseLite.new()
	_terrain_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_terrain_noise.frequency = 0.003
	_terrain_noise.fractal_octaves = 4
	_terrain_noise.fractal_lacunarity = 2.0
	_terrain_noise.fractal_gain = 0.5
	_terrain_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_terrain_noise.seed = 42


func _init_builders() -> void:
	_road_builder.init(_grid, _road_mat, _sidewalk_mat, _ground_mat)
	_building_builder.init(
		_grid, _building_mats, _window_mats, _interior_mat, _roof_mats,
	)
	_tree_builder.init(_grid, _trunk_mats, _canopy_mats, _trunk_mesh, _canopy_meshes)
	_marking_builder.init(_grid, _marking_mat)
	_ramp_builder.init(_grid, _ramp_mat)
	_light_builder.init(_grid, _pole_mat)
	_terrain_builder.init(_grid, _terrain_noise, _terrain_mat, _boundary)
	_village_builder.init(
		_grid, _terrain_noise, _building_mats, _window_mats[0], _boundary,
		_roof_mats, _building_builder,
	)
	_rural_road_builder.init(_grid, _road_mat, _boundary)
	_rural_tree_builder.init(
		_grid, _trunk_mats, _canopy_mats, _trunk_mesh, _canopy_meshes, _boundary
	)
	_suburb_builder.init(
		_grid, _building_mats, _window_mats, _interior_mat,
		_roof_mats, _building_builder,
	)
	_farmland_builder.init(_grid, _boundary)
	_mountain_builder.init(_grid, _boundary)
	_river_map.init(_grid.get_grid_span(), _boundary)
	set_meta("river_map", _river_map)
	_river_builder.init(_grid, _boundary)
	_bridge_builder.init(_grid, _boundary, _road_mat)
	_pier_builder.init(_grid, _boundary)
	_tile_resolver.init(
		_tile_cache, _biome_map, _grid, _boundary, _river_map,
	)


func _build_safety_ground() -> void:
	var body := StaticBody3D.new()
	body.name = "SafetyGround"
	body.position = Vector3(0.0, -20.0, 0.0)
	body.collision_layer = 1
	body.collision_mask = 0
	body.add_to_group("Road")

	var col := CollisionShape3D.new()
	col.shape = WorldBoundaryShape3D.new()
	body.add_child(col)

	add_child(body)


# --- SurfaceTool helpers (shared by builders) ---

## Emit 36 vertices (12 triangles) for an axis-aligned box.
static func st_add_box(st: SurfaceTool, center: Vector3, size: Vector3) -> void:
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var hz := size.z * 0.5
	var cx := center.x
	var cy := center.y
	var cz := center.z

	# 8 corners
	var v0 := Vector3(cx - hx, cy - hy, cz - hz)
	var v1 := Vector3(cx + hx, cy - hy, cz - hz)
	var v2 := Vector3(cx + hx, cy + hy, cz - hz)
	var v3 := Vector3(cx - hx, cy + hy, cz - hz)
	var v4 := Vector3(cx - hx, cy - hy, cz + hz)
	var v5 := Vector3(cx + hx, cy - hy, cz + hz)
	var v6 := Vector3(cx + hx, cy + hy, cz + hz)
	var v7 := Vector3(cx - hx, cy + hy, cz + hz)

	# 6 faces, 2 tris each (CCW winding for outward normals)
	# Front (-Z)
	st.add_vertex(v0); st.add_vertex(v2); st.add_vertex(v1)
	st.add_vertex(v0); st.add_vertex(v3); st.add_vertex(v2)
	# Back (+Z)
	st.add_vertex(v5); st.add_vertex(v6); st.add_vertex(v4)
	st.add_vertex(v4); st.add_vertex(v6); st.add_vertex(v7)
	# Left (-X)
	st.add_vertex(v4); st.add_vertex(v7); st.add_vertex(v0)
	st.add_vertex(v0); st.add_vertex(v7); st.add_vertex(v3)
	# Right (+X)
	st.add_vertex(v1); st.add_vertex(v2); st.add_vertex(v5)
	st.add_vertex(v5); st.add_vertex(v2); st.add_vertex(v6)
	# Top (+Y)
	st.add_vertex(v3); st.add_vertex(v7); st.add_vertex(v2)
	st.add_vertex(v2); st.add_vertex(v7); st.add_vertex(v6)
	# Bottom (-Y)
	st.add_vertex(v4); st.add_vertex(v0); st.add_vertex(v5)
	st.add_vertex(v5); st.add_vertex(v0); st.add_vertex(v1)


## Emit 30 vertices (10 triangles) for a box without the bottom face.
## Use for buildings/objects sitting on ground to avoid z-fighting.
static func st_add_box_no_bottom(
	st: SurfaceTool, center: Vector3, size: Vector3,
) -> void:
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var hz := size.z * 0.5
	var cx := center.x
	var cy := center.y
	var cz := center.z
	var v0 := Vector3(cx - hx, cy - hy, cz - hz)
	var v1 := Vector3(cx + hx, cy - hy, cz - hz)
	var v2 := Vector3(cx + hx, cy + hy, cz - hz)
	var v3 := Vector3(cx - hx, cy + hy, cz - hz)
	var v4 := Vector3(cx - hx, cy - hy, cz + hz)
	var v5 := Vector3(cx + hx, cy - hy, cz + hz)
	var v6 := Vector3(cx + hx, cy + hy, cz + hz)
	var v7 := Vector3(cx - hx, cy + hy, cz + hz)
	# Front (-Z)
	st.add_vertex(v0); st.add_vertex(v2); st.add_vertex(v1)
	st.add_vertex(v0); st.add_vertex(v3); st.add_vertex(v2)
	# Back (+Z)
	st.add_vertex(v5); st.add_vertex(v6); st.add_vertex(v4)
	st.add_vertex(v4); st.add_vertex(v6); st.add_vertex(v7)
	# Left (-X)
	st.add_vertex(v4); st.add_vertex(v7); st.add_vertex(v0)
	st.add_vertex(v0); st.add_vertex(v7); st.add_vertex(v3)
	# Right (+X)
	st.add_vertex(v1); st.add_vertex(v2); st.add_vertex(v5)
	st.add_vertex(v5); st.add_vertex(v2); st.add_vertex(v6)
	# Top (+Y) only — no bottom face
	st.add_vertex(v3); st.add_vertex(v7); st.add_vertex(v2)
	st.add_vertex(v2); st.add_vertex(v7); st.add_vertex(v6)


## Emit a quad as 2 CCW triangles. Vertices must be given in
## bottom-left, bottom-right, top-right, top-left order as seen
## from the outside (outward-facing side).
static func st_add_quad(
	st: SurfaceTool, bl: Vector3, br: Vector3, tr: Vector3, tl: Vector3,
) -> void:
	st.add_vertex(bl); st.add_vertex(tr); st.add_vertex(br)
	st.add_vertex(bl); st.add_vertex(tl); st.add_vertex(tr)


## Emit a face with a rectangular door hole cut out at the bottom-center.
## face_center: world center of the face (at face_height/2 above ground).
## face_width, face_height: dimensions.
## normal: face normal (unused -- kept for API symmetry).
## right: rightward direction along face.
## door_width, door_height: opening dimensions.
static func st_add_face_with_door(
	st: SurfaceTool,
	face_center: Vector3,
	face_width: float, face_height: float,
	_normal: Vector3, right: Vector3,
	door_width: float, door_height: float,
) -> void:
	var up := Vector3.UP
	var hw := face_width * 0.5
	var hh := face_height * 0.5
	var hdw := door_width * 0.5

	# Door top in face-local v (measured from face center)
	var dt := door_height - hh  # offset from face center

	# Left strip (full height)
	var bl := face_center - right * hw - up * hh
	var br := face_center - right * hdw - up * hh
	var tr := face_center - right * hdw + up * hh
	var tl := face_center - right * hw + up * hh
	st_add_quad(st, bl, br, tr, tl)

	# Right strip (full height)
	bl = face_center + right * hdw - up * hh
	br = face_center + right * hw - up * hh
	tr = face_center + right * hw + up * hh
	tl = face_center + right * hdw + up * hh
	st_add_quad(st, bl, br, tr, tl)

	# Above-door strip (door-width, from door_top to face_top)
	bl = face_center - right * hdw + up * dt
	br = face_center + right * hdw + up * dt
	tr = face_center + right * hdw + up * hh
	tl = face_center - right * hdw + up * hh
	st_add_quad(st, bl, br, tr, tl)


## Emit a flat quad on the XZ plane (for road markings).
static func st_add_quad_xz(
	st: SurfaceTool, cx: float, cz: float,
	hw: float, hl: float, y: float,
) -> void:
	var v0 := Vector3(cx - hw, y, cz - hl)
	var v1 := Vector3(cx + hw, y, cz - hl)
	var v2 := Vector3(cx + hw, y, cz + hl)
	var v3 := Vector3(cx - hw, y, cz + hl)
	st.add_vertex(v0); st.add_vertex(v2); st.add_vertex(v1)
	st.add_vertex(v0); st.add_vertex(v3); st.add_vertex(v2)


## Add a BoxShape3D collision child to a StaticBody3D.
static func add_box_collision(body: StaticBody3D, center: Vector3, size: Vector3) -> void:
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	col.position = center
	body.add_child(col)


## Add a ramped sidewalk ConvexPolygonShape3D collision child.
## along_axis: "z" for N-S roads, "x" for E-W roads.
static func add_sidewalk_collision(
	body: StaticBody3D, center: Vector3,
	sw_width: float, length: float,
	sh: float, ramp_run: float,
	along_axis: String,
) -> void:
	var hw := sw_width * 0.5
	var hh := sh * 0.5
	var hl := length * 0.5
	var rr := ramp_run
	var col := CollisionShape3D.new()
	var shape := ConvexPolygonShape3D.new()
	var points: PackedVector3Array
	if along_axis == "z":
		points = PackedVector3Array([
			Vector3(-hw, -hh, -hl),
			Vector3(-hw + rr, hh, -hl),
			Vector3(hw - rr, hh, -hl),
			Vector3(hw, -hh, -hl),
			Vector3(-hw, -hh, hl),
			Vector3(-hw + rr, hh, hl),
			Vector3(hw - rr, hh, hl),
			Vector3(hw, -hh, hl),
		])
	else:
		points = PackedVector3Array([
			Vector3(-hl, -hh, -hw),
			Vector3(-hl, hh, -hw + rr),
			Vector3(-hl, hh, hw - rr),
			Vector3(-hl, -hh, hw),
			Vector3(hl, -hh, -hw),
			Vector3(hl, hh, -hw + rr),
			Vector3(hl, hh, hw - rr),
			Vector3(hl, -hh, hw),
		])
	shape.points = points
	col.shape = shape
	col.position = center
	body.add_child(col)


## Add a CylinderShape3D collision child to a StaticBody3D.
static func add_cylinder_collision(
	body: StaticBody3D, center: Vector3,
	radius: float, height: float,
) -> void:
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	col.shape = shape
	col.position = center
	body.add_child(col)


## Emit window quads on one vertical face of a building.
## face_center: world-space center of the face.
## face_width/face_height: dimensions of the face.
## normal: outward face normal. right: rightward direction along face.
static func st_add_windows_on_face(
	win_st: SurfaceTool,
	face_center: Vector3,
	face_width: float, face_height: float,
	normal: Vector3,
	right: Vector3,
	rng: RandomNumberGenerator,
) -> void:
	var win_w := 1.5
	var win_h := 2.0
	var gap_x := rng.randf_range(0.6, 1.2)
	var gap_y := 1.0
	var floor_h := win_h + gap_y
	var margin_x := 1.0
	var margin_bottom := 3.0
	var margin_top := 2.0
	var offset := normal * 0.02

	var usable_w := face_width - margin_x * 2.0
	var usable_h := face_height - margin_bottom - margin_top
	if usable_w < win_w or usable_h < win_h:
		return

	var cols := int(usable_w / (win_w + gap_x))
	var rows := int(usable_h / floor_h)
	if cols < 1 or rows < 1:
		return

	var total_w := cols * win_w + (cols - 1) * gap_x
	var start_x := -total_w * 0.5 + win_w * 0.5
	var start_y := -face_height * 0.5 + margin_bottom + win_h * 0.5

	var up := Vector3.UP
	for row in range(rows):
		for col in range(cols):
			var cx := start_x + col * (win_w + gap_x)
			var cy := start_y + row * floor_h
			var center := face_center + right * cx + up * cy + offset
			var hw := win_w * 0.5
			var hh := win_h * 0.5
			var v0 := center - right * hw - up * hh
			var v1 := center + right * hw - up * hh
			var v2 := center + right * hw + up * hh
			var v3 := center - right * hw + up * hh
			win_st.add_vertex(v0)
			win_st.add_vertex(v2)
			win_st.add_vertex(v1)
			win_st.add_vertex(v0)
			win_st.add_vertex(v3)
			win_st.add_vertex(v2)


## Like st_add_windows_on_face but picks a random SurfaceTool per window quad
## so each window belongs to an independent material group and can toggle on/off
## separately from its neighbours on the same wall.
## win_sts: pool of SurfaceTools (one per material group).
## win_st_has_data: parallel bool array; set to true when a ST is first begun.
static func st_add_windows_on_face_indep(
	win_sts: Array,
	win_count: int,
	win_st_has_data: Array,
	face_center: Vector3,
	face_width: float, face_height: float,
	normal: Vector3,
	right: Vector3,
	rng: RandomNumberGenerator,
) -> void:
	var win_w := 1.5
	var win_h := 2.0
	var gap_x := rng.randf_range(0.6, 1.2)
	var gap_y := 1.0
	var floor_h := win_h + gap_y
	var margin_x := 1.0
	var margin_bottom := 3.0
	var margin_top := 2.0
	var offset := normal * 0.02

	var usable_w := face_width - margin_x * 2.0
	var usable_h := face_height - margin_bottom - margin_top
	if usable_w < win_w or usable_h < win_h:
		return

	var cols := int(usable_w / (win_w + gap_x))
	var rows := int(usable_h / floor_h)
	if cols < 1 or rows < 1:
		return

	var total_w := cols * win_w + (cols - 1) * gap_x
	var start_x := -total_w * 0.5 + win_w * 0.5
	var start_y := -face_height * 0.5 + margin_bottom + win_h * 0.5

	var up := Vector3.UP
	for row in range(rows):
		for col in range(cols):
			var wi: int = rng.randi() % win_count
			if not win_st_has_data[wi]:
				(win_sts[wi] as SurfaceTool).begin(Mesh.PRIMITIVE_TRIANGLES)
				win_st_has_data[wi] = true
			var win_st: SurfaceTool = win_sts[wi]
			var cx := start_x + col * (win_w + gap_x)
			var cy := start_y + row * floor_h
			var center := face_center + right * cx + up * cy + offset
			var hw := win_w * 0.5
			var hh := win_h * 0.5
			var v0 := center - right * hw - up * hh
			var v1 := center + right * hw - up * hh
			var v2 := center + right * hw + up * hh
			var v3 := center - right * hw + up * hh
			win_st.add_vertex(v0)
			win_st.add_vertex(v2)
			win_st.add_vertex(v1)
			win_st.add_vertex(v0)
			win_st.add_vertex(v3)
			win_st.add_vertex(v2)
