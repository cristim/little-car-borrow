extends GutTest
## C2/C3 regression tests for MissionManager that couldn't fit in the main test file.

const MissionScript = preload("res://src/autoloads/mission_manager.gd")


func _make_mm() -> Node:
	var mm: Node = MissionScript.new()
	add_child_autofree(mm)
	var p := Node3D.new()
	add_child_autofree(p)
	mm._player = p
	mm._rng.randomize()
	return mm


# ================================================================
# C2 — Mission IDs use monotonic counter (unique per generator call)
# ================================================================


func test_mission_ids_unique_and_prefixed() -> void:
	var mm: Node = _make_mm()
	var d: Dictionary = mm._generate_delivery()
	var t: Dictionary = mm._generate_taxi()
	var s: Dictionary = mm._generate_theft()
	assert_ne(d["id"], t["id"], "Delivery and taxi IDs must differ")
	assert_true(d["id"].begins_with("delivery_"), "Delivery ID prefix")
	assert_true(t["id"].begins_with("taxi_"), "Taxi ID prefix")
	assert_true(s["id"].begins_with("theft_"), "Theft ID prefix")


# ================================================================
# C3 — _get_boundary null-safe for freed node (is_instance_valid guard)
# ================================================================


func test_get_boundary_null_for_freed_node() -> void:
	var mm: Node = _make_mm()
	var stale := Node.new()
	add_child(stale)
	mm._boundary = stale
	stale.free()
	var result = mm._get_boundary()
	assert_null(result, "Freed boundary must return null, not stale reference")


# ================================================================
# H1 — _try_unlock_smg fires at most once
# XH2 — _try_unlock_smg safe with freed player node
# ================================================================


func test_smg_unlocked_flag_set_after_valid_player() -> void:
	var mm: Node = _make_mm()
	var p := Node.new()
	p.add_to_group("player")
	add_child_autofree(p)
	mm._try_unlock_smg()
	assert_true(mm._smg_unlocked, "Flag must be set after first unlock attempt with valid player")


func test_smg_unlock_idempotent() -> void:
	var mm: Node = _make_mm()
	var p := Node.new()
	p.add_to_group("player")
	add_child_autofree(p)
	mm._try_unlock_smg()
	var flag_after_first: bool = mm._smg_unlocked
	mm._try_unlock_smg()
	assert_true(flag_after_first, "Flag set on first call")
	assert_true(mm._smg_unlocked, "Flag stays set on second call")


func test_smg_unlock_safe_with_freed_player() -> void:
	var mm: Node = _make_mm()
	var p := Node.new()
	p.add_to_group("player")
	add_child(p)
	p.free()
	mm._try_unlock_smg()
	pass_test("_try_unlock_smg with freed player must not crash")


# ================================================================
# H3 — Active mission timer clamped at 0.0 (never goes negative)
# ================================================================


func test_mission_timer_clamped_at_zero() -> void:
	var mm: Node = _make_mm()
	mm._active_mission = {
		"id": "test_1",
		"type": "delivery",
		"state": "active",
		"time_limit": 1.0,
	}
	mm._mission_timer = 0.01
	mm._process(1.0)
	assert_almost_eq(mm._mission_timer, 0.0, 0.001, "Timer must clamp to 0.0, never go negative")


# ================================================================
# H4 — Vehicle variant read from node meta, not fragile scale matching
# ================================================================


func test_vehicle_variant_read_from_meta() -> void:
	var mm: Node = _make_mm()
	mm._active_mission = {
		"id": "theft_1",
		"type": "theft",
		"state": "pickup",
		"vehicle_variant": "sedan",
		"time_limit": 0.0,
	}
	var vehicle := Node.new()
	vehicle.set_meta("variant", "sedan")
	add_child_autofree(vehicle)
	mm._on_vehicle_entered(vehicle)
	assert_eq(
		mm._active_mission.get("state", ""),
		"active",
		"Mission state should become active when matching vehicle meta variant entered",
	)


func test_vehicle_variant_mismatch_does_not_activate() -> void:
	var mm: Node = _make_mm()
	mm._active_mission = {
		"id": "theft_1",
		"type": "theft",
		"state": "pickup",
		"vehicle_variant": "sedan",
		"time_limit": 0.0,
	}
	var vehicle := Node.new()
	vehicle.set_meta("variant", "sports")
	add_child_autofree(vehicle)
	mm._on_vehicle_entered(vehicle)
	assert_eq(
		mm._active_mission.get("state", ""),
		"pickup",
		"Mission state must stay pickup when variant does not match",
	)
