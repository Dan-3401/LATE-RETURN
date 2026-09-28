class_name HandEquipmentComponent
extends Node
## The Active Hand Equipment. The three quick slots (1 / 2 / 3) are a
## quick bar, not three held items: only the selected slot's item is in
## the hands, driven by one HandBehavior. Selecting another slot (or the
## selected slot's content changing in the backpack screen) always runs
## unequip() on the old behaviour before equip() on the new one.

signal changed(index: int, item: ItemData)

var player: Player
## 0..2, or -1 = empty hands.
var active_slot_index := -1
var active_item: ItemData = null
var active_behavior: HandBehavior = null
var _active_slot := ""


func setup(p: Player) -> void:
	player = p
	GameState.equipment_changed.connect(_sync)
	GameState.set_active_hand(-1)


## Keys 1 / 2 / 3. Pressing the selected slot again empties the hands.
func select(index: int) -> void:
	if active_behavior and active_behavior.is_busy():
		return
	if index == active_slot_index:
		index = -1
	active_slot_index = index
	GameState.set_active_hand(index)
	_sync()


## Empty hands (hiding, cutscenes, death).
func holster() -> void:
	if active_slot_index == -1 and active_behavior == null:
		return
	active_slot_index = -1
	GameState.set_active_hand(-1)
	_sync()


func primary() -> bool:
	return active_behavior != null and active_behavior.primary()


func update(delta: float, shoulder: Vector2, aim: Vector2, facing: int) -> void:
	if active_behavior:
		active_behavior.update(delta, shoulder, aim, facing)


func is_aiming() -> bool:
	return active_behavior != null and active_behavior.is_aiming()


func aims_flashlight() -> bool:
	return active_behavior != null and active_behavior.aims_flashlight()


func count_text() -> String:
	return active_behavior.count_text() if active_behavior else ""


## Re-reads the real equipment data. Called on every equipment change, so
## an item dragged out of the active slot is put away at once.
func _sync() -> void:
	var slot: String = GameState.HAND_SLOTS[active_slot_index] if active_slot_index >= 0 else ""
	var item: ItemData = GameState.hand_item(active_slot_index)
	if item == active_item and slot == _active_slot and (item == null) == (active_behavior == null):
		return
	if active_behavior:
		active_behavior.unequip()
		active_behavior = null
	active_item = item
	_active_slot = slot
	if item and item.hand_behavior:
		var b: HandBehavior = item.hand_behavior.new()
		b.player = player
		b.item = item
		b.slot = slot
		active_behavior = b
		b.equip()
	changed.emit(active_slot_index, active_item)
