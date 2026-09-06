extends Control
class_name CardView

## 一张卡牌。标准扑克牌比例 5:7（2.5×3.5 英寸），圆角半径约为宽度的 5~6%。
## 卡牌类型：
##   day        第 N 天封面（图片路径写死在卡片逻辑里）
##   event      事件卡（选项按 上/左/右 方向滑动触发；数量决定呈现）
##   result     结果卡
##   settlement 每日结算卡
##   ending     结局卡（替换结算卡出现，滑动后重新开始）
## 所有卡牌统一为「空白扑克」外形：米白底 + 中性描边。花色色仅用于选项点缀。
## 布局：事件卡（含时间卡）分上下两等份——上半为事件名（固定位置）+ 描述（居中），
##       下半按动态选项数摆放选项；结果/结算/结局卡不分上下半，标题+描述整体居中。

signal released(dir: String)

const THRESH := 90.0
const RATIO := 5.0 / 7.0          # 扑克牌宽:高
const CARD_FRAC := 0.7            # 占舞台高度的比例（≈ 2/3 屏）
const DAY_ART := ""               # 每日时间卡背景图（全图置空策略，待按 IMAGE_LIST 统一导入后填写）
const SETTLE_ART := ""            # 每日结算卡背景图（同上）

var _card: Dictionary = {}
var _color: Color = Color("#c9b27a")
var _active_dirs: Array[String] = []
var _option_count := 0
var _interactive := true
var _image_path := ""

var _bg: StyleBoxFlat
var _bg_panel: Panel
var _img: TextureRect
var _margin: MarginContainer
var _top_vbox: VBoxContainer
var _title_lbl: Label
var _desc_lbl: Label
var _card_w := 0.0
var _card_h := 0.0

var _title_text := ""
var _desc_text := ""
var _title_color := Color.WHITE
var _desc_color := Color.WHITE
var _title_style := ""
var _desc_style := ""
const TITLE_SIZE := 24   # 全部卡牌标题统一字号
const DESC_SIZE := 18    # 全部描述文本统一字号（文本过多放不下时才收缩防出界）
var _split_ratio := 0.5   # 事件/时间卡上半区占比
var _centered := false     # 居中布局（结果/结算/结局卡，无上下两半）

var _base := Vector2.ZERO
var _dragging := false
var _start := Vector2.ZERO
var _offset := Vector2.ZERO
var _back_tween: Tween

func _ready() -> void:
	# 左上角锚点：尺寸和位置由 _layout_card 显式设置，这样可精确控制扑克牌矩形。
	Ui.place(self, Control.PRESET_TOP_LEFT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)

func configure(card: Dictionary, day: int, color: Color) -> void:
	_card = card
	_color = color
	_interactive = true
	_base = Vector2.ZERO
	_active_dirs.clear()
	for o: Dictionary in card.get("active_options", []):
		_active_dirs.append(str(o.get("dir", "")))
	_option_count = _active_dirs.size()
	_clear_children()
	_image_path = _resolve_image_path(card)
	_build_style()
	match card["kind"]:
		"day":        _build_day(card, day)
		"event":      _build_event(card, day)
		"result":     _build_result(card)
		"settlement": _build_settlement(card, day)
		"ending":     _build_ending(card)
	_layout_card()
	if get_parent() != null and not get_parent().resized.is_connected(_layout_card):
		get_parent().resized.connect(_layout_card)

func _resolve_image_path(card: Dictionary) -> String:
	match card["kind"]:
		"day":        return DAY_ART
		"settlement": return SETTLE_ART
		"event":      return str(card["event"].get("art", ""))
		"result", "ending": return str(card.get("art", ""))
	return ""

# ----------------------------------------------------------------- 样式

func _build_style() -> void:
	_bg = StyleBoxFlat.new()
	_bg.bg_color = Color("#f6f1e6")          # 统一空白扑克底
	_bg.border_color = Color("#c9b27a")      # 统一中性描边
	_bg.shadow_color = Color(0, 0, 0, 0.45)
	_bg.shadow_size = 22
	_bg.shadow_offset = Vector2(0, 12)
	_bg_panel = Panel.new()
	Ui.place(_bg_panel, Control.PRESET_FULL_RECT)
	_bg_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg_panel.add_theme_stylebox_override("panel", _bg)
	add_child(_bg_panel)
	# 背景图：居中、约占卡牌 1/2，作为背景层（在文字之下）
	if _image_path != "":
		var tex := load("res://art/" + _image_path + ".png") as Texture2D
		if tex != null:
			_img = TextureRect.new()
			_img.texture = tex
			_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			_img.modulate = Color(1, 1, 1, 0.35)   # q 版配图淡化至 35% 可见度
			Ui.ghost(_img)
			Ui.place(_img, Control.PRESET_BOTTOM_RIGHT)   # 位置偏右下角（偏移按卡牌尺寸在 _layout_card 计算）
			add_child(_img)

