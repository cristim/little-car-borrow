extends Node3D
## Procedural walk animation for the articulated player model.
## Reads velocity from the parent CharacterBody3D to drive limb swing.

const WALK_AMPLITUDE := 0.22
const RUN_AMPLITUDE := 0.45
const FREQUENCY := 8.0
const DECAY_SPEED := 8.0
const SWIM_DECAY_SPEED := 16.0     # faster decay leaving water so pose snaps out
const RUN_THRESHOLD := 6.0         # m/s — above this, use run amplitude
const SWIM_FREQUENCY := 3.0
const SWIM_ARM_AMPLITUDE := 1.2
const SWIM_LEG_AMPLITUDE := 0.3
const SWIM_ELBOW_MIN := 0.4        # slightly bent at catch
const SWIM_ELBOW_MAX := 1.5        # ~85° peak pull bend
const SWIM_ELBOW_RECOVERY := 1.4   # bent elbow during recovery (forearm dangles)
const SWIM_ELBOW_Y_AMP := 0.5      # forearm sweeps inward during catch/pull
const SWIM_BODY_PITCH := 1.45      # ~83° from vertical, ~7° from horizontal
const SWIM_BODY_ROLL := 0.45       # ~26° each side
const SWIM_ARM_Y_AMPLITUDE := 0.4
const SWIM_ARM_Z_RECOVERY := 1.0   # high elbow during recovery (above water)
const SWIM_ARM_Z_PULL := 0.1       # arm stays low during pull (underwater)
const SWIM_ARM_OFFSET := PI        # standard opposition timing
const SWIM_KICK_RATIO := 3.0       # 6-beat kick (3x arm frequency)
const ELBOW_RATIO := 0.5
const KNEE_RATIO := 0.7
const KNEE_STANCE_FLEX := 0.12     # slight constant knee bend (~7°)
const WALK_LEAN := 0.03            # slight forward lean when walking (~1.7°)
const RUN_LEAN := 0.15             # forward lean at full sprint (~8°)
const RUN_ELBOW_BASE := -1.2       # ~70° bent arms while running
const WALK_ELBOW_BASE := -0.15     # slight natural bend while walking (~8°)
const RUN_ARM_INWARD := 0.15       # arms pump slightly across body (Y)
const RUN_KNEE_LIFT := 0.5         # extra knee bend on forward swing
const WALK_BOUNCE := 0.015         # vertical bounce when walking (1.5cm)
const RUN_BOUNCE := 0.05           # vertical bounce when running (5cm)
const WALK_ARM_INWARD := 0.06      # subtle cross-body arm swing when walking
const ARM_Z_SWAY := 0.08           # arms sway outward slightly during swing
const RUN_ARM_Z_SWAY := 0.12       # more pronounced sway when running
const TORSO_TWIST := 0.04          # torso Y counter-rotation when walking
const RUN_TORSO_TWIST := 0.1       # stronger torso twist when running
const ELBOW_Y_ANGLE := 0.15        # forearms angle slightly inward
const WALK_HIP_SWAY := 0.02        # lateral weight shift when walking (2cm)
const RUN_HIP_SWAY := 0.01         # less sway when running (1cm)
const PELVIS_TILT := 0.04          # hip drop on swing side (~2.3°)
const FLASH_ELBOW_UP := -0.3       # slight bend when looking up
const FLASH_ELBOW_DOWN := -1.0     # deep bend when looking down
const PITCH_UP := 0.8              # camera max pitch
const PITCH_DOWN := -1.2           # camera min pitch
const DEFAULT_GUN_ELBOW := -0.05   # fallback if weapon data unavailable

var _phase := 0.0
var _was_swimming := false

@onready var _left_shoulder: Node3D = $LeftShoulderPivot
@onready var _right_shoulder: Node3D = $RightShoulderPivot
@onready var _left_hip: Node3D = $LeftHipPivot
@onready var _right_hip: Node3D = $RightHipPivot
@onready var _left_elbow: Node3D = $LeftShoulderPivot/LeftElbowPivot
@onready var _right_elbow: Node3D = $RightShoulderPivot/RightElbowPivot
@onready var _left_knee: Node3D = $LeftHipPivot/LeftKneePivot
@onready var _right_knee: Node3D = $RightHipPivot/RightKneePivot
@onready var _head: Node3D = $Head
@onready var _neck: Node3D = $Neck


