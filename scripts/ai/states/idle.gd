extends ZombieState
## Standing still, swaying, now and then turning to look around.

var _t := 0.0
var _turn := 0.0
var _then: StringName = &""


func enter(msg: Dictionary) -> void:
	zombie.nav.stop()
	zombie.play(&"idle")
	_t = msg.get("duration", zombie.patrol.pause_time())
	_then = msg.get("then", &"")
	_turn = randf_range(1.0, 2.5)


func physics_update(delta: float) -> void:
	zombie.nav.stop()
	if calm_vision_check():
		return
	_t -= delta
	_turn -= delta
	if _turn <= 0.0:
		_turn = randf_range(1.2, 3.0)
		if randf() < 0.45:
			zombie.facing = -zombie.facing
	if _t <= 0.0:
		if zombie.patrol.behavior == PatrolComponent.Behavior.LINGER:
			# drift a little, then idle again
			machine.transition_to(&"Wander", {"x": zombie.patrol.linger_x()})
		elif _then != &"":
			machine.transition_to(_then)
		else:
			resume_calm()
