extends Control
class_name ScavengePhase

## 60 秒限时抓牌阶段（致敬 "60 Seconds!"）。
##
## 当前为骨架。后续需求会：
##   1. 由 GameManagerSingleton 挂载本场景作为子节点
##   2. 启动 60 秒倒计时（每秒 emit SignalBus.scavenge_tick）
##   3. 在屏幕上展示散落的卡牌，点击拾取进背包
##   4. 时间到 emit phase_completed 信号
##
## 卡牌数据由 CardManagerSingleton.load_deck(&"item" | &"resource" | &"character") 提供。

## 拾荒阶段总时长（秒）
@export var duration_seconds: float = 60.0

## 当前剩余时间（运行时维护）
var _remaining: float = 0.0

## 本阶段完成信号（GameManager 监听）
signal phase_completed


func _ready() -> void:
	_remaining = duration_seconds
	# TODO(后续需求): 启动 Timer 节点，每秒 _tick()，
	# 时间到 emit phase_completed.emit()


func _process(delta: float) -> void:
	if _remaining <= 0.0:
		return
	_remaining -= delta
	SignalBus.scavenge_tick.emit(_remaining)
	# TODO(后续需求): 用 Tween / AnimationPlayer 播放计时 UI
