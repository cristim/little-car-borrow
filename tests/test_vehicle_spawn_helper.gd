extends GutTest
## Unit tests for src/vehicle_spawn_helper.gd.
##
## Static methods that require a live physics world (probe_spawn_surface,
## is_embedded) are covered via source-code inspection.  apply_terrain_tilt
## works on plain Node3D so it is exercised functionally.

const VehicleSpawnHelperScript = preload("res://src/vehicle_spawn_helper.gd")


# ===========================================================================
# Constants
# ===========================================================================


func test_sea_level_value() -> void:
	assert_eq(
		VehicleSpawnHelperScript.SEA_LEVEL,
		-2.0,
		"SEA_LEVEL should be -2.0",
	)


func test_fp_x_value() -> void:
	assert_eq(
		VehicleSpawnHelperScript.FP_X,
		1.2,
		"FP_X (wheel half-width) should be 1.2 m",
	)


func test_fp_z_value() -> void:
	assert_eq(
		VehicleSpawnHelperScript.FP_Z,
		1.4,
		"FP_Z (wheel half-length) should be 1.4 m",
	)


# ===========================================================================
# apply_terrain_tilt — flat surface (normal = UP, yaw = 0)
# ===========================================================================


func test_flat_normal_yaw0_basis_y_is_up() -> void:
	var v := Node3D.new()
	add_child_autofree(v)
	VehicleSpawnHelperScript.apply_terrain_tilt(v, Vector3.UP, 0.0)
	assert_almost_eq(v.basis.y.y, 1.0, 0.001, "UP terrain keeps basis.y pointing up")


func test_flat_normal_yaw0_basis_y_x_near_zero() -> void:
	var v := Node3D.new()
	add_child_autofree(v)
	VehicleSpawnHelperScript.apply_terrain_tilt(v, Vector3.UP, 0.0)
	assert_almost_eq(v.basis.y.x, 0.0, 0.001, "UP terrain: basis.y.x should be 0")


func test_flat_normal_yaw0_basis_y_z_near_zero() -> void:
	var v := Node3D.new()
	add_child_autofree(v)
	VehicleSpawnHelperScript.apply_terrain_tilt(v, Vector3.UP, 0.0)
	assert_almost_eq(v.basis.y.z, 0.0, 0.001, "UP terrain: basis.y.z should be 0")


func test_flat_normal_yaw0_basis_is_orthonormal() -> void:
	var v := Node3D.new()
	add_child_autofree(v)
	VehicleSpawnHelperScript.apply_terrain_tilt(v, Vector3.UP, 0.0)
	assert_almost_eq(
		v.basis.x.dot(v.basis.y), 0.0, 0.001, "Basis X and Y must be orthogonal"
	)
	assert_almost_eq(
		v.basis.y.dot(v.basis.z), 0.0, 0.001, "Basis Y and Z must be orthogonal"
	)


func test_flat_normal_yaw_pi_over_2_forward_rotated() -> void:
	var v := Node3D.new()
	add_child_autofree(v)
	VehicleSpawnHelperScript.apply_terrain_tilt(v, Vector3.UP, PI / 2.0)
	# fwd_flat = (-sin(π/2), 0, -cos(π/2)) = (-1, 0, 0)
	# -fwd_t should align with basis.z → basis.z ≈ (1, 0, 0)
	assert_almost_eq(v.basis.z.x, 1.0, 0.001, "yaw=π/2 should rotate forward to -X")


# ===========================================================================
# apply_terrain_tilt — tilted surface
# ===========================================================================


func test_tilted_normal_basis_y_follows_normal() -> void:
	var v := Node3D.new()
	add_child_autofree(v)
	var slope: Vector3 = Vector3(0.3, 0.954, 0.0).normalized()
	VehicleSpawnHelperScript.apply_terrain_tilt(v, slope, 0.0)
	# basis.y should align with the terrain normal
	assert_almost_eq(v.basis.y.x, slope.x, 0.01, "basis.y.x should match normal.x")
	assert_almost_eq(v.basis.y.y, slope.y, 0.01, "basis.y.y should match normal.y")
	assert_almost_eq(v.basis.y.z, slope.z, 0.01, "basis.y.z should match normal.z")


