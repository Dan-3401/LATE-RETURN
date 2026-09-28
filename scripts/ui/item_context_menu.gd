class_name ItemContextMenu
extends Control
## Right-click menu for ONE item stack: 【使用】【拆分】【丢弃】, plus the small
## split window ("xx / yy", yy = this stack only) and the red destroy
## confirmation. Pure view: what is possible and what an action does comes
## from InventoryActions (by the stack's container context).
## Closes on an outside click, Esc, a successful use / discard, and when
## the split window opens.

signal acted(action: String)

const TEXT := Color(0.86, 0.83, 0.74)
const HOVER := Color(1, 0.95, 0.82)
const DISABLED := Color(0.34, 0.33, 0.31)
const RED := Color(0.9, 0.3, 0.24)
const NOTE := Color(0.9, 0.62, 0.4)

var ref := {}
var use_btn: Button
var split_btn: Button
var discard_btn: Button
var split_panel: PanelContainer
var split_title: Label
var split_edit: LineEdit
var split_total: Label
var split_minus: Button
var split_plus: Button
var split_ok: Button
var split_cancel: Button
var confirm_panel: PanelContainer
var confirm_text: Label
var confirm_yes: Button
var confirm_no: Button
var note: Label
var last_message := ""

var _menu: PanelContainer
var _dim: ColorRect
var _menu_title: Label
var _stack = null
var _note_tween: Tween


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.45)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.visible = false
	add_child(_dim)
	_menu = PanelContainer.new()
	add_child(_menu)
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 0)
	_menu.add_child(v)
	_menu_title = Label.new()
	_menu_title.add_theme_color_override(&"font_color", Color(0.62, 0.6, 0.54))
	v.add_child(_menu_title)
	use_btn = _button("使用", _on_use)
	split_btn = _button("拆分", _on_split)
	discard_btn = _button("丢弃", _on_discard)
	for b in [use_btn, split_btn, discard_btn]:
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		v.add_child(b)
	# split window
	split_panel = _dialog()
	var sv: VBoxContainer = split_panel.get_child(0)
	split_title = Label.new()
	split_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sv.add_child(split_title)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 2)
	sv.add_child(row)
	split_minus = _button("-", func(): _nudge(-1))
	row.add_child(split_minus)
	split_edit = LineEdit.new()
	split_edit.custom_minimum_size = Vector2(26, 0)
	split_edit.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	split_edit.max_length = 4
	split_edit.context_menu_enabled = false
	split_edit.add_theme_color_override(&"font_color", HOVER)
	split_edit.text_changed.connect(func(_t): _validate_split())
	split_edit.text_submitted.connect(func(_t): _on_split_ok())
	row.add_child(split_edit)
	split_total = Label.new()
	row.add_child(split_total)
	split_plus = _button("+", func(): _nudge(1))
	row.add_child(split_plus)
	var br := _button_row(sv)
	split_ok = _button("确认", _on_split_ok)
	split_cancel = _button("取消", close_all)
	br.add_child(split_ok)
	br.add_child(split_cancel)
	# destroy confirmation
	confirm_panel = _dialog()
	var cv: VBoxContainer = confirm_panel.get_child(0)
	confirm_text = Label.new()
	confirm_text.text = "你确定要销毁当前物品？"
	confirm_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	confirm_text.add_theme_color_override(&"font_color", RED)
	cv.add_child(confirm_text)
	var cr := _button_row(cv)
	confirm_yes = _button("是", _on_confirm_yes)
	confirm_no = _button("否", close_all)
	confirm_yes.add_theme_color_override(&"font_color", RED)
	confirm_yes.add_theme_color_override(&"font_hover_color", Color(1, 0.45, 0.38))
	cr.add_child(confirm_yes)
	cr.add_child(confirm_no)
	# short messages ("没有空余位置。")
	note = Label.new()
	note.add_theme_color_override(&"font_color", NOTE)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	note.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	note.offset_top = -40
	note.offset_bottom = -26
	note.offset_left = -120
	note.offset_right = 120
	note.modulate.a = 0.0


