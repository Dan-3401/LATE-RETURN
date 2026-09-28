class_name HealUseBehavior
extends ItemUseBehavior
## Restores health (bandages...).

@export var amount := 35.0


func use(_item: ItemData, user: Node) -> String:
	var health: HealthComponent = user.get(&"health") if user else null
	if health == null or health.dead:
		return "现在用不了。"
	if health.hp >= health.max_hp:
		return "现在还用不着。"
	health.heal(amount)
	GameState.hp = health.hp
	return ""
