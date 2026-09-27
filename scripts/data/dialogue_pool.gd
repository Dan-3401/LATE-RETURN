class_name DialoguePool
extends Resource
## A pool of short conversations (DialogueData script format), separated by
## lines containing only "---". pick() avoids repeating the previous one.

@export_multiline var pool_text: String = ""

var _cache: Array = []


func entries() -> Array:
	if _cache.is_empty():
		for block in pool_text.split("\n---\n"):
			if block.strip_edges() != "":
				var d := DialogueData.new()
				d.script_text = block
				_cache.append(d)
	return _cache


func pick(last: int) -> int:
	var n := entries().size()
	if n <= 1:
		return 0
	var i := randi() % n
	while i == last:
		i = randi() % n
	return i
