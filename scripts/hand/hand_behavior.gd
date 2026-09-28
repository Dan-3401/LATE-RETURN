class_name HandBehavior
extends RefCounted
## What the active hand item does while it is held. Exactly one instance
## exists at a time (HandEquipmentComponent owns it): switching slots calls
## unequip() on the old one before equip() on the new one.
## An item names its behaviour script in ItemData.hand_behavior, so a new
## kind of hand item is a new script + .tres — the Player does not change.

var player: Player
var item: ItemData
## Equipment slot id the item is held from ("hand1".."hand3").
var slot: String


func equip() -> void:
	pass


func unequip() -> void:
	pass


## Left mouse. Returns true when the action happened.
func primary() -> bool:
	return false


## Every physics frame while held.
func update(_delta: float, _shoulder: Vector2, _aim: Vector2, _facing: int) -> void:
	pass


## The body faces the mouse and plays the armed animation set.
func is_aiming() -> bool:
	return true


## The chest flashlight follows the aim direction.
func aims_flashlight() -> bool:
	return false


## Blocks switching (e.g. in the middle of a knife swing).
func is_busy() -> bool:
	return false


## Small counter for the quick bar ("10", "×3"...).
func count_text() -> String:
	return ""