func _process(delta: float) -> void:
	var parent := get_parent()
	if not parent:
		return

	# Swimming animation override
	if "is_swimming" in parent and parent.is_swimming:
		_was_swimming = true
		_animate_swimming(delta)
		return

	# Use faster decay when transitioning out of swimming
	var decay: float = SWIM_DECAY_SPEED if _was_swimming else DECAY_SPEED
	if _was_swimming:
		# Check if body rotation has decayed enough to switch to normal speed
		if absf(rotation.x) < 0.1 and absf(rotation.z) < 0.1:
			_was_swimming = false

	# Smoothly reset body tilt/roll/twist/bounce
	if rotation.x != 0.0 or rotation.y != 0.0 or rotation.z != 0.0:
		rotation.x = lerpf(rotation.x, 0.0, delta * decay)
		rotation.y = lerpf(rotation.y, 0.0, delta * decay)
		rotation.z = lerpf(rotation.z, 0.0, delta * decay)
	if position.y != 0.0:
		position.y = lerpf(position.y, 0.0, delta * decay)
	if position.x != 0.0:
		position.x = lerpf(position.x, 0.0, delta * decay)
	# Reset head/neck counter-rotation from swimming
	if _head and _head.rotation.z != 0.0:
		_head.rotation.z = lerpf(_head.rotation.z, 0.0, delta * decay)
	if _head and _head.rotation.y != 0.0:
		_head.rotation.y = lerpf(_head.rotation.y, 0.0, delta * decay)
	if _neck and _neck.rotation.z != 0.0:
		_neck.rotation.z = lerpf(_neck.rotation.z, 0.0, delta * decay)
	if _neck and _neck.rotation.y != 0.0:
		_neck.rotation.y = lerpf(_neck.rotation.y, 0.0, delta * decay)

	var vel: Vector3 = parent.velocity if "velocity" in parent else Vector3.ZERO
	var h_speed := Vector2(vel.x, vel.z).length()

	if h_speed > 0.5:
		_phase += delta * h_speed * FREQUENCY
		var t := clampf(
			(h_speed - 0.5) / (RUN_THRESHOLD - 0.5), 0.0, 1.0
		)
		var amp := lerpf(WALK_AMPLITUDE, RUN_AMPLITUDE, t)
		# Phase warp: stretches stance phase, compresses swing (~60/40 split)
		var warped_phase := _phase + 0.25 * sin(_phase)
		var swing := sin(warped_phase) * amp

		# Forward lean: slight when walking, more when running
		var target_lean := lerpf(WALK_LEAN, RUN_LEAN, t)
		rotation.x = lerpf(rotation.x, target_lean, delta * DECAY_SPEED)

		# Walk bounce: peaks at mid-stance (inverted pendulum model)
		# Run bounce: peaks during flight phase (spring-mass model) — inverted
		var bounce_amp := lerpf(WALK_BOUNCE, RUN_BOUNCE, t)
		var walk_bounce := (0.5 + 0.5 * cos(warped_phase * 2.0)) * bounce_amp
		var run_bounce := (0.5 - 0.5 * cos(warped_phase * 2.0)) * bounce_amp
		position.y = lerpf(walk_bounce, run_bounce, t)

		# Lateral hip sway — weight shifts toward stance leg
		var sway := -sin(warped_phase) * lerpf(WALK_HIP_SWAY, RUN_HIP_SWAY, t)
		position.x = sway

		# Pelvis tilt — hip drops on swing-leg side (positive sin = left forward,
		# so negate: left hip drops when left leg swings forward)
		var tilt := -sin(warped_phase) * lerpf(PELVIS_TILT, PELVIS_TILT * 0.5, t)
		rotation.z = tilt

		# Torso counter-rotation — twists opposite to legs
		var twist := sin(warped_phase) * lerpf(TORSO_TWIST, RUN_TORSO_TWIST, t)
		rotation.y = twist

		# Head/neck stabilization — counters torso twist and pelvis tilt
		if _head:
			_head.rotation.y = -twist * 0.6
			_head.rotation.z = -tilt * 0.7
		if _neck:
			_neck.rotation.y = -twist * 0.3
			_neck.rotation.z = -tilt * 0.3

		# Arms: forward/back swing with forward bias at run speed
		var arm_bias := t * 0.1
		_left_shoulder.rotation.x = swing + arm_bias
		_right_shoulder.rotation.x = -swing + arm_bias

		# Arms sweep inward at mid-swing (90° offset from forward/back)
		var inward_amp := lerpf(WALK_ARM_INWARD, RUN_ARM_INWARD, t)
		var l_inward := cos(warped_phase) * inward_amp
		_left_shoulder.rotation.y = l_inward
		_right_shoulder.rotation.y = -l_inward

		# Arms sway inward on forward swing (Z) — natural cross-body pendulum
		var z_sway := lerpf(ARM_Z_SWAY, RUN_ARM_Z_SWAY, t)
		_left_shoulder.rotation.z = -sin(warped_phase) * z_sway
		_right_shoulder.rotation.z = sin(warped_phase) * z_sway

		# Legs: forward/back swing (hips have slightly less range than arms)
		# At run speed, sharpen the waveform so legs snap through mid-stance
		# faster — creates visual flight phase where both legs are near vertical
		var raw_leg := sin(warped_phase)
		var sharp_leg: float = sign(raw_leg) * pow(absf(raw_leg), lerpf(1.0, 0.6, t))
		var leg_swing: float = sharp_leg * amp * 0.85
		# At run speed, bias hip swing backward (more extension behind body)
		var hip_bias := t * -0.1
		_left_hip.rotation.x = -leg_swing + hip_bias
		_right_hip.rotation.x = leg_swing + hip_bias

		# Elbows: natural bend (walk) to pumped ~70° (run),
		# plus extra bend on forward swing (forearm folds up)
		var elbow_base := lerpf(WALK_ELBOW_BASE, RUN_ELBOW_BASE, t)
		var elbow_dyn := lerpf(0.15, ELBOW_RATIO, t)
		# Forward swing: forearm folds up; backswing: slight extension
		var back_ext := lerpf(0.0, 0.15, t)
		_left_elbow.rotation.x = elbow_base \
			+ maxf(0.0, _left_shoulder.rotation.x) * elbow_dyn \
			+ minf(0.0, _left_shoulder.rotation.x) * back_ext
		_right_elbow.rotation.x = elbow_base \
			+ maxf(0.0, _right_shoulder.rotation.x) * elbow_dyn \
			+ minf(0.0, _right_shoulder.rotation.x) * back_ext

		# Forearms angle slightly inward (natural arm hang)
		var elbow_y := lerpf(ELBOW_Y_ANGLE * 0.5, ELBOW_Y_ANGLE, t)
		_left_elbow.rotation.y = elbow_y
		_right_elbow.rotation.y = -elbow_y

		# Knees: stance flexion + swing-phase lift + terminal extension before strike
		var knee_lift := lerpf(0.0, RUN_KNEE_LIFT, t)
		var leg_amp := amp * 0.85
		var l_swing_t := clampf(-_left_hip.rotation.x / leg_amp, 0.0, 1.0)
		var r_swing_t := clampf(-_right_hip.rotation.x / leg_amp, 0.0, 1.0)
		# Knee bends mid-swing then extends before heel strike (sin curve)
		_left_knee.rotation.x = KNEE_STANCE_FLEX \
			+ sin(l_swing_t * PI) * knee_lift
		_right_knee.rotation.x = KNEE_STANCE_FLEX \
			+ sin(r_swing_t * PI) * knee_lift
	else:
		_left_shoulder.rotation.x = lerpf(
			_left_shoulder.rotation.x, 0.0, delta * DECAY_SPEED
		)
		_left_shoulder.rotation.y = lerpf(
			_left_shoulder.rotation.y, 0.0, delta * DECAY_SPEED
		)
		_left_shoulder.rotation.z = lerpf(
			_left_shoulder.rotation.z, 0.0, delta * DECAY_SPEED
		)
		_right_shoulder.rotation.x = lerpf(
			_right_shoulder.rotation.x, 0.0, delta * DECAY_SPEED
		)
		_right_shoulder.rotation.y = lerpf(
			_right_shoulder.rotation.y, 0.0, delta * DECAY_SPEED
		)
		_right_shoulder.rotation.z = lerpf(
			_right_shoulder.rotation.z, 0.0, delta * DECAY_SPEED
		)
		_left_hip.rotation.x = lerpf(
			_left_hip.rotation.x, 0.0, delta * DECAY_SPEED
		)
		_right_hip.rotation.x = lerpf(
			_right_hip.rotation.x, 0.0, delta * DECAY_SPEED
		)
		_left_elbow.rotation.x = lerpf(
			_left_elbow.rotation.x, 0.0, delta * DECAY_SPEED
		)
		_left_elbow.rotation.y = lerpf(
			_left_elbow.rotation.y, 0.0, delta * DECAY_SPEED
		)
		_right_elbow.rotation.x = lerpf(
			_right_elbow.rotation.x, 0.0, delta * DECAY_SPEED
		)
		_right_elbow.rotation.y = lerpf(
			_right_elbow.rotation.y, 0.0, delta * DECAY_SPEED
		)
		_left_knee.rotation.x = lerpf(
			_left_knee.rotation.x, 0.0, delta * DECAY_SPEED
		)
		_right_knee.rotation.x = lerpf(
			_right_knee.rotation.x, 0.0, delta * DECAY_SPEED
		)
		if _head:
			_head.rotation.y = lerpf(
				_head.rotation.y, 0.0, delta * DECAY_SPEED
			)
			_head.rotation.z = lerpf(
				_head.rotation.z, 0.0, delta * DECAY_SPEED
			)
		if _neck:
			_neck.rotation.y = lerpf(
				_neck.rotation.y, 0.0, delta * DECAY_SPEED
			)
			_neck.rotation.z = lerpf(
				_neck.rotation.z, 0.0, delta * DECAY_SPEED
			)

	# Aim arms at crosshair using camera pitch (skip when hidden, e.g. driving)
	if (parent as Node3D).visible:
		var pitch := _get_camera_pitch()

		if _is_armed():
			_aim_gun_arm(pitch)

		if _is_flashlight_on():
			_aim_flashlight_arm(pitch)


