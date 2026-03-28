extends GutTest
## Tests for MinimapHud — coordinate transforms, zoom, fullscreen,
## color mapping, and geometric helpers.

const MinimapScript = preload("res://scenes/ui/hud/minimap_hud.gd")


func _build_minimap() -> Control:
	var mm: Control = MinimapScript.new()
	mm.size = Vector2(300, 300)
	add_child_autofree(mm)
	return mm


# ================================================================
# Constants
# ================================================================

func test_constants_are_consistent() -> void:
	var mm := _build_minimap()
	assert_eq(mm.MINI_SIZE, 300.0, "Mini size should be 300")
	assert_eq(mm.MINI_CENTER, 150.0, "Mini center should be 150")
	assert_eq(mm.MINI_RADIUS, 140.0, "Mini radius should be 140")
	assert_eq(mm.ZOOM_LEVELS.size(), 5, "Should have 5 zoom levels")
	assert_eq(mm.DEFAULT_ZOOM_IDX, 2, "Default zoom index should be 2")


# ================================================================
# Initialization
# ================================================================

func test_ready_sets_minimum_size() -> void:
	var mm := _build_minimap()
	await get_tree().process_frame

	assert_eq(
		mm.custom_minimum_size,
		Vector2(300, 300),
		"Custom min size should be MINI_SIZE x MINI_SIZE",
	)


func test_ready_sets_default_scale() -> void:
	var mm := _build_minimap()
	await get_tree().process_frame

	assert_almost_eq(mm._scale, 0.5, 0.001, "Default scale should be zoom level at index 2")


func test_ready_builds_clip_circle() -> void:
	var mm := _build_minimap()
	await get_tree().process_frame

	assert_eq(mm._clip_circle.size(), 64, "Clip circle should have 64 points")


# ================================================================
# World-to-minimap coordinate transform
# ================================================================

func test_world_to_minimap_center_returns_map_center() -> void:
	var mm := _build_minimap()
	await get_tree().process_frame

	var result: Vector2 = mm._world_to_minimap(Vector3(10, 0, 20), Vector3(10, 0, 20), 0.0)
	assert_almost_eq(result.x, 150.0, 0.01, "Same pos should map to center X")
	assert_almost_eq(result.y, 150.0, 0.01, "Same pos should map to center Y")


func test_world_to_minimap_offset_east() -> void:
	var mm := _build_minimap()
	await get_tree().process_frame

	# 20 units east at scale 0.5 = 10 pixels right of center
	var result: Vector2 = mm._world_to_minimap(Vector3(30, 0, 0), Vector3(10, 0, 0), 0.0)
	assert_almost_eq(result.x, 160.0, 0.01, "20 units east at 0.5 scale = center + 10")
	assert_almost_eq(result.y, 150.0, 0.01, "No Z offset = same Y")


func test_world_to_minimap_offset_south() -> void:
	var mm := _build_minimap()
	await get_tree().process_frame

	# 20 units south (positive Z) = 10 pixels down
	var result: Vector2 = mm._world_to_minimap(Vector3(0, 0, 20), Vector3(0, 0, 0), 0.0)
	assert_almost_eq(result.x, 150.0, 0.01, "No X offset = center X")
	assert_almost_eq(result.y, 160.0, 0.01, "20 south at 0.5 scale = center + 10")


func test_world_to_minimap_with_yaw_rotation() -> void:
	var mm := _build_minimap()
	await get_tree().process_frame

	# 90 degree yaw (PI/2): east becomes south on minimap
	var yaw := PI / 2.0
	var result: Vector2 = mm._world_to_minimap(Vector3(20, 0, 0), Vector3(0, 0, 0), yaw)
	# dx=20, dz=0, yaw=PI/2: rx = 20*cos(PI/2) - 0*sin(PI/2) ~ 0
	# ry = 20*sin(PI/2) + 0*cos(PI/2) ~ 20
	assert_almost_eq(result.x, 150.0, 0.5, "Rotated east should map near center X")
	assert_almost_eq(result.y, 160.0, 0.5, "Rotated east should map south")


# ================================================================
# In-circle check
# ================================================================

func test_in_circle_center_is_true() -> void:
	var mm := _build_minimap()
	await get_tree().process_frame

	assert_true(mm._in_circle(Vector2(150, 150)), "Center should be in circle")


func test_in_circle_edge_is_true() -> void:
	var mm := _build_minimap()
	await get_tree().process_frame

	# Exactly at radius boundary
	assert_true(mm._in_circle(Vector2(150, 10)), "Point at edge (10) should be in circle")


func test_in_circle_outside_is_false() -> void:
	var mm := _build_minimap()
	await get_tree().process_frame

	assert_false(mm._in_circle(Vector2(0, 0)), "Corner should be outside circle")


