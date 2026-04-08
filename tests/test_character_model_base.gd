extends GutTest
## Tests for src/character_model_base.gd — gait animation helpers shared by
## all humanoid character models.

const ModelScript = preload("res://src/character_model_base.gd")

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

var _model: Node3D
var _ls: Node3D
var _rs: Node3D
var _lh: Node3D
var _rh: Node3D


func before_each() -> void:
	_model = Node3D.new()
	_model.set_script(ModelScript)
	_ls = Node3D.new()
	_ls.name = "LeftShoulder"
	_rs = Node3D.new()
	_rs.name = "RightShoulder"
	_lh = Node3D.new()
	_lh.name = "LeftHip"
	_rh = Node3D.new()
	_rh.name = "RightHip"
	_model.add_child(_ls)
	_model.add_child(_rs)
	_model.add_child(_lh)
	_model.add_child(_rh)
	_model._left_shoulder = _ls
	_model._right_shoulder = _rs
	_model._left_hip = _lh
	_model._right_hip = _rh
	add_child_autofree(_model)


# Advance gait by N steps of `delta` seconds at the given h_speed and blend t.
func _sim_gait(h_speed: float, t: float, delta: float, steps: int) -> void:
	for _i in steps:
		_model._animate_gait(delta, h_speed, t)


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------


func test_walk_amplitude_constant() -> void:
	assert_eq(ModelScript.WALK_AMPLITUDE, 0.22)


func test_run_amplitude_constant() -> void:
	assert_eq(ModelScript.RUN_AMPLITUDE, 0.45)


func test_frequency_constant() -> void:
	assert_eq(ModelScript.FREQUENCY, 8.0)


func test_decay_speed_constant() -> void:
	assert_eq(ModelScript.DECAY_SPEED, 8.0)


func test_run_threshold_constant() -> void:
	assert_eq(ModelScript.RUN_THRESHOLD, 6.0)


func test_walk_lean_constant() -> void:
	assert_eq(ModelScript.WALK_LEAN, 0.03)


func test_run_lean_constant() -> void:
	assert_eq(ModelScript.RUN_LEAN, 0.15)


func test_walk_bounce_constant() -> void:
	assert_eq(ModelScript.WALK_BOUNCE, 0.015)


func test_run_bounce_constant() -> void:
	assert_eq(ModelScript.RUN_BOUNCE, 0.05)


func test_walk_hip_sway_constant() -> void:
	assert_eq(ModelScript.WALK_HIP_SWAY, 0.02)


func test_run_hip_sway_constant() -> void:
	assert_eq(ModelScript.RUN_HIP_SWAY, 0.01)


func test_pelvis_tilt_constant() -> void:
	assert_eq(ModelScript.PELVIS_TILT, 0.04)


func test_torso_twist_constant() -> void:
	assert_eq(ModelScript.TORSO_TWIST, 0.04)


func test_run_torso_twist_constant() -> void:
	assert_eq(ModelScript.RUN_TORSO_TWIST, 0.1)


func test_walk_arm_inward_constant() -> void:
	assert_eq(ModelScript.WALK_ARM_INWARD, 0.06)


func test_run_arm_inward_constant() -> void:
	assert_eq(ModelScript.RUN_ARM_INWARD, 0.15)


func test_arm_z_sway_constant() -> void:
	assert_eq(ModelScript.ARM_Z_SWAY, 0.08)


func test_run_arm_z_sway_constant() -> void:
	assert_eq(ModelScript.RUN_ARM_Z_SWAY, 0.12)


# ---------------------------------------------------------------------------
# Initial state
# ---------------------------------------------------------------------------


func test_phase_starts_at_zero() -> void:
	assert_eq(_model._phase, 0.0)


# ---------------------------------------------------------------------------
# Source code key patterns
# ---------------------------------------------------------------------------


func test_source_contains_warped_phase() -> void:
	var src: String = (ModelScript as GDScript).source_code
	assert_true(src.contains("warped_phase"), "Source should reference 'warped_phase'")


func test_source_contains_sharp_leg() -> void:
	var src: String = (ModelScript as GDScript).source_code
	assert_true(src.contains("sharp_leg"), "Source should reference 'sharp_leg'")


func test_source_contains_arm_bias() -> void:
	var src: String = (ModelScript as GDScript).source_code
	assert_true(src.contains("arm_bias"), "Source should reference 'arm_bias'")


# ---------------------------------------------------------------------------
# _animate_gait — phase advancement
# ---------------------------------------------------------------------------


