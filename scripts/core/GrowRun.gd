extends RefCounted
class_name GrowRun

## The entire run lives here. The UI cannot skip settlement or apply an option twice.
enum Phase { MORNING, EVENT, RESULT, NIGHT, RECAP, ENDING }
var phase := Phase.MORNING
var day := 1
var final_day := GameData.TOTAL_DAYS
var stats: Dictionary = GameData.initial_stats()
var flags: Dictionary = GameData.initial_flags()
var events: Array[Dictionary] = []
var by_id: Dictionary = {}
var shown: Dictionary = {} # ID -> last resolved day; never cleared between days.
var eligible_since: Dictionary = {}
var pending: Array[Dictionary] = []
var journal: Array[Dictionary] = []
var history: Array[Dictionary] = []
var metrics := {"duty_days": 0, "duty_shifts": 0, "neighbors_helped": 0, "help_requests": 0}
var rng := RandomNumberGenerator.new()
var current: Dictionary = {}
var options: Array[Dictionary] = []
var shop: Dictionary = {}
var ending: Dictionary = {}
var last_result := ""
var last_changes := ""
var night_text := ""
var selected_action := ""
var action_delta: Dictionary = {}
var action_exposure := 0
var ration := 0
var duty_started := -1
var slots_used := 0
var day_ids: Array[String] = []

func _init(seed_value: int = -1, requested_days: int = GameData.TOTAL_DAYS) -> void:
	if seed_value < 0: rng.randomize()
	else: rng.seed = seed_value
	events = EventLoader.load_events_from_json()
	final_day = maxi(2, requested_days)
	for event in events:
		by_id[event["id"]] = event
		# The epilogue follows the latest authored main-story deadline.
		if event.has("deadline"): final_day = maxi(final_day, int(event["deadline"]) + 1)

func act(index: int) -> bool:
	if phase != Phase.MORNING or index < 0 or index >= GameData.ACTIONS.size(): return false
	var action: Dictionary = GameData.ACTIONS[index]
	selected_action = action["id"]
	var before := stats.duplicate()
	var before_exposure := int(flags["exposure"])
	apply_effects(action.get("effects", {}))
	change_exposure(int(action.get("exposure", 0)))
	action_exposure = int(flags["exposure"]) - before_exposure
	for key in GameData.STAT_KEYS: action_delta[key] = int(stats[key]) - int(before[key])
	ration = int(action.get("ration", 0))
	_update_eligibility()
	_next_event()
	return true

func can_show(event: Dictionary) -> bool:
	var id: String = event["id"]
	if day_ids.has(id): return false
	var last_day := int(event.get("to_day", final_day - 1))
	if last_day == 19: last_day = final_day - 1
	if day < int(event.get("from_day", 2)) or day > last_day: return false
	if event.get("once", true) and shown.has(id): return false
	if shown.has(id) and day - int(shown[id]) < int(event.get("interval", 1)): return false
	if not GameData.matches(event.get("req", {}), stats, flags): return false
	var after: Dictionary = event.get("after", {})
	if not after.is_empty():
		if not shown.has(after["id"]) or day < int(shown[after["id"]]) + int(after["delay"]): return false
	# A pending seed enforces its minimum delay, even for ordinary pool candidates.
	for seed in pending:
		if seed["id"] == id and day < int(seed["due"]): return false
	if event.get("delayed_only", false) and not _is_due(id): return false
	return event.get("type") == "shopping" or not GameData.visible_options(event, stats, flags).is_empty()

func _is_due(id: String) -> bool:
	for seed in pending:
		if seed["id"] == id and day >= int(seed["due"]): return true
	return false

func _update_eligibility() -> void:
	for event in events:
		var id: String = event["id"]
		if can_show(event):
			if not eligible_since.has(id): eligible_since[id] = day
		else:
			eligible_since.erase(id)

func _priority(event: Dictionary) -> int:
	if event.has("deadline") and day >= int(event["deadline"]): return 100 + day - int(event["deadline"])
	if event.get("scheduled", false) and flags["duty"] and day >= duty_started + 3:
		var previous := int(shown.get("duty_routine", duty_started))
		if day >= previous + 3: return 80
	if _is_due(event["id"]) and (event.has("deadline") or event.get("delayed_only", false)): return 30
	return 0

