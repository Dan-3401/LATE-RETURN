class_name LightZone
extends Area2D
## Gameplay Exposure: a simple, hand-placed value for how exposed the player
## is while standing here. Positive = lit (a street lamp pool, a fire
## barrel), negative = deep shadow (an alley, under an awning).
## Deliberately decoupled from the rendered lights: the visuals may be
## soft and layered, the rule stays predictable.

@export_range(-1.0, 1.0, 0.05) var exposure := 1.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	body_entered.connect(func(b): if b is Player: b.stealth.add_exposure_zone(self))
	body_exited.connect(func(b): if b is Player: b.stealth.remove_exposure_zone(self))
