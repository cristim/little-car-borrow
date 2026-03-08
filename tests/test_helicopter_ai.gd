extends GutTest
## Unit tests for helicopter AI scene tree, states, and despawn.

const HeliScript = preload(
	"res://scenes/vehicles/helicopter_ai.gd"
)

var _heli: CharacterBody3D = null


func before_each() -> void:
	_heli = CharacterBody3D.new()
	_heli.set_script(HeliScript)
	add_child_autofree(_heli)


# ==========================================================================
# Scene tree construction
# ==========================================================================

func test_has_body_child() -> void:
	var body := _heli.get_node_or_null("Body")
	assert_not_null(body, "Should have Body child")


func test_has_fuselage_mesh() -> void:
	var mesh := _heli.get_node_or_null("Body/FuselageMesh")
	assert_not_null(mesh, "Should have FuselageMesh")
	assert_true(mesh is MeshInstance3D)


func test_has_rotor_pivot() -> void:
	var pivot := _heli.get_node_or_null("RotorPivot")
	assert_not_null(pivot, "Should have RotorPivot")


func test_has_rotor_mesh() -> void:
	var mesh := _heli.get_node_or_null("RotorPivot/RotorMesh")
	assert_not_null(mesh, "Should have RotorMesh")
	assert_true(mesh is MeshInstance3D)


func test_has_tail_rotor_pivot() -> void:
	var pivot := _heli.get_node_or_null("TailRotorPivot")
	assert_not_null(pivot, "Should have TailRotorPivot")


func test_has_tail_rotor_mesh() -> void:
	var mesh := _heli.get_node_or_null(
		"TailRotorPivot/TailRotorMesh"
	)
	assert_not_null(mesh, "Should have TailRotorMesh")
	assert_true(mesh is MeshInstance3D)


func test_has_searchlight() -> void:
	var light := _heli.get_node_or_null("Searchlight")
	assert_not_null(light, "Should have Searchlight")
	assert_true(light is SpotLight3D)


func test_has_shoot_timer() -> void:
	var timer := _heli.get_node_or_null("ShootTimer")
	assert_not_null(timer, "Should have ShootTimer")
	assert_true(timer is Timer)


func test_has_rotor_audio() -> void:
	var audio := _heli.get_node_or_null("RotorAudio")
	assert_not_null(audio, "Should have RotorAudio")
	assert_true(audio is AudioStreamPlayer3D)


# ==========================================================================
# Group membership
# ==========================================================================

func test_in_police_helicopter_group() -> void:
	assert_true(
		_heli.is_in_group("police_helicopter"),
		"Should be in police_helicopter group",
	)


# ==========================================================================
# Collision setup
# ==========================================================================

func test_collision_layer_zero() -> void:
	assert_eq(
		_heli.collision_layer, 0,
		"Helicopter should not be on any collision layer",
	)


func test_collision_mask_static_only() -> void:
	assert_eq(
		_heli.collision_mask, 2,
		"Helicopter should only collide with Static layer",
	)


# ==========================================================================
# State transitions
# ==========================================================================

func test_initial_state_is_approach() -> void:
	assert_eq(
		_heli._state, HeliScript.HeliState.APPROACH,
		"Initial state should be APPROACH",
	)


func test_begin_despawn_sets_state() -> void:
	_heli.begin_despawn()
	assert_eq(
		_heli._state, HeliScript.HeliState.DESPAWNING,
		"begin_despawn should set state to DESPAWNING",
	)


func test_begin_despawn_stops_shoot_timer() -> void:
	_heli.begin_despawn()
	var timer: Timer = _heli.get_node("ShootTimer")
	assert_true(
		timer.is_stopped(),
		"ShootTimer should be stopped after despawn",
	)


func test_begin_despawn_idempotent() -> void:
	_heli.begin_despawn()
	_heli.begin_despawn()
	assert_eq(
		_heli._state, HeliScript.HeliState.DESPAWNING,
		"Calling begin_despawn twice should not crash",
	)


# ==========================================================================
# Searchlight properties
# ==========================================================================

func test_searchlight_range() -> void:
	var light: SpotLight3D = _heli.get_node("Searchlight")
	assert_eq(
		light.spot_range, HeliScript.SPOTLIGHT_RANGE,
		"Searchlight range should match constant",
	)


func test_searchlight_angle() -> void:
	var light: SpotLight3D = _heli.get_node("Searchlight")
	assert_eq(
		light.spot_angle, HeliScript.SPOTLIGHT_ANGLE,
		"Searchlight angle should match constant",
	)


func test_searchlight_shadow_enabled() -> void:
	var light: SpotLight3D = _heli.get_node("Searchlight")
	assert_true(
		light.shadow_enabled,
		"Searchlight should have shadows enabled",
	)
