extends Control
class_name Card

## 一张卡牌。最上面那张可以拖动：左滑否定 / 右滑确认。
## 后方的卡牌只显示分类与标题，并做缩放 + 旋转堆叠。

signal released(dx: float)
# 拖卡加分预览效果已按需求注释，以下信号与发射点一并停用：
# ## 拖动过程实时上报方向与力度：side=-1 指左(左选项)，+1 指右(右选项)，0 无方向；strength 0..1
# signal previewed(side: int, strength: float)

const STACK_ROT: Array[float] = [-2.4, 2.2, -1.6]
const CARD_MAX_W := 460.0
const CARD_RATIO := 1.42

var interactive := false
var stack_index := 0

var _data: Dictionary = {}
var _flags: Dictionary = {}
var _detailed := false
var _bg: StyleBoxFlat
var _left_mark: PanelContainer
var _right_mark: PanelContainer
var _base := Vector2.ZERO
var _glow := 0.0
var _dragging := false
var _start := Vector2.ZERO
var _offset := Vector2.ZERO
var _back_tween: Tween
var _pointer_id := -2 # -2 none, -1 mouse, >= 0 touch index
var _description: RichTextLabel

func configure(data: Dictionary, number: int, total: int, detailed: bool, stack_pos: int, deck_size: Vector2, flags: Dictionary = {}) -> void:
	_data = data
	_detailed = detailed
	_flags = flags
	interactive = detailed and bool(data.get("swipe_enabled", true))
	stack_index = stack_pos
	mouse_filter = MOUSE_FILTER_STOP if detailed else MOUSE_FILTER_IGNORE
	_build_style()
	_build_content(number, total)
	if interactive: _build_marks()
	apply_stack(stack_pos, deck_size)

## 取某选项的"实际生效版本"（已应用 alt 覆盖）
func _option_for(accept: bool) -> Dictionary:
	var raw: Dictionary = (_data["right"] if accept else _data["left"]) as Dictionary
	return GameData.resolve_option(raw, _flags)

func _build_style() -> void:
	_bg = StyleBoxFlat.new()
	_bg.bg_color = Color("#f4ecd7")
	_bg.set_corner_radius_all(22)
	_bg.shadow_color = Color(0.10, 0.06, 0.02, 0.42)
	_bg.shadow_size = 22
	_bg.shadow_offset = Vector2(0, 12)

## 摆放到堆叠中的第 pos 层（0 = 最顶端）
func apply_stack(pos: int, deck_size: Vector2) -> void:
	stack_index = pos
	var cw := minf(deck_size.x * 0.92, CARD_MAX_W)
	var ch := maxf(minf(deck_size.y - 50.0, cw * CARD_RATIO), 120.0)
	size = Vector2(cw, ch)
	pivot_offset = size * 0.5
	_base = Vector2((deck_size.x - cw) * 0.5, (deck_size.y - ch) * 0.5)
	if pos == 0:
		position = _base
		rotation_degrees = 0.0
		scale = Vector2.ONE
		z_index = 100
	else:
		scale = Vector2.ONE * (1.0 - float(pos) * 0.045)
		position = _base + Vector2(0.0, float(pos) * 15.0)
		rotation_degrees = STACK_ROT[(pos - 1) % STACK_ROT.size()]
		z_index = 100 - pos
	_reposition_marks()
	queue_redraw()

# ------------------------------------------------------------------ 内容

func _build_content(number: int, total: int) -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	Ui.ghost(margin)
	Ui.place(margin, Control.PRESET_FULL_RECT)
	add_child(margin)

	var vbox := VBoxContainer.new()
	Ui.ghost(vbox)
	margin.add_child(vbox)

	var top := HBoxContainer.new()
	Ui.ghost(top)
	vbox.add_child(top)
	top.add_child(_pill(str(_data["cat"])))
	top.add_child(_expand_spacer())
	if _detailed:
		var meta := Label.new()
		meta.text = "%02d / %d" % [number, total]
		Fonts.apply(meta, 12, Color("#a8a294"), "serif")
		top.add_child(meta)

	if _detailed:
		vbox.add_child(Ui.spacer(8.0))
		_add_art(vbox)
		vbox.add_child(Ui.spacer(6.0))
	else:
		vbox.add_child(Ui.spacer(10.0))

	var title := Label.new()
	title.text = str(_data["title"])
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	Fonts.apply(title, 25 if _detailed else 18, Color("#3a2d1c"), "serif-bold")
	vbox.add_child(title)

	if _detailed:
		vbox.add_child(Ui.spacer(10.0))
		var desc := RichTextLabel.new()
		_description = desc
		desc.text = str(_data["desc"])
		desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
		desc.custom_minimum_size.y = 80
		desc.mouse_filter = Control.MOUSE_FILTER_PASS
		desc.add_theme_font_override("normal_font", Fonts.regular())
		desc.add_theme_font_size_override("normal_font_size", 17)
		desc.add_theme_color_override("default_color", Color("#6b5d47"))
		desc.add_theme_constant_override("line_separation", 5)
		vbox.add_child(desc)

	if not _detailed: vbox.add_child(Ui.spacer(0.0, true))

	if _detailed and not _data.get("hide_effects", false):
		vbox.add_child(_effects_row())

	_build_top_line()

