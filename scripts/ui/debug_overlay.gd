extends CanvasLayer
## Debug readout (F3). Only available in debug builds.
## World-space debug drawing (vision cones, hearing ranges, noise events,
## last seen/heard positions) is done by DebugDraw nodes that read
## GameState.debug_enabled.

@onready var label: Label = $Label


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not OS.is_debug_build():
		GameState.debug_enabled = false
		queue_free()
		return
	GameState.debug_enabled = false
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"debug_toggle"):
		GameState.debug_enabled = not GameState.debug_enabled
		visible = GameState.debug_enabled


func _process(_delta: float) -> void:
	if not visible:
		return
	var lines := PackedStringArray()
	lines.append("FPS %d" % Engine.get_frames_per_second())
	var p := get_tree().get_first_node_in_group(&"player") as Player
	if p:
		lines.append("Player %s  %s" % [Player.State.keys()[p.state], MovementComponent.Mode.keys()[p.movement.mode]])
		lines.append("HP %.0f  O2 %.0f%s" % [p.health.hp, p.breath.oxygen, "  HOLD" if p.breath.holding else ("  GASP" if p.breath.gasping else "")])
		lines.append("Presence %.2f  grass:%d exposure:%.2f hidden:%s" % [p.stealth.presence, p.stealth.grass_count, p.stealth.exposure(), p.stealth.hidden])
	var recent := NoiseSystem.recent
	if not recent.is_empty():
		var ev: Dictionary = recent[-1]
		lines.append("Noise %s r=%.0f" % [ev.kind, ev.radius])
	for z in get_tree().get_nodes_in_group(&"zombie"):
		if z.has_method(&"debug_state"):
			lines.append(z.call(&"debug_state"))
	label.text = "\n".join(lines)
