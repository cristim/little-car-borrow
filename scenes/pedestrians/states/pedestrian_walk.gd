extends "res://src/state_machine/state.gd"
## Walk along sidewalks at ~1.4 m/s. Turn at intersections.

const WALK_SPEED := 1.4
const TURN_CHANCE := 0.3

var _direction := Vector3.FORWARD
var _rng := RandomNumberGenerator.new()
var _walk_timer := 0.0
var _idle_interval := 0.0


func enter(_msg: Dictionary = {}) -> void:
	_rng.randomize()
	if _msg.has("direction"):
		_direction = _msg["direction"]
	_idle_interval = _rng.randf_range(8.0, 20.0)
	_walk_timer = 0.0


func physics_update(delta: float) -> void:
	var ped := owner as CharacterBody3D
	ped.velocity.x = _direction.x * WALK_SPEED
	ped.velocity.z = _direction.z * WALK_SPEED
	ped.velocity.y -= 9.8 * delta
	ped.move_and_slide()

	# Face walk direction (model faces +Z; look_at orients -Z, so negate direction)
	if _direction.length_squared() > 0.01:
		var look_target := ped.global_position - _direction
		look_target.y = ped.global_position.y
		if look_target.distance_to(ped.global_position) > 0.01:
			ped.look_at(look_target, Vector3.UP)

	_walk_timer += delta
	if _walk_timer >= _idle_interval:
		state_machine.transition_to("PedestrianIdle")
