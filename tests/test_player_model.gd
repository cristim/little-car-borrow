extends GutTest
## Tests for player_model.gd — methods not covered by animation/run/swim tests.
## Focuses on: _stroke_shape, _apply_arm_stroke, _is_armed, _is_flashlight_on,
## _get_gun_elbow_angle, _aim_gun_arm, _aim_flashlight_arm, and edge cases.

const PlayerModelScript = preload("res://scenes/player/player_model.gd")


class SwimParent:
	extends CharacterBody3D
	var is_swimming := false


var _model: Node3D
var _parent: SwimParent
var _ls: Node3D
var _rs: Node3D
var _lh: Node3D
var _rh: Node3D
var _le: Node3D
var _re: Node3D
var _lk: Node3D
var _rk: Node3D
var _head: Node3D
var _neck: Node3D


func before_each() -> void:
	_parent = SwimParent.new()
	_parent.visible = true
	_model = Node3D.new()
	_model.set_script(PlayerModelScript)
	_ls = Node3D.new()
	_ls.name = "LeftShoulderPivot"
	_rs = Node3D.new()
	_rs.name = "RightShoulderPivot"
	_lh = Node3D.new()
	_lh.name = "LeftHipPivot"
	_rh = Node3D.new()
	_rh.name = "RightHipPivot"
	_le = Node3D.new()
	_le.name = "LeftElbowPivot"
	_ls.add_child(_le)
	_re = Node3D.new()
	_re.name = "RightElbowPivot"
	_rs.add_child(_re)
	_lk = Node3D.new()
	_lk.name = "LeftKneePivot"
	_lh.add_child(_lk)
	_rk = Node3D.new()
	_rk.name = "RightKneePivot"
	_rh.add_child(_rk)
	var forearm := Node3D.new()
	forearm.name = "Forearm"
	_le.add_child(forearm)
	_head = MeshInstance3D.new()
	_head.name = "Head"
	_neck = MeshInstance3D.new()
	_neck.name = "Neck"
	_model.add_child(_ls)
	_model.add_child(_rs)
	_model.add_child(_lh)
	_model.add_child(_rh)
	_model.add_child(_head)
	_model.add_child(_neck)
	_parent.add_child(_model)
	add_child_autofree(_parent)
	await get_tree().process_frame


func _sim(delta: float, frames: int = 1) -> void:
	for i in frames:
		_model._process(delta)


# ==========================================================================
# Static: _stroke_shape
# ==========================================================================

func test_stroke_shape_at_zero() -> void:
	var result: float = PlayerModelScript._stroke_shape(0.0)
	assert_almost_eq(result, 0.0, 0.01, "stroke_shape(0) should be ~0")


func test_stroke_shape_bounded() -> void:
	# Check that stroke shape stays in [-1, 1] over a full cycle
	var min_val := 999.0
	var max_val := -999.0
	for i in 360:
		var phase := float(i) / 360.0 * TAU
		var val: float = PlayerModelScript._stroke_shape(phase)
		min_val = minf(min_val, val)
		max_val = maxf(max_val, val)
	assert_gte(min_val, -1.1, "stroke_shape min should be >= -1.1")
	assert_lte(max_val, 1.1, "stroke_shape max should be <= 1.1")


func test_stroke_shape_oscillates() -> void:
	var had_positive := false
	var had_negative := false
	for i in 360:
		var phase := float(i) / 360.0 * TAU
		var val: float = PlayerModelScript._stroke_shape(phase)
		if val > 0.3:
			had_positive = true
		if val < -0.3:
			had_negative = true
	assert_true(had_positive, "stroke_shape should reach positive values")
	assert_true(had_negative, "stroke_shape should reach negative values")


