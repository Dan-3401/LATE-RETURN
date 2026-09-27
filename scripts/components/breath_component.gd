class_name BreathComponent
extends Node
## Breathing: quiet periodic breath noise, breath holding (oxygen), gasping.

signal oxygen_changed(value: float, max_value: float)
signal gasp_started
signal gasp_ended
signal hold_changed(holding: bool)

@export var max_oxygen := 100.0
@export var drain_per_sec := 15.0
@export var recover_per_sec := 20.0
@export var gasp_duration := 3.2
@export var rehold_threshold := 30.0
@export var breath_interval := 2.6
@export var breath_noise := 26.0
@export var gasp_noise := 125.0
@export var gasp_interval := 0.55

## Scales breath noise (e.g. muffled inside a hiding place).
var noise_scale := 1.0
var oxygen := 100.0
var holding := false
var gasping := false
var enabled := true
var _gasp_left := 0.0
var _breath_timer := 0.0
var _locked := false


func set_hold(want: bool) -> void:
	var can_hold := enabled and not gasping and not (_locked and oxygen < rehold_threshold)
	var new_state := want and can_hold and oxygen > 0.0
	if new_state and not holding:
		AudioManager.play(&"breath_in", -10.0)
	elif holding and not new_state and not gasping:
		AudioManager.play(&"breath_out", -14.0)
	if new_state != holding:
		holding = new_state
		hold_changed.emit(holding)
	if not want:
		_locked = false


func _physics_process(delta: float) -> void:
	var owner_node := get_parent() as Node2D
	if holding:
		oxygen = maxf(oxygen - drain_per_sec * delta, 0.0)
		if oxygen <= 0.0:
			holding = false
			hold_changed.emit(false)
			_start_gasp()
	elif gasping:
		oxygen = minf(oxygen + recover_per_sec * 0.5 * delta, max_oxygen)
		_gasp_left -= delta
		_breath_timer -= delta
		if _breath_timer <= 0.0:
			_breath_timer = gasp_interval
			if owner_node:
				NoiseSystem.emit_noise(owner_node.global_position + Vector2(0, -30), gasp_noise * noise_scale, owner_node, &"gasp")
			AudioManager.play(&"gasp", -4.0, 0.1)
		if _gasp_left <= 0.0:
			gasping = false
			_locked = true
			gasp_ended.emit()
	else:
		oxygen = minf(oxygen + recover_per_sec * delta, max_oxygen)
		_breath_timer -= delta
		if _breath_timer <= 0.0 and enabled:
			_breath_timer = breath_interval + randf_range(-0.3, 0.3)
			if owner_node:
				NoiseSystem.emit_noise(owner_node.global_position + Vector2(0, -30), breath_noise * noise_scale, owner_node, &"breath")
	oxygen_changed.emit(oxygen, max_oxygen)


func _start_gasp() -> void:
	gasping = true
	_gasp_left = gasp_duration
	_breath_timer = 0.0
	gasp_started.emit()


func reset(value: float = 100.0) -> void:
	oxygen = value
	holding = false
	gasping = false
	_locked = false
