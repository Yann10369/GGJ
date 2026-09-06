extends RefCounted
class_name GameData

## 封城三十天 · 防疫成长（对齐 v2 规范化设计稿 + 事件.docx 最新指导）
## 四维：心情 / 免疫力 / 物资 / 和睦（初始均 30，范围 0~100）
## 计数：鸡蛋 / 热干面（int，接龙 +1，消耗 -1，初值 0）
## 旗标：crisis / talked / duty / volunteer / account(初始1) / romance / good_dad
##       son_perfect / test_good / revive / duty_start（大部分开关初始 0）
##
## 事件四池分别由 data/{fixed,community,family,neighborhood}/events.gd 管理：
##   固定 PoolFixed / 社区 PoolCommunity / 家庭 PoolFamily / 邻里 PoolNeighborhood
##
## 数值幅度：+5/+10/+15... 直接写在 effects 里（clamp 0~100）
## 概率：低=2 中=3 高=5（条件不满足即权 0，退出竞争）；固定池现仅日期强制/状态触发，无独立概率事件（chance 机制已取消）
##
## 事件选项结构：
##   dir: "up" | "left" | "right"（由 active_options 按动态选项数自动分配，事件代码不写 dir）
##   art: 选项自己的配图（空 = 留白，预留字段方便批量导入）
##   label / effects / set / dec(计数增减) / result / cond(选项级显示条件) / alt(按状态替换)
## 事件字段 art：仅作为事件卡（描述）的背景图，不再服务整个事件。

const STAT_KEYS: Array[String] = ["mood", "immunity", "supplies", "harmony"]

const STAT_DEFS: Dictionary = {
	"mood":     {"name": "心情",   "color": Color("#e0a33e")},
	"immunity": {"name": "免疫力", "color": Color("#4dbf7e")},
	"supplies": {"name": "物资",   "color": Color("#4f8fd0")},
	"harmony":  {"name": "和睦",   "color": Color("#d96a72")},
}

## 各池主色调（固定=灰 / 家庭=暖黄 / 邻里=天蓝 / 社区=大红）
const CAT_COLORS: Dictionary = {
	"固定": Color("#9aa0b0"),
	"家庭": Color("#e0a33e"),
	"邻里": Color("#4f8fd0"),
	"社区": Color("#d96a72"),
}
const NEUTRAL_COLOR := Color("#c9b27a")

## 事件四池（data/<pool>/events.gd；用 preload 避免 class_name 缓存时序问题）
const _POOL_FIXED := preload("res://data/fixed/events.gd")
const _POOL_COMMUNITY := preload("res://data/community/events.gd")
const _POOL_FAMILY := preload("res://data/family/events.gd")
const _POOL_NEIGHBORHOOD := preload("res://data/neighborhood/events.gd")
const _SETTLEMENT_TIPS := preload("res://data/settlement_tips.gd")

const POOLS: Dictionary = {
	"固定": _POOL_FIXED.EVENTS,
	"社区": _POOL_COMMUNITY.EVENTS,
	"家庭": _POOL_FAMILY.EVENTS,
	"邻里": _POOL_NEIGHBORHOOD.EVENTS,
}

## 全部事件（四池汇总）
static func all_events() -> Array:
	var out: Array = []
	for cat in POOLS:
		for e: Dictionary in POOLS[cat]:
			out.append(e)
	return out

## 接龙采购：全部物资主列表（共 9 种）。每次显示 n 个、玩家选 m 个。
const SHOP_MASTER: Array[Dictionary] = [
	{"id": "meat",    "name": "肉类",          "eff": {"immunity": 5}, "weight": 3},
	{"id": "fruit",   "name": "外地捐赠水果",  "eff": {"immunity": 5}, "weight": 3},
	{"id": "greens",  "name": "绿叶菜",        "eff": {"immunity": 5}, "weight": 2},
	{"id": "milk",    "name": "牛奶",          "eff": {"immunity": 5}, "weight": 2},
	{"id": "egg",     "name": "鸡蛋",          "eff": {"immunity": 5}, "counter": "eggs", "weight": 3},
	{"id": "potato",  "name": "土豆花菜",      "weight": 5},
	{"id": "cabbage", "name": "大白菜白萝卜",  "weight": 5},
	{"id": "staple",  "name": "基础米面粮油",  "weight": 5},
	{"id": "noodles", "name": "热干面便携4包装", "counter": "noodles", "weight": 2},
]

