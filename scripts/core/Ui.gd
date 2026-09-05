extends RefCounted
class_name Ui

## 用「锚点预设 + 显式偏移」把 Control 摆进父节点（父节点为普通 Control 时rect 由偏移决定）。
static func place(control: Control, preset: Control.LayoutPreset,
		left := 0.0, top := 0.0, right := 0.0, bottom := 0.0) -> void:
	control.set_anchors_preset(preset, false)
	control.offset_left = left
	control.offset_top = top
	control.offset_right = right
	control.offset_bottom = bottom

## 快速构造一个 StyleBoxFlat
static func box(color: Color, radius := 0, ml := 0, mt := 0, mr := 0, mb := 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	if radius != 0:
		sb.set_corner_radius_all(radius)
	sb.content_margin_left = float(ml)
	sb.content_margin_top = float(mt)
	sb.content_margin_right = float(mr)
	sb.content_margin_bottom = float(mb)
	return sb

## 容器里用的占位 / 撑开元素
static func spacer(height := 0.0, expand := false) -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.custom_minimum_size = Vector2(0.0, height)
	if expand:
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c

## 让一个 Control 忽略鼠标事件
static func ghost(control: Control) -> void:
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
