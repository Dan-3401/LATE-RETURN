class_name SettingsMenu
extends CanvasLayer
## 设置: 屏幕 (display mode, resolution) and 声音 (master / music / SFX).
## Opened from the main menu and from the pause menu — both edit the same
## Settings autoload; closing returns to whichever screen opened it.
## Volume changes apply while dragging. A display change applies at once and
## asks "保留这些显示设置吗？" with a 15 s countdown; cancel / timeout puts
## the previous display settings back.

signal closed

const CONFIRM_SECONDS := 15
const TEXT := Color(0.83, 0.8, 0.72)
const DIM := Color(0.5, 0.48, 0.43)
const ACCENT := Color(0.86, 0.8, 0.64)

var _root: Control
var _panel: PanelContainer
var _tab_buttons: Array[Button] = []
var _pages: Array[Control] = []
var _mode_value: Label
var _res_value: Label
var _res_row: Control
var _res_note: Label
var _sliders := {}
var _confirm: PanelContainer
var _confirm_label: Label
var _keep_btn: Button
var _back_btn: Button
var _confirm_left := 0.0
var _prev_display := {}
var _tab := 0


static func open_over(parent: Node) -> SettingsMenu:
	var m := SettingsMenu.new()
	parent.add_child(m)
	return m


func _ready() -> void:
	layer = 35
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_show_tab(0)
	_refresh()
	Settings.changed.connect(_refresh)
	SceneManager.set_cursor(SceneManager.CursorMode.ARROW)
	_root.modulate.a = 0.0
	create_tween().tween_property(_root, "modulate:a", 1.0, 0.15)
	_tab_buttons[0].grab_focus.call_deferred()
	AudioManager.play(&"ui_confirm", -10.0, 0.0, &"UI")


# --- building ------------------------------------------------------------------------------
func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.offset_left = -140
	_panel.offset_right = 140
	_panel.offset_top = -86
	_panel.offset_bottom = 86
	_root.add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 6)
	_panel.add_child(v)
	var title := Label.new()
	title.text = "设置"
	title.add_theme_color_override(&"font_color", Color(0.93, 0.89, 0.78))
	v.add_child(title)
	# tabs
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override(&"separation", 10)
	v.add_child(tabs)
	for i in 2:
		var b := Button.new()
		b.text = ["屏幕", "声音"][i]
		b.flat = true
		b.pressed.connect(_show_tab.bind(i))
		b.focus_entered.connect(func(): AudioManager.play(&"ui_move", -14.0, 0.0, &"UI"))
		tabs.add_child(b)
		_tab_buttons.append(b)
	var line := ColorRect.new()
	line.color = Color(0.3, 0.29, 0.26)
	line.custom_minimum_size = Vector2(0, 1)
	v.add_child(line)
	# pages
	var pages := Control.new()
	pages.custom_minimum_size = Vector2(264, 84)
	v.add_child(pages)
	_pages.append(_build_screen_page())
	_pages.append(_build_sound_page())
	for p in _pages:
		pages.add_child(p)
	# footer
	_back_btn = Button.new()
	_back_btn.text = "返回"
	_back_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	_back_btn.pressed.connect(close)
	v.add_child(_back_btn)
	_build_confirm()


func _build_screen_page() -> Control:
	var page := VBoxContainer.new()
	page.add_theme_constant_override(&"separation", 6)
	var mode_row := _option_row("显示模式", func(d): _step_mode(d))
	_mode_value = mode_row.get_meta(&"value")
	page.add_child(mode_row)
	_res_row = _option_row("分辨率", func(d): _step_resolution(d))
	_res_value = _res_row.get_meta(&"value")
	page.add_child(_res_row)
	_res_note = Label.new()
	_res_note.add_theme_color_override(&"font_color", DIM)
	_res_note.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_res_note.custom_minimum_size = Vector2(264, 0)
	page.add_child(_res_note)
	return page


func _build_sound_page() -> Control:
	var page := VBoxContainer.new()
	page.add_theme_constant_override(&"separation", 6)
	for b in [["Master", "主音量"], ["Music", "音乐"], ["SFX", "音效"]]:
		page.add_child(_slider_row(b[0], b[1]))
	return page