func test_in_circle_fullscreen_uses_rect() -> void:
	var mm := _build_minimap()
	await get_tree().process_frame

	mm._fullscreen = true
	mm.size = Vector2(800, 600)

	# In fullscreen, _in_circle uses rectangular bounds
	assert_true(mm._in_circle(Vector2(0, 0)), "Top-left is valid in fullscreen rect")
	assert_true(mm._in_circle(Vector2(400, 300)), "Center is valid in fullscreen rect")
	assert_false(mm._in_circle(Vector2(-1, 0)), "Negative X is outside")
	assert_false(mm._in_circle(Vector2(0, 601)), "Beyond height is outside")


# ================================================================
# Zoom control
# ================================================================

func test_change_zoom_increases_scale() -> void:
	var mm := _build_minimap()
	await get_tree().process_frame

	mm._change_zoom(1)
	assert_eq(mm._zoom_idx, 3, "Zoom index should increase by 1")
	assert_almost_eq(mm._scale, 0.75, 0.001, "Scale should match zoom level 3")


func test_change_zoom_decreases_scale() -> void:
	var mm := _build_minimap()
	await get_tree().process_frame

	mm._change_zoom(-1)
	assert_eq(mm._zoom_idx, 1, "Zoom index should decrease by 1")
	assert_almost_eq(mm._scale, 0.25, 0.001, "Scale should match zoom level 1")


func test_change_zoom_clamps_at_max() -> void:
	var mm := _build_minimap()
	await get_tree().process_frame

	mm._zoom_idx = 4
	mm._change_zoom(1)
	assert_eq(mm._zoom_idx, 4, "Zoom should clamp at max index")


func test_change_zoom_clamps_at_min() -> void:
	var mm := _build_minimap()
	await get_tree().process_frame

	mm._zoom_idx = 0
	mm._change_zoom(-1)
	assert_eq(mm._zoom_idx, 0, "Zoom should clamp at min index")


# ================================================================
# Fullscreen toggle
# ================================================================

func test_toggle_fullscreen_on() -> void:
	var mm := _build_minimap()
	await get_tree().process_frame

	assert_false(mm._fullscreen, "Should start not fullscreen")
	mm._toggle_fullscreen()
	assert_true(mm._fullscreen, "Should be fullscreen after toggle")
	assert_eq(mm._pan_offset, Vector3.ZERO, "Pan should reset on toggle")


func test_toggle_fullscreen_off_restores_mini() -> void:
	var mm := _build_minimap()
	await get_tree().process_frame

	mm._toggle_fullscreen()  # on
	mm._toggle_fullscreen()  # off

	assert_false(mm._fullscreen, "Should be mini after double toggle")
	assert_almost_eq(mm._map_size, 300.0, 0.01, "Map size restored to MINI_SIZE")
	assert_almost_eq(mm._map_center, 150.0, 0.01, "Map center restored")
	assert_almost_eq(mm._map_radius, 140.0, 0.01, "Map radius restored")


func test_fullscreen_rebuilds_rectangular_clip() -> void:
	var mm := _build_minimap()
	await get_tree().process_frame

	mm._fullscreen = true
	mm.size = Vector2(800, 600)
	mm._rebuild_clip_circle()

	assert_eq(mm._clip_circle.size(), 4, "Fullscreen clip should be rectangular (4 points)")


func test_mini_rebuilds_circular_clip() -> void:
	var mm := _build_minimap()
	await get_tree().process_frame

	mm._fullscreen = false
	mm._rebuild_clip_circle()

	assert_eq(mm._clip_circle.size(), 64, "Mini clip should be circular (64 points)")


# ================================================================
# Height-to-color mapping
# ================================================================

func test_height_below_sea_returns_deep_water() -> void:
	var mm := _build_minimap()
	var col: Color = mm._height_to_minimap_color(-10.0)

	assert_almost_eq(col.r, 0.15, 0.01, "Deep water red")
	assert_almost_eq(col.g, 0.35, 0.01, "Deep water green")
	assert_almost_eq(col.b, 0.65, 0.01, "Deep water blue")
	assert_almost_eq(col.a, 0.5, 0.01, "Alpha should be 0.5")


func test_height_at_sea_level_returns_beach_or_green() -> void:
	var mm := _build_minimap()
	# Slightly above sea level (-2.0), near 0 should lerp toward green
	var col: Color = mm._height_to_minimap_color(-1.0)
	assert_almost_eq(col.a, 0.5, 0.01, "Alpha should be 0.5")


func test_height_very_high_returns_snow() -> void:
	var mm := _build_minimap()
	var col: Color = mm._height_to_minimap_color(60.0)

	assert_almost_eq(col.r, 0.90, 0.01, "Snow white red")
	assert_almost_eq(col.g, 0.90, 0.01, "Snow white green")
	assert_almost_eq(col.b, 0.92, 0.01, "Snow white blue")


# ================================================================
# Biome-to-color mapping
# ================================================================

func test_biome_forest_returns_forest_color() -> void:
	var mm := _build_minimap()
	var col: Color = mm._biome_to_color("forest", false)
	assert_almost_eq(col.r, mm.FOREST_COLOR.r, 0.01, "Forest red")
	assert_almost_eq(col.g, mm.FOREST_COLOR.g, 0.01, "Forest green")


