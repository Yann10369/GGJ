extends Control
class_name StatBar

## 顶部四维显示：仅用扑克花色图案表示（黑桃=免疫力，红桃=心情，方块=物资，梅花=和睦）。
## 数值越高，花色内部从底部向上越满。无文本、无进度条、无额外装饰。

const SIZE := 72.0

var key := ""
var value := 0

var _gauge: SuitGauge

func setup(k: String) -> void:
	key = k
	custom_minimum_size = Vector2(SIZE, SIZE)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = MOUSE_FILTER_IGNORE

	_gauge = SuitGauge.new()
	_gauge.suit = SuitGauge.suit_for_key(k)
	_gauge.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_gauge)
	_gauge.value = float(value)

## v 取值 0..100；animate=true 时平滑过渡。
func set_value(v: int, animate: bool) -> void:
	value = v
	if _gauge != null:
		_gauge.set_value(float(v), animate)

## 数值变化提示：按要求不显示文本，留空以保持接口兼容。
func bump(_delta: int) -> void:
	pass
