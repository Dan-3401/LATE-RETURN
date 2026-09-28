class_name InventoryActions
extends RefCounted
## The right-click actions on one specific item stack (使用 / 拆分 / 丢弃).
## The UI only asks this layer what is possible and calls it; which
## container the stack is in (the Context) decides what an action does —
## e.g. 丢弃 in the camp storage destroys the stack (after a confirmation),
## 丢弃 from the backpack drops it on the ground as one pickup.
## Every action works on the real data (GameState containers), never on UI.

enum Context { NONE, PLAYER_BACKPACK, CAMP_STORAGE }
## What 丢弃 does in a context.
enum DiscardMode { NONE, DESTROY, DROP }

const PICKUP_SCENE := preload("res://scenes/items/pickup.tscn")


static func context_of(ref: Dictionary) -> Context:
	match String(ref.get("kind", "")):
		"bag": return Context.PLAYER_BACKPACK
		"storage": return Context.CAMP_STORAGE
	return Context.NONE


static func stack(ref: Dictionary):
	return GameState.stack_at(ref)


## What the menu shows for this stack: {"use", "split", "discard": bool,
## "discard_mode": DiscardMode, "count": int}.
static func menu_state(ref: Dictionary) -> Dictionary:
	var s = stack(ref)
	var ctx := context_of(ref)
	if s == null or ctx == Context.NONE:
		return {"use": false, "split": false, "discard": false, "discard_mode": DiscardMode.NONE, "count": 0}
	return {
		"use": can_use(ref),
		"split": can_split(ref),
		"discard": GameState.can_discard(s.item),
		"discard_mode": discard_mode(ref),
		"count": int(s.count),
	}


# --- 使用 ---------------------------------------------------------------------------------
static func can_use(ref: Dictionary) -> bool:
	var s = stack(ref)
	return s != null and context_of(ref) != Context.NONE and (s.item as ItemData).is_usable()


## Run the item's use effect, then take one item from THIS stack (the stack
## is removed at 0). Returns "" or a reason (nothing consumed then).
static func use(ref: Dictionary, user: Node) -> String:
	if not can_use(ref):
		return "这个不能使用。"
	var s = stack(ref)
	var item: ItemData = s.item
	var err := item.use_behavior.use(item, user)
	if err != "":
		return err
	s.count -= 1
	var inv := GameState.container_of(ref)
	if s.count <= 0:
		inv.slots[ref.index] = null
	inv.changed.emit()
	return ""


# --- 拆分 ---------------------------------------------------------------------------------
static func can_split(ref: Dictionary) -> bool:
	var s = stack(ref)
	return s != null and context_of(ref) != Context.NONE and int(s.count) >= 2


## Valid split amounts are 1 .. count - 1 of this stack.
static func split_valid(ref: Dictionary, amount: int) -> bool:
	var s = stack(ref)
	return s != null and amount >= 1 and amount <= int(s.count) - 1


## New stack in an empty slot of the same container; "没有空余位置。" and no
## change when there is none.
static func split(ref: Dictionary, amount: int) -> String:
	if not can_split(ref):
		return "这个不能拆分。"
	if not split_valid(ref, amount):
		return "invalid"
	return GameState.container_of(ref).split(ref.index, amount)


# --- 丢弃 ---------------------------------------------------------------------------------
static func discard_mode(ref: Dictionary) -> DiscardMode:
	match context_of(ref):
		Context.CAMP_STORAGE: return DiscardMode.DESTROY
		Context.PLAYER_BACKPACK: return DiscardMode.DROP
	return DiscardMode.NONE


## Permanently delete the stack (camp storage, after the 是 confirmation).
static func destroy(ref: Dictionary) -> String:
	return GameState.discard(ref)


## Take the whole stack out of the backpack and put it on the ground next
## to `player` as ONE pickup holding the whole stack. Returns the pickup
## (null = nothing changed).
static func drop_to_ground(ref: Dictionary, player: Node2D) -> Node2D:
	var s = stack(ref)
	if s == null or player == null or not player.is_inside_tree() or not GameState.can_discard(s.item):
		return null
	var level := player.get_parent()
	if level == null:
		return null
	var p: Node2D = PICKUP_SCENE.instantiate()
	p.call(&"set_stack", s)
	GameState.container_of(ref).slots[ref.index] = null
	GameState.container_of(ref).changed.emit()
	level.add_child(p)
	var facing: float = 1.0
	var f = player.get(&"facing")
	if f is float or f is int:
		facing = signf(float(f)) if f != 0 else 1.0
	p.global_position = player.global_position + Vector2(facing * 12.0, -6.0)
	p.call(&"launch", Vector2(facing * 30.0, -90.0))
	AudioManager.play_at(&"item_pop", p.global_position, -8.0)
	return p
