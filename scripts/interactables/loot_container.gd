class_name LootContainer
extends Node2D
## A searchable object. Its loot is assigned when the level loads
## (see LootDirector) and never changes afterwards.
##
## Can Interact and Has Loot are separate: a searchable can ALWAYS be
## checked. Being empty, already searched or emptied by someone else only
## changes what the search finds ("什么都没有。" / "已经搜过了。" /
## "被人搜过了。") — the player learns it by searching, never by a missing
## [F] prompt.

signal searched(container: LootContainer, loot: Array)

@export var data: ContainerData
## Where drops pop out, relative to the container.
@export var drop_origin := Vector2(0, -24)
@export var meter_offset := Vector2(0, -52)
@export var searched_texture: Texture2D
@export var sprite_path: NodePath = ^"Sprite"

## Array of { item: ItemData, count: int } — locked on level load.
var loot: Array = []
## Emptied (by the player, or already empty in the world state).
var is_searched := false
## True when the player did the emptying (vs. "someone else was here").
var searched_by_player := false
## Key in GameState.world (set by the LootDirector).
var persist_key := ""
var _normal_texture: Texture2D

@onready var interactable: Interactable = $Interactable


func _ready() -> void:
	add_to_group(&"loot_container")
	interactable.prompt_text = data.prompt if data else "搜刮"
	interactable.interacted.connect(_on_interacted)
	if has_node(sprite_path):
		_normal_texture = (get_node(sprite_path) as Sprite2D).texture


## Apply the persistent world state for this container.
func apply_state(st) -> void:
	if st == null:
		return
	loot = LootDirector.from_data(st.get("loot", []))
	if st.get("searched", false):
		_mark_searched(st.get("by", "player") == "player")
	else:
		# refilled / untouched: back to a normal, unsearched container
		is_searched = false
		searched_by_player = false
		interactable.focus_priority = 0.0
		if _normal_texture and has_node(sprite_path):
			(get_node(sprite_path) as Sprite2D).texture = _normal_texture


func _mark_searched(by_player: bool) -> void:
	is_searched = true
	searched_by_player = by_player
	# still interactable; nearby pickups simply win the focus
	interactable.focus_priority = -0.3
	if searched_texture and has_node(sprite_path):
		(get_node(sprite_path) as Sprite2D).texture = searched_texture


func get_meter_position() -> Vector2:
	return global_position + meter_offset


func _on_interacted(actor: Node2D) -> void:
	if not actor.has_method(&"begin_search"):
		return
	var t: float = data.search_time if data else 2.0
	if is_searched:
		t = data.recheck_time if data else 0.8
	AudioManager.play_at(data.search_sound if data else &"rummage", global_position + Vector2(0, -20), -4.0 if not is_searched else -9.0)
	NoiseSystem.emit_noise(global_position, 45.0 if not is_searched else 25.0, actor, &"search")
	actor.call(&"begin_search", self, t, _on_search_done.bind(actor))


func _on_search_done(success: bool, actor: Node2D) -> void:
	if not success:
		return
	if is_searched:
		_say(actor, data.searched_lines if searched_by_player else data.picked_clean_lines, "已经搜过了。")
		searched.emit(self, [])
		return
	_mark_searched(true)
	if persist_key != "":
		GameState.world_set(persist_key, {"searched": true, "loot": [], "by": "player"})
	if loot.is_empty():
		_say(actor, data.empty_lines if data else PackedStringArray(), "什么都没有。")
	else:
		_spawn_drops()
	searched.emit(self, loot)


func _say(actor: Node2D, lines: PackedStringArray, fallback: String) -> void:
	if actor.has_method(&"say"):
		actor.call(&"say", lines[randi() % lines.size()] if lines.size() > 0 else fallback)


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
