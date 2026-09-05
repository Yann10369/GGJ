extends RefCounted
class_name EventLoader

## 事件卡片加载器
## 从 data/ 目录加载 JSON 事件文件并转换为 EVENTS 数组

static var _event_cache: Array[Dictionary] = []

## 从 JSON 文件加载所有事件
static func load_events_from_json(base_path: String = "res://data/") -> Array[Dictionary]:
	if not _event_cache.is_empty():
		return _event_cache

	var dir = DirAccess.open(base_path)
	if not dir:
		push_error("Failed to open data directory: " + base_path)
		return []

	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		if file_name.ends_with(".json") and file_name.begins_with("events_"):
			var file_path = base_path + file_name
			var event = load_event_file(file_path)
			if event:
				_event_cache.append(event)
		file_name = dir.get_next()

	dir.list_dir_end()

	# 按 forced_days 排序，确保强制事件优先
	_event_cache.sort_custom(func(a, b): return a.get("forced_days", []).size() > b.get("forced_days", []).size())

	return _event_cache

## 加载单个事件文件
static func load_event_file(file_path: String) -> Dictionary:
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("Failed to open file: " + file_path)
		return {}

	var json_text = file.get_as_text()
	file.close()

	var json = JSON.new()
	var parse_result = json.parse(json_text)
	if parse_result != OK:
		push_error("JSON parse error in " + file_path + ": " + json.get_error_message())
		return {}

	var event = json.data
	if not event or not event.has("id"):
		push_error("Invalid event format in " + file_path)
		return {}

	return event

## 清空缓存（用于重新加载）
static func reload() -> void:
	_event_cache.clear()

## 获取事件数量
static func get_event_count() -> int:
	return _event_cache.size()

## 根据 ID 查找事件
static func find_event_by_id(id: String) -> Dictionary:
	for event in _event_cache:
		if event.get("id") == id:
			return event
	return {}
