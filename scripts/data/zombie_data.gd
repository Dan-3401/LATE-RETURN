class_name ZombieData
extends Resource
## Tunables for a zombie archetype.

@export var max_hp: float = 100.0
@export var patrol_speed: float = 18.0
@export var investigate_speed: float = 34.0
@export var chase_speed: float = 112.0
@export var vision_range: float = 180.0
@export var vision_half_angle: float = 42.0
## Close range where the zombie senses in every direction.
@export var near_sense_range: float = 26.0
## Suspicion gained per second at presence 1.0, full proximity.
@export var detection_rate: float = 1.6
@export var suspicion_decay: float = 0.35
@export var hearing_multiplier: float = 1.0
@export var attack_damage: float = 34.0
@export var attack_range: float = 20.0
@export var attack_windup: float = 0.35
@export var attack_cooldown: float = 1.1
@export var roar_radius: float = 380.0
@export var search_time: float = 7.0
@export var lose_sight_time: float = 1.2
