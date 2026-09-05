extends RefCounted
class_name GameData

## JSON is the single source of story data; these rules are shared by UI and session.
const TOTAL_DAYS := 20
const STAT_KEYS: Array[String] = ["mood", "harmony", "immunity", "supplies"]
const INITIAL := {"mood": 60, "harmony": 40, "immunity": 70, "supplies": 55}
const STAT_DEFS := {
	"mood": {"name": "心情", "color": Color("#e0a33e")},
	"harmony": {"name": "和睦", "color": Color("#d96a72")},
	"immunity": {"name": "免疫力", "color": Color("#4dbf7e")},
	"supplies": {"name": "物资", "color": Color("#4f8fd0")},
}
const ACTIONS := [
	{"id": "rest", "label": "休息", "hint": "免疫力 +5 · 放慢一天", "effects": {"immunity": 5}, "exposure": -10},
	{"id": "family", "label": "陪伴家人", "hint": "心情 +5 · 留一点时间", "effects": {"mood": 5}, "exposure": -5},
	{"id": "community", "label": "联系社区", "hint": "和睦 +5 · 问候邻里", "effects": {"harmony": 5}},
	{"id": "organize", "label": "整理物资", "hint": "今晚物资消耗降为 2", "effects": {}, "ration": 1, "exposure": -5},
]
## Body tiers in the 0–100 immunity range. Below 0 the ending fires before apply_effects runs again.
## Negative effect deltas are scaled by `multiplier`; positive ones are untouched.
const HEALTH_TIERS: Array[Dictionary] = [
	{"min": 80, "name": "状态很好", "multiplier": 1.0},
	{"min": 60, "name": "状态良好", "multiplier": 1.2},
	{"min": 40, "name": "有些疲惫", "multiplier": 1.5},
	{"min": 20, "name": "明显疲惫", "multiplier": 2.0},
	{"min": 1,  "name": "身体不适", "multiplier": 3.0},
]

static func health_tier(immunity: int) -> Dictionary:
	for tier in HEALTH_TIERS:
		if immunity >= int(tier["min"]): return tier
	return {"min": 0, "name": "倒下", "multiplier": 0.0}

## Scale a delta by the body's current tier. Only negative values are amplified; positive ones pass through.
static func scale_delta(delta: int, immunity: int) -> int:
	if delta >= 0: return delta
	return int(round(float(delta) * float(health_tier(immunity)["multiplier"])))

static func initial_stats() -> Dictionary:
	return INITIAL.duplicate()

static func initial_flags() -> Dictionary:
	return {"account": true, "romance": false, "talk_with_son": false,
		"son_study_crisis": false, "online_test_good": false, "son_perfect": false,
		"duty": false, "community_volunteer": false, "egg": 0, "hot_dry_noodle": 0,
		"help_neighbor": false, "received_help": false, "return_gift": false,
		"good_father": false, "exposure": 0}

## Unknown keys fail closed: a typo cannot unlock a story branch.
static func matches(req: Dictionary, stats: Dictionary, flags: Dictionary) -> bool:
	for field in req:
		match field:
			"flags":
				for key in req[field]:
					if not flags.has(key) or flags[key] != req[field][key]: return false
			"min_flags", "min_stats", "max_stats":
				var source: Dictionary = flags if field == "min_flags" else stats
				for key in req[field]:
					if not source.has(key): return false
					if field == "max_stats":
						if int(source[key]) > int(req[field][key]): return false
					elif int(source[key]) < int(req[field][key]): return false
			"any":
				var found := false
				for sub in req[field]: found = found or matches(sub, stats, flags)
				if not found: return false
			"all":
				for sub in req[field]:
					if not matches(sub, stats, flags): return false
			"not":
				if matches(req[field], stats, flags): return false
			_:
				return false
	return true

static func visible_options(event: Dictionary, stats: Dictionary, flags: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for option in event.get("options", []):
		if matches(option.get("requires", {}), stats, flags): result.append(option)
	return result

static func resolve_option(option: Dictionary, _flags: Dictionary = {}) -> Dictionary:
	return option

static func weighted_index(items: Array, rng: RandomNumberGenerator) -> int:
	var total := 0
	for item in items: total += maxi(1, int(item.get("weight", 3)))
	var roll := rng.randi_range(0, maxi(1, total) - 1)
	for i in items.size():
		roll -= maxi(1, int(items[i].get("weight", 3)))
		if roll < 0: return i
	return -1

static func shopping_items(event: Dictionary, flags: Dictionary, rng: RandomNumberGenerator = null) -> Dictionary:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var chosen: Dictionary = event["variants"][0]
	for variant in event["variants"]:
		if matches({"flags": variant.get("when", {})}, {}, flags):
			chosen = variant
			break
	var remaining: Array = chosen["pool"].duplicate(true)
	var picks: Array[Dictionary] = []
	for i in mini(int(chosen["offer"]), remaining.size()):
		picks.append(remaining.pop_at(weighted_index(remaining, rng)))
	return {"choose": int(chosen["choose"]), "items": picks}

static func compute_ending(stats: Dictionary, flags: Dictionary) -> Dictionary:
	if int(stats["immunity"]) <= 0:
		return {"id": "hospital", "title": "需要医院", "text": "刚开始儿子病倒了，然后是妻子和女儿。我本来以为自己会是一个无症状感染者，直到我烧到 40 度。我对不起他们，是我带来的病毒。我们在社区志愿者的帮助下进入了方舱医院，被拆分到不同地方。我要赶紧好起来，然后见他们。"}
	if int(stats["mood"]) <= 0:
		var story: String
		if not flags.get("son_perfect", false):
			story = "他在哪？一个夜里，儿子打开了门，然后再也没回来。没人知道他是怎么做到的，那么多监控和卡口管理人员。妻子每天都在哭。我们想他。"
		elif not flags.get("good_father", false):
			story = "她在哪？我们以为女儿是最省心的，但是疫情后，她离开了，连句道别都没留。妻子每天都在哭。我们想她。"
		else:
			story = "我可能不是一个称职的父亲。前妻在女儿高考后跟我离婚，我带走没成年的儿子，而她们一起离开了。儿子还在上高中，我需要支撑下去。"
		return {"id": "leave", "title": "离开", "text": story}
	if int(stats["supplies"]) <= 0:
		return {"id": "aid", "title": "还好有政府", "text": "勉强度日。我们被当做了困难家庭，获得了街道网格员和其他下沉党员的免费援助。大家顿顿都有吃的了，但也没心思再去想任何事。"}
	if flags.get("duty", false) and flags.get("son_perfect", false) and flags.get("good_father", false):
		return {"id": "grown", "title": "在结束的那一天", "text": "平平安安。当病毒的雾霾散去，你在短暂的喜悦后，更感到的是如释重负。妻子在给所有认识的朋友报平安，孩子们则更忧心即将到来的回堂测试。这个家庭没有被天灾打倒。你其实也没有多少感触，想起沉重的新闻，沉重的话题，沉重的防护服，你其实很惊讶自己扛下来了，湖北扛下来了，中国扛下来了。你对未来一无所知：这个家庭的未来是怎样的？病毒还会回来吗？这道横亘在人类历史上的深重创口，真的还会弥合吗？你不知道。不过，在以后，每当你回想起这段岁月，你也是抗疫一线基层防线一个英勇的标点，你就感到——热泪盈眶。"}
	return {"id": "steady", "title": "平庸却坚定", "text": "这就够了。疫情见证了我们家庭的努力，谁都没有被打倒。我们对未来充满期望。"}
