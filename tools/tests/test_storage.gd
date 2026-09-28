extends SceneTree
## Camp storage (spec 156-172): the storage is the only source of truth
## for camp supplies. Automatic settlement of everything picked up on an
## outing (junk, money, materials, a newly worn uniform...), carried-out
## gear stays, the storage entity + 40-slot screen with drag & drop,
## trip costs taken from real items (HUD in sync), checkpoint without
## double charge / refund, a full storage never swallows anything,
## persistence over scene change / new day / save-load, visual stages.
##   godot --path . -s res://tools/tests/test_storage.gd -- [shot_dir]

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


func _run() -> void:
	GS = root.get_node("/root/GameState")
	SM = root.get_node("/root/SceneManager")
	SS = root.get_node("/root/SaveSystem")
	await wait(0.3)
	check(not "camp" in GS or GS.get("camp") == null, "no separate food / water counter any more")

	# --- start of the free phase: day-1 finds + the old stock go into the storage ------------
	GS.new_game()
	GS.inventory.add(item("water"), 4)
	GS.inventory.add(item("canned_food"), 3)
	GS.inventory.add(item("junk"), 2)
	GS.start_free_phase()
	check(GS.storage.size == 40, "camp storage has 40 slots")
	check(GS.camp_water() == 5 and GS.camp_food() == 5 and GS.storage.count_item(&"junk") == 2 and GS.inventory.used_slots() == 0, "day-1 finds (junk too) + old stock stored (food %d water %d)" % [GS.camp_food(), GS.camp_water()])
	check(await goto("res://scenes/maps/camp_hub.tscn"), "camp hub")
	await wait(1.0)
	var hub = current_scene
	var hud = hub.hud
	check(hud.camp_food.text == str(GS.camp_food()) and hud.camp_water.text == str(GS.camp_water()), "top-right counts come from the storage")

	# --- the storage entity and its screen ---------------------------------------------------
	var p = player()
	p.global_position = Vector2(hub.storage_interact.global_position.x, 224)
	await wait(0.5)
	check(p.interaction.focused == hub.storage_interact and hub.storage_interact.prompt_text == "互动", "[F] 互动 at the storage corner")
	await shot("st01_storage_corner")
	await press("interact")
	await wait(0.4)
	var ui = hub.storage_ui
	check(ui.is_open() and ui.storage_slots.size() == 40, "storage screen with 40 slots")
	check(ui._storage_title.text.contains("/ 40") and ui._bag_title.text.contains("背包"), "storage and backpack side by side")
	await shot("st02_storage_ui")
	# drag water: storage -> backpack; the HUD follows at once
	var water_i: int = -1
	for i in GS.storage.size:
		var s = GS.storage.slots[i]
		if s and s.item.id == &"water":
			water_i = i
	var water_before: int = GS.camp_water()
	await drag(ui.storage_slots[water_i], ui.bag_slots[0])
	check(GS.inventory.count_item(&"water") > 0 and GS.camp_water() < water_before, "storage -> backpack by drag")
	check(hud.camp_water.text == str(GS.camp_water()), "HUD water follows the storage at once (%s)" % hud.camp_water.text)
	# and back (merges into the stack in the storage)
	var target_i: int = GS.storage.first_free()
	await drag(ui.bag_slots[0], ui.storage_slots[target_i])
	check(GS.camp_water() == water_before and GS.inventory.count_item(&"water") == 0, "backpack -> storage by drag")
	# storage -> storage swap
	var a_i := 0
	var b_i := 1
	var a_id: StringName = GS.storage.slots[a_i].item.id
	var b_id: StringName = GS.storage.slots[b_i].item.id
	await drag(ui.storage_slots[a_i], ui.storage_slots[b_i])
	check(a_id == b_id or (GS.storage.slots[a_i].item.id == b_id and GS.storage.slots[b_i].item.id == a_id), "storage <-> storage swap")
	# take bottles for the trip into a hand slot (loadout preparation)
	GS.stash(item("empty_bottle"), 3)
	await wait(0.1)
	var bi := -1
	for i in GS.storage.size:
		var s = GS.storage.slots[i]
		if s and s.item.id == &"empty_bottle":
			bi = i
	await drag(ui.storage_slots[bi], ui.hand_slots["hand3"])
	check(GS.equip_get("hand3") == item("empty_bottle") and GS.equip_count("hand3") == 3, "storage -> hand slot 3 (bottles for the trip)")
	await press("inventory")
	await wait(0.3)
	check(not ui.is_open(), "storage screen closes")

	# --- the trip cost comes out of the storage --------------------------------------------
	var total_before: Dictionary = grand_total()
	var pre: Dictionary = GS.camp_view()
	check(GS.begin_expedition(load("res://resources/locations/store.tres")), "departure")
	check(GS.camp_food() == pre.food - 1 and GS.camp_water() == pre.water - 1, "food -1 water -1 taken from the storage")
	await wait(0.1)
	check(hud.camp_food.text == str(GS.camp_food()) and hud.camp_water.text == str(GS.camp_water()), "HUD synced after paying")
	var after_pay: Dictionary = GS.camp_view()
	var storage_after_pay: Array = GS.storage.to_data()
	check(await goto("res://scenes/maps/region_store.tscn"), "region")
	check(GS.checkpoint.get("storage") == storage_after_pay, "expedition checkpoint holds the paid storage")
	# pick things up (the real pickup path: inventory.add)
	GS.inventory.add(item("water"), 3)
	GS.inventory.add(item("cash"), 1200)
	GS.inventory.add(item("junk"), 3)
	GS.inventory.add(item("parts"), 1)
	GS.inventory.add(item("warehouse_key"), 1)
	GS.inventory.add(item("work_uniform"), 1)
	var ui_i := -1
	for i in GS.inventory.size:
		var s = GS.inventory.slots[i]
		if s and s.item.id == &"work_uniform":
			ui_i = i
	check(GS.quick_equip(ui_i) == "" and GS.inventory.size == 15, "found uniform put on")
	GS.consume_hand("hand3", 1)   # one carried bottle thrown
	# die -> restart: nothing refunded, nothing charged twice
	GS.restore_checkpoint()
	check(GS.camp_view() == after_pay and GS.storage.to_data() == storage_after_pay, "restart: storage exactly as after paying")
	check(GS.inventory.count_item(&"cash") == 0 and GS.equip_count("hand3") == 3, "restart: pickups gone, bottles back")
	# pick up again, then go home through the gate
	GS.inventory.add(item("water"), 3)
	GS.inventory.add(item("cash"), 1200)
	GS.inventory.add(item("junk"), 3)
	GS.inventory.add(item("parts"), 1)
	GS.inventory.add(item("warehouse_key"), 1)
	GS.inventory.add(item("work_uniform"), 1)
	for i in GS.inventory.size:
		var s = GS.inventory.slots[i]
		if s and s.item.id == &"work_uniform":
			GS.quick_equip(i)
			break
	GS.consume_hand("hand3", 1)
	var storage_before_home: Dictionary = GS.storage.counts()
	GS.mark_location_visited()
	var region = current_scene
	region._on_gate(null)
	check(await wait_scene("res://scenes/maps/camp_hub.tscn", 20.0, region), "home")
	await wait(2.6)
	await shot("st03_brought_home")
	var sc: Dictionary = GS.storage.counts()
	var ok := true
	for pair in [[&"water", 3], [&"cash", 1200], [&"junk", 3], [&"parts", 1], [&"warehouse_key", 1], [&"work_uniform", 1]]:
		if int(sc.get(pair[0], 0)) - int(storage_before_home.get(pair[0], 0)) != pair[1]:
			ok = false
			print("  missing: ", pair, " storage ", sc.get(pair[0], 0), " before ", storage_before_home.get(pair[0], 0))
	check(ok, "water, cash, junk, parts, key and uniform all went into the storage")
	check(GS.equip_get("clothing") == null and GS.inventory.size == 10, "the uniform found on this trip was taken off and stored")
	check(GS.equip_get("hand1") != null and GS.equip_get("hand2") != null and GS.equip_count("hand3") == 2, "carried-out gear stays (pistol, knife, 2 bottles left)")
	check(GS.inventory.used_slots() == 0, "nothing found stays in the backpack")
	hub = current_scene
	hud = hub.hud
	check(hud.settlement_rows.text.contains("现金 ×1200") and hud.settlement_rows.text.contains("废纸 ×3") and hud.settlement_rare.text.contains("仓库的钥匙 ×1"), "本次带回 lists everything, rare finds apart")
	var total_after: Dictionary = grand_total()
	var lost := false
	for id in total_before:
		if int(total_after.get(id, 0)) < int(total_before[id]) - (1 if id in [&"canned_food", &"water", &"empty_bottle", &"biscuits", &"noodles"] else 0):
			lost = true
	check(not lost, "nothing that existed before the trip disappeared (except the cost and one thrown bottle)")

	# --- visual stages follow the real stock -----------------------------------------------
	var corner = hub.get_node("Furniture/Storage")
	var tex_now: Texture2D = corner.water.texture
	GS.storage.remove_tag(&"water", 999)
	await wait(0.1)
	check(corner.water.texture == corner.water_textures[0], "no water -> empty look")
	GS.stash(item("water"), 12)
	await wait(0.1)
	check(corner.water.texture == corner.water_textures[3], "10+ water -> big stock look")
	await shot("st04_stock_visual")

	# --- persistence -------------------------------------------------------------------------
	var snap: Array = GS.storage.to_data()
	check(await goto("res://scenes/maps/camp_hub.tscn"), "scene change")
	check(GS.storage.to_data() == snap, "storage (slot positions too) kept over a scene change")
	SS.save_here("res://scenes/maps/camp_hub.tscn", "学校营地")
	GS.new_game()
	SS.load_game()
	check(GS.storage.to_data() == snap and GS.storage.size == 40, "storage kept over save / load")
	GS.new_day()
	check(GS.storage.to_data() == snap, "storage kept over a new day")

	# --- full storage: nothing is swallowed --------------------------------------------------
	check(await goto("res://scenes/maps/camp_hub.tscn"), "camp for the full-storage case")
	await wait(0.6)
	var fill_i: int = GS.storage.first_free()
	while fill_i >= 0:
		GS.storage.slots[fill_i] = {"item": item("soap"), "count": 10}
		fill_i = GS.storage.first_free()
	GS.storage.changed.emit()
	check(GS.storage.used_slots() == 40, "storage 40 / 40")
	check(GS.begin_expedition(load("res://resources/locations/store.tres")), "go out with a full storage")
	GS.inventory.add(item("parts"), 5)
	GS.inventory.add(item("bandage"), 2)
	GS.inventory.add(item("noodles"), 2)
	var before_full: Dictionary = grand_total()
	var settle: Dictionary = GS.end_expedition()
	var after_full: Dictionary = grand_total()
	check(before_full == after_full, "full storage: every item still exists somewhere")
	check(settle.overflow and GS.has_pending() and GS.pending.used_slots() >= 1, "what did not fit waits under 待整理物资 (%d stacks)" % GS.pending.used_slots())
	check(GS.inventory.used_slots() == 0, "the backpack is still emptied")
	GS.expedition_done_today = false   # allow the door check below
	old_scene_home()
	check(await wait_scene("res://scenes/maps/camp_hub.tscn", 20.0), "home with overflow")
	await wait(5.5)
	hub = current_scene
	ui = hub.storage_ui
	check(ui.is_open() and ui._pending_box.visible and ui._desc_text.text == "仓库已经放不下了。", "storage screen opens by itself: 仓库已经放不下了。")
	await shot("st05_full_storage")
	# going out is blocked until it is sorted
	ui.close()
	await wait(0.2)
	var said: Array = []
	player().said.connect(func(t): said.append(t))
	hub._on_door(player())
	await wait(0.3)
	check(not hub.region_map.is_open and "带回来的东西还没整理好。" in said, "cannot go out with unsorted things")
	# make room: throw away soap, move the overflow in
	await wait(0.3)
	if not ui.is_open():
		ui.open()
	await wait(0.3)
	var soap_cell = null
	for s in ui.storage_slots:
		if s.item and s.item.id == &"soap":
			soap_cell = s
			break
	await drag(soap_cell, ui.discard_slot)
	check(GS.storage.used_slots() == 39, "丢弃: one stack thrown away (39 / 40)")
	var key_i := -1
	for i in GS.storage.size:
		var s = GS.storage.slots[i]
		if s and s.item.id == &"warehouse_key":
			key_i = i
	if key_i >= 0:
		await drag(ui.storage_slots[key_i], ui.discard_slot)
		check(GS.storage.count_item(&"warehouse_key") == 1, "the key cannot be thrown away")
	var guard := 0
	while GS.has_pending() and guard < 6:
		guard += 1
		var free: int = GS.storage.first_free()
		if free < 0:
			for s in ui.storage_slots:
				if s.item and s.item.id == &"soap":
					await drag(s, ui.discard_slot)
					break
			free = GS.storage.first_free()
		await drag(ui.pending_slots[0], ui.storage_slots[free])
	check(not GS.has_pending() and not ui._pending_box.visible, "overflow sorted into the storage")
	await shot("st06_sorted")
	ui.close()
	await wait(0.2)
	hub._on_door(player())
	await wait(0.4)
	check(hub.region_map.is_open, "sorted -> the door opens the map again")
	hub.region_map.close()

	SS.delete_save()
	print("RESULT: %s (%d failures)" % ["OK" if failures.is_empty() else "FAILED", failures.size()])
	quit(0 if failures.is_empty() else 1)


func old_scene_home() -> void:
	GS.spawn_point = &"camp_return"
	SM.change_scene("res://scenes/maps/camp_hub.tscn", 0.05)
