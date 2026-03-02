extends "res://src/state_machine/state.gd"
## Stand still for 2-8 seconds, then return to walking.

var _timer := 0.0
var _duration := 0.0
var _rng := RandomNumberGenerator.new()


func enter(_msg: Dictionary = {}) -> void:
	_rng.randomize()
	_timer = 0.0
	_duration = _rng.randf_range(2.0, 8.0)


func physics_update(delta: float) -> void:
	var ped := owner as CharacterBody3D
	ped.velocity = Vector3(0.0, -9.8 * delta, 0.0)
	ped.move_and_slide()

	_timer += delta
	if _timer >= _duration:
		# Pick a random walk direction along sidewalk
		var directions: Array[Vector3] = [
			Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT,
		]
		var dir := directions[_rng.randi() % directions.size()]
		state_machine.transition_to("PedestrianWalk", {"direction": dir})
