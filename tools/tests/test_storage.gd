extends SceneTree
## Camp storage: the storage is the only source of truth for camp supplies.
## Coming home moves NOTHING automatically — the player puts things in /
## takes them out himself at the storage screen, any item (weapons and
## equipment too). Storage entity + 40-slot screen showing backpack, hand
## and gear slots; trip costs taken from real items (HUD in sync);
## checkpoint without double charge / refund; a full storage refuses items
## instead of swallowing them; persistence; visual stages.
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


func find_slot(inv, id: StringName) -> int:
	for i in inv.size:
		var s = inv.slots[i]
		if s and s.item.id == id:
			return i
	return -1


func _run() -> void:
	GS = root.get_node("/root/GameState")
	SM = root.get_node("/root/SceneManager")
	SS = root.get_node("/root/SaveSystem")
	await wait(0.3)
	check(not "camp" in GS or GS.get("camp") == null, "no separate food / water counter any more")

	# --- start of the free phase: nothing is moved for the player -------------------------
	GS.new_game()
	GS.inventory.add(item("water"), 4)
	GS.inventory.add(item("canned_food"), 3)
	GS.inventory.add(item("junk"), 2)
	GS.start_free_phase()
	check(GS.storage.size == 40, "camp storage has 40 slots")
	check(GS.camp_food() == 2 and GS.camp_water() == 1, "storage holds the old camp stock (2 food, 1 water)")
	check(GS.inventory.count_item(&"water") == 4 and GS.inventory.count_item(&"junk") == 2, "day-1 finds stay in the backpack")
	check(await goto("res://scenes/maps/camp_hub.tscn"), "camp hub")
	await wait(1.0)
	var hub = current_scene
	var hud = hub.hud
	check(hud.camp_food.text == "2" and hud.camp_water.text == "1", "top-right counts come from the storage")

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
	check(ui.bag_slots.size() == GS.inventory.size and ui.hand_slots.size() == 3 and ui.gear_slots.size() == 4, "backpack, hand slots and gear slots shown with it")
	await shot("st02_storage_ui")
	# put the water away: backpack -> storage (merges into the stack there)
	await drag(ui.bag_slots[find_slot(GS.inventory, &"water")], ui.storage_slots[find_slot(GS.storage, &"water")])
	check(GS.camp_water() == 5 and GS.inventory.count_item(&"water") == 0, "backpack -> storage (water stacked)")
	check(hud.camp_water.text == "5", "HUD water follows at once (%s)" % hud.camp_water.text)
	await drag(ui.bag_slots[find_slot(GS.inventory, &"canned_food")], ui.storage_slots[GS.storage.first_free()])
	check(GS.camp_food() == 5, "food put away (5)")
	# take one stack out again, then back
	await drag(ui.storage_slots[find_slot(GS.storage, &"water")], ui.bag_slots[GS.inventory.first_free()])
	check(GS.camp_water() == 0 and hud.camp_water.text == "0", "storage -> backpack; HUD shows 0 at once")
	await drag(ui.bag_slots[find_slot(GS.inventory, &"water")], ui.storage_slots[GS.storage.first_free()])
	check(GS.camp_water() == 5, "and back")
	# weapons and equipment can be stored too
	var pistol := item("pistol")
	await drag(ui.hand_slots["hand1"], ui.storage_slots[GS.storage.first_free()])
	check(GS.equip_get("hand1") == null and GS.storage.count_item(&"pistol") == 1, "pistol: hand slot -> storage")
	await drag(ui.storage_slots[find_slot(GS.storage, &"pistol")], ui.hand_slots["hand1"])
	check(GS.equip_get("hand1") == pistol and GS.storage.count_item(&"pistol") == 0, "pistol: storage -> hand slot")
	await drag(ui.gear_slots["backpack"], ui.storage_slots[GS.storage.first_free()])
	check(GS.storage.count_item(&"backpack") == 1 and GS.equip_get("backpack") == null, "even the old backpack (gear) can be stored")
	await drag(ui.storage_slots[find_slot(GS.storage, &"backpack")], ui.gear_slots["backpack"])
	check(GS.equip_get("backpack") != null, "and put back on")
	# bottles for the trip into a hand slot
	GS.stash(item("empty_bottle"), 3)
	await wait(0.1)
	await drag(ui.storage_slots[find_slot(GS.storage, &"empty_bottle")], ui.hand_slots["hand3"])
	check(GS.equip_get("hand3") == item("empty_bottle") and GS.equip_count("hand3") == 3, "storage -> hand slot 3 (loadout)")
	await press("inventory")
	await wait(0.3)
	check(not ui.is_open(), "storage screen closes")

	# --- the trip cost comes out of the storage --------------------------------------------
	var pre: Dictionary = GS.camp_view()
	check(GS.begin_expedition(load("res://resources/locations/store.tres")), "departure")
	check(GS.camp_food() == pre.food - 1 and GS.camp_water() == pre.water - 1, "food -1 water -1 taken from the storage")
	await wait(0.1)
	check(hud.camp_food.text == str(GS.camp_food()) and hud.camp_water.text == str(GS.camp_water()), "HUD synced after paying")
	var after_pay: Dictionary = GS.camp_view()
	var storage_after_pay: Array = GS.storage.to_data()
	check(await goto("res://scenes/maps/region_store.tscn"), "region")
	check(GS.checkpoint.get("storage") == storage_after_pay, "expedition checkpoint holds the paid storage")
	GS.inventory.add(item("cash"), 50)
	GS.restore_checkpoint()
	check(GS.storage.to_data() == storage_after_pay and GS.camp_view() == after_pay, "restart: no refund, no second charge")
	# pick things up, put a found uniform on, go home
	for pair in [["water", 3], ["cash", 1200], ["junk", 3], ["parts", 1], ["warehouse_key", 1], ["work_uniform", 1]]:
		GS.inventory.add(item(pair[0]), pair[1])
	GS.quick_equip(find_slot(GS.inventory, &"work_uniform"))
	var bag_before_home: Dictionary = GS.item_counts()
	var storage_before_home: Array = GS.storage.to_data()
	GS.mark_location_visited()
	var region = current_scene
	region._on_gate(null)
	check(await wait_scene("res://scenes/maps/camp_hub.tscn", 20.0, region), "home")
	await wait(2.0)
	await shot("st03_brought_home")
	check(GS.storage.to_data() == storage_before_home, "coming home moves nothing into the storage")
	check(GS.item_counts() == bag_before_home and GS.equip_get("clothing") == item("work_uniform") and GS.inventory.size == 15, "everything found (and the worn uniform) is still on the player")
	hub = current_scene
	hud = hub.hud
	check(hud.settlement_rows.text.contains("现金 ×1200") and hud.settlement_rare.text.contains("仓库的钥匙 ×1"), "本次带回 note lists the finds")
	# put things away by hand, gear included
	ui = hub.storage_ui
	hub.open_storage()
	await wait(0.4)
	await drag(ui.bag_slots[find_slot(GS.inventory, &"cash")], ui.storage_slots[GS.storage.first_free()])
	await drag(ui.bag_slots[find_slot(GS.inventory, &"junk")], ui.storage_slots[GS.storage.first_free()])
	await drag(ui.gear_slots["clothing"], ui.storage_slots[GS.storage.first_free()])
	check(GS.storage.count_item(&"cash") > 0 and GS.storage.count_item(&"junk") >= 3 and GS.inventory.count_item(&"junk") == 0, "cash and junk put away by hand")
	check(GS.equip_get("clothing") == null and GS.storage.count_item(&"work_uniform") == 1 and GS.inventory.size == 10, "the uniform taken off straight into the storage")
	await shot("st04_put_away")
	ui.close()
	await wait(0.2)

	# --- visual stages follow the real stock -----------------------------------------------
	var corner = hub.get_node("Furniture/Storage")
	GS.storage.remove_tag(&"water", 999)
	await wait(0.1)
	check(corner.water.texture == corner.water_textures[0], "no water -> empty look")
	GS.stash(item("water"), 12)
	await wait(0.1)
	check(corner.water.texture == corner.water_textures[3], "10+ water -> big stock look")

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

	# --- full storage: refuses, never swallows ---------------------------------------------
	check(await goto("res://scenes/maps/camp_hub.tscn"), "camp for the full-storage case")
	await wait(0.6)
	hub = current_scene
	ui = hub.storage_ui
	var f: int = GS.storage.first_free()
	while f >= 0:
		GS.storage.slots[f] = {"item": item("soap"), "count": 10}
		f = GS.storage.first_free()
	GS.storage.changed.emit()
	GS.inventory.add(item("bandage"), 2)
	var total_before: Dictionary = grand_total()
	hub.open_storage()
	await wait(0.4)
	check(ui._storage_title.text.contains("40 / 40"), "storage 40 / 40")
	var soap_i := find_slot(GS.storage, &"soap")
	await drag(ui.bag_slots[find_slot(GS.inventory, &"bandage")], ui.storage_slots[soap_i])
	check(grand_total() == total_before and GS.storage.used_slots() == 40, "full: dropping on an occupied slot swaps, nothing is swallowed")
	soap_i = find_slot(GS.storage, &"soap")
	await drag(ui.storage_slots[soap_i], ui.discard_slot)
	check(ui.context_menu.confirm_panel.visible and GS.storage.used_slots() == 40, "丢弃 slot asks first (red confirmation), nothing gone yet")
	ui.context_menu.confirm_yes.pressed.emit()
	await wait(0.1)
	check(GS.storage.used_slots() == 39, "丢弃 makes room (39 / 40)")
	var key_i := find_slot(GS.storage, &"warehouse_key")
	if key_i < 0:
		GS.stash(item("warehouse_key"), 1)
		key_i = find_slot(GS.storage, &"warehouse_key")
	await drag(ui.storage_slots[key_i], ui.discard_slot)
	check(GS.storage.count_item(&"warehouse_key") == 1, "the key cannot be thrown away")
	await shot("st05_full_storage")
	ui.close()

	SS.delete_save()
	print("RESULT: %s (%d failures)" % ["OK" if failures.is_empty() else "FAILED", failures.size()])
	quit(0 if failures.is_empty() else 1)
