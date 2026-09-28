extends Node
## Persistent run state: inventory, equipment, objective, checkpoint, days,
## camp resources, expeditions and persistent world state.
## Gameplay logic lives in components/levels; this only stores data that must
## survive scene changes.

signal objective_changed
signal ammo_changed(ammo: int)
signal inventory_changed
signal camp_changed
signal equipment_changed
signal active_hand_changed(index: int)

const START_AMMO := 10
const BASE_CAPACITY := 10
const PISTOL_ITEM := preload("res://resources/items/pistol.tres")
const KNIFE_ITEM := preload("res://resources/items/knife.tres")
const BACKPACK_ITEM := preload("res://resources/items/backpack.tres")
## The three quick slots (keys 1 / 2 / 3). All of them are HAND slots, so
## any hand equipment fits into any of them.
const HAND_SLOTS := ["hand1", "hand2", "hand3"]
## Equipment slot id -> slot type. Adding a slot = adding a line here.
const SLOT_TYPES := {
	"hand1": ItemData.SlotType.HAND,
	"hand2": ItemData.SlotType.HAND,
	"hand3": ItemData.SlotType.HAND,
	"helmet": ItemData.SlotType.HEAD,
	"armor": ItemData.SlotType.ARMOR,
	"clothing": ItemData.SlotType.CLOTHING,
	"backpack": ItemData.SlotType.BACKPACK,
}
## The date of day 0 (the first day, the linear story day).
const START_DATE := {"year": 2025, "month": 9, "day": 28, "hour": 12, "minute": 0, "second": 0}
const MAIN_QUEST_TITLE := "寻找能够治疗哮喘病的药"
## Items that are handed over to the camp storage when coming home.
const CAMP_TAGS := [&"food", &"water"]
## Items counted as a "rare discovery" for the diary.
const RARE_ITEMS := [&"warehouse_key", &"work_uniform"]

enum Phase { STORY, FREE }

var inventory := Inventory.new(BASE_CAPACITY)
## slot id -> null or {"item": ItemData, "count": int}
var equipment := {}
## Selected hand slot (0..2) or -1 = empty hands. Runtime only: the player
## starts every scene with empty hands.
var active_hand := -1
var ammo: int = START_AMMO:
	set(v):
		ammo = maxi(v, 0)
		ammo_changed.emit(ammo)
var max_hp: float = 100.0
var hp: float = 100.0
var oxygen: float = 100.0
var flags := {}
var objective := {}
var checkpoint := {}
var loot_seed: int = 0
var debug_enabled: bool = OS.is_debug_build()

# --- day / camp / expedition ---------------------------------------------------
var phase: Phase = Phase.STORY
var day_index := 0
var camp := {"food": 0, "water": 0}
## Current expedition: {active, location, region, location_visited, seed, start_counts}
var expedition := {}
var expedition_done_today := false
## What the player brought home today: {"gains": {item_id: count}, "rare": [item_id]}
var daily := {}
## Item ids the player has ever obtained (for "first time" rare discoveries).
var obtained_ever := {}
## Persistent world state: "store/ShelfA" -> {searched, loot:[{path,count}]}, flags...
var world := {}
## Where the next scene should place the player (e.g. &"store_door").
var spawn_point: StringName = &""
## Pending settlement to show when the camp loads: {"food": n, "water": n}
var pending_settlement := {}
## Diary page to show next: {"date": String, "lines": PackedStringArray, "next": StringName}
var pending_diary := {}


func _ready() -> void:
	inventory.changed.connect(_on_inventory_changed)
	inventory.item_added.connect(_on_item_added)
	new_game()


func new_game() -> void:
	inventory.resize(BASE_CAPACITY, true)
	inventory.clear()
	equipment = {}
	for slot in SLOT_TYPES:
		equipment[slot] = null
	equipment.hand1 = {"item": PISTOL_ITEM, "count": 1}
	equipment.hand2 = {"item": KNIFE_ITEM, "count": 1}
	equipment.backpack = {"item": BACKPACK_ITEM, "count": 1}
	active_hand = -1
	ammo = START_AMMO
	hp = max_hp
	oxygen = 100.0
	flags = {}
	checkpoint = {}
	objective = {"id": &"", "title": "", "required": {}, "active": false, "complete": false}
	phase = Phase.STORY
	day_index = 0
	camp = {"food": 0, "water": 0}
	expedition = {}
	expedition_done_today = false
	daily = {"gains": {}, "rare": []}
	obtained_ever = {}
	world = {}
	spawn_point = &""
	pending_settlement = {}
	pending_diary = {}
	randomize()
	loot_seed = randi()
	objective_changed.emit()
	camp_changed.emit()


func is_free_phase() -> bool:
	return phase == Phase.FREE


