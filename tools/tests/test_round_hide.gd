extends SceneTree
## Round 111-135 acceptance:
##  * Demo 1 -> Demo 2 day 1: every searchable in the store still shows
##    [F] 搜刮 (same init as any later day); empty / searched feedback
##  * zombie corpses never slide (idle, patrol, investigate, bottle sprint,
##    chase, knife, pistol, hide takedown)
##  * street cars / barriers no longer force a jump
##  * long story: hold Space to skip, same end state as watching it
##  * hide gameplay: bottle from a hide spot, Space lure, knife takedown
##    (knife in any slot, camera zoom, back into hiding)
##   godot --path . -s res://tools/tests/test_round_hide.gd -- [shot_dir]

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


func key(code: Key) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = true
	Input.parse_input_event(ev)
	await physics_frame
	var ev2 := InputEventKey.new()
	ev2.physical_keycode = code
	ev2.keycode = code
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


func put_in_hand(id: String, slot: String, n := 1) -> void:
	GS.equipment[slot] = {"item": item(id), "count": n}
	GS.equipment_changed.emit()


## x drift of a corpse over `t` seconds after death
func corpse_drift(z, t := 1.0) -> float:
	var x0: float = z.global_position.x
	await wait(t)
	return absf(z.global_position.x - x0)


func freeze_zombies_except(keep: Array) -> void:
	for z in get_nodes_in_group(&"zombie"):
		if not z in keep:
			z.process_mode = Node.PROCESS_MODE_DISABLED
			z.visible = false


func _run() -> void:
	GS = root.get_node("/root/GameState")
	SM = root.get_node("/root/SceneManager")
	NS = root.get_node("/root/NoiseSystem")
	await wait(0.3)
	await test_searchables()
	await test_corpses()
	await test_traversal()
	await test_hide_gameplay()
	await test_skip()
	print("RESULT: %s (%d failures)" % ["OK" if failures.is_empty() else "FAILED", failures.size()])
	quit(0 if failures.is_empty() else 1)


# --- 1. searchables ------------------------------------------------------------------
func test_searchables() -> void:
	GS.new_game()
	check(await goto("res://scenes/maps/convenience_store.tscn"), "story store")
	await wait(0.5)
	var p = player()
	# a thorough first day: every container searched
	for c in get_nodes_in_group(&"loot_container"):
		c._on_search_done(true, p)
	var blocked := 0
	for c in get_nodes_in_group(&"loot_container"):
		if not c.interactable.can_interact(p):
			blocked += 1
	check(blocked == 0, "searched containers stay interactable on the story day (%d blocked)" % blocked)
	# Demo 2, first free day — exactly the same path as any later day
	GS.start_free_phase()
	check(GS.begin_expedition(load("res://resources/locations/store.tres")), "day 1 expedition")
	GS.mark_location_visited()
	GS.spawn_point = &"location_entry"
	check(await goto("res://scenes/maps/convenience_store.tscn"), "Demo 2 day 1 store")
	p = player()
	await wait(0.5)
	# after the LootDirector ran (it may refill things): one untouched but
	# empty container, one emptied by "someone else"
	current_scene.get_node("Props/ShelfC").apply_state({"searched": false, "loot": []})
	current_scene.get_node("Props/Boxes").apply_state({"searched": true, "loot": [], "by": "world"})
	var cs := get_nodes_in_group(&"loot_container")
	blocked = 0
	for c in cs:
		if not c.interactable.can_interact(p):
			blocked += 1
	check(cs.size() == 8 and blocked == 0, "day 1: all %d searchables can be checked (%d blocked)" % [cs.size(), blocked])
	var said: Array = []
	p.said.connect(func(t): said.append(t))
	var shelf_a = current_scene.get_node("Props/ShelfA")
	p.global_position = Vector2(shelf_a.global_position.x, 224)
	await wait(0.4)
	check(p.interaction.focused == shelf_a.interactable and shelf_a.interactable.prompt_text == "搜刮", "[F] 搜刮 shown at an already searched shelf")
	await shot("r01_day1_prompt")
	# empty container, first search: a full search, then "什么都没有。"
	var shelf_c = current_scene.get_node("Props/ShelfC")
	p.global_position = Vector2(shelf_c.global_position.x, 224)
	await wait(0.4)
	await press("interact")
	await wait(0.5)
	check(p.is_searching(), "empty container: the full search runs")
	await wait(2.4)
	check(said.size() > 0 and said[-1] == "什么都没有。", "empty first search: 什么都没有。 (%s)" % str(said))
	await press("interact")
	await wait(1.4)
	check(said[-1] in ["已经搜过了。", "里面已经没东西了。"], "search again: 已经搜过了。 (%s)" % said[-1])
	var boxes = current_scene.get_node("Props/Boxes")
	p.global_position = Vector2(boxes.global_position.x, 224)
	await wait(0.4)
	await press("interact")
	await wait(1.4)
	check(said[-1] == "被人搜过了。", "emptied by someone else: 被人搜过了。 (%s)" % said[-1])
	# day 2 behaves the same
	GS.end_expedition()
	GS.camp_add("food", 5)
	GS.camp_add("water", 5)
	GS.new_day()
	GS.begin_expedition(load("res://resources/locations/store.tres"))
	GS.spawn_point = &"location_entry"
	check(await goto("res://scenes/maps/convenience_store.tscn"), "day 2 store")
	p = player()
	blocked = 0
	for c in get_nodes_in_group(&"loot_container"):
		if not c.interactable.can_interact(p):
			blocked += 1
	check(blocked == 0, "day 2: same behaviour (%d blocked)" % blocked)


