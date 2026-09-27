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

const START_AMMO := 10
const BASE_CAPACITY := 10
const PISTOL_WEAPON := preload("res://resources/weapons/pistol.tres")
const KNIFE_WEAPON := preload("res://resources/weapons/knife.tres")
const BACKPACK_ITEM := preload("res://resources/items/backpack.tres")
## The date of day 0 (the first day, the linear story day).
const START_DATE := {"year": 2025, "month": 9, "day": 28, "hour": 12, "minute": 0, "second": 0}
const MAIN_QUEST_TITLE := "寻找能够治疗哮喘病的药"
## Items that are handed over to the camp storage when coming home.
const CAMP_TAGS := [&"food", &"water"]
## Items counted as a "rare discovery" for the diary.
const RARE_ITEMS := [&"warehouse_key", &"work_uniform"]

enum Phase { STORY, FREE }

var inventory := Inventory.new(BASE_CAPACITY)
## slot -> ItemData or null
var equipment := {}
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
	equipment = {
		"helmet": null,
		"armor": null,
		"clothing": null,
		"primary": PISTOL_WEAPON.item,
		"melee": KNIFE_WEAPON.item,
		"throwable": null,
		"backpack": BACKPACK_ITEM,
	}
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
func capacity() -> int:
	var cap := BASE_CAPACITY
	for k in equipment:
		var it: ItemData = equipment[k]
		if it:
			cap += it.capacity_bonus
	return cap


## Equip an item from the inventory into its slot. Returns "" or an error line.
func equip_item(item: ItemData) -> String:
	if item.equip_slot == &"":
		return "这个不能装备。"
	var slot := String(item.equip_slot)
	var old: ItemData = equipment.get(slot)
	if item.equip_slot == &"throwable":
		# throwables stay in the backpack; the slot only selects which one to throw
		equipment[slot] = item
		equipment_changed.emit()
		inventory.changed.emit()
		return ""
	if old:
		var err := unequip(slot)
		if err != "":
			return err
	inventory.remove(item.id, 1)
	equipment[slot] = item
	inventory.resize(capacity())
	equipment_changed.emit()
	return ""


## Unequip a slot back into the backpack. Refuses if it would lose items.
func unequip(slot: String) -> String:
	var item: ItemData = equipment.get(slot)
	if item == null:
		return ""
	if slot == "throwable":
		equipment[slot] = null
		equipment_changed.emit()
		inventory.changed.emit()
		return ""
	var new_cap := capacity() - item.capacity_bonus
	# the unequipped item itself needs a slot too
	if inventory.used_slots() + 1 > new_cap:
		return "背包里的东西太多了。"
	equipment[slot] = null
	inventory.resize(new_cap)
	inventory.add(item, 1)
	equipment_changed.emit()
	return ""


func throwable() -> ItemData:
	var it: ItemData = equipment.get("throwable")
	if it and inventory.count_item(it.id) <= 0:
		return null
	return it


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
	var counts := {}
	for s in inventory.slots:
		if s != null:
			counts[s.item.id] = counts.get(s.item.id, 0) + s.count
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
	var counts := {}
	for s in inventory.slots:
		if s != null:
			counts[s.item.id] = counts.get(s.item.id, 0) + s.count
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
		eq[k] = equipment[k].resource_path if equipment[k] else ""
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
	hp = checkpoint.hp
	oxygen = checkpoint.oxygen
	ammo = checkpoint.ammo
	inventory.resize(int(checkpoint.get("capacity", BASE_CAPACITY)), true)
	inventory.from_data(checkpoint.inventory)
	for k in checkpoint.equipment:
		var p: String = checkpoint.equipment[k]
		equipment[k] = load(p) if p != "" else null
	objective = checkpoint.objective.duplicate(true)
	flags = checkpoint.flags.duplicate(true)
	if checkpoint.has("phase"):
		phase = checkpoint.phase
		day_index = checkpoint.day_index
		camp = checkpoint.camp.duplicate(true)
		expedition = checkpoint.expedition.duplicate(true)
		daily = checkpoint.daily.duplicate(true)
		obtained_ever = checkpoint.obtained_ever.duplicate(true)
		world = checkpoint.world.duplicate(true)
		spawn_point = &"region_start" if is_free_phase() else &""
	objective_changed.emit()
	camp_changed.emit()
	equipment_changed.emit()