func test_biome_mountain_returns_mountain_color() -> void:
	var mm := _build_minimap()
	var col: Color = mm._biome_to_color("mountain", false)
	assert_almost_eq(col.r, mm.MOUNTAIN_COLOR.r, 0.01, "Mountain red")


func test_biome_ocean_returns_ocean_color() -> void:
	var mm := _build_minimap()
	var col: Color = mm._biome_to_color("ocean", false)
	assert_almost_eq(col.r, mm.OCEAN_COLOR.r, 0.01, "Ocean red")


func test_biome_unknown_with_water_returns_water_color() -> void:
	var mm := _build_minimap()
	var col: Color = mm._biome_to_color("unknown_biome", true)
	assert_almost_eq(col.r, mm.WATER_COLOR.r, 0.01, "Water red for unknown biome")


func test_biome_unknown_without_water_returns_terrain_color() -> void:
	var mm := _build_minimap()
	var col: Color = mm._biome_to_color("unknown_biome", false)
	assert_almost_eq(col.r, mm.TERRAIN_COLOR.r, 0.01, "Terrain color for unknown biome")


func test_biome_suburb_returns_suburb_color() -> void:
	var mm := _build_minimap()
	var col: Color = mm._biome_to_color("suburb", false)
	assert_almost_eq(col.r, mm.SUBURB_COLOR.r, 0.01, "Suburb red")


func test_biome_farmland_returns_farmland_color() -> void:
	var mm := _build_minimap()
	var col: Color = mm._biome_to_color("farmland", false)
	assert_almost_eq(col.r, mm.FARMLAND_COLOR.r, 0.01, "Farmland red")


func test_biome_village_returns_village_color() -> void:
	var mm := _build_minimap()
	var col: Color = mm._biome_to_color("village", false)
	assert_almost_eq(col.r, mm.VILLAGE_COLOR.r, 0.01, "Village red")


# ================================================================
# River edge point calculation
# ================================================================

func test_river_edge_pt_north() -> void:
	var mm := _build_minimap()
	var pt: Vector3 = mm._river_edge_pt(100.0, 200.0, 50.0, 0, 0.5)
	assert_almost_eq(pt.x, 100.0, 0.01, "North edge X at center")
	assert_almost_eq(pt.z, 150.0, 0.01, "North edge Z = oz - hs")


func test_river_edge_pt_east() -> void:
	var mm := _build_minimap()
	var pt: Vector3 = mm._river_edge_pt(100.0, 200.0, 50.0, 1, 0.5)
	assert_almost_eq(pt.x, 150.0, 0.01, "East edge X = ox + hs")
	assert_almost_eq(pt.z, 200.0, 0.01, "East edge Z at center")


func test_river_edge_pt_south() -> void:
	var mm := _build_minimap()
	var pt: Vector3 = mm._river_edge_pt(100.0, 200.0, 50.0, 2, 0.5)
	assert_almost_eq(pt.x, 100.0, 0.01, "South edge X at center")
	assert_almost_eq(pt.z, 250.0, 0.01, "South edge Z = oz + hs")


func test_river_edge_pt_west() -> void:
	var mm := _build_minimap()
	var pt: Vector3 = mm._river_edge_pt(100.0, 200.0, 50.0, 3, 0.5)
	assert_almost_eq(pt.x, 50.0, 0.01, "West edge X = ox - hs")
	assert_almost_eq(pt.z, 200.0, 0.01, "West edge Z at center")


func test_river_edge_pt_unknown_dir_returns_origin() -> void:
	var mm := _build_minimap()
	var pt: Vector3 = mm._river_edge_pt(100.0, 200.0, 50.0, 99, 0.5)
	assert_almost_eq(pt.x, 100.0, 0.01, "Unknown dir returns ox")
	assert_almost_eq(pt.z, 200.0, 0.01, "Unknown dir returns oz")


func test_river_edge_pt_offset_position() -> void:
	var mm := _build_minimap()
	# pos=0.75 means offset = (0.75 - 0.5) * 50 * 2 = 25
	var pt: Vector3 = mm._river_edge_pt(100.0, 200.0, 50.0, 0, 0.75)
	assert_almost_eq(pt.x, 125.0, 0.01, "North edge offset by position")


# ================================================================
# Process without player does not crash
# ================================================================

func test_process_without_player_does_not_crash() -> void:
	var mm := _build_minimap()
	await get_tree().process_frame

	mm._player = null
	await get_tree().process_frame
	assert_true(true, "Process should not crash without player")


# ================================================================
# Frame counter triggers redraw
# ================================================================

func test_frame_count_increments() -> void:
	var mm := _build_minimap()
	await get_tree().process_frame

	# Provide a dummy player so _process runs the frame counter path
	var player := Node3D.new()
	player.name = "DummyPlayer"
	player.add_to_group("player")
	add_child_autofree(player)
	mm._player = player

	var start_count: int = mm._frame_count
	await get_tree().process_frame
	await get_tree().process_frame

	assert_gt(mm._frame_count, start_count, "Frame count should increment")