func _pick(pool: String, urgent_only := false) -> Dictionary:
	var candidates: Array = []
	var best_priority := -1
	for event in events:
		if event.has("forced_days") or not can_show(event): continue
		if pool == "family" and event["pool"] != "family": continue
		if pool == "outside" and event["pool"] == "family": continue
		var priority := _priority(event)
		if urgent_only and priority < 80: continue
		if event.get("scheduled", false) and priority < 80: continue
		if priority < best_priority: continue
		if priority > best_priority:
			candidates.clear()
			best_priority = priority
		var candidate: Dictionary = event.duplicate()
		var weight := int(event.get("weight", 3))
		var wait_days := day - int(eligible_since.get(event["id"], day))
		if event.has("deadline") and wait_days >= 3: weight += (wait_days - 2) * 3
		if event.get("negative") == "family" and int(stats["mood"]) < 25: weight *= 3
		if event.get("negative") == "health": weight += int(flags["exposure"]) / 5
		if event.get("positive_community", false) and int(stats["harmony"]) >= 60: weight *= 2
		candidate["weight"] = weight
		candidates.append(candidate)
	if candidates.is_empty(): return {}
	return candidates[GameData.weighted_index(candidates, rng)]

func _next_event() -> void:
	current = {}
	options.clear()
	shop = {}
	if slots_used >= 2 or (day == final_day and slots_used >= 1):
		_settle_night()
		return
	if day == final_day:
		current = by_id["eve"].duplicate(true)
	else:
		var fixed: Array[Dictionary] = []
		for event in events:
			var fixed_today := false
			# JSON numbers are floats; Array.has uses strict Variant types.
			for fixed_day in event.get("forced_days", []):
				if int(fixed_day) == day: fixed_today = true
			if event["id"] != "eve" and fixed_today and can_show(event): fixed.append(event)
		fixed.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("fixed_order", 0)) < int(b.get("fixed_order", 0)))
		if not fixed.is_empty(): current = fixed[0]
	if current.is_empty():
		# On shopping days, slot B may be overridden by an overdue story/duty card.
		# All other days preserve A=outside, B=family; no third card is created.
		if slots_used == 1 and day_ids.has("ordering"): current = _pick("outside", true)
		if current.is_empty(): current = _pick("outside" if slots_used == 0 else "family")
	if current.is_empty():
		slots_used += 1
		_next_event()
		return
	current = current.duplicate(true)
	if current.get("special") == "rumor":
		current["truth"] = rng.randf() < 0.5
	if current.get("special") == "delivery_news":
		for seed in pending:
			if seed["id"] == "delivery_news" and day >= int(seed["due"]):
				var true_rumor: bool = seed.get("truth", false)
				current["desc"] = "配送人员确认：这次部分物资没能按原计划送齐，大家需要再匀一匀储备。" if true_rumor else "社区澄清了群里的消息：车辆只是调整了路线，物资照常配送。"
				current["options"][0]["effects"] = {"supplies": -5} if true_rumor else {"mood": 5}
				break
	if current.get("type") == "shopping": shop = GameData.shopping_items(current, flags, rng)
	else: options = GameData.visible_options(current, stats, flags)
	phase = Phase.EVENT

