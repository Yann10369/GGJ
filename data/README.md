# Grow 事件配置

运行时仅使用本目录的 JSON。新增模板后，把 ID 加进 `event_manifest.json`，文件命名为 `events_<id>.json`。所有文件必须是合法 UTF-8 JSON，对话里的英文双引号需要转义。

## 事件

`id` 唯一；`title`、`desc`、`cat` 用于展示；`art` 对应 `assets/textures/cards/<art>.png`，可省略。

`pool` 为 `family`、`community` 或 `world`。`weight` 默认 3，低 / 中 / 高为 2 / 3 / 5。`once` 默认 true；可重复事件设为 false，并指定 `interval`。

`from_day`、`to_day` 限定窗口。比赛版以 19 为常规池的末日；调整单局时长时，此值随解封前夜一起移动。短期事件如口罩的 `to_day: 6` 保持不变。

`forced_days` 指定固定日期，`fixed_order` 决定同日先后（较小的先）。`eve` 是特殊的尾声入口，由单局结束日期控制。每天最多两张，因此同日不要配置超过两个固定事件。

`deadline` 是关键剧情的保底日期，仍须满足条件。符合条件连续三天未抽到后，权重开始递增；达到期限后优先进入卡位。`scheduled: true` 用于值守，每次完成后隔三天到期；`delayed_only: true` 只允许由种子解锁。`after: {"id":"test","delay":3}` 要求前一事件已经处理，并至少过去三天。

## 条件

事件的 `req` 与选项的 `requires` 使用同一结构，可组合：

```json
{
  "flags": {"talk_with_son": true},
  "min_flags": {"egg": 1},
  "min_stats": {"mood": 50},
  "max_stats": {"immunity": 30}
}
```

`flags` 精确匹配；数值计数用 `min_flags`。支持 `any: [条件, 条件]`、`all: [...]`、`not: 条件`。未知字段或变量不满足条件，防止拼写错误解锁剧情。

## 选项

只使用完整 `options` 数组，不再混用 `left/right/alt`。符合条件的选项全部显示。

```json
{
  "label": "询问事情原委",
  "requires": {"flags": {"talk_with_son": true}},
  "effects": {"mood": 10, "supplies": -5, "immunity": 5},
  "set": {"son_study_crisis": false, "online_test_good": true},
  "result": "儿子开始向你解释成绩背后的事情。",
  "record": "生长 · 那次谈话让儿子愿意解释成绩背后的事情。",
  "followups": [{"id": "test2", "delay": 3}]
}
```

`effects` 为四状态即时增减，普通强度按 ±5、±10、±15。`set` 设置 Flag；`clear` 是需要归 false 的 Flag 名数组；`add` 增减食材计数且不低于零。`record` 是成长记录，不要写程序变量名。`followups` 设置最早日期，不跳过目标事件自身的条件。

`exposure` 调整隐藏暴露风险；`ration` 降低当晚物资消耗；`metrics` 记录统计次数。`outcomes` 是包含权重、效果和结果的随机分支，用于漏网之鱼。所有随机结果由单局 RNG 决定，界面预览不改变随机序列。

当前 Flag：`account`、`romance`、`talk_with_son`、`son_study_crisis`、`online_test_good`、`son_perfect`、`duty`、`community_volunteer`、`egg`、`hot_dry_noodle`、`help_neighbor`、`received_help`、`return_gift`、`good_father`、`exposure`。

## 接龙

`type: "shopping"` 使用 `variants`。`when` 按身份选择变体；`offer` 是展示数量，`choose` 是必须选择的数量，`pool` 是候选物品。`purchase_effects` 为一次采购的固定收益；每个物品的 `eff` 为额外效果，`counter` 为保留的食材计数。单局状态机验证 ID、数量和重复项后才应用奖励。

`special: "rumor"`、`"delivery_news"` 由单局处理消息真相及延迟配送回信。核实消息会撤销当天主动行动实际获得的收益（考虑封顶），并告知可靠信息。