func test_animate_gait_advances_phase() -> void:
	_model._animate_gait(0.016, 5.0, 0.0)
	assert_gt(_model._phase, 0.0, "_phase should increase after one frame")


func test_animate_gait_phase_proportional_to_speed() -> void:
	var m_slow := Node3D.new()
	m_slow.set_script(ModelScript)
	var ls_s := Node3D.new()
	var rs_s := Node3D.new()
	var lh_s := Node3D.new()
	var rh_s := Node3D.new()
	m_slow.add_child(ls_s)
	m_slow.add_child(rs_s)
	m_slow.add_child(lh_s)
	m_slow.add_child(rh_s)
	m_slow._left_shoulder = ls_s
	m_slow._right_shoulder = rs_s
	m_slow._left_hip = lh_s
	m_slow._right_hip = rh_s
	add_child_autofree(m_slow)

	m_slow._animate_gait(0.016, 2.0, 0.0)
	_model._animate_gait(0.016, 6.0, 0.0)
	assert_gt(
		_model._phase,
		m_slow._phase,
		"Higher speed should advance _phase further per frame",
	)


# ---------------------------------------------------------------------------
# _animate_gait — body transforms
# ---------------------------------------------------------------------------


func test_animate_gait_sets_forward_lean() -> void:
	_sim_gait(5.0, 0.0, 0.016, 30)
	assert_gt(_model.rotation.x, 0.001, "Walk should produce positive forward lean")


func test_animate_gait_sets_position_y() -> void:
	_sim_gait(5.0, 0.0, 0.016, 30)
	assert_gt(absf(_model.position.y), 0.0, "Walk should produce vertical bounce")


func test_animate_gait_sets_position_x() -> void:
	var max_x := 0.0
	for _i in 60:
		_model._animate_gait(0.016, 5.0, 0.0)
		max_x = maxf(max_x, absf(_model.position.x))
	assert_gt(max_x, 0.001, "Walk should produce lateral hip sway")


func test_animate_gait_sets_pelvis_tilt() -> void:
	var max_z := 0.0
	for _i in 60:
		_model._animate_gait(0.016, 5.0, 0.0)
		max_z = maxf(max_z, absf(_model.rotation.z))
	assert_gt(max_z, 0.001, "Walk should produce pelvis tilt (rotation.z)")


func test_animate_gait_sets_torso_twist() -> void:
	var max_y := 0.0
	for _i in 60:
		_model._animate_gait(0.016, 5.0, 0.0)
		max_y = maxf(max_y, absf(_model.rotation.y))
	assert_gt(max_y, 0.001, "Walk should produce torso twist (rotation.y)")


# ---------------------------------------------------------------------------
# _animate_gait — shoulder (arm) rotation
# ---------------------------------------------------------------------------


func test_animate_gait_rotates_left_shoulder_x() -> void:
	_sim_gait(5.0, 0.0, 0.016, 5)
	assert_true(
		absf(_ls.rotation.x) > 0.0,
		"Left shoulder rotation.x should be non-zero after one gait frame",
	)


func test_animate_gait_shoulders_counter_rotate_x() -> void:
	_sim_gait(5.0, 0.0, 0.016, 5)
	# At any non-zero phase the arms are exactly anti-symmetric in their swing
	# component. Both share a forward bias, so compare signs after subtracting bias.
	var bias: float = _model._phase * 0.0  # arm_bias = t * 0.1; t=0 so bias=0
	var l_swing: float = _ls.rotation.x - bias
	var r_swing: float = _rs.rotation.x - bias
	assert_almost_eq(
		l_swing,
		-r_swing,
		0.001,
		"Left/right shoulder swing components should be opposite — L=%f R=%f" % [l_swing, r_swing],
	)


func test_animate_gait_shoulders_have_y_rotation() -> void:
	_sim_gait(5.0, 0.0, 0.016, 10)
	assert_true(
		absf(_ls.rotation.y) > 0.0 or absf(_rs.rotation.y) > 0.0,
		"Shoulders should have Y cross-body rotation",
	)


func test_animate_gait_shoulders_y_are_mirrored() -> void:
	_sim_gait(5.0, 0.0, 0.016, 30)
	assert_almost_eq(
		_ls.rotation.y,
		-_rs.rotation.y,
		0.001,
		"Shoulder Y rotations should be mirrored — L=%f R=%f" % [_ls.rotation.y, _rs.rotation.y],
	)


func test_animate_gait_shoulders_have_z_rotation() -> void:
	var max_z := 0.0
	for _i in 30:
		_model._animate_gait(0.016, 5.0, 0.0)
		max_z = maxf(max_z, absf(_ls.rotation.z))
	assert_gt(max_z, 0.001, "Shoulders should have Z sway rotation")