func _ready() -> void:
	# the note outlives the menu: it lives next to it, not inside
	get_parent().add_child.call_deferred(note)
	# small opaque pixel boxes (1 px frame) so nothing shows through
	_menu.add_theme_stylebox_override(&"panel", _box(3, 2))
	split_panel.add_theme_stylebox_override(&"panel", _box(8, 5))
	confirm_panel.add_theme_stylebox_override(&"panel", _box(8, 5))
	GameState.inventory_changed.connect(_on_data_changed)
	GameState.camp_changed.connect(_on_data_changed)


func _box(mx: int, my: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.075, 0.07, 0.08, 0.97)
	sb.border_color = Color(0.46, 0.43, 0.37)
	sb.set_border_width_all(1)
	sb.anti_aliasing = false
	sb.content_margin_left = mx
	sb.content_margin_right = mx
	sb.content_margin_top = my
	sb.content_margin_bottom = my + 1
	return sb


func _button(t: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_color_override(&"font_color", TEXT)
	b.add_theme_color_override(&"font_hover_color", HOVER)
	b.add_theme_color_override(&"font_disabled_color", DISABLED)
	b.add_theme_stylebox_override(&"disabled", StyleBoxEmpty.new())
	b.pressed.connect(cb)
	return b


func _dialog() -> PanelContainer:
	var p := PanelContainer.new()
	p.set_anchors_preset(Control.PRESET_CENTER)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	p.visible = false
	add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 4)
	p.add_child(v)
	return p


func _button_row(parent: Control) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.alignment = BoxContainer.ALIGNMENT_CENTER
	r.add_theme_constant_override(&"separation", 10)
	parent.add_child(r)
	return r


# --- opening / closing ---------------------------------------------------------------------
func is_open() -> bool:
	return visible


func is_menu_visible() -> bool:
	return visible and _menu.visible


## Open the menu for the stack at `stack_ref`, next to `at` (screen pos).
func open_for(stack_ref: Dictionary, at: Vector2) -> void:
	var st: Dictionary = InventoryActions.menu_state(stack_ref)
	if st.count <= 0:
		return
	ref = stack_ref.duplicate()
	_stack = GameState.stack_at(ref)
	var item: ItemData = _stack.item
	_menu_title.text = "%s ×%d" % [item.display_name, st.count] if st.count > 1 else item.display_name
	use_btn.disabled = not st.use
	split_btn.disabled = not st.split
	discard_btn.disabled = not st.discard
	split_panel.visible = false
	confirm_panel.visible = false
	_dim.visible = false
	_menu.visible = true
	visible = true
	_menu.reset_size()
	var vp := get_viewport_rect().size
	var sz := _menu.get_combined_minimum_size()
	_menu.position = Vector2(clampf(at.x, 2, vp.x - sz.x - 2), clampf(at.y, 2, vp.y - sz.y - 2)).round()
	AudioManager.play(&"ui_move", -12.0, 0.0, &"UI")


func close_all() -> void:
	visible = false
	_menu.visible = false
	_dim.visible = false
	split_panel.visible = false
	confirm_panel.visible = false
	ref = {}
	_stack = null


## The red "destroy?" question straight away (the storage screen's 丢弃 slot).
func ask_destroy(stack_ref: Dictionary) -> void:
	var s = GameState.stack_at(stack_ref)
	if s == null:
		return
	if not GameState.can_discard(s.item):
		show_note("这个不能丢。")
		return
	ref = stack_ref.duplicate()
	_stack = s
	_menu.visible = false
	split_panel.visible = false
	visible = true
	_show_confirm()


func _gui_input(event: InputEvent) -> void:
	# a click outside the menu closes it (dialogs stay until answered)
	if event is InputEventMouseButton and event.pressed and _menu.visible:
		close_all()
		accept_event()


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"pause"):
		close_all()
		get_viewport().set_input_as_handled()


