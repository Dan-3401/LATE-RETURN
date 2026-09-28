extends SceneTree
## Visual review helper: screenshots of every main map at a few player
## positions (lighting, foreground). No checks — look at the images.
##   godot --path . -s res://tools/tests/shoot_scenes.gd -- <shot_dir> [prefix]

var shot_dir := ""
var prefix := "v"
var GS: Node
var SM: Node

const SHOTS := [
	["res://scenes/maps/convenience_store.tscn", [150, 460, 700, 900]],
	["res://scenes/maps/warehouse.tscn", [80, 260, 420]],
	["res://scenes/maps/street.tscn", [300, 880, 1480, 2200]],
	["res://scenes/maps/region_store.tscn", [200, 1300, 2400]],
	["res://scenes/maps/camp_hub.tscn", [120, 300]],
]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	shot_dir = args[0] if args.size() > 0 else "/tmp"
	if args.size() > 1:
		prefix = args[1]
	_run.call_deferred()


func wait(t: float) -> void:
	await create_timer(t).timeout


func _run() -> void:
	GS = root.get_node("/root/GameState")
	SM = root.get_node("/root/SceneManager")
	await wait(0.3)
	GS.new_game()
	GS.start_free_phase()
	GS.begin_expedition(load("res://resources/locations/store.tres"))
	GS.mark_location_visited()
	for entry in SHOTS:
		var path: String = entry[0]
		GS.spawn_point = &"location_entry"
		var old := current_scene
		SM.change_scene(path, 0.05)
		while current_scene == old or current_scene == null or SM.is_busy():
			await wait(0.1)
		await wait(1.5)
		SM.set_black(0.0)
		var p = get_first_node_in_group(&"player")
		var name := path.get_file().get_basename()
		for x in entry[1]:
			p.global_position = Vector2(x, p.global_position.y)
			var cam = get_first_node_in_group(&"game_camera")
			if cam and cam.has_method(&"snap_to_target"):
				cam.snap_to_target()
			await wait(0.6)
			await process_frame
			root.get_texture().get_image().save_png("%s/%s_%s_%d.png" % [shot_dir, prefix, name, x])
		# flashlight on for the dark interiors
		if name in ["convenience_store", "warehouse"]:
			p.global_position = Vector2(entry[1][0], p.global_position.y)
			var cam2 = get_first_node_in_group(&"game_camera")
			if cam2 and cam2.has_method(&"snap_to_target"):
				cam2.snap_to_target()
			p.face(1)
			await wait(0.3)
			# aim the beam slightly down to the right, across the shelves
			var k := Vector2(root.size) / Vector2(480, 270)
			root.warp_mouse(Vector2(430, 170) * k)
			p.flashlight.set_on(true, true)
			await wait(0.8)
			root.get_texture().get_image().save_png("%s/%s_%s_flash.png" % [shot_dir, prefix, name])
	quit(0)
