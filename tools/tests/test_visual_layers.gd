extends SceneTree
## Lighting + foreground acceptance (spec 99-110):
## pixel art stays Nearest (only glows / blurred foreground are LINEAR),
## every main map has layered warm + cold lights, the flashlight still casts
## shadows, gameplay exposure (light raises, shadow lowers presence),
## foreground layers exist in every map, use the z_index convention, have
## no collision, and fade while covering the player / a zombie.
##   godot --path . -s res://tools/tests/test_visual_layers.gd -- [shot_dir]

var shot_dir := ""
var failures: Array[String] = []
var GS: Node
var SM: Node

const MAPS := [
	"res://scenes/maps/convenience_store.tscn",
	"res://scenes/maps/warehouse.tscn",
	"res://scenes/maps/street.tscn",
	"res://scenes/maps/region_store.tscn",
	"res://scenes/maps/camp_hub.tscn",
	"res://scenes/maps/school_camp.tscn",
]


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


func all_nodes(n: Node, out: Array) -> Array:
	out.append(n)
	for c in n.get_children():
		all_nodes(c, out)
	return out


func goto(path: String) -> bool:
	var old := current_scene
	SM.change_scene(path, 0.05)
	var t := 0.0
	while t < 20.0 and (current_scene == old or current_scene == null or SM.is_busy()):
		await wait(0.1)
		t += 0.1
	await wait(0.6)
	SM.set_black(0.0)
	return current_scene != null and current_scene.scene_file_path == path


## Is `n` allowed to use smooth (LINEAR) filtering? Only glow/shade sprites
## and pieces of a blurred foreground layer.
func smooth_allowed(n: Node) -> bool:
	if n is Sprite2D and (n as Sprite2D).texture and (n as Sprite2D).texture.resource_path.ends_with("/halo.png"):
		return true
	var p := n
	while p:
		if p.name == "ForegroundBlur":
			return true
		p = p.get_parent()
	return false


