extends Control
class_name ShoppingCard

## "接龙时间"专用：手机样式的物资选购界面。抽 N 件商品展示，玩家选 choose 件后确认。

signal completed(effects: Dictionary, counters: Dictionary, result: String)

const PHONE_W := 440.0
const PHONE_H := 640.0

var _items: Array[Dictionary] = []
var _choose := 3
var _selected: Dictionary = {}  # id -> bool
var _buttons: Dictionary = {}    # id -> Button
var _counter: Label
var _confirm: Button
var _result_text := ""
var _phone: Control

func setup(event: Dictionary, flags: Dictionary) -> void:
	var data: Dictionary = GameData.shopping_items(event, flags)
	_choose = int(data["choose"])
	_items = data["items"]
	_result_text = str(event.get("result_after", ""))
	_selected.clear()
	_build_content()

func _ready() -> void:
	if _phone == null:
		_build_shell()
	resized.connect(_layout)

func _build_shell() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_phone = Control.new()
	_phone.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_phone)

func _build_content() -> void:
	for c in _phone.get_children():
		c.queue_free()
	_buttons.clear()
	# 背板：用 _draw 画一个深色圆角手机
	var artist := _PhoneBg.new()
	_phone.add_child(artist)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 60)
	margin.add_theme_constant_override("margin_bottom", 22)
	Ui.ghost(margin)
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	_phone.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	Ui.ghost(vbox)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "接龙采购"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Fonts.apply(title, 22, Color("#f0ede4"), "serif-bold")
	vbox.add_child(title)

	var hint := Label.new()
	hint.text = "从下方选 %d 件" % _choose
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Fonts.apply(hint, 12, Color("#9aa0b0"))
	vbox.add_child(hint)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	Ui.ghost(grid)
	vbox.add_child(grid)
	for it in _items:
		var b := _item_button(it)
		_buttons[it["id"]] = b
		grid.add_child(b)

	vbox.add_child(Ui.spacer(0.0, true))

	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 12)
	Ui.ghost(bottom)
	vbox.add_child(bottom)

	_counter = Label.new()
	_counter.text = "已选 0 / %d" % _choose
	Fonts.apply(_counter, 14, Color("#e7c985"), "bold")
	_counter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(_counter)

	_confirm = Button.new()
	_confirm.text = "确认下单"
	_confirm.disabled = true
	_confirm.focus_mode = Control.FOCUS_NONE
	_confirm.custom_minimum_size = Vector2(120, 42)
	var sb := Ui.box(Color("#c99a3e"), 21, 14, 0, 14, 0)
	_confirm.add_theme_stylebox_override("normal", sb)
	_confirm.add_theme_stylebox_override("hover", sb)
	_confirm.add_theme_stylebox_override("pressed", sb)
	_confirm.add_theme_stylebox_override("disabled", Ui.box(Color(1, 1, 1, 0.08), 21, 14, 0, 14, 0))
	_confirm.add_theme_font_override("font", Fonts.bold())
	_confirm.add_theme_font_size_override("font_size", 14)
	_confirm.add_theme_color_override("font_color", Color("#1d222e"))
	_confirm.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.35))
	_confirm.pressed.connect(_on_confirm)
	bottom.add_child(_confirm)
	_layout()

func _item_button(it: Dictionary) -> Button:
	var b := Button.new()
	b.text = str(it["name"])
	b.toggle_mode = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 44)
	var off := Ui.box(Color(1, 1, 1, 0.06), 12, 10, 0, 10, 0)
	var on := Ui.box(Color("#c99a3e", 0.25), 12, 10, 0, 10, 0)
	on.set_border_width_all(2)
	on.border_color = Color("#e7c985")
	b.add_theme_stylebox_override("normal", off)
	b.add_theme_stylebox_override("hover", off)
	b.add_theme_stylebox_override("pressed", off)
	b.add_theme_stylebox_override("focused", off)
	b.toggled.connect(func(_p: bool): _on_toggle(it["id"], b))
	b.add_theme_font_override("font", Fonts.regular())
	b.add_theme_font_size_override("font_size", 13)
	b.add_theme_color_override("font_color", Color("#e9e6dd"))
	return b

func _on_toggle(id, btn: Button) -> void:
	if btn.button_pressed:
		var count := 0
		for k in _selected:
			if _selected[k]:
				count += 1
		if count >= _choose:
			btn.button_pressed = false
			return
		_selected[id] = true
	else:
		_selected[id] = false
	_refresh()

func _refresh() -> void:
	var count := 0
	for k in _selected:
		if _selected[k]:
			count += 1
	_counter.text = "已选 %d / %d" % [count, _choose]
	_confirm.disabled = count < _choose

func _on_confirm() -> void:
	var eff: Dictionary = {}
	var counters: Dictionary = {}
	for it in _items:
		if _selected.get(it["id"], false):
			for k in it.get("eff", {}):
				eff[k] = int(eff.get(k, 0)) + int(it["eff"][k])
			if it.has("counter"):
				counters[it["counter"]] = int(counters.get(it["counter"], 0)) + 1
	# 所有采购都给一点基础物资
	eff["supplies"] = int(eff.get("supplies", 0)) + 2
	completed.emit(eff, counters, _result_text)

func _layout() -> void:
	if _phone == null:
		return
	_phone.size = Vector2(minf(size.x * 0.92, PHONE_W), minf(size.y - 14, PHONE_H))
	_phone.position = Vector2((size.x - _phone.size.x) * 0.5, (size.y - _phone.size.y) * 0.5)


class _PhoneBg extends Control:
	func _ready() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT, false)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("#1d2230")
		sb.set_corner_radius_all(28)
		sb.shadow_color = Color(0, 0, 0, 0.55)
		sb.shadow_size = 24
		sb.shadow_offset = Vector2(0, 14)
		sb.border_color = Color("#c99a3e")
		sb.set_border_width_all(2)
		draw_style_box(sb, r)
		var gold := StyleBoxFlat.new()
		gold.bg_color = Color("#c99a3e")
		gold.set_corner_radius_all(0)
		draw_style_box(gold, Rect2(0, 0, r.size.x, 10))
		var notch := StyleBoxFlat.new()
		notch.bg_color = Color(0, 0, 0, 0.7)
		notch.set_corner_radius_all(6)
		draw_style_box(notch, Rect2(r.size.x * 0.5 - 36, 16, 72, 8))
