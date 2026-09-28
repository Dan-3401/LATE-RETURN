extends SceneTree
## Settings (spec 136-155): defaults, audio buses / dB mapping / live
## volume, persistence, display modes and resolutions actually applied to
## the window (the 480x270 world view never changes), the keep-settings
## countdown, and both entry points (main menu / pause menu) returning to
## where they came from.
## Run on a big virtual screen so 2560x1440 fits:
##   xvfb-run -s "-screen 0 3840x2160x24" godot --path . -s res://tools/tests/test_settings.gd -- [shot_dir]

var shot_dir := ""
var failures: Array[String] = []
var S: Node
var SM: Node
var GS: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	shot_dir = args[0] if args.size() > 0 else ""
	_run.call_deferred()


func check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + msg)
	if not cond:
		failures.append(msg)


func wait(t: float) -> void:
	await create_timer(t).timeout


## The real output on the (virtual) monitor, not just the 480x270 viewport.
func screen_shot(n: String) -> void:
	if shot_dir == "" or DisplayServer.get_name() == "headless":
		return
	await process_frame
	await process_frame
	var img: Image = null
	if DisplayServer.has_method(&"screen_get_image"):
		img = DisplayServer.screen_get_image(DisplayServer.window_get_current_screen())
	if img == null or img.is_empty():
		img = root.get_texture().get_image()
	else:
		var pos := DisplayServer.window_get_position()
		var size := DisplayServer.window_get_size()
		img = img.get_region(Rect2i(pos, size))
	img.save_png(shot_dir + "/" + n + ".png")


