extends Node
## Persistent run state: inventory, equipment, objective, checkpoint.
## Gameplay logic lives in components; this only stores data that must
## survive scene changes.

signal objective_changed
signal ammo_changed(ammo: int)
signal inventory_changed

const START_AMMO := 10
const PISTOL_WEAPON := preload("res://resources/weapons/pistol.tres")
const KNIFE_WEAPON := preload("res://resources/weapons/knife.tres")
const BACKPACK_ITEM := preload("res://resources/items/backpack.tres")

var inventory := Inventory.new(10)
## slot -> ItemData or null
var equipment := {}
var ammo: int = START_AMMO:
	set(v):
		ammo = maxi(v, 0)
		ammo_changed.emit(ammo)
var max_hp: float = 100.0
var hp: float = 100.0
var oxygen: float = 100.0
var flags := {}
var objective := {}
var checkpoint := {}
var loot_seed: int = 0
var debug_enabled: bool = OS.is_debug_build()


func _ready() -> void:
	inventory.changed.connect(_on_inventory_changed)
	new_game()


func new_game() -> void:
	inventory.clear()
	equipment = {
		"helmet": null,
		"armor": null,
		"primary": PISTOL_WEAPON.item,
		"melee": KNIFE_WEAPON.item,
		"backpack": BACKPACK_ITEM,
	}
	ammo = START_AMMO
	hp = max_hp
	oxygen = 100.0
	flags = {}
	checkpoint = {}
	objective = {"id": &"", "title": "", "required": {}, "active": false, "complete": false}
	randomize()
	loot_seed = randi()
	objective_changed.emit()


# --- Objective -------------------------------------------------------------
func start_objective(id: StringName, title: String, required: Dictionary) -> void:
	objective = {"id": id, "title": title, "required": required, "active": true, "complete": false}
	_check_objective()
	objective_changed.emit()


func objective_progress(tag: StringName) -> int:
	return inventory.count_tag(tag)


func is_objective_complete() -> bool:
	return objective.get("complete", false)


func _check_objective() -> void:
	if not objective.get("active", false):
		return
	var done := true
	for tag in objective.required:
		if inventory.count_tag(tag) < int(objective.required[tag]):
			done = false
	if done != objective.complete:
		objective.complete = done
		objective_changed.emit()


func clear_objective() -> void:
	objective.active = false
	objective_changed.emit()


func _on_inventory_changed() -> void:
	_check_objective()
	inventory_changed.emit()
	objective_changed.emit()


# --- Checkpoint -------------------------------------------------------------
func snapshot() -> Dictionary:
	var eq := {}
	for k in equipment:
		eq[k] = equipment[k].resource_path if equipment[k] else ""
	return {
		"hp": hp,
		"oxygen": oxygen,
		"ammo": ammo,
		"inventory": inventory.to_data(),
		"equipment": eq,
		"objective": objective.duplicate(true),
		"flags": flags.duplicate(true),
	}


func save_checkpoint(id: StringName, scene_path: String) -> void:
	checkpoint = snapshot()
	checkpoint["id"] = id
	checkpoint["scene"] = scene_path


func has_checkpoint() -> bool:
	return not checkpoint.is_empty()


func restore_checkpoint() -> void:
	if checkpoint.is_empty():
		return
	hp = checkpoint.hp
	oxygen = checkpoint.oxygen
	ammo = checkpoint.ammo
	inventory.from_data(checkpoint.inventory)
	for k in checkpoint.equipment:
		var p: String = checkpoint.equipment[k]
		equipment[k] = load(p) if p != "" else null
	objective = checkpoint.objective.duplicate(true)
	flags = checkpoint.flags.duplicate(true)
	objective_changed.emit()