func test_stroke_shape_asymmetric() -> void:
	# With harmonic distortion, positive and negative half-cycles differ in width
	var pos_count := 0
	var neg_count := 0
	for i in 720:
		var phase := float(i) / 720.0 * TAU
		var val: float = PlayerModelScript._stroke_shape(phase)
		if val > 0.0:
			pos_count += 1
		elif val < 0.0:
			neg_count += 1
	assert_true(
		pos_count != neg_count,
		"Stroke shape should be asymmetric — pos=%d neg=%d" \
			% [pos_count, neg_count],
	)


# ==========================================================================
# _apply_arm_stroke
# ==========================================================================

func test_apply_arm_stroke_left_sets_all_axes() -> void:
	var shoulder := Node3D.new()
	var elbow := Node3D.new()
	add_child_autofree(shoulder)
	add_child_autofree(elbow)
	_model._apply_arm_stroke(shoulder, elbow, 0.8, 1.0)
	# Shoulder should have non-zero values on all 3 axes
	assert_true(
		absf(shoulder.rotation.x) > 0.01,
		"Shoulder X should be set",
	)
	assert_true(
		absf(shoulder.rotation.y) > 0.01,
		"Shoulder Y should be set",
	)
	assert_true(
		absf(shoulder.rotation.z) > 0.01,
		"Shoulder Z should be set",
	)


func test_apply_arm_stroke_right_mirrors_y_and_z() -> void:
	var sh_l := Node3D.new()
	var el_l := Node3D.new()
	var sh_r := Node3D.new()
	var el_r := Node3D.new()
	add_child_autofree(sh_l)
	add_child_autofree(el_l)
	add_child_autofree(sh_r)
	add_child_autofree(el_r)
	var stroke := 0.6
	_model._apply_arm_stroke(sh_l, el_l, stroke, 1.0)
	_model._apply_arm_stroke(sh_r, el_r, stroke, -1.0)
	# X should be the same
	assert_almost_eq(sh_l.rotation.x, sh_r.rotation.x, 0.001, "X same")
	# Y and Z should be negated
	assert_almost_eq(
		sh_l.rotation.y, -sh_r.rotation.y, 0.001, "Y mirrored",
	)
	assert_almost_eq(
		sh_l.rotation.z, -sh_r.rotation.z, 0.001, "Z mirrored",
	)


func test_apply_arm_stroke_elbow_x_within_bounds() -> void:
	var shoulder := Node3D.new()
	var elbow := Node3D.new()
	add_child_autofree(shoulder)
	add_child_autofree(elbow)
	# Test a range of stroke values
	for i in 20:
		var stroke := -1.0 + float(i) * 0.1
		_model._apply_arm_stroke(shoulder, elbow, stroke, 1.0)
		assert_gte(
			elbow.rotation.x, PlayerModelScript.SWIM_ELBOW_MIN,
			"Elbow X should not go below min at stroke=%f" % stroke,
		)
		assert_lte(
			elbow.rotation.x, PlayerModelScript.SWIM_ELBOW_MAX,
			"Elbow X should not exceed max at stroke=%f" % stroke,
		)


func test_apply_arm_stroke_recovery_elbow_different_from_pull() -> void:
	var sh1 := Node3D.new()
	var el1 := Node3D.new()
	var sh2 := Node3D.new()
	var el2 := Node3D.new()
	add_child_autofree(sh1)
	add_child_autofree(el1)
	add_child_autofree(sh2)
	add_child_autofree(el2)
	# Recovery phase (positive stroke)
	_model._apply_arm_stroke(sh1, el1, 0.9, 1.0)
	# Pull phase (negative stroke)
	_model._apply_arm_stroke(sh2, el2, -0.9, 1.0)
	assert_true(
		absf(el1.rotation.x - el2.rotation.x) > 0.05,
		"Elbow bend should differ between recovery and pull",
	)


# ==========================================================================
# _is_armed / _is_flashlight_on
# ==========================================================================

func test_is_armed_false_when_no_weapon_node() -> void:
	# No PlayerWeapon child on parent
	assert_false(
		_model._is_armed(),
		"_is_armed should be false without PlayerWeapon",
	)


