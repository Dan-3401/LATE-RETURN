extends Node
## Global noise bus. Anything can emit a noise; hearing components listen.
## A noise only carries its position — never the emitter's live position.

signal noise_emitted(event: Dictionary)

## Recent events kept for the debug overlay.
var recent: Array = []


## kind: footstep, land, breath, gasp, knife, gunshot, roar, growl, impact...
func emit_noise(pos: Vector2, radius: float, source: Node = null, kind: StringName = &"generic") -> void:
	if radius <= 0.0:
		return
	var ev := {
		"position": pos,
		"radius": radius,
		"source": source,
		"kind": kind,
		"time": Time.get_ticks_msec() / 1000.0,
	}
	recent.append(ev)
	if recent.size() > 24:
		recent.pop_front()
	noise_emitted.emit(ev)


func clear() -> void:
	recent.clear()