func _aim_gun_arm(pitch: float) -> void:
	var elbow_angle := _get_gun_elbow_angle()
	var total: float = -(PI / 2.0 + pitch)
	_right_shoulder.rotation.x = total - elbow_angle
	_right_elbow.rotation.x = elbow_angle


func _aim_flashlight_arm(pitch: float) -> void:
	var t: float = clampf(
		(pitch - PITCH_UP) / (PITCH_DOWN - PITCH_UP), 0.0, 1.0
	)
	var elbow: float = lerpf(FLASH_ELBOW_UP, FLASH_ELBOW_DOWN, t)
	var total: float = -(PI / 2.0 + pitch)
	_left_shoulder.rotation.x = total - elbow
	_left_elbow.rotation.x = elbow


func _get_gun_elbow_angle() -> float:
	var pw := get_parent().get_node_or_null("PlayerWeapon")
	if pw == null:
		return DEFAULT_GUN_ELBOW
	var w: Dictionary = pw.WEAPONS[pw._current_idx]
	var angle: float = w.get("elbow", DEFAULT_GUN_ELBOW)
	return angle


func _get_camera_pitch() -> float:
	var camera := get_viewport().get_camera_3d()
	if not camera:
		return 0.0
	var fwd: Vector3 = -camera.global_transform.basis.z
	return asin(clampf(fwd.y, -1.0, 1.0))


