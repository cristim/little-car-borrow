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

func test_city_has_window_mat_off_var() -> void:
	# Verify city.gd declares _window_mat_off (populated after _ready)
	var script: GDScript = CityScript as GDScript
	var src: String = script.source_code
	assert_true(
		src.contains("_window_mat_off"),
		"city.gd should declare _window_mat_off",
	)


func test_city_has_window_mat_on_var() -> void:
	var script: GDScript = CityScript as GDScript
	var src: String = script.source_code
	assert_true(
		src.contains("_window_mat_on"),
		"city.gd should declare _window_mat_on",
	)


# --- chunk_builder_buildings.gd tests ---

func test_builder_init_stores_window_mat_off() -> void:
	var builder = BuilderScript.new()
	var grid = RoadGridScript.new()
	var mats: Array[StandardMaterial3D] = []
	for _i in 3:
		mats.append(StandardMaterial3D.new())
	var mat_off := StandardMaterial3D.new()
	var mat_on := StandardMaterial3D.new()
	builder.init(grid, mats, mat_off, mat_on, StandardMaterial3D.new())
	assert_eq(builder._window_mat_off, mat_off, "Builder should store window_mat_off")


func test_builder_init_stores_window_mat_on() -> void:
	var builder = BuilderScript.new()
	var grid = RoadGridScript.new()
	var mats: Array[StandardMaterial3D] = [StandardMaterial3D.new()]
	var mat_off := StandardMaterial3D.new()
	var mat_on := StandardMaterial3D.new()
	builder.init(grid, mats, mat_off, mat_on, StandardMaterial3D.new())
	assert_eq(builder._window_mat_on, mat_on, "Builder should store window_mat_on")


func test_build_creates_window_mesh_instances() -> void:
	var builder = BuilderScript.new()
	var grid = RoadGridScript.new()
	var mats: Array[StandardMaterial3D] = []
	for _i in 3:
		mats.append(StandardMaterial3D.new())
	builder.init(
		grid, mats, StandardMaterial3D.new(), StandardMaterial3D.new(),
		StandardMaterial3D.new(),
	)

	var chunk := Node3D.new()
	add_child_autofree(chunk)
	builder.build(chunk, Vector2i(0, 0), 0.0, 0.0)

	# Two shared-material window nodes: WindowsOff and WindowsOn
	var body: Node = chunk.get_child(0)
	var found_off := false
	var found_on := false
	for i in body.get_child_count():
		var child := body.get_child(i)
		if child.name == "WindowsOff":
			found_off = true
		elif child.name == "WindowsOn":
			found_on = true
	assert_true(found_off, "Should create WindowsOff mesh node")
	assert_true(found_on, "Should create WindowsOn mesh node")


func test_build_deterministic_with_same_tile() -> void:
	var builder = BuilderScript.new()
	var grid = RoadGridScript.new()
	var mats: Array[StandardMaterial3D] = []
	for _i in 3:
		mats.append(StandardMaterial3D.new())
	builder.init(
		grid, mats, StandardMaterial3D.new(), StandardMaterial3D.new(),
		StandardMaterial3D.new(),
	)

	# Build same tile twice — group meshes metadata should have same size
	var chunk1 := Node3D.new()
	add_child_autofree(chunk1)
	builder.build(chunk1, Vector2i(5, 7), 0.0, 0.0)

	var chunk2 := Node3D.new()
	add_child_autofree(chunk2)
	builder.build(chunk2, Vector2i(5, 7), 0.0, 0.0)

	var body1: Node = chunk1.get_child(0)
	var body2: Node = chunk2.get_child(0)

	if not body1.has_meta("win_group_meshes"):
		return  # no windows on this tile
	var gm1: Array = body1.get_meta("win_group_meshes")
	var gm2: Array = body2.get_meta("win_group_meshes")
	assert_eq(gm1.size(), gm2.size(), "Same tile should produce same number of window groups")


