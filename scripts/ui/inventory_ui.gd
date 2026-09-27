extends CanvasLayer
## Backpack screen: equipment on the left, 10 slots on the right,
## description of the hovered item at the bottom.

const SLOT_SIZE := Vector2(24, 24)
const EQUIP_SLOTS := [["helmet", "头盔"], ["armor", "护甲"], ["primary", "主武器"], ["melee", "近战武器"], ["backpack", "背包"]]
const EMPTY_ICONS := {
	"helmet": preload("res://art/ui/icons/helmet.png"),
	"armor": preload("res://art/ui/icons/armor.png"),
}

@onready var root: Control = $Root
@onready var equip_list: VBoxContainer = $Root/Panel/HBox/Equip/List
@onready var grid: GridContainer = $Root/Panel/HBox/Bag/Grid
@onready var bag_title: Label = $Root/Panel/HBox/Bag/Title
@onready var desc_name: Label = $Root/Panel/Desc/VBox/Name
@onready var desc_text: Label = $Root/Panel/Desc/VBox/Text

var _open := false


func _ready() -> void:
	layer = 20
	root.visible = false
	GameState.inventory_changed.connect(_refresh)


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
	if v:
		_refresh()
		_show_desc(null)


func _refresh() -> void:
	if not is_inside_tree():
		return
	for c in equip_list.get_children():
		c.queue_free()
	for e in EQUIP_SLOTS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 4)
		var item: ItemData = GameState.equipment.get(e[0])
		var slot := _make_slot(item, 1, EMPTY_ICONS.get(e[0]))
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
	var used := 0
	for s in GameState.inventory.slots:
		if s != null:
			used += 1
		grid.add_child(_make_slot(s.item if s else null, s.count if s else 0))
	bag_title.text = "背包  %d / %d" % [used, GameState.inventory.size]


func _make_slot(item: ItemData, count: int, empty_icon: Texture2D = null) -> Control:
	var slot := PanelContainer.new()
	slot.theme_type_variation = &"SlotPanel"
	slot.custom_minimum_size = SLOT_SIZE
	slot.mouse_filter = Control.MOUSE_FILTER_STOP
	var icon := TextureRect.new()
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if item:
		icon.texture = item.icon
	elif empty_icon:
		icon.texture = empty_icon
		icon.modulate = Color(1, 1, 1, 0.25)
	slot.add_child(icon)
	if item and count > 1:
		var n := Label.new()
		n.text = str(count)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		n.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		n.add_theme_font_size_override(&"font_size", 12)
		n.add_theme_constant_override(&"line_spacing", -4)
		n.add_theme_color_override(&"font_outline_color", Color(0.03, 0.03, 0.04))
		n.add_theme_constant_override(&"outline_size", 3)
		n.position = Vector2(0, 6)
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(n)
	slot.mouse_entered.connect(func():
		slot.theme_type_variation = &"SlotFocusPanel"
		_show_desc(item))
	slot.mouse_exited.connect(func():
		slot.theme_type_variation = &"SlotPanel"
		_show_desc(null))
	return slot


func _show_desc(item: ItemData) -> void:
	if item == null:
		desc_name.text = ""
		desc_text.text = "Tab 关闭"
		desc_text.modulate.a = 0.5
		return
	desc_text.modulate.a = 1.0
	desc_name.text = item.display_name
	desc_text.text = item.description
