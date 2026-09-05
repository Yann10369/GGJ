# 封城十四天 · 事件卡片数据

本目录包含《封城十四天》游戏的所有事件卡片 JSON 数据文件。每个文件对应一个独立的事件卡牌。

## 文件格式

每个 JSON 文件包含以下字段：

### 基本字段
| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | string | 事件唯一标识符 |
| `cat` | string | 事件分类（封控/社区/家庭/邻里） |
| `title` | string | 事件标题 |
| `art` | string | 插图文件名（对应 art/目录下的图片） |
| `desc` | string | 事件描述文本 |
| `weight` | int | 权重（2=低概率，3=中概率，5=高概率） |

### 出现条件
| 字段 | 类型 | 说明 |
|------|------|------|
| `forced_days` | array | 强制出现的天数列表，如 [1,5,9,13] |
| `from_day` | int | 从该天起才可进入牌池 |
| `once` | bool | 全局只出现一次 |
| `req.flags` | object | 需要的旗标状态，如 {"duty": true} |
| `req.max_stats` | object | 状态值上限，如 {"mood": 50} |
| `req.min_stats` | object | 状态值下限，如 {"harmony": 60} |

### 选项字段
| 字段 | 类型 | 说明 |
|------|------|------|
| `left/right` | object | 左右选项配置 |
| `label` | string | 选项按钮文字 |
| `effects` | object | 状态变化 {mood/immunity/supplies/harmony: int} |
| `set` | object | 设置的旗标 {flag_name: value} |
| `result` | string | 选择后的剧情结果文本 |
| `alt` | object | 隐藏分支条件覆盖 |

### Shopping 类型事件
对于采购类事件（type: "shopping"），使用 `variants` 数组：
```json
"variants": [
  {
    "when": {"volunteer": false},
    "choose": 3,
    "pool": [
      {"id": "meat", "name": "肉类", "eff": {"immunity": 6}, "weight": 3}
    ]
  }
]
```

## 状态键名
- `mood` - 心情
- `immunity` - 免疫力
- `supplies` - 物资
- `harmony` - 和睦

## 旗标说明
| 旗标 | 说明 | 初始值 |
|------|------|--------|
| `eggs` | 家里有鸡蛋 | true |
| `crisis` | 小儿子学业危机 | false |
| `talked` | 已与儿子谈心 | false |
| `duty` | 值守中 | false |
| `volunteer` | 也是社区志愿者 | false |
| `account` | 女儿网恋账号未了 | true |
| `romance` | 女儿被骗过 | false |
| `good_dad` | 好爸爸达成 | false |
| `son_perfect` | 儿子完美结局 | false |
| `test_good` | 线上测试好结局 | false |
| `noodles` | 热干面计数 | 0 |

## 事件列表

### 封控池
- `events_lockdown.json` - 封城（第 1 天强制）

### 社区池
- `events_ordering.json` - 接龙时间（购物事件，第 1,5,9,13 天）
- `events_party_squad.json` - 党员突击队（第 7 天起）
- `events_duty_routine.json` - 例行值守（duty=1 时每日）
- `events_slip_through.json` - 漏网之鱼（duty=1 时概率）
- `events_volunteer.json` - 也是社区志愿者（第 10 天起，duty=1）
- `events_difficulty.json` - 困难（volunteer=1 时）

### 家庭池
- `events_talk.json` - 谈心（心情≥55）
- `events_hanger.json` - 给他脸了（心情≤50）
- `events_cake.json` - 蛋糕（eggs=true，心情≤50）
- `events_gaming.json` - 人之常情，吗？
- `events_test.json` - 线上测试（crisis=true）
- `events_test2.json` - 线上测试 2（test_good=true）
- `events_online_romance.json` - 网恋（account=true）
- `events_good_dad.json` - 你是我的好爸爸（account=true, romance=true）

### 邻里池
- `events_help_low.json` - 求助（和睦<60，supplies<50）
- `events_help_high.json` - 求助（和睦≥60，supplies<50）
- `events_return_gift.json` - 回礼（harmony≥65）

## 使用方法

1. 在 `GameData.gd` 中加载这些 JSON 文件
2. 根据天数、状态、旗标筛选可显示事件
3. 按权重随机抽取事件
4. 玩家选择后应用 effects 和 set

## 注意事项

- 所有数值效果会累加到对应状态
- 状态封顶 100，保底 0
- 旗标为持久化标记，影响后续事件触发
- alt 字段用于实现隐藏分支剧情