func choose(index: int) -> bool:
	if phase != Phase.EVENT or current.get("type") == "shopping" or index < 0 or index >= options.size(): return false
	var option: Dictionary = options[index].duplicate(true)
	var outcomes: Array = option.get("outcomes", [])
	if not outcomes.is_empty(): option.merge(outcomes[GameData.weighted_index(outcomes, rng)], true)
	var before := stats.duplicate()
	apply_effects(option.get("effects", {}))
	change_exposure(int(option.get("exposure", 0)))
	for key in option.get("set", {}):
		flags[key] = option["set"][key]
		if key == "duty" and flags[key]: duty_started = day
	for key in option.get("clear", []): flags[key] = false
	for key in option.get("add", {}): flags[key] = maxi(0, int(flags.get(key, 0)) + int(option["add"][key]))
	for key in option.get("metrics", {}): metrics[key] = int(metrics.get(key, 0)) + int(option["metrics"][key])
	ration = mini(2, ration + int(option.get("ration", 0)))
	for followup in option.get("followups", []): schedule(followup["id"], int(followup["delay"]))
	last_result = option.get("result", "")
	if current.get("special") == "rumor":
		if option.get("special") == "verify_rumor":
			for key in action_delta: stats[key] = clampi(int(stats[key]) - int(action_delta[key]), 0, 100)
			change_exposure(-action_exposure)
			if selected_action == "organize": ration = maxi(0, ration - 1)
			last_result += "\n今天主动行动的收益已用于核实消息。\n"
			last_result += "配送人员确认部分物资可能不足，留一些储备会更稳妥。" if current["truth"] else "配送人员确认只是改了路线，物资会照常送到。"
			schedule("delivery_news", 2, {"truth": current["truth"]})
		else:
			schedule("delivery_news", 2, {"truth": current["truth"]})
	if option.has("record"): record(option["record"], current["id"])
	_finish_choice(before, option.get("label", ""))
	return true

func purchase(ids: Array) -> bool:
	if phase != Phase.EVENT or current.get("type") != "shopping" or ids.size() != int(shop.get("choose", 0)): return false
	var selected: Array = []
	for id in ids:
		if selected.has(id): return false
		var found := false
		for item in shop["items"]:
			if item["id"] == id: found = true
		if not found: return false
		selected.append(id)
	var before := stats.duplicate()
	apply_effects(current.get("purchase_effects", {"supplies": 10}))
	var names: Array[String] = []
	for item in shop["items"]:
		if not selected.has(item["id"]): continue
		apply_effects(item.get("eff", {}))
		names.append(item["name"])
		if item.has("counter"):
			var key: String = item["counter"]
			flags[key] = int(flags.get(key, 0)) + 1
	last_result = "接龙已完成：%s。\n%s" % ["、".join(names), current.get("result_after", "")]
	_finish_choice(before, "、".join(names))
	return true

func _finish_choice(before: Dictionary, label: String) -> void:
	var id: String = current["id"]
	shown[id] = day
	day_ids.append(id)
	history.append({"day": day, "id": id, "choice": label})
	pending = pending.filter(func(seed: Dictionary) -> bool: return seed["id"] != id)
	eligible_since.erase(id)
	slots_used += 1
	last_changes = changes_text(before)
	phase = Phase.RESULT

func continue_run() -> bool:
	match phase:
		Phase.RESULT:
			_next_event()
		Phase.NIGHT:
			if not ending.is_empty(): phase = Phase.RECAP
			else:
				day += 1
				slots_used = 0
				day_ids.clear()
				selected_action = ""
				action_delta.clear()
				ration = 0
				phase = Phase.MORNING
		Phase.RECAP:
			phase = Phase.ENDING
		_:
			return false
	return true

func _settle_night() -> void:
	var before := stats.duplicate()
	var consumption := maxi(1, 3 - ration)
	apply_effects({"supplies": -consumption})
	night_text = "一家四口的日常消耗：物资 -%d。" % consumption
	if int(stats["supplies"]) < 25:
		apply_effects({"mood": -1})
		night_text += "\n储备不多了，心情 -1。"
	if flags["duty"]: metrics["duty_days"] += 1
	if int(flags["exposure"]) > 0 and rng.randf() < float(flags["exposure"]) / 180.0:
		apply_effects({"immunity": -5})
		night_text += "\n最近的奔波让身体感到疲惫，免疫力 -5。"
	change_exposure(-3)
	last_changes = changes_text(before)
	if int(stats["immunity"]) <= 0 or int(stats["mood"]) <= 0 or int(stats["supplies"]) <= 0 or day == final_day:
		ending = GameData.compute_ending(stats, flags)
	phase = Phase.NIGHT

func apply_effects(effects: Dictionary) -> void:
	var body := int(stats["immunity"])
	for key in GameData.STAT_KEYS:
		var raw := int(effects.get(key, 0))
		var delta := GameData.scale_delta(raw, body) if raw < 0 else raw
		stats[key] = clampi(int(stats[key]) + delta, 0, 100)