## "名称    <  值  >"  — arrows, clicks and ←/→ on the focused row.
func _option_row(label: String, step: Callable) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 4)
	var name_l := Label.new()
	name_l.text = label
	name_l.custom_minimum_size = Vector2(76, 0)
	name_l.add_theme_color_override(&"font_color", TEXT)
	row.add_child(name_l)
	var left := Button.new()
	left.text = "<"
	left.flat = true
	left.pressed.connect(func(): step.call(-1))
	row.add_child(left)
	var value := Label.new()
	value.custom_minimum_size = Vector2(120, 0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.add_theme_color_override(&"font_color", ACCENT)
	row.add_child(value)
	var right := Button.new()
	right.text = ">"
	right.flat = true
	right.pressed.connect(func(): step.call(1))
	row.add_child(right)
	for b in [left, right]:
		b.gui_input.connect(func(ev: InputEvent):
			if ev.is_action_pressed(&"ui_left"):
				step.call(-1)
				b.accept_event()
			elif ev.is_action_pressed(&"ui_right"):
				step.call(1)
				b.accept_event())
		b.focus_entered.connect(func(): AudioManager.play(&"ui_move", -14.0, 0.0, &"UI"))
	row.set_meta(&"value", value)
	row.set_meta(&"left", left)
	row.set_meta(&"right", right)
	row.set_meta(&"name", name_l)
	return row


func _slider_row(bus: String, label: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 6)
	var name_l := Label.new()
	name_l.text = label
	name_l.custom_minimum_size = Vector2(76, 0)
	name_l.add_theme_color_override(&"font_color", TEXT)
	row.add_child(name_l)
	var s := HSlider.new()
	s.min_value = 0
	s.max_value = 100
	s.step = 1
	s.custom_minimum_size = Vector2(140, 12)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_style_slider(s)
	row.add_child(s)
	var val := Label.new()
	val.custom_minimum_size = Vector2(24, 0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val.add_theme_color_override(&"font_color", ACCENT)
	row.add_child(val)
	s.value_changed.connect(func(x: float):
		val.text = str(int(x))
		if int(x) != _volume_of(bus):
			Settings.set_volume(bus, int(x))
			AudioManager.play(&"ui_move", -16.0, 0.0, &"UI" if bus != "Music" else &"UI"))
	_sliders[bus] = [s, val]
	return row


## Flat, square, low-saturation slider: a 2px track, a filled part, a
## small pixel grabber. No rounded corners.
func _style_slider(s: HSlider) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.2, 0.19, 0.17)
	track.content_margin_top = 1
	track.content_margin_bottom = 1
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.62, 0.58, 0.49)
	fill.content_margin_top = 1
	fill.content_margin_bottom = 1
	var fill_hi := fill.duplicate()
	fill_hi.bg_color = ACCENT
	s.add_theme_stylebox_override(&"slider", track)
	s.add_theme_stylebox_override(&"grabber_area", fill)
	s.add_theme_stylebox_override(&"grabber_area_highlight", fill_hi)
	s.add_theme_icon_override(&"grabber", _grabber(Color(0.8, 0.76, 0.66)))
	s.add_theme_icon_override(&"grabber_highlight", _grabber(Color(0.95, 0.9, 0.78)))
	s.add_theme_icon_override(&"grabber_disabled", _grabber(DIM))
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color(0, 0, 0, 0)
	focus.border_color = Color(0.86, 0.8, 0.64, 0.5)
	focus.set_border_width_all(1)
	s.add_theme_stylebox_override(&"focus", focus)
	s.focus_entered.connect(func(): AudioManager.play(&"ui_move", -14.0, 0.0, &"UI"))


func _grabber(col: Color) -> Texture2D:
	var img := Image.create(4, 8, false, Image.FORMAT_RGBA8)
	img.fill(col)
	for y in 8:
		img.set_pixel(0, y, col.darkened(0.35))
		img.set_pixel(3, y, col.darkened(0.35))
	return ImageTexture.create_from_image(img)


