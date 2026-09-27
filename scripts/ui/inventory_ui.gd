extends CanvasLayer
## Backpack screen: equipment on the left, the backpack slots on the right,
## the selected item's description and action (装备 / 卸下) at the bottom.

const SLOT_SIZE := Vector2(20, 20)
const EQUIP_SLOTS := [
	["helmet", "头盔"], ["armor", "护甲"], ["clothing", "服装"],
	["primary", "主武器"], ["melee", "近战武器"], ["throwable", "投掷物"], ["backpack", "背包"],
]
const EMPTY_ICONS := {
	"helmet": preload("res://art/ui/icons/helmet.png"),
	"armor": preload("res://art/ui/icons/armor.png"),
	"clothing": preload("res://art/ui/icons/work_uniform.png"),
	"throwable": preload("res://art/ui/icons/empty_bottle.png"),
}

@onready var root: Control = $Root
@onready var equip_list: VBoxContainer = $Root/Panel/HBox/Equip/List
@onready var grid: GridContainer = $Root/Panel/HBox/Bag/Grid
@onready var bag_title: Label = $Root/Panel/HBox/Bag/Title
@onready var desc_name: Label = $Root/Panel/Desc/VBox/Name
@onready var desc_text: Label = $Root/Panel/Desc/VBox/Text
@onready var action_btn: Button = $Root/Panel/Desc/VBox/Action

var _open := false
## Current selection: {"kind": "bag"/"equip", "item": ItemData, "slot": String}
var _sel := {}


func _ready() -> void:
	layer = 20
	root.visible = false
	GameState.inventory_changed.connect(_refresh)
	GameState.equipment_changed.connect(_refresh)
	action_btn.pressed.connect(_on_action)
	action_btn.visible = false


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
	AudioManager.play(&"bag_open" if v else &"bag_close", -6.0)
	var p := get_tree().get_first_node_in_group(&"player") as Player
	if p:
		p.input_enabled = not v
	SceneManager.set_cursor(SceneManager.CursorMode.ARROW if v else SceneManager.CursorMode.CROSSHAIR)
	if v:
		_sel = {}
		_refresh()


func _refresh() -> void:
	if not is_inside_tree():
		return
	for c in equip_list.get_children():
		c.queue_free()
	for e in EQUIP_SLOTS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 4)
		row.custom_minimum_size = Vector2(0, 20)
		var item: ItemData = GameState.equipment.get(e[0])
		var count := 1
		if e[0] == "throwable" and item:
			count = GameState.inventory.count_item(item.id)
		var slot := _make_slot(item, count, EMPTY_ICONS.get(e[0]), {"kind": "equip", "item": item, "slot": e[0]})
		row.add_child(slot)
		var l := Label.new()
		l.text = e[1]
		l.add_theme_color_override(&"font_color", Color(0.55, 0.53, 0.48) if item == null else Color(0.83, 0.8, 0.72))
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(l)
		if e[0] == "primary" and item != null:
			var a := Label.new()
			a.text = "%d发" % GameState.ammo
			a.add_theme_color_override(&"font_color", Color(0.72, 0.62, 0.42))
			a.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(a)
		equip_list.add_child(row)
	for c in grid.get_children():
		c.queue_free()
	var inv := GameState.inventory
	for i in inv.size:
		var s = inv.slots[i]
		grid.add_child(_make_slot(s.item if s else null, s.count if s else 0, null, {"kind": "bag", "item": s.item if s else null, "slot": str(i)}))
	bag_title.text = "背包  %d / %d" % [inv.used_slots(), inv.size]
	_show_desc(_sel.get("item"))


func _make_slot(item: ItemData, count: int, empty_icon: Texture2D, sel: Dictionary) -> Control:
	var slot := PanelContainer.new()
	var selected: bool = not _sel.is_empty() and _sel.kind == sel.kind and _sel.slot == sel.slot and item != null
	slot.theme_type_variation = &"SlotFocusPanel" if selected else &"SlotPanel"
	slot.custom_minimum_size = SLOT_SIZE
	slot.mouse_filter = Control.MOUSE_FILTER_STOP
	var icon := TextureRect.new()
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if item:
		icon.texture = item.icon
	elif empty_icon:
		icon.texture = empty_icon
		icon.modulate = Color(1, 1, 1, 0.22)
	slot.add_child(icon)
	if item and count > 1:
		var n := Label.new()
		n.text = str(count)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		n.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		n.add_theme_constant_override(&"line_spacing", -4)
		n.add_theme_color_override(&"font_outline_color", Color(0.03, 0.03, 0.04))
		n.add_theme_constant_override(&"outline_size", 3)
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(n)
	slot.mouse_entered.connect(func():
		if _sel.is_empty():
			_show_desc(item))
	slot.mouse_exited.connect(func():
		if _sel.is_empty():
			_show_desc(null))
	slot.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			if item == null:
				_sel = {}
			else:
				_sel = sel.duplicate()
				AudioManager.play(&"ui_move", -12.0, 0.0, &"UI")
			_refresh())
	return slot


func _show_desc(item: ItemData) -> void:
	action_btn.visible = false
	desc_text.remove_theme_color_override(&"font_color")
	if item == null:
		desc_name.text = ""
		desc_text.text = "点击物品查看    Tab 关闭"
		desc_text.modulate.a = 0.5
		return
	desc_text.modulate.a = 1.0
	desc_name.text = item.display_name
	desc_text.text = item.description
	if _sel.is_empty() or _sel.item != item:
		return
	if _sel.kind == "bag" and item.equip_slot != &"":
		var already: bool = GameState.equipment.get(String(item.equip_slot)) == item
		action_btn.text = "已装备" if already else "装备"
		action_btn.disabled = already
		action_btn.visible = true
	elif _sel.kind == "equip" and _sel.slot in ["clothing", "throwable"]:
		action_btn.text = "卸下"
		action_btn.disabled = false
		action_btn.visible = true


## Equip / unequip the selected item. Never loses items: unequipping the
## uniform is refused while the backpack holds more than the base capacity.
func _on_action() -> void:
	if _sel.is_empty():
		return
	var err := ""
	if _sel.kind == "bag":
		err = GameState.equip_item(_sel.item)
	else:
		err = GameState.unequip(_sel.slot)
	if err != "":
		desc_text.text = err
		desc_text.add_theme_color_override(&"font_color", Color(0.85, 0.35, 0.3))
		AudioManager.play(&"ui_back", -8.0, 0.0, &"UI")
		var p := get_tree().get_first_node_in_group(&"player") as Player
		if p:
			p.say(err)
		return
	AudioManager.play(&"equip", -8.0)
	_sel = {}
	_refresh()
