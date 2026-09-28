class_name ItemData
extends Resource
## Static description of an item. New items are new .tres files — no code changes.

enum ItemType { CONSUMABLE, MATERIAL, JUNK, CURRENCY, WEAPON, AMMO, EQUIPMENT, QUEST, THROWABLE, KEY }
## What kind of equipment this is. Decides which equipment slots accept it
## (see slot_type()). Never decide by item name.
enum EquipmentCategory { NONE, PISTOL, MELEE_WEAPON, THROWABLE, HAND_TOOL, CLOTHING, HEAD, ARMOR, BACKPACK }
## Kinds of equipment slots. The three quick slots 1/2/3 are all HAND.
enum SlotType { NONE, HAND, CLOTHING, HEAD, ARMOR, BACKPACK }

@export var id: StringName
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var item_type: ItemType = ItemType.MATERIAL
@export var stackable: bool = true
@export var max_stack: int = 10
@export var value: int = 0
@export var weight: float = 0.0
## Objective tag counted by tasks (e.g. &"water", &"food"). Empty = none.
@export var task_tag: StringName = &""

@export_group("Equipment")
@export var equippable: bool = false
@export var equipment_category: EquipmentCategory = EquipmentCategory.NONE
## Can be held and actively used from a hand slot (1 / 2 / 3).
@export var usable_in_hand: bool = false
## HandBehavior script that runs while the item is the active hand item
## (aim/fire, melee swing, throw...). New hand items only need a new script.
@export var hand_behavior: Script
## Weapon stats for pistol / melee behaviours.
@export var weapon: Resource
## Extra backpack slots while equipped.
@export var capacity_bonus: int = 0

@export_group("Diary")
## Name used in the diary ("水", "食物"...). Empty = display_name.
@export var diary_name: String = ""


const _CATEGORY_SLOT := {
	EquipmentCategory.PISTOL: SlotType.HAND,
	EquipmentCategory.MELEE_WEAPON: SlotType.HAND,
	EquipmentCategory.THROWABLE: SlotType.HAND,
	EquipmentCategory.HAND_TOOL: SlotType.HAND,
	EquipmentCategory.CLOTHING: SlotType.CLOTHING,
	EquipmentCategory.HEAD: SlotType.HEAD,
	EquipmentCategory.ARMOR: SlotType.ARMOR,
	EquipmentCategory.BACKPACK: SlotType.BACKPACK,
}


## The kind of equipment slot this item fits into (NONE = not equipment).
func slot_type() -> SlotType:
	if not equippable:
		return SlotType.NONE
	var t: SlotType = _CATEGORY_SLOT.get(equipment_category, SlotType.NONE)
	if t == SlotType.HAND and not usable_in_hand:
		return SlotType.NONE
	return t


func is_hand_equipment() -> bool:
	return slot_type() == SlotType.HAND
