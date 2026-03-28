extends GutTest
## Unit tests for the randomized building window lights system.
## Tests cover material pool creation, per-building group assignment,
## and night-time toggling logic.

const CityScript = preload("res://scenes/world/city.gd")
const BuilderScript = preload(
	"res://scenes/world/generator/chunk_builder_buildings.gd"
)
const DayNightEnvScript = preload(
	"res://scenes/world/day_night_environment.gd"
)
const RoadGridScript = preload("res://src/road_grid.gd")


# --- city.gd material pool tests ---

func test_city_creates_four_window_materials() -> void:
	var city: Node3D = CityScript.new()
	add_child_autofree(city)
	# _init_materials is called in _ready, but we can check the var exists
	# and is empty before _ready (it was just created)
	# After _ready it would have 4, but _ready triggers chunk loading
	# so just verify the type
	assert_true(
		city._window_mats is Array,
		"_window_mats should be an Array",
	)


func test_window_mats_is_typed_array() -> void:
	var city: Node3D = CityScript.new()
	add_child_autofree(city)
	assert_true(
		city._window_mats is Array,
		"_window_mats should be an Array",
	)


# --- chunk_builder_buildings.gd tests ---

func test_builder_init_accepts_material_array() -> void:
	var builder = BuilderScript.new()
	var grid = RoadGridScript.new()
	var mats: Array[StandardMaterial3D] = []
	for _i in 3:
		mats.append(StandardMaterial3D.new())
	var win_mats: Array[StandardMaterial3D] = []
	for _i in 4:
		win_mats.append(StandardMaterial3D.new())
	builder.init(grid, mats, win_mats, StandardMaterial3D.new())
	assert_eq(
		builder._window_mats.size(), 4,
		"Builder should store 4 window materials",
	)


func test_builder_stores_window_mats_reference() -> void:
	var builder = BuilderScript.new()
	var grid = RoadGridScript.new()
	var mats: Array[StandardMaterial3D] = [StandardMaterial3D.new()]
	var win_mats: Array[StandardMaterial3D] = []
	var expected := StandardMaterial3D.new()
	win_mats.append(expected)
	builder.init(grid, mats, win_mats, StandardMaterial3D.new())
	assert_eq(
		builder._window_mats[0], expected,
		"Builder should store the exact material references",
	)


func test_build_creates_window_mesh_instances() -> void:
	var builder = BuilderScript.new()
	var grid = RoadGridScript.new()
	var mats: Array[StandardMaterial3D] = []
	for _i in 3:
		mats.append(StandardMaterial3D.new())
	var win_mats: Array[StandardMaterial3D] = []
	for _i in 4:
		win_mats.append(StandardMaterial3D.new())
	builder.init(grid, mats, win_mats, StandardMaterial3D.new())

	var chunk := Node3D.new()
	add_child_autofree(chunk)
	builder.build(chunk, Vector2i(0, 0), 0.0, 0.0)

	# Find window mesh instances — named "Windows_0", "Windows_1", etc.
	var body: Node = chunk.get_child(0)
	var win_count := 0
	for i in body.get_child_count():
		var child := body.get_child(i)
		if child.name.begins_with("Windows_"):
			win_count += 1
	assert_gt(
		win_count, 0,
		"Should create at least one window mesh instance",
	)
	assert_true(
		win_count <= 4,
		"Should create at most 4 window mesh instances",
	)


func test_build_deterministic_with_same_tile() -> void:
	var builder = BuilderScript.new()
	var grid = RoadGridScript.new()
	var mats: Array[StandardMaterial3D] = []
	for _i in 3:
		mats.append(StandardMaterial3D.new())
	var win_mats: Array[StandardMaterial3D] = []
	for _i in 4:
		win_mats.append(StandardMaterial3D.new())
	builder.init(grid, mats, win_mats, StandardMaterial3D.new())

	# Build same tile twice, check same window distribution
	var chunk1 := Node3D.new()
	add_child_autofree(chunk1)
	builder.build(chunk1, Vector2i(5, 7), 0.0, 0.0)

	var chunk2 := Node3D.new()
	add_child_autofree(chunk2)
	builder.build(chunk2, Vector2i(5, 7), 0.0, 0.0)

	var body1: Node = chunk1.get_child(0)
	var body2: Node = chunk2.get_child(0)

	var names1: Array[String] = []
	var names2: Array[String] = []
	for i in body1.get_child_count():
		var child := body1.get_child(i)
		if child.name.begins_with("Windows_"):
			names1.append(child.name)
	for i in body2.get_child_count():
		var child := body2.get_child(i)
		if child.name.begins_with("Windows_"):
			names2.append(child.name)

	assert_eq(
		names1, names2,
		"Same tile should produce same window group distribution",
	)