func test_window_meshes_use_correct_materials() -> void:
	# WindowsOff uses mat_off, WindowsOn uses mat_on (shared global materials)
	var builder = BuilderScript.new()
	var grid = RoadGridScript.new()
	var mats: Array[StandardMaterial3D] = []
	for _i in 3:
		mats.append(StandardMaterial3D.new())
	var mat_off := StandardMaterial3D.new()
	mat_off.albedo_color = Color(0.18, 0.22, 0.28)
	var mat_on := StandardMaterial3D.new()
	mat_on.albedo_color = Color(0.9, 0.8, 0.5)
	builder.init(grid, mats, mat_off, mat_on, StandardMaterial3D.new())

	var chunk := Node3D.new()
	add_child_autofree(chunk)
	builder.build(chunk, Vector2i(0, 0), 0.0, 0.0)

	var body: Node = chunk.get_child(0)
	for i in body.get_child_count():
		var child := body.get_child(i)
		if child is MeshInstance3D:
			if child.name == "WindowsOff":
				assert_eq(
					(child as MeshInstance3D).material_override, mat_off,
					"WindowsOff should reference mat_off",
				)
			elif child.name == "WindowsOn":
				assert_eq(
					(child as MeshInstance3D).material_override, mat_on,
					"WindowsOn should reference mat_on",
				)


# --- day_night_environment.gd per-chunk toggling tests ---

func test_builder_stores_win_group_meshes_meta() -> void:
	var builder = BuilderScript.new()
	var grid = RoadGridScript.new()
	var mats: Array[StandardMaterial3D] = []
	for _i in 3:
		mats.append(StandardMaterial3D.new())
	builder.init(
		grid, mats, StandardMaterial3D.new(), StandardMaterial3D.new(),
		StandardMaterial3D.new(),
	)

	var chunk := Node3D.new()
	add_child_autofree(chunk)
	builder.build(chunk, Vector2i(0, 0), 0.0, 0.0)

	var body: Node = chunk.get_child(0)
	assert_true(
		body.has_meta("win_group_meshes"),
		"Builder should store win_group_meshes metadata on the body node",
	)


func test_builder_window_active_all_false_initially() -> void:
	# Daytime default: all window groups are off (no emission)
	var builder = BuilderScript.new()
	var grid = RoadGridScript.new()
	var mats: Array[StandardMaterial3D] = []
	for _i in 3:
		mats.append(StandardMaterial3D.new())
	builder.init(
		grid, mats, StandardMaterial3D.new(), StandardMaterial3D.new(),
		StandardMaterial3D.new(),
	)

	var chunk := Node3D.new()
	add_child_autofree(chunk)
	builder.build(chunk, Vector2i(0, 0), 0.0, 0.0)

	var body: Node = chunk.get_child(0)
	if not body.has_meta("window_active"):
		return  # no windows on this tile — skip
	var active: Array = body.get_meta("window_active")
	for i in active.size():
		assert_false(
			active[i],
			"window_active[%d] should start as false (daytime)" % i,
		)


func test_builder_adds_body_to_building_chunk_group() -> void:
	var builder = BuilderScript.new()
	var grid = RoadGridScript.new()
	var mats: Array[StandardMaterial3D] = []
	for _i in 3:
		mats.append(StandardMaterial3D.new())
	builder.init(
		grid, mats, StandardMaterial3D.new(), StandardMaterial3D.new(),
		StandardMaterial3D.new(),
	)

	var chunk := Node3D.new()
	add_child_autofree(chunk)
	builder.build(chunk, Vector2i(0, 0), 0.0, 0.0)

	var body: Node = chunk.get_child(0)
	# Only assert group membership when windows were actually created
	if body.has_meta("win_group_meshes"):
		assert_true(
			body.is_in_group("building_chunk"),
			"Body with windows should be in building_chunk group",
		)


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
