class_name DialogueData
extends Resource
## A scripted conversation written in a tiny plain-text format:
##   speaker: text            -> a spoken line
##   [pause 1.5]              -> silence
##   [cmd name arg...]        -> a command handled by the cutscene script
## Lines starting with # are comments.

@export_multiline var script_text: String = ""


func parse() -> Array:
	var out: Array = []
	for raw in script_text.split("\n"):
		var line := raw.strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		if line.begins_with("[") and line.ends_with("]"):
			var parts := line.substr(1, line.length() - 2).split(" ", false)
			if parts.size() > 0 and parts[0] == "pause":
				out.append({"type": "pause", "time": float(parts[1]) if parts.size() > 1 else 1.0})
			elif parts.size() > 0 and parts[0] == "cmd":
				out.append({"type": "cmd", "name": parts[1] if parts.size() > 1 else "", "args": parts.slice(2)})
			continue
		var idx := line.find(":")
		if idx == -1:
			idx = line.find("：")
		if idx == -1:
			continue
		out.append({"type": "line", "speaker": line.substr(0, idx).strip_edges(), "text": line.substr(idx + 1).strip_edges()})
	return out
