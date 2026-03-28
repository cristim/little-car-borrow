extends "res://src/state_machine/state.gd"
## Run away from a threat (vehicle) at 4 m/s.
## Returns to Walk after 5s or when threat is >20m away.

const FLEE_SPEED := 4.0
const FLEE_DURATION := 5.0
const SAFE_DISTANCE := 20.0

var _flee_direction := Vector3.FORWARD
var _threat_pos := Vector3.ZERO
var _timer := 0.0


func enter(msg: Dictionary = {}) -> void:
	_timer = 0.0
	_threat_pos = msg.get("threat_pos", owner.global_position) as Vector3
	var away: Vector3 = owner.global_position - _threat_pos
	away.y = 0.0
	if away.length_squared() > 0.01:
		_flee_direction = away.normalized()
	else:
		_flee_direction = Vector3.FORWARD


func physics_update(delta: float) -> void:
	var ped := owner as CharacterBody3D
	ped.velocity.x = _flee_direction.x * FLEE_SPEED
	ped.velocity.z = _flee_direction.z * FLEE_SPEED
	ped.velocity.y -= 9.8 * delta
	ped.move_and_slide()

	# Face away from threat
	# Model faces +Z; look_at orients -Z, so negate to make face point forward
	var look_target := ped.global_position - _flee_direction
	look_target.y = ped.global_position.y
	if look_target.distance_to(ped.global_position) > 0.01:
		ped.look_at(look_target, Vector3.UP)

	_timer += delta
	var dist := ped.global_position.distance_to(_threat_pos)
	if _timer >= FLEE_DURATION or dist >= SAFE_DISTANCE:
		state_machine.transition_to("PedestrianWalk", {"direction": _flee_direction})