# --- Calendar ------------------------------------------------------------------
## Real calendar arithmetic (no "9月31日").
func date_for_day(index: int) -> Dictionary:
	var base := Time.get_unix_time_from_datetime_dict(START_DATE)
	return Time.get_datetime_dict_from_unix_time(base + index * 86400)


func date_text(index: int = -1) -> String:
	var d := date_for_day(day_index if index < 0 else index)
	return "%d月%d日" % [d.month, d.day]


# --- Objective -------------------------------------------------------------
func start_objective(id: StringName, title: String, required: Dictionary) -> void:
	objective = {"id": id, "title": title, "required": required, "active": true, "complete": false}
	_check_objective()
	objective_changed.emit()


func objective_progress(tag: StringName) -> int:
	return inventory.count_tag(tag)


func is_objective_complete() -> bool:
	return objective.get("complete", false)


func _check_objective() -> void:
	if not objective.get("active", false):
		return
	var done := true
	for tag in objective.required:
		if inventory.count_tag(tag) < int(objective.required[tag]):
			done = false
	if done != objective.complete:
		objective.complete = done
		objective_changed.emit()


func clear_objective() -> void:
	objective.active = false
	objective_changed.emit()


func _on_inventory_changed() -> void:
	_check_objective()
	inventory_changed.emit()
	objective_changed.emit()


func _on_item_added(item: ItemData, _count: int) -> void:
	if item.id in RARE_ITEMS and not obtained_ever.has(item.id):
		obtained_ever[item.id] = true
		if not item.id in daily.rare:
			daily.rare.append(item.id)


# --- Equipment -----------------------------------------------------------------
## Equipment lives here, never in UI nodes: every slot holds null or
## {"item": ItemData, "count": int}, exactly like a backpack slot.
## Moves between the backpack and the equipment slots go through
## move_item(), which the inventory UI calls for every drag & drop.
## Item locations are addressed with refs:
##   {"kind": "bag", "index": int}   or   {"kind": "equip", "slot": String}
func equip_get(slot: String) -> ItemData:
	var s = equipment.get(slot)
	return s.item if s != null else null


func equip_count(slot: String) -> int:
	var s = equipment.get(slot)
	return int(s.count) if s != null else 0


func hand_item(index: int) -> ItemData:
	if index < 0 or index >= HAND_SLOTS.size():
		return null
	return equip_get(HAND_SLOTS[index])


## The single compatibility rule for every equipment slot: the slot's type
## must match the item's slot type (derived from its EquipmentCategory).
func can_accept(slot: String, item: ItemData) -> bool:
	return item != null and SLOT_TYPES.has(slot) and item.slot_type() == SLOT_TYPES[slot]


func capacity() -> int:
	var cap := BASE_CAPACITY
	for k in equipment:
		if equipment[k] != null:
			cap += equipment[k].item.capacity_bonus
	return cap


func _ref_get(ref: Dictionary):
	if ref.kind == "bag":
		var i: int = ref.index
		return inventory.slots[i] if i >= 0 and i < inventory.size else null
	return equipment.get(ref.slot)


func _ref_set(ref: Dictionary, v) -> void:
	if ref.kind == "bag":
		inventory.slots[ref.index] = v
	else:
		equipment[ref.slot] = v


func _ref_valid(ref: Dictionary) -> bool:
	if ref.get("kind") == "bag":
		return int(ref.get("index", -1)) >= 0 and int(ref.index) < inventory.size
	return ref.get("kind") == "equip" and SLOT_TYPES.has(ref.get("slot", ""))


## Move, merge or swap. Returns "" on success or a short reason (the UI
## uses it for the red/green highlight while dragging). Never loses items:
## anything that does not fit stays where it was.
func move_item(src: Dictionary, dst: Dictionary, dry_run := false) -> String:
	if not _ref_valid(src) or not _ref_valid(dst):
		return "invalid"
	if src.kind == dst.kind and src.get("index") == dst.get("index") and src.get("slot") == dst.get("slot"):
		return "same"
	var a = _ref_get(src)
	if a == null:
		return "empty"
	var b = _ref_get(dst)
	if dst.kind == "equip" and not can_accept(dst.slot, a.item):
		return "这个不能装备在这里。"
	var merge: bool = b != null and b.item.id == a.item.id and a.item.stackable and b.count < a.item.max_stack
	if b != null and not merge and b.item.id == a.item.id and a.item.stackable:
		return "已经放满了。"
	var swap: bool = b != null and not merge
	if swap and src.kind == "equip" and not can_accept(src.slot, b.item):
		return "这个不能装备在这里。"
	# bag size after the move (clothing / backpack change the capacity)
	var cap_after := capacity()
	var used_after := inventory.used_slots()
	if not merge:
		if src.kind == "equip":
			cap_after -= a.item.capacity_bonus
			if swap:
				cap_after += b.item.capacity_bonus
		if dst.kind == "equip":
			cap_after += a.item.capacity_bonus
			if swap:
				cap_after -= b.item.capacity_bonus
		if src.kind == "bag" and dst.kind == "equip" and not swap:
			used_after -= 1
		elif src.kind == "equip" and dst.kind == "bag" and not swap:
			used_after += 1
	elif src.kind == "bag" and a.count <= a.item.max_stack - b.count:
		used_after -= 1
	if used_after > cap_after:
		return "背包里的东西太多了。"
	if dry_run:
		return ""
	if merge:
		var take: int = mini(a.count, a.item.max_stack - b.count)
		b.count += take
		a.count -= take
		if a.count <= 0:
			_ref_set(src, null)
	else:
		_ref_set(dst, a)
		_ref_set(src, b)
	if cap_after != inventory.size:
		inventory.resize(cap_after)
	inventory.changed.emit()
	equipment_changed.emit()
	return ""


