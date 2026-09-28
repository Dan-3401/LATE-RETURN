extends SceneTree
## Demo 2 loop test:
## day-1 diary -> task update -> camp hub (resources, sister) -> region map
## (locked places, costs) -> region (checkpoint, return restriction, bottle
## decoy, AI priority, death/restart without double cost) -> store (warehouse
## door, key) -> warehouse (uniform, capacity guard) -> home (settlement)
## -> end day -> templated diary -> new day (ammo reset, persistence).
##   godot --path . -s res://tools/tests/test_day_loop.gd -- [shot_dir]

var shot_dir := ""
var failures: Array[String] = []
var GS: Node
var SM: Node
var NS: Node


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


func any_key() -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_SPACE
	ev.pressed = true
	Input.parse_input_event(ev)
	await physics_frame
	var ev2 := InputEventKey.new()
	ev2.physical_keycode = KEY_SPACE
	ev2.pressed = false
	Input.parse_input_event(ev2)
	await physics_frame


## Left-click a map marker with a real mouse event pushed into the window,
## so GUI nodes that could swallow the click are part of the test.
func click_map(map, loc) -> void:
	var vp_pos: Vector2 = map.map_rect.global_position + loc.map_position
	var win_pos := vp_pos * (Vector2(root.size) / Vector2(480, 270))
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = win_pos
		ev.global_position = win_pos
		root.push_input(ev)
		await wait(0.05)
	await wait(0.3)


func wait_scene(path: String, timeout: float, old: Node = null) -> bool:
	if old == null:
		old = current_scene
	var t := 0.0
	# first wait for the scene instance to actually change
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


func bag_index(id: StringName) -> int:
	for i in GS.inventory.size:
		var s = GS.inventory.slots[i]
		if s != null and s.item.id == id:
			return i
	return -1


func player():
	return get_first_node_in_group(&"player")


func unit_tests() -> void:
	# calendar: real dates, no 9月31日
	check(GS.date_text(0) == "9月28日", "day 0 is 9月28日")
	check(GS.date_text(1) == "9月29日", "day 1 is 9月29日")
	check(GS.date_text(3) == "10月1日", "month rolls over to 10月1日 (%s)" % GS.date_text(3))
	check(GS.date_text(34) == "11月1日", "october has 31 days (%s)" % GS.date_text(34))
	# diary templates
	var DW = load("res://scripts/systems/diary_writer.gd")
	var one: PackedStringArray = DW.daily({&"water": 3}, [])
	check(one[0] == "今天搜到了一些水。" and one[-1] == "妹妹也很开心。" and one.size() == 2, "diary: one kind, no rare line (%s)" % "|".join(one))
	var two: PackedStringArray = DW.daily({&"water": 3, &"canned_food": 2}, [])
	check(two[0] == "今天搜到了一些水和食物。", "diary: two kinds (%s)" % two[0])
	var three: PackedStringArray = DW.daily({&"water": 3, &"biscuits": 2, &"empty_bottle": 1, &"junk": 1}, [])
	check(three[0] == "今天搜到了一些水、食物和空瓶子。", "diary: top three kinds (%s)" % three[0])
	var rare1: PackedStringArray = DW.daily({&"water": 1}, [&"warehouse_key"])
	check(rare1[1] == "甚至还搜到了仓库的钥匙！", "diary: one rare (%s)" % rare1[1])
	var rare2: PackedStringArray = DW.daily({&"soap": 1}, [&"warehouse_key", &"work_uniform"])
	check(rare2[1] == "甚至还找到了仓库的钥匙和便利店员工的工装服！" and rare2[0] == "今天搜到了一些生活用品。", "diary: two rares in one line (%s)" % "|".join(rare2))


