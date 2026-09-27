class_name StealthComponent
extends Node
## Computes the player's Presence (0 = invisible, 1 = very noticeable).

signal presence_changed(value: float)
signal hidden_changed(hidden: bool)

enum Motion { IDLE, SNEAK, WALK, RUN, AIR }

@export var base_idle := 0.25
@export var base_sneak := 0.35
@export var base_walk := 0.6
@export var base_run := 1.0
@export var base_air := 0.8
@export var grass_factor := 0.4
@export var grass_factor_running := 0.85
@export var flashlight_bonus := 0.22
@export var light_zone_bonus := 0.35

var presence := 0.5
var motion: Motion = Motion.IDLE
var grass_count := 0
var light_count := 0
var hidden := false
var hide_spot: Node = null
var flashlight_on := false
var _spike := 0.0
var _spike_time := 0.0


func in_grass() -> bool:
	return grass_count > 0


func in_light() -> bool:
	return light_count > 0


func set_hidden(value: bool, spot: Node = null) -> void:
	hidden = value
	hide_spot = spot if value else null
	hidden_changed.emit(hidden)


## Temporarily force a minimum presence (gunshots, loud actions).
func spike(amount: float, duration: float) -> void:
	_spike = maxf(_spike, amount)
	_spike_time = maxf(_spike_time, duration)


func update(delta: float, new_motion: Motion, is_flashlight_on: bool) -> void:
	motion = new_motion
	flashlight_on = is_flashlight_on
	var target := 0.0
	if not hidden:
		match motion:
			Motion.IDLE: target = base_idle
			Motion.SNEAK: target = base_sneak
			Motion.WALK: target = base_walk
			Motion.RUN: target = base_run
			Motion.AIR: target = base_air
		if in_grass():
			target *= grass_factor_running if motion == Motion.RUN else grass_factor
		if flashlight_on:
			target += flashlight_bonus
		if in_light():
			target += light_zone_bonus
		if _spike_time > 0.0:
			target = maxf(target, _spike)
	_spike_time = maxf(_spike_time - delta, 0.0)
	target = clampf(target, 0.0, 1.0)
	var rate := 20.0 if hidden else 5.0
	presence = move_toward(presence, target, rate * delta)
	presence_changed.emit(presence)