func test_is_armed_true_when_weapon_armed() -> void:
	var pw := Node.new()
	pw.name = "PlayerWeapon"
	pw.set_meta("_armed", true)
	# Use a script to add the _armed property
	var script := GDScript.new()
	script.source_code = "extends Node\nvar _armed := true\n"
	script.reload()
	pw.set_script(script)
	_parent.add_child(pw)
	assert_true(
		_model._is_armed(),
		"_is_armed should be true when PlayerWeapon._armed is true",
	)


func test_is_armed_false_when_weapon_holstered() -> void:
	var pw := Node.new()
	pw.name = "PlayerWeapon"
	var script := GDScript.new()
	script.source_code = "extends Node\nvar _armed := false\n"
	script.reload()
	pw.set_script(script)
	_parent.add_child(pw)
	assert_false(
		_model._is_armed(),
		"_is_armed should be false when PlayerWeapon._armed is false",
	)


func test_is_flashlight_on_false_when_no_flashlight() -> void:
	assert_false(
		_model._is_flashlight_on(),
		"_is_flashlight_on should be false without Flashlight node",
	)


func test_is_flashlight_on_false_when_flashlight_hidden() -> void:
	var forearm := _le.get_node("Forearm")
	var fl := SpotLight3D.new()
	fl.name = "Flashlight"
	fl.visible = false
	forearm.add_child(fl)
	assert_false(
		_model._is_flashlight_on(),
		"_is_flashlight_on should be false when flashlight not visible",
	)


func test_is_flashlight_on_true_when_visible() -> void:
	var forearm := _le.get_node("Forearm")
	var fl := SpotLight3D.new()
	fl.name = "Flashlight"
	fl.visible = true
	forearm.add_child(fl)
	assert_true(
		_model._is_flashlight_on(),
		"_is_flashlight_on should be true when flashlight visible",
	)


# ==========================================================================
# _get_gun_elbow_angle
# ==========================================================================

func test_get_gun_elbow_default_without_weapon() -> void:
	var angle: float = _model._get_gun_elbow_angle()
	assert_almost_eq(
		angle, PlayerModelScript.DEFAULT_GUN_ELBOW, 0.001,
		"Should return DEFAULT_GUN_ELBOW without PlayerWeapon",
	)


func test_get_gun_elbow_reads_weapon_data() -> void:
	var pw := Node.new()
	pw.name = "PlayerWeapon"
	var script := GDScript.new()
	script.source_code = (
		"extends Node\n"
		+ "const WEAPONS := [{\"elbow\": -0.4}]\n"
		+ "var _current_idx := 0\n"
	)
	script.reload()
	pw.set_script(script)
	_parent.add_child(pw)
	var angle: float = _model._get_gun_elbow_angle()
	assert_almost_eq(angle, -0.4, 0.001, "Should read elbow from weapon data")


# ==========================================================================
# _aim_gun_arm
# ==========================================================================

func test_aim_gun_arm_sets_shoulder_and_elbow() -> void:
	_rs.rotation = Vector3.ZERO
	_re.rotation = Vector3.ZERO
	_model._aim_gun_arm(0.0)
	# total = -(PI/2 + 0) = -PI/2
	# shoulder.x = total - elbow_angle
	assert_true(
		absf(_rs.rotation.x) > 0.1,
		"Right shoulder X should be set after aim_gun_arm",
	)


func test_aim_gun_arm_pitch_affects_shoulder() -> void:
	_model._aim_gun_arm(0.3)
	var shoulder_at_03 := _rs.rotation.x
	_model._aim_gun_arm(-0.3)
	var shoulder_at_neg03 := _rs.rotation.x
	assert_true(
		absf(shoulder_at_03 - shoulder_at_neg03) > 0.1,
		"Different pitches should produce different shoulder rotations",
	)


# ==========================================================================
# _aim_flashlight_arm
# ==========================================================================