func _run() -> void:
	GS = root.get_node("/root/GameState")
	SM = root.get_node("/root/SceneManager")
	NS = root.get_node("/root/NoiseSystem")
	GS.new_game()
	unit_tests()

	# ---------------- day 1 ends: diary ----------------
	GS.inventory.add(load("res://resources/items/water.tres"), 5)
	GS.inventory.add(load("res://resources/items/canned_food.tres"), 3)
	GS.inventory.add(load("res://resources/items/biscuits.tres"), 2)
	GS.pending_diary = {"date": GS.date_text(0), "lines": load("res://scripts/systems/diary_writer.gd").first_day(), "next": &"first"}
	change_scene_to_file("res://scenes/ui/diary.tscn")
	await process_frame
	await process_frame
	await wait(20.0)
	await shot("d01_diary_first")
	var lines := current_scene.get_node("Paper/Lines").get_children()
	check(lines.size() == 7 and lines[0].text == "今天还是去了学校旁边的便利店。", "first diary page text")
	check(current_scene.get_node("Paper/Date").text == "9月28日", "first diary date")
	await any_key()
	await wait(5.2)
	await shot("d02_task_update")
	check(current_scene.get_node("Task/Title").text == "寻找能够治疗哮喘病的药", "task update shown in the dark")
	check(await wait_scene("res://scenes/maps/camp_hub.tscn", 15.0), "day 2 starts in the camp hub")
	check(GS.is_free_phase() and GS.day_index == 1, "free phase, day 2 (9月29日)")
	check(GS.camp_food() >= 2 + 4 and GS.camp_water() >= 1 + 4 and GS.inventory.used_slots() == 0, "day-1 finds + the old stock are in the camp storage (%d/%d)" % [GS.camp_food(), GS.camp_water()])
	check(GS.inventory.count_tag(&"water") == 0, "camp supplies no longer in the backpack")
	check(GS.objective.title == "寻找能够治疗哮喘病的药", "main objective shown")
	var hud = current_scene.get_node("HUD")
	check(hud.get_node("Overlay/Camp").visible and hud.get_node("Overlay/Camp/HBox/Food").text == str(GS.camp_food()), "camp resource UI (top right)")
	await wait(1.5)
	await shot("d03_camp_hub")

	# ---------------- sister ----------------
	var p = player()
	var hub = current_scene
	var spoken: Array = []
	hub.dialogue_player.line_started.connect(func(s, t): spoken.append([s, t]))
	p.global_position = Vector2(hub.sister.global_position.x - 16, 224)
	await wait(0.4)
	await press("end_day")
	await wait(0.3)
	check(not hub.confirm.is_open, "cannot end the day before going out")
	await press("interact")
	await wait(1.2)
	await shot("d04_sister_talk")
	for i in 40:
		await wait(0.25)
		if not hub.dialogue_player.playing:
			break
		await press("interact")
	check(spoken.size() >= 2 and spoken[0][0] == "妹妹", "sister small talk plays (%d lines)" % spoken.size())

	# ---------------- the map ----------------
	p.global_position = Vector2(hub.door_interact.global_position.x, 224)
	await wait(0.4)
	await press("interact")
	await wait(0.6)
	var map = hub.region_map
	check(map.is_open, "door opens the region map")
	var locs := {}
	for l in map.locations:
		locs[l.id] = l
	# hover the hospital (warp the mouse onto its marker)
	var hpos: Vector2 = map.map_rect.global_position + locs[&"hospital"].map_position
	root.warp_mouse(hpos * (Vector2(root.size) / Vector2(480, 270)))
	await wait(0.3)
	if map.hovered != locs[&"hospital"]:
		map.hovered = locs[&"hospital"]
		map._show_info(locs[&"hospital"])
	check(map.info_cost.text.contains("食物 ×3") and map.info_cost.text.contains("水 ×2"), "hover shows cost")
	await shot("d05_map_hover")
	var before: Dictionary = GS.camp_view()
	await click_map(map, locs[&"hospital"])   # real left click through the viewport
	check(GS.camp_view() == before and current_scene == hub and map.is_open, "locked location: no cost, no travel")
	check(map.note.text.contains("后面的区域以后再来探索吧......"), "locked location line")
	await shot("d06_map_locked")
	await wait(1.0)
	await click_map(map, locs[&"store"])
	check(map.confirm.visible, "confirm popup: 前往这里？")
	await shot("d07_map_confirm")
	map.go_btn.emit_signal("pressed")
	check(GS.camp_food() == before.food - 1 and GS.camp_water() == before.water - 1, "cost taken out of the storage (%d/%d)" % [GS.camp_food(), GS.camp_water()])
	check(await wait_scene("res://scenes/maps/region_store.tscn", 10.0), "departure -> store district region")
	var camp_after_pay: Dictionary = GS.camp_view()
	check(String(GS.checkpoint.get("id", "")) == "expedition_1" and GS.checkpoint.has("storage"), "expedition checkpoint after paying")

	# ---------------- region: return restriction ----------------
	p = player()
	var region = current_scene
	var said: Array = []
	p.said.connect(func(t): said.append(t))
	check(p.global_position.x > 2400, "starts at the school gate")
	p.global_position = Vector2(2530, 224)
	await wait(0.6)
	check("还什么都没干呢……" in said, "cannot go home before exploring a location")
	check(not region.gate.can_interact(p), "gate closed until a location is visited")
	await shot("d08_region_start")

	# ---------------- bottle decoy ----------------
	var bottle_item: ItemData = load("res://resources/items/empty_bottle.tres")
	GS.inventory.add(bottle_item, 2)
	check(GS.move_item({"kind": "bag", "index": bag_index(&"empty_bottle")}, {"kind": "equip", "slot": "hand3"}) == "" and GS.equip_get("hand3") == bottle_item and GS.equip_count("hand3") == 2, "bottles dragged into hand slot 3")
	var stray = region.get_node("Zombies/Stray")
	stray.machine.transition_to(&"Idle", {"duration": 99.0})
	p.global_position = Vector2(2440, 224)
	p.set_physics_process(false)
	await wait(0.3)
	var target: Vector2 = stray.global_position + Vector2(-90, 0)
	p.hands.select(2)
	check(p.throw.is_ready and not p.weapons.is_armed(), "key 3: throw-ready, no gun out")
	p.throw.update(p, p.shoulder_global(), target, -1)
	var arc: PackedVector2Array = p.throw.simulate(p, p.shoulder_global(), p.throw.solve_velocity(p.shoulder_global(), target))
	check(arc.size() > 5 and absf(arc[-1].x - target.x) < 24.0, "trajectory predicts landing near the aim (%.0f vs %.0f)" % [arc[-1].x if arc.size() else 0.0, target.x])
	await shot("d09_throw_aim")
	var breaks: Array = []
	NS.noise_emitted.connect(func(ev): if ev.kind == &"bottle": breaks.append(ev))
	check(p.hands.primary(), "bottle thrown")
	check(GS.equip_count("hand3") == 1, "throw consumes one bottle")
	for i in 40:
		await wait(0.05)
		if not breaks.is_empty():
			break
	check(breaks.size() == 1 and absf(breaks[0].position.x - target.x) < 30.0, "noise at the impact point, not at the player")
	await wait(0.1)
	check(stray.machine.state_name() == &"Investigate", "zombie reacts to the bottle (%s)" % stray.machine.state_name())
	check(stray.last_heard_pos.distance_to(breaks[0].position) < 1.0 if not breaks.is_empty() else false, "zombie only knows the impact position")
	var spd := 0.0
	for i in 30:
		await wait(0.05)
		spd = maxf(spd, absf(stray.velocity.x))
	check(spd > stray.data.investigate_speed * 1.5, "zombie sprints to the bottle (%.0f px/s)" % spd)
	await shot("d10_bottle_decoy")
	for i in 60:
		await wait(0.1)
		if stray.machine.state_name() == &"Search":
			break
	check(stray.machine.state_name() == &"Search", "finds nothing -> Search")
	p.hands.holster()
	p.set_physics_process(true)

	# priority: a zombie watching the player ignores a bottle
	var pacer = region.get_node("Zombies/Pacer")
	pacer.machine.transition_to(&"Idle", {"duration": 99.0})
	pacer.facing = 1
	p.global_position = Vector2(pacer.global_position.x + 80, 224)
	p.flashlight.set_on(true, true)
	for i in 40:
		await wait(0.05)
		if pacer.vision.can_see and pacer.vision.suspicion >= 0.3:
			break
	var decoy: Vector2 = pacer.global_position + Vector2(-150, 0)
	NS.emit_noise(decoy, 260.0, null, &"bottle")
	await wait(0.2)
	check(pacer.last_heard_pos.distance_to(decoy) > 1.0 or pacer.machine.state_name() in [&"Alert", &"Chase", &"Suspicious"], "seeing the player beats the bottle (%s)" % pacer.machine.state_name())

	# ---------------- death -> expedition checkpoint ----------------
	for i in 300:
		await wait(0.1)
		if p.is_dead():
			break
	if not p.is_dead():
		p.health.take_damage(999.0, pacer)
	check(p.is_dead(), "player died in the region")
	var go: Node = null
	for i in 150:
		await wait(0.1)
		go = root.get_node_or_null("GameOver")
		if go:
			break
	check(go != null, "GAME OVER in the region")
	await wait(4.0)
	go.get_node("Root/Center/VBox/Buttons/Restart").emit_signal("pressed")
	check(await wait_scene("res://scenes/maps/region_store.tscn", 10.0), "restart -> expedition start")
	check(GS.camp_view() == camp_after_pay, "no second payment after dying (%s)" % str(GS.camp_view()))
	check(GS.count_carried(&"empty_bottle") == 0 and GS.equip_get("hand3") == null, "backpack and hand slots restored to the expedition start")
	p = player()
	check(p.global_position.x > 2400, "restart at the school gate")

	# ---------------- into the store ----------------
	region = current_scene
	p.global_position = Vector2(146, 224)
	await wait(0.4)
	await press("interact")
	check(await wait_scene("res://scenes/maps/convenience_store.tscn", 10.0), "store door -> the same store")
	check(GS.expedition.location_visited, "location visited flag")
	p = player()
	said.clear()
	p.said.connect(func(t): said.append(t))
	var store = current_scene
	await wait(1.5)
	# day-1 searched containers stay empty unless refilled; the key may be hidden somewhere
	var key_in: String = ""
	for k in GS.world:
		var st = GS.world[k]
		if st is Dictionary and st.has("loot"):
			for e in st.loot:
				if String(e.path).ends_with("warehouse_key.tres"):
					key_in = k
	print("key hidden in: ", key_in)
	var wdoor = store.get_node("WarehouseDoor")
	p.global_position = Vector2(wdoor.global_position.x, 224)
	await wait(0.4)
	await press("interact")
	await wait(1.4)
	check("用蛮力的话，会引来很多丧尸吧……" in said, "locked warehouse without key")
	check(not wdoor.is_unlocked(), "door stays locked")
	await shot("d11_warehouse_locked")
	# search the whole store
	for c in get_nodes_in_group(&"loot_container"):
		if c.is_searched:
			continue
		p.global_position = Vector2(c.global_position.x + (-18 if c.name == "Counter" else 0), 224)
		await wait(0.25)
		await press("interact")
		await wait(2.6)
		for it in get_nodes_in_group(&"pickup"):
			if is_instance_valid(it) and not it.is_queued_for_deletion():
				p.global_position = Vector2(it.global_position.x, 224)
				await wait(0.3)
				await press("interact")
				await wait(0.25)
	if GS.inventory.count_item(&"warehouse_key") == 0:
		print("NOTE: the key was not rolled on this seed; giving it to continue the test")
		GS.inventory.add(load("res://resources/items/warehouse_key.tres"), 1)
	else:
		check(key_in != "", "key came from a store container")
	p.global_position = Vector2(wdoor.global_position.x, 224)
	await wait(0.4)
	await press("interact")
	await wait(1.8)
	check(wdoor.is_unlocked() and GS.world_get("warehouse_unlocked", false), "key unlocks the warehouse")
	await shot("d12_warehouse_unlocked")
	await press("interact")
	check(await wait_scene("res://scenes/maps/warehouse.tscn", 10.0), "enter the warehouse")
	await wait(2.0)
	await shot("d13_warehouse")

	# ---------------- warehouse: uniform ----------------
	p = player()
	var locker = current_scene.get_node("Props/StaffLocker")
	p.global_position = Vector2(locker.global_position.x, 224)
	await wait(0.3)
	await press("interact")
	await wait(2.6)
	for it in get_nodes_in_group(&"pickup"):
		if is_instance_valid(it) and not it.is_queued_for_deletion():
			p.global_position = Vector2(it.global_position.x, 224)
			await wait(0.3)
			await press("interact")
			await wait(0.25)
	var uniform: ItemData = load("res://resources/items/work_uniform.tres")
	check(GS.inventory.count_item(&"work_uniform") == 1, "work uniform found in the staff locker")
	check(GS.quick_equip(bag_index(&"work_uniform")) == "" and GS.inventory.size == 15, "equipping the uniform: 15 slots")
	# fill up to 13 used slots, then try to take it off
	var junk_items := ["parts", "junk", "soap", "bandage", "cash", "biscuits", "noodles", "water", "canned_food", "empty_bottle", "knife", "pistol", "backpack"]
	var k := 0
	while GS.inventory.used_slots() < 13 and k < junk_items.size():
		GS.inventory.add(load("res://resources/items/%s.tres" % junk_items[k]), 1)
		k += 1
	var used: int = GS.inventory.used_slots()
	var err: String = GS.unequip_to_bag("clothing")
	check(err == "背包里的东西太多了。" and GS.equip_get("clothing") == uniform and GS.inventory.used_slots() == used, "cannot take the uniform off with 13 slots used")
	# open the backpack screen to look at it
	await press("inventory")
	await wait(0.4)
	await shot("d14_inventory_uniform")
	await press("inventory")
	# drop extra test items again (keep supplies)
	for id in ["parts", "junk", "bandage", "cash", "noodles", "empty_bottle", "knife", "pistol", "backpack"]:
		GS.inventory.remove(StringName(id), 99)
	var searched_before: int = 0
	for c in get_nodes_in_group(&"loot_container"):
		if c.is_searched:
			searched_before += 1

	# ---------------- back home ----------------
	p.global_position = Vector2(48, 224)
	await wait(0.4)
	await press("interact")
	check(await wait_scene("res://scenes/maps/convenience_store.tscn", 10.0), "warehouse -> store")
	p = player()
	check(absf(p.global_position.x - (current_scene.get_node("WarehouseDoor").global_position.x + 14.0)) < 4.0, "back at the warehouse door")
	p.global_position = Vector2(current_scene.get_node("ExitDoor").global_position.x, 224)
	await wait(0.4)
	await press("interact")
	check(await wait_scene("res://scenes/maps/region_store.tscn", 10.0), "store -> region (at the store door)")
	p = player()
	check(p.global_position.x < 300.0, "region spawn at the store door")
	region = current_scene
	check(region.gate.can_interact(p), "gate opens after visiting a location")
	var carry_food: int = GS.inventory.count_tag(&"food")
	var carry_water: int = GS.inventory.count_tag(&"water")
	var camp_before: Dictionary = GS.camp_view()
	var acquired: Dictionary = GS.expedition.get("acquired", {}).duplicate()
	p.global_position = Vector2(2530, 224)
	await wait(0.5)
	await press("interact")
	check(await wait_scene("res://scenes/maps/camp_hub.tscn", 10.0), "gate -> camp")
	await wait(2.2)
	await shot("d15_settlement")
	check(GS.camp_food() == camp_before.food + carry_food and GS.camp_water() == camp_before.water + carry_water, "food and water went into the storage (+%d food +%d water)" % [carry_food, carry_water])
	check(acquired.has(&"work_uniform") and GS.equip_get("clothing") == null and GS.storage.count_item(&"work_uniform") == 1 and GS.inventory.size == 10, "the uniform found today was taken off and stored")
	check(GS.equip_get("hand1") != null and GS.equip_get("hand2") != null, "gear carried out stays with the player")
	check(GS.expedition_done_today and GS.daily.rare.has(&"work_uniform"), "day marked done; uniform is a rare find")
	await wait(3.5)
	hub = current_scene
	p = player()
	p.global_position = Vector2(hub.door_interact.global_position.x, 224)
	said.clear()
	p.said.connect(func(t): said.append(t))
	await wait(0.4)
	await press("interact")
	await wait(0.5)
	check(not hub.region_map.is_open and "今天已经很晚了，明天再出去吧。" in said, "only one outing per day")

	# ---------------- end the day ----------------
	GS.ammo = 3
	p.global_position = Vector2(hub.sister.global_position.x - 16, 224)
	await wait(0.5)
	check(hub.sister_interact.prompt_text.contains("[G] 结束本日"), "sister offers to end the day")
	await press("end_day")
	await wait(0.4)
	check(hub.confirm.is_open, "end day asks for confirmation")
	await shot("d16_end_day_confirm")
	hub.confirm.yes_btn.emit_signal("pressed")
	check(await wait_scene("res://scenes/ui/diary.tscn", 20.0), "end day -> diary")
	await wait(16.0)
	await shot("d17_diary_day2")
	var date: String = current_scene.get_node("Paper/Date").text
	var texts: Array = current_scene.get_node("Paper/Lines").get_children().map(func(l): return l.text)
	print("diary: ", date, " ", texts)
	check(date == "9月29日", "diary date 9月29日")
	check(texts[0].begins_with("今天搜到了一些") and texts[-1] == "妹妹也很开心。", "diary built from real loot")
	check(("甚至还找到了仓库的钥匙和便利店员工的工装服！" in texts) or ("甚至还搜到了便利店员工的工装服！" in texts), "rare discovery line")
	await any_key()
	check(await wait_scene("res://scenes/maps/camp_hub.tscn", 20.0), "diary -> new day")
	check(GS.day_index == 2 and GS.date_text() == "9月30日", "new day: 9月30日")
	check(GS.ammo == 10, "pistol ammo reset to 10 (not stacked)")
	check(GS.storage.count_item(&"work_uniform") == 1 and GS.inventory.size == 10, "uniform waits in the storage")
	check(GS.world_get("warehouse_unlocked", false), "warehouse stays unlocked")
	check(not GS.expedition_done_today and GS.daily.gains.is_empty(), "daily state reset")
	await shot("d18_new_day")

	print("RESULT: %s (%d failures)" % ["OK" if failures.is_empty() else "FAILED", failures.size()])
	quit(0 if failures.is_empty() else 1)