# --- 2. corpses ------------------------------------------------------------------------
func test_corpses() -> void:
	GS.new_game()
	check(await goto("res://scenes/maps/street.tscn"), "street for corpse tests")
	var level = current_scene
	var p = player()
	p.set_physics_process(false)
	p.global_position = Vector2(60, 224)
	var zs: Array = []
	for z in get_nodes_in_group(&"zombie"):
		zs.append(z)
	var cases := [
		["idle", func(z): z.machine.transition_to(&"Idle", {"duration": 99.0})],
		["patrol", func(z): z.machine.transition_to(&"Patrol")],
		["investigate", func(z): z.machine.transition_to(&"Investigate", {"pos": z.global_position + Vector2(400, 0)})],
		["bottle sprint", func(z): z.machine.transition_to(&"Investigate", {"pos": z.global_position + Vector2(-400, 0), "sprint": true})],
		["chase", func(z):
			z.last_seen_pos = z.global_position + Vector2(400, 0)
			z.machine.transition_to(&"Chase")],
	]
	var i := 0
	for cs in cases:
		var z = zs[i % zs.size()]
		i += 1
		if z.dead:
			continue
		cs[1].call(z)
		await wait(0.8)
		var spd: float = absf(z.velocity.x)
		z.take_damage(9999.0, p, Vector2(1, 0))
		var drift: float = await corpse_drift(z, 1.0)
		check(z.dead and drift < 2.0 and z.machine.state_name() == &"Dead", "%s death: corpse stays (moving %.0f px/s before, drift %.1f px)" % [cs[0], spd, drift])
		z.machine.transition_to(&"Chase")
		check(z.machine.state_name() == &"Dead" and not z.attack.enabled, "%s: Dead is final, no attacks" % cs[0])
	# knife (swinging into a running zombie) and pistol
	p.set_physics_process(true)
	for z in get_nodes_in_group(&"zombie"):
		if z.dead:
			continue
		z.machine.transition_to(&"Investigate", {"pos": z.global_position + Vector2(-300, 0), "sprint": true})
		await wait(0.6)
		p.global_position = Vector2(z.global_position.x - 14, 224)
		p.hands.select(1)
		p.set_physics_process(false)
		p.facing = 1
		p.weapons.update_aim(p.shoulder_global(), z.global_position + Vector2(0, -26), 1)
		for k in 3:
			p.weapons.try_attack(p, p.shoulder_global(), 1)
			await wait(0.55)
			if z.dead:
				break
		var drift: float = await corpse_drift(z, 1.0)
		check(z.dead and drift < 2.0, "knife kill on a running zombie: no slide (%.1f px)" % drift)
		p.set_physics_process(true)
		break
	for z in get_nodes_in_group(&"zombie"):
		if z.dead:
			continue
		z.machine.transition_to(&"Investigate", {"pos": z.global_position + Vector2(300, 0), "sprint": true})
		await wait(0.6)
		p.global_position = Vector2(z.global_position.x - 120, 224)
		p.hands.select(0)
		await wait(0.2)
		p.set_physics_process(false)
		var sh: Vector2 = p.shoulder_global()
		p.weapons.update_aim(sh, z.global_position + Vector2(0, -26), 1)
		p.weapons.try_attack(p, sh, 1)
		await wait(0.1)
		var drift: float = await corpse_drift(z, 1.0)
		check(z.dead and drift < 2.0, "pistol kill on a sprinting zombie: no slide (%.1f px)" % drift)
		p.set_physics_process(true)
		break


