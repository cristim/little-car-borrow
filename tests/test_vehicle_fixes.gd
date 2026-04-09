extends GutTest
## Source-inspection tests for vehicles/L1, L3, L5 and
## core/L2, L3, L4 low-severity fixes.

const HelicopterAIScript = preload("res://scenes/vehicles/helicopter_ai.gd")
const VehicleHealthScript = preload("res://scenes/vehicles/vehicle_health.gd")
const PoliceSirenScript = preload("res://scenes/vehicles/police_siren.gd")
const StateMachineScript = preload("res://src/state_machine/state_machine.gd")
const ChunkPersistenceScript = preload("res://src/chunk_persistence.gd")
const WeaponMeshBuilderScript = preload("res://src/weapon_mesh_builder.gd")
const GameManagerScript = preload("res://src/autoloads/game_manager.gd")


# ==========================================================================
# vehicles/L1 — helicopter body tilt lerps instead of snapping
# ==========================================================================


func test_helicopter_tilt_uses_lerpf() -> void:
	var src: String = (HelicopterAIScript as GDScript).source_code
	assert_true(
		src.contains("lerpf(rotation.x, -TILT_ANGLE"),
		"Helicopter tilt must use lerpf to reach -TILT_ANGLE (no snap)",
	)


func test_helicopter_tilt_not_hardcoded() -> void:
	var src: String = (HelicopterAIScript as GDScript).source_code
	assert_false(
		src.contains("rotation.x = -TILT_ANGLE"),
		"Helicopter tilt must not assign rotation.x directly (causes snap)",
	)


# ==========================================================================
# vehicles/L3 — fire sound stored and stopped on explosion
# ==========================================================================


func test_vehicle_health_has_fire_sound_var() -> void:
	var src: String = (VehicleHealthScript as GDScript).source_code
	assert_true(
		src.contains("_fire_sound"),
		"vehicle_health must declare _fire_sound member variable",
	)


func test_vehicle_health_stops_fire_sound_on_explode() -> void:
	var src: String = (VehicleHealthScript as GDScript).source_code
	var explode_idx: int = src.find("func _explode()")
	var explode_body: String = src.substr(explode_idx, 300)
	assert_true(
		explode_body.contains("_fire_sound") and explode_body.contains(".stop()"),
		"_explode must stop _fire_sound before cleaning up",
	)


# ==========================================================================
# vehicles/L5 — police siren distance culling
# ==========================================================================


func test_police_siren_has_cull_distance() -> void:
	var src: String = (PoliceSirenScript as GDScript).source_code
	assert_true(
		src.contains("CULL_DISTANCE"),
		"PoliceSiren must define CULL_DISTANCE constant",
	)


func test_police_siren_process_checks_distance() -> void:
	var src: String = (PoliceSirenScript as GDScript).source_code
	var proc_idx: int = src.find("func _process(")
	var proc_body: String = src.substr(proc_idx, 250)
	assert_true(
		proc_body.contains("CULL_DISTANCE") and proc_body.contains("distance_to"),
		"_process must cull frame generation beyond CULL_DISTANCE",
	)


# ==========================================================================
# core/L2 — state_machine validates initial_state is own child
# ==========================================================================


func test_state_machine_validates_initial_state_parent() -> void:
	var src: String = (StateMachineScript as GDScript).source_code
	assert_true(
		src.contains("initial_state.get_parent() != self"),
		"StateMachine must validate initial_state.get_parent() == self",
	)


# ==========================================================================
# core/L3 — chunk_persistence save_tile syncs dirty dict
# ==========================================================================


func test_save_tile_erases_from_dirty() -> void:
	var src: String = (ChunkPersistenceScript as GDScript).source_code
	var save_idx: int = src.find("func save_tile(")
	var save_body: String = src.substr(save_idx, 350)
	assert_true(
		save_body.contains("_dirty.erase(tile)"),
		"save_tile must erase tile from _dirty to keep dict consistent",
	)


# ==========================================================================
# core/L4 — weapon_mesh_builder sets muzzle_local_pos on unknown weapon
# ==========================================================================


func test_weapon_mesh_builder_has_fallthrough() -> void:
	var src: String = (WeaponMeshBuilderScript as GDScript).source_code
	assert_true(
		src.contains("muzzle_local_pos") and src.contains("push_warning"),
		"WeaponMeshBuilder must warn and set muzzle_local_pos for unknown weapon names",
	)


# ==========================================================================
# player/L4 — SEA_LEVEL single source of truth in GameManager
# ==========================================================================


func test_game_manager_defines_sea_level() -> void:
	var src: String = (GameManagerScript as GDScript).source_code
	assert_true(
		src.contains("const SEA_LEVEL"),
		"GameManager must define the canonical SEA_LEVEL constant",
	)


func test_sea_level_value() -> void:
	assert_eq(GameManagerScript.SEA_LEVEL, -2.0, "SEA_LEVEL must be -2.0")
