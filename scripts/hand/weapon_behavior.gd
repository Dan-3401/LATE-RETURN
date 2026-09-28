extends HandBehavior
## Pistol (aim / fire) and melee weapons (swing). The stats come from
## ItemData.weapon (a WeaponData); WeaponComponent does the actual work.


func equip() -> void:
	player.weapons.equip(item.weapon)


func unequip() -> void:
	player.weapons.equip(null)


func primary() -> bool:
	var w: WeaponData = item.weapon
	if not player.weapons.try_attack(player, player.shoulder_global(), player.facing):
		return false
	player.stealth.spike(1.0 if w.is_ranged else 0.6, 1.0 if w.is_ranged else 0.3)
	return true


func update(_delta: float, shoulder: Vector2, aim: Vector2, facing: int) -> void:
	player.weapons.update_aim(shoulder, aim, facing)


func aims_flashlight() -> bool:
	return true


func is_busy() -> bool:
	return player.weapons.busy


func count_text() -> String:
	return str(GameState.ammo) if (item.weapon as WeaponData).is_ranged else ""
