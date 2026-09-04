extends RefCounted
class_name GameData

## 主题：封城十四天 · 防疫成长
## 四维属性：心情 / 免疫力 / 物资 / 和睦
## 旗标：eggs（家里有鸡蛋）/ crisis（小儿子学业危机）/ talked（已与儿子谈心）

const STAT_KEYS: Array[String] = ["mood", "immunity", "supplies", "harmony"]

const STAT_DEFS: Dictionary = {
	"mood":     {"name": "心情",   "color": Color("#e0a33e")},
	"immunity": {"name": "免疫力", "color": Color("#4dbf7e")},
	"supplies": {"name": "物资",   "color": Color("#4f8fd0")},
	"harmony":  {"name": "和睦",   "color": Color("#d96a72")},
}

const INITIAL: Dictionary = {"mood": 60, "immunity": 62, "supplies": 56, "harmony": 65}

const TOTAL_DAYS := 14

## 每个事件的字典字段：
##   id, cat, title, art, desc, weight, first (可选)
##   left / right：{label, effects:{stat:int}, set:{flag:bool}, result:str, alt(可选):{flag,flag_value,effects,result}}
##   req (可选)：{flags:{k:v}, max_stats:{k:v}, min_stats:{k:v}} —— 满足才可出现
const EVENTS: Array[Dictionary] = [
	{
		"id": "lockdown", "cat": "封控", "title": "封城", "art": "lock",
		"desc": "深夜通知突然下发，小区封控管理。楼下的铁门落了锁，一家人的居家生活，从今天开始。",
		"first": true, "weight": 0,
		"left": {
			"label": "抢购物资",
			"effects": {"supplies": 24, "mood": -8, "immunity": -6},
			"result": "你赶在封控前冲进超市，粮油米面塞满了后备箱。可回来路上，听说邻居已经先抢空了货架。",
		},
		"right": {
			"label": "安顿全家",
			"effects": {"mood": 10, "immunity": 6, "supplies": -4, "harmony": 6},
			"result": "一家人在餐桌前开了个小会，把工作、学习、做饭排了个班。心里有了数，日子就没那么慌。",
		},
	},
	{
		"id": "talk", "cat": "家庭", "title": "谈心", "art": "talk",
		"desc": "孩子贪玩是天性，作为父亲，你要负好责任。你打开小儿子的房门。",
		"weight": 5,
		"left": {
			"label": "跟他说清楚利害",
			"effects": {"mood": -8, "harmony": -4},
			"set": {"crisis": false},
			"result": "你口干舌燥，也不知道他听进去多少。本来想结合他的未来用心教育一下，最后变成一场说教。",
		},
		"right": {
			"label": "结合自身经验讲讲",
			"effects": {"mood": 8, "harmony": 6},
			"set": {"crisis": false, "talked": true},
			"result": "你告诉儿子，虽然他还小，但已经是一个男人了。结合自己多年的经历，希望儿子能明白。父亲不善言辞，但你是个善于沟通的爸爸。",
		},
	},
	{
		"id": "hanger", "cat": "家庭", "title": "给他脸了", "art": "hanger",
		"desc": "小兔崽子天天不学好，一进来发现他又在打游戏！你实在忍不下去了。",
		"weight": 4,
		"left": {
			"label": "按住火气",
			"effects": {"mood": 4, "harmony": 6},
			"set": {"crisis": true},
			"result": "你把游戏关了，平静地告诉他先去做作业。儿子不太情愿，但最后还是去了。",
		},
		"right": {
			"label": "家法伺候",
			"effects": {"mood": -14, "harmony": -10},
			"set": {"crisis": false},
			"result": "家里开始了一场棍棒教育，鸡飞狗跳的整层楼都能听到。事后你心里也有点后悔。",
		},
	},
	{
		"id": "cake", "cat": "家庭", "title": "蛋糕", "art": "cake",
		"desc": "妻子用矿泉水瓶做成的简易打蛋器配合电饭煲，做出了封城以来家里第一顿零嘴。",
		"weight": 8, "req": {"flags": {"eggs": true}},
		"left": {
			"label": "端给赌气的儿子",
			"effects": {"mood": 14, "supplies": -8, "immunity": 6},
			"set": {"crisis": true, "eggs": false},
			"result": "今晚不在乎网课、考勤和线上测试，只是疫情中彼此依偎的家庭。",
		},
		"right": {
			"label": "每个人有份",
			"effects": {"mood": 8, "immunity": 6, "harmony": 4},
			"set": {"eggs": false},
			"result": "打蛋清真的很麻烦，在没有合适道具的情况下。但大家分工合作，成果属于每个人。",
		},
	},
	{
		"id": "test", "cat": "学业", "title": "线上测试", "art": "test",
		"desc": "搞什么？小儿子平时全校 30 名以内，这次线上测试直接掉到了 150 名开外。妻子急得不知道怎么办。",
		"weight": 9, "req": {"flags": {"crisis": true}},
		"left": {
			"label": "没收设备，全程陪同",
			"effects": {"mood": -6, "harmony": -4},
			"set": {"crisis": false},
			"result": "儿子意见很大，但是这是为了他好。",
		},
		"right": {
			"label": "询问事情原委",
			"effects": {"mood": 10, "harmony": 2, "supplies": -4, "immunity": 4},
			"set": {"crisis": false},
			"result": "儿子已经努力学习了，线上监考没经验，几乎所有题目都能搜到。所有人的成绩都不正常。",
			"alt": {
				"flag": "talked", "flag_value": true,
				"effects": {"mood": 18, "harmony": 8, "supplies": -4, "immunity": 4},
				"result": "他什么都没有做错。仔细看了看成绩表，几乎所有人的分数都不正常。一家人晚上吃了一顿好的，其乐融融。",
			},
		},
	},
	{
		"id": "help_low", "cat": "邻里", "title": "求助", "art": "phone",
		"desc": "女儿正是长身体的时候，却越来越容易累。或许我们需要一顿像样的饭。",
		"weight": 7,
		"req": {"max_stats": {"harmony": 59, "supplies": 49}},
		"left": {
			"label": "在群里求助",
			"effects": {"mood": -8, "harmony": -2},
			"result": "你在社区群里问了问，可消息很快就被接龙刷过去了。过了一天，仍没有任何回应。",
		},
		"right": {
			"label": "物资短缺总要适应",
			"effects": {"mood": 4},
			"result": "妻子给土豆换了换花样，用土豆泥，我们又敷衍了一顿。",
		},
	},
	{
		"id": "help_high", "cat": "邻里", "title": "求助", "art": "phone",
		"desc": "女儿正是长身体的时候，却越来越容易累。或许我们需要一顿像样的饭。",
		"weight": 7,
		"req": {"max_stats": {"supplies": 49}, "min_stats": {"harmony": 60}},
		"left": {
			"label": "在群里求助",
			"effects": {"mood": 14, "immunity": 14, "harmony": -2, "supplies": 4},
			"result": "18 楼的住户很快回信了。他们家把一条鲫鱼放在了门口。汤很鲜美，看到女儿脸颊浮现出久违的笑容。",
		},
		"right": {
			"label": "物资短缺总要适应",
			"effects": {"mood": 4},
			"result": "妻子给土豆换了换花样，用土豆泥，我们又敷衍了一顿。",
		},
	},
	{
		"id": "fish", "cat": "邻里", "title": "回礼", "art": "fish",
		"desc": "上次的鱼汤女儿很喜欢。你想送点什么当回礼。",
		"weight": 6, "req": {"min_stats": {"harmony": 65}},
		"left": {
			"label": "送一份小礼物",
			"effects": {"supplies": -6, "harmony": 6, "mood": 8},
			"result": "你找了点家里多余的干货放在 18 楼门口。",
		},
		"right": {
			"label": "默默记下",
			"effects": {"mood": 2, "supplies": -2},
			"result": "你在心里记下了这份人情，想着解封后一定要好好谢人家。",
		},
	},
	{
		"id": "online_visit", "cat": "事业", "title": "线上家访", "art": "father",
		"desc": "儿子的班主任打来视频通话。家里有点慌。",
		"weight": 4,
		"left": {
			"label": "安静地接听",
			"effects": {"mood": 4, "harmony": 2, "supplies": -2},
			"result": "你接了电话，老师简单问了问情况。",
		},
		"right": {
			"label": "认真准备",
			"effects": {"mood": -4, "supplies": -4, "immunity": 2},
			"result": "你提前准备了材料和说辞，和老师聊了半小时。",
		},
	},
	{
		"id": "ledger", "cat": "家庭", "title": "妻子的账本", "art": "mother",
		"desc": "妻子在厨房里翻账本，已经算到封控后第 12 天了。",
		"weight": 4,
		"left": {
			"label": "重新算一遍",
			"effects": {"mood": -4, "harmony": 2},
			"result": "你又算了一遍，发现妻子记漏了几笔。",
		},
		"right": {
			"label": "两人分工记账",
			"effects": {"mood": 6, "harmony": 6, "supplies": -2},
			"result": "你们把家里能省的和必须花的都列了一遍。心里有底。",
		},
	},
	{
		"id": "late_night", "cat": "家庭", "title": "深夜的粥", "art": "mother2",
		"desc": "封控久了，夜里总睡不踏实。厨房还有半袋米。",
		"weight": 4,
		"left": {
			"label": "给孩子熬锅粥",
			"effects": {"mood": 8, "harmony": 4, "immunity": 4},
			"result": "凌晨两点，厨房的灯亮着，米香飘满了楼道。",
		},
		"right": {
			"label": "早休息",
			"effects": {"immunity": 8},
			"result": "你强迫自己躺回去。明天还有很多事要做。",
		},
	},
]

