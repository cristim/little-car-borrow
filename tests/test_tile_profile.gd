extends GutTest
## Unit tests for tile_profile.gd edge profile system.

const TP = preload("res://src/tile_profile.gd")


func test_get_opposite_directions() -> void:
	assert_eq(TP.get_opposite(TP.NORTH), TP.SOUTH)
	assert_eq(TP.get_opposite(TP.SOUTH), TP.NORTH)
	assert_eq(TP.get_opposite(TP.EAST), TP.WEST)
	assert_eq(TP.get_opposite(TP.WEST), TP.EAST)


func test_create_flat_edge_default_height() -> void:
	var edge: Dictionary = TP.create_flat_edge("city_center")
	assert_eq(edge["biome"], "city_center")
	assert_eq(edge["roads"].size(), 0)
	assert_eq(edge["heights"].size(), TP.HEIGHT_SAMPLES)
	for i in range(TP.HEIGHT_SAMPLES):
		assert_eq(edge["heights"][i], 0.0)
	assert_true(edge["river"].is_empty())


func test_create_flat_edge_custom_height() -> void:
	var edge: Dictionary = TP.create_flat_edge("suburb", 5.0)
	for i in range(TP.HEIGHT_SAMPLES):
		assert_eq(edge["heights"][i], 5.0)


func test_create_edge_with_roads() -> void:
	var roads: Array = [{"position": 0.3, "width": 0.05}]
	var heights := PackedFloat32Array()
	heights.resize(TP.HEIGHT_SAMPLES)
	heights.fill(0.0)
	var edge: Dictionary = TP.create_edge("farmland", roads, heights, {})
	assert_eq(edge["roads"].size(), 1)
	assert_eq(edge["roads"][0]["position"], 0.3)


func test_biomes_compatible_valid_pairs() -> void:
	assert_true(TP.biomes_compatible("city_center", "residential"))
	assert_true(TP.biomes_compatible("residential", "suburb"))
	assert_true(TP.biomes_compatible("forest", "mountain"))
	assert_true(TP.biomes_compatible("farmland", "ocean"))


func test_biomes_compatible_invalid_pairs() -> void:
	assert_false(TP.biomes_compatible("city_center", "forest"))
	assert_false(TP.biomes_compatible("mountain", "ocean"))
	assert_false(TP.biomes_compatible("city_center", "ocean"))
	assert_false(TP.biomes_compatible("mountain", "farmland"))


func test_biomes_compatible_empty_string_always_true() -> void:
	assert_true(TP.biomes_compatible("", "forest"))
	assert_true(TP.biomes_compatible("city_center", ""))
	assert_true(TP.biomes_compatible("", ""))


func test_edges_compatible_matching_flat_city() -> void:
	var a: Dictionary = TP.create_flat_edge("city_center")
	var b: Dictionary = TP.create_flat_edge("residential")
	assert_true(TP.edges_compatible(a, b))


func test_edges_compatible_road_mismatch() -> void:
	var roads_a: Array = [{"position": 0.5, "width": 0.05}]
	var heights := PackedFloat32Array()
	heights.resize(TP.HEIGHT_SAMPLES)
	heights.fill(0.0)
	var a: Dictionary = TP.create_edge("suburb", roads_a, heights, {})
	var b: Dictionary = TP.create_flat_edge("suburb")
	assert_false(TP.edges_compatible(a, b))


func test_edges_compatible_road_match() -> void:
	var roads: Array = [{"position": 0.5, "width": 0.05}]
	var heights := PackedFloat32Array()
	heights.resize(TP.HEIGHT_SAMPLES)
	heights.fill(0.0)
	var a: Dictionary = TP.create_edge("suburb", roads, heights, {})
	var b: Dictionary = TP.create_edge("farmland", roads.duplicate(true), heights, {})
	assert_true(TP.edges_compatible(a, b))


func test_edges_compatible_height_mismatch() -> void:
	var h1 := PackedFloat32Array()
	h1.resize(TP.HEIGHT_SAMPLES)
	h1.fill(0.0)
	var h2 := PackedFloat32Array()
	h2.resize(TP.HEIGHT_SAMPLES)
	h2.fill(10.0)
	var a: Dictionary = TP.create_edge("forest", [], h1, {})
	var b: Dictionary = TP.create_edge("forest", [], h2, {})
	assert_false(TP.edges_compatible(a, b))


func test_edges_compatible_biome_mismatch() -> void:
	var a: Dictionary = TP.create_flat_edge("city_center")
	var b: Dictionary = TP.create_flat_edge("mountain")
	assert_false(TP.edges_compatible(a, b))


func test_city_biomes_constant() -> void:
	assert_true("city_center" in TP.CITY_BIOMES)
	assert_true("residential" in TP.CITY_BIOMES)
	assert_true("suburb" in TP.CITY_BIOMES)
	assert_false("forest" in TP.CITY_BIOMES)


func test_all_biomes_have_adjacency_entry() -> void:
	for biome: String in TP.BIOME_ADJACENCY:
		var neighbors: Array = TP.BIOME_ADJACENCY[biome]
		assert_gt(
			neighbors.size(), 0,
			"Biome %s should have at least one neighbor" % biome,
		)


func test_adjacency_is_symmetric() -> void:
	for biome_a: String in TP.BIOME_ADJACENCY:
		var neighbors: Array = TP.BIOME_ADJACENCY[biome_a]
		for biome_b: String in neighbors:
			var reverse: Array = TP.BIOME_ADJACENCY.get(biome_b, [])
			assert_true(
				biome_a in reverse,
				"Adjacency should be symmetric: %s -> %s but not reverse"
				% [biome_a, biome_b],
			)