func _add_art(vbox: VBoxContainer) -> void:
	var art_id: String = str(_data.get("art", ""))
	if art_id == "":
		return
	var tex := load("res://assets/textures/cards/" + art_id + ".png") as Texture2D
	if tex == null:
		return
	var sz := tex.get_size()
	var max_w := 460.0
	var max_h := 150.0
	var k := minf(max_w / sz.x, max_h / sz.y)
	var w := sz.x * k
	var h := sz.y * k
	var box := CenterContainer.new()
	box.custom_minimum_size = Vector2(0, h)
	Ui.ghost(box)
	var rect := TextureRect.new()
	rect.texture = tex
	rect.custom_minimum_size = Vector2(w, h)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	Ui.ghost(rect)
	box.add_child(rect)
	vbox.add_child(box)

func _build_top_line() -> void:
	var grad := Gradient.new()
	grad.set_color(0, Color("#c99a3e"))
	grad.set_color(1, Color("#c99a3e"))
	grad.add_point(0.5, Color("#e7c985"))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = 256
	tex.height = 8
	var rect := TextureRect.new()
	rect.texture = tex
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	Ui.ghost(rect)
	Ui.place(rect, Control.PRESET_TOP_WIDE, 18, 0, -18, 5)
	add_child(rect)

func _effects_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	Ui.ghost(row)
	row.add_child(_effect_col(false))
	row.add_child(_effect_col(true))
	return row

func _effect_col(accept: bool) -> Control:
	var opt: Dictionary = _option_for(accept)
	var eff: Dictionary = opt.get("effects", {})
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Ui.ghost(panel)
	# 不做红/绿正反暗示，两栏统一中性底
	panel.add_theme_stylebox_override("panel",
		Ui.box(Color("#efe7d2"), 14, 10, 10, 10, 12))

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	Ui.ghost(vbox)
	panel.add_child(vbox)

	var head := Label.new()
	head.text = ("左 · " if not accept else "右 · ") + str(opt.get("label", "确认" if accept else "否定"))
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Fonts.apply(head, 12, Color("#6b6f7a"), "bold")
	vbox.add_child(head)

	var flow := FlowContainer.new()
	flow.add_theme_constant_override("h_separation", 4)
	flow.add_theme_constant_override("v_separation", 4)
	Ui.ghost(flow)
	vbox.add_child(flow)
	for k in GameData.STAT_KEYS:
		var d := int(eff.get(k, 0))
		if d != 0:
			flow.add_child(_chip(d, k))
	return panel

func _chip(delta: int, key: String) -> Control:
	var plus := delta > 0
	var panel := PanelContainer.new()
	Ui.ghost(panel)
	panel.add_theme_stylebox_override("panel",
		Ui.box(Color("#3f9d6c", 0.16) if plus else Color("#cf4f4f", 0.14), 6, 6, 2, 6, 2))
	var label := Label.new()
	label.text = "%s%d %s" % ["+" if plus else "", delta, (GameData.STAT_DEFS[key] as Dictionary)["name"]]
	Fonts.apply(label, 11, Color("#2f7a52") if plus else Color("#b54040"), "bold")
	panel.add_child(label)
	return panel

func _pill(text: String) -> Control:
	var panel := PanelContainer.new()
	Ui.ghost(panel)
	var sb := Ui.box(Color(1, 1, 1, 0.0), 999, 10, 3, 10, 3)
	sb.set_border_width_all(1)
	sb.border_color = Color("#c99a3e")
	panel.add_theme_stylebox_override("panel", sb)
	var label := Label.new()
	label.text = text
	Fonts.apply(label, 11, Color("#c99a3e"))
	panel.add_child(label)
	return panel

func _expand_spacer() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Ui.ghost(c)
	return c

# -------------------------------------------------------------- 拖拽标记

func _build_marks() -> void:
	var left_label: String = str(_option_for(false).get("label", "否定"))
	var right_label: String = str(_option_for(true).get("label", "确认"))
	# 不做红/绿区分：左右只是两种选择
	_left_mark = _mark(left_label, Color("#c99a3e"), -8.0)
	_right_mark = _mark(right_label, Color("#c99a3e"), 8.0)
	add_child(_left_mark)
	add_child(_right_mark)
	_left_mark.size = _left_mark.get_combined_minimum_size()
	_right_mark.size = _right_mark.get_combined_minimum_size()
	_left_mark.modulate.a = 0.0
	_right_mark.modulate.a = 0.0
	_reposition_marks()

func _mark(text: String, color: Color, rot: float) -> PanelContainer:
	var panel := PanelContainer.new()
	Ui.ghost(panel)
	var sb := Ui.box(Color(1, 1, 1, 0.0), 10, 16, 4, 16, 4)
	sb.set_border_width_all(3)
	sb.border_color = color
	panel.add_theme_stylebox_override("panel", sb)
	var label := Label.new()
	label.text = text
	label.custom_minimum_size.x = 280
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	Fonts.apply(label, 18, color, "serif-bold")
	panel.add_child(label)
	panel.rotation_degrees = rot
	return panel

