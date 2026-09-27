extends CanvasLayer
## Scene transitions (fades, loading screen) and the pixel software cursor.

signal scene_changed(path: String)

const LOADING_SCENE := "res://scenes/ui/loading_screen.tscn"
const CURSOR_ARROW := preload("res://art/ui/cursor_arrow.png")
const CURSOR_CROSS := preload("res://art/ui/crosshair.png")

enum CursorMode { ARROW, CROSSHAIR, HIDDEN }

var _fade: ColorRect
var _cursor: Sprite2D
var _busy := false
var cursor_mode: CursorMode = CursorMode.ARROW


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_fade)
	_cursor = Sprite2D.new()
	_cursor.texture = CURSOR_ARROW
	_cursor.centered = false
	_cursor.z_index = 100
	add_child(_cursor)
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	set_cursor(CursorMode.ARROW)


func _process(_delta: float) -> void:
	var mp := get_viewport().get_mouse_position()
	_cursor.position = mp.round() - (_cursor.texture.get_size() * 0.5).floor() * (1.0 if cursor_mode == CursorMode.CROSSHAIR else 0.0)


func set_cursor(mode: CursorMode) -> void:
	cursor_mode = mode
	_cursor.visible = mode != CursorMode.HIDDEN
	_cursor.texture = CURSOR_CROSS if mode == CursorMode.CROSSHAIR else CURSOR_ARROW


func is_busy() -> bool:
	return _busy


func fade_to(alpha: float, time: float, color := Color.BLACK) -> void:
	_fade.color = Color(color.r, color.g, color.b, _fade.color.a)
	var t := create_tween()
	t.tween_property(_fade, "color:a", alpha, time)
	await t.finished


func set_black(alpha: float = 1.0) -> void:
	_fade.color = Color(0, 0, 0, alpha)


## Fade out, swap scene, fade in. With loading=true a short loading screen
## (small 迟归 mark) is shown while the next scene loads.
func change_scene(path: String, fade_time: float = 0.8, loading: bool = false) -> void:
	if _busy:
		return
	_busy = true
	get_tree().paused = false
	await fade_to(1.0, fade_time)
	AudioManager.stop_all_loops(0.5)
	NoiseSystem.clear()
	if loading:
		var ls: Node = load(LOADING_SCENE).instantiate()
		add_child(ls)
		move_child(ls, 0)
		ResourceLoader.load_threaded_request(path)
		await fade_to(0.0, 0.4)
		var t0 := Time.get_ticks_msec()
		while ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			await get_tree().process_frame
		while Time.get_ticks_msec() - t0 < 1800:
			await get_tree().process_frame
		var packed: PackedScene = ResourceLoader.load_threaded_get(path)
		await fade_to(1.0, 0.4)
		ls.queue_free()
		get_tree().change_scene_to_packed(packed)
	else:
		get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame
	scene_changed.emit(path)
	_busy = false
	# Levels may hold the black screen themselves (e.g. the wake-up intro).
	if not get_tree().current_scene or not get_tree().current_scene.get_meta(&"hold_black", false):
		await fade_to(0.0, fade_time)
