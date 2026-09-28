class_name StorageUI
extends CanvasLayer
## 营地仓库 screen: the camp storage (40 slots) next to everything the player
## carries — backpack, the three hand slots and the gear slots. Nothing is
## moved automatically when coming home: the player chooses what to put in
## and what to take out, any item at all (weapons and equipment too).
## Uses the same ItemSlot drag & drop as the backpack screen — every move is
## GameState.move_item() on the real data (stack, swap, validation). A 丢弃
## slot throws unwanted stacks away (never keys / story items).

signal closed

const COLS := 10
const GEAR := [
	["helmet", preload("res://art/ui/icons/helmet.png")],
	["armor", preload("res://art/ui/icons/armor.png")],
	["clothing", preload("res://art/ui/icons/work_uniform.png")],
	["backpack", preload("res://art/ui/icons/backpack.png")],
]
const TEXT := Color(0.93, 0.89, 0.78)
const DIM := Color(0.6, 0.58, 0.52)
const WARN := Color(0.9, 0.62, 0.4)

var storage_slots: Array[ItemSlot] = []
var bag_slots: Array[ItemSlot] = []
var pending_slots: Array[ItemSlot] = []
var hand_slots := {}
## helmet / armor / clothing / backpack
var gear_slots := {}
var discard_slot: ItemSlot

var _open := false
var _root: Control
var _storage_title: Label
var _bag_title: Label
var _storage_grid: GridContainer
var _bag_grid: GridContainer
var _pending_box: VBoxContainer
var _pending_grid: GridContainer
var _desc_name: Label
var _desc_text: Label
var _message := ""


func _ready() -> void:
	layer = 21
	_build()
	_root.visible = false
	GameState.inventory_changed.connect(_refresh)
	GameState.equipment_changed.connect(_refresh)
	GameState.camp_changed.connect(_refresh)


func is_open() -> bool:
	return _open


func open(message := "") -> void:
	_open = true
	_message = message
	_root.visible = true
	var p := get_tree().get_first_node_in_group(&"player") as Player
	if p:
		p.input_enabled = false
	SceneManager.set_cursor(SceneManager.CursorMode.ARROW)
	AudioManager.play(&"bag_open", -6.0)
	_refresh()


func close() -> void:
	if not _open:
		return
	_open = false
	_root.visible = false
	var p := get_tree().get_first_node_in_group(&"player") as Player
	if p:
		p.input_enabled = true
	SceneManager.set_cursor(SceneManager.CursorMode.CROSSHAIR)
	AudioManager.play(&"bag_close", -6.0)
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	if event.is_action_pressed(&"pause") or event.is_action_pressed(&"inventory") or event.is_action_pressed(&"interact"):
		get_viewport().set_input_as_handled()
		close()


# --- building ----------------------------------------------------------------------------
func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -218
	panel.offset_right = 218
	panel.offset_top = -124
	panel.offset_bottom = 124
	_root.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 4)
	panel.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override(&"separation", 14)
	v.add_child(top)
	# storage
	var left := VBoxContainer.new()
	left.add_theme_constant_override(&"separation", 3)
	top.add_child(left)
	_storage_title = _label("营地仓库", TEXT)
	left.add_child(_storage_title)
	_storage_grid = _grid(COLS)
	left.add_child(_storage_grid)
	for i in GameState.STORAGE_CAPACITY:
		var s := _slot({"kind": "storage", "index": i})
		_storage_grid.add_child(s)
		storage_slots.append(s)
	# backpack + hands + discard
	var right := VBoxContainer.new()
	right.add_theme_constant_override(&"separation", 3)
	top.add_child(right)
	_bag_title = _label("背包", TEXT)
	right.add_child(_bag_title)
	_bag_grid = _grid(5)
	right.add_child(_bag_grid)
	right.add_child(_label("手持  1 / 2 / 3", DIM))
	var hands := HBoxContainer.new()
	hands.add_theme_constant_override(&"separation", 3)
	right.add_child(hands)
	for slot in GameState.HAND_SLOTS:
		var s := _slot({"kind": "equip", "slot": slot})
		hands.add_child(s)
		hand_slots[slot] = s
	right.add_child(_label("装备  头盔 / 护甲 / 服装 / 背包", DIM))
	var gear := HBoxContainer.new()
	gear.add_theme_constant_override(&"separation", 3)
	right.add_child(gear)
	for g in GEAR:
		var s := _slot({"kind": "equip", "slot": g[0]})
		s.empty_icon = g[1]
		gear.add_child(s)
		gear_slots[g[0]] = s
	var sep := Control.new()
	sep.custom_minimum_size = Vector2(8, 0)
	gear.add_child(sep)
	discard_slot = _slot({"kind": "discard"})
	discard_slot.empty_icon = null
	gear.add_child(discard_slot)
	var tl := _label("丢弃", DIM)
	tl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	gear.add_child(tl)
	# overflow from coming home
	_pending_box = VBoxContainer.new()
	_pending_box.add_theme_constant_override(&"separation", 2)
	v.add_child(_pending_box)
	_pending_box.add_child(_label("待整理物资 — 仓库已经放不下了", WARN))
	_pending_grid = _grid(COLS)
	_pending_box.add_child(_pending_grid)
	# description / messages
	var desc := PanelContainer.new()
	desc.theme_type_variation = &"PromptPanel"
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(desc)
	var dv := VBoxContainer.new()
	dv.add_theme_constant_override(&"separation", -1)
	desc.add_child(dv)
	_desc_name = _label("", TEXT)
	dv.add_child(_desc_name)
	_desc_text = _label("", DIM)
	_desc_text.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_desc_text.custom_minimum_size = Vector2(400, 0)
	dv.add_child(_desc_text)


