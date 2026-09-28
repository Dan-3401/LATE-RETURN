class_name QuickBar
extends Control
## The three hand slots (keys 1 / 2 / 3) in the bottom-right corner.
## Reads the real equipment data; the selected slot gets a slightly
## brighter frame and a small tick under it — nothing louder.

const SLOT := 20
const GAP := 3
const DIM := Color(1, 1, 1, 0.55)

var _slots: Array[PanelContainer] = []
var _icons: Array[TextureRect] = []
var _counts: Array[Label] = []
var _marker: ColorRect
var _name: Label
var _name_tween: Tween
var player: Player


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in 3:
		var p := PanelContainer.new()
		p.theme_type_variation = &"SlotPanel"
		p.position = Vector2(i * (SLOT + GAP), 0)
		p.size = Vector2(SLOT, SLOT)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icon := TextureRect.new()
		icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		p.add_child(icon)
		add_child(p)
		var key := Label.new()
		key.text = str(i + 1)
		key.position = Vector2(i * (SLOT + GAP), -13)
		key.size = Vector2(SLOT, 12)
		key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		key.add_theme_color_override(&"font_color", Color(0.62, 0.6, 0.54))
		key.add_theme_color_override(&"font_outline_color", Color(0.03, 0.03, 0.04))
		key.add_theme_constant_override(&"outline_size", 3)
		add_child(key)
		var cnt := Label.new()
		cnt.position = Vector2(i * (SLOT + GAP), 9)
		cnt.size = Vector2(SLOT - 1, 12)
		cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		cnt.add_theme_color_override(&"font_outline_color", Color(0.03, 0.03, 0.04))
		cnt.add_theme_constant_override(&"outline_size", 3)
		add_child(cnt)
		_slots.append(p)
		_icons.append(icon)
		_counts.append(cnt)
	_marker = ColorRect.new()
	_marker.color = Color(0.86, 0.8, 0.62)
	_marker.size = Vector2(8, 1)
	_marker.visible = false
	add_child(_marker)
	_name = Label.new()
	# the held item's name, briefly, to the left of the bar
	_name.position = Vector2(-124, 4)
	_name.size = Vector2(118, 12)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_name.add_theme_color_override(&"font_color", Color(0.78, 0.74, 0.64))
	_name.add_theme_color_override(&"font_outline_color", Color(0.03, 0.03, 0.04))
	_name.add_theme_constant_override(&"outline_size", 3)
	_name.modulate.a = 0.0
	add_child(_name)
	GameState.equipment_changed.connect(refresh)
	GameState.inventory_changed.connect(refresh)
	GameState.ammo_changed.connect(func(_a): refresh())
	GameState.active_hand_changed.connect(_on_active_changed)
	refresh()


func _on_active_changed(_i: int) -> void:
	refresh()
	var it := GameState.hand_item(GameState.active_hand)
	_name.text = it.display_name if it else ("空手" if GameState.active_hand >= 0 else "")
	if _name_tween:
		_name_tween.kill()
	_name_tween = create_tween()
	_name_tween.tween_property(_name, "modulate:a", 1.0, 0.15)
	_name_tween.tween_interval(1.4)
	_name_tween.tween_property(_name, "modulate:a", 0.0, 0.6)


func refresh() -> void:
	if _slots.is_empty():
		return
	for i in 3:
		var slot: String = GameState.HAND_SLOTS[i]
		var it := GameState.equip_get(slot)
		var active := GameState.active_hand == i
		_slots[i].theme_type_variation = &"SlotFocusPanel" if active else &"SlotPanel"
		_slots[i].modulate = Color.WHITE if active else DIM
		_icons[i].texture = it.icon if it else null
		var txt := ""
		if it:
			if it.weapon and (it.weapon as WeaponData).is_ranged:
				txt = str(GameState.ammo)
			elif it.stackable:
				txt = str(GameState.equip_count(slot))
		_counts[i].text = txt
		_counts[i].modulate = Color.WHITE if active else DIM
		var ammo_out: bool = it != null and it.weapon != null and (it.weapon as WeaponData).is_ranged and GameState.ammo <= 0
		_counts[i].add_theme_color_override(&"font_color", Color(0.8, 0.36, 0.3) if ammo_out else Color(0.86, 0.82, 0.72))
	var a := GameState.active_hand
	_marker.visible = a >= 0
	if a >= 0:
		_marker.position = Vector2(a * (SLOT + GAP) + (SLOT - 8) / 2.0, SLOT + 2)
