extends Node
## Animates sky, sun, fog, ambient light, and window glow
## based on DayNightManager. Set exported NodePaths in the scene.

# Keyframe curves: [[hour, value], ...] — linearly interpolated.
# Sun pitch (degrees above horizon)
const SUN_PITCH := [
	[0.0, -20.0], [5.0, -20.0], [6.0, 10.0], [7.0, 45.0],
	[12.0, 60.0], [17.0, 45.0], [19.0, 10.0],
	[20.0, -20.0], [24.0, -20.0],
]
const SUN_ENERGY := [
	[0.0, 0.0], [5.0, 0.0], [6.0, 0.3], [7.0, 1.0],
	[17.0, 1.0], [19.0, 0.3], [20.0, 0.0], [24.0, 0.0],
]
const AMBIENT_ENERGY := [
	[0.0, 0.05], [5.0, 0.05], [6.0, 0.1], [7.0, 0.3],
	[17.0, 0.3], [19.0, 0.15], [20.0, 0.05], [24.0, 0.05],
]
const SKY_TOP_R := [
	[0.0, 0.02], [5.0, 0.02], [6.0, 0.2], [7.0, 0.35],
	[17.0, 0.35], [18.0, 0.4], [20.0, 0.02], [24.0, 0.02],
]
const SKY_TOP_G := [
	[0.0, 0.02], [5.0, 0.02], [6.0, 0.3], [7.0, 0.55],
	[17.0, 0.55], [18.0, 0.3], [20.0, 0.02], [24.0, 0.02],
]
const SKY_TOP_B := [
	[0.0, 0.08], [5.0, 0.08], [6.0, 0.5], [7.0, 0.85],
	[17.0, 0.85], [18.0, 0.4], [20.0, 0.08], [24.0, 0.08],
]
const SKY_HOR_R := [
	[0.0, 0.05], [5.0, 0.05], [6.0, 0.7], [7.0, 0.6],
	[17.0, 0.6], [18.0, 0.8], [20.0, 0.05], [24.0, 0.05],
]
const SKY_HOR_G := [
	[0.0, 0.05], [5.0, 0.05], [6.0, 0.4], [7.0, 0.7],
	[17.0, 0.7], [18.0, 0.4], [20.0, 0.05], [24.0, 0.05],
]
const SKY_HOR_B := [
	[0.0, 0.15], [5.0, 0.15], [6.0, 0.3], [7.0, 0.85],
	[17.0, 0.85], [18.0, 0.3], [20.0, 0.15], [24.0, 0.15],
]
const SUN_COL_R := [
	[0.0, 0.2], [5.0, 0.2], [6.0, 1.0], [7.0, 1.0],
	[17.0, 1.0], [18.0, 1.0], [20.0, 0.2], [24.0, 0.2],
]
const SUN_COL_G := [
	[0.0, 0.2], [5.0, 0.2], [6.0, 0.6], [7.0, 0.95],
	[17.0, 0.95], [18.0, 0.6], [20.0, 0.2], [24.0, 0.2],
]
const SUN_COL_B := [
	[0.0, 0.3], [5.0, 0.3], [6.0, 0.3], [7.0, 0.9],
	[17.0, 0.9], [18.0, 0.3], [20.0, 0.3], [24.0, 0.3],
]

@export var light_path: NodePath
@export var env_path: NodePath
@export var city_path: NodePath

var _light: DirectionalLight3D
var _env: WorldEnvironment
var _city: Node3D
var _sky_mat: ProceduralSkyMaterial


func _ready() -> void:
	_light = get_node_or_null(light_path) as DirectionalLight3D
	_env = get_node_or_null(env_path) as WorldEnvironment
	_city = get_node_or_null(city_path) as Node3D

	if _env and _env.environment:
		var sky: Sky = _env.environment.sky
		if sky:
			_sky_mat = sky.sky_material as ProceduralSkyMaterial


func _process(_delta: float) -> void:
	var h: float = DayNightManager.current_hour
	_update_sun(h)
	_update_sky(h)
	_update_fog(h)
	_update_ambient(h)
	_update_windows(h)
	_update_streetlights()


func _update_sun(h: float) -> void:
	if not _light:
		return
	var pitch := deg_to_rad(_sample(SUN_PITCH, h))
	var yaw := lerpf(-PI * 0.5, PI * 0.5, h / 24.0)
	_light.rotation = Vector3(pitch, yaw, 0.0)
	_light.light_energy = _sample(SUN_ENERGY, h)
	_light.light_color = Color(
		_sample(SUN_COL_R, h),
		_sample(SUN_COL_G, h),
		_sample(SUN_COL_B, h),
	)
	_light.visible = _light.light_energy > 0.01


func _update_sky(h: float) -> void:
	if not _sky_mat:
		return
	_sky_mat.sky_top_color = Color(
		_sample(SKY_TOP_R, h),
		_sample(SKY_TOP_G, h),
		_sample(SKY_TOP_B, h),
	)
	_sky_mat.sky_horizon_color = Color(
		_sample(SKY_HOR_R, h),
		_sample(SKY_HOR_G, h),
		_sample(SKY_HOR_B, h),
	)


func _update_fog(h: float) -> void:
	if not _env or not _env.environment:
		return
	_env.environment.fog_light_color = Color(
		_sample(SKY_HOR_R, h),
		_sample(SKY_HOR_G, h),
		_sample(SKY_HOR_B, h),
	)


func _update_ambient(h: float) -> void:
	if not _env or not _env.environment:
		return
	_env.environment.ambient_light_energy = _sample(
		AMBIENT_ENERGY, h
	)


func _update_windows(h: float) -> void:
	if not _city:
		return
	var win_mat = _city.get("_window_mat") as StandardMaterial3D
	if not win_mat:
		return
	var night := h < 6.0 or h > 19.0
	if night:
		win_mat.emission_enabled = true
		win_mat.emission = Color(0.9, 0.8, 0.5)
		win_mat.emission_energy_multiplier = 0.6
	else:
		win_mat.emission_enabled = false


func _update_streetlights() -> void:
	var show := (
		DayNightManager.is_night()
		or DayNightManager.is_dusk_or_dawn()
	)
	get_tree().call_group("streetlight", "set_visible", show)


## Sample a piecewise-linear curve at the given hour.
static func _sample(curve: Array, h: float) -> float:
	if curve.is_empty():
		return 0.0
	if h <= curve[0][0]:
		return curve[0][1]
	for i in range(1, curve.size()):
		if h <= curve[i][0]:
			var prev_h: float = curve[i - 1][0]
			var prev_v: float = curve[i - 1][1]
			var curr_h: float = curve[i][0]
			var curr_v: float = curve[i][1]
			var t := (h - prev_h) / (curr_h - prev_h)
			return lerpf(prev_v, curr_v, t)
	return curve[curve.size() - 1][1]
