extends SceneTree
## End-to-end run of the whole demo through the real scene flow:
## menu -> store (intro, flashlight, loot, inventory, exit) -> street
## (checkpoint, detection, roar, chase, death, game over, restart, cross)
## -> loading -> camp (full ending dialogue) -> Demo End -> menu.
##   godot --path . -s res://tools/tests/test_full_flow.gd -- [shot_dir]

var shot_dir := ""
var failures: Array[String] = []
var GS: Node
var SM: Node


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


func wait_scene(path: String, timeout: float) -> bool:
	var t := 0.0
	while t < timeout:
		if current_scene and current_scene.scene_file_path == path and not SM.is_busy():
			return true
		await wait(0.2)
		t += 0.2
	return false


func player():
	return get_first_node_in_group(&"player")


func _run() -> void:
	GS = root.get_node("/root/GameState")
	SM = root.get_node("/root/SceneManager")
	SM.scene_changed.connect(func(pth): print("[scene] ", pth))
	change_scene_to_file("res://scenes/ui/main_menu.tscn")
	await wait(2.5)
	await shot("01_menu")
	check(current_scene.name == "MainMenu", "main menu loads")
	current_scene.get_node("UI/Menu/Start").emit_signal("pressed")
	check(await wait_scene("res://scenes/maps/convenience_store.tscn", 10.0), "start -> convenience store")

	# --- store intro
	var p = player()
	var lines: Array = []
	p.said.connect(func(t): lines.append(t))
	await wait(4.5)
	await shot("02_wake")
	check(p.state == 3, "player in cutscene during wake-up")
	for i in 150:
		await wait(0.1)
		if p.state == 0:
			break
	check("我居然在这种地方睡着了吗……" in lines and "不行，我得加快了。" in lines, "wake-up lines spoken")
	check(p.state == 0, "control returned after intro")
	await press("flashlight")
	await wait(1.5)
	check(p.flashlight.is_on, "flashlight on with H")
	check(GS.objective.get("id") == &"store_supplies" and GS.objective.active, "loot objective started")
	await shot("03_flashlight")

	# --- loot everything
	var containers := get_nodes_in_group(&"loot_container")
	for c in containers:
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
	await wait(1.0)
	for it in get_nodes_in_group(&"pickup"):
		if is_instance_valid(it) and not it.is_queued_for_deletion():
			p.global_position = Vector2(it.global_position.x, 224)
			await wait(0.3)
			await press("interact")
			await wait(0.25)
	check(GS.inventory.count_tag(&"water") >= 4 and GS.inventory.count_tag(&"food") >= 4, "water>=4 food>=4 collected (%d/%d)" % [GS.inventory.count_tag(&"water"), GS.inventory.count_tag(&"food")])
	check(GS.inventory.count_item(&"cash") > 0, "cash from the register")
	await press("inventory")
	await wait(0.4)
	await shot("04_inventory")
	await press("inventory")
	await wait(3.0)
	check("物资准备完成。" in lines, "completion line spoken")
	var door = current_scene.get_node("ExitDoor")
	check(door.unlocked, "exit unlocked")
	p.global_position = Vector2(door.global_position.x, 224)
	await wait(0.4)
	await press("interact")
	check(await wait_scene("res://scenes/maps/street.tscn", 10.0), "store exit -> street")

	# --- street: checkpoint
	check(GS.checkpoint.get("id") == &"street", "street checkpoint created on entry")
	var cp_ammo: int = GS.checkpoint.ammo
	p = player()
	lines.clear()
	p.said.connect(func(t): lines.append(t))
	await wait(1.6)
	await shot("05_street")
	# walk into the first-sight trigger
	p.global_position = Vector2(300, 224)
	await wait(3.5)
	check("还是不要招惹这些家伙比较好……" in lines, "street warning line")

	# --- get caught on purpose: fire the pistol near two zombies
	var walker = current_scene.get_node("Zombies/Walker")
	var doorman = current_scene.get_node("Zombies/Doorman")
	p.global_position = Vector2(walker.global_position.x - 90, 224)
	p.hands.select(0)   # hand slot 1 = pistol
	await wait(0.3)
	p.weapons.update_aim(p.shoulder_global(), p.shoulder_global() + Vector2(0, -100), 1)
	p.weapons.try_attack(p, p.shoulder_global(), 1)
	await wait(0.3)
	check(GS.ammo == cp_ammo - 1, "gunshot used a bullet")
	check(walker.machine.state_name() in [&"Investigate", &"Alert", &"Chase", &"Suspicious"], "gunshot draws the walker (%s)" % walker.machine.state_name())
	var alerted := false
	for i in 100:
		await wait(0.1)
		if walker.machine.state_name() in [&"Chase", &"Attack"]:
			alerted = true
			break
	check(alerted, "walker alerted and chasing")
	check(doorman.machine.state_name() != &"Idle", "doorman reacts to the noise chain (%s)" % doorman.machine.state_name())
	await shot("06_chase")
	for i in 300:
		await wait(0.1)
		if p.is_dead():
			break
	check(p.is_dead(), "player killed")
	var go: Node = null
	for i in 150:
		await wait(0.1)
		go = root.get_node_or_null("GameOver")
		if go:
			break
	check(go != null, "game over shown")
	await wait(5.0)
	await shot("07_gameover")
	go.get_node("Root/Center/VBox/Buttons/Restart").emit_signal("pressed")
	check(await wait_scene("res://scenes/maps/street.tscn", 10.0), "restart -> street checkpoint")
	check(GS.ammo == cp_ammo, "ammo reset to checkpoint (%d)" % GS.ammo)
	check(GS.inventory.count_tag(&"water") >= 4, "supplies kept")

	# --- cross the street (teleport along a sneaking route, using a hide spot)
	p = player()
	p.movement.sneak_toggled = true
	await wait(1.5)
	for x in [372, 486, 716, 1024, 1380, 1620, 1920, 2172, 2400]:
		p = player()
		p.global_position = Vector2(x, 180 if x in [486] else 224)
		await wait(0.6)
		if p.is_dead():
			break
	check(not p.is_dead(), "crossed without dying")
	p.global_position = Vector2(2540, 224)
	check(await wait_scene("res://scenes/maps/school_camp.tscn", 20.0), "street exit -> loading -> camp")

	# --- camp: the ending
	await wait(8.0)
	await shot("08_camp")
	var dp = current_scene.get_node("DialoguePlayer")
	var spoken: Array = []
	dp.line_started.connect(func(s, t): spoken.append(t))
	for i in 1200:
		await wait(0.25)
		if not is_instance_valid(dp) or not dp.playing:
			break
		if i % 3 == 0:
			await press("interact")
		if i == 60:
			await shot("09_dialogue")
	check("早点回来。" in spoken and "别让我等太久。" in spoken and "嗯。" in spoken, "ending dialogue played (%d lines)" % spoken.size())
	check(await wait_scene("res://scenes/ui/diary.tscn", 40.0), "fade -> first diary page (9月28日)")
	await wait(18.0)
	await shot("10_diary")
	check(current_scene.get_node("Paper/Date").text == "9月28日", "diary date")
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_SPACE
	ev.pressed = true
	Input.parse_input_event(ev)
	check(await wait_scene("res://scenes/maps/camp_hub.tscn", 20.0), "diary -> task update -> day 2 camp hub")
	check(GS.is_free_phase() and GS.objective.title == "寻找能够治疗哮喘病的药", "Demo 2 starts with the medicine task")

	print("RESULT: %s (%d failures)" % ["OK" if failures.is_empty() else "FAILED", failures.size()])
	quit(0 if failures.is_empty() else 1)