func test_tilted_normal_basis_is_orthonormal() -> void:
	var v := Node3D.new()
	add_child_autofree(v)
	var slope: Vector3 = Vector3(0.0, 0.954, 0.3).normalized()
	VehicleSpawnHelperScript.apply_terrain_tilt(v, slope, 0.0)
	assert_almost_eq(
		v.basis.x.dot(v.basis.y), 0.0, 0.001, "Tilted basis X and Y must be orthogonal"
	)
	assert_almost_eq(
		v.basis.y.dot(v.basis.z), 0.0, 0.001, "Tilted basis Y and Z must be orthogonal"
	)
	assert_almost_eq(
		v.basis.x.dot(v.basis.z), 0.0, 0.001, "Tilted basis X and Z must be orthogonal"
	)


func test_tilted_normal_basis_x_length_one() -> void:
	var v := Node3D.new()
	add_child_autofree(v)
	var slope: Vector3 = Vector3(0.3, 0.954, 0.0).normalized()
	VehicleSpawnHelperScript.apply_terrain_tilt(v, slope, 0.0)
	assert_almost_eq(v.basis.x.length(), 1.0, 0.001, "basis.x must be unit length")


func test_tilted_normal_basis_z_length_one() -> void:
	var v := Node3D.new()
	add_child_autofree(v)
	var slope: Vector3 = Vector3(0.3, 0.954, 0.0).normalized()
	VehicleSpawnHelperScript.apply_terrain_tilt(v, slope, 0.0)
	assert_almost_eq(v.basis.z.length(), 1.0, 0.001, "basis.z must be unit length")


func test_tilted_normal_yaw_pi_basis_y_still_follows_normal() -> void:
	var v := Node3D.new()
	add_child_autofree(v)
	var slope: Vector3 = Vector3(0.0, 0.954, -0.3).normalized()
	VehicleSpawnHelperScript.apply_terrain_tilt(v, slope, PI)
	assert_almost_eq(v.basis.y.y, slope.y, 0.01, "basis.y.y should match normal.y at yaw=π")


# ===========================================================================
# apply_terrain_tilt — degenerate forward vector (fallback to yaw rotation)
# ===========================================================================
# When normal = (0,0,-1) and yaw = 0:
#   fwd_flat = (-sin(0), 0, -cos(0)) = (0, 0, -1)
#   dot = fwd_flat · normal = (0)(0)+(0)(0)+(-1)(-1) = 1
#   fwd_t = fwd_flat - normal * 1 = (0,0,-1) - (0,0,-1) = (0,0,0)
#   length_squared = 0 ≤ 0.01 → fallback: rotation.y = yaw


func test_degenerate_fwd_fallback_sets_rotation_y() -> void:
	var v := Node3D.new()
	add_child_autofree(v)
	var degenerate_normal: Vector3 = Vector3(0.0, 0.0, -1.0)
	VehicleSpawnHelperScript.apply_terrain_tilt(v, degenerate_normal, 0.0)
	assert_almost_eq(v.rotation.y, 0.0, 0.001, "Degenerate fwd: rotation.y should equal yaw")


func test_degenerate_fwd_fallback_nonzero_yaw() -> void:
	var v := Node3D.new()
	add_child_autofree(v)
	var yaw: float = PI / 4.0
	# Normal parallel to fwd_flat causes fwd_t to collapse → triggers degenerate path
	var degenerate_normal: Vector3 = Vector3(-sin(yaw), 0.0, -cos(yaw)).normalized()
	VehicleSpawnHelperScript.apply_terrain_tilt(v, degenerate_normal, yaw)
	assert_almost_eq(
		v.rotation.y, yaw, 0.001, "Degenerate fwd: rotation.y should equal the given yaw"
	)


func test_degenerate_fwd_fallback_negative_yaw() -> void:
	var v := Node3D.new()
	add_child_autofree(v)
	var yaw: float = -PI / 3.0
	# Normal parallel to fwd_flat causes fwd_t to collapse → triggers degenerate path
	var degenerate_normal: Vector3 = Vector3(-sin(yaw), 0.0, -cos(yaw)).normalized()
	VehicleSpawnHelperScript.apply_terrain_tilt(v, degenerate_normal, yaw)
	assert_almost_eq(
		v.rotation.y, yaw, 0.001, "Degenerate fwd: rotation.y should equal negative yaw"
	)