func press(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	await process_frame
	var ev2 := InputEventAction.new()
	ev2.action = action
	ev2.pressed = false
	Input.parse_input_event(ev2)
	await process_frame


func goto(path: String) -> void:
	var old := current_scene
	SM.change_scene(path, 0.05)
	while current_scene == old or current_scene == null or SM.is_busy():
		await wait(0.1)
	await wait(0.6)
	SM.set_black(0.0)


func bus_db(name: String) -> float:
	return AudioServer.get_bus_volume_db(AudioServer.get_bus_index(name))


func _run() -> void:
	S = root.get_node("/root/Settings")
	SM = root.get_node("/root/SceneManager")
	GS = root.get_node("/root/GameState")
	await wait(0.3)
	check(S.path.begins_with("user://settings_test_"), "tests use their own settings file")

	# --- defaults -------------------------------------------------------------------------
	check(S.display_mode == S.DisplayMode.BORDERLESS and S.resolution == S.screen_size(), "first start: borderless at the monitor resolution (%s)" % str(S.resolution))
	check(S.master == 80 and S.music == 70 and S.sfx == 80, "first start: 80 / 70 / 80")
	check(FileAccess.file_exists(S.path), "defaults written to the settings file")

	# --- audio -----------------------------------------------------------------------------
	for b in ["Master", "Music", "SFX", "Ambience", "World", "UI", "Voice"]:
		check(AudioServer.get_bus_index(b) >= 0, "bus %s exists" % b)
	check(AudioServer.get_bus_send(AudioServer.get_bus_index("Ambience")) == &"Music", "ambience -> Music")
	for b in ["World", "UI", "Voice"]:
		check(AudioServer.get_bus_send(AudioServer.get_bus_index(b)) == &"SFX", "%s -> SFX" % b)
	check(absf(S.volume_to_db(100)) < 0.01 and absf(S.volume_to_db(50) + 12.04) < 0.2 and S.volume_to_db(0) <= -79.0, "0..100 maps to a proper dB curve (50 = %.1f dB)" % S.volume_to_db(50))
	S.set_volume("Music", 25)
	check(absf(bus_db("Music") - S.volume_to_db(25)) < 0.01, "music slider applies at once (%.1f dB)" % bus_db("Music"))
	S.set_volume("SFX", 0)
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")), "SFX 0 = muted")
	S.set_volume("Master", 60)
	check(absf(bus_db("Master") - S.volume_to_db(60)) < 0.01, "master applies at once")

	# --- persistence ("restart") -------------------------------------------------------------
	S.set_volume("SFX", 45)
	S.resolution = Vector2i(1600, 900)
	S.display_mode = S.DisplayMode.WINDOWED
	S.save_settings()
	S.master = 1
	S.music = 1
	S.sfx = 1
	S.resolution = Vector2i(1, 1)
	check(S.load_settings(), "settings file reads back")
	check(S.master == 60 and S.music == 25 and S.sfx == 45 and S.resolution == Vector2i(1600, 900) and S.display_mode == S.DisplayMode.WINDOWED, "values survive a restart")

	# --- display: really apply to the window -------------------------------------------------
	S.apply_display_enabled = true
	await goto("res://scenes/maps/camp_hub.tscn")
	var cam = get_first_node_in_group(&"game_camera")
	print("screen size: ", S.screen_size(), " resolutions: ", S.resolutions())
	for r in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440)]:
		S.display_mode = S.DisplayMode.WINDOWED
		S.set_resolution(r)
		await wait(0.6)
		var ws := DisplayServer.window_get_size()
		check(ws == S.windowed_size(), "windowed %s -> window %s" % [S.resolution_text(r), str(ws)])
		check(root.get_visible_rect().size == Vector2(480, 270), "world view stays 480x270 at %s" % S.resolution_text(r))
		var ur: Rect2i = S.usable_rect()
		var wp := DisplayServer.window_get_position()
		check(ur.has_point(wp) and ur.encloses(Rect2i(wp, ws)) or ws.x > ur.size.x, "window on screen at %s (pos %s)" % [S.resolution_text(r), str(wp)])
		# UI at this size: inventory, region map, a speech bubble
		var hub = current_scene
		hub.hud.inventory_ui.set_open(true)
		await wait(0.3)
		await screen_shot("s_%dx%d_inventory" % [r.x, r.y])
		hub.hud.inventory_ui.set_open(false)
		hub.region_map.open()
		await wait(0.5)
		await screen_shot("s_%dx%d_map" % [r.x, r.y])
		hub.region_map.close()
		hub.player.say("风好冷。")
		await wait(0.8)
		await screen_shot("s_%dx%d_dialogue" % [r.x, r.y])
	# modes back and forth
	for m in [S.DisplayMode.BORDERLESS, S.DisplayMode.WINDOWED, S.DisplayMode.FULLSCREEN, S.DisplayMode.BORDERLESS, S.DisplayMode.WINDOWED]:
		S.set_display_mode(m)
		await wait(0.8)
		var mode := DisplayServer.window_get_mode()
		var borderless := DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_BORDERLESS)
		var ws := DisplayServer.window_get_size()
		var ok := false
		match m:
			S.DisplayMode.BORDERLESS:
				ok = mode == DisplayServer.WINDOW_MODE_WINDOWED and borderless and ws == S.screen_size()
			S.DisplayMode.WINDOWED:
				ok = mode == DisplayServer.WINDOW_MODE_WINDOWED and not borderless and ws == S.windowed_size()
			S.DisplayMode.FULLSCREEN:
				ok = mode in [DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN, DisplayServer.WINDOW_MODE_FULLSCREEN]
		check(ok, "%s: mode %d borderless %s size %s" % [S.MODE_NAMES[m], mode, borderless, str(ws)])
		check(root.get_visible_rect().size == Vector2(480, 270) and cam and is_instance_valid(cam), "%s: same world view, camera fine" % S.MODE_NAMES[m])
	await screen_shot("s_windowed_final")
	# resolution bigger than the screen -> a size that fits
	S.display_mode = S.DisplayMode.WINDOWED
	S.set_resolution(Vector2i(3840, 2160))
	await wait(0.6)
	var fit: Vector2i = S.windowed_size()
	check(fit.x <= S.usable_rect().size.x and fit.y <= S.usable_rect().size.y, "too big for the screen -> %s fits" % str(fit))
	S.set_resolution(Vector2i(1280, 720))
	await wait(0.4)

	# --- the keep-settings countdown -----------------------------------------------------------
	await goto("res://scenes/ui/main_menu.tscn")
	await wait(2.5)
	var menu = current_scene
	menu.settings_btn.emit_signal("pressed")
	await wait(0.3)
	var sm = menu.settings_menu
	check(sm != null, "main menu -> 设置")
	var before: Dictionary = S.display_state()
	sm._step_mode(1)
	await wait(0.4)
	check(sm.is_confirming() and S.display_mode != before.mode, "display change applies and asks to keep it")
	await screen_shot("s_confirm")
	sm._confirm_left = 0.05
	await wait(0.3)
	check(not sm.is_confirming() and S.display_state() == before, "countdown ran out -> previous display settings back")
	sm._step_mode(1)
	await wait(0.3)
	sm.keep_display()
	var kept: Dictionary = S.display_state()
	check(kept != before and S.load_settings() and S.display_state() == kept, "保留 saves the new display settings")
	S.restore_display_state(before)
	S.save_settings()
	# sound page slider drives the bus
	sm._show_tab(1)
	await wait(0.2)
	sm._sliders["Music"][0].value = 40
	await wait(0.1)
	check(S.music == 40 and absf(bus_db("Music") - S.volume_to_db(40)) < 0.01, "dragging the music slider changes the bus at once")
	await screen_shot("s_sound_page")
	await press("pause")
	await wait(0.3)
	check(menu.settings_menu == null and current_scene == menu and menu.settings_btn.has_focus(), "back from settings -> main menu")

	# --- from the pause menu ------------------------------------------------------------------
	GS.new_game()
	GS.start_free_phase()
	await goto("res://scenes/maps/camp_hub.tscn")
	await wait(1.0)
	var pause = current_scene.hud.pause_menu
	pause.set_open(true)
	await wait(0.2)
	pause.settings_btn.emit_signal("pressed")
	await wait(0.3)
	check(pause.settings_menu != null and paused, "pause -> 设置 (game stays paused)")
	await screen_shot("s_pause_settings")
	pause.settings_menu.close()
	await wait(0.3)
	check(pause.is_open() and pause.settings_menu == null and paused and current_scene.scene_file_path.ends_with("camp_hub.tscn"), "back from settings -> pause menu, not the main menu")
	pause.set_open(false)

	S.apply_display_enabled = false
	print("RESULT: %s (%d failures)" % ["OK" if failures.is_empty() else "FAILED", failures.size()])
	quit(0 if failures.is_empty() else 1)
