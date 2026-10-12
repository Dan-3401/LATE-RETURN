extends SceneTree
## Backpack rules (Demo v2.01): the character has no slots of his own, every
## backpack slot comes from the worn backpack (+ pockets such as the work
## uniform). A backpack never goes inside a backpack — it is worn or kept in
## another container (the camp storage). It can only be taken off when what
## is in the bag still fits elsewhere. Old saves with a backpack in the bag
## are repaired on load. Real drags on the storage screen.
##   godot --path . -s res://tools/tests/test_backpack.gd -- [shot_dir]

var shot_dir := ""
var failures: Array[String] = []
var GS: Node
var SM: Node
var SS: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	shot_dir = args[0] if args.size() > 0 else ""
	_run.call_deferred()


func check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + msg)
	if not cond:
		failures.append(msg)


func shot(n: String) -> void:
	if shot_dir == "" or DisplayServer.get_name() == "headless":
		return
	await process_frame
	root.get_texture().get_image().save_png(shot_dir + "/" + n + ".png")


func wait(t: float) -> void:
	await create_timer(t).timeout


func press(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	await physics_frame
	var ev2 := InputEventAction.new()
	ev2.action = action
	ev2.pressed = false
	Input.parse_input_event(ev2)
	await physics_frame


func wait_scene(path: String, timeout: float, old: Node = null) -> bool:
	if old == null:
		old = current_scene
	var t := 0.0
	while t < timeout and current_scene == old and is_instance_valid(old):
		await wait(0.1)
		t += 0.1
	while t < timeout:
		if current_scene and current_scene.scene_file_path == path and not SM.is_busy():
			await wait(0.3)
			return true
		await wait(0.2)
		t += 0.2
	return false


func goto(path: String) -> bool:
	var old := current_scene
	SM.change_scene(path, 0.05)
	var ok := await wait_scene(path, 20.0, old)
	SM.set_black(0.0)
	return ok


func player():
	return get_first_node_in_group(&"player")


func item(id: String) -> ItemData:
	return load("res://resources/items/%s.tres" % id)


## Everything that exists anywhere (bag, equipment, storage, overflow).
func grand_total() -> Dictionary:
	var out: Dictionary = GS.item_counts()
	for inv in [GS.storage, GS.pending]:
		var c: Dictionary = inv.counts()
		for id in c:
			out[id] = int(out.get(id, 0)) + c[id]
	return out


func drag(from: Control, to: Control) -> void:
	var k := Vector2(root.size) / Vector2(480, 270)
	var a := from.get_global_rect().get_center() * k
	var b := to.get_global_rect().get_center() * k
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = a
	down.global_position = a
	down.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(down)
	await process_frame
	for i in range(1, 13):
		var m := InputEventMouseMotion.new()
		var pos := a.lerp(b, i / 12.0)
		m.position = pos
		m.global_position = pos
		m.relative = (b - a) / 12.0
		m.button_mask = MOUSE_BUTTON_MASK_LEFT
		root.push_input(m)
		await process_frame
	await wait(0.1)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = b
	up.global_position = b
	root.push_input(up)
	await wait(0.15)


func find_slot(inv, id: StringName) -> int:
	for i in inv.size:
		var s = inv.slots[i]
		if s and s.item.id == id:
			return i
	return -1


func bag(i: int) -> Dictionary:
	return {"kind": "bag", "index": i}


func eq(slot: String) -> Dictionary:
	return {"kind": "equip", "slot": slot}


func st(i: int) -> Dictionary:
	return {"kind": "storage", "index": i}


func _run() -> void:
	GS = root.get_node("/root/GameState")
	SM = root.get_node("/root/SceneManager")
	SS = root.get_node("/root/SaveSystem")
	await wait(0.3)
	var IN_BAG: String = GS.BACKPACK_IN_BAG
	var NOT_EMPTY: String = GS.BACKPACK_NOT_EMPTY
	var backpack := item("backpack")

	# --- capacity comes only from equipment ------------------------------------------------
	GS.new_game()
	check(GS.BASE_CAPACITY == 0, "the character himself has no slots")
	check(backpack.capacity_bonus == 10 and GS.equip_get("backpack") == backpack, "the starting backpack is worn and gives 10 slots")
	check(GS.capacity() == 10 and GS.inventory.size == 10, "bag = the backpack's 10 slots")
	check(not backpack.fits_in_bag() and item("work_uniform").fits_in_bag() and item("water").fits_in_bag(), "fits_in_bag() decided by equipment_category only")

	# --- a backpack never goes into the bag ---------------------------------------------------
	check(GS.move_item(eq("backpack"), bag(0), true) == IN_BAG, "worn backpack -> bag slot refused: " + IN_BAG)
	check(GS.unequip_to_bag("backpack") == IN_BAG and GS.equip_get("backpack") == backpack, "卸下 refused too, the backpack stays on")
	var p_said: Array[String] = []

	# --- camp: storage screen ------------------------------------------------------------------
	GS.inventory.add(item("water"), 3)
	GS.inventory.add(item("parts"), 5)
	GS.start_free_phase()
	check(await goto("res://scenes/maps/camp_hub.tscn"), "camp hub")
	await wait(0.8)
	var hub = current_scene
	var p = player()
	p.said.connect(func(t): p_said.append(t))
	hub.open_storage()
	await wait(0.4)
	var ui = hub.storage_ui
	check(ui.is_open(), "storage screen open")
	var bag_before: Array = GS.inventory.to_data()
	var total_before: Dictionary = grand_total()
	check(GS.move_item(eq("backpack"), st(GS.storage.first_free()), true) == NOT_EMPTY, "dry run: a backpack with things in it cannot be taken off")
	await drag(ui.gear_slots["backpack"], ui.storage_slots[GS.storage.first_free()])
	check(GS.equip_get("backpack") == backpack and GS.inventory.to_data() == bag_before and grand_total() == total_before, "drag refused: nothing moved, nothing lost")
	await shot("bp01_refused_not_empty")
	# empty the bag into the storage, then the backpack can go in
	for id in [&"water", &"parts"]:
		await drag(ui.bag_slots[find_slot(GS.inventory, id)], ui.storage_slots[GS.storage.first_free()])
	check(GS.inventory.used_slots() == 0, "bag emptied into the storage")
	await drag(ui.gear_slots["backpack"], ui.storage_slots[GS.storage.first_free()])
	check(GS.equip_get("backpack") == null and GS.storage.count_item(&"backpack") == 1, "empty backpack stored in the camp storage")
	check(GS.capacity() == 0 and GS.inventory.size == 0 and ui.bag_slots.size() == 0, "no backpack = no bag slots (screen shows none)")
	check(grand_total() == total_before, "nothing lost while moving things around")
	await shot("bp02_no_backpack")

	# --- without a backpack nothing can be picked up ---------------------------------------
	var left: int = p.receive_item(item("water"), 1)
	check(left == 1 and GS.inventory.count_item(&"water") == 0 and p_said.has("已经装不下了。"), "no backpack: pickups refused (已经装不下了。)")

	# --- pockets (uniform) only, and a backpack lying in the storage ------------------------
	GS.stash(item("work_uniform"), 1)
	await wait(0.1)
	await drag(ui.storage_slots[find_slot(GS.storage, &"work_uniform")], ui.gear_slots["clothing"])
	check(GS.equip_get("clothing") != null and GS.inventory.size == 5 and ui.bag_slots.size() == 5, "uniform pockets alone: 5 slots")
	var bp_i := find_slot(GS.storage, &"backpack")
	check(GS.move_item(st(bp_i), bag(0), true) == IN_BAG, "storage backpack -> bag slot refused (red frame)")
	await drag(ui.storage_slots[bp_i], ui.bag_slots[0])
	check(GS.storage.count_item(&"backpack") == 1 and GS.inventory.count_item(&"backpack") == 0, "drag refused, backpack stays in the storage")
	# a bag item may not be swapped with a backpack either
	GS.inventory.add(item("parts"), 1)
	await wait(0.1)
	check(GS.move_item(bag(find_slot(GS.inventory, &"parts")), st(bp_i), true) == IN_BAG, "swap that would put the backpack into the bag refused")
	# put it back on: 10 + 5
	await drag(ui.storage_slots[bp_i], ui.gear_slots["backpack"])
	check(GS.equip_get("backpack") == backpack and GS.inventory.size == 15 and ui.bag_slots.size() == 15, "backpack worn again: 10 + 5 = 15 slots")
	await shot("bp03_backpack_and_uniform")
	# a backpack lying on the ground cannot be picked into the bag
	p_said.clear()
	left = p.receive_item(backpack, 1)
	check(left == 1 and GS.inventory.count_item(&"backpack") == 0 and p_said.has(IN_BAG), "picking up a backpack into the bag refused")
	ui.close()
	await wait(0.2)

	# --- backpack screen without a backpack -------------------------------------------------
	GS.inventory.remove(&"parts", 99)
	GS.move_item(eq("backpack"), st(GS.storage.first_free()))
	GS.move_item(eq("clothing"), st(GS.storage.first_free()))
	check(GS.inventory.size == 0, "no backpack, no uniform: 0 slots")
	await press("inventory")
	await wait(0.4)
	check(hub.hud.inventory_ui.is_open(), "backpack screen still opens with 0 slots")
	await shot("bp04_inventory_no_backpack")
	await press("inventory")
	await wait(0.2)

	# --- old saves: a backpack inside the bag is repaired on load ----------------------------
	GS.new_game()
	var snap: Dictionary = GS.snapshot()
	snap.equipment["backpack"] = null
	snap.capacity = 10
	snap.inventory = [{"path": backpack.resource_path, "count": 1}, {"path": item("water").resource_path, "count": 2}]
	GS.apply_snapshot(snap)
	check(GS.equip_get("backpack") == backpack and GS.inventory.count_item(&"backpack") == 0 and GS.inventory.count_item(&"water") == 2 and GS.inventory.size == 10, "old save: backpack in the bag is worn again")
	snap = GS.snapshot()
	snap.inventory = [{"path": backpack.resource_path, "count": 1}]
	GS.apply_snapshot(snap)
	check(GS.equip_get("backpack") == backpack and GS.inventory.count_item(&"backpack") == 0 and GS.storage.count_item(&"backpack") == 1, "old save: a second backpack in the bag goes to the camp storage")
	check(GS.inventory.size == 10, "bag size follows the worn backpack after loading")

	SS.delete_save()
	print("RESULT: %s (%d failures)" % ["OK" if failures.is_empty() else "FAILED", failures.size()])
	quit(0 if failures.is_empty() else 1)
