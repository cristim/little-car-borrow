extends RefCounted
## Noise-modulated circular city boundary.
## Produces an organic blob shape instead of a square grid.
## Shared by city.gd, terrain builder, village builder, and minimap.

const BASE_RADIUS := 3.8  # tiles from origin
const VARIATION := 0.8  # +/- tiles of noise modulation
const LOOP_RADIUS := 2.5  # radius in noise space for seamless loop
const NOISE_SEED := 77
const NOISE_FREQ := 0.3

var _noise: FastNoiseLite
var _grid_span: float


func init(grid_span: float) -> void:
	_grid_span = grid_span
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