func _build_confirm() -> void:
	_confirm = PanelContainer.new()
	_confirm.set_anchors_preset(Control.PRESET_CENTER)
	_confirm.offset_left = -96
	_confirm.offset_right = 96
	_confirm.offset_top = -30
	_confirm.offset_bottom = 30
	_confirm.visible = false
	_root.add_child(_confirm)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	_confirm.add_child(v)
	_confirm_label = Label.new()
	_confirm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_confirm_label.add_theme_color_override(&"font_color", TEXT)
	v.add_child(_confirm_label)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override(&"separation", 16)
	v.add_child(h)
	_keep_btn = Button.new()
	_keep_btn.text = "保留"
	_keep_btn.pressed.connect(keep_display)
	h.add_child(_keep_btn)
	var cancel := Button.new()
	cancel.text = "取消"
	cancel.pressed.connect(revert_display)
	h.add_child(cancel)


# --- behaviour ---------------------------------------------------------------------------------
func _show_tab(i: int) -> void:
	_tab = i
	for k in _pages.size():
		_pages[k].visible = k == i
		_tab_buttons[k].add_theme_color_override(&"font_color", ACCENT if k == i else DIM)
		_tab_buttons[k].add_theme_color_override(&"font_hover_color", ACCENT if k == i else TEXT)


func _volume_of(bus: String) -> int:
	match bus:
		"Master": return Settings.master
		"Music": return Settings.music
	return Settings.sfx


func _refresh() -> void:
	_mode_value.text = Settings.MODE_NAMES[Settings.display_mode]
	var applies := Settings.resolution_applies()
	# full screen / borderless always use the monitor's own resolution
	_res_value.text = Settings.resolution_text(Settings.resolution if applies else Settings.screen_size())
	_res_value.add_theme_color_override(&"font_color", ACCENT if applies else DIM)
	(_res_row.get_meta(&"name") as Label).add_theme_color_override(&"font_color", TEXT if applies else DIM)
	if applies:
		var used := Settings.windowed_size()
		_res_note.text = "" if used == Settings.resolution else "屏幕放不下，实际 %s" % Settings.resolution_text(used)
	else:
		_res_note.text = "跟随显示器；窗口模式下可调整"
	for bus in _sliders:
		var s: HSlider = _sliders[bus][0]
		s.set_value_no_signal(_volume_of(bus))
		_sliders[bus][1].text = str(_volume_of(bus))


func _step_mode(d: int) -> void:
	if _confirm.visible:
		return
	_begin_display_change()
	Settings.set_display_mode(wrapi(Settings.display_mode + d, 0, 3) as Settings.DisplayMode)
	_ask_keep()


func _step_resolution(d: int) -> void:
	if _confirm.visible:
		return
	var list := Settings.resolutions()
	var i := list.find(Settings.resolution)
	if i < 0:
		i = 0
	var next: Vector2i = list[wrapi(i + d, 0, list.size())]
	if not Settings.resolution_applies():
		# remembered for windowed mode; nothing on screen changes now
		Settings.resolution = next
		Settings.save_settings()
		Settings.changed.emit()
		return
	_begin_display_change()
	Settings.set_resolution(next)
	_ask_keep()


func _begin_display_change() -> void:
	_prev_display = Settings.display_state()
	AudioManager.play(&"ui_confirm", -10.0, 0.0, &"UI")


func _ask_keep() -> void:
	_confirm_left = CONFIRM_SECONDS
	_confirm.visible = true
	_update_confirm_text()
	_keep_btn.grab_focus()


func _update_confirm_text() -> void:
	_confirm_label.text = "保留这些显示设置吗？\n%d" % ceili(_confirm_left)


func keep_display() -> void:
	_confirm.visible = false
	Settings.save_settings()
	AudioManager.play(&"ui_confirm", -8.0, 0.0, &"UI")
	_tab_buttons[0].grab_focus()


func revert_display() -> void:
	_confirm.visible = false
	Settings.restore_display_state(_prev_display)
	Settings.save_settings()
	AudioManager.play(&"ui_back", -8.0, 0.0, &"UI")
	_tab_buttons[0].grab_focus()


func is_confirming() -> bool:
	return _confirm.visible


func _process(delta: float) -> void:
	if _confirm.visible:
		_confirm_left -= delta
		if _confirm_left <= 0.0:
			revert_display()
		else:
			_update_confirm_text()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause") or event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		if _confirm.visible:
			revert_display()
		else:
			close()


func close() -> void:
	if _confirm.visible:
		revert_display()
	Settings.save_settings()
	AudioManager.play(&"ui_back", -10.0, 0.0, &"UI")
	closed.emit()
	queue_free()
