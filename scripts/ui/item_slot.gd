class_name ItemSlot
extends PanelContainer
## One slot of the backpack screen (backpack cell or equipment slot).
## Pure view: `ref` says which real slot it shows, the item always comes
## from GameState. Drag & drop asks GameState.move_item() — in dry-run mode
## while hovering, for the live green / red / neutral frame — and only a
## successful drop changes data, so a refused drop leaves the item where
## it was.

signal clicked(slot: ItemSlot)
signal hovered(slot: ItemSlot, on: bool)

const OK_EQUIP := Color(0.46, 0.82, 0.42)
const BAD := Color(0.88, 0.3, 0.24)
const NEUTRAL := Color(0.86, 0.8, 0.64, 0.85)

## {"kind": "bag", "index": i} or {"kind": "equip", "slot": "hand1"}
var ref := {}
var item: ItemData
var count := 0
var empty_icon: Texture2D
var selected := false

var _icon: TextureRect
var _count: Label
var _frame: Control
var _frame_color := Color(0, 0, 0, 0)
var _drag_source := false


func _init() -> void:
	custom_minimum_size = Vector2(20, 20)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_icon = TextureRect.new()
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icon)
	_count = Label.new()
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_count.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_count.add_theme_constant_override(&"line_spacing", -4)
	_count.add_theme_color_override(&"font_outline_color", Color(0.03, 0.03, 0.04))
	_count.add_theme_constant_override(&"outline_size", 3)
	_count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_count)
	_frame = Control.new()
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.draw.connect(_draw_frame)
	add_child(_frame)
	mouse_entered.connect(func(): hovered.emit(self, true))
	mouse_exited.connect(func():
		_set_frame(Color(0, 0, 0, 0))
		hovered.emit(self, false))


func set_content(it: ItemData, n: int, count_text := "") -> void:
	item = it
	count = n
	if it:
		_icon.texture = it.icon
		_icon.modulate = Color.WHITE
	else:
		_icon.texture = empty_icon
		_icon.modulate = Color(1, 1, 1, 0.22)
	_count.text = count_text if count_text != "" else (str(n) if it and n > 1 else "")
	theme_type_variation = &"SlotFocusPanel" if selected and it else &"SlotPanel"


# --- drag & drop -----------------------------------------------------------------
func _get_drag_data(_at: Vector2) -> Variant:
	if item == null:
		return null
	_drag_source = true
	var wrap := Control.new()
	var tex := TextureRect.new()
	tex.texture = item.icon
	tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tex.modulate = Color(1, 1, 1, 0.7)
	tex.position = -item.icon.get_size() / 2.0
	wrap.add_child(tex)
	set_drag_preview(wrap)
	_icon.modulate = Color(1, 1, 1, 0.3)
	AudioManager.play(&"ui_move", -12.0, 0.0, &"UI")
	return {"item_slot_ref": ref.duplicate()}


func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	if not (data is Dictionary and data.has("item_slot_ref")):
		return false
	var src: Dictionary = data.item_slot_ref
	if src == ref:
		_set_frame(NEUTRAL)
		return false
	var ok := GameState.move_item(src, ref, true) == ""
	if not ok:
		_set_frame(BAD)
	elif ref.kind == "equip":
		_set_frame(OK_EQUIP)
	else:
		_set_frame(NEUTRAL)
	return ok


func _drop_data(_at: Vector2, data: Variant) -> void:
	_set_frame(Color(0, 0, 0, 0))
	var err := GameState.move_item(data.item_slot_ref, ref)
	if err == "":
		AudioManager.play(&"equip" if ref.kind == "equip" else &"ui_move", -10.0, 0.0, &"UI")


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		_set_frame(Color(0, 0, 0, 0))
		if _drag_source:
			_drag_source = false
			if item:
				_icon.modulate = Color.WHITE
			if not get_viewport().gui_is_drag_successful():
				# refused or dropped nowhere: nothing moved, a soft "no"
				AudioManager.play(&"ui_back", -12.0, 0.0, &"UI")


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(self)


func _set_frame(c: Color) -> void:
	if c == _frame_color:
		return
	_frame_color = c
	_frame.queue_redraw()


func frame_color() -> Color:
	return _frame_color


func _draw_frame() -> void:
	if _frame_color.a <= 0.0:
		return
	# the frame child sits inside the panel margins; draw over the whole cell
	var off := _frame.position
	var r := Rect2(-off + Vector2(0.5, 0.5), size - Vector2.ONE)
	_frame.draw_rect(r, _frame_color, false, 1.0)
