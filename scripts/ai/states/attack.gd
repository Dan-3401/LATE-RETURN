extends ZombieState
## Wind-up, lunge, strike.

var _t := 0.0
var _struck := false


func enter(_msg: Dictionary) -> void:
	_t = 0.0
	_struck = false
	zombie.nav.stop()
	var p := zombie.get_player()
	if p:
		zombie.face_x(p.global_position.x)
	zombie.play(&"attack")
	zombie.vocal(&"zombie_attack", -1.0)


func physics_update(delta: float) -> void:
	zombie.nav.stop()
	_t += delta
	var p := zombie.get_player()
	if not _struck and _t >= zombie.data.attack_windup:
		_struck = true
		zombie.velocity.x = zombie.facing * 60.0
		if p:
			zombie.attack.strike(p)
	if _t >= zombie.data.attack_windup + 0.4:
		if p == null or p.is_dead():
			machine.transition_to(&"Feed")
		else:
			machine.transition_to(&"Chase")


func on_noise(_ev: Dictionary, _i: float) -> void:
	pass


func on_damaged(_source: Node) -> void:
	pass