func _is_armed() -> bool:
	var pw := get_parent().get_node_or_null("PlayerWeapon")
	return pw != null and pw._armed


func _is_flashlight_on() -> bool:
	var fl := _left_elbow.get_node_or_null("Forearm/Flashlight")
	return fl != null and fl.visible


func _animate_swimming(delta: float) -> void:
	_phase += delta * SWIM_FREQUENCY * TAU

	# Body tilt nearly horizontal
	rotation.x = lerpf(rotation.x, SWIM_BODY_PITCH, delta * 4.0)

	# Per-arm phase with opposition timing
	var l_phase := _phase
	var r_phase := _phase + SWIM_ARM_OFFSET

	# Stroke shaping: phase distortion so pull is slower, recovery is faster
	var l_raw := _stroke_shape(l_phase)
	var r_raw := _stroke_shape(r_phase)

	# Body roll driven by both arms: rolls toward the recovering arm
	var roll_target := (sin(l_phase) - sin(r_phase)) * 0.5 * SWIM_BODY_ROLL
	rotation.z = lerpf(rotation.z, roll_target, delta * 6.0)

	# Counter-rotate head and neck to keep them stable
	if _head:
		_head.rotation.z = -rotation.z * 0.8
		# Breathing turn: head rotates to one side every 3rd stroke
		var breath_cycle := fmod(_phase / TAU, 3.0)
		var breath_t := clampf(1.0 - breath_cycle * 3.0, 0.0, 1.0)
		_head.rotation.y = breath_t * 0.5 * sign(rotation.z)
	if _neck:
		_neck.rotation.z = -rotation.z * 0.5
		# Distribute breathing turn through neck too
		if _head:
			_neck.rotation.y = _head.rotation.y * 0.4

	# -- Arm stroke (per arm) --
	_apply_arm_stroke(_left_shoulder, _left_elbow, l_raw, 1.0)
	_apply_arm_stroke(_right_shoulder, _right_elbow, r_raw, -1.0)

	# -- 6-beat flutter kick (3x arm stroke frequency) --
	var kick_phase := _phase * SWIM_KICK_RATIO
	# Amplitude modulation: every 3rd kick (synced with arm entry) is stronger
	var major_beat := 0.5 + 0.5 * cos(kick_phase * (2.0 / SWIM_KICK_RATIO))
	var kick_amp := SWIM_LEG_AMPLITUDE * (0.6 + 0.4 * major_beat)
	var kick := sin(kick_phase) * kick_amp
	# Modulate kick amplitude by body roll: leg on rolling-toward side kicks harder
	var roll_mod := clampf(rotation.z / SWIM_BODY_ROLL, -1.0, 1.0)
	_left_hip.rotation.x = kick * (1.0 + roll_mod * 0.3)
	_right_hip.rotation.x = -kick * (1.0 - roll_mod * 0.3)
	# Knees bend on downkick (power phase), straight on upkick
	_left_knee.rotation.x = maxf(0.0, -kick) * 0.5
	_right_knee.rotation.x = maxf(0.0, kick) * 0.5


