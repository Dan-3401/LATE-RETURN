extends SceneTree
## Hand equipment + drag & drop (spec 85-98, 110):
## three HAND slots on keys 1/2/3, any hand item in any slot, one active
## item, clean switching, category-based compatibility, drag & drop in the
## backpack screen with live green/red/neutral frames, refused drops,
## active item removed -> empty hands, persistence over scene change,
## checkpoint, save/load and a new day.
##   godot --path . -s res://tools/tests/test_hand_equipment.gd -- [shot_dir]

var shot_dir := ""
var failures: Array[String] = []
var GS: Node
var SM: Node
var SS: Node
var IS   # item_slot.gd, loaded after the autoloads exist


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


func player():
	return get_first_node_in_group(&"player")


func item(id: String) -> ItemData:
	return load("res://resources/items/%s.tres" % id)


func bag(i: int) -> Dictionary:
	return {"kind": "bag", "index": i}


func eq(slot: String) -> Dictionary:
	return {"kind": "equip", "slot": slot}


func bag_index(id: StringName) -> int:
	for i in GS.inventory.size:
		var s = GS.inventory.slots[i]
		if s != null and s.item.id == id:
			return i
	return -1


func hands_state() -> Array:
	return [GS.equip_get("hand1"), GS.equip_get("hand2"), GS.equip_get("hand3")]


## Real mouse drag in the window: press on `from`, move over `to`, run
## `mid` while hovering, release.
func drag(from: Control, to: Control, mid: Callable = Callable()) -> void:
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
	if mid.is_valid():
		await mid.call()
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = b
	up.global_position = b
	root.push_input(up)
	await wait(0.15)


