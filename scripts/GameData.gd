extends RefCounted
class_name GameData

## 封城十四天 · 防疫成长（事件池 v6）
## 四维：心情 / 免疫力 / 物资 / 和睦
## 旗标：eggs（家里有鸡蛋）/ crisis（儿子学业危机）/ talked（已与儿子谈心）
##       duty（值守中）/ volunteer（也是社区志愿者）/ account（女儿网恋账号未了，初始为真）
##       romance（女儿被骗过）/ good_dad（"你是我的好爸爸"达成）/ son_perfect（儿子完美结局）
##       test_good（线上测试好结局）/ noodles（热干面计数）

const STAT_KEYS: Array[String] = ["mood", "immunity", "supplies", "harmony"]

const STAT_DEFS: Dictionary = {
	"mood":     {"name": "心情",   "color": Color("#e0a33e")},
	"immunity": {"name": "免疫力", "color": Color("#4dbf7e")},
	"supplies": {"name": "物资",   "color": Color("#4f8fd0")},
	"harmony":  {"name": "和睦",   "color": Color("#d96a72")},
}

const INITIAL: Dictionary = {"mood": 60, "immunity": 62, "supplies": 56, "harmony": 65}

const TOTAL_DAYS := 14

## 事件字段：
##   id, cat, title, art(可选), desc, weight(低2/中3/高5), type("swipe"默认 / "shopping")
##   forced_days:[int]（指定日强制出现，优先于牌池）
##   from_day:int（从该天起才进牌池）  once:bool（全局只出现一次）
##   req:{flags:{k:v}, max_stats:{k:v}, min_stats:{k:v}}
##   left/right：{label, effects:{stat:int}, set:{flag:val}, result:str, alt:{flag,flag_value,effects,set,result}}
##   shopping 事件用 variants:[{when:{flag:val}, choose:int, items:[...]}]，items:{id,name,eff:{},counter,weight}
const EVENTS: Array[Dictionary] = [
	{
		"id": "lockdown", "cat": "封控", "title": "封城", "art": "lock",
		"desc": "工作停摆，一切社交暂停。一家四口被迫全天候待在一起。奇怪的是，我已经很久没认真看过他们的脸了。",
		"forced_days": [1], "once": true,
		"left": {"label": "修复亲子关系", "effects": {"mood": 6, "harmony": 4},
			"result": "或许我可以试着做点什么。我局促，也无奈——但总归，他们是家人。"},
		"right": {"label": "能活下来就好", "effects": {"immunity": 4, "mood": -4},
			"result": "当生离死别真的出现，一切外物都不重要了，唯独希望的是家人平平安安。"},
	},
	{
		"id": "ordering", "type": "shopping", "cat": "社区", "title": "接龙时间", "art": "phone",
		"desc": "感谢社区志愿者，我们可以在手机上便捷选择物资——虽然有什么、有多少并不确定。",
		"forced_days": [1, 5, 9, 13],
		"result_after": "封城前再不稀罕的，现在也稀罕了。",
		"variants": [
			{"when": {"volunteer": false}, "choose": 3, "pool": [
				{"id": "meat", "name": "肉类", "eff": {"immunity": 6, "supplies": 4}, "weight": 3},
				{"id": "fruit", "name": "外地捐赠水果", "eff": {"immunity": 6, "supplies": 3}, "weight": 3},
				{"id": "greens", "name": "绿叶菜", "eff": {"immunity": 4, "supplies": 2}, "weight": 2},
				{"id": "milk", "name": "牛奶", "eff": {"immunity": 5, "supplies": 2}, "weight": 2},
				{"id": "egg", "name": "鸡蛋", "eff": {"immunity": 3, "supplies": 2}, "counter": "eggs", "weight": 3},
				{"id": "potato", "name": "土豆花菜", "eff": {"supplies": 5}, "weight": 5},
				{"id": "cabbage", "name": "大白菜白萝卜", "eff": {"supplies": 5}, "weight": 5},
				{"id": "staple", "name": "基础米面粮油", "eff": {"supplies": 7}, "weight": 5},
			]},
			{"when": {"volunteer": true}, "choose": 4, "pool": [
				{"id": "meat", "name": "冻肉", "eff": {"immunity": 7, "supplies": 5}, "weight": 3},
				{"id": "fruit", "name": "稀有蔬果", "eff": {"immunity": 7, "supplies": 4}, "weight": 3},
				{"id": "egg", "name": "鸡蛋", "eff": {"immunity": 4, "supplies": 3}, "counter": "eggs", "weight": 3},
				{"id": "potato", "name": "土豆花菜", "eff": {"supplies": 6}, "weight": 5},
				{"id": "cabbage", "name": "大白菜白萝卜", "eff": {"supplies": 6}, "weight": 5},
				{"id": "staple", "name": "基础米面粮油", "eff": {"supplies": 8}, "weight": 5},
				{"id": "noodles", "name": "热干面便携装", "eff": {"mood": 6, "supplies": 4}, "counter": "noodles", "weight": 2},
				{"id": "mask", "name": "口罩纸巾", "eff": {"immunity": 6, "supplies": 3}, "weight": 4},
			]},
		],
	},
	{
		"id": "party_squad", "cat": "社区", "title": "党员突击队", "art": "father",
		"desc": "“两队一网”推行，单位抽调骨干党员成立了党员突击队。你自然成为了其中一员。",
		"from_day": 7, "once": true, "weight": 5,
		"left": {"label": "服从安排", "effects": {"harmony": 8, "immunity": -4}, "set": {"duty": true},
			"result": "三班倒 24 小时值守，从明天就要开始。这或许艰巨，却是我作为党员的责任。"},
		"right": {"label": "婉拒安排", "effects": {"harmony": -6, "mood": -8}, "set": {"duty": false},
			"result": "我信奉安全至上。孩子们似乎不这么看，我第一次发现，责任并非别人要求你承担才存在。"},
	},
	{
		"id": "duty_routine", "cat": "社区", "title": "例行值守",
		"desc": "奉献的人是光荣的。每次回来，你会换衣消毒，在门外等酒精味散尽才进家。",
		"req": {"flags": {"duty": true}}, "weight": 6,
		"left": {"label": "今天也去值守", "effects": {"immunity": -4, "harmony": 6},
			"result": "值守无聊，盒饭却是个盼头。不知是谁做的，味道的确不错。"},
		"right": {"label": "偶尔离一次岗", "effects": {"immunity": 4, "harmony": -10}, "set": {"duty": false},
			"result": "很快受到单位批评——你的离岗让上一位多驻了 8 小时。再没有离岗的理由了。"},
	},
	{
		"id": "slip_through", "cat": "社区", "title": "漏网之鱼",
		"desc": "封锁在家有人烦闷是自然的，但溜出家多少有点不应该。你今天去小区排查一下。",
		"req": {"flags": {"duty": true}}, "weight": 3,
		"left": {"label": "走左边的小径", "effects": {"mood": 6},
			"result": "没什么意外。每户阳台晾满衣服，是家人齐聚共渡难关的样子。阳光不会变，人也是。"},
		"right": {"label": "走中间的大路", "effects": {"harmony": 6},
			"result": "竟逮到一个瞎遛达的，你远远示意他回去。事后你才意识到口罩戴太久了，手感都奇怪。"},
	},
	{
		"id": "volunteer", "cat": "社区", "title": "也是社区志愿者",
		"desc": "社区招募更多人手转运物资，微信群热闹起来。志愿者意味着更大感染几率，你怎么办？",
		"from_day": 10, "req": {"flags": {"duty": true}}, "weight": 4,
		"left": {"label": "干活不嫌多", "effects": {"mood": 8, "harmony": 8, "immunity": -12}, "set": {"volunteer": true},
			"result": "支持大家走到这里的，是最朴素的英雄情怀。灾难面前，普通人不再普通。"},
		"right": {"label": "做好值守已不易", "effects": {"mood": 8, "immunity": 4}, "set": {"volunteer": false},
			"result": "一事精致，便能动人。你有任务，也有家庭，选择了家庭。"},
	},
	{
		"id": "difficulty", "cat": "社区", "title": "困难",
		"desc": "新到的这批物资分量不足，还都是坏菜烂叶。有居民朝你撒气，质疑你们拿回扣。",
		"req": {"flags": {"volunteer": true}}, "weight": 3,
		"left": {"label": "忽视，做好自己的事", "effects": {"harmony": 6, "mood": 4},
			"result": "你一如既往做好每次运送，得到更多善意——悄悄放在门前的小物件，刷屏的感谢。"},
		"right": {"label": "据理力争", "effects": {"harmony": -10},
			"result": "你在群里把道理讲清，那账号偃旗息鼓。但氛围微妙起来——过段时间他私信道了歉。"},
	},
	{
		"id": "talk", "cat": "家庭", "title": "谈心", "art": "talk",
		"desc": "孩子贪玩是天性，作为父亲，你要负好责任。你打开小儿子的房门。",
		"req": {"min_stats": {"mood": 55}, "flags": {"son_perfect": false}}, "weight": 2,
		"left": {"label": "跟他说清楚利害", "effects": {"mood": -8, "harmony": -4}, "set": {"crisis": false},
			"result": "你口干舌燥，也不知道他听进去多少。本来想用心教育，最后变成一场说教。"},
		"right": {"label": "结合自身经验讲讲", "effects": {"mood": 8, "harmony": 6}, "set": {"crisis": false, "talked": true},
			"result": "父亲向来不善言辞，但你现在是一个善于沟通的爸爸。"},
	},
	{
		"id": "hanger", "cat": "家庭", "title": "给他脸了", "art": "hanger",
		"desc": "小兔崽子天天不学好，一进来发现他又在打游戏！你实在忍不下去了。",
		"req": {"max_stats": {"mood": 50}}, "weight": 3,
		"left": {"label": "按住火气", "effects": {"mood": 4, "harmony": 6}, "set": {"crisis": true},
			"result": "你把游戏关了，平静地让他先去做作业。他不情愿，但最后还是去了。"},
		"right": {"label": "家法伺候", "effects": {"mood": -14, "harmony": -10}, "set": {"crisis": false},
			"result": "家里棍棒教育，鸡飞狗跳的整层楼都能听到。事后你心里也有点后悔。"},
	},
	{
		"id": "cake", "cat": "家庭", "title": "蛋糕", "art": "cake",
		"desc": "妻子用矿泉水瓶做的简易打蛋器配合电饭煲，做出了封城以来家里第一顿零嘴。",
		"req": {"flags": {"eggs": true}, "max_stats": {"mood": 50}}, "weight": 6,
		"left": {"label": "端给赌气的儿子", "effects": {"mood": 14, "supplies": -8, "immunity": 6},
			"set": {"crisis": true, "eggs": false},
			"result": "今晚不在乎网课、考勤和测试，只是疫情中彼此依偎的家庭。"},
		"right": {"label": "每个人有份", "effects": {"mood": 8, "immunity": 6}, "set": {"eggs": false},
			"result": "打蛋清很麻烦，但大家分工合作，成果属于每个人。",
			"alt": {"flag": "talked", "flag_value": true,
				"effects": {"mood": 14, "immunity": 6, "harmony": 4},
				"result": "儿子也分到一块。打蛋清很麻烦，但分工合作，成果属于每个人。"}},
	},
	{
		"id": "gaming", "cat": "家庭", "title": "人之常情，吗？",
		"desc": "你推开儿子的房门，本该学习的他正热火朝天地打着游戏。",
		"weight": 4,
		"left": {"label": "需要干预", "effects": {"mood": 4}, "set": {"crisis": false},
			"result": "跟儿子约法三章，白天不关门，晚上拿走电脑。你试了一个温和父亲能做的所有举措。"},
		"right": {"label": "可以适当玩玩", "effects": {"mood": 6}, "set": {"crisis": true},
			"result": "他早晚要自己学会控制屏幕时长。"},
	},
	{
		"id": "test", "cat": "家庭", "title": "线上测试", "art": "test",
		"desc": "搞什么？小儿子平时全校 30 名以内，这次线上测试直接掉到 150 名开外。妻子急得不知怎么办。",
		"req": {"flags": {"crisis": true, "son_perfect": false}}, "weight": 5,
		"left": {"label": "没收设备全程陪同", "effects": {"mood": -6, "harmony": -4}, "set": {"crisis": false},
			"result": "儿子意见很大，但这是为了他好。"},
		"right": {"label": "询问事情原委", "effects": {"mood": 10, "harmony": 2, "immunity": 4}, "set": {"crisis": false},
			"result": "儿子没做错。线上监考没经验，几乎所有题目都能搜到。我们狠狠夸了他，吃了顿好的。",
			"alt": {"flag": "talked", "flag_value": true,
				"effects": {"mood": 18, "harmony": 8, "immunity": 4, "supplies": -4},
				"set": {"crisis": false, "test_good": true},
				"result": "你从蛛丝马迹跟他讲清利害。儿子什么都没做错，几乎所有人的分数都不正常。"}},
	},
	{
		"id": "test2", "cat": "家庭", "title": "又一次测试", "art": "test",
		"desc": "又一次测试快来了。儿子按部就班，空闲打会儿游戏。妻子也不操心了，天天拉我在客厅打羽毛球。",
		"req": {"flags": {"test_good": true, "son_perfect": false}}, "weight": 2,
		"left": {"label": "鼓励儿子", "effects": {"mood": 10}, "set": {"son_perfect": true},
			"result": "新的考试系统没杜绝作弊，但比上次好多了。至少儿子没作弊，我们为他骄傲。"},
		"right": {"label": "跟班主任反馈", "effects": {"mood": 10}, "set": {"son_perfect": true},
			"result": "换了新软件，路由器也借到了。儿子考得不错，中考没那么让人担心了。"},
	},
	{
		"id": "help_low", "cat": "邻里", "title": "求助", "art": "phone",
		"desc": "女儿正长身体，却越来越容易累。或许我们需要一顿像样的饭。",
		"req": {"max_stats": {"harmony": 59, "supplies": 49}}, "weight": 5,
		"left": {"label": "在群里求助", "effects": {"mood": -8, "harmony": -2},
			"result": "你在社区群里问了问，可消息很快被接龙刷过去了。"},
		"right": {"label": "物资短缺总要适应", "effects": {"mood": 4},
			"result": "妻子给土豆换了花样，用土豆泥，我们又敷衍了一顿。"},
	},
	{
		"id": "help_high", "cat": "邻里", "title": "求助", "art": "phone",
		"desc": "女儿正长身体，却越来越容易累。或许我们需要一顿像样的饭。",
		"req": {"max_stats": {"supplies": 49}, "min_stats": {"harmony": 60}}, "weight": 5,
		"left": {"label": "在群里求助", "effects": {"mood": 14, "immunity": 14, "harmony": -2, "supplies": 4},
			"result": "18 楼很快回信了。一条鲫鱼放在门口，汤很鲜美。女儿脸颊浮现久违的笑容。"},
		"right": {"label": "物资短缺总要适应", "effects": {"mood": 4},
			"result": "妻子给土豆换了花样，用土豆泥，我们又敷衍了一顿。"},
	},
	{
		"id": "return_gift", "cat": "邻里", "title": "回礼", "art": "fish",
		"desc": "上次的鱼汤女儿很喜欢。你想送点什么当回礼。",
		"req": {"min_stats": {"harmony": 65}}, "weight": 4,
		"left": {"label": "送一份小礼物", "effects": {"supplies": -6, "harmony": 6, "mood": 8},
			"result": "你找了点家里多余的干货放在 18 楼门口。"},
		"right": {"label": "默默记下", "effects": {"mood": 2, "supplies": -2},
			"result": "你在心里记下这份人情，想着解封后好好谢人家。"},
	},
	{
		"id": "online_romance", "cat": "家庭", "title": "网恋",
		"desc": "你无意瞥见女儿手机，竟发现她在跟网上的人发暧昧消息。你感觉全身的血往脑门上窜。",
		"req": {"flags": {"account": true, "good_dad": false}}, "weight": 5,
		"left": {"label": "训斥一顿", "effects": {"supplies": -6, "mood": -6}, "set": {"account": false},
			"result": "妻子揪着女儿劈头盖脸一顿骂，当面删了好友。两天后她饿得出门，吃了满满一锅面。"},
		"right": {"label": "别管了", "effects": {"mood": -4}, "set": {"romance": true},
			"result": "你深呼吸，默默把手机放回原位。这是女儿的事，她总要自己学着办。"},
	},
	{
		"id": "good_dad", "cat": "家庭", "title": "你是我的好爸爸", "art": "mother2",
		"desc": "今天你早起，女儿也早就起床，默默在沙发上温习课程。她看着你，欲言又止。",
		"req": {"flags": {"account": true, "romance": true, "good_dad": false}, "min_stats": {"mood": 50}}, "weight": 2,
		"left": {"label": "轻声问她怎么了", "effects": {"mood": 16, "harmony": 6}, "set": {"good_dad": true},
			"result": "“我网恋被骗了，还被骗走所有压岁钱……”女儿落下泪。你环住她的肩，向她保证不告诉妈妈。“你是我的好爸爸。”"},
		"right": {"label": "不是最好的时机", "effects": {"mood": 4},
			"result": "你去厨房做早饭，女儿安安静静地学习。多好的一个早晨。"},
	},
]

