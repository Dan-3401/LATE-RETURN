extends CanvasLayer
## Backpack screen. Left: the three hand slots (1 / 2 / 3) and the gear
## slots; right: the backpack cells; bottom: the selected item.
## Drag & drop is the main way to sort things (see ItemSlot). The screen
## only shows GameState — it never stores where an item is.

const GEAR_SLOTS := [["helmet", "头盔"], ["armor", "护甲"], ["clothing", "服装"], ["backpack", "背包"]]
const EMPTY_ICONS := {
	"helmet": preload("res://art/ui/icons/helmet.png"),
	"armor": preload("res://art/ui/icons/armor.png"),
	"clothing": preload("res://art/ui/icons/work_uniform.png"),
	"backpack": preload("res://art/ui/icons/backpack.png"),
}

@onready var root: Control = $Root
@onready var equip_col: VBoxContainer = $Root/Panel/HBox/Equip
@onready var equip_list: VBoxContainer = $Root/Panel/HBox/Equip/List
@onready var grid: GridContainer = $Root/Panel/HBox/Bag/Grid
@onready var bag_title: Label = $Root/Panel/HBox/Bag/Title
@onready var desc_name: Label = $Root/Panel/Desc/VBox/Name
@onready var desc_text: Label = $Root/Panel/Desc/VBox/Text
@onready var action_btn: Button = $Root/Panel/Desc/VBox/Action

var _open := false
var _selected: ItemSlot = null
## slot id -> ItemSlot (hand1..3, helmet, armor, clothing, backpack)
var equip_slots := {}
var bag_slots: Array[ItemSlot] = []
## Right-click menu (使用 / 拆分 / 丢弃) for backpack stacks.
var context_menu: ItemContextMenu


func _ready() -> void:
	layer = 20
	root.visible = false
	_build_equipment()
	GameState.inventory_changed.connect(_refresh)
	GameState.equipment_changed.connect(_refresh)
	GameState.ammo_changed.connect(func(_a): _refresh())
	action_btn.pressed.connect(_on_action)
	action_btn.visible = false
	context_menu = ItemContextMenu.new()
	root.add_child(context_menu)
	context_menu.acted.connect(func(_a): _selected = null; _refresh())


func is_open() -> bool:
	return _open


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"inventory"):
		var p := get_tree().get_first_node_in_group(&"player") as Player
		if not _open and (p == null or p.is_dead() or p.state == Player.State.CUTSCENE):
			return
		set_open(not _open)
		get_viewport().set_input_as_handled()
	elif _open and event.is_action_pressed(&"pause"):
		set_open(false)
		get_viewport().set_input_as_handled()


func set_open(v: bool) -> void:
	_open = v
	root.visible = v
	context_menu.close_all()
	AudioManager.play(&"bag_open" if v else &"bag_close", -6.0)
	var p := get_tree().get_first_node_in_group(&"player") as Player
	if p:
		p.input_enabled = not v
	SceneManager.set_cursor(SceneManager.CursorMode.ARROW if v else SceneManager.CursorMode.CROSSHAIR)
	if v:
		_selected = null
		_refresh()


# --- building ----------------------------------------------------------------------
func _build_equipment() -> void:
	for c in equip_list.get_children():
		c.queue_free()
	var hand_title := Label.new()
	hand_title.text = "手持"
	hand_title.add_theme_color_override(&"font_color", Color(0.62, 0.6, 0.54))
	equip_list.add_child(hand_title)
	var hand_row := HBoxContainer.new()
	hand_row.add_theme_constant_override(&"separation", 3)
	equip_list.add_child(hand_row)
	var key_row := HBoxContainer.new()
	key_row.add_theme_constant_override(&"separation", 3)
	equip_list.add_child(key_row)
	for i in GameState.HAND_SLOTS.size():
		var s := _make_slot({"kind": "equip", "slot": GameState.HAND_SLOTS[i]})
		hand_row.add_child(s)
		equip_slots[GameState.HAND_SLOTS[i]] = s
		var key := Label.new()
		key.text = str(i + 1)
		key.custom_minimum_size = Vector2(20, 0)
		key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		key.add_theme_color_override(&"font_color", Color(0.55, 0.53, 0.48))
		key_row.add_child(key)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 4)
	equip_list.add_child(gap)
	for e in GEAR_SLOTS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 4)
		var s := _make_slot({"kind": "equip", "slot": e[0]})
		s.empty_icon = EMPTY_ICONS.get(e[0])
		row.add_child(s)
		var l := Label.new()
		l.text = e[1]
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		l.name = "Label"
		row.add_child(l)
		equip_list.add_child(row)
		equip_slots[e[0]] = s


