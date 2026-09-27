class_name LootDirector
extends Node
## Rolls loot for every LootContainer in the level when it loads, then
## guarantees the objective minimum by redistributing missing items into
## random containers. After that the loot is locked for this run.

@export var required := {&"water": 4, &"food": 4}
## Items used to fill shortfalls, matched by their task_tag.
@export var fill_items: Array[ItemData] = []
## Extra copies beyond the minimum so the last shelf is not always the one.
@export var bonus := {&"water": 1, &"food": 1}


func _ready() -> void:
	# wait until all containers are in the tree
	await get_tree().process_frame
	distribute()


func distribute() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = GameState.loot_seed
	var containers: Array = []
	for c in get_tree().get_nodes_in_group(&"loot_container"):
		if c.data and c.data.loot_table:
			containers.append(c)
	containers.sort_custom(func(a, b): return String(a.get_path()) < String(b.get_path()))
	# 1. roll every container
	for c in containers:
		c.loot = c.data.loot_table.roll(rng)
	# 2. count objective items
	for tag in required:
		var have := 0
		for c in containers:
			for e in c.loot:
				if e.item.task_tag == tag:
					have += e.count
		var want: int = int(required[tag]) + int(bonus.get(tag, 0))
		# 3. top up into random eligible containers
		var candidates: Array = containers.filter(func(c): return c.data.accepts_guaranteed)
		var pool: Array = fill_items.filter(func(i): return i.task_tag == tag)
		if candidates.is_empty() or pool.is_empty():
			push_warning("LootDirector: cannot guarantee '%s'" % tag)
			continue
		while have < want:
			var c = candidates[rng.randi() % candidates.size()]
			var item: ItemData = pool[rng.randi() % pool.size()]
			LootTable._merge(c.loot, item, 1)
			have += 1
	if OS.is_debug_build():
		var summary := {}
		for c in containers:
			for e in c.loot:
				summary[e.item.id] = summary.get(e.item.id, 0) + e.count
		print("[LootDirector] seed=%d loot=%s" % [GameState.loot_seed, summary])
