extends ZombieState
## Calm down and shuffle back to its usual area.

var _x := 0.0


func enter(_msg: Dictionary) -> void:
	_x = zombie.patrol.home_x + randf_range(-10.0, 10.0)
	zombie.play(&"walk")


func physics_update(_delta: float) -> void:
	if calm_vision_check():
		return
	if zombie.nav.move_toward_x(_x, zombie.data.patrol_speed * 1.2):
		machine.transition_to(&"Idle")
