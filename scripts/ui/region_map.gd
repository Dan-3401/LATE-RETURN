class_name RegionMap
extends CanvasLayer
## The hand-marked city map used to pick today's destination.
## Hover: highlight + name, cost and description. Click: confirm, pay, go.
## Locations that are not open yet only get a remark from the brother.

signal closed
signal departed(location: LocationData)

const MARK_COLOR := Color(0.55, 0.14, 0.1)
const MARK_HOVER := Color(0.78, 0.2, 0.12)
const INK := Color(0.2, 0.16, 0.13)
## Map paper colour: a patch of it sits behind every place name so the
## roads drawn on the map never run through the text.
const PAPER := Color(0.63, 0.6, 0.53)

@export var locations: Array[LocationData] = []

@onready var root: Control = $Root
@onready var map_rect: TextureRect = $Root/Map
@onready var marks: Control = $Root/Map/Marks
@onready var info_name: Label = $Root/Info/VBox/Name
@onready var info_cost: Label = $Root/Info/VBox/Cost
@onready var info_desc: Label = $Root/Info/VBox/Desc
@onready var info_warn: Label = $Root/Info/VBox/Warn
@onready var res_label: Label = $Root/Resources
@onready var note: Label = $Root/Note
@onready var confirm: Control = $Root/Confirm
@onready var confirm_cost: Label = $Root/Confirm/VBox/Cost
@onready var go_btn: Button = $Root/Confirm/VBox/Buttons/Go
@onready var cancel_btn: Button = $Root/Confirm/VBox/Buttons/Cancel

var is_open := false
var hovered: LocationData = null
var _selected: LocationData = null
var _t := 0.0
var _note_tween: Tween


func _ready() -> void:
	layer = 25
	root.visible = false
	marks.draw.connect(_draw_marks)
	go_btn.pressed.connect(_depart)
	cancel_btn.pressed.connect(_cancel_confirm)
	for b in [go_btn, cancel_btn]:
		b.mouse_entered.connect(func(): AudioManager.play(&"ui_move", -14.0, 0.0, &"UI"))


func open() -> void:
	is_open = true
	root.visible = true
	confirm.visible = false
	note.modulate.a = 0.0
	hovered = null
	_show_info(null)
	_refresh_resources()
	SceneManager.set_cursor(SceneManager.CursorMode.ARROW)
	AudioManager.play(&"page", -8.0)
	root.modulate.a = 0.0
	create_tween().tween_property(root, "modulate:a", 1.0, 0.35)


func close() -> void:
	if not is_open:
		return
	is_open = false
	AudioManager.play(&"page", -12.0)
	var t := create_tween()
	t.tween_property(root, "modulate:a", 0.0, 0.25)
	t.tween_callback(func(): root.visible = false)
	SceneManager.set_cursor(SceneManager.CursorMode.CROSSHAIR)
	closed.emit()


func _process(delta: float) -> void:
	if not is_open:
		return
	_t += delta
	if not confirm.visible:
		var mp := map_rect.get_local_mouse_position()
		var h := location_at(mp)
		if h != hovered:
			hovered = h
			if h:
				AudioManager.play(&"ui_move", -14.0, 0.0, &"UI")
			_show_info(h)
	marks.queue_redraw()


## Uses _input, not _unhandled_input: the full-screen map controls (dim,
## paper) are GUI nodes and would otherwise swallow every mouse click.
func _input(event: InputEvent) -> void:
	if not is_open:
		return
	if event.is_action_pressed(&"pause") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT):
		get_viewport().set_input_as_handled()
		if confirm.visible:
			_cancel_confirm()
		else:
			close()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not confirm.visible:
		var loc := location_at(map_rect.get_global_transform_with_canvas().affine_inverse() * event.position)
		if loc:
			get_viewport().set_input_as_handled()
			hovered = loc
			choose(loc)


func location_at(map_pos: Vector2) -> LocationData:
	for l in locations:
		if map_pos.distance_to(l.map_position) <= l.marker_radius + 6.0:
			return l
	return null


