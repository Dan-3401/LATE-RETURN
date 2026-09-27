extends ZombieState
## Looks around the spot for a while. If it saw the player hide here it
## lingers at the hiding place, clawing at it — but cannot see inside.

var _pos := Vector2.ZERO
var _t := 0.0
var _step := 0.0
var _x := 0.0
var _hide_spot: Node2D = null
var _bang := 0.0
var _extended := 0.0


func enter(msg: Dictionary) -> void:
	_pos = msg.get("pos", zombie.global_position)
	_hide_spot = msg.get("hide_spot", null)
	_t = zombie.data.search_time * (1.4 if _hide_spot else 1.0)
	_step = 0.0
	_x = zombie.global_position.x
	_bang = 3.5 if _hide_spot else 0.0
	_extended = 0.0
	zombie.vision.gain_multiplier = 2.0
	zombie.play(&"idle")


func exit() -> void:
	zombie.vision.gain_multiplier = 1.0
	if _hide_spot and is_instance_valid(_hide_spot) and _hide_spot.has_method(&"set_disturbed"):
		_hide_spot.call(&"set_disturbed", false)


func physics_update(delta: float) -> void:
	var v := zombie.vision
	if v.suspicion >= 1.0:
		machine.transition_to(&"Alert")
		return
	if v.can_see:
		_pos = zombie.last_seen_pos
		_x = _pos.x
	_t -= delta
	if _t <= 0.0:
		v.suspicion = minf(v.suspicion, 0.15)
		machine.transition_to(&"Return")
		return
	if _bang > 0.0:
		_bang -= delta
		zombie.nav.stop()
		if is_instance_valid(_hide_spot):
			zombie.face_x(_hide_spot.global_position.x)
			if _hide_spot.has_method(&"set_disturbed"):
				_hide_spot.call(&"set_disturbed", true)
		zombie.play(&"bang")
		if _bang <= 0.0 and is_instance_valid(_hide_spot) and _hide_spot.has_method(&"set_disturbed"):
			_hide_spot.call(&"set_disturbed", false)
		return
	_step -= delta
	if _step <= 0.0:
		_step = randf_range(1.2, 2.4)
		if randf() < 0.5:
			zombie.facing = -zombie.facing
			_x = zombie.global_position.x
		else:
			_x = _pos.x + randf_range(-50.0, 50.0)
	if zombie.nav.move_toward_x(_x, zombie.data.investigate_speed * 0.8, 4.0):
		zombie.play(&"idle")
	else:
		zombie.play(&"walk")


func on_noise(ev: Dictionary, _intensity: float) -> void:
	zombie.last_heard_pos = ev.position
	var here: bool = (ev.position as Vector2).distance_to(_pos) < 60.0 or (_hide_spot != null and (ev.position as Vector2).distance_to(_hide_spot.global_position) < 60.0)
	if here and not ev.kind in LOUD_KINDS:
		# something close by (breathing inside the hiding place?): keep at it a bit longer
		zombie.face_x(ev.position.x)
		if _extended < 6.0:
			_t += 2.0
			_extended += 2.0
			if _hide_spot:
				_bang = maxf(_bang, 1.5)
		return
	machine.transition_to(&"Investigate", {"pos": ev.position, "fast": ev.kind in LOUD_KINDS})