## Asymmetric stroke: second harmonic breaks half-cycle symmetry so pull is
## slower/longer and recovery is faster/snappier (real catch-up timing).
static func _stroke_shape(phase: float) -> float:
	var warped := phase + 0.3 * sin(phase) + 0.15 * sin(2.0 * phase)
	return sin(warped)


## Apply a single arm's freestyle stroke to shoulder and elbow.
## sign_f is 1.0 for left arm, -1.0 for right arm (mirrors Y and Z).
func _apply_arm_stroke(
	shoulder: Node3D,
	elbow: Node3D,
	stroke: float,
	sign_f: float,
) -> void:
	var swing := stroke * SWIM_ARM_AMPLITUDE

	# Pull factor: 0 at recovery, 1 at max pull
	var pull_t := clampf(-stroke, 0.0, 1.0)
	# Recovery factor: 0 during pull, 1 at max recovery
	var recovery_t := clampf(stroke, 0.0, 1.0)
	# Entry moment: peaks at the transition from recovery to pull
	var entry_t := recovery_t * (1.0 - recovery_t) * 4.0

	# X: forward/back with more overhead reach and entry dip (fingertip-first)
	shoulder.rotation.x = -PI * 0.4 + swing - entry_t * 0.25

	# Y: arm reaches outward during recovery, sweeps inward during pull
	shoulder.rotation.y = sign_f * (
		recovery_t * SWIM_ARM_Y_AMPLITUDE - pull_t * SWIM_ARM_Y_AMPLITUDE * 0.3
	)

	# Z: high elbow during recovery (above water), low during pull (underwater)
	var z_lift := recovery_t * SWIM_ARM_Z_RECOVERY - pull_t * SWIM_ARM_Z_PULL
	shoulder.rotation.z = -sign_f * z_lift

	# Elbow X: bent during recovery, extends at catch, bends during pull.
	# Separate branches avoid unwanted re-bend at the catch-to-pull transition.
	var elbow_bend: float
	if recovery_t > pull_t:
		# Recovery phase: starts bent (forearm dangles at hip exit) → extends to catch
		elbow_bend = lerpf(SWIM_ELBOW_RECOVERY, SWIM_ELBOW_MIN, recovery_t)
	else:
		# Pull phase: starts extended at catch, bends progressively
		elbow_bend = lerpf(SWIM_ELBOW_MIN, SWIM_ELBOW_MAX, pull_t)
	elbow.rotation.x = clampf(elbow_bend, SWIM_ELBOW_MIN, SWIM_ELBOW_MAX)

	# Elbow Y: forearm sweeps inward during catch (S-curve pull path)
	var s_curve := sin(pull_t * PI)
	elbow.rotation.y = sign_f * s_curve * SWIM_ELBOW_Y_AMP
