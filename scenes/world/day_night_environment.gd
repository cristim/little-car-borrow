extends Node
## Animates sky, sun, fog, ambient light, window glow, stars, moon, and clouds
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
	[0.0, 0.01], [5.0, 0.01], [6.0, 0.18], [7.0, 0.09],
	[17.0, 0.09], [18.0, 0.28], [20.0, 0.01], [24.0, 0.01],
]
const SKY_TOP_G := [
	[0.0, 0.01], [5.0, 0.01], [6.0, 0.18], [7.0, 0.22],
	[17.0, 0.22], [18.0, 0.18], [20.0, 0.01], [24.0, 0.01],
]
const SKY_TOP_B := [
	[0.0, 0.05], [5.0, 0.05], [6.0, 0.48], [7.0, 0.82],
	[17.0, 0.82], [18.0, 0.38], [20.0, 0.05], [24.0, 0.05],
]
const SKY_HOR_R := [
	[0.0, 0.02], [5.0, 0.02], [6.0, 0.82], [7.0, 0.36],
	[17.0, 0.36], [18.0, 0.90], [20.0, 0.02], [24.0, 0.02],
]
const SKY_HOR_G := [
	[0.0, 0.02], [5.0, 0.02], [6.0, 0.42], [7.0, 0.62],
	[17.0, 0.62], [18.0, 0.40], [20.0, 0.02], [24.0, 0.02],
]
const SKY_HOR_B := [
	[0.0, 0.08], [5.0, 0.08], [6.0, 0.22], [7.0, 0.82],
	[17.0, 0.82], [18.0, 0.16], [20.0, 0.08], [24.0, 0.08],
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

# Moon / stars
const MOON_DIST := 4000.0
const MOON_RADIUS := 180.0
const STAR_SPHERE_R := 4800.0

# Clouds / weather — index = weather state: 0=clear, 1=cloudy, 2=overcast
const CLOUD_COUNT := 8
const CLOUD_DRIFT_SPEED := 2.5
const CLOUD_ALT_MIN := 130.0
const CLOUD_ALT_MAX := 260.0
const CLOUD_SPAWN_HALF := 700.0
const WEATHER_INTERVAL_MIN := 60.0
const WEATHER_INTERVAL_MAX := 200.0
const WEATHER_FOG: Array = [0.00015, 0.0007, 0.002]
const WEATHER_CLOUD_A: Array = [0.22, 0.58, 0.88]
const WEATHER_CLOUD_G: Array = [1.0, 0.80, 0.55]

@export var light_path: NodePath
@export var env_path: NodePath
@export var city_path: NodePath

var _light: DirectionalLight3D
var _env: WorldEnvironment
var _city: Node3D
var _sky_mat: ProceduralSkyMaterial
var _last_lights_visible := false
var _last_window_night := false
var _mat_active: Array[bool] = []  # sized dynamically to match window mat count
var _rng := RandomNumberGenerator.new()
var _window_toggle_timer: Timer

var _moon: MeshInstance3D
var _moon_mat: ShaderMaterial
var _moon_phase: float = 0.5
var _star_sphere: MeshInstance3D
var _star_mat: ShaderMaterial
var _clouds: Array[Node3D] = []
var _cloud_mats: Array[StandardMaterial3D] = []
var _cloud_wx: Array[float] = []
var _cloud_wz: Array[float] = []
var _cloud_wy: Array[float] = []
var _weather: int = 0
var _weather_timer: Timer
var _fog_current: float = 0.0005
var _cloud_alpha: float = 0.22
var _cloud_grey: float = 1.0


func _ready() -> void:
	_light = get_node_or_null(light_path) as DirectionalLight3D
	_env = get_node_or_null(env_path) as WorldEnvironment
	_city = get_node_or_null(city_path) as Node3D

	if _env and _env.environment:
		var sky: Sky = _env.environment.sky
		if sky:
			_sky_mat = sky.sky_material as ProceduralSkyMaterial

	_rng.randomize()
	_moon_phase = _rng.randf()

	_window_toggle_timer = Timer.new()
	_window_toggle_timer.one_shot = true
	_window_toggle_timer.timeout.connect(_on_window_toggle)
	add_child(_window_toggle_timer)

	_setup_moon()
	_setup_stars()
	_setup_clouds()

	_weather_timer = Timer.new()
	_weather_timer.one_shot = true
	_weather_timer.timeout.connect(_on_weather_change)
	add_child(_weather_timer)
	_weather_timer.wait_time = _rng.randf_range(WEATHER_INTERVAL_MIN, WEATHER_INTERVAL_MAX)
	_weather_timer.start()


func _process(delta: float) -> void:
	var h: float = DayNightManager.current_hour
	_update_sun(h)
	_update_sky(h)
	_update_fog(h, delta)
	_update_ambient(h)
	_update_windows(h)
	_update_streetlights()
	_update_moon(h)
	_update_stars(h)
	_update_clouds(delta)


func _setup_moon() -> void:
	var mesh := SphereMesh.new()
	mesh.radius = MOON_RADIUS
	mesh.height = MOON_RADIUS * 2.0
	mesh.radial_segments = 24
	mesh.rings = 12

	var shader := Shader.new()
	shader.code = _moon_shader_src()
	_moon_mat = ShaderMaterial.new()
	_moon_mat.shader = shader
	_moon_mat.set_shader_parameter("phase", _moon_phase)
	_moon_mat.set_shader_parameter("brightness", 0.0)

	_moon = MeshInstance3D.new()
	_moon.mesh = mesh
	_moon.set_surface_override_material(0, _moon_mat)
	_moon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_moon.visible = false
	add_child(_moon)


func _setup_stars() -> void:
	var mesh := SphereMesh.new()
	mesh.radius = STAR_SPHERE_R
	mesh.height = STAR_SPHERE_R * 2.0
	mesh.radial_segments = 32
	mesh.rings = 16

	var shader := Shader.new()
	shader.code = _star_shader_src()

	_star_mat = ShaderMaterial.new()
	_star_mat.shader = shader
	_star_mat.set_shader_parameter("star_alpha", 0.0)

	_star_sphere = MeshInstance3D.new()
	_star_sphere.mesh = mesh
	_star_sphere.set_surface_override_material(0, _star_mat)
	_star_sphere.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_star_sphere)


