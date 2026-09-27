class_name RigData
extends Resource
## Per-frame attachment points exported by the art generator.
## points[anim_name][frame] = { "shoulder": Vector2, "chest": Vector2, "head": Vector2 }
## Coordinates are relative to the character's feet (sprite origin).

@export var points: Dictionary = {}


func get_point(anim: StringName, frame: int, key: String, fallback := Vector2.ZERO) -> Vector2:
	var a: Array = points.get(String(anim), [])
	if a.is_empty():
		return fallback
	var f: Dictionary = a[clampi(frame, 0, a.size() - 1)]
	return f.get(key, fallback)
