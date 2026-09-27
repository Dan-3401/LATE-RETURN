extends SceneTree
## Street / AI / death / checkpoint test.
##   godot --path . -s res://tools/tests/test_street.gd -- [shot_dir]

var shot_dir := ""
var failures: Array[String] = []
var GS: Node
var level: Node
var player


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


func z(name: String):
	return level.get_node("Zombies/" + name)


func load_street() -> void:
	change_scene_to_file("res://scenes/maps/street.tscn")
	await process_frame
	await process_frame
	level = current_scene
	await wait(2.0)
	player = get_first_node_in_group(&"player")


func _run() -> void:
	GS = root.get_node("/root/GameState")
	GS.new_game()
	# pretend we come from the store with supplies
	GS.inventory.add(load("res://resources/items/water.tres"), 4)
	GS.inventory.add(load("res://resources/items/canned_food.tres"), 4)
	GS.ammo = 7
	await load_street()
	check(GS.checkpoint.get("id") == &"street", "street checkpoint created")
	check(GS.checkpoint.get("ammo") == 7, "checkpoint stores ammo")

	# --- 1. calm zombies move (not statues)
	var walker = z("Walker")
	var x0: float = walker.global_position.x
	await wait(4.0)
	var moved: bool = absf(walker.global_position.x - x0) > 2.0 or walker.machine.state_name() == &"Idle"
	check(moved, "walker patrols (state=%s dx=%.1f)" % [walker.machine.state_name(), walker.global_position.x - x0])

	# --- 2. sneaking in grass behind the zombie stays unnoticed
	player.global_position = Vector2(372, 224)   # Grass1
	player.movement.sneak_toggled = true
	await wait(1.5)
	check(player.stealth.in_grass(), "player registered in grass")
	check(player.stealth.presence < 0.2, "presence low in grass while still (%.2f)" % player.stealth.presence)
	check(walker.vision.suspicion < 0.3, "walker not suspicious of sneaking player in grass (%.2f)" % walker.vision.suspicion)

	# --- 3. hearing: a noise makes a calm zombie investigate the noise position
	var drifter = z("Drifter")
	player.global_position = Vector2(150, 224)
	await wait(0.5)
	var np: Vector2 = drifter.global_position + Vector2(-70, 0)
	root.get_node("/root/NoiseSystem").emit_noise(np, 150.0, null, &"impact")
	await wait(0.2)
	check(drifter.machine.state_name() == &"Investigate", "noise -> Investigate (%s)" % drifter.machine.state_name())
	check(drifter.last_heard_pos.distance_to(np) < 1.0, "zombie only knows the noise position")
	await wait(6.0)
	check(drifter.machine.state_name() in [&"Search", &"Investigate", &"Return", &"Idle", &"Wander"], "investigate -> search/return (%s)" % drifter.machine.state_name())

	# --- 4. hide spot: hiding unseen gives presence 0, zombie walking by does not notice
	var dumpster = level.get_node("Props/Dumpster1")
	player.movement.sneak_toggled = false
	player.global_position = Vector2(dumpster.global_position.x, 224)
	await wait(0.3)
	player.interaction.try_interact()
	await wait(0.4)
	check(player.is_hidden(), "player hidden in dumpster")
	check(player.stealth.presence == 0.0, "presence 0 while hidden")
	walker.global_position = Vector2(dumpster.global_position.x - 40, 224)
	walker.facing = 1
	await wait(2.0)
	check(walker.vision.suspicion == 0.0 and not walker.vision.can_see, "zombie next to hide spot cannot see hidden player")
	await shot("street_hidden")
	player.stealth.hide_spot.release(player)
	await wait(0.2)
	check(not player.is_hidden(), "player left hide spot")

	# --- 5. seen entering a hide spot: zombie comes to search, does not forget
	await load_street()
	walker = z("Walker")
	dumpster = level.get_node("Props/Dumpster1")
	walker.global_position = Vector2(dumpster.global_position.x - 120, 224)
	walker.facing = 1
	walker.machine.transition_to(&"Idle", {"duration": 99.0})
	player.global_position = Vector2(dumpster.global_position.x, 224)
	await wait(0.5)   # zombie starts seeing the player
	walker.vision.suspicion = 0.6
	walker.vision.time_since_seen = 0.0
	player.interaction.try_interact()
	await wait(0.3)
	check(player.is_hidden(), "player hid while being watched")
	var st: StringName = walker.machine.state_name()
	check(st == &"Investigate" or st == &"Search", "witness goes to investigate hide spot (%s)" % st)
	await wait(5.0)
	check(walker.machine.state_name() == &"Search", "zombie searches at the hide spot (%s)" % walker.machine.state_name())
	check(absf(walker.global_position.x - dumpster.global_position.x) < 40.0, "zombie lingers near hide spot")
	await shot("street_search_hide")
	check(player.is_hidden() and not player.is_dead(), "hidden player not found")
	for i in 600:   # the witnessed-hide search is long by design (search_time × 2.8)
		await wait(0.1)
		if walker.machine.state_name() in [&"Return", &"Idle", &"Patrol", &"PatrolResume"]:
			break
	check(walker.machine.state_name() in [&"Return", &"Idle", &"Patrol", &"PatrolResume"], "zombie gives up and returns (%s)" % walker.machine.state_name())
	player.stealth.hide_spot.release(player)

	# --- 6. detection -> alert -> roar -> others investigate -> chase -> attack -> death
	await load_street()
	walker = z("Walker")
	var doorman = z("Doorman")
	walker.machine.transition_to(&"Idle", {"duration": 99.0})
	walker.facing = -1
	player.global_position = Vector2(walker.global_position.x - 70, 224)
	player.movement.sneak_toggled = false
	player.flashlight.set_on(true)
	var roars := [0]
	root.get_node("/root/NoiseSystem").noise_emitted.connect(func(ev): if ev.kind == &"roar": roars[0] += 1)
	var alerted := false
	for i in 60:
		await wait(0.1)
		if walker.machine.state_name() in [&"Alert", &"Chase", &"Attack"]:
			alerted = true
			break
	check(alerted, "zombie spots a visible player (%s, sus=%.2f)" % [walker.machine.state_name(), walker.vision.suspicion])
	await wait(0.6)
	await shot("street_alert")
	check(roars[0] >= 1, "alert roar emitted as noise")
	await wait(0.6)
	check(doorman.machine.state_name() in [&"Investigate", &"Suspicious", &"Alert", &"Chase", &"Search"], "roar draws nearby zombie (%s)" % doorman.machine.state_name())
	check(walker.machine.state_name() in [&"Chase", &"Attack"], "walker chases (%s)" % walker.machine.state_name())
	var hp0: float = player.health.hp
	for i in 80:
		await wait(0.1)
		if player.health.hp < hp0:
			break
	check(player.health.hp < hp0, "zombie attack damages player (%.0f -> %.0f)" % [hp0, player.health.hp])
	await shot("street_chase")
	# stand still until dead
	for i in 200:
		await wait(0.1)
		if player.is_dead():
			break
	check(player.is_dead(), "player dies after repeated attacks")
	await wait(2.5)
	check(walker.machine.state_name() == &"Feed", "zombie feeds on the body (%s)" % walker.machine.state_name())
	await shot("street_death")
	var go: Node = null
	for i in 120:
		await wait(0.1)
		go = root.get_node_or_null("GameOver")
		if go:
			break
	check(go != null, "GAME OVER screen shown")
	await wait(3.5)
	await shot("street_gameover")

	# --- 7. restart -> back to street checkpoint, state restored
	GS.ammo = 1
	go.get_node("Root/Center/VBox/Buttons/Restart").emit_signal("pressed")
	await wait(4.0)
	var cs := current_scene
	check(cs != null and cs.scene_file_path == "res://scenes/maps/street.tscn", "restart loads street (%s)" % (cs.scene_file_path if cs else "null"))
	check(GS.ammo == 7, "ammo restored to checkpoint (%d)" % GS.ammo)
	check(GS.inventory.count_tag(&"water") == 4 and GS.inventory.count_tag(&"food") == 4, "supplies kept after restart")
	var p2 = get_first_node_in_group(&"player")
	check(p2 != null and not p2.is_dead() and p2.health.hp == GS.checkpoint.hp, "player alive at checkpoint hp")
	check(p2.global_position.x < 200.0, "player back at street start")
	level = cs

	# --- 8. pistol one-shot + knife sneak kill
	player = p2
	walker = z("Walker")
	walker.machine.transition_to(&"Idle", {"duration": 99.0})
	walker.facing = 1
	player.global_position = Vector2(walker.global_position.x - 12, 224)   # behind it
	player.weapons.equip(player.weapons.knife)
	player.facing = 1
	await wait(0.2)
	player.set_physics_process(false)   # keep the scripted aim (no mouse in tests)
	player.weapons.update_aim(player.shoulder_global(), walker.global_position + Vector2(0, -26), 1)
	check(walker.is_vulnerable_to_sneak_attack(player), "zombie vulnerable from behind")
	player.weapons.try_attack(player, player.shoulder_global() + Vector2(0, 0), 1)
	# aim toward the zombie
	await wait(0.5)
	check(walker.dead, "knife sneak attack kills unaware zombie (hp=%.0f)" % walker.hp)
	var drifter2 = z("Drifter")
	player.weapons.equip(player.weapons.pistol)
	player.global_position = Vector2(drifter2.global_position.x - 120, 224)
	await wait(0.2)
	var ammo0: int = GS.ammo
	var shoulder: Vector2 = player.shoulder_global()
	player.weapons.update_aim(shoulder, drifter2.global_position + Vector2(0, -26), 1)
	player.weapons.try_attack(player, shoulder, 1)
	await wait(0.3)
	check(GS.ammo == ammo0 - 1, "pistol uses ammo")
	check(drifter2.dead, "pistol shot kills zombie")

	print("RESULT: %s (%d failures)" % ["OK" if failures.is_empty() else "FAILED", failures.size()])
	quit(0 if failures.is_empty() else 1)