func _setup_clouds() -> void:
	for _i in CLOUD_COUNT:
		# Each cloud is a cluster of overlapping flattened spheres (puffs).
		# Sharing one material per cluster lets us tint/fade the whole cloud at once.
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(1.0, 1.0, 1.0, 0.0)

		var cluster := Node3D.new()
		add_child(cluster)

		var puff_count: int = _rng.randi_range(4, 7)
		var cluster_width: float = _rng.randf_range(120.0, 280.0)
		for _j in puff_count:
			var r: float = _rng.randf_range(35.0, 70.0)
			var puff_mesh := SphereMesh.new()
			puff_mesh.radius = r
			puff_mesh.height = r * 2.0
			puff_mesh.radial_segments = 10
			puff_mesh.rings = 5

			var puff := MeshInstance3D.new()
			puff.mesh = puff_mesh
			puff.set_surface_override_material(0, mat)
			puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			# Flatten vertically, spread horizontally for a classic cloud silhouette
			var sx: float = _rng.randf_range(0.9, 1.4)
			var sy: float = _rng.randf_range(0.35, 0.55)
			var sz: float = _rng.randf_range(0.7, 1.1)
			puff.scale = Vector3(sx, sy, sz)
			puff.position = Vector3(
				_rng.randf_range(-cluster_width * 0.5, cluster_width * 0.5),
				_rng.randf_range(-8.0, 8.0),
				_rng.randf_range(-cluster_width * 0.2, cluster_width * 0.2),
			)
			cluster.add_child(puff)

		var wx: float = _rng.randf_range(-CLOUD_SPAWN_HALF, CLOUD_SPAWN_HALF)
		var wz: float = _rng.randf_range(-CLOUD_SPAWN_HALF, CLOUD_SPAWN_HALF)
		var wy: float = _rng.randf_range(CLOUD_ALT_MIN, CLOUD_ALT_MAX)
		cluster.global_position = Vector3(wx, wy, wz)
		cluster.rotation.y = _rng.randf_range(0.0, TAU)

		_clouds.append(cluster)
		_cloud_mats.append(mat)
		_cloud_wx.append(wx)
		_cloud_wz.append(wz)
		_cloud_wy.append(wy)


func _update_sun(h: float) -> void:
	if not _light:
		return
	var pitch := deg_to_rad(-_sample(SUN_PITCH, h))
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


func _update_fog(h: float, delta: float) -> void:
	if not _env or not _env.environment:
		return
	_env.environment.fog_light_color = Color(
		_sample(SKY_HOR_R, h),
		_sample(SKY_HOR_G, h),
		_sample(SKY_HOR_B, h),
	)
	# Reduce fog during bright daytime — fog is mainly a low-light / night effect
	var sun_e: float = _sample(SUN_ENERGY, h)
	var day_suppress: float = lerpf(1.0, 0.08, sun_e)
	var fog_target: float = WEATHER_FOG[_weather] * day_suppress
	_fog_current = lerpf(_fog_current, fog_target, delta * 0.3)
	_env.environment.fog_density = _fog_current


func _update_ambient(h: float) -> void:
	if not _env or not _env.environment:
		return
	_env.environment.ambient_light_energy = _sample(AMBIENT_ENERGY, h)


