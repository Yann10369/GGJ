extends Control

## 封城十四天 · 防疫成长
## 14 天封控中，每天抽一张事件牌：左滑选左侧方案，右滑选右侧方案。
## 四维：心情 / 免疫力 / 物资 / 和睦；旗标：eggs / crisis / talked。

const DESIGN_WIDTH := 720.0
const THRESHOLD := 90.0

var stats: Dictionary = {}
var flags: Dictionary = {}
var day := 1
var last_event_id := ""
var current_event: Dictionary = {}
var busy := false

var content: MarginContainer
var stage: Control
var deck: Control
var counter: Label
var end_screen: Control
var summary: RichTextLabel
var result_banner: PanelContainer
var result_label: Label
var btn_left: Button
var btn_right: Button
var stat_bars: Dictionary = {}
var cards: Array[CardView] = []
var top_card: CardView
var _result_tween: Tween

func _ready() -> void:
	stats = GameData.initial_stats()
	flags = GameData.initial_flags()
	theme = _make_theme()
	resized.connect(_layout)
	_build_background()
	_build_content()
	_layout()
	refresh_stats(false)
	render_day()

func _make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = Fonts.regular()
	t.default_font_size = 14
	return t

# ------------------------------------------------------------------ 布局

func _layout() -> void:
	if content == null:
		return
	var w := minf(size.x, DESIGN_WIDTH)
	content.size = Vector2(w, size.y)
	content.position = Vector2((size.x - w) * 0.5, 0.0)

func _build_background() -> void:
	var lin := Gradient.new()
	lin.set_color(0, Color("#141722"))
	lin.set_color(1, Color("#1d222e"))
	var lin_tex := GradientTexture2D.new()
	lin_tex.gradient = lin
	lin_tex.width = 8
	lin_tex.height = 256
	lin_tex.fill_from = Vector2(0.5, 0.0)
	lin_tex.fill_to = Vector2(0.5, 1.0)
	var base := TextureRect.new()
	base.texture = lin_tex
	base.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	base.stretch_mode = TextureRect.STRETCH_SCALE
	Ui.ghost(base)
	Ui.place(base, Control.PRESET_FULL_RECT)
	add_child(base)

	var rad := Gradient.new()
	rad.set_color(0, Color("#262c3b"))
	rad.set_color(1, Color("#262c3b", 0.0))
	rad.add_point(0.6, Color("#262c3b", 0.0))
	var rad_tex := GradientTexture2D.new()
	rad_tex.gradient = rad
	rad_tex.fill = GradientTexture2D.FILL_RADIAL
	rad_tex.fill_from = Vector2(0.5, 0.5)
	rad_tex.fill_to = Vector2(1.0, 0.5)
	rad_tex.width = 512
	rad_tex.height = 512
	var glow := TextureRect.new()
	glow.texture = rad_tex
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	Ui.ghost(glow)
	Ui.place(glow, Control.PRESET_CENTER_TOP, -450, -440, 450, 220)
	add_child(glow)

func _build_content() -> void:
	content = MarginContainer.new()
	content.add_theme_constant_override("margin_left", 18)
	content.add_theme_constant_override("margin_right", 18)
	content.add_theme_constant_override("margin_top", 18)
	content.add_theme_constant_override("margin_bottom", 0)
	Ui.ghost(content)
	add_child(content)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	Ui.ghost(vbox)
	content.add_child(vbox)

	vbox.add_child(_build_header())
	vbox.add_child(_build_stage())

	var actions_wrap := MarginContainer.new()
	actions_wrap.add_theme_constant_override("margin_top", 14)
	actions_wrap.add_theme_constant_override("margin_bottom", 20)
	Ui.ghost(actions_wrap)
	actions_wrap.add_child(_build_actions())
	vbox.add_child(actions_wrap)

