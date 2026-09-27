extends ZombieState
## The player is down. Close in and feed.

var _x := 0.0
var _eating := false


func enter(_msg: Dictionary) -> void:
	_eating = false
	var p := zombie.get_player()
	var px := p.global_position.x if p else zombie.global_position.x
	var side := signf(zombie.global_position.x - px)
	if side == 0.0:
		side = 1.0
	_x = px + side * randf_range(9.0, 16.0)
	zombie.play(&"run")
	zombie.vision.gain_multiplier = 0.0


func physics_update(_delta: float) -> void:
	if _eating:
		zombie.nav.stop()
		return
	if zombie.nav.move_toward_x(_x, zombie.data.investigate_speed * 1.6, 3.0):
		var p := zombie.get_player()
		if p:
			zombie.face_x(p.global_position.x)
		_eating = true
		zombie.play(&"eat")
		zombie.vocal(&"zombie_eat", -4.0)


func on_noise(_ev: Dictionary, _i: float) -> void:
	pass


func on_damaged(_source: Node) -> void:
	pass
