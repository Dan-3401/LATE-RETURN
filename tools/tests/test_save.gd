extends SceneTree
## Save system test: autosave points (street checkpoint, camp hub, expedition
## checkpoint), continue from the main menu, no double cost when resuming an
## expedition, overwrite confirmation for a new game, corrupt file handling.
##   godot --path . -s res://tools/tests/test_save.gd -- [shot_dir]

var shot_dir := ""
var failures: Array[String] = []
var GS: Node
var SM: Node
var SS: Node
var saves := 0


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


func player():
	return get_first_node_in_group(&"player")



func goto(path: String) -> bool:
	var old := current_scene
	SM.change_scene(path, 0.2)
	return await wait_scene(path, 20.0, old)


func raw_save() -> Dictionary:
	var f := FileAccess.open(SS.path, FileAccess.READ)
	return f.get_var(false) if f else {}


func _run() -> void:
	GS = root.get_node("/root/GameState")
	SM = root.get_node("/root/SceneManager")
	SS = root.get_node("/root/SaveSystem")
	SS.saved.connect(func(): saves += 1)
	await wait(0.5)

	# --- 0. basics ------------------------------------------------------------
	check(SS.path.begins_with("user://savegame_test_"), "tests use their own save file")
	check(not SS.has_save(), "no save at start")
	var f := FileAccess.open(SS.path, FileAccess.WRITE)
	f.store_string("definitely not a save")
	f.close()
	check(not SS.has_save() and SS.load_game() == "", "corrupt file is ignored")
	SS.delete_save()

	# --- 1. story: street checkpoint autosaves --------------------------------------
	GS.new_game()
	GS.inventory.add(load("res://resources/items/water.tres"), 2)
	check(await goto("res://scenes/maps/street.tscn"), "street loaded")
	await wait(0.5)
	var info: Dictionary = SS.read_info()
	check(SS.has_save() and info.place == "街道" and info.date == "9月28日", "street checkpoint autosaved (%s)" % str(info))
	check(saves == 1, "save indicator signal fired")
	await shot("s01_saved_indicator")

	# --- 2. free phase: the camp hub autosaves --------------------------------------
	GS.start_free_phase()
	check(await goto("res://scenes/maps/camp_hub.tscn"), "camp hub loaded")
	await wait(0.5)
	info = SS.read_info()
	check(info.place == "学校营地" and info.date == "9月29日", "camp hub autosaved (%s)" % str(info))
	var camp_saved: Dictionary = GS.camp.duplicate()
	GS.camp_add("food", 50)
	GS.inventory.add(load("res://resources/items/junk.tres"), 1)
	GS.new_game()
	var scene: String = SS.load_game()
	check(scene == "res://scenes/maps/camp_hub.tscn", "load returns the camp hub")
	check(GS.is_free_phase() and GS.day_index == 1 and GS.camp == camp_saved, "state restored (camp %s)" % str(GS.camp))
	check(GS.objective.title == "寻找能够治疗哮喘病的药" and GS.inventory.count_item(&"junk") == 0, "objective restored, unsaved changes gone")

	# --- 3. continue from the main menu -----------------------------------------------
	GS.new_game()
	check(await goto("res://scenes/ui/main_menu.tscn"), "main menu")
	await wait(3.2)
	var menu = current_scene
	check(menu.continue_btn.visible and menu.start_btn.text == "新游戏", "menu offers 继续游戏 / 新游戏")
	check(menu.save_info.text == "9月29日 · 学校营地", "menu shows the save (%s)" % menu.save_info.text)
	await shot("s02_menu_continue")
	menu.continue_btn.emit_signal("pressed")
	check(await wait_scene("res://scenes/maps/camp_hub.tscn", 20.0, menu), "继续游戏 -> camp hub")
	check(GS.day_index == 1 and GS.camp == camp_saved and GS.is_free_phase(), "continued game has the saved state")

	# --- 4. expedition checkpoint: resume without paying twice --------------------------
	var hub = current_scene
	var store_loc = load("res://resources/locations/store.tres")
	check(GS.begin_expedition(store_loc), "expedition started")
	var camp_after_pay: Dictionary = GS.camp.duplicate()
	var old := current_scene
	SM.change_scene(store_loc.region_scene, 0.2)
	check(await wait_scene(store_loc.region_scene, 20.0, old), "region loaded")
	info = SS.read_info()
	check(info.place == "外出途中", "expedition checkpoint autosaved (%s)" % str(info))
	GS.inventory.add(load("res://resources/items/water.tres"), 3)   # picked up after the save
	GS.new_game()
	scene = SS.load_game()
	check(scene == store_loc.region_scene and GS.camp == camp_after_pay, "resume at the expedition start, cost paid once (%s)" % str(GS.camp))
	check(GS.expedition.get("active", false) and GS.inventory.count_item(&"water") == 0, "expedition active, no duplicated loot")
	old = current_scene
	SM.change_scene(scene, 0.2)
	check(await wait_scene(scene, 20.0, old), "resumed region")
	var region = current_scene
	check(absf(player().global_position.x - region.start_x) < 4.0 and GS.camp == camp_after_pay, "player at the region start, no second charge")

	# --- 5. come home: the hub saves the finished outing ---------------------------------
	GS.mark_location_visited()
	region._on_gate(null)
	check(await wait_scene("res://scenes/maps/camp_hub.tscn", 20.0, region), "home")
	await wait(0.3)
	var raw := raw_save()
	check(raw.state.expedition_done_today == true and raw.state.expedition.is_empty() and raw.checkpoint.is_empty(), "save after coming home: outing done, no stale checkpoint")
	GS.new_game()
	SS.load_game()
	check(GS.expedition_done_today and GS.pending_settlement.is_empty(), "loaded: today's outing done, settlement not replayed")

	# --- 6. pause menu note ---------------------------------------------------------------
	old = current_scene
	SM.change_scene("res://scenes/maps/camp_hub.tscn", 0.2)
	await wait_scene("res://scenes/maps/camp_hub.tscn", 20.0, old)
	await wait(0.8)
	await press("pause")
	await wait(0.3)
	await shot("s03_pause_note")
	await press("pause")
	await wait(0.3)

	# --- 7. new game asks before overwriting ---------------------------------------------
	check(await goto("res://scenes/ui/main_menu.tscn"), "back to menu")
	await wait(3.2)
	menu = current_scene
	menu.start_btn.emit_signal("pressed")
	await wait(0.3)
	check(menu.confirm.is_open, "new game asks for confirmation")
	await shot("s04_overwrite_confirm")
	menu.confirm.no_btn.emit_signal("pressed")
	await wait(0.3)
	check(SS.has_save() and current_scene == menu, "declined: save kept, still in the menu")
	menu.start_btn.emit_signal("pressed")
	await wait(0.3)
	menu.confirm.yes_btn.emit_signal("pressed")
	await wait(0.3)
	check(not SS.has_save(), "accepted: old save removed")
	check(await wait_scene("res://scenes/maps/convenience_store.tscn", 20.0, menu), "new game starts in the store")
	check(GS.day_index == 0 and not GS.is_free_phase(), "fresh state")

	SS.delete_save()
	print("RESULT: %s (%d failures)" % ["OK" if failures.is_empty() else "FAILED", failures.size()])
	quit(0 if failures.is_empty() else 1)
