extends RefCounted
## Edge profile data structure for Carcassonne-style tile matching.
## Each chunk has 4 edges (N/E/S/W). Edges store biome, road positions,
## height samples, and river data for seamless neighbor matching.

const NORTH := 0  # -Z direction
const EAST := 1   # +X direction
const SOUTH := 2  # +Z direction
const WEST := 3   # -X direction

const HEIGHT_SAMPLES := 8  # number of height samples per edge

const CITY_BIOMES: Array[String] = ["city_center", "residential", "suburb"]

const BIOME_ADJACENCY: Dictionary = {
	"city_center": ["city_center", "residential"],
	"residential": ["city_center", "residential", "suburb"],
	"suburb": [
		"residential", "suburb", "village",
		"farmland", "forest", "ocean",
	],
	"village": ["suburb", "farmland", "forest", "village"],
	"forest": ["suburb", "village", "forest", "mountain", "farmland", "ocean"],
	"mountain": ["forest", "mountain"],
	"farmland": ["suburb", "village", "forest", "farmland", "ocean"],
	"ocean": ["ocean", "farmland", "forest", "suburb"],
}


## Create an edge profile dictionary.
static func create_edge(
	biome: String,
	roads: Array,
	heights: PackedFloat32Array,
	river: Dictionary,
) -> Dictionary:
	return {
		"biome": biome,
		"roads": roads,
		"heights": heights,
		"river": river,
	}


## Create a flat edge profile (for city tiles where height = constant).
static func create_flat_edge(biome: String, height: float = 0.0) -> Dictionary:
	var heights := PackedFloat32Array()
	heights.resize(HEIGHT_SAMPLES)
	heights.fill(height)
	return create_edge(biome, [], heights, {})


## Return the opposite direction (NORTH <-> SOUTH, EAST <-> WEST).
static func get_opposite(dir: int) -> int:
	return (dir + 2) % 4


## Check if two facing edges are compatible for matching.
## a = edge of tile A facing tile B, b = edge of tile B facing tile A.
static func edges_compatible(a: Dictionary, b: Dictionary) -> bool:
	# Check biome adjacency
	if not biomes_compatible(a.get("biome", ""), b.get("biome", "")):
		return false

	# Check road continuity: each road in a should have a matching road in b
	var roads_a: Array = a.get("roads", [])
	var roads_b: Array = b.get("roads", [])
	if roads_a.size() != roads_b.size():
		return false
	for ra: Dictionary in roads_a:
		var matched := false
		for rb: Dictionary in roads_b:
			if absf(ra.get("position", 0.0) - rb.get("position", 0.0)) < 0.05:
				if absf(ra.get("width", 0.0) - rb.get("width", 0.0)) < 0.1:
					matched = true
					break
		if not matched:
			return false

	# Check height continuity
	var ha: PackedFloat32Array = a.get("heights", PackedFloat32Array())
	var hb: PackedFloat32Array = b.get("heights", PackedFloat32Array())
	if ha.size() > 0 and hb.size() > 0 and ha.size() == hb.size():
		for i in range(ha.size()):
			if absf(ha[i] - hb[i]) > 1.0:
				return false

	# Check river continuity
	var river_a: Dictionary = a.get("river", {})
	var river_b: Dictionary = b.get("river", {})
	var a_has_river := river_a.has("position")
	var b_has_river := river_b.has("position")
	if a_has_river != b_has_river:
		return false
	if a_has_river and b_has_river:
		if absf(river_a["position"] - river_b["position"]) > 0.05:
			return false

	return true


## Check if two biomes are allowed to be adjacent.
static func biomes_compatible(biome_a: String, biome_b: String) -> bool:
	if biome_a == "" or biome_b == "":
		return true
	var allowed: Array = BIOME_ADJACENCY.get(biome_a, [])
	return biome_b in allowed