func _build_header() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	Ui.ghost(box)

	var brand := HBoxContainer.new()
	brand.add_theme_constant_override("separation", 10)
	Ui.ghost(brand)
	var spark := SparkIcon.new()
	spark.custom_minimum_size = Vector2(30, 30)
	spark.setup(Color("#c99a3e"), false)
	brand.add_child(spark)
	var title := Label.new()
	title.text = "封城十四天"
	Fonts.apply(title, 26, Color("#e9e6dd"), "serif-bold")
	brand.add_child(title)
	box.add_child(brand)

	box.add_child(_rich_line([
		["左滑选左 · 右滑选右 · ", false], ["14 天", true],
		["封控中的每一次抉择", false]
	], 12, Color("#9aa0b0")))

	var stats_wrap := MarginContainer.new()
	stats_wrap.add_theme_constant_override("margin_top", 10)
	Ui.ghost(stats_wrap)
	box.add_child(stats_wrap)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	Ui.ghost(grid)
	stats_wrap.add_child(grid)
	for k in GameData.STAT_KEYS:
		var bar := StatBar.new()
		bar.setup(k)
		grid.add_child(bar)
		stat_bars[k] = bar
	return box

func _build_stage() -> Control:
	stage = Control.new()
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.custom_minimum_size = Vector2(0, 360)
	Ui.ghost(stage)

	var hint_center := CenterContainer.new()
	hint_center.custom_minimum_size = Vector2(0, 20)
	Ui.ghost(hint_center)
	Ui.place(hint_center, Control.PRESET_TOP_WIDE, 0, 2, 0, 24)
	hint_center.add_child(_rich_line([
		["拖动卡牌 —— 左滑选左侧方案，右滑选右侧方案", false], ["（← → 键亦可）", true]
	], 12, Color("#7e8495")))
	stage.add_child(hint_center)

	deck = Control.new()
	Ui.ghost(deck)
	Ui.place(deck, Control.PRESET_FULL_RECT, 0, 34, 0, -26)
	deck.resized.connect(_on_deck_resized)
	stage.add_child(deck)

	counter = Label.new()
	counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	counter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	Fonts.apply(counter, 12, Color("#8a90a0"), "serif")
	Ui.ghost(counter)
	stage.add_child(counter)

	result_banner = PanelContainer.new()
	result_banner.add_theme_stylebox_override("panel",
		Ui.box(Color("#f6f1e6"), 14, 16, 8, 16, 10))
	result_banner.visible = false
	result_banner.z_index = 50
	Ui.ghost(result_banner)
	stage.add_child(result_banner)
	result_label = Label.new()
	result_label.custom_minimum_size = Vector2(420, 0)
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_label.add_theme_constant_override("line_spacing", 3)
	Fonts.apply(result_label, 13, Color("#272b33"))
	result_banner.add_child(result_label)

	stage.resized.connect(func() -> void:
		counter.size = Vector2(140, 20)
		counter.position = Vector2(stage.size.x - 142.0, stage.size.y - 24.0)
		if result_banner.visible:
			result_banner.position = Vector2((stage.size.x - result_banner.size.x) * 0.5, 24.0)
	)

	end_screen = _build_end_screen()
	stage.add_child(end_screen)
	return stage

func _build_actions() -> Control:
	var box := HBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 16)
	Ui.ghost(box)
	btn_left = _make_button("← ", Color("#cf4f4f"), Color("#f09292"))
	btn_left.pressed.connect(func() -> void: decide(false))
	box.add_child(btn_left)
	btn_right = _make_button(" →", Color("#3f9d6c"), Color("#7fd6a8"))
	btn_right.pressed.connect(func() -> void: decide(true))
	box.add_child(btn_right)
	return box

