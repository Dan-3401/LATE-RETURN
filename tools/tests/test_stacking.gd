extends SceneTree
## A1.1 stacking: stack limits by item type (weapons / equipment / keys 1,
## throwables 20, materials & junk 67), top-up-first stacking, the
## right-click menu on ONE stack (使用 / 拆分 / 丢弃) in the backpack and the
## camp storage, the split window (xx / yy of this stack only, 1 .. n-1,
## "没有空余位置。"), the red destroy confirmation in the storage, dropping a
## backpack stack on the ground as ONE pickup, whole-or-nothing pickups.
##   godot --path . -s res://tools/tests/test_stacking.gd -- [shot_dir]

var shot_dir := ""
var failures: Array[String] = []
var GS: Node
var SM: Node
var SS: Node
var said: Array[String] = []


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


## A real mouse click (left or right) in the middle of a control.
func click(c: Control, button := MOUSE_BUTTON_LEFT) -> void:
	await click_at(c.get_global_rect().get_center(), button)


func click_at(vp_pos: Vector2, button := MOUSE_BUTTON_LEFT) -> void:
	var pos := vp_pos * (Vector2(root.size) / Vector2(480, 270))
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = button
		ev.pressed = pressed
		ev.position = pos
		ev.global_position = pos
		ev.button_mask = (MOUSE_BUTTON_MASK_LEFT if button == MOUSE_BUTTON_LEFT else MOUSE_BUTTON_MASK_RIGHT) if pressed else 0
		root.push_input(ev)
		await process_frame
	await wait(0.1)


func counts_list(inv) -> Array:
	var out: Array = []
	for s in inv.slots:
		if s != null:
			out.append(s.count)
	return out


func stacks_of(inv, id: StringName) -> Array:
	var out: Array = []
	for s in inv.slots:
		if s != null and s.item.id == id:
			out.append(s.count)
	return out


func find_slot(inv, id: StringName, n := -1) -> int:
	for i in inv.size:
		var s = inv.slots[i]
		if s and s.item.id == id and (n < 0 or s.count == n):
			return i
	return -1


func pickups() -> Array:
	return get_nodes_in_group(&"pickup")


