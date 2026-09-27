class_name ItemData
extends Resource
## Static description of an item. New items are new .tres files — no code changes.

enum ItemType { CONSUMABLE, MATERIAL, JUNK, CURRENCY, WEAPON, AMMO, EQUIPMENT, QUEST, THROWABLE, KEY }

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
## Equipment slot this item can be equipped into ("clothing", "throwable"...). Empty = not equippable.
@export var equip_slot: StringName = &""
## Extra backpack slots while equipped.
@export var capacity_bonus: int = 0
## Name used in the diary ("水", "食物"...). Empty = display_name.
@export var diary_name: String = ""
