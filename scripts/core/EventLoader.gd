extends RefCounted
class_name EventLoader

## Manifest order is stable both in the editor and in exported PCKs.
static func load_events_from_json() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var ids: Variant = _read("res://data/event_manifest.json")
	if not ids is Array: return result
	var seen := {}
	for id in ids:
		var event: Variant = _read("res://data/events_%s.json" % id)
		if not event is Dictionary or event.get("id", "") != id or seen.has(id):
			push_error("Invalid or duplicate event: %s" % id)
			return []
		if event.get("type") != "shopping" and event.get("options", []).is_empty():
			push_error("Event has no choices: %s" % id)
			return []
		seen[id] = true
		result.append(event)
	return result

static func _read(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Cannot open event data: " + path)
		return null
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_error("%s:%d %s" % [path, json.get_error_line(), json.get_error_message()])
		return null
	return json.data
