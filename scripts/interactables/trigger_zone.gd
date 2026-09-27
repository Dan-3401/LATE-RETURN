class_name TriggerZone
extends Area2D
## Emits `triggered` once when the player enters.

signal triggered(player: Player)

@export var once := true
var _done := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	body_entered.connect(_on_body)


func _on_body(b: Node) -> void:
	if b is Player and not (once and _done):
		_done = true
		triggered.emit(b)