func _clear_children() -> void:
	for c in get_children():
		if c != null:
			c.queue_free()
	_bg = null
	_bg_panel = null
	_img = null
	_margin = null
	_top_vbox = null
	_title_lbl = null
	_desc_lbl = null

# ----------------------------------------------------------------- 两等份骨架

func _build_split() -> void:
	_centered = false
	_margin = MarginContainer.new()
	Ui.ghost(_margin)
	Ui.place(_margin, Control.PRESET_FULL_RECT)
	add_child(_margin)
	var split := VBoxContainer.new()
	Ui.ghost(split)
	split.add_theme_constant_override("separation", 0)
	_margin.add_child(split)
	var top := Control.new()
	top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	top.clip_contents = true
	Ui.ghost(top)
	split.add_child(top)
	var bottom := Control.new()
	bottom.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bottom.clip_contents = true
	Ui.ghost(bottom)
	split.add_child(bottom)
	_top_vbox = VBoxContainer.new()
	_top_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	Ui.ghost(_top_vbox)
	Ui.place(_top_vbox, Control.PRESET_FULL_RECT)
	top.add_child(_top_vbox)
	_title_lbl = Label.new()
	_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Ui.ghost(_title_lbl)
	_top_vbox.add_child(_title_lbl)
	_desc_lbl = Label.new()
	_desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_desc_lbl.add_theme_constant_override("line_spacing", 4)
	Ui.ghost(_desc_lbl)
	_top_vbox.add_child(_desc_lbl)

func _build_bottom_hint(t: String, parent: Control = null) -> void:
	var c := CenterContainer.new()
	Ui.ghost(c)
	if parent != null:
		# 居中布局：提示固定在卡片底部
		c.custom_minimum_size = Vector2(0, 40)
		c.size_flags_vertical = Control.SIZE_SHRINK_END
		parent.add_child(c)
	else:
		Ui.place(c, Control.PRESET_FULL_RECT)
		c.offset_top = 32.0   # 提示文字整体下移一点（内容中心下移 16px）
		var bottom: Control = _margin.get_child(0).get_child(1)
		bottom.add_child(c)
	var l := Label.new()
	l.text = t
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	Fonts.apply(l, 13, Color("#9a9080"))
	Ui.ghost(l)
	c.add_child(l)