static func initial_stats() -> Dictionary:
	return INITIAL.duplicate()

static func initial_flags() -> Dictionary:
	return {"eggs": true, "crisis": false, "talked": false, "duty": false, "volunteer": false,
		"account": true, "romance": false, "good_dad": false, "son_perfect": false,
		"test_good": false, "noodles": 0}

## 某天强制出现的事件列表（按 EVENTS 顺序，跳过已显示的 once 事件）
static func forced_for_day(day: int, shown: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for e in EVENTS:
		var fd = e.get("forced_days", [])
		if fd is Array and (fd as Array).has(day):
			if not (e.get("once", false) and shown.get(e["id"], false)):
				result.append(e)
	return result

## 该事件当前是否满足出现条件
static func can_show(event: Dictionary, stats: Dictionary, flags: Dictionary, shown: Dictionary, day: int) -> bool:
	if event.get("once", false) and shown.get(event["id"], false):
		return false
	if event.has("from_day") and day < int(event["from_day"]):
		return false
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

## 从牌池按权重抽一个（不与上一次相同、满足条件、非强制事件）
static func pick_event(last_id: String, stats: Dictionary, flags: Dictionary, shown: Dictionary, day: int) -> Dictionary:
	var cands: Array[Dictionary] = []
	for e in EVENTS:
		var fd = e.get("forced_days", [])
		if fd is Array and fd.size() > 0:
			continue  # 强制事件不进牌池
		if e["id"] == last_id:
			continue
		if not can_show(e, stats, flags, shown, day):
			continue
		cands.append(e)
	if cands.is_empty():
		for e in EVENTS:
			if e["id"] != last_id:
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
	return cands[0]

## 解析选项的实际生效版本（应用 alt 覆盖）
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

## 接龙采购：按当前旗标选一个 variant，再按权重抽 choose 个商品展示
static func shopping_items(event: Dictionary, flags: Dictionary) -> Dictionary:
	var chosen: Dictionary = event["variants"][0]
	for v in event["variants"]:
		var ok := true
		var when: Dictionary = v.get("when", {})
		for k in when:
			if bool(flags.get(k, false)) != bool(when[k]):
				ok = false
				break
		if ok:
			chosen = v
			break
	var pool: Array = chosen["pool"]
	var choose: int = int(chosen["choose"])
	var picks: Array[Dictionary] = []
	var remaining := pool.duplicate(true)
	for i in range(choose):
		if remaining.is_empty():
			break
		var total := 0
		for it in remaining:
			total += int(it.get("weight", 3))
		var r := randi() % maxi(1, total)
		var idx := 0
		for j in remaining.size():
			var w := int(remaining[j].get("weight", 3))
			if r < w:
				idx = j
				break
			r -= w
		picks.append(remaining[idx])
		remaining.remove_at(idx)
	return {"choose": choose, "items": picks}

## 计算结局
static func compute_ending(stats: Dictionary, flags: Dictionary) -> Dictionary:
	var mood := int(stats["mood"])
	var imm := int(stats["immunity"])
	var sup := int(stats["supplies"])
	var duty := bool(flags.get("duty", false))
	var son := bool(flags.get("son_perfect", false))
	var dad := bool(flags.get("good_dad", false))
	if imm <= 0:
		return {"title": "需要医院", "text": "刚开始儿子病倒了，然后是妻子和女儿。我烧到 40 度，是我带来的病毒。我们在志愿者帮助下进了方舱，被拆分到不同地方。我要赶紧好起来，然后见他们。"}
	if mood <= 0:
		if not son:
			return {"title": "离开", "text": "一个夜里，儿子打开了门，然后再也没回来。没人知道他是怎么做到的。妻子每天都在哭。我们想他。"}
		elif not dad:
			return {"title": "离开", "text": "我们以为女儿最省心，可疫情后她离开了，连句道别都没留。妻子每天都在哭。我们想她。"}
		else:
			return {"title": "离开", "text": "我可能不是一个称职的父亲。前妻在女儿高考后跟我离婚，我带走没成年的儿子，而她们一起离开了。儿子还在上高中，我需要支撑下去。"}
	if sup <= 0:
		return {"title": "还好有政府", "text": "勉强度日。我们被当做困难家庭，获得了街道网格员和下沉党员的免费援助。大家顿顿都有吃的，但也没心思再去想任何事。"}
	if duty and son and dad:
		return {"title": "在结束的那一天", "text": "平平安安。病毒雾霾散去，你短暂喜悦后更感到如释重负。这个家庭没被天灾打倒。每当你回想起这段岁月，你是抗疫一线基层防线一个英勇的标点，就感到——热泪盈眶。"}
	return {"title": "平庸却坚定", "text": "这就够了。疫情见证了我们家庭的努力，谁都没有被打倒。我们对未来充满期望。"}
