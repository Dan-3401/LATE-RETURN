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
## 0 = the default stack size of the item type (see STACK_BY_TYPE). Only set
## this for a special item that must differ from its category.
@export var max_stack_override: int = 0
@export var value: int = 0
@export var weight: float = 0.0
## Objective tag counted by tasks (e.g. &"water", &"food"). Empty = none.
@export var task_tag: StringName = &""

@export_group("Use")
## What happens when the item is used from the right-click menu (使用).
## null = the item cannot be used. Equipping is not using.
@export var use_behavior: ItemUseBehavior

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


## Default stack size per item type. A new item of a type gets this
## automatically; `max_stack_override` is the per-item exception.
const STACK_BY_TYPE := {
	ItemType.WEAPON: 1,
	ItemType.EQUIPMENT: 1,
	ItemType.KEY: 1,
	ItemType.QUEST: 1,
	ItemType.THROWABLE: 20,
	ItemType.MATERIAL: 67,
	ItemType.JUNK: 67,
	ItemType.AMMO: 67,
	ItemType.CONSUMABLE: 10,
	ItemType.CURRENCY: 999,
}


## How many of this item fit into one slot.
func stack_limit() -> int:
	if not stackable:
		return 1
	if max_stack_override > 0:
		return max_stack_override
	return int(STACK_BY_TYPE.get(item_type, 1))


## Can be used from the right-click menu (decided by data, never by name).
func is_usable() -> bool:
	return use_behavior != null


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


## Whether the item may be put into the player's backpack slots. A backpack
## (the thing that provides those slots) never goes inside a backpack: it is
## either worn or kept in another container such as the camp storage.
func fits_in_bag() -> bool:
	return equipment_category != EquipmentCategory.BACKPACK
