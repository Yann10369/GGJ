extends Control
class_name ShoppingCard

## "接龙时间" 第二段：选择物资卡（m 选 n）。
## 与统一卡（CardView）同尺寸（5:7 扑克、等比圆角、居中 ~2/3 屏），
## 保留微信气泡绿配色与清单式勾选交互；无提交按钮——
## 选够数量后向任意方向滑动卡片完成采购（与其他卡片的滑动习惯一致）。

signal completed(effects: Dictionary, counters: Dictionary, result: String)

const THRESH := 90.0
const RATIO := 5.0 / 7.0          # 与 CardView 一致：扑克牌宽:高
const CARD_FRAC := 0.7            # 与 CardView 一致：占舞台高度比例
const BUBBLE := Color("#07c160")
const BUBBLE_LIGHT := Color("#95ec69")
const INK := Color("#0c5b2e")

var _items: Array[Dictionary] = []
var _choose := 3
var _show_count := 5
var _base_effect: Dictionary = {}
var _selected: Dictionary = {}    # id -> bool
var _rows: Array[CheckRow] = []
var _result_text := ""
var _counter: Label
var _prompt: Label
var _bg_sb: StyleBoxFlat

var _base := Vector2.ZERO
var _dragging := false
var _start := Vector2.ZERO
var _offset := Vector2.ZERO
var _back_tween: Tween

func setup(event: Dictionary, flags: Dictionary, master: Array, show_count: int, choose: int) -> void:
	_choose = choose
	_show_count = show_count
	_base_effect = event.get("base_effect", {})
	_items = _pick_random(master, show_count)
	_result_text = str(event.get("result_after", ""))
	_selected.clear()
	_build()
	_layout_card()

func _pick_random(master: Array, n: int) -> Array[Dictionary]:
	var pool: Array = master.duplicate(true)
	pool.shuffle()
	var out: Array[Dictionary] = []
	for i in range(mini(n, pool.size())):
		out.append(pool[i])
	return out

func _ready() -> void:
	# 与 CardView 相同：左上角锚点，尺寸/位置由 _layout_card 显式控制
	Ui.place(self, Control.PRESET_TOP_LEFT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)
	if get_parent() != null and not get_parent().resized.is_connected(_layout_card):
		get_parent().resized.connect(_layout_card)

# ----------------------------------------------------------------- 布局

func _layout_card() -> void:
	if get_parent() == null:
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
	custom_minimum_size = Vector2(w, h)
	size = Vector2(w, h)
	position = (avail - Vector2(w, h)) / 2.0
	_base = position
	if _bg_sb != null:
		# 圆角/描边随卡牌等比缩放，与统一卡一致
		_bg_sb.set_corner_radius_all(maxi(8, int(w * 0.06)))
		_bg_sb.set_border_width_all(maxi(2, int(w * 0.006)))

# ----------------------------------------------------------------- 构建

func _build() -> void:
	for c in get_children():
		c.queue_free()
	_rows.clear()

	_bg_sb = StyleBoxFlat.new()
	_bg_sb.bg_color = BUBBLE_LIGHT
	_bg_sb.border_color = BUBBLE
	var bg := Panel.new()
	Ui.place(bg, Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_theme_stylebox_override("panel", _bg_sb)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 26)
	margin.add_theme_constant_override("margin_bottom", 24)
	Ui.ghost(margin)
	Ui.place(margin, Control.PRESET_FULL_RECT)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	Ui.ghost(vbox)
	margin.add_child(vbox)

	var hint := Label.new()
	hint.text = "接龙采购 · 挑选 %d 件物资" % _show_count
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Fonts.apply(hint, 16, INK, "bold")
	Ui.ghost(hint)
	vbox.add_child(hint)

	_counter = Label.new()
	_counter.text = "已选 0 / %d" % _choose
	_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Fonts.apply(_counter, 13, INK)
	Ui.ghost(_counter)
	vbox.add_child(_counter)

	# 清单：打乱顺序后从上往下依次排列（单列，等距，行宽撑满）
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	Ui.ghost(list)
	vbox.add_child(list)

	for it in _items:
		var row := CheckRow.new()
		row.setup(str(it["name"]), str(it["id"]))
		row.toggled.connect(_on_row_toggled.bind(it["id"]))
		list.add_child(row)
		_rows.append(row)

	vbox.add_child(Ui.spacer(0.0, true))

	_prompt = Label.new()
	_prompt.text = "再选 %d 件" % _choose
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Fonts.apply(_prompt, 13, INK)
	Ui.ghost(_prompt)
	vbox.add_child(_prompt)

