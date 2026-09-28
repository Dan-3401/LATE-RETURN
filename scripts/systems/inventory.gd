class_name Inventory
extends RefCounted
## Fixed-size slot inventory with stacking.

signal changed
signal item_added(item: ItemData, count: int)

var size: int = 10
## Each slot: null or { "item": ItemData, "count": int }
var slots: Array = []


func _init(slot_count: int = 10) -> void:
	size = slot_count
	slots.resize(size)


## Adds items, returns how many could NOT be added.
func add(item: ItemData, count: int = 1) -> int:
	var left := count
	if item.stackable:
		for s in slots:
			if left <= 0:
				break
			if s != null and s.item.id == item.id and s.count < item.max_stack:
				var take := mini(left, item.max_stack - s.count)
				s.count += take
				left -= take
	for i in size:
		if left <= 0:
			break
		if slots[i] == null:
			var take := mini(left, item.max_stack if item.stackable else 1)
			slots[i] = {"item": item, "count": take}
			left -= take
	if left != count:
		item_added.emit(item, count - left)
		changed.emit()
	return left


func used_slots() -> int:
	var n := 0
	for s in slots:
		if s != null:
			n += 1
	return n


## Change the number of slots. Growing appends empty slots. Shrinking first
## packs items toward the front; unless `force` it never drops items (the
## caller must check used_slots() first).
func resize(new_size: int, force: bool = false) -> void:
	if new_size >= size:
		slots.resize(new_size)
		size = new_size
		changed.emit()
		return
	var packed: Array = []
	for s in slots:
		if s != null:
			packed.append(s)
	if packed.size() > new_size and not force:
		push_error("Inventory.resize would drop items")
		return
	slots.clear()
	slots.resize(new_size)
	for i in mini(packed.size(), new_size):
		slots[i] = packed[i]
	size = new_size
	changed.emit()


func can_add(item: ItemData, count: int = 1) -> bool:
	var room := 0
	for s in slots:
		if s == null:
			room += item.max_stack if item.stackable else 1
		elif item.stackable and s.item.id == item.id:
			room += item.max_stack - s.count
	return room >= count


func remove(item_id: StringName, count: int = 1) -> int:
	var left := count
	for i in range(size - 1, -1, -1):
		var s = slots[i]
		if s != null and s.item.id == item_id and left > 0:
			var take := mini(left, s.count)
			s.count -= take
			left -= take
			if s.count <= 0:
				slots[i] = null
	if left != count:
		changed.emit()
	return count - left


## Removes up to `count` items with this task tag (e.g. 1 food for a trip),
## taking from the last slots first. Returns how many were removed.
func remove_tag(tag: StringName, count: int = 1) -> int:
	var left := count
	for i in range(size - 1, -1, -1):
		var s = slots[i]
		if s != null and s.item.task_tag == tag and left > 0:
			var take := mini(left, s.count)
			s.count -= take
			left -= take
			if s.count <= 0:
				slots[i] = null
	if left != count:
		changed.emit()
	return count - left


func first_free() -> int:
	for i in size:
		if slots[i] == null:
			return i
	return -1


## item id -> total count
func counts() -> Dictionary:
	var out := {}
	for s in slots:
		if s != null:
			out[s.item.id] = int(out.get(s.item.id, 0)) + s.count
	return out


func count_item(item_id: StringName) -> int:
	var n := 0
	for s in slots:
		if s != null and s.item.id == item_id:
			n += s.count
	return n


func count_tag(tag: StringName) -> int:
	var n := 0
	for s in slots:
		if s != null and s.item.task_tag == tag:
			n += s.count
	return n


func clear() -> void:
	for i in size:
		slots[i] = null
	changed.emit()


func to_data() -> Array:
	var out: Array = []
	for s in slots:
		if s == null:
			out.append(null)
		else:
			out.append({"path": s.item.resource_path, "count": s.count})
	return out


func from_data(data: Array) -> void:
	if data.size() > size:
		slots.resize(data.size())
		size = data.size()
	for i in size:
		slots[i] = null
		if i < data.size() and data[i] != null:
			var item := load(data[i].path) as ItemData
			if item:
				slots[i] = {"item": item, "count": int(data[i].count)}
	changed.emit()
