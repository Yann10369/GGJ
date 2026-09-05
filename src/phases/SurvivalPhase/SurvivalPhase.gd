extends Control
class_name SurvivalPhase

## 避难所每日生存与决策阶段。
##
## 当前为骨架。后续需求会：
##   1. 展示今天的随机事件（由 GameData.pick_event / EventData 选出）
##   2. 让玩家用拖拽 / 左右键 / 按钮选择左 / 右方案
##   3. 应用效果、消耗资源、推动 GameManagerSingleton.modify_stat
##   4. 推进到次日 / 触发结局
##
## 阶段完成时 emit phase_completed。

## 当前展示的事件 ID（运行时由 GameManager 注入）
@export var current_event_id: StringName

## 当前天数（运行时由 GameManager 注入）
@export var day: int = 1

## 本阶段完成信号
signal phase_completed


func _ready() -> void:
	# TODO(后续需求): 监听 SignalBus.day_started，
	# 拉取今日事件 -> 渲染 Card 实体 -> 等待玩家决策
	pass


func resolve_choice(accepted: bool) -> void:
	# TODO(后续需求): 应用当前事件的左/右效果
	SignalBus.event_resolved.emit(current_event_id, accepted)
	phase_completed.emit()