func test_aim_flashlight_arm_sets_left_shoulder_and_elbow() -> void:
	_ls.rotation = Vector3.ZERO
	_le.rotation = Vector3.ZERO
	_model._aim_flashlight_arm(0.0)
	assert_true(
		absf(_ls.rotation.x) > 0.1,
		"Left shoulder X should be set after aim_flashlight_arm",
	)
	assert_true(
		absf(_le.rotation.x) > 0.01,
		"Left elbow X should be set after aim_flashlight_arm",
	)


func test_aim_flashlight_elbow_varies_with_pitch() -> void:
	_model._aim_flashlight_arm(PlayerModelScript.PITCH_UP)
	var elbow_up := _le.rotation.x
	_model._aim_flashlight_arm(PlayerModelScript.PITCH_DOWN)
	var elbow_down := _le.rotation.x
	assert_true(
		absf(elbow_up - elbow_down) > 0.1,
		"Elbow angle should vary between pitch up and pitch down",
	)


func test_aim_flashlight_elbow_clamped_range() -> void:
	_model._aim_flashlight_arm(PlayerModelScript.PITCH_UP)
	var elbow_up := _le.rotation.x
	_model._aim_flashlight_arm(PlayerModelScript.PITCH_DOWN)
	var elbow_down := _le.rotation.x
	# Up should give FLASH_ELBOW_UP, down should give FLASH_ELBOW_DOWN
	assert_almost_eq(
		elbow_up, PlayerModelScript.FLASH_ELBOW_UP, 0.01,
		"Pitch up should give FLASH_ELBOW_UP",
	)
	assert_almost_eq(
		elbow_down, PlayerModelScript.FLASH_ELBOW_DOWN, 0.01,
		"Pitch down should give FLASH_ELBOW_DOWN",
	)


# ==========================================================================
# Constants sanity
# ==========================================================================

func test_run_threshold_positive() -> void:
	assert_gt(
		PlayerModelScript.RUN_THRESHOLD, 0.0,
		"RUN_THRESHOLD should be positive",
	)


func test_swim_frequency_positive() -> void:
	assert_gt(
		PlayerModelScript.SWIM_FREQUENCY, 0.0,
		"SWIM_FREQUENCY should be positive",
	)


func test_decay_speed_positive() -> void:
	assert_gt(
		PlayerModelScript.DECAY_SPEED, 0.0,
		"DECAY_SPEED should be positive",
	)


func test_swim_decay_faster_than_normal() -> void:
	assert_gt(
		PlayerModelScript.SWIM_DECAY_SPEED, PlayerModelScript.DECAY_SPEED,
		"SWIM_DECAY_SPEED should be faster than DECAY_SPEED",
	)


# ==========================================================================
# _was_swimming transition flag
# ==========================================================================

func test_was_swimming_set_after_swim() -> void:
	_parent.is_swimming = true
	_sim(0.016, 10)
	assert_true(
		_model._was_swimming,
		"_was_swimming should be true after swimming",
	)


func test_was_swimming_clears_after_decay() -> void:
	_parent.is_swimming = true
	_sim(0.016, 30)
	_parent.is_swimming = false
	_parent.velocity = Vector3.ZERO
	# Simulate enough frames for body rotation to decay below 0.1
	_sim(0.1, 40)
	assert_false(
		_model._was_swimming,
		"_was_swimming should clear once rotation decays",
	)


# ==========================================================================
# Hip sway position resets when idle
# ==========================================================================

func test_hip_sway_resets_on_stop() -> void:
	_parent.velocity = Vector3(0, 0, 5.0)
	_sim(0.016, 30)
	_parent.velocity = Vector3.ZERO
	_sim(0.1, 30)
	assert_almost_eq(
		_model.position.x, 0.0, 0.01,
		"Hip sway (position.x) should decay to 0 when idle",
	)


# ==========================================================================
# Face details — _ready builds head parts
# ==========================================================================

