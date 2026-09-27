class_name PatrolComponent
extends Node
## Calm behaviour configuration: pacing between two points, wandering in an
## area, or lingering in place. Never stands like a post: pauses, looks
## around, drifts.

enum Behavior { PATROL, WANDER, LINGER }

@export var behavior: Behavior = Behavior.PATROL
@export var left := -60.0
@export var right := 60.0
@export var pause_min := 1.2
@export var pause_max := 3.8
## Chance per second to stop mid-walk and look around.
@export var midway_stop_chance := 0.12

var home_x := 0.0
var _toward_right := true


func setup(x: float, facing: int) -> void:
	home_x = x
	_toward_right = facing > 0


func calm_state() -> StringName:
	match behavior:
		Behavior.WANDER: return &"Wander"
		Behavior.LINGER: return &"Idle"
	return &"Patrol"


func next_patrol_x() -> float:
	var x := home_x + (right if _toward_right else left) + randf_range(-8.0, 8.0)
	_toward_right = not _toward_right
	return x


func random_x() -> float:
	return home_x + randf_range(left, right)


func linger_x() -> float:
	return home_x + randf_range(-14.0, 14.0)


func pause_time() -> float:
	return randf_range(pause_min, pause_max)


func clamp_x(x: float) -> float:
	return clampf(x, home_x + left - 40.0, home_x + right + 40.0)