func _label(t: String, col: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_color_override(&"font_color", col)
	return l


func _grid(cols: int) -> GridContainer:
	var g := GridContainer.new()
	g.columns = cols
	g.add_theme_constant_override(&"h_separation", 2)
	g.add_theme_constant_override(&"v_separation", 2)
	return g


func _slot(ref: Dictionary) -> ItemSlot:
	var s := ItemSlot.new()
	s.ref = ref
	s.hovered.connect(func(sl: ItemSlot, on: bool): _show_desc(sl.item if on else null))
	return s


# --- refresh from the real data ----------------------------------------------------------
func _refresh() -> void:
	if not is_inside_tree():
		return
	var st := GameState.storage
	for i in storage_slots.size():
		var e = st.slots[i] if i < st.size else null
		storage_slots[i].set_content(e.item if e else null, e.count if e else 0)
	_storage_title.text = "营地仓库  %d / %d" % [st.used_slots(), st.size]
	# backpack (its size follows the clothing)
	var inv := GameState.inventory
	if bag_slots.size() != inv.size:
		for s in bag_slots:
			s.queue_free()
		bag_slots.clear()
		for i in inv.size:
			var s := _slot({"kind": "bag", "index": i})
			_bag_grid.add_child(s)
			bag_slots.append(s)
	for i in bag_slots.size():
		var e = inv.slots[i]
		bag_slots[i].set_content(e.item if e else null, e.count if e else 0)
	_bag_title.text = "背包  %d / %d" % [inv.used_slots(), inv.size]
	for slot in hand_slots:
		var it := GameState.equip_get(slot)
		var txt := ""
		if it and it.weapon and (it.weapon as WeaponData).is_ranged:
			txt = str(GameState.ammo)
		hand_slots[slot].set_content(it, GameState.equip_count(slot), txt)
	for slot in gear_slots:
		gear_slots[slot].set_content(GameState.equip_get(slot), GameState.equip_count(slot))
	# overflow
	var pd := GameState.pending
	if pending_slots.size() != pd.size:
		for s in pending_slots:
			s.queue_free()
		pending_slots.clear()
		for i in pd.size:
			var s := _slot({"kind": "pending", "index": i})
			_pending_grid.add_child(s)
			pending_slots.append(s)
	for i in pending_slots.size():
		var e = pd.slots[i]
		pending_slots[i].set_content(e.item if e else null, e.count if e else 0)
	_pending_box.visible = GameState.has_pending()
	if _message != "" and not GameState.has_pending():
		_message = ""
	_show_desc(null)


func _show_desc(item: ItemData) -> void:
	if item:
		_desc_name.text = item.display_name
		_desc_text.text = item.description
		_desc_text.remove_theme_color_override(&"font_color")
		return
	_desc_name.text = ""
	if _message != "":
		_desc_text.text = _message
		_desc_text.add_theme_color_override(&"font_color", WARN)
	else:
		_desc_text.text = "拖动物品存入或取出（武器、装备也可以）    F / Tab 关闭"
		_desc_text.add_theme_color_override(&"font_color", DIM)