# ----------------------------------------------------------------- 交互

func _selected_count() -> int:
	var n := 0
	for k in _selected:
		if _selected[k]:
			n += 1
	return n

func _on_row_toggled(on: bool, id: String) -> void:
	_selected[id] = on
	_refresh()

func _refresh() -> void:
	var n := _selected_count()
	_counter.text = "已选 %d / %d" % [n, _choose]
	if n >= _choose:
		_prompt.text = "已选够，向任意方向滑动提交"
	else:
		_prompt.text = "再选 %d 件" % (_choose - n)

func _toggle_at(global_point: Vector2) -> void:
	for row in _rows:
		if row.get_global_rect().has_point(global_point):
			if row.is_on() and _selected.get(row._id, false):
				_selected[row._id] = false
				row.toggle()
			elif not row.is_on() and _selected_count() < _choose:
				_selected[row._id] = true
				row.toggle()
			return

func _on_gui_input(event: InputEvent) -> void:
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
			if _offset.length() > THRESH:
				if _selected_count() >= _choose:
					_finish()
				else:
					_return_to_center()
			elif _offset.length() < 8.0:
				_return_to_center()
				_toggle_at(get_global_mouse_position())
			else:
				_return_to_center()
	elif event is InputEventMouseMotion and _dragging:
		_offset = get_global_mouse_position() - _start
		position = _base + _offset
		rotation_degrees = clamp(_offset.x * 0.04, -18.0, 18.0)
		get_viewport().set_input_as_handled()

## 键盘方向键等效滑动（选够才会提交）
func try_confirm() -> void:
	if _selected_count() >= _choose:
		_finish()

func _return_to_center() -> void:
	if _back_tween != null and _back_tween.is_valid():
		_back_tween.kill()
	_back_tween = create_tween()
	_back_tween.set_parallel(true)
	_back_tween.tween_property(self, "position", _base, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_back_tween.tween_property(self, "rotation_degrees", 0.0, 0.35)

# ----------------------------------------------------------------- 提交

func _finish() -> void:
	var eff: Dictionary = {}
	var counters: Dictionary = {}
	for it in _items:
		if _selected.get(it["id"], false):
			for k in it.get("eff", {}):
				eff[k] = int(eff.get(k, 0)) + int(it["eff"][k])
			if it.has("counter"):
				counters[it["counter"]] = int(counters.get(it["counter"], 0)) + 1
	for k in _base_effect:
		eff[k] = int(eff.get(k, 0)) + int(_base_effect[k])
	completed.emit(eff, counters, _result_text)

# ----------------------------------------------------------------- 清单行

class CheckRow extends Control:
	signal toggled(on: bool)
	var _on := false
	var _label := ""
	var _id := ""

	func setup(label: String, id: String) -> void:
		_label = label
		_id = id
		custom_minimum_size = Vector2(0, 46)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func is_on() -> bool:
		return _on

	func toggle() -> void:
		_on = not _on
		queue_redraw()
		toggled.emit(_on)

	func _draw() -> void:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("#ffffff", 0.55)
		sb.set_corner_radius_all(12)
		draw_style_box(sb, Rect2(0.0, 4.0, size.x, size.y - 8.0))
		var r := 15.0
		var cx := 22.0
		var cy := size.y * 0.5
		var csb := StyleBoxFlat.new()
		csb.bg_color = Color("#07c160") if _on else Color("#ffffff")
		csb.set_corner_radius_all(int(r))
		csb.border_color = Color("#07c160")
		csb.set_border_width_all(2)
		draw_style_box(csb, Rect2(cx - r, cy - r, r * 2.0, r * 2.0))
		if _on:
			draw_line(Vector2(cx - 7.0, cy), Vector2(cx - 2.0, cy + 6.0), Color("#ffffff"), 3.0, true)
			draw_line(Vector2(cx - 2.0, cy + 6.0), Vector2(cx + 8.0, cy - 7.0), Color("#ffffff"), 3.0, true)
		draw_string(Fonts.regular(), Vector2(48.0, cy + 5.0), _label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#1d222e"))
