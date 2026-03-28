extends RefCounted
## Noise-modulated circular city boundary.
## Produces an organic blob shape instead of a square grid.
## Shared by city.gd, terrain builder, village builder, and minimap.

const BASE_RADIUS := 0.76  # tiles from origin  # TODO: restore to 3.8
const VARIATION := 0.16  # +/- tiles of noise modulation  # TODO: restore to 0.8
const LOOP_RADIUS := 2.5  # radius in noise space for seamless loop
const NOISE_SEED := 77
const NOISE_FREQ := 0.3
## Must match chunk_builder_terrain.SUBDIVISIONS so get_mesh_height()
## bilinearly interpolates at exactly the same grid resolution as the mesh.
const TERRAIN_SUBDIVISIONS := 16

var _noise: FastNoiseLite
var _grid_span: float
var _terrain_noise: FastNoiseLite


func init(grid_span: float, terrain_noise: FastNoiseLite = null) -> void:
	_grid_span = grid_span
	_terrain_noise = terrain_noise
	_noise = FastNoiseLite.new()
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.seed = NOISE_SEED
	_noise.frequency = NOISE_FREQ
	_noise.fractal_octaves = 1


## Returns the boundary radius (in world units) at the given angle.
func get_boundary_radius_at_angle(angle: float) -> float:
	var nx: float = cos(angle) * LOOP_RADIUS
	var nz: float = sin(angle) * LOOP_RADIUS
	var raw: float = _noise.get_noise_2d(nx, nz)
	var tile_radius: float = BASE_RADIUS + raw * VARIATION
	return (tile_radius + 0.5) * _grid_span


## Returns true if the given tile coordinate is inside the city boundary.
func is_city_tile(tile: Vector2i) -> bool:
	var center_x: float = float(tile.x) * _grid_span
	var center_z: float = float(tile.y) * _grid_span
	var dist: float = sqrt(center_x * center_x + center_z * center_z)
	var angle: float = atan2(center_z, center_x)
	return dist < get_boundary_radius_at_angle(angle)


## Returns signed distance from the boundary at a world position.
## Negative = inside city, positive = outside city.
func get_signed_distance(wx: float, wz: float) -> float:
	var dist: float = sqrt(wx * wx + wz * wz)
	var angle: float = atan2(wz, wx)
	return dist - get_boundary_radius_at_angle(angle)


## Returns a polygon (PackedVector2Array) approximating the boundary.
## Points are in world XZ coordinates.
func get_boundary_polygon(segments: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.resize(segments)
	var step: float = TAU / float(segments)
	for i in range(segments):
		var angle: float = float(i) * step
		var r: float = get_boundary_radius_at_angle(angle)
		pts[i] = Vector2(cos(angle) * r, sin(angle) * r)
	return pts


## Returns terrain height matched to the actual rendered mesh surface.
## The terrain mesh is a grid of SUBDIVISIONS×SUBDIVISIONS quads per chunk,
## linearly interpolated between vertices.  Evaluating the raw noise formula
## at an arbitrary point gives the curved noise value, which diverges from
## the flat triangle face when terrain curves — causing trees to appear to
## float.  This function bilinearly interpolates the same four grid-corner
## heights that the mesh uses, so the result sits exactly on the surface.
func get_mesh_height(wx: float, wz: float) -> float:
	var step: float = _grid_span / float(TERRAIN_SUBDIVISIONS)
	# Grid-aligned corner to the south-west of the point
	var gx: float = floor(wx / step) * step
	var gz: float = floor(wz / step) * step
	# Sample four corners at actual mesh vertex positions
	var h00: float = get_ground_height(gx, gz)
	var h10: float = get_ground_height(gx + step, gz)
	var h01: float = get_ground_height(gx, gz + step)
	var h11: float = get_ground_height(gx + step, gz + step)
	# Bilinear interpolation — matches the flat-quad mesh surface
	var fx: float = (wx - gx) / step
	var fz: float = (wz - gz) / step
	return lerpf(lerpf(h00, h10, fx), lerpf(h01, h11, fx), fz)


## Returns the terrain ground height at a world XZ position.
## Matches chunk_builder_terrain.gd _sample_height() exactly.
## Requires terrain_noise passed to init().
func get_ground_height(wx: float, wz: float) -> float:
	if not _terrain_noise:
		return 0.0

	var edge_dist: float = get_signed_distance(wx, wz)
	if edge_dist < 0.0:
		return 0.0

	var raw: float = _terrain_noise.get_noise_2d(wx, wz)
	var n: float = (raw + 1.0) * 0.5
	var fade: float = clampf(
		edge_dist / (_grid_span * 3.0), 0.0, 1.0
	)
	var max_h: float = lerpf(20.0, 80.0, fade)
	var h: float = n * max_h - 6.0

	# West ocean: terrain descends below sea level westward.
	# Shore slope starts ~2.5 tiles west (just past suburb ring at ~2.26),
	# fully submerged by ~3.5 tiles. 100m depression overwhelms terrain noise.
	var shore_start: float = _grid_span * 2.5
	var shore_end: float = _grid_span * 3.5
	var in_ocean := -wx > shore_start
	if in_ocean:
		var shore_t: float = clampf(
			(-wx - shore_start) / (shore_end - shore_start), 0.0, 1.0,
		)
		h -= shore_t * shore_t * 100.0

	# Non-ocean terrain stays above sea level (no scattered ponds)
	if not in_ocean:
		h = maxf(h, -2.0)

	# Negative heights allowed for beach slopes and underwater seabed.
	var blend_range: float = _grid_span * 2.0
	if edge_dist < blend_range:
		var t: float = edge_dist / blend_range
		t = t * t * t
		h = lerpf(0.0, h, t)

	return h
