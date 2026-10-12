class_name WarehouseDoor
extends Node2D
## The store's back storeroom. Locked until the key is used once; after that
## it stays open for good (GameState.world["warehouse_unlocked"]).
## Forcing it is not an option: noise brings the dead.

signal entered(actor: Node2D)

const FLAG := "warehouse_unlocked"

@export var key_item: ItemData

@onready var interactable: Interactable = $Interactable
@onready var open_sprite: Sprite2D = $OpenSprite

var _busy := false


func _ready() -> void:
	interactable.interacted.connect(_on_interacted)
	_refresh()


func is_unlocked() -> bool:
	return GameState.world_get(FLAG, false)


func _refresh() -> void:
	open_sprite.visible = is_unlocked()
	interactable.prompt_text = "进入储藏间" if is_unlocked() else "互动"
	interactable.refresh_prompt()


func _on_interacted(actor: Node2D) -> void:
	if _busy:
		return
	if is_unlocked():
		entered.emit(actor)
		return
	_busy = true
	# node-bound tweens: nothing resumes if the level is left mid-way
	var t := create_tween()
	if key_item and GameState.inventory.count_item(key_item.id) > 0:
		# take out the key, insert, turn
		AudioManager.play_at(&"key_jingle", global_position + Vector2(0, -30), -4.0)
		t.tween_interval(0.6)
		t.tween_callback(func(): AudioManager.play_at(&"lock_open", global_position + Vector2(0, -30), -2.0))
		t.tween_interval(0.7)
		t.tween_callback(func():
			GameState.world_set(FLAG, true)
			_refresh()
			if actor.has_method(&"say"):
				actor.call(&"say", "开了。"))
	else:
		AudioManager.play_at(&"lock_rattle", global_position + Vector2(0, -30), -2.0)
		NoiseSystem.emit_noise(global_position + Vector2(0, -30), 60.0, actor, &"rattle")
		t.tween_interval(0.8)
		var key_at_camp: bool = key_item != null and GameState.storage.count_item(key_item.id) > 0
		t.tween_callback(func():
			if actor.has_method(&"say"):
				actor.call(&"say", "钥匙还放在营地的仓库里......" if key_at_camp else "用蛮力的话，会引来很多丧尸吧......"))
	t.tween_callback(func(): _busy = false)
