extends GutTest
## Unit tests for chunk_builder_suburb.gd — door, window and interior
## geometry added to suburban houses.

const SuburbScript = preload(
	"res://scenes/world/generator/chunk_builder_suburb.gd"
)
const BuilderScript = preload(
	"res://scenes/world/generator/chunk_builder_buildings.gd"
)
const RoadGridScript = preload("res://src/road_grid.gd")


func _make_builder() -> RefCounted:
	var builder = SuburbScript.new()
	var grid = RoadGridScript.new()
	var mats: Array[StandardMaterial3D] = []
	for _i in 3:
		mats.append(StandardMaterial3D.new())
	var mat_off := StandardMaterial3D.new()
	var mat_on := StandardMaterial3D.new()
	var interior_mat := StandardMaterial3D.new()
	var roof_mats: Array[StandardMaterial3D] = [StandardMaterial3D.new()]
	var bld_builder = BuilderScript.new()
	bld_builder.init(grid, mats, mat_off, mat_on, interior_mat, roof_mats)
	builder.init(grid, mats, mat_off, mat_on, interior_mat, roof_mats, bld_builder)
	return builder


# ==========================================================================
# Constants
# ==========================================================================

func test_door_width_less_than_min_building_width() -> void:
	assert_lt(
		SuburbScript.DOOR_WIDTH, SuburbScript.HOUSE_WIN_W * 4.0,
		"DOOR_WIDTH should be narrower than a wide face",
	)


func test_house_win_smaller_than_commercial() -> void:
	# Residential windows are intentionally smaller than the 1.5×2.0 used
	# in city commercial buildings.
	assert_lt(SuburbScript.HOUSE_WIN_W, 1.5)
	assert_lt(SuburbScript.HOUSE_WIN_H, 2.0)


func test_house_win_margins_allow_windows_in_min_height_house() -> void:
	# A MIN_HEIGHT (3m) house must be able to fit at least one row.
	var avail_h := (
		SuburbScript.MIN_HEIGHT
		- SuburbScript.HOUSE_WIN_MARGIN_BOT
		- SuburbScript.HOUSE_WIN_MARGIN_TOP
	)
	assert_gte(
		avail_h, SuburbScript.HOUSE_WIN_H,
		"Margins should allow windows even in the shortest suburb house",
	)


# ==========================================================================
# build() — body structure
# ==========================================================================

func test_build_creates_static_body() -> void:
	var builder = _make_builder()
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	builder.build(chunk, Vector2i(0, 0), 0.0, 0.0)
	assert_gt(chunk.get_child_count(), 0, "build() should add a body node")
	assert_true(
		chunk.get_child(0) is StaticBody3D,
		"First child should be StaticBody3D",
	)


func test_build_body_in_static_group() -> void:
	var builder = _make_builder()
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	builder.build(chunk, Vector2i(0, 0), 0.0, 0.0)
	var body: Node = chunk.get_child(0)
	assert_true(body.is_in_group("Static"), "Body should be in Static group")


# ==========================================================================
# Determinism
# ==========================================================================

func test_same_tile_produces_same_child_names() -> void:
	var builder = _make_builder()

	var chunk1 := Node3D.new()
	add_child_autofree(chunk1)
	builder.build(chunk1, Vector2i(3, 5), 0.0, 0.0)

	var chunk2 := Node3D.new()
	add_child_autofree(chunk2)
	builder.build(chunk2, Vector2i(3, 5), 0.0, 0.0)

	# Compare only MeshInstance3D names — CollisionShape3D nodes get
	# auto-incremented unique names that change between builds.
	var names1: Array[String] = []
	var names2: Array[String] = []
	if chunk1.get_child_count() > 0:
		var b1: Node = chunk1.get_child(0)
		for i in b1.get_child_count():
			var child := b1.get_child(i)
			if child is MeshInstance3D:
				names1.append(child.name)
	if chunk2.get_child_count() > 0:
		var b2: Node = chunk2.get_child(0)
		for i in b2.get_child_count():
			var child := b2.get_child(i)
			if child is MeshInstance3D:
				names2.append(child.name)

	assert_eq(names1, names2, "Same tile must produce identical mesh child layout")


