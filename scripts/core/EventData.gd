extends Resource
class_name EventData

## 事件数据资源（Custom Resource 模板）。
##
## 一个 .tres 实例描述一个"每日事件"（如：变异蟑螂入侵 / 商人敲门）。
## 当前 GameData.EVENTS 仍是数组内字典形式，本类先定义字段形态，
## 后续可逐个把现有事件迁移为 .tres 实例。
##
## 运行时由 CardManagerSingleton 配合 pick_event() 使用，
## 或被 SurvivalPhase 直接消费。

## 唯一 ID
@export var event_id: StringName

## 分类标签（"封控" / "家庭" / "邻里" / "社区" 等，纯展示用）
@export var category: String

## 事件标题（牌面大字）
@export var title: String

## 事件正文（牌面描述）
@export_multiline var description: String

## 配图（位于 res://assets/textures/cards/）
@export var art: Texture2D

## 抽取权重（高数字更易被抽到；同权重内随机）
@export_range(1, 10) var weight: int = 3

## 从第几天起才进牌池（默认第 1 天）
@export var from_day: int = 1

## 全局只出现一次（一旦出现过就永久从池中剔除）
@export var once: bool = false

## 强制出现的天（覆盖抽取；空数组则走普通抽取）
@export var forced_days: Array[int] = []

## 出现条件：{flags:{k:v}, min_stats:{k:v}, max_stats:{k:v}}
## - flags: 要求当前 flags[k] == v
## - min_stats: 当前 stats[k] >= v
## - max_stats: 当前 stats[k] <= v
@export var req: Dictionary = {}

## 左选项 {label, effects, set, result, alt}
@export var left_option: Dictionary = {}

## 右选项 {label, effects, set, result, alt}
@export var right_option: Dictionary = {}

## 特殊事件类型："swipe"（默认，左滑右滑）/ "shopping"（接龙采购）
@export var event_type: StringName = &"swipe"

## shopping 事件专用：变体配置（按 when:{flag:val} 选 variant）
@export var shopping_variants: Array[Dictionary] = []