func test_face_details_eyes_created() -> void:
	assert_not_null(
		_head.get_node_or_null("EyeLeft"),
		"_ready should add EyeLeft to Head",
	)
	assert_not_null(
		_head.get_node_or_null("EyeRight"),
		"_ready should add EyeRight to Head",
	)


func test_face_details_ears_created() -> void:
	assert_not_null(
		_head.get_node_or_null("EarLeft"),
		"_ready should add EarLeft to Head",
	)
	assert_not_null(
		_head.get_node_or_null("EarRight"),
		"_ready should add EarRight to Head",
	)


func test_face_details_hair_created() -> void:
	assert_not_null(
		_head.get_node_or_null("HairTop"),
		"_ready should add HairTop to Head",
	)


func test_face_details_nose_created() -> void:
	assert_not_null(
		_head.get_node_or_null("Nose"),
		"_ready should add Nose to Head",
	)


func test_face_details_mouth_created() -> void:
	assert_not_null(
		_head.get_node_or_null("Mouth"),
		"_ready should add Mouth to Head",
	)


func test_face_details_are_mesh_instances() -> void:
	for part_name in ["EyeLeft", "EyeRight", "EarLeft", "EarRight",
					"HairTop", "Nose", "Mouth", "BrowLeft", "BrowRight"]:
		var node: Node = _head.get_node_or_null(part_name)
		assert_not_null(node, "%s should exist" % part_name)
		assert_true(
			node is MeshInstance3D,
			"%s should be MeshInstance3D" % part_name,
		)


func test_eyes_are_darker_than_skin() -> void:
	var eye := _head.get_node("EyeLeft") as MeshInstance3D
	var ear := _head.get_node("EarLeft") as MeshInstance3D
	var eye_mesh := eye.mesh as BoxMesh
	var ear_mesh := ear.mesh as BoxMesh
	# Eye albedo luminance should be less than ear (skin) albedo luminance
	var eye_lum: float = eye_mesh.material.albedo_color.get_luminance()
	var ear_lum: float = ear_mesh.material.albedo_color.get_luminance()
	assert_lt(eye_lum, ear_lum, "Eyes should be darker than skin-coloured ears")


func test_hair_is_darker_than_skin() -> void:
	var hair := _head.get_node("HairTop") as MeshInstance3D
	var ear := _head.get_node("EarLeft") as MeshInstance3D
	var hair_mesh := hair.mesh as BoxMesh
	var ear_mesh := ear.mesh as BoxMesh
	var hair_lum: float = hair_mesh.material.albedo_color.get_luminance()
	var ear_lum: float = ear_mesh.material.albedo_color.get_luminance()
	assert_lt(hair_lum, ear_lum, "Hair should be darker than skin")


func test_ears_protrude_sideways() -> void:
	# Ears should be positioned with |X| > head half-width (0.11)
	var ear_l := _head.get_node("EarLeft") as MeshInstance3D
	var ear_r := _head.get_node("EarRight") as MeshInstance3D
	assert_gt(ear_l.position.x, 0.10, "Left ear should extend past head edge")
	assert_lt(ear_r.position.x, -0.10, "Right ear should extend past head edge")


func test_eyes_are_on_front_face() -> void:
	# Player faces +Z, so front face of head is at Z = +0.095; eyes must be there
	var eye_l := _head.get_node("EyeLeft") as MeshInstance3D
	assert_gt(eye_l.position.z, 0.09, "Eye should be on front face (+Z) of head")


# ==========================================================================
# Hand details — _ready builds hand parts on elbow pivots
# ==========================================================================

func test_hand_left_palm_created() -> void:
	assert_not_null(
		_le.get_node_or_null("HandLeft_Palm"),
		"_ready should add HandLeft_Palm to LeftElbowPivot",
	)


func test_hand_right_palm_created() -> void:
	assert_not_null(
		_re.get_node_or_null("HandRight_Palm"),
		"_ready should add HandRight_Palm to RightElbowPivot",
	)