func _make_slot(ref: Dictionary) -> ItemSlot:
	var s := ItemSlot.new()
	s.ref = ref
	s.clicked.connect(_on_slot_clicked)
	s.hovered.connect(_on_slot_hovered)
	s.context_requested.connect(_on_slot_context)
	return s


## Right-click: the action menu for this one stack (backpack cells only;
## equipment is handled by drag & drop / 装备 / 卸下).
func _on_slot_context(s: ItemSlot) -> void:
	if InventoryActions.context_of(s.ref) == InventoryActions.Context.NONE:
		return
	context_menu.open_for(s.ref, s.global_position + Vector2(s.size.x + 1, 0))


func _ensure_bag_slots() -> void:
	var n := GameState.inventory.size
	if bag_slots.size() == n:
		return
	for s in bag_slots:
		s.queue_free()
	bag_slots.clear()
	for i in n:
		var s := _make_slot({"kind": "bag", "index": i})
		grid.add_child(s)
		bag_slots.append(s)
	if _selected and _selected.ref.kind == "bag":
		_selected = null


# --- refresh from the real data ------------------------------------------------------
func _refresh() -> void:
	if not is_inside_tree():
		return
	_ensure_bag_slots()
	for slot_id in equip_slots:
		var s: ItemSlot = equip_slots[slot_id]
		var it := GameState.equip_get(slot_id)
		s.selected = s == _selected
		var txt := ""
		if it and it.weapon and (it.weapon as WeaponData).is_ranged:
			txt = str(GameState.ammo)
		s.set_content(it, GameState.equip_count(slot_id), txt)
		var row := s.get_parent()
		if row.has_node("Label"):
			(row.get_node("Label") as Label).add_theme_color_override(&"font_color",
				Color(0.55, 0.53, 0.48) if it == null else Color(0.83, 0.8, 0.72))
	var inv := GameState.inventory
	for i in bag_slots.size():
		var st = inv.slots[i]
		bag_slots[i].selected = bag_slots[i] == _selected
		bag_slots[i].set_content(st.item if st else null, st.count if st else 0)
	bag_title.text = "背包  %d / %d" % [inv.used_slots(), inv.size]
	if _selected and _selected.item == null:
		_selected = null
	_show_desc(_selected.item if _selected else null)


# --- selection / description -------------------------------------------------------
func _on_slot_clicked(s: ItemSlot) -> void:
	if s.item == null:
		_selected = null
	else:
		_selected = s
		AudioManager.play(&"ui_move", -12.0, 0.0, &"UI")
	_refresh()


func _on_slot_hovered(s: ItemSlot, on: bool) -> void:
	if _selected == null:
		_show_desc(s.item if on else null)


func _show_desc(item: ItemData) -> void:
	action_btn.visible = false
	desc_text.remove_theme_color_override(&"font_color")
	if item == null:
		desc_name.text = ""
		desc_text.text = "拖动物品整理    点击查看    右键操作    Tab 关闭"
		desc_text.modulate.a = 0.5
		return
	desc_text.modulate.a = 1.0
	desc_name.text = item.display_name
	desc_text.text = item.description
	if _selected == null or _selected.item != item:
		return
	if _selected.ref.kind == "bag" and item.slot_type() != ItemData.SlotType.NONE:
		action_btn.text = "装备"
		action_btn.disabled = false
		action_btn.visible = true
	elif _selected.ref.kind == "equip":
		action_btn.text = "卸下"
		action_btn.disabled = false
		action_btn.visible = true


## Button alternative to dragging. Never loses items.
func _on_action() -> void:
	if _selected == null or _selected.item == null:
		return
	var err := ""
	if _selected.ref.kind == "bag":
		err = GameState.quick_equip(_selected.ref.index)
	else:
		err = GameState.unequip_to_bag(_selected.ref.slot)
	if err != "":
		desc_text.text = err
		desc_text.add_theme_color_override(&"font_color", Color(0.85, 0.35, 0.3))
		AudioManager.play(&"ui_back", -8.0, 0.0, &"UI")
		var p := get_tree().get_first_node_in_group(&"player") as Player
		if p:
			p.say(err)
		return
	AudioManager.play(&"equip", -8.0)
	_selected = null
	_refresh()