func _update_moon(h: float) -> void:
	if not _moon:
		return
	var night: float = _night_factor(h)
	_moon.visible = night > 0.01
	if not _moon.visible:
		return
	var cam: Camera3D = get_viewport().get_camera_3d()
	var origin: Vector3 = cam.global_position if cam else Vector3.ZERO
	var sun_fwd: Vector3 = -_light.global_basis.z if _light else Vector3(0.0, -1.0, 0.0)
	# Moon opposite the sun; ensure it stays above horizon
	var moon_dir: Vector3 = Vector3(-sun_fwd.x, absf(sun_fwd.y) + 0.15, -sun_fwd.z).normalized()
	_moon.global_position = origin + moon_dir * MOON_DIST
	_moon_mat.set_shader_parameter("brightness", night)


func _update_stars(h: float) -> void:
	if not _star_sphere or not _star_mat:
		return
	_star_mat.set_shader_parameter("star_alpha", _night_factor(h))
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam:
		_star_sphere.global_position = cam.global_position


func _update_clouds(delta: float) -> void:
	var a_target: float = WEATHER_CLOUD_A[_weather]
	var g_target: float = WEATHER_CLOUD_G[_weather]
	_cloud_alpha = lerpf(_cloud_alpha, a_target, delta * 0.15)
	_cloud_grey = lerpf(_cloud_grey, g_target, delta * 0.15)
	var c := Color(_cloud_grey, _cloud_grey, _cloud_grey, _cloud_alpha)
	for i in _clouds.size():
		_cloud_wx[i] += CLOUD_DRIFT_SPEED * delta
		if _cloud_wx[i] > CLOUD_SPAWN_HALF * 2.0:
			_cloud_wx[i] = -CLOUD_SPAWN_HALF * 2.0
		_clouds[i].global_position = Vector3(_cloud_wx[i], _cloud_wy[i], _cloud_wz[i])
		_cloud_mats[i].albedo_color = c


func _on_weather_change() -> void:
	var roll: float = _rng.randf()
	if roll < 0.5:
		_weather = 0  # clear — most common
	elif roll < 0.8:
		_weather = 1  # cloudy
	else:
		_weather = 2  # overcast
	_weather_timer.wait_time = _rng.randf_range(WEATHER_INTERVAL_MIN, WEATHER_INTERVAL_MAX)
	_weather_timer.start()


func _night_factor(h: float) -> float:
	return clampf(1.0 - _sample(SUN_ENERGY, h) * 2.5, 0.0, 1.0)


func _update_windows(h: float) -> void:
	if not _city:
		return
	var mats_v: Variant = _city.get("_window_mats")
	if mats_v == null:
		return
	var mats: Array = mats_v
	if mats.is_empty():
		return
	var night := h < 6.0 or h > 19.0
	if night == _last_window_night:
		return
	_last_window_night = night
	if night:
		# Random initial pattern: each group independently 55% chance of being lit
		_mat_active.resize(mats.size())
		for i in mats.size():
			_mat_active[i] = _rng.randf() < 0.55
			var mat: StandardMaterial3D = mats[i]
			mat.emission_enabled = _mat_active[i]
			mat.emission = Color(0.9, 0.8, 0.5)
			mat.emission_energy_multiplier = 0.6
		if _window_toggle_timer.is_stopped():
			_window_toggle_timer.wait_time = _rng.randf_range(5.0, 12.0)
			_window_toggle_timer.start()
	else:
		for mat in mats:
			(mat as StandardMaterial3D).emission_enabled = false
		_window_toggle_timer.stop()
		_mat_active.resize(mats.size())
		_mat_active.fill(true)  # reset so next night starts from full state


func _on_window_toggle() -> void:
	if not _city:
		return
	var mats_v: Variant = _city.get("_window_mats")
	if mats_v == null:
		return
	var mats: Array = mats_v
	if mats.is_empty():
		return
	# Don't toggle if it's no longer night
	var h: float = DayNightManager.current_hour
	if not (h < 6.0 or h > 19.0):
		return

	if mats.size() != _mat_active.size():
		return

	var on_indices: Array[int] = []
	var off_indices: Array[int] = []
	for i in _mat_active.size():
		if _mat_active[i]:
			on_indices.append(i)
		else:
			off_indices.append(i)

	# Bias strongly toward turning off — simulates people going to sleep over time.
	# Keep at least 2 groups lit so the city never goes completely dark.
	if _rng.randf() < 0.75 and on_indices.size() > 2:
		var pick: int = on_indices[_rng.randi_range(0, on_indices.size() - 1)]
		_mat_active[pick] = false
		(mats[pick] as StandardMaterial3D).emission_enabled = false
	elif off_indices.size() > 0:
		# Occasionally turn one back on (light sleepers, night owls)
		var pick: int = off_indices[_rng.randi_range(0, off_indices.size() - 1)]
		_mat_active[pick] = true
		(mats[pick] as StandardMaterial3D).emission_enabled = true

	# Fast interval so changes feel organic, not robotic
	_window_toggle_timer.wait_time = _rng.randf_range(5.0, 12.0)
	_window_toggle_timer.start()


