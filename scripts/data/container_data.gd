class_name ContainerData
extends Resource
## A searchable container type (shelf, fridge, cash register...).

@export var display_name: String = "货架"
@export var prompt: String = "搜刮"
@export var search_time: float = 2.0
@export var loot_table: LootTable
## First search of a container that turns out empty (random pick).
@export var empty_lines: PackedStringArray = PackedStringArray(["什么都没有。"])
## Checking again a container the player already emptied.
@export var searched_lines: PackedStringArray = PackedStringArray(["已经搜过了。", "里面已经没东西了。"])
## A container the world state says was emptied by someone else.
@export var picked_clean_lines: PackedStringArray = PackedStringArray(["被人搜过了。"])
## A re-check is a quick look, not a full search.
@export var recheck_time: float = 0.8
## Whether this container may receive guaranteed objective items.
@export var accepts_guaranteed: bool = true
@export var search_sound: StringName = &"rummage"
