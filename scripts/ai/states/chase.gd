extends ZombieState
## Full speed pursuit of the visible player. Loses them -> last seen position.

var _lost := 0.0
var _growl := 0.0


func enter(_msg: Dictionary) -> void:
	_lost = 0.0
	_growl = randf_range(1.0, 2.0)
	zombie.nav.allow_climb = true
	zombie.vision.gain_multiplier = 3.0
	zombie.play(&"run")


func exit() -> void:
	zombie.nav.allow_climb = false
	zombie.vision.gain_multiplier = 1.0


func physics_update(delta: float) -> void:
	var p := zombie.get_player()
	if p == null or p.is_dead():
		machine.transition_to(&"Feed")
		return
	if p.is_hidden():
		var spot := p.stealth.hide_spot as Node2D
		if spot and zombie.vision.time_since_seen < zombie.data.lose_sight_time:
			machine.transition_to(&"Investigate", {"pos": spot.global_position, "hide_spot": spot, "fast": true, "from_chase": true})
		else:
			machine.transition_to(&"Investigate", {"pos": zombie.last_seen_pos, "fast": true, "from_chase": true})
		return
	if zombie.vision.can_see:
		_lost = 0.0
	else:
		_lost += delta
		if _lost > zombie.data.lose_sight_time:
			machine.transition_to(&"Investigate", {"pos": zombie.last_seen_pos, "fast": true, "from_chase": true})
			return
	# while it has line of sight it tracks the real position, otherwise the last seen one
	var tx := p.global_position.x if zombie.vision.can_see else zombie.last_seen_pos.x
	if zombie.attack.can_attack(p):
		machine.transition_to(&"Attack")
		return
	zombie.play(&"run")
	zombie.nav.move_toward_x(tx, zombie.data.chase_speed, 3.0)
	_growl -= delta
	if _growl <= 0.0:
		_growl = randf_range(2.0, 3.2)
		zombie.vocal(&"zombie_growl", -2.0)
		NoiseSystem.emit_noise(zombie.global_position, 190.0, zombie, &"growl")


func on_noise(_ev: Dictionary, _i: float) -> void:
	pass


func on_damaged(_source: Node) -> void:
	pass
