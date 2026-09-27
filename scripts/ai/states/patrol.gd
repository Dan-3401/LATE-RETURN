extends ZombieState
## Slow pacing between two points with random stops.

var _x := 0.0


func enter(msg: Dictionary) -> void:
	_x = msg.get("x", zombie.patrol.next_patrol_x())
	zombie.play(&"walk")


func physics_update(delta: float) -> void:
	if calm_vision_check():
		return
	if randf() < zombie.patrol.midway_stop_chance * delta:
		machine.transition_to(&"Idle", {"duration": randf_range(0.8, 2.0), "then": &"PatrolResume"})
		return
	if zombie.nav.move_toward_x(_x, zombie.data.patrol_speed * randf_range(0.95, 1.05)):
		machine.transition_to(&"Idle")
