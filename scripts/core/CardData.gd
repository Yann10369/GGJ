extends Resource
class_name CardData

## 卡牌数据资源（Custom Resource 模板）。
##
## 一个 .tres 实例描述一张卡牌（道具 / 物资 / 人物）。
## 现阶段仅定义通用字段；后续需求会按 category 扩展各自专用字段
## （道具的耐久度、物资的数量、人物的饱食度/心情/健康等）。
##
## 配合 scripts/autoloads/CardManagerSingleton.gd 使用：
##   var deck: Array[CardData] = []
##   deck.append(load("res://data/cards/items/gas_mask.tres"))
##
## TODO(后续需求): 把 GameData 中的内联事件与资产迁移到 .tres，
##                 并在 EditorPlugin 里给 Inspector 增加专用字段编辑面板。

## 唯一 ID，运行时检索用
@export var card_id: StringName

## 类别："item"（道具）/ "resource"（物资）/ "character"（人物）
@export var category: StringName

## 牌面标题
@export var title: String

## 简短描述（一行）
@export_multiline var description: String

## 卡面插图（位于 res://assets/textures/cards/）
@export var art: Texture2D

## 抽取权重（高数字更易被抽到）
@export_range(1, 10) var weight: int = 3

## 立即生效的四维效果 {stat_key: delta}（仅用于即时结算的卡牌）
@export var effects: Dictionary = {}

## 消耗型卡牌每日自动消耗的资源 {resource_key: amount}
@export var daily_consumption: Dictionary = {}

## 元数据 / 旗标钩子（自由使用，譬如 duration、stackable 等）
@export var meta: Dictionary = {}
