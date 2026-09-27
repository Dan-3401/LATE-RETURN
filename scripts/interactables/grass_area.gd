class_name GrassArea
extends Area2D
## Tall grass: lowers Presence while the player is inside (never absolute
## invisibility). Rustles when moved through quickly.

var _inside: Array[Player] = []
var _rustle := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)


func _on_enter(b: Node) -> void:
	if b is Player:
		_inside.append(b)
		b.stealth.grass_count += 1
		_sway(1.8)


func _on_exit(b: Node) -> void:
	if b is Player:
		_inside.erase(b)
		b.stealth.grass_count = maxi(b.stealth.grass_count - 1, 0)


func _physics_process(delta: float) -> void:
	_rustle -= delta
	for p in _inside:
		if absf(p.velocity.x) > 90.0 and _rustle <= 0.0:
			_rustle = 0.35
			NoiseSystem.emit_noise(p.global_position, 60.0, p, &"rustle")
			_sway(2.2)


func _sway(speed: float) -> void:
	for c in get_children():
		if c is AnimatedSprite2D:
			c.speed_scale = speed
			var t := create_tween()
			t.tween_property(c, "speed_scale", 1.0, 1.2)
