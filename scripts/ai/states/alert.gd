extends ZombieState
## Spotted! Freeze, turn, and let out a roar that draws the others.

var _roared := false
var _t := 0.0


func enter(_msg: Dictionary) -> void:
	zombie.nav.stop()
	zombie.face_x(zombie.last_seen_pos.x)
	zombie.vision.suspicion = maxf(zombie.vision.suspicion, 1.0)
	_roared = false
	_t = 0.0
	# a zombie that roared recently goes straight for the chase
	if zombie.roar_cooldown > 0.0:
		zombie.vocal(&"zombie_alert", -2.0)
		machine.transition_to(&"Chase")
		return
	zombie.play(&"alert")


func physics_update(delta: float) -> void:
	zombie.nav.stop()
	_t += delta
	if not _roared and _t >= 0.35:
		_roared = true
		zombie.roar()
	if _t >= 1.0:
		machine.transition_to(&"Chase")


func on_noise(_ev: Dictionary, _i: float) -> void:
	pass


func on_damaged(_source: Node) -> void:
	pass
