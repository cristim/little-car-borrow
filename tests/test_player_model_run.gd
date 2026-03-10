extends GutTest
## Tests for player_model.gd — running animation.

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


func test_forward_lean() -> void:
	_parent.velocity = Vector3(0, 0, 10.0)
	_sim(0.016, 30)
	assert_gt(
		_model.rotation.x, 0.01,
		"Body should lean forward — got %f" % _model.rotation.x,
	)


func test_vertical_bounce_non_negative() -> void:
	_parent.velocity = Vector3(0, 0, 10.0)
	_sim(0.016, 30)
	assert_gte(
		_model.position.y, 0.0,
		"Bounce should be >= 0 — got %f" % _model.position.y,
	)


func test_arms_more_bent_than_walk() -> void:
	_parent.velocity = Vector3(0, 0, 3.0)
	_sim(0.016, 30)
	var walk_elbow := _le.rotation.x
	_parent.velocity = Vector3.ZERO
	_sim(0.1, 20)
	_parent.velocity = Vector3(0, 0, 10.0)
	_sim(0.016, 30)
	assert_lt(
		_le.rotation.x, walk_elbow,
		"Run elbows more bent — run=%f walk=%f" % [_le.rotation.x, walk_elbow],
	)


func test_stronger_torso_twist_than_walk() -> void:
	_parent.velocity = Vector3(0, 0, 3.0)
	var walk_max := 0.0
	for i in 60:
		_model._process(0.016)
		walk_max = maxf(walk_max, absf(_model.rotation.y))
	_parent.velocity = Vector3.ZERO
	_sim(0.1, 20)
	_parent.velocity = Vector3(0, 0, 10.0)
	var run_max := 0.0
	for i in 60:
		_model._process(0.016)
		run_max = maxf(run_max, absf(_model.rotation.y))
	assert_gt(
		run_max, walk_max,
		"Run twist > walk — run=%f walk=%f" % [run_max, walk_max],
	)


func test_arm_z_sway_larger_than_walk() -> void:
	_parent.velocity = Vector3(0, 0, 3.0)
	var walk_z := 0.0
	for i in 60:
		_model._process(0.016)
		walk_z = maxf(walk_z, absf(_ls.rotation.z))
	_parent.velocity = Vector3.ZERO
	_sim(0.1, 20)
	_parent.velocity = Vector3(0, 0, 10.0)
	var run_z := 0.0
	for i in 60:
		_model._process(0.016)
		run_z = maxf(run_z, absf(_ls.rotation.z))
	assert_gt(
		run_z, walk_z,
		"Run Z sway > walk — run=%f walk=%f" % [run_z, walk_z],
	)


func test_knee_lift_on_forward_swing() -> void:
	_parent.velocity = Vector3(0, 0, 10.0)
	var max_knee := 0.0
	for i in 60:
		_model._process(0.016)
		max_knee = maxf(max_knee, _lk.rotation.x)
	assert_gt(max_knee, 0.1, "Knee lift — got %f" % max_knee)


func test_knee_extends_before_heel_strike() -> void:
	_parent.velocity = Vector3(0, 0, 10.0)
	# Track knee bend: it should peak mid-swing then drop toward stance flex
	var had_high := false
	var returned_low := false
	for i in 120:
		_model._process(0.016)
		var knee := _lk.rotation.x
		if knee > 0.2:
			had_high = true
		elif had_high and knee < 0.15:
			returned_low = true
	assert_true(had_high, "Knee should lift during swing")
	assert_true(returned_low, "Knee should extend before heel strike")


func test_run_bounce_larger_than_walk() -> void:
	_parent.velocity = Vector3(0, 0, 3.0)
	var walk_max := 0.0
	for i in 60:
		_model._process(0.016)
		walk_max = maxf(walk_max, _model.position.y)
	_parent.velocity = Vector3.ZERO
	_sim(0.1, 20)
	_parent.velocity = Vector3(0, 0, 10.0)
	var run_max := 0.0
	for i in 60:
		_model._process(0.016)
		run_max = maxf(run_max, _model.position.y)
	assert_gt(
		run_max, walk_max,
		"Run bounce > walk — run=%f walk=%f" % [run_max, walk_max],
	)


func test_run_arms_bias_forward() -> void:
	_parent.velocity = Vector3(0, 0, 10.0)
	# Average of both arms should be positive (biased forward)
	var sum := 0.0
	for i in 60:
		_model._process(0.016)
		sum += _ls.rotation.x + _rs.rotation.x
	assert_gt(sum / 60.0, 0.01, "Arms should bias forward at run speed")


func test_run_legs_bias_backward() -> void:
	_parent.velocity = Vector3(0, 0, 10.0)
	# Average of both hips should be negative (biased backward for toe-off)
	var sum := 0.0
	for i in 60:
		_model._process(0.016)
		sum += _lh.rotation.x + _rh.rotation.x
	assert_lt(sum / 60.0, -0.01, "Hips should bias backward at run speed")


func test_run_hip_range_larger_than_walk() -> void:
	_parent.velocity = Vector3(0, 0, 3.0)
	var walk_range := 0.0
	var walk_min := 999.0
	var walk_max := -999.0
	for i in 120:
		_model._process(0.016)
		walk_min = minf(walk_min, _lh.rotation.x)
		walk_max = maxf(walk_max, _lh.rotation.x)
	walk_range = walk_max - walk_min
	_parent.velocity = Vector3.ZERO
	_sim(0.1, 20)
	_parent.velocity = Vector3(0, 0, 10.0)
	var run_min := 999.0
	var run_max := -999.0
	for i in 120:
		_model._process(0.016)
		run_min = minf(run_min, _lh.rotation.x)
		run_max = maxf(run_max, _lh.rotation.x)
	var run_range := run_max - run_min
	assert_gt(
		run_range, walk_range,
		"Run hip range > walk — run=%f walk=%f" % [run_range, walk_range],
	)


func test_run_head_counters_torso_twist() -> void:
	_parent.velocity = Vector3(0, 0, 10.0)
	_sim(0.016, 60)
	if absf(_model.rotation.y) > 0.001:
		assert_true(
			sign(_head.rotation.y) != sign(_model.rotation.y),
			"Head Y should oppose torso Y — head=%f body=%f" \
				% [_head.rotation.y, _model.rotation.y],
		)
