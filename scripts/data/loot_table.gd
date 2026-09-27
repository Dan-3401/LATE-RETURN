class_name LootTable
extends Resource
## Weighted loot table. Each roll picks one entry (or nothing).

@export var entries: Array[LootEntry] = []
@export var rolls_min: int = 1
@export var rolls_max: int = 2
## Weight of "nothing" for each roll.
@export var empty_weight: float = 1.0


## Returns an Array of { "item": ItemData, "count": int }.
func roll(rng: RandomNumberGenerator) -> Array:
	var result: Array = []
	var rolls := rng.randi_range(rolls_min, rolls_max)
	var total := empty_weight
	for e in entries:
		total += e.weight
	for i in rolls:
		var pick := rng.randf() * total
		if pick < empty_weight:
			continue
		pick -= empty_weight
		for e in entries:
			if pick < e.weight:
				_merge(result, e.item, rng.randi_range(e.min_count, e.max_count))
				break
			pick -= e.weight
	return result


static func _merge(result: Array, item: ItemData, count: int) -> void:
	for r in result:
		if r.item == item and item.stackable:
			r.count += count
			return
	result.append({"item": item, "count": count})