func test_animate_gait_shoulders_z_are_mirrored() -> void:
	_sim_gait(5.0, 0.0, 0.016, 30)
	assert_almost_eq(
		_ls.rotation.z,
		-_rs.rotation.z,
		0.001,
		"Shoulder Z rotations should be mirrored — L=%f R=%f" % [_ls.rotation.z, _rs.rotation.z],
	)


# ---------------------------------------------------------------------------
# _animate_gait — hip (leg) rotation
# ---------------------------------------------------------------------------


func test_animate_gait_rotates_left_hip_x() -> void:
	_sim_gait(5.0, 0.0, 0.016, 5)
	assert_true(
		absf(_lh.rotation.x) > 0.0,
		"Left hip rotation.x should be non-zero after gait",
	)


func test_animate_gait_hips_counter_rotate_x() -> void:
	_sim_gait(5.0, 0.0, 0.016, 5)
	# hip_bias = t * -0.1 = 0 when t=0; legs are perfectly anti-symmetric
	var avg: float = (_lh.rotation.x + _rh.rotation.x) * 0.5
	var l_swing: float = _lh.rotation.x - avg
	var r_swing: float = _rh.rotation.x - avg
	assert_almost_eq(
		l_swing,
		-r_swing,
		0.001,
		"Left/right hip swing components should be opposite — L=%f R=%f" % [l_swing, r_swing],
	)


# ---------------------------------------------------------------------------
# _animate_gait — run blend increases lean
# ---------------------------------------------------------------------------


func test_run_blend_increases_forward_lean() -> void:
	# Walk blend
	var walk_model := Node3D.new()
	walk_model.set_script(ModelScript)
	var wls := Node3D.new()
	var wrs := Node3D.new()
	var wlh := Node3D.new()
	var wrh := Node3D.new()
	walk_model.add_child(wls)
	walk_model.add_child(wrs)
	walk_model.add_child(wlh)
	walk_model.add_child(wrh)
	walk_model._left_shoulder = wls
	walk_model._right_shoulder = wrs
	walk_model._left_hip = wlh
	walk_model._right_hip = wrh
	add_child_autofree(walk_model)

	for _i in 60:
		walk_model._animate_gait(0.016, 5.0, 0.0)
		_model._animate_gait(0.016, 5.0, 1.0)

	assert_gt(
		_model.rotation.x,
		walk_model.rotation.x,
		"Run blend (t=1) should produce more forward lean than walk blend (t=0)",
	)


# ---------------------------------------------------------------------------
# _animate_gait — head and neck stabilization
# ---------------------------------------------------------------------------


func test_animate_gait_head_set_counters_torso_y() -> void:
	var head := Node3D.new()
	_model._head = head
	_model.add_child(head)
	_sim_gait(5.0, 0.0, 0.016, 60)
	if absf(_model.rotation.y) > 0.001:
		assert_true(
			sign(head.rotation.y) != sign(_model.rotation.y),
			"Head Y should counter torso twist — head=%f body=%f" % [
				head.rotation.y, _model.rotation.y
			],
		)


func test_animate_gait_neck_set_counters_torso_y() -> void:
	var neck := Node3D.new()
	_model._neck = neck
	_model.add_child(neck)
	_sim_gait(5.0, 0.0, 0.016, 60)
	if absf(_model.rotation.y) > 0.001:
		assert_true(
			sign(neck.rotation.y) != sign(_model.rotation.y),
			"Neck Y should counter torso twist — neck=%f body=%f" % [
				neck.rotation.y, _model.rotation.y
			],
		)


func test_animate_gait_null_head_no_crash() -> void:
	# _head is null by default — must not crash
	assert_null(_model._head)
	_sim_gait(5.0, 0.0, 0.016, 5)
	pass_test("_animate_gait with null _head completed without error")


# ---------------------------------------------------------------------------
# _decay_gait — body transforms
# ---------------------------------------------------------------------------


func test_decay_gait_reduces_rotation_x() -> void:
	_model.rotation.x = 0.5
	_model._decay_gait(0.016)
	assert_lt(_model.rotation.x, 0.5, "rotation.x should decay toward 0")


func test_decay_gait_reduces_rotation_y() -> void:
	_model.rotation.y = 0.3
	_model._decay_gait(0.016)
	assert_lt(_model.rotation.y, 0.3, "rotation.y should decay toward 0")


func test_decay_gait_reduces_rotation_z() -> void:
	_model.rotation.z = 0.2
	_model._decay_gait(0.016)
	assert_lt(_model.rotation.z, 0.2, "rotation.z should decay toward 0")


