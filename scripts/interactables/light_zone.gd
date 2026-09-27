class_name LightZone
extends Area2D
## Standing in this area makes the player easier to see.

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	body_entered.connect(func(b): if b is Player: b.stealth.light_count += 1)
	body_exited.connect(func(b): if b is Player: b.stealth.light_count = maxi(b.stealth.light_count - 1, 0))
