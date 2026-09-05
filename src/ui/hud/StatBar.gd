extends Control
class_name StatBar

## 顶部的一根属性条：图标 + 名称 + 数值 + 进度条 + 浮动增减提示。

const HEIGHT := 76.0
const BUMP_W := 68.0

var key := ""
var tint := Color.WHITE
var value := 0

var _val: Label
var _bar: ProgressBar
var _bump: Label
var _pv: Label
var _panel: StyleBoxFlat
var _bar_tween: Tween
var _pop_tween: Tween
var _bump_tween: Tween

func setup(k: String) -> void:
	key = k
	var def: Dictionary = GameData.STAT_DEFS[k]
	tint = def["color"] as Color
	custom_minimum_size = Vector2(0.0, HEIGHT)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = MOUSE_FILTER_IGNORE

	_panel = Ui.box(Color(1, 1, 1, 0.045), 14)
	_panel.set_border_width_all(1)
	_panel.border_color = Color(1, 1, 1, 0.07)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	Ui.ghost(head)
	Ui.place(head, Control.PRESET_TOP_WIDE, 10, 10, -10, 26)
	add_child(head)

	var icon := StatIcon.new()
	icon.custom_minimum_size = Vector2(15, 15)
	icon.setup(StatIcon.kind_for(k), tint)
	head.add_child(icon)

	var name_label := Label.new()
	name_label.text = str(def["name"])
	Fonts.apply(name_label, 11, Color("#c8cdd9"))
	head.add_child(name_label)

	_val = Label.new()
	_val.text = "0"
	_val.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	Fonts.apply(_val, 24, tint, "serif")
	Ui.place(_val, Control.PRESET_TOP_WIDE, 10, 27, -10, 62)
	add_child(_val)

	_bar = ProgressBar.new()
	_bar.min_value = 0.0
	_bar.max_value = 100.0
	_bar.step = 0.1
	_bar.show_percentage = false
	Ui.ghost(_bar)
	_bar.add_theme_stylebox_override("background", Ui.box(Color(1, 1, 1, 0.10), 3))
	_bar.add_theme_stylebox_override("fill", Ui.box(tint, 3))
	Ui.place(_bar, Control.PRESET_BOTTOM_WIDE, 10, -13, -10, -8)
	add_child(_bar)

	_bump = Label.new()
	_bump.text = ""
	_bump.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_bump.custom_minimum_size = Vector2(BUMP_W, 0)
	_bump.modulate.a = 0.0
	_bump.size = Vector2(BUMP_W, 20)
	Ui.ghost(_bump)
	add_child(_bump)

	# 拖卡预览用的 "+N/-N" 小标，位于数值行右侧，平时隐藏
	_pv = Label.new()
	_pv.text = ""
	_pv.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_pv.custom_minimum_size = Vector2(BUMP_W, 0)
	_pv.modulate.a = 0.0
	_pv.size = Vector2(BUMP_W, 20)
	Fonts.apply(_pv, 16, Color("#7fd6a8"), "bold")
	Ui.ghost(_pv)
	add_child(_pv)

func _draw() -> void:
	draw_style_box(_panel, Rect2(Vector2.ZERO, size))

func set_value(v: int, animate: bool) -> void:
	value = v
	_val.text = str(v)
	if _bar_tween != null and _bar_tween.is_valid():
		_bar_tween.kill()
	if animate:
		_bar_tween = create_tween()
		_bar_tween.tween_property(_bar, "value", float(v), 0.7)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		_bar.value = float(v)
		if _bump_tween != null and _bump_tween.is_valid():
			_bump_tween.kill()
		_bump.text = ""
		_bump.modulate.a = 0.0

## 数值变化时冒出的 "+28 / -18"，同时让数字弹一下
func bump(delta: int) -> void:
	_bump.text = ("+" if delta > 0 else "") + str(delta)
	_bump.add_theme_color_override("font_color", Color("#7fd6a8") if delta > 0 else Color("#f09292"))
	var base_y := 26.0
	_bump.position = Vector2(size.x - 10.0 - BUMP_W, base_y)
	_bump.modulate.a = 0.0

	if _bump_tween != null and _bump_tween.is_valid():
		_bump_tween.kill()
	_bump_tween = create_tween()
	_bump_tween.tween_property(_bump, "modulate:a", 1.0, 0.22)
	_bump_tween.parallel().tween_property(_bump, "position:y", base_y - 18.0, 0.9)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_bump_tween.parallel().tween_property(_bump, "modulate:a", 0.0, 0.68).set_delay(0.22)

	_val.pivot_offset = _val.size * 0.5
	if _pop_tween != null and _pop_tween.is_valid():
		_pop_tween.kill()
	_pop_tween = create_tween()
	_pop_tween.tween_property(_val, "scale", Vector2(1.32, 1.32), 0.16)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_pop_tween.tween_property(_val, "scale", Vector2.ONE, 0.19)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

# 拖卡加分预览效果已按需求注释：
# ## 拖卡预览：在数值行右侧浮现 "+N / -N" 小标，透明度随拖动强度变化。
# ## 传 delta=0 或 strength=0 即清除预览。
# func preview(delta: int, strength: float) -> void:
# 	if _pv == null:
# 		return
# 	if delta == 0 or strength <= 0.02:
# 		if _pv.modulate.a > 0.0:
# 			_pv.text = ""
# 			_pv.modulate.a = 0.0
# 		return
# 	_pv.text = ("+" if delta > 0 else "") + str(delta)
# 	_pv.add_theme_color_override("font_color", Color("#7fd6a8") if delta > 0 else Color("#f09292"))
# 	_pv.position = Vector2(size.x - 10.0 - BUMP_W, 24.0)
# 	_pv.modulate.a = clampf(strength, 0.15, 1.0)