## Put a backpack item into its equipment slot (the first free hand slot
## for hand equipment; swapping with the occupant otherwise).
func quick_equip(bag_index: int) -> String:
	var s = inventory.slots[bag_index] if bag_index < inventory.size else null
	if s == null:
		return "empty"
	var item: ItemData = s.item
	if item.slot_type() == ItemData.SlotType.NONE:
		return "这个不能装备。"
	var target := ""
	for slot in SLOT_TYPES:
		if can_accept(slot, item) and equipment[slot] == null:
			target = slot
			break
	if target == "":
		for slot in SLOT_TYPES:
			if can_accept(slot, item):
				target = slot
				break
	if item.is_hand_equipment() and equipment[target] != null:
		return "手持栏已经满了。"
	return move_item({"kind": "bag", "index": bag_index}, {"kind": "equip", "slot": target})


## Take an equipment slot off into the first free backpack slot.
func unequip_to_bag(slot: String) -> String:
	if equipment.get(slot) == null:
		return ""
	for i in inventory.size:
		if inventory.slots[i] == null:
			return move_item({"kind": "equip", "slot": slot}, {"kind": "bag", "index": i})
	return "背包里的东西太多了。"


## Use up items held in a hand slot (a thrown bottle). An emptied slot is
## refilled from the same items in the backpack, so a stack of bottles in
## the bag keeps the throwable in hand.
func consume_hand(slot: String, n: int = 1) -> void:
	var s = equipment.get(slot)
	if s == null:
		return
	var item: ItemData = s.item
	s.count -= n
	if s.count <= 0:
		equipment[slot] = null
		var refill := mini(inventory.count_item(item.id), item.max_stack)
		if refill > 0:
			inventory.remove(item.id, refill)
			equipment[slot] = {"item": item, "count": refill}
	inventory.changed.emit()
	equipment_changed.emit()


## Everything the player carries (backpack + equipment), by item id.
func item_counts() -> Dictionary:
	var counts := {}
	for s in inventory.slots:
		if s != null:
			counts[s.item.id] = counts.get(s.item.id, 0) + s.count
	for k in equipment:
		var s = equipment[k]
		if s != null:
			counts[s.item.id] = counts.get(s.item.id, 0) + s.count
	return counts


func count_carried(item_id: StringName) -> int:
	return int(item_counts().get(item_id, 0))


func set_active_hand(index: int) -> void:
	if index == active_hand:
		return
	active_hand = index
	active_hand_changed.emit(index)


# --- Camp ----------------------------------------------------------------------
func camp_add(res: String, amount: int) -> void:
	camp[res] = maxi(int(camp.get(res, 0)) + amount, 0)
	camp_changed.emit()


func can_afford(cost: Dictionary) -> bool:
	for k in cost:
		if int(camp.get(k, 0)) < int(cost[k]):
			return false
	return true


## Hand food/water over to the camp. Returns {"food": n, "water": n}.
func deposit_supplies() -> Dictionary:
	var got := {"food": 0, "water": 0}
	for s in inventory.slots:
		if s != null and s.item.task_tag in CAMP_TAGS:
			got[String(s.item.task_tag)] += s.count
	for tag in CAMP_TAGS:
		var n: int = got[String(tag)]
		if n > 0:
			for i in inventory.size:
				var s = inventory.slots[i]
				if s != null and s.item.task_tag == tag:
					inventory.slots[i] = null
			camp_add(String(tag), n)
	inventory.changed.emit()
	return got


# --- Phases & days ------------------------------------------------------------------
## After the first diary: day 2 begins and the game opens up.
func start_free_phase() -> void:
	phase = Phase.FREE
	# whatever was carried home on the first day goes into the camp
	camp = {"food": 2, "water": 1}
	deposit_supplies()
	pending_settlement = {}
	start_objective(&"medicine", MAIN_QUEST_TITLE, {})
	_begin_day(day_index + 1)
	camp_changed.emit()


