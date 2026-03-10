extends GutTest
## Tests for player_model.gd — swimming animation and transitions.

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


# -- Body position --

func test_body_pitches_forward() -> void:
	_parent.is_swimming = true
	_sim(0.016, 60)
	assert_gt(
		_model.rotation.x, 0.5,
		"Body should pitch forward — got %f" % _model.rotation.x,
	)


func test_body_rolls_with_meaningful_amplitude() -> void:
	_parent.is_swimming = true
	var min_z := 0.0
	var max_z := 0.0
	for i in 200:
		_model._process(0.016)
		min_z = minf(min_z, _model.rotation.z)
		max_z = maxf(max_z, _model.rotation.z)
	var range_z := max_z - min_z
	# Should roll at least ~0.2 rad total (~10° each side)
	assert_gt(range_z, 0.2, "Body roll range — got %f" % range_z)


# -- Head stability --

func test_head_counter_rotates_against_body_roll() -> void:
	_parent.is_swimming = true
	_sim(0.016, 100)
	# When body rolls one way, head should counter-rotate
	if absf(_model.rotation.z) > 0.01:
		assert_true(
			sign(_head.rotation.z) != sign(_model.rotation.z),
			"Head Z should oppose body Z — head=%f body=%f" \
				% [_head.rotation.z, _model.rotation.z],
		)


func test_head_rotation_smaller_than_body_roll() -> void:
	_parent.is_swimming = true
	var max_head_z := 0.0
	var max_body_z := 0.0
	for i in 200:
		_model._process(0.016)
		max_head_z = maxf(max_head_z, absf(_head.rotation.z))
		max_body_z = maxf(max_body_z, absf(_model.rotation.z))
	# Net head rotation in world = body_z + head_z, head_z counters ~80%
	# So net head movement should be much smaller than body roll
	assert_gt(max_body_z, max_head_z, "Head Z smaller than body roll")


# -- Arm stroke --

func test_arms_use_all_3_axes() -> void:
	_parent.is_swimming = true
	var mx := 0.0
	var my := 0.0
	var mz := 0.0
	for i in 200:
		_model._process(0.016)
		mx = maxf(mx, absf(_ls.rotation.x))
		my = maxf(my, absf(_ls.rotation.y))
		mz = maxf(mz, absf(_ls.rotation.z))
	assert_gt(mx, 0.1, "Shoulder X active — got %f" % mx)
	assert_gt(my, 0.1, "Shoulder Y active — got %f" % my)
	assert_gt(mz, 0.1, "Shoulder Z active — got %f" % mz)


func test_arm_z_higher_during_recovery_than_pull() -> void:
	_parent.is_swimming = true
	# Track Z when arm is forward (recovery) vs backward (pull)
	var max_z_recovery := 0.0
	var max_z_pull := 0.0
	for i in 200:
		_model._process(0.016)
		# Left arm forward (recovery) = positive shoulder.x relative to base
		if _ls.rotation.x > -PI * 0.3:
			max_z_recovery = maxf(max_z_recovery, absf(_ls.rotation.z))
		else:
			max_z_pull = maxf(max_z_pull, absf(_ls.rotation.z))
	assert_gt(
		max_z_recovery, max_z_pull,
		"Recovery Z should be higher — recovery=%f pull=%f" \
			% [max_z_recovery, max_z_pull],
	)


# -- Catch-up timing --

func test_arms_not_exactly_opposite() -> void:
	_parent.is_swimming = true
	# If arms were exactly 180° apart, they'd always sum to a constant
	# With catch-up timing, the sum varies over time
	var sums: Array[float] = []
	for i in 200:
		_model._process(0.016)
		sums.append(_ls.rotation.x + _rs.rotation.x)
	var min_sum := sums[0]
	var max_sum := sums[0]
	for s in sums:
		min_sum = minf(min_sum, s)
		max_sum = maxf(max_sum, s)
	assert_gt(
		max_sum - min_sum, 0.1,
		"Arm X sum should vary (catch-up) — range=%f" % (max_sum - min_sum),
	)


# -- Elbow articulation --

func test_elbows_articulate_x() -> void:
	_parent.is_swimming = true
	var min_e := 999.0
	var max_e := -999.0
	for i in 200:
		_model._process(0.016)
		min_e = minf(min_e, _le.rotation.x)
		max_e = maxf(max_e, _le.rotation.x)
	assert_gt(max_e - min_e, 0.3, "Elbows articulate X")


func test_elbow_y_s_curve_during_pull() -> void:
	_parent.is_swimming = true
	# Elbow Y should peak mid-pull then return, not stay at max
	var max_y := 0.0
	var had_nonzero := false
	var returned_low := false
	for i in 300:
		_model._process(0.016)
		var ey := absf(_le.rotation.y)
		max_y = maxf(max_y, ey)
		if ey > 0.1:
			had_nonzero = true
		elif had_nonzero and ey < 0.05:
			returned_low = true
	assert_true(had_nonzero, "Elbow Y should peak during pull")
	assert_true(returned_low, "Elbow Y should return low (S-curve)")


# -- 6-beat flutter kick --

func test_kick_faster_than_arms() -> void:
	_parent.is_swimming = true
	# Count zero-crossings of hip rotation (each crossing = half cycle)
	var hip_crossings := 0
	var shoulder_crossings := 0
	var prev_hip := 0.0
	var prev_shoulder := 0.0
	for i in 300:
		_model._process(0.016)
		var hip_x := _lh.rotation.x
		var sh_x := _ls.rotation.x
		if i > 0:
			if sign(hip_x) != sign(prev_hip) and prev_hip != 0.0:
				hip_crossings += 1
			if sign(sh_x) != sign(prev_shoulder) and prev_shoulder != 0.0:
				shoulder_crossings += 1
		prev_hip = hip_x
		prev_shoulder = sh_x
	# 6-beat kick should have ~3x as many zero crossings as arms
	assert_gt(
		hip_crossings, shoulder_crossings * 2,
		"Kick crossings should be >2x arm — kick=%d arm=%d" \
			% [hip_crossings, shoulder_crossings],
	)


