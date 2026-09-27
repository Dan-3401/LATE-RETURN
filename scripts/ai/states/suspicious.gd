extends ZombieState
## Something caught its attention: stop, turn toward it, wait.

var _pos := Vector2.ZERO
var _t := 0.0
var _hits := 0


func enter(msg: Dictionary) -> void:
	_pos = msg.get("pos", zombie.global_position)
	_t = 1.8
	_hits = 1
	zombie.nav.stop()
	zombie.face_x(_pos.x)
	zombie.play(&"idle")
	zombie.vision.gain_multiplier = 1.6
	zombie.vocal(&"zombie_growl", -10.0)


func exit() -> void:
	zombie.vision.gain_multiplier = 1.0


func physics_update(delta: float) -> void:
	zombie.nav.stop()
	var v := zombie.vision
	if v.suspicion >= 1.0:
		machine.transition_to(&"Alert")
		return
	if v.can_see:
		_pos = zombie.last_seen_pos
		zombie.face_x(_pos.x)
	_t -= delta
	if _t <= 0.0:
		if v.suspicion > 0.45 or _hits >= 2:
			machine.transition_to(&"Investigate", {"pos": _pos})
		else:
			resume_calm()


func on_noise(ev: Dictionary, intensity: float) -> void:
	if bottle_noise(ev):
		return
	if ev.kind in LOUD_KINDS:
		machine.transition_to(&"Investigate", {"pos": ev.position, "fast": true})
		return
	_hits += 1
	_pos = ev.position
	zombie.face_x(_pos.x)
	if _hits >= 2 or intensity > 0.5:
		machine.transition_to(&"Investigate", {"pos": _pos})