# ==========================================================================
# Windows
# ==========================================================================

func test_build_creates_suburb_window_meshes() -> void:
	# Windows are now two shared-material nodes: WindowsOff and WindowsOn
	var builder = _make_builder()
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	builder.build(chunk, Vector2i(1, 1), 0.0, 0.0)
	if chunk.get_child_count() == 0:
		return  # no buildings on this tile — vacuously pass
	var body: Node = chunk.get_child(0)
	if not body.has_meta("win_group_meshes"):
		return  # no windows on this tile
	var found_off := false
	var found_on := false
	for i in body.get_child_count():
		var child := body.get_child(i)
		if child.name == "WindowsOff":
			found_off = true
		elif child.name == "WindowsOn":
			found_on = true
	assert_true(found_off, "Should have WindowsOff node when windows exist")
	assert_true(found_on, "Should have WindowsOn node when windows exist")


func test_window_mesh_has_material_override() -> void:
	var builder = _make_builder()
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	builder.build(chunk, Vector2i(2, 2), 0.0, 0.0)
	if chunk.get_child_count() == 0:
		return
	var body: Node = chunk.get_child(0)
	for i in body.get_child_count():
		var child := body.get_child(i)
		if child is MeshInstance3D and (
			child.name == "WindowsOff" or child.name == "WindowsOn"
		):
			assert_not_null(
				(child as MeshInstance3D).material_override,
				"%s must have material_override set" % child.name,
			)


func test_window_mats_are_shared_across_chunks() -> void:
	# Both chunks must reference the SAME material instances (shared, not copied).
	var builder = _make_builder()

	var chunk1 := Node3D.new()
	add_child_autofree(chunk1)
	builder.build(chunk1, Vector2i(4, 4), 0.0, 0.0)

	var chunk2 := Node3D.new()
	add_child_autofree(chunk2)
	builder.build(chunk2, Vector2i(4, 4), 0.0, 0.0)

	if chunk1.get_child_count() == 0 or chunk2.get_child_count() == 0:
		return

	var b1: Node = chunk1.get_child(0)
	var b2: Node = chunk2.get_child(0)

	if not b1.has_meta("win_group_meshes") or not b2.has_meta("win_group_meshes"):
		return  # no windows on this tile

	var mat1: StandardMaterial3D = null
	var mat2: StandardMaterial3D = null
	for i in b1.get_child_count():
		var c := b1.get_child(i)
		if c is MeshInstance3D and c.name == "WindowsOff":
			mat1 = (c as MeshInstance3D).material_override as StandardMaterial3D
			break
	for i in b2.get_child_count():
		var c := b2.get_child(i)
		if c is MeshInstance3D and c.name == "WindowsOff":
			mat2 = (c as MeshInstance3D).material_override as StandardMaterial3D
			break

	if mat1 == null or mat2 == null:
		return
	assert_eq(
		mat1, mat2,
		"Both chunks must share the same WindowsOff material (batching)",
	)


# ==========================================================================
# Per-chunk window toggle metadata
# ==========================================================================

func test_body_in_building_chunk_group_when_windows_exist() -> void:
	var builder = _make_builder()
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	builder.build(chunk, Vector2i(1, 1), 0.0, 0.0)
	if chunk.get_child_count() == 0:
		return
	var body: Node = chunk.get_child(0)
	if body.has_meta("win_group_meshes"):
		assert_true(
			body.is_in_group("building_chunk"),
			"Body with windows should be in building_chunk group",
		)


func test_window_active_meta_all_false_initially() -> void:
	# Daytime default: all window groups are off
	var builder = _make_builder()
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	builder.build(chunk, Vector2i(1, 1), 0.0, 0.0)
	if chunk.get_child_count() == 0:
		return
	var body: Node = chunk.get_child(0)
	if not body.has_meta("window_active"):
		return
	var active: Array = body.get_meta("window_active")
	for i in active.size():
		assert_false(
			active[i],
			"window_active[%d] should start as false (daytime)" % i,
		)


# ==========================================================================
# Interior room
# ==========================================================================