func _reposition_marks() -> void:
	if _left_mark == null or _right_mark == null:
		return
	_left_mark.position = Vector2(22.0, 34.0)
	_left_mark.pivot_offset = _left_mark.size * 0.5
	_right_mark.position = Vector2(size.x - 22.0 - _right_mark.size.x, 34.0)
	_right_mark.pivot_offset = _right_mark.size * 0.5

# ---------------------------------------------------------------- 交互

func _input(event: InputEvent) -> void:
	# Observe the whole card before RichTextLabel consumes a mouse/touch press.
	# Only claim horizontal gestures; scrollbars and vertical reading remain usable.
	if not interactive:
		_pointer_id = -2
		_dragging = false
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed: _begin_pointer(-1, event.position)
		elif _pointer_id == -1: _end_pointer(event.position)
	elif event is InputEventMouseMotion and _pointer_id == -1:
		_move_pointer(event.position)
	elif event is InputEventScreenTouch:
		if event.pressed: _begin_pointer(event.index, event.position)
		elif _pointer_id == event.index:
			if event.canceled: return_to_center()
			else: _end_pointer(event.position)
	elif event is InputEventScreenDrag and _pointer_id == event.index:
		_move_pointer(event.position)

func _begin_pointer(id: int, point: Vector2) -> void:
	if _pointer_id != -2: return
	var area := get_parent() as Control
	if area != null and area.clip_contents and not area.get_global_rect().has_point(point): return
	var local_point := get_global_transform_with_canvas().affine_inverse() * point
	if not Rect2(Vector2.ZERO, size).has_point(local_point): return
	if _description != null:
		var scrollbar := _description.get_v_scroll_bar()
		if scrollbar.visible and scrollbar.get_global_rect().has_point(point): return
	if _back_tween != null and _back_tween.is_valid(): _back_tween.kill()
	_pointer_id = id
	_start = point
	_offset = Vector2.ZERO
	_dragging = false

func _move_pointer(point: Vector2) -> void:
	_offset = point - _start
	if not _dragging:
		if absf(_offset.y) > 10 and absf(_offset.y) >= absf(_offset.x):
			_pointer_id = -2
			return
		if absf(_offset.x) < 10: return
		_dragging = true
	_apply_drag(Vector2(_offset.x, 0))
	get_viewport().set_input_as_handled()

func _end_pointer(point: Vector2) -> void:
	var was_dragging := _dragging
	_pointer_id = -2
	_dragging = false
	if was_dragging:
		# 拖卡加分预览效果已按需求注释：
		# previewed.emit(0, 0.0)
		get_viewport().set_input_as_handled()
		released.emit(point.x - _start.x)

func _apply_drag(v: Vector2) -> void:
	position = _base + v
	rotation_degrees = clampf(v.x * 0.055, -20.0, 20.0)
	var a := clampf(absf(v.x) / 90.0, 0.0, 1.0)
	_left_mark.modulate.a = a if v.x < 0.0 else 0.0
	_right_mark.modulate.a = a if v.x > 0.0 else 0.0
	_glow = clampf(v.x / 120.0, -1.0, 1.0)
	set_glow(_glow)
	# 拖卡加分预览效果已按需求注释：
	# var side := 0
	# if v.x < -4.0:
	# 	side = -1
	# elif v.x > 4.0:
	# 	side = 1
	# previewed.emit(side, a)

## 拖动手感光晕（中性金色，不分红/绿）
func set_glow(v: float) -> void:
	var base := Color(0, 0, 0, 0.42)
	var strength := clampf(absf(v), 0.0, 1.0)
	_bg.shadow_color = base.lerp(Color(0.78, 0.58, 0.22, 0.55), strength)
	queue_redraw()

func return_to_center() -> void:
	_pointer_id = -2
	_dragging = false
	# 拖卡加分预览效果已按需求注释：
	# previewed.emit(0, 0.0)
	if _back_tween != null and _back_tween.is_valid():
		_back_tween.kill()
	_back_tween = create_tween()
	_back_tween.set_parallel(true)
	_back_tween.tween_property(self, "position", _base, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_back_tween.tween_property(self, "rotation_degrees", 0.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if _left_mark != null:
		_back_tween.tween_property(_left_mark, "modulate:a", 0.0, 0.25)
		_back_tween.tween_property(_right_mark, "modulate:a", 0.0, 0.25)
	_back_tween.tween_method(set_glow, _glow, 0.0, 0.35)
	_glow = 0.0

func fly_out(dir: int) -> void:
	interactive = false
	mouse_filter = MOUSE_FILTER_IGNORE
	set_glow(float(dir))
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "position", position + Vector2(float(dir) * 900.0, -60.0), 0.45)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "rotation_degrees", rotation_degrees + float(dir) * 24.0, 0.45)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "modulate:a", 0.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func _draw() -> void:
	if _bg != null:
		draw_style_box(_bg, Rect2(Vector2.ZERO, size))
