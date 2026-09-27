class_name HealthComponent
extends Node

signal damaged(amount: float, source: Node)
signal healed(amount: float)
signal died
signal changed(hp: float, max_hp: float)

@export var max_hp := 100.0
@export var invulnerability_time := 0.7

var hp := 100.0
var dead := false
var _invuln := 0.0


func _ready() -> void:
	hp = max_hp


func _physics_process(delta: float) -> void:
	_invuln = maxf(_invuln - delta, 0.0)


func set_hp(value: float) -> void:
	hp = clampf(value, 0.0, max_hp)
	dead = hp <= 0.0
	changed.emit(hp, max_hp)


func take_damage(amount: float, source: Node = null) -> bool:
	if dead or _invuln > 0.0 or amount <= 0.0:
		return false
	hp = maxf(hp - amount, 0.0)
	_invuln = invulnerability_time
	damaged.emit(amount, source)
	changed.emit(hp, max_hp)
	if hp <= 0.0:
		dead = true
		died.emit()
	return true


func heal(amount: float) -> void:
	if dead:
		return
	hp = minf(hp + amount, max_hp)
	healed.emit(amount)
	changed.emit(hp, max_hp)
