extends ZombieState
## Walk to where something was seen / heard.

var _pos := Vector2.ZERO
var _fast := false
var _hide_spot: Node2D = null


func enter(msg: Dictionary) -> void:
	_pos = msg.get("pos", zombie.global_position)
	_fast = msg.get("fast", false)
	_hide_spot = msg.get("hide_spot", null)
	zombie.vision.gain_multiplier = 2.2
	zombie.nav.allow_climb = false
	zombie.play(&"run" if _fast else &"walk")


func exit() -> void:
	zombie.vision.gain_multiplier = 1.0


func physics_update(_delta: float) -> void:
	var v := zombie.vision
	if v.suspicion >= 1.0:
		machine.transition_to(&"Alert")
		return
	if v.can_see:
		_pos = zombie.last_seen_pos
	var spd := zombie.data.investigate_speed * (1.9 if _fast else 1.0)
	var target_x := _pos.x
	if _hide_spot and is_instance_valid(_hide_spot):
		target_x = _hide_spot.global_position.x - zombie.facing * 10.0
	if zombie.nav.move_toward_x(target_x, spd, 6.0):
		machine.transition_to(&"Search", {"pos": _pos, "hide_spot": _hide_spot})


func on_noise(ev: Dictionary, _intensity: float) -> void:
	zombie.last_heard_pos = ev.position
	_pos = ev.position
	if ev.kind in LOUD_KINDS and not _fast:
		_fast = true
		zombie.play(&"run")