func test_decay_gait_reduces_position_y() -> void:
	_model.position.y = 0.05
	_model._decay_gait(0.016)
	assert_lt(_model.position.y, 0.05, "position.y should decay toward 0")


func test_decay_gait_reduces_position_x() -> void:
	_model.position.x = 0.02
	_model._decay_gait(0.016)
	assert_lt(_model.position.x, 0.02, "position.x should decay toward 0")


# ---------------------------------------------------------------------------
# _decay_gait — shoulder decays
# ---------------------------------------------------------------------------


func test_decay_gait_decays_left_shoulder_x() -> void:
	_ls.rotation.x = 0.4
	_model._decay_gait(0.016)
	assert_lt(_ls.rotation.x, 0.4, "Left shoulder rotation.x should decay toward 0")


func test_decay_gait_decays_right_shoulder_x() -> void:
	_rs.rotation.x = 0.4
	_model._decay_gait(0.016)
	assert_lt(_rs.rotation.x, 0.4, "Right shoulder rotation.x should decay toward 0")


func test_decay_gait_decays_left_shoulder_y() -> void:
	_ls.rotation.y = 0.3
	_model._decay_gait(0.016)
	assert_lt(_ls.rotation.y, 0.3, "Left shoulder rotation.y should decay toward 0")


func test_decay_gait_decays_left_shoulder_z() -> void:
	_ls.rotation.z = 0.2
	_model._decay_gait(0.016)
	assert_lt(_ls.rotation.z, 0.2, "Left shoulder rotation.z should decay toward 0")


# ---------------------------------------------------------------------------
# _decay_gait — hip decays
# ---------------------------------------------------------------------------


func test_decay_gait_decays_left_hip_x() -> void:
	_lh.rotation.x = 0.35
	_model._decay_gait(0.016)
	assert_lt(_lh.rotation.x, 0.35, "Left hip rotation.x should decay toward 0")


func test_decay_gait_decays_right_hip_x() -> void:
	_rh.rotation.x = 0.35
	_model._decay_gait(0.016)
	assert_lt(_rh.rotation.x, 0.35, "Right hip rotation.x should decay toward 0")


# ---------------------------------------------------------------------------
# _decay_gait — optional head / neck
# ---------------------------------------------------------------------------


func test_decay_gait_decays_head_rotation() -> void:
	var head := Node3D.new()
	head.rotation.y = 0.5
	head.rotation.z = 0.3
	_model._head = head
	_model.add_child(head)
	_model._decay_gait(0.016)
	assert_lt(head.rotation.y, 0.5, "Head rotation.y should decay toward 0")
	assert_lt(head.rotation.z, 0.3, "Head rotation.z should decay toward 0")


func test_decay_gait_decays_neck_rotation() -> void:
	var neck := Node3D.new()
	neck.rotation.y = 0.4
	neck.rotation.z = 0.2
	_model._neck = neck
	_model.add_child(neck)
	_model._decay_gait(0.016)
	assert_lt(neck.rotation.y, 0.4, "Neck rotation.y should decay toward 0")
	assert_lt(neck.rotation.z, 0.2, "Neck rotation.z should decay toward 0")


func test_decay_gait_null_head_no_crash() -> void:
	assert_null(_model._head)
	_model.rotation.x = 0.3
	_ls.rotation.x = 0.2
	_model._decay_gait(0.016)
	pass_test("_decay_gait with null _head completed without error")


func test_decay_gait_null_neck_no_crash() -> void:
	assert_null(_model._neck)
	_model.rotation.y = 0.2
	_model._decay_gait(0.016)
	pass_test("_decay_gait with null _neck completed without error")


# ---------------------------------------------------------------------------
# _decay_gait — converges to zero over many frames
# ---------------------------------------------------------------------------


func test_decay_gait_converges_to_zero() -> void:
	_model.rotation.x = 1.0
	_model.rotation.y = 0.5
	_model.rotation.z = 0.3
	_ls.rotation.x = 0.8
	_lh.rotation.x = 0.6
	for _i in 200:
		_model._decay_gait(0.016)
	assert_almost_eq(_model.rotation.x, 0.0, 0.001, "rotation.x should converge to 0")
	assert_almost_eq(_model.rotation.y, 0.0, 0.001, "rotation.y should converge to 0")
	assert_almost_eq(_ls.rotation.x, 0.0, 0.001, "shoulder rotation.x should converge to 0")
	assert_almost_eq(_lh.rotation.x, 0.0, 0.001, "hip rotation.x should converge to 0")
