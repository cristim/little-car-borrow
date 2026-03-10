extends GutTest
## Tests for player_model.gd — walking, idle, and symmetry.

const PlayerModelScript = preload("res://scenes/player/player_model.gd")

var _model: Node3D
var _parent: CharacterBody3D
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
	_parent = CharacterBody3D.new()
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


# -- Idle --

func test_idle_joints_near_zero() -> void:
	_parent.velocity = Vector3.ZERO
	_sim(0.1, 10)
	assert_almost_eq(_ls.rotation.x, 0.0, 0.01, "shoulder X")
	assert_almost_eq(_ls.rotation.y, 0.0, 0.01, "shoulder Y")
	assert_almost_eq(_ls.rotation.z, 0.0, 0.01, "shoulder Z")
	assert_almost_eq(_model.rotation.x, 0.0, 0.01, "body pitch")
	assert_almost_eq(_model.rotation.y, 0.0, 0.01, "body twist")


# -- Walk: multi-axis motion --

func test_walk_arms_swing_opposite() -> void:
	_parent.velocity = Vector3(0, 0, 3.0)
	_sim(0.016, 30)
	# Arms swing in opposition (one forward, one back) but with a shared
	# forward bias at higher speeds — check that the swing components oppose
	var avg := (_ls.rotation.x + _rs.rotation.x) * 0.5
	var l_swing := _ls.rotation.x - avg
	var r_swing := _rs.rotation.x - avg
	assert_almost_eq(
		l_swing, -r_swing, 0.01,
		"Arm swing components opposite — L=%f R=%f" % [l_swing, r_swing],
	)


func test_walk_arms_have_y_rotation() -> void:
	_parent.velocity = Vector3(0, 0, 3.0)
	_sim(0.016, 30)
	assert_true(
		absf(_ls.rotation.y) > 0.001 or absf(_rs.rotation.y) > 0.001,
		"Arms should have Y rotation (cross-body)",
	)


func test_walk_arms_have_z_rotation() -> void:
	_parent.velocity = Vector3(0, 0, 3.0)
	_sim(0.016, 30)
	assert_true(
		absf(_ls.rotation.z) > 0.001 or absf(_rs.rotation.z) > 0.001,
		"Arms should have Z rotation (sway)",
	)


func test_walk_legs_swing_opposite() -> void:
	_parent.velocity = Vector3(0, 0, 3.0)
	_sim(0.016, 30)
	# Legs swing in opposition but share a backward bias at higher speeds
	var avg := (_lh.rotation.x + _rh.rotation.x) * 0.5
	var l_swing := _lh.rotation.x - avg
	var r_swing := _rh.rotation.x - avg
	assert_almost_eq(
		l_swing, -r_swing, 0.01,
		"Leg swing components opposite — L=%f R=%f" % [l_swing, r_swing],
	)


func test_walk_torso_twists() -> void:
	_parent.velocity = Vector3(0, 0, 3.0)
	_sim(0.016, 30)
	assert_true(
		absf(_model.rotation.y) > 0.001,
		"Torso should twist — got %f" % _model.rotation.y,
	)


func test_walk_elbow_y_set() -> void:
	_parent.velocity = Vector3(0, 0, 3.0)
	_sim(0.016, 30)
	assert_true(absf(_le.rotation.y) > 0.001, "Left elbow Y")
	assert_true(absf(_re.rotation.y) > 0.001, "Right elbow Y")


# -- Walk: symmetry --

func test_walk_arms_mirrored_y() -> void:
	_parent.velocity = Vector3(0, 0, 3.0)
	_sim(0.016, 30)
	assert_almost_eq(
		_ls.rotation.y, -_rs.rotation.y, 0.001,
		"Arm Y mirrored — L=%f R=%f" % [_ls.rotation.y, _rs.rotation.y],
	)


func test_walk_arms_mirrored_z() -> void:
	_parent.velocity = Vector3(0, 0, 3.0)
	_sim(0.016, 30)
	assert_almost_eq(
		_ls.rotation.z, -_rs.rotation.z, 0.001,
		"Arm Z mirrored — L=%f R=%f" % [_ls.rotation.z, _rs.rotation.z],
	)


func test_walk_elbows_mirrored_y() -> void:
	_parent.velocity = Vector3(0, 0, 3.0)
	_sim(0.016, 30)
	assert_almost_eq(
		_le.rotation.y, -_re.rotation.y, 0.001,
		"Elbow Y mirrored — L=%f R=%f" % [_le.rotation.y, _re.rotation.y],
	)


# -- Walk: new features --

func test_walk_has_lateral_hip_sway() -> void:
	_parent.velocity = Vector3(0, 0, 3.0)
	var max_x := 0.0
	for i in 60:
		_model._process(0.016)
		max_x = maxf(max_x, absf(_model.position.x))
	assert_gt(max_x, 0.001, "Should have lateral hip sway — got %f" % max_x)