func _run() -> void:
	GS = root.get_node("/root/GameState")
	SM = root.get_node("/root/SceneManager")
	SS = root.get_node("/root/SaveSystem")
	IS = load("res://scripts/ui/item_slot.gd")
	await wait(0.3)
	GS.new_game()
	GS.start_free_phase()
	var old := current_scene
	SM.change_scene("res://scenes/maps/camp_hub.tscn", 0.2)
	check(await wait_scene("res://scenes/maps/camp_hub.tscn", 20.0, old), "camp hub")
	await wait(0.5)
	var p = player()
	var pistol := item("pistol")
	var knife := item("knife")
	var bottle := item("empty_bottle")

	# --- data: three HAND slots, category based compatibility -----------------------
	var hand_types := 0
	for s in GS.SLOT_TYPES:
		if GS.SLOT_TYPES[s] == ItemData.SlotType.HAND:
			hand_types += 1
	check(GS.HAND_SLOTS.size() == 3 and hand_types == 3, "exactly three hand slots")
	check(hands_state() == [pistol, knife, null], "default: 1 pistol, 2 knife, 3 empty")
	for id in ["cash", "warehouse_key", "water", "canned_food", "junk", "work_uniform"]:
		var ok := false
		for s in GS.HAND_SLOTS:
			ok = ok or GS.can_accept(s, item(id))
		check(not ok, "%s cannot go into a hand slot" % id)
	for id in ["pistol", "knife", "empty_bottle"]:
		var ok := true
		for s in GS.HAND_SLOTS:
			ok = ok and GS.can_accept(s, item(id))
		check(ok, "%s fits every hand slot" % id)
	var fake := ItemData.new()
	fake.id = &"fake_gun"
	fake.display_name = "手枪"
	check(not GS.can_accept("hand1", fake), "compatibility is by category, not by name")
	check(not GS.can_accept("clothing", bottle) and GS.can_accept("clothing", item("work_uniform")), "clothing slot takes clothing only")

	# --- keys 1/2/3, one active item, clean switching ------------------------------------
	GS.inventory.add(bottle, 3)
	check(GS.move_item(bag(bag_index(&"empty_bottle")), eq("hand3")) == "", "bottles into slot 3")
	await press("hand_1")
	await wait(0.2)
	check(p.hands.active_item == pistol and p.weapons.current != null and p.weapons.current.is_ranged and p.arm_pivot.visible, "1 -> pistol out (Gun)")
	await shot("h01_pistol_active")
	await press("hand_3")
	await wait(0.2)
	check(p.hands.active_item == bottle and p.throw.is_ready and p.throw_pivot.visible, "3 -> bottle ready (Throwable)")
	check(p.weapons.current == null and not p.arm_pivot.visible, "gun put away before the bottle comes out")
	await shot("h02_bottle_active")
	await press("hand_2")
	await wait(0.2)
	check(p.hands.active_item == knife and p.weapons.current != null and not p.weapons.current.is_ranged and not p.throw.is_ready, "2 -> knife (Melee), throw aim left")
	await press("hand_2")
	await wait(0.2)
	check(p.hands.active_item == null and p.weapons.current == null and not p.throw.is_ready and not p.arm_pivot.visible and not p.throw_pivot.visible, "same key again -> empty hands")
	var bar = current_scene.hud.quick_bar
	await press("hand_1")
	await wait(0.2)
	check(bar._slots[0].theme_type_variation == &"SlotFocusPanel" and bar._slots[1].theme_type_variation == &"SlotPanel" and bar._marker.visible, "quick bar highlights the active slot")
	await shot("h03_quickbar")

	# --- any hand item in any slot ------------------------------------------------------
	check(GS.move_item(eq("hand1"), eq("hand3")) == "", "slot 1 <-> slot 3")
	await wait(0.1)
	check(hands_state() == [bottle, knife, pistol], "pistol now in 3, bottles in 1")
	check(p.hands.active_item == bottle and p.throw.is_ready and p.weapons.current == null, "active slot 1 refreshed to the bottle")
	check(GS.move_item(eq("hand2"), eq("hand1")) == "", "slot 2 <-> slot 1")
	check(hands_state() == [knife, bottle, pistol], "knife in 1, bottles in 2")
	await wait(0.1)
	check(p.hands.active_item == knife and not p.throw.is_ready, "active slot 1 now the knife")
	await press("hand_3")
	await wait(0.2)
	check(p.hands.active_item == pistol and p.weapons.current.is_ranged, "pistol works from slot 3")
	await press("hand_2")
	await wait(0.2)
	check(p.hands.active_item == bottle and p.throw.is_ready, "bottle works from slot 2")
	# two melee weapons, no gun
	GS.inventory.add(knife, 1)
	check(GS.move_item(bag(bag_index(&"knife")), eq("hand3")) == "" and GS.equip_get("hand3") == knife, "second knife replaces the pistol in slot 3")
	check(GS.inventory.count_item(&"pistol") == 1, "the pistol went back to the backpack (swap)")

	# --- active item removed -> empty hands ------------------------------------------------
	await press("hand_3")
	await wait(0.2)
	check(p.weapons.current != null, "knife from slot 3 out")
	var free_i := -1
	for i in GS.inventory.size:
		if GS.inventory.slots[i] == null:
			free_i = i
			break
	check(GS.move_item(eq("hand3"), bag(free_i)) == "", "slot 3 -> backpack")
	await wait(0.1)
	check(GS.equip_get("hand3") == null and p.weapons.current == null and not p.arm_pivot.visible and p.hands.active_item == null, "active item gone -> empty hands at once")

	# --- backpack moves: move, merge, overflow, swap ----------------------------------------
	GS.inventory.clear()
	GS.inventory.slots[0] = {"item": item("water"), "count": 3}
	GS.inventory.slots[1] = {"item": item("water"), "count": 4}
	GS.inventory.slots[2] = {"item": item("water"), "count": 8}
	GS.inventory.slots[3] = {"item": item("cash"), "count": 20}
	check(GS.move_item(bag(0), bag(1)) == "" and GS.inventory.slots[0] == null and GS.inventory.slots[1].count == 7, "stack merge 3 + 4 = 7")
	check(GS.move_item(bag(1), bag(2)) == "" and GS.inventory.slots[2].count == 10 and GS.inventory.slots[1].count == 5, "merge up to max stack, rest stays")
	check(GS.move_item(bag(3), bag(1)) == "" and GS.inventory.slots[1].item.id == &"cash" and GS.inventory.slots[3].item.id == &"water", "different items swap")
	check(GS.move_item(bag(1), bag(9)) == "" and GS.inventory.slots[9].item.id == &"cash" and GS.inventory.slots[1] == null, "move into an empty cell")
	var cash_count: int = GS.inventory.slots[9].count
	check(GS.move_item(bag(9), eq("hand1")) != "", "cash -> hand slot refused")
	check(GS.inventory.slots[9].item.id == &"cash" and GS.inventory.slots[9].count == cash_count and GS.equip_get("hand1") == knife, "refused: cash stays, slot unchanged")

	# --- drag & drop in the backpack screen ------------------------------------------------
	GS.inventory.add(pistol, 1)
	GS.inventory.add(item("warehouse_key"), 1)
	var inv = current_scene.hud.inventory_ui
	await press("inventory")
	await wait(0.4)
	check(inv.is_open(), "backpack screen open")
	var cash_cell = inv.bag_slots[9]
	var hand1 = inv.equip_slots["hand1"]
	var seen := {}
	await drag(cash_cell, hand1, func():
		seen["cash"] = hand1.frame_color()
		await shot("h04_drag_cash_red"))
	check(seen.get("cash") == IS.BAD, "cash over a hand slot: red frame while dragging")
	check(GS.inventory.slots[9] != null and GS.inventory.slots[9].item.id == &"cash" and GS.equip_get("hand1") == knife, "cash dropped on a hand slot returns to its cell")
	check(hand1.frame_color().a == 0.0, "frame cleared after the drop")
	var key_cell = inv.bag_slots[bag_index(&"warehouse_key")]
	var hand2 = inv.equip_slots["hand2"]
	await drag(key_cell, hand2, func(): seen["key"] = hand2.frame_color())
	check(seen.get("key") == IS.BAD and GS.equip_get("hand2") == bottle and bag_index(&"warehouse_key") >= 0, "key cannot be dragged into a hand slot")
	var pistol_cell = inv.bag_slots[bag_index(&"pistol")]
	var hand3 = inv.equip_slots["hand3"]
	await drag(pistol_cell, hand3, func():
		seen["pistol"] = hand3.frame_color()
		await shot("h05_drag_pistol_green"))
	check(seen.get("pistol") == IS.OK_EQUIP, "pistol over a hand slot: green frame")
	check(GS.equip_get("hand3") == pistol and GS.inventory.count_item(&"pistol") == 0, "backpack -> equipment slot by drag")
	await drag(hand2, hand1)
	check(hands_state() == [bottle, knife, pistol], "equipment slot <-> equipment slot by drag (swap)")
	var empty_cell = null
	for c in inv.bag_slots:
		if c.item == null:
			empty_cell = c
			break
	await drag(hand2, empty_cell, func(): seen["bag"] = empty_cell.frame_color())
	check(seen.get("bag") == IS.NEUTRAL, "empty backpack cell: neutral frame")
	check(GS.equip_get("hand2") == null and empty_cell.item == knife, "equipment slot -> backpack by drag")
	await drag(empty_cell, hand2)
	check(GS.equip_get("hand2") == knife, "and back again")
	var water_cell = inv.bag_slots[bag_index(&"water")]
	var far_cell = inv.bag_slots[8]
	var water_n: int = water_cell.count
	await drag(water_cell, far_cell)
	check(far_cell.item != null and far_cell.item.id == &"water" and far_cell.count == water_n, "backpack -> backpack by drag")
	await shot("h06_inventory_after")
	await press("inventory")
	await wait(0.3)

	# --- persistence: scene change, checkpoint, save/load, new day ---------------------------------
	var layout := hands_state()
	var bag_data: Array = GS.inventory.to_data()
	old = current_scene
	SM.change_scene("res://scenes/maps/camp_hub.tscn", 0.2)
	check(await wait_scene("res://scenes/maps/camp_hub.tscn", 20.0, old), "scene change")
	check(hands_state() == layout and GS.inventory.to_data() == bag_data, "hand slots and backpack kept over a scene change")
	GS.save_checkpoint(&"test", "res://scenes/maps/camp_hub.tscn")
	GS.move_item(eq("hand1"), eq("hand2"))
	GS.restore_checkpoint()
	check(hands_state() == layout, "checkpoint restores the hand slots")
	var bottles: int = GS.equip_count("hand1")
	SS.save_here("res://scenes/maps/camp_hub.tscn", "学校营地")
	GS.new_game()
	check(hands_state() != layout, "(new game resets)")
	SS.load_game()
	check(hands_state() == layout and GS.equip_count("hand1") == bottles, "save / load keeps the hand slots and counts")
	GS.new_day()
	check(hands_state() == layout, "a new day keeps the hand slots")
	p = player()
	check(p.hands.active_item == null, "each scene starts with empty hands")

	SS.delete_save()
	print("RESULT: %s (%d failures)" % ["OK" if failures.is_empty() else "FAILED", failures.size()])
	quit(0 if failures.is_empty() else 1)