# --- 3. traversal ------------------------------------------------------------------------
func test_traversal() -> void:
	GS.new_game()
	check(await goto("res://scenes/maps/street.tscn"), "street for traversal")
	freeze_zombies_except([])
	var p = player()
	p.global_position = Vector2(200, 224)
	var max_up := 0.0
	Input.action_press(&"move_right")
	var t := 0.0
	while t < 25.0 and p.global_position.x < 1250.0:
		await physics_frame
		t += 1.0 / 60.0
		max_up = maxf(max_up, 224.0 - p.global_position.y)
	Input.action_release(&"move_right")
	check(p.global_position.x >= 1250.0, "walked past barrier, sedan, barrier and van without jumping (x=%.0f)" % p.global_position.x)
	check(max_up < 4.0, "never had to climb (max rise %.1f px)" % max_up)


# --- 4. hide gameplay -------------------------------------------------------------------
func test_hide_gameplay() -> void:
	GS.new_game()
	check(await goto("res://scenes/maps/street.tscn"), "street for hide gameplay")
	await wait(1.5)   # the street's short intro
	var level = current_scene
	var hides := get_nodes_in_group(&"hide_spot")
	check(hides.size() >= 7, "street has more hide spots (%d)" % hides.size())
	var nook = level.get_node("Props/NookB")
	var p = player()
	var walker = level.get_node("Zombies/Pacer")
	freeze_zombies_except([walker])
	walker.global_position = Vector2(nook.global_position.x + 170, 224)
	walker.facing = 1
	walker.machine.transition_to(&"Idle", {"duration": 99.0})
	# loadout: 1 pistol, 2 knife, 3 bottles
	put_in_hand("empty_bottle", "hand3", 3)
	p.global_position = Vector2(nook.global_position.x, 224)
	await wait(0.4)
	await press("interact")
	await wait(0.4)
	check(p.is_hidden(), "hidden in the nook")
	await shot("r02_hidden_nook")
	# bottle from the hiding place
	await press("hand_3")
	await wait(0.2)
	check(p.throw.is_ready and p.is_hidden(), "bottle ready while hidden")
	var breaks: Array = []
	NS.noise_emitted.connect(func(ev): if ev.kind == &"bottle": breaks.append(ev))
	var target: Vector2 = walker.global_position + Vector2(90, 0)
	var k := Vector2(root.size) / Vector2(480, 270)
	root.warp_mouse(target * 0 + (p.get_viewport().get_canvas_transform() * target) * k)
	await wait(0.3)
	await shot("r03_hidden_aim")
	await press("attack")
	for i in 40:
		await wait(0.05)
		if not breaks.is_empty():
			break
	check(breaks.size() == 1 and GS.equip_count("hand3") == 2, "bottle thrown from the hide spot (one used)")
	check(p.is_hidden(), "still hidden after throwing")
	await wait(0.2)
	check(walker.machine.state_name() == &"Investigate", "zombie drawn by the bottle (%s)" % walker.machine.state_name())
	# let it calm down, then lure it with Space
	walker.global_position = Vector2(nook.global_position.x + 150, 224)
	walker.machine.transition_to(&"Idle", {"duration": 99.0})
	await wait(0.3)
	var lures: Array = []
	NS.noise_emitted.connect(func(ev): if ev.kind == &"hide_lure": lures.append(ev))
	await press("jump")
	await wait(0.3)
	check(lures.size() == 1 and absf(lures[0].position.x - nook.global_position.x) < 2.0, "Space in hiding: lure noise from the hide spot")
	check(p.is_hidden() and p.state == p.State.HIDDEN, "lure keeps the player hidden")
	check(walker.machine.state_name() == &"Investigate", "zombie comes to the knock (%s)" % walker.machine.state_name())
	var prompt_seen := false
	for i in 120:
		await wait(0.1)
		if p.takedown.target == walker:
			prompt_seen = true
			break
	check(prompt_seen, "zombie walks into takedown range")
	check(GS.active_hand == 2 and p.takedown.knife_slot() == 1, "knife in slot 2, bottle (slot 3) active")
	await wait(0.15)
	await shot("r04_takedown_prompt")
	var cam = get_first_node_in_group(&"game_camera")
	await press("attack")
	await wait(0.2)
	var zoomed: bool = cam.zoom.x > 1.1
	var leaning: bool = p.visual.visible and p.arm_pivot.visible and GS.active_hand == 1
	await shot("r05_takedown")
	check(zoomed, "camera zooms in (zoom %.2f)" % cam.zoom.x)
	check(leaning, "the brother leans out with the knife")
	await wait(0.9)
	check(walker.dead, "zombie killed")
	var drift: float = await corpse_drift(walker, 0.8)
	check(drift < 2.0, "takedown corpse stays (%.1f px)" % drift)
	check(p.is_hidden() and not p.visual.visible, "back in hiding")
	check(GS.active_hand == 2 and p.throw.is_ready, "active slot restored to 3 (bottle)")
	check(absf(cam.zoom.x - 1.0) < 0.01, "camera zoom restored")
	# two zombies: only the nearest is the target
	var za = level.get_node("Zombies/Walker")
	var zb = level.get_node("Zombies/Doorman")
	for z in [za, zb]:
		z.process_mode = Node.PROCESS_MODE_INHERIT
		z.visible = true
		z.machine.transition_to(&"Idle", {"duration": 99.0})
	za.global_position = Vector2(nook.global_position.x + 30, 224)
	zb.global_position = Vector2(nook.global_position.x - 20, 224)
	await wait(0.3)
	check(p.takedown.target == zb, "two in reach: the nearest one is the target")
	# no knife anywhere: no takedown
	var knife_backup = GS.equipment.hand2
	GS.equipment.hand2 = null
	GS.equipment_changed.emit()
	await wait(0.2)
	check(p.takedown.target == null and not p.takedown.can_perform(), "no knife in any slot: no takedown")
	GS.equipment.hand2 = knife_backup
	GS.equipment_changed.emit()


