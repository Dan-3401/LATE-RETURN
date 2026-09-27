extends SceneTree
## Automated store loop test (run with a display for screenshots):
##   godot --path . -s res://tools/tests/test_store.gd -- <shot_dir>
## Searches every container, picks up every drop through the real
## interaction path, then checks inventory, objective and exit unlock.

var shot_dir := ""
var failures: Array[String] = []
var GS: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	shot_dir = args[0] if args.size() > 0 else ""
	_run.call_deferred()


func check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + msg)
	if not cond:
		failures.append(msg)


func shot(name: String) -> void:
	if shot_dir == "" or DisplayServer.get_name() == "headless":
		return
	await process_frame
	root.get_texture().get_image().save_png(shot_dir + "/" + name + ".png")


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


func _run() -> void:
	GS = root.get_node("/root/GameState")
	GS.new_game()
	var packed: PackedScene = load("res://scenes/maps/convenience_store.tscn")
	var level := packed.instantiate()
	level.set("skip_intro", true)
	root.add_child(level)
	current_scene = level
	await wait(1.0)
	var player: Player = get_first_node_in_group(&"player")
	check(player != null, "player exists")
	check(GS.objective.get("active", false), "objective active")
	var exit_door := level.get_node("ExitDoor")
	check(not exit_door.unlocked, "exit locked at start")

	# total guaranteed loot
	var water := 0
	var food := 0
	var containers := get_nodes_in_group(&"loot_container")
	for c in containers:
		for e in c.loot:
			if e.item.task_tag == &"water":
				water += e.count
			elif e.item.task_tag == &"food":
				food += e.count
	check(water >= 4 and food >= 4, "guaranteed loot water=%d food=%d" % [water, food])

	# walk to the exit while locked -> player line
	player.global_position = Vector2(exit_door.global_position.x - 60, 224)
	await wait(0.3)
	var said := [""]
	player.said.connect(func(t): said[0] = t)
	player.global_position = Vector2(exit_door.global_position.x, 224)
	await wait(0.4)
	check(said[0] == "还没有搜集到足够的物资呢。", "locked exit line (%s)" % said[0])
	await shot("store_locked_exit")

	player.flashlight.set_on(true)
	var first := true
	for c in containers:
		player.global_position = Vector2(c.global_position.x + (-18 if c.name == "Counter" else 0), 224)
		await wait(0.25)
		await press("interact")
		await wait(1.0)
		if first:
			await shot("store_searching")
		check(player.is_searching() or c.is_searched, "searching %s" % c.name)
		await wait(1.4)
		check(c.is_searched, "searched %s" % c.name)
		if first:
			await wait(0.2)
			await shot("store_drops")
			first = false
		await wait(0.9)
		# pick up everything that dropped
		for p in get_nodes_in_group(&"pickup"):
			if not is_instance_valid(p):
				continue
			player.global_position = Vector2(p.global_position.x, 224)
			await wait(0.2)
			await press("interact")
			await wait(0.25)
	# stragglers
	for p in get_nodes_in_group(&"pickup"):
		if is_instance_valid(p) and not p.is_queued_for_deletion():
			player.global_position = Vector2(p.global_position.x, 224)
			await wait(0.2)
			await press("interact")
			await wait(0.25)
	# second search of a container must be impossible
	var c0 = containers[0]
	check(not c0.interactable.can_interact(player), "container can only be searched once")

	var inv: Inventory = GS.inventory
	print("inventory: ", inv.to_data().map(func(s): return null if s == null else "%s x%d" % [s.path.get_file(), s.count]))
	check(inv.count_tag(&"water") >= 4, "water >= 4 (%d)" % inv.count_tag(&"water"))
	check(inv.count_tag(&"food") >= 4, "food >= 4 (%d)" % inv.count_tag(&"food"))
	check(inv.count_item(&"cash") > 0, "cash from register (%d)" % inv.count_item(&"cash"))
	check(GS.is_objective_complete(), "objective complete")
	await wait(2.5)
	check(exit_door.unlocked, "exit unlocked")

	# inventory screen
	await press("inventory")
	await wait(0.3)
	await shot("store_inventory")
	var inv_ui = level.get_node("HUD/InventoryUI")
	check(inv_ui.is_open(), "inventory opens with Tab")
	await press("inventory")
	await wait(0.2)
	check(not inv_ui.is_open(), "inventory closes with Tab")

	# leave through the exit
	player.global_position = Vector2(exit_door.global_position.x, 224)
	await wait(0.4)
	await shot("store_exit_prompt")
	await press("interact")
	await wait(0.5)
	check(GS.flags.get("store_done", false), "exit used")

	print("RESULT: %s (%d failures)" % ["OK" if failures.is_empty() else "FAILED", failures.size()])
	quit(0 if failures.is_empty() else 1)
