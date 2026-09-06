extends RefCounted
class_name SettlementTips

## 结算提示数据（按 结算提示.docx）
## 五个池：你 / 妻子 / 儿子 / 女儿 / 局势。
## 每次结算（未触发结局时）：每池排除未达成条件的条目，剩下等概率随机选一条，
## 按池顺序逐行输出（每行一条，换行分隔）。
## cond 使用与事件 req 相同的判定格式（flags / min_stats / max_stats），由 GameData._req_ok 判定。

const ORDER: Array[String] = ["你", "妻子", "儿子", "女儿", "局势"]

const POOLS: Array[Dictionary] = [
	# ------------------------------------------------ 你
	{"pool": "你", "cond": {"flags": {"revive": true}, "max_stats": {"immunity": 49}},
		"text": "经历了之前家里难熬的集体发烧，你觉得你也有点撑不住了。"},
	{"pool": "你", "cond": {"flags": {"duty": false}},
		"text": "你心里空落落的。其他同事在值班吗？"},
	{"pool": "你", "cond": {"flags": {"duty": true}},
		"text": "一想到最近还要值班，你疲惫的睡下了。"},
	{"pool": "你", "cond": {"flags": {"volunteer": true}},
		"text": "明天要送药吗？你不放心的又检查了一遍手机。"},
	{"pool": "你", "cond": {"flags": {"volunteer": true}},
		"text": "我们的社区充满希望。你想。"},
	# ------------------------------------------------ 妻子
	{"pool": "妻子", "cond": {"max_stats": {"supplies": 50}},
		"text": "妻子向你抱怨不多的家用。"},
	{"pool": "妻子", "cond": {"max_stats": {"mood": 29}},
		"text": "你们背对背，一夜无话。"},
	{"pool": "妻子", "cond": {"min_stats": {"mood": 30}},
		"text": "妻子跟你聊了几句，就都沉沉的睡过去了。"},
	{"pool": "妻子", "cond": {"max_stats": {"harmony": 69}},
		"text": "妻子跟你讲了讲社区发生的趣事。"},
	{"pool": "妻子", "cond": {"min_stats": {"harmony": 70}},
		"text": "妻子在群里聊到了很晚。"},
	# ------------------------------------------------ 儿子
	{"pool": "儿子", "cond": {"flags": {"crisis": false}},
		"text": "你还未在儿子学业上操多少心。"},
	{"pool": "儿子", "cond": {"flags": {"crisis": true, "son_perfect": false}},
		"text": "儿子似乎有了网瘾。"},
	{"pool": "儿子", "cond": {"flags": {"son_perfect": true}},
		"text": "儿子今晚多学了一会。"},
	{"pool": "儿子", "cond": {"flags": {"talked": true, "son_perfect": true}},
		"text": "自从那次谈心，儿子再没惹你生气。"},
	# ------------------------------------------------ 女儿
	{"pool": "女儿", "cond": {"flags": {"account": false}},
		"text": "你很高兴女儿步入正轨。"},
	{"pool": "女儿", "cond": {"flags": {"account": true, "good_dad": false}},
		"text": "想起女儿，你心里总是空落落的。"},
	{"pool": "女儿", "cond": {"flags": {"good_dad": true}},
		"text": "想起女儿，你心底一阵柔软。"},
	# ------------------------------------------------ 局势（和睦 / 心情 / 免疫力 / 物资）
	{"pool": "局势", "cond": {"max_stats": {"harmony": 30}},
		"text": "往好处想，你至少没跟邻居在微信群里吵起来。"},
	{"pool": "局势", "cond": {"min_stats": {"harmony": 31}, "max_stats": {"harmony": 69}},
		"text": "朴素的互助已然足够，微小的善意足以支撑大家在危机中艰难前行。"},
	{"pool": "局势", "cond": {"min_stats": {"harmony": 70}},
		"text": "你跟邻里风雨同舟，守望相助。"},
	{"pool": "局势", "cond": {"max_stats": {"mood": 30}},
		"text": "家里真是一团乱麻，你偶尔也会有撂挑子不干了的想法。"},
	{"pool": "局势", "cond": {"min_stats": {"mood": 31}, "max_stats": {"mood": 69}},
		"text": "家庭的鸡毛蒜皮让人愤懑又无奈，孩子们似乎有点懂事了，但也没那么多。"},
	{"pool": "局势", "cond": {"min_stats": {"mood": 70}},
		"text": "家和万事兴，你感觉你们之间的感情不会更好了。"},
	{"pool": "局势", "cond": {"max_stats": {"immunity": 30}},
		"text": "你想做家庭坚实的一员，但是目前看来，似乎有点力不从心了。"},
	{"pool": "局势", "cond": {"min_stats": {"immunity": 31}, "max_stats": {"immunity": 69}},
		"text": "互联网信息鱼龙混杂。熏醋、盐水漱口、喝高度酒？你们没有尝试过，但是也不免紧张了起来。"},
	{"pool": "局势", "cond": {"min_stats": {"immunity": 70}},
		"text": "按时起床，规律饮食，每晚做运动。你们在小小的家里面，努力生活。"},
	{"pool": "局势", "cond": {"max_stats": {"supplies": 30}},
		"text": "家里捉襟见肘，每顿都不能浪费。"},
	{"pool": "局势", "cond": {"min_stats": {"supplies": 31}, "max_stats": {"supplies": 69}},
		"text": "在封城之际，你们每顿都能吃好，已经足够幸运。"},
	{"pool": "局势", "cond": {"min_stats": {"supplies": 70}},
		"text": "你们冰箱里食物还不少，你不得不承认，囤积粮食是个好习惯。"},
]
