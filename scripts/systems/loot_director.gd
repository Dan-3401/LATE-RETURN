class_name LootDirector
extends Node
## Decides the loot of every LootContainer in the level and keeps it in
## GameState.world so it persists across days, deaths and scene changes.
##
## Story day (first visit): roll every container, then guarantee the
## objective minimum by redistributing missing items into random containers.
## Free phase: containers keep their previous state; once per expedition a
## few already-searched containers refill with low value loot and, while the
## player has not found it yet, the special key may be hidden somewhere.
## All randomness uses the expedition seed so a restart reproduces it.

@export var world_prefix := "store"
@export var required := {&"water": 4, &"food": 4}
## Items used to fill shortfalls, matched by their task_tag.
@export var fill_items: Array[ItemData] = []
## Extra copies beyond the minimum so the last shelf is not always the one.
@export var bonus := {&"water": 1, &"food": 1}
## Free phase refill for searched containers.
@export var refill_table: LootTable
@export var refill_chance := 0.35
## Special key hidden in a random container in the free phase.
@export var key_item: ItemData
@export var key_base_chance := 0.45
@export var key_chance_per_day := 0.3
## World flag that makes the key unnecessary (e.g. the door is unlocked).
@export var key_flag := "warehouse_unlocked"
## Items that are always put into a specific container on the first roll.
@export var guaranteed_in: Dictionary = {}


func _ready() -> void:
	await get_tree().process_frame
	distribute()


func _containers() -> Array:
	var out: Array = []
	for c in get_tree().get_nodes_in_group(&"loot_container"):
		if c.data and c.data.loot_table:
			out.append(c)
	out.sort_custom(func(a, b): return String(a.name) < String(b.name))
	return out


func distribute() -> void:
	var containers := _containers()
	var rng := RandomNumberGenerator.new()
	var fresh := false
	for c in containers:
		c.persist_key = "%s/%s" % [world_prefix, c.name]
		if GameState.world_get(c.persist_key) == null:
			fresh = true
	if fresh:
		rng.seed = hash(GameState.loot_seed + hash(world_prefix))
		_first_roll(containers, rng)
	if GameState.is_free_phase():
		_prepare_expedition(containers)
	for c in containers:
		c.apply_state(GameState.world_get(c.persist_key))
	if OS.is_debug_build():
		var summary := {}
		for c in containers:
			for e in c.loot:
				summary[e.item.id] = summary.get(e.item.id, 0) + e.count
		print("[LootDirector:%s] loot=%s" % [world_prefix, summary])


func _first_roll(containers: Array, rng: RandomNumberGenerator) -> void:
	var rolled := {}
	for c in containers:
		if GameState.world_get(c.persist_key) == null:
			rolled[c.persist_key] = c.data.loot_table.roll(rng)
			if guaranteed_in.has(String(c.name)):
				LootTable._merge(rolled[c.persist_key], guaranteed_in[String(c.name)], 1)
	# the objective minimum only matters on the story day
	if not GameState.is_free_phase():
		for tag in required:
			var have := 0
			for k in rolled:
				for e in rolled[k]:
					if e.item.task_tag == tag:
						have += e.count
			var want: int = int(required[tag]) + int(bonus.get(tag, 0))
			var candidates: Array = containers.filter(func(c): return rolled.has(c.persist_key) and c.data.accepts_guaranteed)
			var pool: Array = fill_items.filter(func(i): return i.task_tag == tag)
			if candidates.is_empty() or pool.is_empty():
				continue
			while have < want:
				var c = candidates[rng.randi() % candidates.size()]
				LootTable._merge(rolled[c.persist_key], pool[rng.randi() % pool.size()], 1)
				have += 1
	for k in rolled:
		GameState.world_set(k, {"searched": false, "loot": _to_data(rolled[k])})


func _prepare_expedition(containers: Array) -> void:
	var exp: Dictionary = GameState.expedition
	var flag := "prepared_" + world_prefix
	if exp.is_empty() or exp.get(flag, false):
		return
	exp[flag] = true
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(int(exp.get("seed", 0)) + hash(world_prefix))
	# refill some searched containers with low value leftovers
	for c in containers:
		var st: Dictionary = GameState.world_get(c.persist_key)
		if st.searched and refill_table and rng.randf() < refill_chance:
			st.searched = false
			st.loot = _to_data(refill_table.roll(rng))
	# hide the key
	if key_item and not GameState.obtained_ever.has(key_item.id) and not GameState.world_get(key_flag, false) \
			and GameState.inventory.count_item(key_item.id) == 0 and not containers.is_empty():
		var days: int = maxi(GameState.day_index - 1, 0)
		if rng.randf() < key_base_chance + key_chance_per_day * days:
			var c = containers[rng.randi() % containers.size()]
			var st: Dictionary = GameState.world_get(c.persist_key)
			if st.searched:
				st.searched = false
				st.loot = []
			st.loot.append({"path": key_item.resource_path, "count": 1})
			print("[LootDirector] key hidden in ", c.name)


static func _to_data(loot: Array) -> Array:
	var out: Array = []
	for e in loot:
		out.append({"path": e.item.resource_path, "count": e.count})
	return out


static func from_data(data: Array) -> Array:
	var out: Array = []
	for e in data:
		var it := load(e.path) as ItemData
		if it:
			out.append({"item": it, "count": int(e.count)})
	return out
