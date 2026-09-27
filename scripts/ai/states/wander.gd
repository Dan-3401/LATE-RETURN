extends ZombieState
## Shuffle to a random spot in the area, then pause.

var _x := 0.0


func enter(msg: Dictionary) -> void:
	_x = msg.get("x", zombie.patrol.random_x())
	zombie.play(&"walk")


func physics_update(_delta: float) -> void:
	if calm_vision_check():
		return
	if zombie.nav.move_toward_x(_x, zombie.data.patrol_speed):
		machine.transition_to(&"Idle")
