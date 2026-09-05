extends Node
class_name CardManagerSingleton

## 全局卡牌管理器（洗牌 / 发牌 / 牌库维护）。
##
## 当前为骨架。等 data/cards/ 下的 .tres 实例就位后，
## 由 load_deck(category) 扫描 res://data/cards/{items,resources,characters}/*.tres
## 返回 Array[CardData]。
##
## 所有卡牌操作通过 SignalBus 广播，UI 监听即可。

## 全局 RNG 种子（0 表示不固定）
@export var seed_value: int = 0

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	if seed_value == 0:
		_rng.randomize()
	else:
		_rng.seed = seed_value
	print("[CardManager] ready")


## 加载某个 category 的牌库
## category: &"item" / &"resource" / &"character"
func load_deck(category: StringName) -> Array[Resource]:
	var dir_path := "res://data/cards/%s/" % str(category)
	var result: Array[Resource] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_warning("[CardManager] deck dir not found: %s" % dir_path)
		return result
	for f in dir.get_files():
		if f.get_extension() != "tres":
			continue
		var path := dir_path + f
		var card: Resource = load(path)
		if card != null:
			result.append(card)
	return result


## 洗牌（in-place 返回新数组，不修改原数组）
func shuffle_deck(deck: Array) -> Array:
	var copy := deck.duplicate()
	for i in range(copy.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp = copy[i]
		copy[i] = copy[j]
		copy[j] = tmp
	SignalBus.deck_shuffled.emit(copy.size())
	return copy


## 从牌库抽一张牌（不重复移除；如需移除调用 draw_and_remove）
func draw_card(deck: Array) -> Resource:
	if deck.is_empty():
		return null
	return deck[_rng.randi_range(0, deck.size() - 1)]


## 抽一张并从原数组移除
func draw_and_remove(deck: Array) -> Resource:
	if deck.is_empty():
		return null
	var idx := _rng.randi_range(0, deck.size() - 1)
	var card: Resource = deck[idx]
	deck.remove_at(idx)
	SignalBus.card_drawn.emit(card)
	return card


## 按权重抽一张（用于事件抽取）
func draw_weighted(items: Array) -> Resource:
	if items.is_empty():
		return null
	var total := 0
	for it in items:
		total += int(it.get("weight", 3))
	var r := _rng.randi_range(0, maxi(1, total) - 1)
	for it in items:
		var w := int(it.get("weight", 3))
		if r < w:
			return it
		r -= w
	return items[0]