# --- 5. cutscene skip -----------------------------------------------------------------------
func camp_state() -> Dictionary:
	GS.new_game()
	GS.inventory.add(item("water"), 4)
	GS.inventory.add(item("canned_food"), 4)
	GS.flags["store_done"] = true
	GS.loot_seed = 12345
	return {}


func test_skip() -> void:
	# watch it
	camp_state()
	check(await goto("res://scenes/maps/school_camp.tscn"), "camp story (watch)")
	var p = player()
	var p_jump := false
	check(await wait_scene("res://scenes/ui/diary.tscn", 240.0), "story played to the end -> diary")
	var watched := {"diary": GS.pending_diary.duplicate(true), "state": GS.snapshot()}
	# skip it
	camp_state()
	check(await goto("res://scenes/maps/school_camp.tscn"), "camp story (skip)")
	var level = current_scene
	await wait(0.6)
	check(level.skipper != null and level.skipper.is_hint_visible(), "hint 长按 Space 跳过 shown at the start")
	await shot("r06_skip_hint")
	await wait(4.5)
	check(not level.skipper.is_hint_visible(), "hint fades out")
	await key(KEY_K)
	await wait(0.4)
	check(level.skipper.is_hint_visible(), "any key brings the hint back")
	# a short tap does not skip
	await press("jump")
	await wait(0.6)
	check(current_scene == level and not level._story_done, "a tap on Space does not skip")
	Input.action_press(&"jump")
	await wait(1.3)
	Input.action_release(&"jump")
	check(await wait_scene("res://scenes/ui/diary.tscn", 20.0, level), "hold Space -> skipped to the diary")
	var skipped := {"diary": GS.pending_diary.duplicate(true), "state": GS.snapshot()}
	check(watched.diary == skipped.diary, "same diary page / next step as watching")
	check(watched.state == skipped.state, "same game state as watching")
