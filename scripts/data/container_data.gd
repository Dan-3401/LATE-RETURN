class_name ContainerData
extends Resource
## A searchable container type (shelf, fridge, cash register...).

@export var display_name: String = "货架"
@export var prompt: String = "搜刮"
@export var search_time: float = 2.0
@export var loot_table: LootTable
## Line the player may mutter when a container turns out empty (random pick).
@export var empty_lines: PackedStringArray = PackedStringArray(["……什么都没有。"])
## Whether this container may receive guaranteed objective items.
@export var accepts_guaranteed: bool = true
@export var search_sound: StringName = &"rummage"
