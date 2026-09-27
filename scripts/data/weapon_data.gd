class_name WeaponData
extends Resource

@export var id: StringName
@export var display_name: String = ""
@export var item: ItemData
@export var is_ranged: bool = false
@export var damage: float = 40.0
## Multiplier against an unaware target hit from behind.
@export var sneak_multiplier: float = 1.0
@export var cooldown: float = 0.5
@export var attack_range: float = 18.0
## Radius (px) of the noise event produced when attacking.
@export var noise_radius: float = 40.0
@export var hit_noise_radius: float = 60.0
@export var attack_sound: StringName = &""
@export var arm_texture: Texture2D
## Pivot (shoulder) inside the arm texture.
@export var arm_pivot: Vector2 = Vector2(3, 4)
## Muzzle / blade tip inside the arm texture.
@export var tip: Vector2 = Vector2(21, 2)
