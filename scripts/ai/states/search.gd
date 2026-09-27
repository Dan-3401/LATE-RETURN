extends ZombieState
## Searching the area. Plain searches are short and local. When the zombie
## saw the player get into a hiding place (or lost them mid-chase) it becomes
## a long, widening sweep: claw at the hiding place, look left and right,
## drift further out, come back to the spot now and then — never a wall,
## there are always moments to slip away (Hide -> Observe -> Relocate).

var _pos := Vector2.ZERO
var _t := 0.0
var _total := 0.0
var _hide_spot: Node2D = null
var _intense := false
var _bang := 0.0
var _extended := 0.0
var _pause := 0.0
var _x := 0.0
var _next_return := 0.0
var _max_radius := 60.0


func enter(msg: Dictionary) -> void:
	_pos = msg.get("pos", zombie.global_position)
	_hide_spot = msg.get("hide_spot", null)
	_intense = _hide_spot != null or msg.get("from_chase", false)
	var base: float = zombie.data.search_time
	_total = base * (2.8 if _hide_spot else (2.0 if _intense else 1.0))
	_t = _total
	_max_radius = 170.0 if _intense else 70.0
	_bang = 3.0 if _hide_spot else 0.0
	_extended = 0.0
	_pause = 0.6
	_x = zombie.global_position.x
	_next_return = randf_range(5.0, 7.0)
	zombie.vision.gain_multiplier = 2.0
	zombie.play(&"idle")


func exit() -> void:
	zombie.vision.gain_multiplier = 1.0
	_set_disturbed(false)


## Current sweep radius: grows over the search.
func radius() -> float:
	var k := 1.0 - _t / maxf(_total, 0.01)
	return lerpf(35.0, _max_radius, clampf(k * 1.3, 0.0, 1.0))


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
	# clawing at the hiding place
	if _bang > 0.0:
		_bang -= delta
		zombie.nav.stop()
		if is_instance_valid(_hide_spot):
			zombie.face_x(_hide_spot.global_position.x)
			_set_disturbed(true)
		zombie.play(&"bang")
		if _bang <= 0.0:
			_set_disturbed(false)
			_pause = 1.0
		return
	# every so often, go back and check the hiding place again
	if _hide_spot and is_instance_valid(_hide_spot):
		_next_return -= delta
		if _next_return <= 0.0:
			_next_return = randf_range(6.0, 9.0)
			_x = _hide_spot.global_position.x + randf_range(-14.0, 14.0)
	if _pause > 0.0:
		_pause -= delta
		zombie.nav.stop()
		zombie.play(&"idle")
		if _pause <= 0.0:
			_pick_next()
		return
	var arrived := zombie.nav.move_toward_x(_x, zombie.data.investigate_speed * (0.9 if _intense else 0.75), 4.0)
	zombie.play(&"walk")
	if arrived:
		# look left and right
		_pause = randf_range(0.9, 1.8)
		if randf() < 0.6:
			zombie.facing = -zombie.facing


func _pick_next() -> void:
	var r := radius()
	var center := _pos.x
	_x = center + randf_range(-r, r)
	# avoid tiny moves
	if absf(_x - zombie.global_position.x) < 16.0:
		_x = center + signf(randf() - 0.5) * r


func _set_disturbed(on: bool) -> void:
	if _hide_spot and is_instance_valid(_hide_spot) and _hide_spot.has_method(&"set_disturbed"):
		_hide_spot.call(&"set_disturbed", on)


func on_noise(ev: Dictionary, _intensity: float) -> void:
	if ev.kind == &"bottle":
		# it knows the player is around here: a bottle elsewhere won't fool it
		if not _intense:
			bottle_noise(ev)
		return
	zombie.last_heard_pos = ev.position
	var here: bool = (ev.position as Vector2).distance_to(_pos) < 70.0 or (_hide_spot != null and is_instance_valid(_hide_spot) and (ev.position as Vector2).distance_to(_hide_spot.global_position) < 70.0)
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