func test_knee_bends_on_downkick() -> void:
	_parent.is_swimming = true
	# When left hip is negative (downkick), left knee should bend
	var correct := 0
	var total := 0
	for i in 200:
		_model._process(0.016)
		if absf(_lh.rotation.x) > 0.05:
			total += 1
			# Negative hip = downkick, knee should bend (> 0)
			if _lh.rotation.x < -0.05 and _lk.rotation.x > 0.01:
				correct += 1
			elif _lh.rotation.x > 0.05 and _lk.rotation.x < 0.01:
				correct += 1
	assert_gt(correct, total / 3, "Knee should bend on downkick, not upkick")


func test_flutter_kick_oscillates() -> void:
	_parent.is_swimming = true
	var min_l := 0.0
	var max_l := 0.0
	for i in 200:
		_model._process(0.016)
		min_l = minf(min_l, _lh.rotation.x)
		max_l = maxf(max_l, _lh.rotation.x)
	assert_gt(max_l - min_l, 0.1, "Flutter kick oscillates hips")


func test_kick_left_right_opposition() -> void:
	_parent.is_swimming = true
	var correct := 0
	for i in 200:
		_model._process(0.016)
		if absf(_lh.rotation.x) > 0.05 and absf(_rh.rotation.x) > 0.05:
			if sign(_lh.rotation.x) != sign(_rh.rotation.x):
				correct += 1
	assert_gt(correct, 50, "Left and right kick should be in opposition")


func test_neck_z_counters_body_roll_during_swim() -> void:
	_parent.is_swimming = true
	_sim(0.016, 100)
	if absf(_model.rotation.z) > 0.01:
		assert_true(
			sign(_neck.rotation.z) != sign(_model.rotation.z),
			"Neck Z should oppose body roll — neck=%f body=%f" \
				% [_neck.rotation.z, _model.rotation.z],
		)


func test_breathing_head_turn() -> void:
	_parent.is_swimming = true
	# Head Y should periodically turn for breathing
	var had_turn := false
	for i in 400:
		_model._process(0.016)
		if absf(_head.rotation.y) > 0.1:
			had_turn = true
	assert_true(had_turn, "Head should turn for breathing during swim")


# -- Transitions --

func test_swim_to_idle_body_resets() -> void:
	_parent.is_swimming = true
	_sim(0.016, 60)
	assert_gt(absf(_model.rotation.x), 0.3, "Pre: body tilted")
	_parent.is_swimming = false
	_parent.velocity = Vector3.ZERO
	_sim(0.1, 30)
	assert_almost_eq(_model.rotation.x, 0.0, 0.05, "Pitch resets")
	assert_almost_eq(_model.rotation.z, 0.0, 0.05, "Roll resets")


func test_swim_to_idle_shoulder_yz_resets() -> void:
	_parent.is_swimming = true
	_sim(0.016, 60)
	_parent.is_swimming = false
	_parent.velocity = Vector3.ZERO
	_sim(0.1, 30)
	assert_almost_eq(_ls.rotation.y, 0.0, 0.05, "Shoulder Y resets")
	assert_almost_eq(_ls.rotation.z, 0.0, 0.05, "Shoulder Z resets")


func test_swim_to_idle_head_resets() -> void:
	_parent.is_swimming = true
	_sim(0.016, 60)
	_parent.is_swimming = false
	_parent.velocity = Vector3.ZERO
	_sim(0.1, 30)
	assert_almost_eq(_head.rotation.z, 0.0, 0.05, "Head Z resets")
	assert_almost_eq(_neck.rotation.z, 0.0, 0.05, "Neck Z resets")


func test_swim_to_walk_fast_transition() -> void:
	# Swim to build up body pitch
	_parent.is_swimming = true
	_sim(0.016, 60)
	var pitch_after_swim := _model.rotation.x
	assert_gt(absf(pitch_after_swim), 0.5, "Pre: body heavily tilted")
	# Stop swimming, start walking — should decay quickly
	_parent.is_swimming = false
	_parent.velocity = Vector3(0, 0, 3.0)
	# Only 15 frames at 60fps = 0.25 seconds
	_sim(0.016, 15)
	assert_lt(
		absf(_model.rotation.x), absf(pitch_after_swim) * 0.3,
		"Body should decay >70%% in 0.25s — was %f now %f" \
			% [pitch_after_swim, _model.rotation.x],
	)


func test_run_to_idle_decays() -> void:
	_parent.velocity = Vector3(0, 0, 10.0)
	_sim(0.016, 30)
	_parent.velocity = Vector3.ZERO
	_sim(0.1, 30)
	assert_almost_eq(_ls.rotation.x, 0.0, 0.05, "Shoulder X")
	assert_almost_eq(_ls.rotation.y, 0.0, 0.05, "Shoulder Y")
	assert_almost_eq(_ls.rotation.z, 0.0, 0.05, "Shoulder Z")
	assert_almost_eq(_model.rotation.x, 0.0, 0.05, "Lean")
	assert_almost_eq(_model.rotation.y, 0.0, 0.05, "Twist")
	assert_almost_eq(_model.position.y, 0.0, 0.01, "Bounce")
	assert_almost_eq(_le.rotation.y, 0.0, 0.05, "Elbow Y")
	assert_almost_eq(_head.rotation.z, 0.0, 0.05, "Head Z after run")
	assert_almost_eq(_neck.rotation.y, 0.0, 0.05, "Neck Y after run")