func test_hand_left_flashlight_body_created() -> void:
	assert_not_null(
		_le.get_node_or_null("FlashlightBody"),
		"_ready should add FlashlightBody to LeftElbowPivot",
	)


func test_hand_parts_are_mesh_instances() -> void:
	var left_parts := ["HandLeft_Palm", "HandLeft_Fingers", "HandLeft_Thumb",
		"FlashlightBody"]
	var right_parts := ["HandRight_Palm", "HandRight_Fingers", "HandRight_Thumb"]
	for part_name in left_parts:
		var node: Node = _le.get_node_or_null(part_name)
		assert_not_null(node, "%s should exist on left elbow" % part_name)
		assert_true(node is MeshInstance3D, "%s should be MeshInstance3D" % part_name)
	for part_name in right_parts:
		var node: Node = _re.get_node_or_null(part_name)
		assert_not_null(node, "%s should exist on right elbow" % part_name)
		assert_true(node is MeshInstance3D, "%s should be MeshInstance3D" % part_name)


func test_hands_at_wrist_depth() -> void:
	var palm_l := _le.get_node("HandLeft_Palm") as MeshInstance3D
	assert_lt(
		palm_l.position.y, -0.24,
		"Left palm should be at wrist depth (Y < -0.24 from elbow)",
	)


func test_right_hand_at_gun_grip_height() -> void:
	# Palm should sit at wrist depth (Y ≈ -0.252), not mid-forearm.
	var palm_r := _re.get_node("HandRight_Palm") as MeshInstance3D
	assert_lt(
		palm_r.position.y, -0.22,
		"Right palm should be at wrist depth (Y < -0.22 from elbow)",
	)
	# Palm Z offset must be small — not sticking out perpendicular to the forearm.
	assert_lt(
		absf(palm_r.position.z), 0.05,
		"Right palm Z offset should be < 5 cm (not perpendicular to arm)",
	)


func test_flashlight_body_tilted_upward() -> void:
	var fl_body := _le.get_node("FlashlightBody") as MeshInstance3D
	# 20° upward tilt → rotation.x ≈ -deg_to_rad(20) ≈ -0.349
	assert_lt(
		fl_body.rotation.x, -0.30,
		"FlashlightBody should be tilted upward (rotation.x < -0.30 rad)",
	)


func test_flashlight_body_has_forward_z_offset() -> void:
	var fl_body := _le.get_node("FlashlightBody") as MeshInstance3D
	assert_lt(
		fl_body.position.z, -0.02,
		"FlashlightBody should extend in -Z (forward of palm when aimed)",
	)


func test_thumb_sides_are_mirrored() -> void:
	var thumb_l := _le.get_node("HandLeft_Thumb") as MeshInstance3D
	var thumb_r := _re.get_node("HandRight_Thumb") as MeshInstance3D
	assert_gt(thumb_l.position.x, 0.0, "Left thumb should be on +X side")
	assert_lt(thumb_r.position.x, 0.0, "Right thumb should be on -X side")


# ==========================================================================
# Flashlight scene position — source inspection on player.tscn
# ==========================================================================

func test_flashlight_positioned_at_housing_tip() -> void:
	# Read the raw .tscn text so we can inspect the Flashlight transform.
	# The SpotLight3D sits at the tip of the tilted FlashlightBody housing
	# (0, -0.139, -0.074) in Forearm-local space.
	var f: FileAccess = FileAccess.open(
		"res://scenes/player/player.tscn", FileAccess.READ
	)
	assert_not_null(f, "player.tscn should be readable")
	var src: String = f.get_as_text()
	f.close()
	assert_false(
		src.contains("0, -0.125, 0\nvisible = false"),
		"Flashlight should not be at bare wrist position (0, -0.125, 0)",
	)
	assert_true(
		src.contains("-0.139") and src.contains("-0.074"),
		"Flashlight transform should contain tilted housing-tip offsets (-0.139, -0.074)",
	)