func _run() -> void:
	GS = root.get_node("/root/GameState")
	SM = root.get_node("/root/SceneManager")
	await wait(0.3)
	check(int(ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter")) == 0, "project default texture filter is Nearest")
	check(ProjectSettings.get_setting("display/window/stretch/scale_mode") == "integer", "integer scaling")

	# --- static checks on every main map ------------------------------------------------
	for path in MAPS:
		var inst: Node = load(path).instantiate()
		var name: String = path.get_file().get_basename()
		var nodes := all_nodes(inst, [])
		var bad_filter: Array[String] = []
		var warm := 0
		var cold := 0
		var lights := 0
		for n in nodes:
			if n is CanvasItem and (n as CanvasItem).texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR and not smooth_allowed(n):
				bad_filter.append(str(n.name))
			if n is Light2D and (n as Light2D).enabled:
				lights += 1
				var col := (n as Light2D).color
				if col.r > col.b + 0.1:
					warm += 1
				elif col.b > col.r + 0.1:
					cold += 1
		check(bad_filter.is_empty(), "%s: pixel art stays Nearest %s" % [name, str(bad_filter)])
		check(lights >= 5 and warm >= 1 and cold >= 1, "%s: layered lights (%d lights, %d warm, %d cold)" % [name, lights, warm, cold])
		var fg := inst.get_node_or_null("Foreground")
		var fgb := inst.get_node_or_null("ForegroundBlur")
		check(fg != null and fgb != null, "%s: Foreground + ForegroundBlur layers" % name)
		if fg and fgb:
			check(fg.z_index == RenderLayers.FOREGROUND and fgb.z_index == RenderLayers.FOREGROUND_BLUR, "%s: foreground z_index convention" % name)
			check(fg is ForegroundFader and fgb is ForegroundFader, "%s: foreground layers fade" % name)
			check(fgb.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR and fgb.scroll_scale.x > fg.scroll_scale.x, "%s: blur layer is soft and moves faster" % name)
			var solid := 0
			for layer in [fg, fgb]:
				for n in all_nodes(layer, []):
					if n is CollisionObject2D or n is CollisionShape2D or n is CollisionPolygon2D or n is LightOccluder2D:
						solid += 1
			check(solid == 0, "%s: foreground has no collision / occluders" % name)
			check(fg.get_child_count() >= 2 and fgb.get_child_count() >= 1, "%s: foreground pieces (%d sharp, %d blurred)" % [name, fg.get_child_count(), fgb.get_child_count()])
		inst.free()

	# --- flashlight still casts shadows ---------------------------------------------------
	var pl: Node = load("res://scenes/player/player.tscn").instantiate()
	check(pl.get_node("BeamLight").shadow_enabled and pl.get_node("BeamWallLight").shadow_enabled, "flashlight beams cast shadows (occluders work)")
	pl.free()

	# --- runtime: fade + exposure in the street --------------------------------------------
	GS.new_game()
	check(await goto("res://scenes/maps/street.tscn"), "street loaded")
	var level = current_scene
	var p = get_first_node_in_group(&"player")
	var cam = get_first_node_in_group(&"game_camera")
	p.set_physics_process(false)
	for z in get_nodes_in_group(&"zombie"):
		z.process_mode = Node.PROCESS_MODE_DISABLED
	p.global_position = Vector2(1000, 224)
	cam.snap_to_target()
	await wait(0.5)
	var fg: ForegroundFader = level.get_node("Foreground")
	var sign: Sprite2D = fg.get_node("Sign")
	# slide the sign in front of the player
	var pscreen: Vector2 = p.get_global_transform_with_canvas().origin
	var sscreen: Vector2 = sign.get_global_transform_with_canvas().origin
	sign.position.x += pscreen.x - sscreen.x - 30
	await wait(0.8)
	check(fg.is_covering(p) and sign.modulate.a < 0.5, "foreground fades while covering the player (a=%.2f)" % sign.modulate.a)
	await shot("vl01_fade_player")
	# move it out of the way (above the frame, covering nothing)
	sign.position.y -= 600
	await wait(0.8)
	check(sign.modulate.a > 0.95, "and comes back afterwards (a=%.2f)" % sign.modulate.a)
	# covering a zombie
	var z = level.get_node("Zombies/Doorman")
	var zscreen: Vector2 = z.get_global_transform_with_canvas().origin
	sscreen = sign.get_global_transform_with_canvas().origin
	sign.position.y += 600
	sscreen = sign.get_global_transform_with_canvas().origin
	sign.position.x += zscreen.x - sscreen.x - 30
	await wait(0.8)
	check(sign.modulate.a < 0.5, "foreground fades over a zombie too (a=%.2f)" % sign.modulate.a)
	await shot("vl02_fade_zombie")

	# gameplay exposure: lamp pool vs alley shadow, same idle stance
	var lamp = level.get_node("Props/Lamp")
	p.global_position = Vector2(lamp.global_position.x + 14, 224)
	p.set_physics_process(true)
	await wait(1.2)
	var ex_lit: float = p.stealth.exposure()
	var pres_lit: float = p.stealth.presence
	p.global_position = Vector2(715, 224)
	await wait(1.2)
	var ex_dark: float = p.stealth.exposure()
	var pres_dark: float = p.stealth.presence
	p.global_position = Vector2(560, 224)
	await wait(1.2)
	var pres_open: float = p.stealth.presence
	check(ex_lit > 0.5 and ex_dark < 0.0, "exposure: lamp %.2f, alley %.2f" % [ex_lit, ex_dark])
	check(pres_lit > pres_open and pres_dark < pres_open, "presence: lit %.2f > open %.2f > shadow %.2f" % [pres_lit, pres_open, pres_dark])

	print("RESULT: %s (%d failures)" % ["OK" if failures.is_empty() else "FAILED", failures.size()])
	quit(0 if failures.is_empty() else 1)