## 居中布局（结果/结算/结局卡）：不分上下两半，标题在上、描述撑满剩余空间居中。
## 返回 VBox，供底部提示挂载。
func _build_centered() -> VBoxContainer:
	_centered = true
	_margin = MarginContainer.new()
	Ui.ghost(_margin)
	Ui.place(_margin, Control.PRESET_FULL_RECT)
	add_child(_margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	Ui.ghost(vbox)
	_margin.add_child(vbox)
	_title_lbl = Label.new()
	_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Ui.ghost(_title_lbl)
	vbox.add_child(_title_lbl)
	_desc_lbl = Label.new()
	_desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_desc_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_desc_lbl.add_theme_constant_override("line_spacing", 4)
	Ui.ghost(_desc_lbl)
	vbox.add_child(_desc_lbl)
	return vbox

# ----------------------------------------------------------------- 各类卡牌

func _build_day(card: Dictionary, day: int) -> void:
	_title_text = "第 %d 天" % day
	_desc_text = "封控第 %d 日" % day
	_title_color = Color("#272b33"); _desc_color = Color("#8a8070")
	_title_style = "serif-bold"; _desc_style = ""
	_build_split()
	_build_bottom_hint("滑动任意方向，开始这一天")

func _build_event(card: Dictionary, day: int) -> void:
	var ev: Dictionary = card["event"]
	_title_text = str(ev.get("title", ""))
	_desc_text = str(ev.get("desc", ""))
	_title_color = Color("#272b33"); _desc_color = Color("#5b5f6a")
	_title_style = "serif-bold"; _desc_style = ""
	_build_split()
	if _option_count == 0:
		# 无选项事件（如接龙开场）：沿用既有的灰色提示，任意方向滑动
		_build_bottom_hint("滑动任意方向，继续")
	else:
		_build_options(card.get("active_options", []))

func _build_result(card: Dictionary) -> void:
	_title_text = str(card.get("title", ""))
	_desc_text = str(card.get("text", ""))
	_title_color = Color("#8a8070"); _desc_color = Color("#272b33")
	_title_style = "serif"; _desc_style = ""
	var vbox: VBoxContainer = _build_centered()   # 结果卡：整体居中，不分上下半
	_build_bottom_hint("滑动任意方向，继续", vbox)

func _build_settlement(card: Dictionary, day: int) -> void:
	_title_text = "第 %d 天 · 结算" % day
	_desc_text = str(card.get("tips", ""))   # 五池结算提示，逐行居中
	_title_color = Color("#272b33"); _desc_color = Color("#8a8070")
	_title_style = "serif-bold"; _desc_style = ""
	var vbox: VBoxContainer = _build_centered()   # 结算卡：整体居中，不分上下半
	_build_bottom_hint("滑动任意方向，进入次日", vbox)

func _build_ending(card: Dictionary) -> void:
	## 结局卡：替换原结算卡出现；title + 文本居中 + 结局配图（art），滑动后重新开始
	_title_text = str(card.get("title", ""))
	_desc_text = str(card.get("text", ""))
	_title_color = Color("#272b33"); _desc_color = Color("#272b33")
	_title_style = "serif-bold"; _desc_style = ""
	var vbox: VBoxContainer = _build_centered()   # 结局卡：整体居中，不分上下半
	_build_bottom_hint("滑动任意方向，重新开始", vbox)

# ----------------------------------------------------------------- 选项（下半部分 左/上/右）

## 简洁选项：无框、无数值提示、黑色粗体。
## 位置：左选项→下半部分偏左居中；右选项→偏右居中；上选项→偏上中心。

func _build_options(opts: Array) -> void:
	var bottom: Control = _margin.get_child(0).get_child(1)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	Ui.ghost(row)
	Ui.place(row, Control.PRESET_FULL_RECT)
	bottom.add_child(row)
	# 三等分列：左列 / 中列 / 右列
	var cols: Array[VBoxContainer] = []
	for i in 3:
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.add_theme_constant_override("separation", 6)
		Ui.ghost(col)
		row.add_child(col)
		cols.append(col)
	cols[1].alignment = BoxContainer.ALIGNMENT_BEGIN  # 上选项贴下半部分顶部
	for o: Dictionary in opts:
		var slot := _make_slot(o)
		var d := str(o.get("dir", ""))
		if d == "up":
			cols[1].add_child(slot)
		elif d == "left":
			cols[0].add_child(slot)
		elif d == "right":
			cols[2].add_child(slot)

func _make_slot(opt: Dictionary) -> Control:
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	Ui.ghost(box)
	# 选项可单独带图（无则默认留空白；art 字段保留供批量导入）
	var art_id := str(opt.get("art", ""))
	if art_id != "":
		var tex := load("res://art/" + art_id + ".png") as Texture2D
		if tex != null:
			var ir := TextureRect.new()
			ir.texture = tex
			ir.custom_minimum_size = Vector2(48, 48)
			ir.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			ir.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			ir.modulate = Color(1, 1, 1, 0.35)   # 选项配图统一 35%
			Ui.ghost(ir)
			box.add_child(ir)
	var head := Label.new()
	head.text = str(opt.get("label", ""))
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	Fonts.apply(head, 15, Color("#272b33"), "bold")
	Ui.ghost(head)
	box.add_child(head)
	return box

# ----------------------------------------------------------------- 自适应布局

func _layout_card() -> void:
	if _bg == null or get_parent() == null:
		return
	var avail: Vector2 = (get_parent() as Control).size
	if avail.x <= 0 or avail.y <= 0:
		return
	var h: float = avail.y * CARD_FRAC
	var w: float = h * RATIO
	if w > avail.x * 0.95:
		w = avail.x * 0.95
		h = w / RATIO
	w = int(w); h = int(h)
	_card_w = w; _card_h = h
	custom_minimum_size = Vector2(w, h)
	size = Vector2(w, h)
	position = (avail - size) / 2.0
	# 圆角与描边随卡牌等比缩放（标准扑克圆角 ≈ 宽度的 5~6%）
	var r := maxi(8, int(w * 0.06))
	_bg.set_corner_radius_all(r)
	_bg.set_border_width_all(maxi(2, int(w * 0.006)))
	if _margin != null:
		var m := int(w * 0.07)
		_margin.add_theme_constant_override("margin_left", m)
		_margin.add_theme_constant_override("margin_right", m)
		_margin.add_theme_constant_override("margin_top", int(h * 0.05))
		_margin.add_theme_constant_override("margin_bottom", int(h * 0.05))
	if _img != null and _img.texture != null:
		# q 版配图加大（约 0.62 卡宽），贴右下角且稍微向右探
		var side := int(minf(w, h) * 0.62)
		var mr := int(w * 0.02)
		var mb := int(w * 0.05)
		_img.offset_left = -side - mr
		_img.offset_top = -side - mb
		_img.offset_right = -mr
		_img.offset_bottom = -mb
	_fit_texts()
	_base = position

func _fit_texts() -> void:
	if _title_lbl == null:
		return
	_title_lbl.text = _title_text
	_desc_lbl.text = _desc_text
	var inner_w := _card_w * 0.86
	var top_h := _card_h * _split_ratio - _card_h * 0.05 * 2
	# 标题：全部卡牌统一字号（仅当极端超宽时才收缩，防出界）
	var ts := _fit_font(_title_text, inner_w, top_h * 0.45, TITLE_SIZE, 16, _title_style)
	Fonts.apply(_title_lbl, ts, _title_color, _title_style)
	var title_h := _title_lbl.get_minimum_size().y
	# 描述：全部卡牌统一字号（放不下时按真实换行高度收缩防出界）
	var desc_max: float
	if _centered:
		desc_max = maxf(12.0, _card_h * 0.9 - title_h - 46.0)   # 居中布局：近似整卡高度（扣标题/底部提示）
	else:
		desc_max = maxf(12.0, top_h - title_h - 6.0)
	var ds := _fit_font_wrapped(_desc_text, inner_w, desc_max, DESC_SIZE, 10, Fonts.regular())
	Fonts.apply(_desc_lbl, ds, _desc_color, _desc_style)

func _fit_font(text: String, max_w: float, max_h: float, max_size: int, min_size: int, style: String) -> int:
	if text == "":
		return min_size
	var font: Font
	if style.contains("serif"):
		font = Fonts.serif()
	elif style.contains("bold"):
		font = Fonts.bold()
	else:
		font = Fonts.regular()
	var size := max_size
	while size > min_size:
		var s := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, max_w, size)
		if s.y <= max_h:
			return size
		size -= 1
	return min_size

