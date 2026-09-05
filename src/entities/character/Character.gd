extends Control
class_name Character

## 避难所里的人物状态实体（爸爸 / 妻子 / 女儿 / 小儿子）。
##
## 当前为骨架。后续需求会：
##   1. 通过 CardData(category=&"character") 关联到具体人物
##   2. 暴露饱食度/心情/健康三维（取代原 GameData 的全局四维中部分指标）
##   3. 在 HUD 中作为图标列展示，鼠标悬浮显示详情
##
## 状态变化通过 SignalBus.stat_changed / flag_changed 广播，
## 本节点只负责可视化与本地交互（hover、点击展开日记条目）。

## 人物 ID，对应 CardData.card_id
@export var character_id: StringName

## 头像插图
@export var portrait: Texture2D

## 当前状态（与 CardData.meta 同步）
@export var mood: int = 60
@export var health: int = 80
@export var hunger: int = 40


func _ready() -> void:
	# TODO(后续需求): 监听 SignalBus.daily_tick / hunger_depleted 等信号
	pass
