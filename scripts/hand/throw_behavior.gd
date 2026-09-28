extends HandBehavior
## Throwables (the empty bottle): throw-aim with a dotted arc, left mouse
## throws one item from the hand slot. ThrowComponent does the flight.


func equip() -> void:
	player.throw.set_ready(true)


func unequip() -> void:
	player.throw.set_ready(false)


func primary() -> bool:
	return player.throw.try_throw(player, item, slot)


func update(_delta: float, shoulder: Vector2, aim: Vector2, facing: int) -> void:
	player.throw.update(player, shoulder, aim, facing)


func count_text() -> String:
	return "×%d" % GameState.equip_count(slot)