func test_walk_has_pelvis_tilt() -> void:
	_parent.velocity = Vector3(0, 0, 3.0)
	var max_z := 0.0
	for i in 60:
		_model._process(0.016)
		max_z = maxf(max_z, absf(_model.rotation.z))
	assert_gt(max_z, 0.001, "Should have pelvis tilt — got %f" % max_z)


func test_walk_has_forward_lean() -> void:
	_parent.velocity = Vector3(0, 0, 3.0)
	_sim(0.016, 60)
	assert_gt(
		_model.rotation.x, 0.01,
		"Walk should have slight forward lean — got %f" % _model.rotation.x,
	)


func test_walk_bounce_peaks_at_mid_stance() -> void:
	_parent.velocity = Vector3(0, 0, 3.0)
	# Collect bounce at max leg spread vs legs crossing vertical
	var bounce_at_spread := 0.0
	var bounce_at_vertical := 0.0
	for i in 120:
		_model._process(0.016)
		var leg_spread := absf(_lh.rotation.x)
		if leg_spread > 0.1:
			bounce_at_spread = maxf(bounce_at_spread, _model.position.y)
		elif leg_spread < 0.02:
			bounce_at_vertical = maxf(bounce_at_vertical, _model.position.y)
	assert_gt(
		bounce_at_vertical, bounce_at_spread,
		"Bounce should peak at mid-stance — vert=%f spread=%f" \
			% [bounce_at_vertical, bounce_at_spread],
	)


func test_walk_hip_sway_toward_stance_leg() -> void:
	_parent.velocity = Vector3(0, 0, 3.0)
	# When left leg is back (stance), body should shift left (negative X)
	# Left leg back = _lh.rotation.x > 0 (positive = forward, so back = negative)
	# Actually: _left_hip.rotation.x = -leg_swing, so when swing>0, left hip<0 = back = stance
	var sway_with_left_stance := 0.0
	var sway_with_right_stance := 0.0
	for i in 120:
		_model._process(0.016)
		if _lh.rotation.x < -0.05:
			sway_with_left_stance = _model.position.x
		elif _lh.rotation.x > 0.05:
			sway_with_right_stance = _model.position.x
	# Left back (stance) → sway should be negative (toward left)
	assert_lt(
		sway_with_left_stance, sway_with_right_stance,
		"Sway toward stance leg — left=%f right=%f" \
			% [sway_with_left_stance, sway_with_right_stance],
	)


func test_walk_head_counters_pelvis_tilt() -> void:
	_parent.velocity = Vector3(0, 0, 3.0)
	_sim(0.016, 60)
	if absf(_model.rotation.z) > 0.001:
		assert_true(
			sign(_head.rotation.z) != sign(_model.rotation.z),
			"Head Z should oppose pelvis Z — head=%f body=%f" \
				% [_head.rotation.z, _model.rotation.z],
		)


func test_walk_neck_counters_torso_twist() -> void:
	_parent.velocity = Vector3(0, 0, 3.0)
	_sim(0.016, 60)
	if absf(_model.rotation.y) > 0.001:
		assert_true(
			sign(_neck.rotation.y) != sign(_model.rotation.y),
			"Neck Y should oppose torso Y — neck=%f body=%f" \
				% [_neck.rotation.y, _model.rotation.y],
		)


func test_walk_neck_counters_pelvis_tilt() -> void:
	_parent.velocity = Vector3(0, 0, 3.0)
	_sim(0.016, 60)
	if absf(_model.rotation.z) > 0.001:
		assert_true(
			sign(_neck.rotation.z) != sign(_model.rotation.z),
			"Neck Z should oppose pelvis Z — neck=%f body=%f" \
				% [_neck.rotation.z, _model.rotation.z],
		)


func test_walk_contralateral_coordination() -> void:
	_parent.velocity = Vector3(0, 0, 3.0)
	_sim(0.016, 30)
	# Left arm forward should coincide with right leg forward
	# Left arm X > 0 = forward, right hip X > 0 = forward (because swing is negated)
	# Actually: _right_hip.rotation.x = leg_swing (positive when swing>0)
	# So when left arm forward (ls.x > 0), right hip should be positive too
	assert_true(
		sign(_ls.rotation.x) == sign(_rh.rotation.x),
		"Left arm and right leg should swing together — arm=%f leg=%f" \
			% [_ls.rotation.x, _rh.rotation.x],
	)


func test_walk_head_counters_torso_twist_y() -> void:
	_parent.velocity = Vector3(0, 0, 3.0)
	_sim(0.016, 60)
	if absf(_model.rotation.y) > 0.001:
		assert_true(
			sign(_head.rotation.y) != sign(_model.rotation.y),
			"Head Y should oppose torso Y — head=%f body=%f" \
				% [_head.rotation.y, _model.rotation.y],
		)