## 换行感知的字号自适应：get_string_size 不含自动换行，
## 用 TextParagraph 按真实折行高度测量（描述文本专用）。
func _fit_font_wrapped(text: String, max_w: float, max_h: float, max_size: int, min_size: int, font: Font) -> int:
	if text == "":
		return min_size
	var size := max_size
	while size > min_size:
		var para := TextParagraph.new()
		para.add_string(text, font, size)
		para.set_width(max_w)
		para.set_line_spacing(4.0)
		var s: Vector2 = para.get_size()
		if s.y <= max_h:
			return size
		size -= 1
	return min_size

# ----------------------------------------------------------------- 交互

func _on_gui_input(event: InputEvent) -> void:
	if not _interactive:
		return
	if event is InputEventMouseButton:
		if event.button_index != MOUSE_BUTTON_LEFT:
			return
		if event.pressed:
			_dragging = true
			_start = get_global_mouse_position()
			_offset = Vector2.ZERO
			get_viewport().set_input_as_handled()
		elif _dragging:
			_dragging = false
			get_viewport().set_input_as_handled()
			_on_release()
	elif event is InputEventMouseMotion and _dragging:
		_offset = get_global_mouse_position() - _start
		_apply_drag(_offset)
		get_viewport().set_input_as_handled()

func _on_release() -> void:
	var dir := _dir_of(_offset)
	if dir == "":
		return_to_center()
		return
	if _card.get("kind", "") == "event":
		if _option_count == 0 or dir in _active_dirs:
			released.emit(dir)
		else:
			return_to_center()
	else:
		released.emit(dir)

func _dir_of(v: Vector2) -> String:
	if v.length() < THRESH:
		return ""
	if abs(v.x) >= abs(v.y):
		return "left" if v.x < 0.0 else "right"
	return "up"

func _apply_drag(v: Vector2) -> void:
	position = _base + v
	rotation_degrees = clamp(v.x * 0.04, -18.0, 18.0)
	_bg_panel.modulate = Color.WHITE.lerp(_color, clamp(abs(v.x) / 120.0, 0.0, 1.0))

func return_to_center() -> void:
	if _back_tween != null and _back_tween.is_valid():
		_back_tween.kill()
	_back_tween = create_tween()
	_back_tween.set_parallel(true)
	_back_tween.tween_property(self, "position", _base, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_back_tween.tween_property(self, "rotation_degrees", 0.0, 0.4)
	_bg_panel.modulate = Color.WHITE

func fly_out(dir: int) -> void:
	_interactive = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var off := Vector2(float(dir) * 900.0, -40.0) if dir != 0 else Vector2(0.0, -900.0)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "position", position + off, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "modulate:a", 0.0, 0.4)
