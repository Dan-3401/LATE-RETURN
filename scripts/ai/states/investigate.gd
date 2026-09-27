extends ZombieState
## Walk to where something was seen / heard.

var _pos := Vector2.ZERO
var _fast := false
var _sprint := false
var _from_chase := false
var _startle := 0.0
var _hide_spot: Node2D = null


func enter(msg: Dictionary) -> void:
	_pos = msg.get("pos", zombie.global_position)
	_fast = msg.get("fast", false)
	_sprint = msg.get("sprint", false)
	_from_chase = msg.get("from_chase", false)
	_startle = msg.get("startle", 0.0)
	_hide_spot = msg.get("hide_spot", null)
	zombie.vision.gain_multiplier = 2.2
	zombie.nav.allow_climb = false
	if _startle > 0.0:
		# jerk toward the sound, freeze for a heartbeat
		zombie.nav.stop()
		zombie.face_x(_pos.x)
		zombie.play(&"idle")
		zombie.vocal(&"zombie_alert", -6.0)
	else:
		zombie.play(&"run" if (_fast or _sprint) else &"walk")


func exit() -> void:
	zombie.vision.gain_multiplier = 1.0


func physics_update(delta: float) -> void:
	var v := zombie.vision
	if _startle > 0.0:
		_startle -= delta
		zombie.nav.stop()
		if v.suspicion >= 1.0:
			machine.transition_to(&"Alert")
		elif _startle <= 0.0:
			zombie.play(&"run")
		return
	if v.suspicion >= 1.0:
		machine.transition_to(&"Alert")
		return
	if v.can_see:
		_pos = zombie.last_seen_pos
	var spd := zombie.data.investigate_speed * (1.9 if _fast else 1.0)
	if _sprint:
		spd = zombie.data.chase_speed * 0.85
	var target_x := _pos.x
	if _hide_spot and is_instance_valid(_hide_spot):
		target_x = _hide_spot.global_position.x - zombie.facing * 10.0
	if zombie.nav.move_toward_x(target_x, spd, 6.0):
		machine.transition_to(&"Search", {"pos": _pos, "hide_spot": _hide_spot, "from_chase": _from_chase})


func on_noise(ev: Dictionary, _intensity: float) -> void:
	# heading to where it last saw the player: a bottle does not distract it
	if ev.kind == &"bottle":
		if _from_chase or _hide_spot or (zombie.vision.can_see and zombie.vision.suspicion >= 0.3):
			return
		_pos = ev.position
		_sprint = true
		zombie.play(&"run")
		return
	zombie.last_heard_pos = ev.position
	_pos = ev.position
	if ev.kind in LOUD_KINDS and not _fast:
		_fast = true
		zombie.play(&"run")