func _begin_day(index: int) -> void:
	day_index = index
	ammo = START_AMMO
	hp = max_hp
	oxygen = 100.0
	daily = {"gains": {}, "rare": []}
	expedition = {}
	expedition_done_today = false
	spawn_point = &""
	checkpoint = {}


func new_day() -> void:
	_begin_day(day_index + 1)
	if objective.get("id") != &"medicine":
		start_objective(&"medicine", MAIN_QUEST_TITLE, {})


# --- Expeditions -----------------------------------------------------------------
## Pays the cost and prepares the persistent world for this outing.
func begin_expedition(loc: LocationData) -> bool:
	var cost := {"food": loc.cost_food, "water": loc.cost_water}
	if not can_afford(cost) or expedition_done_today or not loc.playable:
		return false
	camp_add("food", -loc.cost_food)
	camp_add("water", -loc.cost_water)
	var counts := item_counts()
	expedition = {
		"active": true,
		"location": loc.id,
		"region": loc.region_scene,
		"location_visited": false,
		"seed": randi(),
		"start_counts": counts,
	}
	loot_seed = expedition.seed
	spawn_point = &"region_start"
	return true


func mark_location_visited() -> void:
	if expedition.get("active", false):
		expedition.location_visited = true


## Coming home: supplies go to the camp, today's gains are recorded.
func end_expedition() -> Dictionary:
	var counts := item_counts()
	for id in counts:
		var gained: int = counts[id] - int(expedition.get("start_counts", {}).get(id, 0))
		if gained > 0:
			daily.gains[id] = int(daily.gains.get(id, 0)) + gained
	var got := deposit_supplies()
	expedition = {}
	expedition_done_today = true
	checkpoint = {}
	pending_settlement = got
	return got


# --- World state ------------------------------------------------------------------
func world_get(key: String, default = null):
	return world.get(key, default)


func world_set(key: String, value) -> void:
	world[key] = value


# --- Checkpoint -------------------------------------------------------------
func snapshot() -> Dictionary:
	var eq := {}
	for k in equipment:
		var s = equipment[k]
		eq[k] = {"path": s.item.resource_path, "count": s.count} if s != null else null
	return {
		"hp": hp,
		"oxygen": oxygen,
		"ammo": ammo,
		"capacity": inventory.size,
		"inventory": inventory.to_data(),
		"equipment": eq,
		"objective": objective.duplicate(true),
		"flags": flags.duplicate(true),
		"phase": phase,
		"day_index": day_index,
		"camp": camp.duplicate(true),
		"expedition": expedition.duplicate(true),
		"daily": daily.duplicate(true),
		"obtained_ever": obtained_ever.duplicate(true),
		"world": world.duplicate(true),
		"expedition_done_today": expedition_done_today,
		"loot_seed": loot_seed,
	}


func save_checkpoint(id: StringName, scene_path: String) -> void:
	checkpoint = snapshot()
	checkpoint["id"] = id
	checkpoint["scene"] = scene_path


func has_checkpoint() -> bool:
	return not checkpoint.is_empty()


func restore_checkpoint() -> void:
	if checkpoint.is_empty():
		return
	apply_snapshot(checkpoint)
	if checkpoint.has("phase"):
		spawn_point = &"region_start" if is_free_phase() else &""


## Puts a snapshot() back (checkpoint restart, loading a save).
func apply_snapshot(d: Dictionary) -> void:
	hp = d.hp
	oxygen = d.oxygen
	ammo = d.ammo
	inventory.resize(int(d.get("capacity", BASE_CAPACITY)), true)
	inventory.from_data(d.inventory)
	for k in SLOT_TYPES:
		equipment[k] = null
		var e = d.equipment.get(k)
		if e is Dictionary and ResourceLoader.exists(String(e.get("path", ""))):
			var item := load(e.path) as ItemData
			if item:
				equipment[k] = {"item": item, "count": maxi(int(e.get("count", 1)), 1)}
	objective = d.objective.duplicate(true)
	flags = d.flags.duplicate(true)
	if d.has("phase"):
		phase = d.phase
		day_index = d.day_index
		camp = d.camp.duplicate(true)
		expedition = d.expedition.duplicate(true)
		daily = d.daily.duplicate(true)
		obtained_ever = d.obtained_ever.duplicate(true)
		world = d.world.duplicate(true)
	if d.has("expedition_done_today"):
		expedition_done_today = d.expedition_done_today
		loot_seed = d.loot_seed
	objective_changed.emit()
	camp_changed.emit()
	equipment_changed.emit()
