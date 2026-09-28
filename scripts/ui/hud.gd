class_name HUD
extends Node
## In-game HUD glue: objective tracker, hints, weapon/ammo, HP, sneak icon,
## oxygen meter. Listens to the player's components and GameState.

@onready var world_ui: WorldUI = $WorldUI
@onready var objective_box: Control = $Overlay/Objective
@onready var objective_title: Label = $Overlay/Objective/Title
@onready var objective_rows: VBoxContainer = $Overlay/Objective/Rows
@onready var hint_label: Label = $Overlay/Hint
@onready var sneak_icon: TextureRect = $Overlay/Status/Sneak
@onready var hp_bar: PixelMeter = $Overlay/Status/HP
@onready var quick_bar: QuickBar = $Overlay/QuickBar
@onready var damage_vignette: TextureRect = $Overlay/DamageVignette
@onready var hide_shade: TextureRect = $Overlay/HideShade
@onready var inventory_ui: Node = $InventoryUI
@onready var camp_box: Control = $Overlay/Camp
@onready var camp_food: Label = $Overlay/Camp/HBox/Food
@onready var camp_water: Label = $Overlay/Camp/HBox/Water
@onready var settlement: Control = $Overlay/Settlement
@onready var settlement_rows: Label = $Overlay/Settlement/VBox/Rows
@onready var settlement_rare: Label = $Overlay/Settlement/VBox/Rare
@onready var pause_menu: Node = $PauseMenu

var player: Player
var _hint_tween: Tween
var _hp_show := 0.0
var _last_objective_done := false


func _ready() -> void:
	GameState.objective_changed.connect(_refresh_objective)
	GameState.camp_changed.connect(_refresh_camp)
	_refresh_camp()
	hint_label.modulate.a = 0.0
	damage_vignette.modulate.a = 0.0
	_refresh_objective()
	await get_tree().process_frame
	bind_player(get_tree().get_first_node_in_group(&"player") as Player)


func bind_player(p: Player) -> void:
	player = p
	if player == null:
		return
	quick_bar.player = player
	player.health.changed.connect(_on_hp_changed)
	player.health.damaged.connect(func(_a, _s): _flash_damage())
	hp_bar.ratio = player.health.hp / player.health.max_hp
	hp_bar.target_alpha = 0.0 if player.health.hp >= player.health.max_hp else 0.8


func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	sneak_icon.modulate.a = move_toward(sneak_icon.modulate.a, 0.85 if player.movement.sneak_toggled else 0.0, delta * 4.0)
	var b := player.breath
	var show_o2 := b.holding or b.gasping or b.oxygen < b.max_oxygen - 0.5
	var col := Color(0.62, 0.74, 0.86) if not b.gasping else Color(0.8, 0.45, 0.4)
	world_ui.set_meter(&"oxygen", player.get_speech_anchor() + Vector2(0, -2), b.oxygen / b.max_oxygen, col, show_o2 and not player.is_dead(), 16)
	if _hp_show > 0.0:
		_hp_show -= delta
		if _hp_show <= 0.0 and player.health.hp >= player.health.max_hp:
			hp_bar.target_alpha = 0.0
	damage_vignette.modulate.a = move_toward(damage_vignette.modulate.a, 0.0, delta * 1.5)
	hide_shade.modulate.a = move_toward(hide_shade.modulate.a, 0.85 if player.is_hidden() else 0.0, delta * 3.0)


func _on_hp_changed(hp: float, max_hp: float) -> void:
	hp_bar.ratio = hp / max_hp
	hp_bar.fill_color = Color(0.72, 0.25, 0.2) if hp / max_hp < 0.35 else Color(0.78, 0.7, 0.6)
	hp_bar.target_alpha = 0.85
	_hp_show = 3.0


func _flash_damage() -> void:
	damage_vignette.modulate.a = 0.55




func _refresh_camp() -> void:
	camp_box.visible = GameState.is_free_phase()
	# counted from the real items in the camp storage
	camp_food.text = str(GameState.camp_food())
	camp_water.text = str(GameState.camp_water())


const SETTLEMENT_MAX_ROWS := 7


## Short "本次带回：" list of what this trip brought home (still in the
## backpack — the player puts things away at the storage), rare finds apart.
func show_settlement(got: Dictionary) -> void:
	var items: Dictionary = got.get("items", {})
	var rows: Array = []
	var rare_rows: Array = []
	for id in items:
		var it: ItemData = DiaryWriter.item(id)
		var n: int = items[id]
		if it == null:
			continue
		var line := "%s ×%d" % [it.display_name, n]
		if id in GameState.RARE_ITEMS:
			rare_rows.append(line)
		else:
			rows.append(line)
	var room := SETTLEMENT_MAX_ROWS - rare_rows.size()
	if rows.size() > room:
		var extra := rows.size() - (room - 1)
		rows = rows.slice(0, room - 1)
		rows.append("…… 另有 %d 种" % extra)
	if rows.is_empty() and rare_rows.is_empty():
		rows.append("这次什么也没带回来")
	settlement_rows.text = "\n".join(rows)
	settlement_rows.visible = not rows.is_empty()
	# rare finds get their own, warmer line on top
	settlement_rare.text = "\n".join(rare_rows)
	settlement_rare.visible = not rare_rows.is_empty()
	settlement.reset_size()
	var t := create_tween()
	t.tween_property(settlement, "modulate:a", 1.0, 0.4)
	t.tween_interval(3.8)
	t.tween_property(settlement, "modulate:a", 0.0, 0.8)


func _refresh_objective() -> void:
	var o := GameState.objective
	objective_box.visible = o.get("active", false)
	if not objective_box.visible:
		return
	objective_title.text = o.title
	for c in objective_rows.get_children():
		c.queue_free()
	var names := {&"water": "水", &"food": "食物"}
	for tag in o.required:
		var l := Label.new()
		var have := GameState.objective_progress(tag)
		var need: int = int(o.required[tag])
		l.text = "%s  %d / %d" % [names.get(tag, String(tag)), mini(have, need), need]
		if have >= need:
			l.add_theme_color_override(&"font_color", Color(0.62, 0.72, 0.55))
		objective_rows.add_child(l)


## Low-key hint at the bottom of the screen (e.g. "H：打开手电筒").
func show_hint(text: String, duration: float = 4.0) -> void:
	hint_label.text = text
	if _hint_tween:
		_hint_tween.kill()
	_hint_tween = create_tween()
	_hint_tween.tween_property(hint_label, "modulate:a", 1.0, 0.5)
	_hint_tween.tween_interval(duration)
	_hint_tween.tween_property(hint_label, "modulate:a", 0.0, 0.8)


func hide_hint() -> void:
	if _hint_tween:
		_hint_tween.kill()
	_hint_tween = create_tween()
	_hint_tween.tween_property(hint_label, "modulate:a", 0.0, 0.4)


func is_menu_open() -> bool:
	return inventory_ui.call(&"is_open") or pause_menu.call(&"is_open")