const INITIAL: Dictionary = {"mood": 30, "immunity": 30, "supplies": 30, "harmony": 30}
const TOTAL_DAYS := 14

static func initial_stats() -> Dictionary:
	return INITIAL.duplicate()

static func initial_flags() -> Dictionary:
	return {"eggs": 0, "noodles": 0, "duty_start": 0, "crisis": false, "talked": false,
		"duty": false, "volunteer": false, "account": true, "romance": false,
		"good_dad": false, "son_perfect": false, "test_good": false, "revive": false,
		"exchange": false, "burden": false, "duty_done": false}

static func cat_color(cat: String) -> Color:
	return CAT_COLORS.get(cat, NEUTRAL_COLOR)

## 某天强制出现的事件（固定池日期强制，跳过已显示的 once 事件）
static func forced_for_day(day: int, shown: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for e: Dictionary in POOLS["固定"]:
		var fd = e.get("forced_days", [])
		if fd is Array and (fd as Array).has(day):
			if not (e.get("once", false) and shown.get(e["id"], false)):
				result.append(e)
	return result

## 固定池现仅日期强制 / 状态触发，无独立概率事件（chance 机制已取消）。

## 条件是否满足（flags / max_stats / min_stats / max_stats_any / min_flags / any(或)）
static func _req_ok(req: Dictionary, stats: Dictionary, flags: Dictionary, day: int) -> bool:
	if req.has("flags"):
		for k in req["flags"]:
			if bool(flags.get(k, false)) != bool(req["flags"][k]):
				return false
	if req.has("max_stats"):
		for k in req["max_stats"]:
			if int(stats.get(k, 0)) > int(req["max_stats"][k]):
				return false
	if req.has("min_stats"):
		for k in req["min_stats"]:
			if int(stats.get(k, 0)) < int(req["min_stats"][k]):
				return false
	if req.has("max_stats_any"):
		var any_ok := false
		for k in req["max_stats_any"]:
			if int(stats.get(k, 0)) <= int(req["max_stats_any"][k]):
				any_ok = true
		if not any_ok:
			return false
	if req.has("min_flags"):
		for k in req["min_flags"]:
			if int(flags.get(k, 0)) < int(req["min_flags"][k]):
				return false
	if req.has("any"):
		var ok := false
		for cond in req["any"]:
			if _req_ok(cond, stats, flags, day):
				ok = true
		if not ok:
			return false
	return true

## 事件当前是否满足出现条件
static func can_show(event: Dictionary, stats: Dictionary, flags: Dictionary, shown: Dictionary, day: int) -> bool:
	if event.get("once", false) and shown.get(event["id"], false):
		return false
	if event.has("from_day") and day < int(event["from_day"]):
		return false
	if event.has("stop_flag") and bool(flags.get(event["stop_flag"], false)):
		return false
	if event.has("scheduled") and bool(event["scheduled"]):
		return false
	if not event.has("req"):
		return true
	return _req_ok(event["req"], stats, flags, day)

## 选项当前是否显示（选项级条件；无条件则恒显）
static func option_enabled(opt: Dictionary, stats: Dictionary, flags: Dictionary, day: int) -> bool:
	if not opt.has("cond"):
		return true
	return _req_ok(opt["cond"], stats, flags, day)

## 动态选项数：事件传入时调用。
## 1) 过滤 cond 不满足的选项，得到可用选项列表（保持定义顺序）；
## 2) 按可用选项数分配最终呈现/滑动方向（方向完全由这里决定，事件代码不写 dir）：
##    1 个 → 上；2 个 → 左/右；3 个 → 左/上/右；
## 返回的数组中每个选项的 dir 已是最终呈现/滑动方向，与卡牌显示的左/上/右槽位一致。
## 取舍说明：直接在此筛选后只把可用选项传给卡牌（卡牌保持纯展示，逻辑集中在 GameData）。
static func active_options(ev: Dictionary, stats: Dictionary, flags: Dictionary, day: int) -> Array:
	var usable: Array = []
	for o: Dictionary in ev.get("options", []):
		if option_enabled(o, stats, flags, day):
			usable.append(o)
	var count := usable.size()
	if count <= 0:
		return usable
	var slots: Array[String] = []
	match count:
		1: slots = ["up"]
		2: slots = ["left", "right"]
		3: slots = ["left", "up", "right"]
		_: slots = ["left", "up", "right"]
	var out: Array = []
	for i in usable.size():
		var c: Dictionary = usable[i].duplicate(true)
		# 选项按状态切换配图（如「求助 t2」：和睦达标才显示）
		if c.has("alt") and _alt_matches(c["alt"], stats, flags) and (c["alt"] as Dictionary).has("art"):
			c["art"] = c["alt"]["art"]
		c["dir"] = slots[i]
		out.append(c)
	return out

## 从指定牌池按权重抽一个（exclude 内的 id 不参与；强制/排程/固定池概率事件不参与）
static func pick_event(last_id: String, stats: Dictionary, flags: Dictionary, shown: Dictionary, day: int, cat_filter := "", exclude: Array = []) -> Dictionary:
	var cands: Array[Dictionary] = []
	for e: Dictionary in POOLS.get(cat_filter, []):
		var fd = e.get("forced_days", [])
		if fd is Array and fd.size() > 0:
			continue
		if bool(e.get("scheduled", false)):
			continue
		if e.has("chance"):
			continue
		if e["id"] in exclude:
			continue
		if e["id"] == last_id:
			continue
		if not can_show(e, stats, flags, shown, day):
			continue
		cands.append(e)
	if cands.is_empty():
		for e: Dictionary in POOLS.get(cat_filter, []):
			if bool(e.get("scheduled", false)) or e.has("chance"):
				continue
			if e["id"] in exclude or e["id"] == last_id:
				continue
			if not can_show(e, stats, flags, shown, day):
				continue
			cands.append(e)
	var total := 0
	for e in cands:
		total += int(e.get("weight", 3))
	var r := randi() % maxi(1, total)
	for e in cands:
		var w := int(e.get("weight", 3))
		if r < w:
			return e
		r -= w
	return cands[0] if not cands.is_empty() else {}

## alt 分支条件是否命中（旗标 / 状态阈值）
static func _alt_matches(alt: Dictionary, flags: Dictionary, stats: Dictionary) -> bool:
	var matched := true
	if alt.has("flag"):
		matched = matched and (bool(flags.get(alt.get("flag", ""), false)) == bool(alt.get("flag_value", true)))
	if alt.has("min_stats"):
		for k in alt["min_stats"]:
			if int(stats.get(k, 0)) < int(alt["min_stats"][k]):
				matched = false
	if alt.has("max_stats"):
		for k in alt["max_stats"]:
			if int(stats.get(k, 0)) > int(alt["max_stats"][k]):
				matched = false
	return matched

## 解析选项的实际生效版本（应用 alt 覆盖：旗标 / 状态阈值）
static func resolve_option(opt: Dictionary, flags: Dictionary, stats: Dictionary = {}) -> Dictionary:
	if not opt.has("alt"):
		return opt
	var alt: Dictionary = opt["alt"]
	if not _alt_matches(alt, flags, stats):
		return opt
	var merged: Dictionary = opt.duplicate(true)
	for k in ["effects", "set", "dec", "result", "label"]:
		if alt.has(k):
			merged[k] = alt[k]
	return merged

## 接龙采购：返回全部物资主列表（9 种）的副本
static func shopping_master() -> Array[Dictionary]:
	return SHOP_MASTER.duplicate(true)

## 接龙采购：按旗标决定“显示数量 n”与“需选数量 m”
##   非志愿者：显示 5 选 3；志愿者：显示 7 选 4
static func shopping_params(flags: Dictionary) -> Dictionary:
	var vol := bool(flags.get("volunteer", false))
	return {"show": 7 if vol else 5, "choose": 4 if vol else 3}

## 结局判定已迁移至 data/endings.gd（GameEndings.judge），结局以卡片形式替换结算卡

## 结算提示：结算卡未触发结局时，在五个池（你/妻子/儿子/女儿/局势）中
## 各自排除未达成条件的条目，剩下等概率随机选一条，按池顺序逐行输出。
static func settlement_tips(stats: Dictionary, flags: Dictionary) -> String:
	var pools: Dictionary = {}
	for e: Dictionary in _SETTLEMENT_TIPS.POOLS:
		if not _req_ok(e["cond"], stats, flags, 0):
			continue
		var p := str(e["pool"])
		if not pools.has(p):
			pools[p] = []
		(pools[p] as Array).append(str(e["text"]))
	var lines: Array[String] = []
	for p: String in _SETTLEMENT_TIPS.ORDER:
		if not pools.has(p):
			continue
		var cands: Array = pools[p]
		lines.append(str(cands[randi() % cands.size()]))
	return "\n".join(lines)
