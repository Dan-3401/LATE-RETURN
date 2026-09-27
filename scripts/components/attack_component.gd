class_name AttackComponent
extends Node
## Melee reach checks and damage for zombies.

var owner_body: Node2D
var data: ZombieData
var cooldown := 0.0


func setup(o: Node2D, d: ZombieData) -> void:
	owner_body = o
	data = d


func _physics_process(delta: float) -> void:
	cooldown = maxf(cooldown - delta, 0.0)


func in_reach(target: Node2D, extra := 0.0) -> bool:
	if target == null:
		return false
	var dx := absf(target.global_position.x - owner_body.global_position.x)
	var dy := absf(target.global_position.y - owner_body.global_position.y)
	return dx <= data.attack_range + extra and dy < 30.0


func can_attack(target: Node2D) -> bool:
	return cooldown <= 0.0 and in_reach(target)


## Resolve the hit at the strike frame. Returns true on hit.
func strike(target: Node2D) -> bool:
	cooldown = data.attack_cooldown
	if in_reach(target, 8.0) and target.has_method(&"take_damage"):
		var facing: int = owner_body.get(&"facing")
		# must be facing the target
		if signf(target.global_position.x - owner_body.global_position.x) in [0.0, float(facing)]:
			target.call(&"take_damage", data.attack_damage, owner_body, Vector2(facing, 0))
			return true
	return false