func _update_streetlights() -> void:
	var show := (
		DayNightManager.is_night()
		or DayNightManager.is_dusk_or_dawn()
	)
	if show == _last_lights_visible:
		return
	_last_lights_visible = show
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


## Inline GLSL for the moon sphere with phase rendering.
## phase: 0=new moon (dark), 0.25=waxing quarter, 0.5=full, 0.75=waning quarter.
## The terminator is computed in view-space so it always faces the camera correctly.
static func _moon_shader_src() -> String:
	return """shader_type spatial;
render_mode unshaded;

uniform float phase : hint_range(0.0, 1.0) = 0.5;
uniform float brightness : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec3 n = normalize(NORMAL);

	// Terminator line sweeps across the disc as phase changes.
	// cos(phase*TAU): +1 at new moon, -1 at full moon, +1 at new moon.
	// Waxing (0..0.5): right side lit. Waning (0.5..1): left side lit.
	float px = cos(phase * 6.2832);
	float flip = phase > 0.5 ? -1.0 : 1.0;
	float lit = smoothstep(-0.06, 0.06, flip * n.x - px);

	// Subtle surface shading to suggest craters / texture depth
	float shade = 0.80 + 0.20 * dot(n, normalize(vec3(0.3, 0.5, 1.0)));

	vec3 lit_col = vec3(0.94, 0.89, 0.76) * shade;
	vec3 dark_col = vec3(0.01, 0.01, 0.03);

	ALBEDO = mix(dark_col, lit_col, lit) * brightness;
	EMISSION = lit_col * lit * 2.2 * brightness;
}
"""


## Inline GLSL for the star sphere (viewed from inside via cull_front).
## Stars are pushed to the far depth plane (z=0 in Godot 4 reverse-Z) so geometry occludes them.
static func _star_shader_src() -> String:
	return """shader_type spatial;
render_mode unshaded, cull_front, blend_add;

uniform float star_alpha : hint_range(0.0, 1.0) = 0.0;

float hash2(vec2 p) {
	p = fract(p * vec2(127.1, 311.7));
	p += dot(p, p + 34.23);
	return fract(p.x * p.y);
}

void vertex() {
	vec4 clip = PROJECTION_MATRIX * (VIEW_MATRIX * (MODEL_MATRIX * vec4(VERTEX, 1.0)));
	POSITION = vec4(clip.xy, 0.0, clip.w);
}

void fragment() {
	// Layer 1 — dense background field: tiny dim stars, size range ~3x
	vec2 g1 = UV * 96.0;
	vec2 id1 = floor(g1);
	vec2 lc1 = fract(g1) - 0.5;
	float h1 = hash2(id1);
	float sz1 = 0.007 + h1 * 0.010;
	float glow1 = step(0.91, h1)
		* smoothstep(sz1, 0.0, length(lc1))
		* star_alpha;
	vec3 col1 = mix(vec3(0.85, 0.92, 1.0), vec3(1.0, 0.93, 0.78), h1) * glow1;

	// Layer 2 — constellation anchors: sparser, clearly larger, noticeably brighter
	vec2 g2 = UV * 30.0;
	vec2 id2 = floor(g2);
	vec2 lc2 = fract(g2) - 0.5;
	float h2 = hash2(id2 + vec2(53.1, 97.4));
	float sz2 = 0.016 + h2 * 0.018;
	float glow2 = step(0.79, h2)
		* smoothstep(sz2, 0.0, length(lc2))
		* star_alpha;
	vec3 col2 = mix(vec3(0.9, 0.95, 1.0), vec3(1.0, 0.82, 0.55), h2) * glow2 * 1.4;

	// Layer 3 — rare prominent stars: largest, with a soft halo
	vec2 g3 = UV * 12.0;
	vec2 id3 = floor(g3);
	vec2 lc3 = fract(g3) - 0.5;
	float h3 = hash2(id3 + vec2(11.3, 137.8));
	float d3 = length(lc3);
	float sz3 = 0.032 + h3 * 0.022;
	float present3 = step(0.88, h3);
	float core3 = present3 * smoothstep(sz3, 0.0, d3);
	float halo3 = present3 * smoothstep(0.16, 0.0, d3) * 0.22;
	float glow3 = (core3 + halo3) * star_alpha;
	vec3 col3 = mix(vec3(0.7, 0.85, 1.0), vec3(1.0, 0.75, 0.5), h3) * glow3 * 1.8;

	ALBEDO = col1 + col2 + col3;
	EMISSION = col1 + col2 + col3;
}
"""
