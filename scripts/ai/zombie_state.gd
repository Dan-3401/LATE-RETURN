class_name ZombieState
extends Node
## Base class for zombie states. Shared helpers implement the common
## "calm" reactions (see / hear something) so each state stays small.

const LOUD_KINDS := [&"gunshot", &"roar", &"growl", &"impact"]

var zombie: Zombie
var machine: StateMachine


func enter(_msg: Dictionary) -> void:
	pass


func exit() -> void:
	pass


func physics_update(_delta: float) -> void:
	pass


func on_noise(ev: Dictionary, intensity: float) -> void:
	calm_noise(ev, intensity)


func on_damaged(source: Node) -> void:
	if source is Node2D:
		zombie.last_seen_pos = (source as Node2D).global_position
		zombie.face_x(zombie.last_seen_pos.x)
	machine.transition_to(&"Alert")


# --- shared reactions ---------------------------------------------------------
## For calm states. Returns true if a transition happened.
func calm_vision_check() -> bool:
	var v := zombie.vision
	if v.suspicion >= 1.0:
		machine.transition_to(&"Alert")
		return true
	if v.can_see and v.suspicion >= 0.3:
		machine.transition_to(&"Suspicious", {"pos": zombie.last_seen_pos})
		return true
	return false


func calm_noise(ev: Dictionary, intensity: float) -> void:
	zombie.last_heard_pos = ev.position
	if ev.kind in LOUD_KINDS:
		machine.transition_to(&"Investigate", {"pos": ev.position, "fast": true})
	elif intensity > 0.55:
		machine.transition_to(&"Investigate", {"pos": ev.position})
	else:
		machine.transition_to(&"Suspicious", {"pos": ev.position, "heard": true})


func resume_calm() -> void:
	machine.transition_to(zombie.patrol.calm_state())