func _build_end_screen() -> Control:
	var es := Control.new()
	es.visible = false
	es.z_index = 60
	Ui.ghost(es)
	Ui.place(es, Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	Ui.ghost(center)
	Ui.place(center, Control.PRESET_FULL_RECT)
	es.add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	Ui.ghost(box)
	center.add_child(box)

	var t1 := Label.new()
	t1.text = "封控结束"
	t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Fonts.apply(t1, 30, Color("#e7c985"), "serif-bold")
	box.add_child(t1)
	box.add_child(Ui.spacer(6.0))

	summary = RichTextLabel.new()
	summary.bbcode_enabled = true
	summary.fit_content = true
	summary.scroll_active = false
	summary.custom_minimum_size = Vector2(430, 0)
	summary.add_theme_font_override("normal", Fonts.regular())
	summary.add_theme_font_size_override("normal_font_size", 14)
	summary.add_theme_color_override("default_color", Color("#aeb3c2"))
	summary.add_theme_constant_override("line_separation", 10)
	Ui.ghost(summary)
	box.add_child(summary)
	box.add_child(Ui.spacer(14.0))

	var btn := _make_button("重新开始", Color("#c99a3e"), Color("#e7c985"))
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.pressed.connect(restart)
	box.add_child(btn)
	return es

## parts: [[文本, 是否高亮], ...]
func _rich_line(parts: Array, size: int, base_color: Color) -> Control:
	var box := HBoxContainer.new()
	Ui.ghost(box)
	for p in parts:
		var label := Label.new()
		label.text = str(p[0])
		var hot := bool(p[1])
		Fonts.apply(label, size, Color("#e7c985") if hot else base_color, "bold" if hot else "")
		box.add_child(label)
	return box

func _make_button(text: String, accent: Color, text_color: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(156, 48)

	var normal := Ui.box(Color(1, 1, 1, 0.04), 24, 22, 0, 22, 0)
	normal.set_border_width_all(2)
	normal.border_color = Color(accent, 0.55)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(accent, 0.16)
	hover.border_color = Color(accent, 0.9)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(accent, 0.26)

	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_font_override("font", Fonts.bold())
	b.add_theme_font_size_override("font_size", 15)
	b.add_theme_color_override("font_color", text_color)
	b.add_theme_color_override("font_hover_color", text_color.lightened(0.15))
	b.add_theme_color_override("font_pressed_color", text_color)
	return b

# ------------------------------------------------------------------ 牌堆

func _event_by_id(id: String) -> Dictionary:
	for e in GameData.EVENTS:
		if e["id"] == id:
			return e
	return GameData.EVENTS[0]

func _pick_top_event() -> Dictionary:
	if day == 1:
		for e in GameData.EVENTS:
			if e.get("first", false):
				return e
	return GameData.pick_event(last_event_id, stats, flags)

func render_day() -> void:
	for c in cards:
		if is_instance_valid(c):
			c.queue_free()
	cards.clear()
	top_card = null

	counter.text = "第 %d / %d 天" % [day, GameData.TOTAL_DAYS]
	counter.visible = day <= GameData.TOTAL_DAYS
	if day > GameData.TOTAL_DAYS:
		show_end()
		return

	var top_event := _pick_top_event()
	current_event = top_event
	# 抽 3 张后方预览（仅用于堆叠视觉效果）
	var picked_ids: Array[String] = [top_event["id"]]
	var deck_events: Array[Dictionary] = [top_event]
	for i in 3:
		var pv := GameData.pick_event(picked_ids[-1], stats, flags)
		picked_ids.append(pv["id"])
		deck_events.append(_event_by_id(pv["id"]))

	for i in range(deck_events.size() - 1, -1, -1):
		var card := CardView.new()
		deck.add_child(card)
		card.configure(deck_events[i], day, GameData.TOTAL_DAYS, i == 0, i, deck.size, flags)
		card.released.connect(_on_card_released)
		cards.append(card)
		if i == 0:
			top_card = card

	_update_buttons(top_event)

func _update_buttons(ev: Dictionary) -> void:
	var lo := GameData.resolve_option(ev["left"], flags)
	var ro := GameData.resolve_option(ev["right"], flags)
	btn_left.text = "← " + str(lo.get("label", ""))
	btn_right.text = str(ro.get("label", "")) + " →"

func _on_deck_resized() -> void:
	for c in cards:
		if is_instance_valid(c):
			c.apply_stack(c.stack_index, deck.size)

func _on_card_released(dx: float) -> void:
	if busy or not is_instance_valid(top_card):
		return
	if dx > THRESHOLD:
		decide(true)
	elif dx < -THRESHOLD:
		decide(false)
	else:
		top_card.return_to_center()

# ------------------------------------------------------------------ 决策

func decide(accept: bool) -> void:
	if busy or day > GameData.TOTAL_DAYS or current_event.is_empty():
		return
	busy = true
	var ev: Dictionary = current_event
	var opt := GameData.resolve_option(ev["right"] if accept else ev["left"], flags)
	last_event_id = ev["id"]
	if is_instance_valid(top_card):
		top_card.fly_out(1 if accept else -1)
	_apply_choice(opt)
	day += 1
	await get_tree().create_timer(0.45).timeout
	render_day()
	busy = false

func _apply_choice(opt: Dictionary) -> void:
	var eff: Dictionary = opt.get("effects", {})
	var changed: Array = []
	for k in GameData.STAT_KEYS:
		var d := int(eff.get(k, 0))
		if d == 0:
			continue
		stats[k] = clampi(int(stats[k]) + d, 0, 100)
		changed.append([k, d])
	var sets: Dictionary = opt.get("set", {})
	for k in sets:
		flags[k] = sets[k]
	refresh_stats(true)
	_show_result(str(opt.get("result", "")))
	if changed.is_empty():
		return
	await get_tree().create_timer(0.18).timeout
	for c in changed:
		var bar: StatBar = stat_bars[c[0]]
		bar.bump(int(c[1]))

func refresh_stats(animate: bool) -> void:
	for k in GameData.STAT_KEYS:
		var bar: StatBar = stat_bars[k]
		bar.set_value(int(stats[k]), animate)

func _show_result(text: String) -> void:
	if text == "" or not is_instance_valid(result_banner):
		return
	result_label.text = text
	await get_tree().process_frame
	result_banner.position = Vector2((stage.size.x - result_banner.size.x) * 0.5, 24.0)
	result_banner.visible = true
	result_banner.modulate.a = 0.0
	if _result_tween != null and _result_tween.is_valid():
		_result_tween.kill()
	_result_tween = create_tween()
	_result_tween.tween_property(result_banner, "modulate:a", 1.0, 0.3)
	_result_tween.tween_interval(2.2)
	_result_tween.tween_property(result_banner, "modulate:a", 0.0, 0.6)
	_result_tween.tween_callback(func() -> void: result_banner.visible = false)

func show_end() -> void:
	var best := GameData.STAT_KEYS[0]
	for k in GameData.STAT_KEYS:
		if int(stats[k]) > int(stats[best]):
			best = k
	var def: Dictionary = GameData.STAT_DEFS[best]
	summary.clear()
	summary.append_text(
		"[center]14 天封控终于熬过去了。\n" +
		"最终四维 —— 心情 [b]%d[/b] · 免疫力 [b]%d[/b] · 物资 [b]%d[/b] · 和睦 [b]%d[/b]\n" %
			[int(stats["mood"]), int(stats["immunity"]), int(stats["supplies"]), int(stats["harmony"])] +
		"这段日子里，你家最被呵护的是 [color=#%s][b]%s[/b][/color]。[/center]" %
			[(def["color"] as Color).to_html(false), str(def["name"])]
	)
	if is_instance_valid(deck):
		deck.visible = false
	btn_left.visible = false
	btn_right.visible = false
	if is_instance_valid(result_banner):
		result_banner.visible = false
	end_screen.visible = true
	end_screen.modulate.a = 0.0
	create_tween().tween_property(end_screen, "modulate:a", 1.0, 0.5)

func restart() -> void:
	stats = GameData.initial_stats()
	flags = GameData.initial_flags()
	day = 1
	last_event_id = ""
	current_event = {}
	busy = false
	end_screen.visible = false
	if is_instance_valid(deck):
		deck.visible = true
	btn_left.visible = true
	btn_right.visible = true
	if _result_tween != null and _result_tween.is_valid():
		_result_tween.kill()
	result_banner.visible = false
	refresh_stats(false)
	render_day()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_LEFT, KEY_A:
				decide(false)
			KEY_RIGHT, KEY_D:
				decide(true)
			KEY_R:
				if day > GameData.TOTAL_DAYS:
					restart()