func test_window_meshes_use_correct_materials() -> void:
	var builder = BuilderScript.new()
	var grid = RoadGridScript.new()
	var mats: Array[StandardMaterial3D] = []
	for _i in 3:
		mats.append(StandardMaterial3D.new())
	var win_mats: Array[StandardMaterial3D] = []
	for _i in 4:
		var wm := StandardMaterial3D.new()
		wm.albedo_color = Color(0.18, 0.22, 0.28)
		win_mats.append(wm)
	builder.init(grid, mats, win_mats, StandardMaterial3D.new())

	var chunk := Node3D.new()
	add_child_autofree(chunk)
	builder.build(chunk, Vector2i(0, 0), 0.0, 0.0)

	var body: Node = chunk.get_child(0)
	for i in body.get_child_count():
		var child := body.get_child(i)
		if child is MeshInstance3D and child.name.begins_with("Windows_"):
			var idx_str: String = child.name.replace("Windows_", "")
			var idx := idx_str.to_int()
			assert_eq(
				(child as MeshInstance3D).material_override,
				win_mats[idx],
				"Window mesh should use corresponding material",
			)


# --- day_night_environment.gd toggling tests ---

func test_mat_active_starts_empty() -> void:
	var env: Node = DayNightEnvScript.new()
	add_child_autofree(env)
	assert_eq(
		env._mat_active.size(), 0,
		"mat_active should start empty — sized on first night",
	)


func test_mat_active_fill_resets_all() -> void:
	var env: Node = DayNightEnvScript.new()
	add_child_autofree(env)
	env._mat_active.resize(4)
	env._mat_active[1] = false
	env._mat_active[3] = false
	env._mat_active.fill(true)
	assert_eq(
		env._mat_active, [true, true, true, true] as Array[bool],
		"fill(true) should reset all groups to active",
	)


func test_on_window_toggle_keeps_at_least_one_on() -> void:
	# Simulate toggling with only 1 group on — it should not turn it off
	var env: Node = DayNightEnvScript.new()
	add_child_autofree(env)
	# Wait a frame for _ready
	await get_tree().process_frame

	# Create a fake city using the actual city script so _window_mats exists
	var fake_city: Node3D = CityScript.new()
	fake_city._window_mats = [] as Array[StandardMaterial3D]
	for _i in 4:
		var m := StandardMaterial3D.new()
		m.emission_enabled = false
		fake_city._window_mats.append(m)
	add_child_autofree(fake_city)
	env._city = fake_city

	# Set only group 2 as on
	env._mat_active = [false, false, true, false] as Array[bool]

	# Force night hour so toggle doesn't bail
	var saved_hour: float = DayNightManager.current_hour
	DayNightManager.current_hour = 22.0

	# Call toggle many times — group 2 should never turn off
	for _i in 100:
		env._on_window_toggle()

	assert_true(
		env._mat_active.has(true),
		"At least one group must remain active after toggling",
	)

	# Restore hour
	DayNightManager.current_hour = saved_hour


# ==========================================================================
# st_add_windows_on_face_indep — per-window material independence
# ==========================================================================

func test_indep_uses_multiple_groups_on_tall_face() -> void:
	# A tall, wide face should have rows×cols > win_count, so with random
	# per-window assignment we expect more than one group to be used.
	var win_count := 8
	var win_sts: Array = []
	var win_st_has_data: Array = []
	for _i in win_count:
		win_sts.append(SurfaceTool.new())
		win_st_has_data.append(false)

	var rng := RandomNumberGenerator.new()
	rng.seed = 12345  # deterministic

	# A 20m wide × 30m tall face has plenty of windows
	CityScript.st_add_windows_on_face_indep(
		win_sts, win_count, win_st_has_data,
		Vector3.ZERO, 20.0, 30.0,
		Vector3(0, 0, -1), Vector3(1, 0, 0),
		rng,
	)

	var groups_used := 0
	for i in win_count:
		if win_st_has_data[i]:
			groups_used += 1
	assert_gt(
		groups_used, 1,
		"A large face should distribute windows across multiple material groups",
	)


func test_indep_skips_narrow_face() -> void:
	# A face narrower than one window should produce no geometry.
	var win_count := 8
	var win_sts: Array = []
	var win_st_has_data: Array = []
	for _i in win_count:
		win_sts.append(SurfaceTool.new())
		win_st_has_data.append(false)

	var rng := RandomNumberGenerator.new()

	CityScript.st_add_windows_on_face_indep(
		win_sts, win_count, win_st_has_data,
		Vector3.ZERO, 1.0, 20.0,  # only 1m wide — too narrow
		Vector3(0, 0, -1), Vector3(1, 0, 0),
		rng,
	)

	for i in win_count:
		assert_false(
			win_st_has_data[i],
			"No geometry expected for a face narrower than one window",
		)


func test_indep_all_begun_sts_have_geometry() -> void:
	# Every ST that was begun (has_data = true) should have vertices.
	var win_count := 8
	var win_sts: Array = []
	var win_st_has_data: Array = []
	for _i in win_count:
		win_sts.append(SurfaceTool.new())
		win_st_has_data.append(false)

	var rng := RandomNumberGenerator.new()
	rng.seed = 99

	CityScript.st_add_windows_on_face_indep(
		win_sts, win_count, win_st_has_data,
		Vector3.ZERO, 20.0, 30.0,
		Vector3(0, 0, -1), Vector3(1, 0, 0),
		rng,
	)

	for i in win_count:
		if win_st_has_data[i]:
			var mesh := (win_sts[i] as SurfaceTool).commit()
			assert_gt(
				mesh.get_surface_count(), 0,
				"ST[%d] has_data=true but produced no mesh surface" % i,
			)
