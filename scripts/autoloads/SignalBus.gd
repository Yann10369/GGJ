extends Node

## 全局事件总线：让 UI / 逻辑 / 资源解耦。
## 任何节点 emit，订阅者 connect，发布者和订阅者无需相互引用。
##
## 用法示例：
##   SignalBus.card_drawn.emit(card)
##   SignalBus.card_drawn.connect(_on_card_drawn)

# --------------------------------------------------------------- 卡牌
signal card_drawn(card: Resource)
signal card_played(card: Resource)
signal card_discarded(card: Resource)
signal deck_shuffled(deck_size: int)

# --------------------------------------------------------------- 阶段
signal phase_changed(from: StringName, to: StringName)
signal phase_completed(phase: StringName)
signal scavenge_tick(remaining_seconds: float)

# --------------------------------------------------------------- 时间 / 天
signal day_started(day: int)
signal day_ended(day: int)

# --------------------------------------------------------------- 状态
signal stat_changed(key: String, old_value: int, new_value: int)
signal flag_changed(key: String, value: Variant)

# --------------------------------------------------------------- 事件
signal event_triggered(event_id: StringName)
signal event_resolved(event_id: StringName, accepted: bool)

# --------------------------------------------------------------- UI
signal card_swiped(direction: int)        # -1 左 / +1 右
signal shop_purchase_confirmed(items: Array)
signal journal_updated(day: int)
