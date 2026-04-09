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
