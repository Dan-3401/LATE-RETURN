class_name GroundNavComponent
extends Node
## Side-view ground movement for AI: walk toward an x, hop over small
## obstacles, optionally climb onto vehicles while chasing.

@export var hop_velocity := -190.0
@export var climb_velocity := -310.0

var body: CharacterBody2D
var allow_climb := false
var _gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var _stuck := 0.0
var _move_dir := 0.0
## Set by halt() on death: no horizontal movement is ever applied again.
var halted := false


func setup(b: CharacterBody2D) -> void:
	body = b


## Returns true when within `tolerance` of x.
func move_toward_x(x: float, speed: float, tolerance: float = 4.0) -> bool:
	if halted:
		return true
	var dx := x - body.global_position.x
	if absf(dx) <= tolerance:
		stop()
		return true
	_move_dir = signf(dx)
	body.velocity.x = _move_dir * speed
	body.set(&"facing", int(_move_dir))
	return false


func stop() -> void:
	_move_dir = 0.0
	body.velocity.x = move_toward(body.velocity.x, 0.0, 30.0)


## Dead bodies: stop now and never move sideways again (gravity only).
func halt() -> void:
	halted = true
	_move_dir = 0.0
	_stuck = 0.0
	body.velocity.x = 0.0


func physics_step(delta: float) -> void:
	if halted:
		# whatever wrote velocity this frame, a corpse does not slide
		body.velocity.x = 0.0
		body.velocity.y = minf(maxf(body.velocity.y, 0.0) + _gravity * delta, 520.0) if not body.is_on_floor() else 0.0
		body.move_and_slide()
		return
	if not body.is_on_floor():
		body.velocity.y = minf(body.velocity.y + _gravity * delta, 520.0)
	var before := body.global_position.x
	body.move_and_slide()
	if _move_dir != 0.0 and body.is_on_floor():
		if absf(body.global_position.x - before) < 0.2:
			_stuck += delta
			var wait := 0.6 if allow_climb else 0.25
			if _stuck > wait:
				_stuck = 0.0
				body.velocity.y = climb_velocity if allow_climb else hop_velocity
				body.velocity.x = _move_dir * 40.0
		else:
			_stuck = 0.0