## Click on a location (also used by tests).
func choose(loc: LocationData) -> void:
	if not loc.playable:
		_say("后面的区域以后再来探索吧......")
		return
	if GameState.expedition_done_today:
		_say("今天已经很晚了，明天再出去吧。")
		return
	var missing := GameState.missing_for({"food": loc.cost_food, "water": loc.cost_water})
	if not missing.is_empty():
		_say(lack_line(missing))
		return
	if GameState.has_pending():
		_say("带回来的东西还没整理好。")
		return
	_selected = loc
	confirm_cost.text = "食物 ×%d  /  水 ×%d" % [loc.cost_food, loc.cost_water]
	confirm.visible = true
	go_btn.grab_focus()
	AudioManager.play(&"ui_confirm", -12.0, 0.0, &"UI")


func _cancel_confirm() -> void:
	confirm.visible = false
	_selected = null


func _depart() -> void:
	if _selected == null:
		return
	var loc := _selected
	_selected = null
	confirm.visible = false
	if not GameState.begin_expedition(loc):
		_say(lack_line(GameState.missing_for({"food": loc.cost_food, "water": loc.cost_water})))
		return
	_refresh_resources()
	is_open = false
	departed.emit(loc)


func _show_info(l: LocationData) -> void:
	info_warn.text = ""
	if l == null:
		info_name.text = "选择要去的地方"
		info_cost.text = ""
		info_desc.text = "右键 / Esc 收起地图"
		return
	info_name.text = l.display_name
	info_cost.text = "消耗  食物 ×%d  水 ×%d" % [l.cost_food, l.cost_water]
	info_desc.text = l.description
	var lack := PackedStringArray()
	if GameState.camp_food() < l.cost_food:
		lack.append("食物不足。")
	if GameState.camp_water() < l.cost_water:
		lack.append("水不足。")
	info_warn.text = " ".join(lack)


## The brother's line when the storage cannot pay the trip.
static func lack_line(missing: Array) -> String:
	if missing.has("food") and missing.has("water"):
		return "食物和水都不够了。"
	if missing.has("water"):
		return "水不够了。"
	if missing.has("food"):
		return "食物不够了。"
	return "现在过去的话，带的东西不够。"


## Counted from the real items in the camp storage.
func _refresh_resources() -> void:
	res_label.text = "食物 %d    水 %d" % [GameState.camp_food(), GameState.camp_water()]


func _say(text: String) -> void:
	note.text = "“%s”" % text
	if _note_tween:
		_note_tween.kill()
	_note_tween = create_tween()
	_note_tween.tween_property(note, "modulate:a", 1.0, 0.2)
	_note_tween.tween_interval(2.2)
	_note_tween.tween_property(note, "modulate:a", 0.0, 0.6)


## Hand-drawn circles around the places; the hovered one gets a thicker,
## slightly breathing ring and its name inked darker.
func _draw_marks() -> void:
	var font := ThemeDB.fallback_font
	if root.theme:
		font = root.get_theme_default_font()
	for l in locations:
		var is_h := l == hovered
		var col := MARK_HOVER if is_h else MARK_COLOR
		if not l.playable and not is_h:
			col = col.darkened(0.25)
		var r := l.marker_radius + (1.0 + roundf(sin(_t * 4.0)) if is_h else 0.0)
		_pixel_ring(l.map_position, r, col, 2 if is_h else 1)
		if is_h:
			_pixel_ring(l.map_position, r + 3, Color(col, 0.5), 1)
		# name label next to the circle
		var name_pos := l.map_position + Vector2(l.marker_radius + 4, 4)
		draw_label(font, name_pos, l.display_name, INK if not is_h else Color(0.35, 0.05, 0.03))


func draw_label(font: Font, pos: Vector2, text: String, col: Color) -> void:
	var size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
	var top := pos.round() - Vector2(1, font.get_ascent(12))
	marks.draw_rect(Rect2(top, size + Vector2(2, 0)).abs().grow_individual(0, -1, 0, -1), PAPER)
	marks.draw_string(font, pos.round(), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, col)


func _pixel_ring(center: Vector2, r: float, col: Color, width: int) -> void:
	var steps := int(r * 7)
	var last := Vector2i(9999, 9999)
	for i in steps:
		var a := TAU * i / steps
		# slightly wobbly, like a pencil circle
		var rr := r + sin(a * 3.0 + center.x) * 0.8
		var p := Vector2i(roundi(center.x + cos(a) * rr), roundi(center.y + sin(a) * rr))
		if p == last:
			continue
		last = p
		marks.draw_rect(Rect2(p, Vector2(width, width)), col)