## The stack changed under the menu (moved, used up...): never act on a
## stale stack.
func _still_valid() -> bool:
	return _stack != null and is_same(GameState.stack_at(ref), _stack)


func _on_data_changed() -> void:
	if visible and not _still_valid():
		close_all()


# --- actions -----------------------------------------------------------------------------------
func _player() -> Node2D:
	return get_tree().get_first_node_in_group(&"player") as Node2D


func _on_use() -> void:
	if not _still_valid():
		close_all()
		return
	var err := InventoryActions.use(ref, _player())
	if err != "":
		show_note(err)
		AudioManager.play(&"ui_back", -8.0, 0.0, &"UI")
		return
	AudioManager.play(&"ui_confirm", -8.0, 0.0, &"UI")
	close_all()
	acted.emit("use")


func _on_split() -> void:
	if not _still_valid() or not InventoryActions.can_split(ref):
		return
	var n: int = _stack.count
	split_title.text = "拆分  %s" % (_stack.item as ItemData).display_name
	split_total.text = "/ %d" % n
	split_edit.text = str(maxi(1, n / 2))
	_menu.visible = false
	split_panel.visible = true
	_dim.visible = true
	split_panel.reset_size()
	split_panel.position = ((get_viewport_rect().size - split_panel.get_combined_minimum_size()) / 2.0).round()
	_validate_split()
	split_edit.grab_focus()
	split_edit.caret_column = split_edit.text.length()


## The amount typed in the split window, or -1 when it is not an integer.
func split_amount() -> int:
	var t := split_edit.text.strip_edges()
	return int(t) if t.is_valid_int() else -1


func _validate_split() -> void:
	var ok := _still_valid() and InventoryActions.split_valid(ref, split_amount())
	split_ok.disabled = not ok
	var a := split_amount()
	split_minus.disabled = a <= 1
	split_plus.disabled = _stack == null or a >= int(_stack.count) - 1
	split_edit.add_theme_color_override(&"font_color", HOVER if ok else RED)


func _nudge(d: int) -> void:
	if _stack == null:
		return
	var a := split_amount()
	a = clampi((a if a > 0 else 0) + d, 1, maxi(1, int(_stack.count) - 1))
	split_edit.text = str(a)
	_validate_split()


func _on_split_ok() -> void:
	if split_ok.disabled or not _still_valid():
		return
	var err := InventoryActions.split(ref, split_amount())
	close_all()
	if err != "":
		show_note(err)
		AudioManager.play(&"ui_back", -8.0, 0.0, &"UI")
		return
	AudioManager.play(&"ui_move", -8.0, 0.0, &"UI")
	acted.emit("split")


func _on_discard() -> void:
	if not _still_valid():
		close_all()
		return
	match InventoryActions.discard_mode(ref):
		InventoryActions.DiscardMode.DESTROY:
			_menu.visible = false
			_show_confirm()
		InventoryActions.DiscardMode.DROP:
			var p := InventoryActions.drop_to_ground(ref, _player())
			if p == null:
				show_note("这个不能丢。")
				return
			close_all()
			acted.emit("drop")


func _show_confirm() -> void:
	confirm_panel.visible = true
	_dim.visible = true
	confirm_panel.reset_size()
	confirm_panel.position = ((get_viewport_rect().size - confirm_panel.get_combined_minimum_size()) / 2.0).round()
	AudioManager.play(&"ui_confirm", -12.0, 0.0, &"UI")


func _on_confirm_yes() -> void:
	if not _still_valid():
		close_all()
		return
	var err := InventoryActions.destroy(ref)
	close_all()
	if err != "":
		show_note(err)
		return
	AudioManager.play(&"ui_back", -6.0, 0.0, &"UI")
	acted.emit("destroy")


func show_note(t: String) -> void:
	last_message = t
	note.text = t
	if _note_tween:
		_note_tween.kill()
	note.modulate.a = 1.0
	_note_tween = note.create_tween()
	_note_tween.tween_interval(1.8)
	_note_tween.tween_property(note, "modulate:a", 0.0, 0.6)