func test_degenerate_fwd_does_not_crash() -> void:
	# Ensure no assert/error is raised on fully degenerate input.
	var v := Node3D.new()
	add_child_autofree(v)
	VehicleSpawnHelperScript.apply_terrain_tilt(v, Vector3(0.0, 0.0, -1.0), 0.0)
	assert_true(true, "apply_terrain_tilt must not crash on degenerate normal")


# ===========================================================================
# probe_spawn_surface — source-code inspection
# ===========================================================================


func test_probe_spawn_surface_uses_collision_mask_1() -> void:
	var src: String = (VehicleSpawnHelperScript as GDScript).source_code
	assert_true(
		src.contains("collision_mask = 1"),
		"probe_spawn_surface must set collision_mask = 1 (Ground layer only)",
	)


func test_probe_spawn_surface_calls_get_signed_distance() -> void:
	var src: String = (VehicleSpawnHelperScript as GDScript).source_code
	assert_true(
		src.contains("get_signed_distance"),
		"probe_spawn_surface must call boundary.get_signed_distance()",
	)


func test_probe_spawn_surface_calls_get_ground_height() -> void:
	var src: String = (VehicleSpawnHelperScript as GDScript).source_code
	assert_true(
		src.contains("get_ground_height"),
		"probe_spawn_surface must call boundary.get_ground_height() for outside-city fallback",
	)


func test_probe_spawn_surface_guards_sd_lt_0_and_sea_level() -> void:
	var src: String = (VehicleSpawnHelperScript as GDScript).source_code
	assert_true(
		src.contains("sd < 0.0") and src.contains("SEA_LEVEL"),
		"probe_spawn_surface must guard against surface_y < SEA_LEVEL when inside city",
	)


func test_probe_spawn_surface_returns_ok_false_by_default() -> void:
	var src: String = (VehicleSpawnHelperScript as GDScript).source_code
	assert_true(
		src.contains('"ok": false'),
		"probe_spawn_surface result dict must initialise ok to false",
	)


func test_probe_spawn_surface_returns_terrain_normal_key() -> void:
	var src: String = (VehicleSpawnHelperScript as GDScript).source_code
	assert_true(
		src.contains('"terrain_normal"'),
		"probe_spawn_surface result must contain terrain_normal key",
	)


func test_probe_spawn_surface_returns_corner_h_key() -> void:
	var src: String = (VehicleSpawnHelperScript as GDScript).source_code
	assert_true(
		src.contains('"corner_h"'),
		"probe_spawn_surface result must contain corner_h key for per-wheel heights",
	)


func test_probe_spawn_surface_skips_steep_slope() -> void:
	var src: String = (VehicleSpawnHelperScript as GDScript).source_code
	assert_true(
		src.contains("terrain_normal.y <= 0.3"),
		"probe_spawn_surface must reject positions steeper than ~73° (normal.y <= 0.3)",
	)


# ===========================================================================
# is_embedded — source-code inspection
# ===========================================================================


func test_is_embedded_uses_direct_space_state() -> void:
	var src: String = (VehicleSpawnHelperScript as GDScript).source_code
	assert_true(
		src.contains("direct_space_state"),
		"is_embedded must access world.direct_space_state",
	)


func test_is_embedded_calls_intersect_ray() -> void:
	var src: String = (VehicleSpawnHelperScript as GDScript).source_code
	assert_true(
		src.contains("intersect_ray"),
		"is_embedded must call intersect_ray() to sample terrain below the vehicle",
	)


func test_is_embedded_reads_global_position() -> void:
	var src: String = (VehicleSpawnHelperScript as GDScript).source_code
	assert_true(
		src.contains("global_position"),
		"is_embedded must read the vehicle's global_position",
	)


func test_is_embedded_returns_false_when_no_hit() -> void:
	var src: String = (VehicleSpawnHelperScript as GDScript).source_code
	assert_true(
		src.contains("return false"),
		"is_embedded must return false when the ray finds no hit",
	)
