class_name LootContainer
extends Node2D
## A searchable object. Its loot is assigned when the level loads
## (see LootDirector) and never changes afterwards.

signal searched(container: LootContainer, loot: Array)

@export var data: ContainerData
## Where drops pop out, relative to the container.
@export var drop_origin := Vector2(0, -24)
@export var meter_offset := Vector2(0, -52)
@export var searched_texture: Texture2D
@export var sprite_path: NodePath = ^"Sprite"

## Array of { item: ItemData, count: int } — locked on level load.
var loot: Array = []
var is_searched := false

@onready var interactable: Interactable = $Interactable


func _ready() -> void:
	add_to_group(&"loot_container")
	interactable.prompt_text = data.prompt if data else "搜刮"
	interactable.interacted.connect(_on_interacted)
	interactable.condition = func(_a): return not is_searched


func get_meter_position() -> Vector2:
	return global_position + meter_offset


func _on_interacted(actor: Node2D) -> void:
	if is_searched or not actor.has_method(&"begin_search"):
		return
	AudioManager.play_at(data.search_sound if data else &"rummage", global_position + Vector2(0, -20), -4.0)
	NoiseSystem.emit_noise(global_position, 45.0, actor, &"search")
	actor.call(&"begin_search", self, data.search_time if data else 2.0, _on_search_done.bind(actor))


func _on_search_done(success: bool, actor: Node2D) -> void:
	if not success:
		return
	is_searched = true
	interactable.enabled = false
	if searched_texture and has_node(sprite_path):
		(get_node(sprite_path) as Sprite2D).texture = searched_texture
	if loot.is_empty():
		if actor.has_method(&"say") and data and data.empty_lines.size() > 0:
			actor.call(&"say", data.empty_lines[randi() % data.empty_lines.size()])
	else:
		_spawn_drops()
	searched.emit(self, loot)


func _spawn_drops() -> void:
	var scene: PackedScene = preload("res://scenes/items/pickup.tscn")
	var i := 0
	for entry in loot:
		var p: Node2D = scene.instantiate()
		p.set("item", entry.item)
		p.set("count", entry.count)
		get_parent().add_child(p)
		p.global_position = global_position + drop_origin
		var dir := -1.0 if i % 2 == 0 else 1.0
		p.call(&"launch", Vector2(dir * randf_range(22.0, 55.0) + randf_range(-8, 8), randf_range(-150.0, -120.0)), i * 0.12)
		i += 1
	AudioManager.play_at(&"item_pop", global_position + drop_origin, -6.0)
