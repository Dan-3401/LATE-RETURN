class_name StateMachine
extends Node
## Explicit finite state machine. Child nodes extending ZombieState are the
## states; their node names are the state names.

signal transitioned(from: StringName, to: StringName)

@export var initial_state: StringName = &"Idle"

var states := {}
var current: ZombieState
var actor: Node


func setup(a: Node) -> void:
	actor = a
	for c in get_children():
		if c is ZombieState:
			states[c.name] = c
			c.zombie = a
			c.machine = self
	transition_to(initial_state)


func transition_to(state_name: StringName, msg: Dictionary = {}) -> void:
	if not states.has(state_name):
		push_error("Unknown state " + state_name)
		return
	var from: StringName = current.name if current else &""
	# Dead is final: nothing may bring a corpse back into an AI state
	if from == &"Dead":
		return
	if current:
		current.exit()
	current = states[state_name]
	current.enter(msg)
	transitioned.emit(from, state_name)


func physics_update(delta: float) -> void:
	if current:
		current.physics_update(delta)


func on_noise(ev: Dictionary, intensity: float) -> void:
	if current:
		current.on_noise(ev, intensity)


func on_damaged(source: Node) -> void:
	if current:
		current.on_damaged(source)


func state_name() -> StringName:
	return current.name if current else &""