static func initial_stats() -> Dictionary:
	return INITIAL.duplicate()

static func initial_flags() -> Dictionary:
	return {"eggs": true, "crisis": false, "talked": false}

## 当前统计/旗标下，某事件是否可出现
static func can_show(event: Dictionary, stats: Dictionary, flags: Dictionary) -> bool:
	if not event.has("req"):
		return true
	var req: Dictionary = event["req"]
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
	return true

## 按权重抽一个不与上一次相同、且满足条件的事件
static func pick_event(last_id: String, stats: Dictionary, flags: Dictionary) -> Dictionary:
	var candidates: Array[Dictionary] = []
	for c in EVENTS:
		if c["id"] == last_id:
			continue
		if not can_show(c, stats, flags):
			continue
		candidates.append(c)
	if candidates.is_empty():
		for c in EVENTS:
			if c["id"] != last_id:
				candidates.append(c)
	var total := 0
	for c in candidates:
		total += int(c.get("weight", 1))
	var r := randi() % maxi(1, total)
	for c in candidates:
		var w := int(c.get("weight", 1))
		if r < w:
			return c
		r -= w
	return candidates[0]

## 抽取一个事件，且不与“排除列表”中的任何一个 id 重复（用于牌堆后面的预览）
static func pick_preview(exclude_ids: Array[String]) -> Dictionary:
	var candidates: Array[Dictionary] = []
	for c in EVENTS:
		if exclude_ids.has(c["id"]):
			continue
		candidates.append(c)
	if candidates.is_empty():
		candidates = EVENTS.duplicate()
	var total := 0
	for c in candidates:
		total += int(c.get("weight", 1))
	var r := randi() % maxi(1, total)
	for c in candidates:
		var w := int(c.get("weight", 1))
		if r < w:
			return c
		r -= w
	return candidates[0]

## 解析选项的"实际生效版本"：若 alt 条件满足，用 alt 覆盖 effects/result/set
static func resolve_option(opt: Dictionary, flags: Dictionary) -> Dictionary:
	if not opt.has("alt"):
		return opt
	var alt: Dictionary = opt["alt"]
	if bool(flags.get(alt.get("flag", ""), false)) == bool(alt.get("flag_value", true)):
		var merged: Dictionary = opt.duplicate(true)
		for k in ["effects", "set", "result", "label"]:
			if alt.has(k):
				merged[k] = alt[k]
		return merged
	return opt