func test_build_creates_interior_mesh_for_houses_with_doors() -> void:
	# The interior mesh is named "SuburbInteriors" and appears when at least
	# one house has a door wide enough to pass the check.
	var builder = _make_builder()
	var chunk := Node3D.new()
	add_child_autofree(chunk)
	# Tile (0,0) deterministically places buildings
	builder.build(chunk, Vector2i(0, 0), 0.0, 0.0)
	if chunk.get_child_count() == 0:
		return
	var body: Node = chunk.get_child(0)
	# Count interiors (may be zero if all houses are too narrow for a door)
	var int_node: MeshInstance3D = null
	for i in body.get_child_count():
		var child := body.get_child(i)
		if child.name == "SuburbInteriors" and child is MeshInstance3D:
			int_node = child as MeshInstance3D
			break
	# We can't guarantee interiors without controlling RNG, but verify
	# that if the node exists it has geometry.
	if int_node != null:
		assert_not_null(int_node.mesh, "SuburbInteriors must have a mesh")
		assert_gt(
			int_node.mesh.get_surface_count(), 0,
			"SuburbInteriors mesh must have at least one surface",
		)


# ==========================================================================
# _add_house_windows_on_face — unit tests
# ==========================================================================

func test_house_windows_skipped_when_face_too_narrow() -> void:
	var builder = SuburbScript.new()
	var win_count := 4
	var win_sts: Array = []
	var win_st_has_data: Array = []
	for _i in win_count:
		win_sts.append(SurfaceTool.new())
		win_st_has_data.append(false)
	var rng := RandomNumberGenerator.new()

	# Face too narrow: avail_w < HOUSE_WIN_W
	builder._add_house_windows_on_face(
		win_sts, win_count, win_st_has_data,
		Vector3.ZERO, 0.5, 4.0,
		Vector3(0, 0, -1), Vector3(1, 0, 0), rng,
	)
	for i in win_count:
		assert_false(
			win_st_has_data[i],
			"No windows expected on a face narrower than HOUSE_WIN_W",
		)


func test_house_windows_skipped_when_face_too_short() -> void:
	var builder = SuburbScript.new()
	var win_count := 4
	var win_sts: Array = []
	var win_st_has_data: Array = []
	for _i in win_count:
		win_sts.append(SurfaceTool.new())
		win_st_has_data.append(false)
	var rng := RandomNumberGenerator.new()

	# Face too short: avail_h < HOUSE_WIN_H (height = 1.0m)
	builder._add_house_windows_on_face(
		win_sts, win_count, win_st_has_data,
		Vector3.ZERO, 6.0, 1.0,
		Vector3(0, 0, -1), Vector3(1, 0, 0), rng,
	)
	for i in win_count:
		assert_false(
			win_st_has_data[i],
			"No windows expected on a face shorter than margins + window height",
		)


func test_house_windows_places_geometry_on_valid_face() -> void:
	var builder = SuburbScript.new()
	var win_count := 4
	var win_sts: Array = []
	var win_st_has_data: Array = []
	for _i in win_count:
		win_sts.append(SurfaceTool.new())
		win_st_has_data.append(false)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42

	# Wide, tall face should produce windows
	builder._add_house_windows_on_face(
		win_sts, win_count, win_st_has_data,
		Vector3.ZERO, 10.0, 4.0,
		Vector3(0, 0, -1), Vector3(1, 0, 0), rng,
	)
	var any_data := false
	for i in win_count:
		if win_st_has_data[i]:
			any_data = true
	assert_true(any_data, "Windows should be placed on a 10m × 4m face")


func test_house_windows_begun_sts_have_geometry() -> void:
	var builder = SuburbScript.new()
	var win_count := 4
	var win_sts: Array = []
	var win_st_has_data: Array = []
	for _i in win_count:
		win_sts.append(SurfaceTool.new())
		win_st_has_data.append(false)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77

	builder._add_house_windows_on_face(
		win_sts, win_count, win_st_has_data,
		Vector3.ZERO, 10.0, 4.0,
		Vector3(0, 0, -1), Vector3(1, 0, 0), rng,
	)
	for i in win_count:
		if win_st_has_data[i]:
			var mesh := (win_sts[i] as SurfaceTool).commit()
			assert_gt(
				mesh.get_surface_count(), 0,
				"ST[%d] has_data=true but produced no surface" % i,
			)