func _run() -> void:
	GS = root.get_node("/root/GameState")
	SM = root.get_node("/root/SceneManager")
	SS = root.get_node("/root/SaveSystem")
	var Inv: GDScript = load("res://scripts/systems/inventory.gd")
	var Actions: GDScript = load("res://scripts/systems/inventory_actions.gd")
	await wait(0.3)

	# --- 1-6: stack limits by type, top-up first ---------------------------------------------------
	for id in ["pistol", "knife", "work_uniform", "backpack", "warehouse_key"]:
		var inv = Inv.new(10)
		inv.add(item(id), 3)
		check(item(id).stack_limit() == 1 and counts_list(inv) == [1, 1, 1], "%s never stacks above 1 (%s)" % [id, str(counts_list(inv))])
	var inv = Inv.new(10)
	inv.add(item("empty_bottle"), 25)
	check(item("empty_bottle").stack_limit() == 20 and counts_list(inv) == [20, 5], "bottles ×25 -> 20 + 5")
	inv = Inv.new(10)
	inv.add(item("parts"), 70)
	check(item("parts").stack_limit() == 67 and counts_list(inv) == [67, 3], "parts ×70 -> 67 + 3")
	check(item("junk").stack_limit() == 67, "junk (杂项) stacks to 67")
	inv = Inv.new(10)
	inv.add(item("parts"), 60)
	inv.add(item("parts"), 10)
	check(counts_list(inv) == [67, 3] and inv.slots[0].count == 67, "parts 60/67 + 10 -> the old stack 67, new stack 3")
	inv = Inv.new(10)
	inv.add(item("parts"), 60)
	inv.slots[2] = {"item": item("parts"), "count": 10}
	check(not inv.can_add(item("parts"), 67 * 8 + 7 + 57 + 1) and inv.can_add(item("parts"), 67 * 8 + 7 + 57), "can_add counts the room of partial stacks and free slots")

	# --- camp storage screen ------------------------------------------------------------------------
	GS.new_game()
	GS.start_free_phase()
	GS.storage.clear()
	GS.stash(item("canned_food"), 3)
	GS.stash(item("water"), 3)
	GS.stash(item("parts"), 64)
	GS.inventory.clear()
	GS.inventory.add(item("parts"), 10)
	check(await goto("res://scenes/maps/camp_hub.tscn"), "camp hub")
	await wait(0.8)
	var hub = current_scene
	var p = player()
	p.said.connect(func(t): said.append(t))
	hub.open_storage()
	await wait(0.4)
	var ui = hub.storage_ui
	var menu = ui.context_menu
	var parts_i := find_slot(GS.storage, &"parts", 64)

	# 7: unusable item -> 使用 disabled; menu for the clicked stack only
	await click(ui.storage_slots[parts_i], MOUSE_BUTTON_RIGHT)
	check(menu.is_menu_visible(), "right-click opens the menu")
	check(menu.use_btn.disabled and not menu.split_btn.disabled and not menu.discard_btn.disabled, "parts: 使用 greyed out, 拆分 / 丢弃 available")
	check(menu.use_btn.get_theme_color(&"font_disabled_color") != menu.use_btn.get_theme_color(&"font_color"), "disabled entries use a grey colour")
	check(Actions.context_of(menu.ref) == Actions.Context.CAMP_STORAGE, "storage stack -> CAMP_STORAGE context")
	await shot("sk01_menu_storage")
	# Esc and an outside click close it
	await press("pause")
	check(not menu.is_open() and ui.is_open(), "Esc closes the menu (the storage stays open)")
	await click(ui.storage_slots[parts_i], MOUSE_BUTTON_RIGHT)
	await click_at(Vector2(6, 262))
	check(not menu.is_open(), "a click outside closes the menu")

	# 11: the split window shows xx / 64 (this stack), not 74
	await click(ui.storage_slots[parts_i], MOUSE_BUTTON_RIGHT)
	await click(menu.split_btn)
	check(not menu.is_menu_visible() and menu.split_panel.visible, "拆分 opens the split window, the menu hides")
	check(menu.split_total.text == "/ 64", "split window reads this stack only: xx / 64 (%s)" % menu.split_total.text)
	await shot("sk02_split_window")
	# 13: 0 / 64 / 65 / -3 / 2.5 / text cannot be confirmed
	for bad in ["0", "64", "65", "-3", "2.5", "abc", ""]:
		menu.split_edit.text = bad
		menu.split_edit.text_changed.emit(bad)
		check(menu.split_ok.disabled, "split amount '%s' cannot be confirmed" % bad)
	for bad in [0, 64, 65, -1]:
		check(Actions.split({"kind": "storage", "index": parts_i}, bad) != "" and GS.storage.slots[parts_i].count == 64, "split %d refused by the action layer, nothing changes" % bad)
	menu.split_edit.text = "20"
	menu.split_edit.text_changed.emit("20")
	check(not menu.split_ok.disabled, "20 of 64 can be confirmed")
	await click(menu.split_ok)
	check(GS.storage.slots[parts_i].count == 44 and stacks_of(GS.storage, &"parts").has(20) and GS.storage.count_item(&"parts") == 64, "split 20 of 64 -> 44 + 20 in the storage (%s)" % str(stacks_of(GS.storage, &"parts")))
	check(GS.inventory.count_item(&"parts") == 10 and not menu.is_open(), "backpack untouched, window closed")
	var ui_new: int = find_slot(GS.storage, &"parts", 20)
	check(ui.storage_slots[parts_i]._count.text == "44" and ui.storage_slots[ui_new]._count.text == "20", "storage screen shows 44 and 20")
	var saved: Array = GS.storage.to_data()
	var re = Inv.new(40)
	re.from_data(saved)
	check(stacks_of(re, &"parts") == stacks_of(GS.storage, &"parts"), "the split stacks are what gets saved")

	# 9 / 10 / 8: 拆分 needs >= 2, 使用 from data (bandage)
	GS.inventory.add(item("bandage"), 1)
	var band_i := find_slot(GS.inventory, &"bandage")
	await click(ui.bag_slots[band_i], MOUSE_BUTTON_RIGHT)
	check(menu.split_btn.disabled and not menu.use_btn.disabled, "bandage ×1: 拆分 disabled, 使用 enabled (use_behavior)")
	check(Actions.context_of(menu.ref) == Actions.Context.PLAYER_BACKPACK, "backpack stack -> PLAYER_BACKPACK context")
	await press("pause")
	GS.inventory.add(item("bandage"), 1)
	await click(ui.bag_slots[band_i], MOUSE_BUTTON_RIGHT)
	check(not menu.split_btn.disabled, "bandage ×2: 拆分 enabled")
	p.health.take_damage(50.0)
	await wait(0.1)
	var hp_before: float = p.health.hp
	await click(menu.use_btn)
	check(GS.inventory.count_item(&"bandage") == 1 and p.health.hp > hp_before, "使用: effect ran, stack 2 -> 1 (hp %.0f -> %.0f)" % [hp_before, p.health.hp])
	check(not menu.is_open(), "a successful use closes the menu")
	await click(ui.bag_slots[band_i], MOUSE_BUTTON_RIGHT)
	await click(menu.use_btn)
	check(GS.inventory.count_item(&"bandage") == 0 and GS.inventory.slots[band_i] == null, "the last one used: the stack is gone")
	GS.inventory.add(item("pistol"), 1)
	await click(ui.bag_slots[find_slot(GS.inventory, &"pistol")], MOUSE_BUTTON_RIGHT)
	check(menu.use_btn.disabled and menu.split_btn.disabled, "pistol: 使用 greyed (equipping is not using), 拆分 greyed")
	await press("pause")
	GS.inventory.remove(&"pistol", 1)

	# 15-17: storage 丢弃 = red destroy confirmation
	var pick_n: int = pickups().size()
	await click(ui.storage_slots[ui_new], MOUSE_BUTTON_RIGHT)
	await click(menu.discard_btn)
	check(menu.confirm_panel.visible and menu.confirm_text.text == "你确定要销毁当前物品？", "storage 丢弃 asks 你确定要销毁当前物品？")
	var red: Color = menu.confirm_text.get_theme_color(&"font_color")
	check(red.r > 0.8 and red.g < 0.4, "the question is red")
	await shot("sk03_destroy_confirm")
	await click(menu.confirm_no)
	check(GS.storage.count_item(&"parts") == 64 and not menu.is_open(), "否: nothing changes")
	await click(ui.storage_slots[ui_new], MOUSE_BUTTON_RIGHT)
	await click(menu.discard_btn)
	await click(menu.confirm_yes)
	check(GS.storage.count_item(&"parts") == 44 and GS.storage.slots[ui_new] == null, "是: that stack (20) is destroyed, the other stays")
	check(pickups().size() == pick_n, "destroying never makes a pickup")
	# the key cannot be destroyed
	GS.stash(item("warehouse_key"), 1)
	await click(ui.storage_slots[find_slot(GS.storage, &"warehouse_key")], MOUSE_BUTTON_RIGHT)
	check(menu.discard_btn.disabled, "keys: 丢弃 greyed out")
	await press("pause")

	# 14: a full storage cannot split -> nothing lost
	var f: int = GS.storage.first_free()
	while f >= 0:
		GS.storage.slots[f] = {"item": item("soap"), "count": 1}
		f = GS.storage.first_free()
	GS.storage.changed.emit()
	await wait(0.1)
	var total_before: int = GS.storage.count_item(&"parts")
	await click(ui.storage_slots[parts_i], MOUSE_BUTTON_RIGHT)
	await click(menu.split_btn)
	menu.split_edit.text = "4"
	menu.split_edit.text_changed.emit("4")
	await click(menu.split_ok)
	check(menu.last_message == "没有空余位置。", "full storage: 没有空余位置。")
	check(GS.storage.count_item(&"parts") == total_before and GS.storage.slots[parts_i].count == 44 and GS.inventory.count_item(&"parts") == 10, "nothing lost, nothing sent to the backpack")
	await shot("sk04_no_room")
	ui.close()
	await wait(0.2)

	# --- 18-21: on an outing: dropping and picking up whole stacks --------------------------------------
	GS.storage.clear()
	GS.stash(item("canned_food"), 3)
	GS.stash(item("water"), 3)
	var loc = load("res://resources/locations/store.tres")
	check(GS.begin_expedition(loc), "outing started")
	check(await goto(loc.region_scene), "region map")
	await wait(1.0)
	var region = current_scene
	p = player()
	said.clear()
	p.said.connect(func(t): said.append(t))
	GS.inventory.clear()
	GS.inventory.add(item("empty_bottle"), 8)
	var bag_ui = region.hud.inventory_ui
	bag_ui.set_open(true)
	await wait(0.3)
	var bmenu = bag_ui.context_menu
	var bottle_i := find_slot(GS.inventory, &"empty_bottle")
	await click(bag_ui.bag_slots[bottle_i], MOUSE_BUTTON_RIGHT)
	check(bmenu.is_menu_visible() and bmenu.use_btn.disabled and not bmenu.discard_btn.disabled, "backpack menu on the map")
	await shot("sk05_menu_backpack")
	var before: Array = pickups().duplicate()
	await click(bmenu.discard_btn)
	var fresh: Array = pickups().filter(func(n): return not n in before)
	check(fresh.size() == 1, "丢弃 ×8 makes exactly ONE pickup (%d)" % fresh.size())
	check(GS.inventory.count_item(&"empty_bottle") == 0 and not bmenu.is_open(), "the stack left the backpack, menu closed")
	bag_ui.set_open(false)
	var pk = fresh[0] if fresh.size() > 0 else null
	check(pk != null and pk.item.id == &"empty_bottle" and pk.count == 8, "pickup quantity = 8")
	await wait(1.5)
	check(pk.global_position.distance_to(p.global_position) < 60.0, "dropped next to the player")
	check(pk.interactable.prompt_title == "空瓶子 ×8" and pk.interactable._prompt_string() == "空瓶子 ×8\n[F] 拾取", "prompt: 空瓶子 ×8 / [F] 拾取")
	await shot("sk06_dropped_stack")

	# 19: picking it up merges by the normal rules (17 + 8 -> 20 + 5)
	GS.inventory.add(item("empty_bottle"), 17)
	pk.interactable.interact(p)
	await wait(0.4)
	check(stacks_of(GS.inventory, &"empty_bottle") == [20, 5], "picked up: 17 + 8 -> 20 + 5 (%s)" % str(stacks_of(GS.inventory, &"empty_bottle")))
	check(not is_instance_valid(pk) or not pk.is_in_group(&"pickup"), "the pickup is gone")

	# 20: a full backpack: nothing picked up
	var scene: PackedScene = load("res://scenes/items/pickup.tscn")
	var gp = scene.instantiate()
	gp.set_stack({"item": item("parts"), "count": 10})
	region.add_child(gp)
	gp.global_position = p.global_position + Vector2(10, -4)
	gp.launch(Vector2(0, -40))
	await wait(1.2)
	GS.inventory.clear()
	for i in GS.inventory.size:
		GS.inventory.slots[i] = {"item": item("junk"), "count": 67}
	GS.inventory.changed.emit()
	var snapshot: Array = GS.inventory.to_data()
	said.clear()
	gp.interactable.interact(p)
	await wait(0.3)
	check(said.has("已经装不下了。"), "full backpack: 已经装不下了。")
	check(is_instance_valid(gp) and gp.count == 10 and gp.is_in_group(&"pickup") and gp.interactable.enabled, "the pickup stays on the ground, still ×10")
	check(GS.inventory.to_data() == snapshot, "the backpack is unchanged")
	await shot("sk07_cannot_carry")

	# 21: room for only 3 of 10 -> still nothing picked up
	GS.inventory.slots[0] = {"item": item("parts"), "count": 64}
	GS.inventory.changed.emit()
	snapshot = GS.inventory.to_data()
	said.clear()
	gp.interactable.interact(p)
	await wait(0.3)
	check(said.has("已经装不下了。") and gp.count == 10 and GS.inventory.count_item(&"parts") == 64, "room for 3 of 10: refused whole, ground ×10, bag 64")
	check(GS.inventory.to_data() == snapshot, "no partial pickup")
	# with room it goes in whole
	GS.inventory.slots[1] = null
	GS.inventory.changed.emit()
	gp.interactable.interact(p)
	await wait(0.3)
	check(stacks_of(GS.inventory, &"parts") == [67, 7], "with room: 64 + 10 -> 67 + 7")

	SS.delete_save()
	print("RESULT: %s (%d failures)" % ["OK" if failures.is_empty() else "FAILED", failures.size()])
	quit(0 if failures.is_empty() else 1)