func change_exposure(delta: int) -> void:
	flags["exposure"] = clampi(int(flags["exposure"]) + delta, 0, 100)

func schedule(id: String, delay: int, payload: Dictionary = {}) -> void:
	if not by_id.has(id):
		push_error("Unknown followup: " + id)
		return
	if by_id[id].get("once", true) and shown.has(id): return
	for seed in pending:
		if seed["id"] == id: return
	var seed := {"id": id, "due": day + maxi(1, delay)}
	seed.merge(payload)
	pending.append(seed)
	# Late main-story consequences get their own day before the epilogue.
	# Optional recurring flavor seeds do not keep a run alive indefinitely.
	if by_id[id].has("deadline") and int(seed["due"]) >= final_day - 1:
		final_day = int(seed["due"]) + 2
		by_id[id]["deadline"] = final_day - 1
		by_id[id]["to_day"] = final_day - 1

func record(text: String, id: String) -> void:
	journal.append({"day": day, "text": text, "id": id})

func changes_text(before: Dictionary) -> String:
	var parts: Array[String] = []
	for key in GameData.STAT_KEYS:
		var delta := int(stats[key]) - int(before[key])
		if delta != 0: parts.append("%s %s%d" % [GameData.STAT_DEFS[key]["name"], "+" if delta > 0 else "", delta])
	return " · ".join(parts) if not parts.is_empty() else "今天的选择，未必马上有回声。"

func morning_news() -> String:
	var official: String
	if day == 1: official = "社区通知 · 小区开始封闭管理，请居民留在家中。"
	elif day < 7: official = "社区通知 · 生活物资由社区组织接龙，下一轮请留意群消息。"
	elif day < 10: official = "社区通知 · 出入管理更加严格，党员突击队开始组织值守。"
	elif day < final_day: official = "社区通知 · 志愿者正在分拣和运送生活物资，请错峰领取。"
	else: official = "社区通知 · 大家开始为恢复日常生活做准备。"
	var life := ["生活消息 · 对面阳台多了一床晒着的被子。", "群聊闲话 · 有人分享了电饭煲做蛋糕的方法。", "未证实的消息 · 群里说会有新鲜蔬菜送来，品种还不确定。", "生活消息 · 孩子们的老师又换了一种上课软件。"]
	var tier := GameData.health_tier(int(stats["immunity"]))
	var health := "\n身体感受 · %s（免疫力 %d）" % [tier["name"], int(stats["immunity"])]
	if float(tier["multiplier"]) > 1.5:
		health += "\n负面事件对你的冲击会被放大（×%s）。" % str(tier["multiplier"])
	return official + "\n" + life[(day - 1) % life.size()] + health

func recap_text() -> String:
	var text := "走过 %d 天\n参与社区值守：%d 天（完成 %d 次轮班）\n物资志愿工作：%s\n帮助邻居：%d 次 · 向社区求助：%d 次\n与儿子真正谈心：%s\n儿子的学业危机：%s\n女儿主动向你求助：%s\n" % [day, metrics["duty_days"], metrics["duty_shifts"], "是" if flags["community_volunteer"] else "否", metrics["neighbors_helped"], metrics["help_requests"], "是" if flags["talk_with_son"] else "否", "已经解决" if flags["son_perfect"] else "仍有没说完的话", "是" if flags["good_father"] else "还没有"]
	text += "\n最终状态\n"
	for key in GameData.STAT_KEYS: text += "%s %d  " % [GameData.STAT_DEFS[key]["name"], stats[key]]
	text += "\n\n过去种下的东西\n"
	for entry in journal.slice(maxi(0, journal.size() - 5)):
		text += "第 %d 天 · %s\n\n" % [entry["day"], entry["text"]]
	if flags["return_gift"]: text += "那条鱼和后来的回礼，让楼上楼下有了往来。"
	elif int(stats["harmony"]) >= 60: text += "走出门时，你已经认得几位邻居。"
	else: text += "窗外还有很多陌生的窗口，日子还会继续。"
	return text
