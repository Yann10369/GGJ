extends Control

const THRESHOLD := 90.0
const SIDE_W := 330.0

const BG_HOME := "res://assets/textures/background/home.jpg"
const BG_NEIGHBORHOOD := "res://assets/textures/background/neighborhood.jpg"
const BG_ELEVATOR := "res://assets/textures/background/elevator.png"
## 事件发生在「家里/宅内」时用客厅背景；其余默认用小区外景。
## 出门执勤/排查类的上楼道电梯场景用电梯厅背景，避免整屏黑底。
const ELEVATOR_EVENTS := ["slip_through", "volunteer", "party_squad", "duty_routine"]
const NEIGHBORHOOD_EVENTS := ["lockdown", "difficulty", "delivery_news", "help_high", "help_low"]

var run: GrowRun
var stage: Control
var actions: VBoxContainer
var swipe_choices: Array[Label] = []
var day_label: Label
var phase_label: Label
var community: CommunityView
var stat_bars: Dictionary = {}
var top_card: Card
var shopping_card: ShoppingCard
var journal_overlay: Control
var ui_generation := 0

var _bg_tex: TextureRect
var _bg_path := ""

func _ready() -> void:
	var ui_theme := Theme.new()
	ui_theme.default_font = Fonts.regular()
	ui_theme.default_font_size = 16
	theme = ui_theme
	_set_background(BG_HOME)
	_build_ui()
	restart()

# ------------------------------------------------------------------ 背景

func _set_background(path: String) -> void:
	if _bg_path == path:
		return
	_bg_path = path
	var tex := load(path) as Texture2D
	if tex == null:
		return
	if _bg_tex == null:
		_bg_tex = TextureRect.new()
		_bg_tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_bg_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_bg_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_bg_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		_bg_tex.modulate = Color(1, 1, 1, 0.5)
		add_child(_bg_tex)
		move_child(_bg_tex, 0)
	_bg_tex.texture = tex

func _background_for_phase() -> String:
	var home_phases := {GrowRun.Phase.MORNING: true, GrowRun.Phase.NIGHT: true, GrowRun.Phase.RECAP: true, GrowRun.Phase.ENDING: true}
	if home_phases.get(run.phase, false):
		return BG_HOME
	if run.phase == GrowRun.Phase.EVENT and not run.current.is_empty():
		var id: String = str(run.current.get("id", ""))
		if ELEVATOR_EVENTS.has(id):
			return BG_ELEVATOR
		if NEIGHBORHOOD_EVENTS.has(id):
			return BG_NEIGHBORHOOD
	# RESULT 沿用事件当下的场景（run.current 仍保留原事件）
	if run.phase == GrowRun.Phase.RESULT and not run.current.is_empty():
		var rid: String = str(run.current.get("id", ""))
		if ELEVATOR_EVENTS.has(rid):
			return BG_ELEVATOR
		if NEIGHBORHOOD_EVENTS.has(rid):
			return BG_NEIGHBORHOOD
	return BG_HOME

func _apply_background() -> void:
	_set_background(_background_for_phase())

# ------------------------------------------------------------------ UI

func _build_ui() -> void:
	var outer := MarginContainer.new()
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		outer.add_theme_constant_override("margin_" + side, 20 if side in ["left", "right"] else 16)
	add_child(outer)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	Ui.ghost(row)
	outer.add_child(row)

	# 左侧栏：品牌 / 状态 / 属性。用不透明面板衬底，保证场景背景图上仍清晰可读
	var left_panel := PanelContainer.new()
	left_panel.custom_minimum_size = Vector2(SIDE_W, 0)
	left_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var lp_sb := Ui.box(Color("#121720", 0.96), 14, 18, 14, 18, 14)
	lp_sb.set_border_width_all(1)
	lp_sb.border_color = Color(1, 1, 1, 0.07)
	left_panel.add_theme_stylebox_override("panel", lp_sb)
	row.add_child(left_panel)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 12)
	Ui.ghost(left)
	left_panel.add_child(left)

	var heading := HBoxContainer.new()
	left.add_child(heading)
	var brand := _label("GROW / 封城之后", 26, Color("#e7c985"))
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(brand)
	var journal_button := _button("成长记录", _open_journal)
	journal_button.custom_minimum_size.x = 108
	heading.add_child(journal_button)
	left.add_child(_label("每一个选择，都会在之后的某一天重新找到你。", 12, Color("#9ca9b5")))

	community = CommunityView.new()
	community.custom_minimum_size.y = 88
	community.custom_minimum_size.x = SIDE_W
	left.add_child(community)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	left.add_child(grid)
	for key in GameData.STAT_KEYS:
		var bar := StatBar.new()
		bar.setup(key)
		grid.add_child(bar)
		stat_bars[key] = bar

	var status := VBoxContainer.new()
	status.add_theme_constant_override("separation", 2)
	left.add_child(status)
	day_label = _label("", 18, Color("#e7c985"))
	status.add_child(day_label)
	phase_label = _label("", 13, Color("#9ca9b5"))
	status.add_child(phase_label)

	# 右侧栏：舞台 + 操作按钮
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 10)
	Ui.ghost(right)
	row.add_child(right)

	stage = Control.new()
	stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.custom_minimum_size.y = 360
	# Card rotation, shadows and stack offsets stay inside the event area.
	stage.clip_contents = true
	right.add_child(stage)
	stage.resized.connect(_layout_cards)

	actions = VBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	right.add_child(actions)

func restart() -> void:
	_close_journal()
	GameManager.start_new_game()
	run = GameManager.run
	Audio.play_music()
	render()

func _clear_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()

func render() -> void:
	ui_generation += 1
	_apply_background()
	# 拖卡加分预览效果已按需求注释：
	# for key in stat_bars: stat_bars[key].preview(0, 0.0)
	_clear_children(stage)
	_clear_children(actions)
	swipe_choices.clear()
	top_card = null
	shopping_card = null
	for key in stat_bars: stat_bars[key].set_value(int(run.stats[key]), true)
	community.set_harmony(int(run.stats["harmony"]))
	day_label.text = "第 %02d / %d 天" % [run.day, run.final_day]
	match run.phase:
		GrowRun.Phase.MORNING:
			phase_label.text = "早晨 · 今天想保护什么"
			_show_text("新的一天", run.morning_news() + "\n\n你是一个四口之家的父亲。每天先做一件小事，再面对今天的选择。\n\n今天的主动行动（每天一次）")
			for i in GameData.ACTIONS.size():
				var action: Dictionary = GameData.ACTIONS[i]
				_add_action(action["label"] + "   /   " + action["hint"], func() -> void: _act(i))
		GrowRun.Phase.EVENT:
			phase_label.text = "白天 · " + ("接龙采购" if run.current.get("type") == "shopping" else "今天的第 %d 张卡" % (run.slots_used + 1))
			if run.current.get("type") == "shopping": _show_shop()
			else: _show_card()
		GrowRun.Phase.RESULT:
			phase_label.text = "选择之后"
			_show_text(run.current["title"], run.last_result + "\n\n" + run.last_changes)
			_add_action("继续这一天", _continue)
		GrowRun.Phase.NIGHT:
			phase_label.text = "夜晚 · 结算"
			_show_text("天色慢慢暗下来", run.night_text + "\n\n今天已经结束。过去留下的事，也许会在以后的日子里再有回声。")
			_add_action("回看这些日子" if not run.ending.is_empty() else "睡一觉，迎接明天", _continue)
		GrowRun.Phase.RECAP:
			phase_label.text = "过去种下的东西"
			_show_text("我们一路走来", run.recap_text())
			_add_action("看看我们的结局", _continue)
		GrowRun.Phase.ENDING:
			phase_label.text = "这一次，我们的故事"
			_show_text(run.ending["title"], run.ending["text"])
			_add_action("再过一次这些日子", restart)
			Audio.stop_music()
			Audio.play_sfx("end")

func _show_card() -> void:
	var event: Dictionary = run.current.duplicate(true)
	var binary := run.options.size() == 2
	event["swipe_enabled"] = binary
	if binary:
		event["left"] = run.options[0]
		event["right"] = run.options[1]
	event["hide_effects"] = true
	for layer in [2, 1]:
		var back := Card.new()
		stage.add_child(back)
		back.configure({"cat": "尚未发生", "title": "", "left": {}, "right": {}}, run.day, run.final_day, false, layer, stage.size)
	top_card = Card.new()
	stage.add_child(top_card)
	top_card.configure(event, run.day, run.final_day, true, 0, stage.size, run.flags)
	top_card.released.connect(_on_swipe)
	# 拖卡加分预览效果已按需求注释：
	# top_card.previewed.connect(_on_card_preview)
	if binary:
		_show_swipe_choices()
	else:
		for i in run.options.size():
			_add_action("%d. %s" % [i + 1, run.options[i]["label"]], func() -> void: _choose(i))
	_layout_cards()
	Audio.play_sfx("flip")

func _layout_cards() -> void:
	for child in stage.get_children():
		if child is Card:
			child.apply_stack(child.stack_index, stage.size)

## 拖卡加分预览效果已按需求注释，不再映射到属性条：
#func _on_card_preview(side: int, strength: float) -> void:
#	if run == null or run.phase != GrowRun.Phase.EVENT or run.current.get("type") == "shopping" or run.options.size() != 2:
#		return
#	var eff: Dictionary = (run.options[1] if side > 0 else run.options[0]).get("effects", {})
#	for k in GameData.STAT_KEYS:
#		stat_bars[k].preview(int(eff.get(k, 0)) if side != 0 else 0, strength if side != 0 else 0.0)

## 二选一：既可拖动卡片，也可点下方按钮直接确定
func _show_swipe_choices() -> void:
	var hint := _label("拖动卡牌左右滑动，或点下方按钮确定 · 也可使用 ← → / A D", 13, Color("#a9b6bd"))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Ui.ghost(hint)
	actions.add_child(hint)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	Ui.ghost(row)
	actions.add_child(row)
	for i in 2:
		var b := Button.new()
		b.text = ("← 左滑 · " if i == 0 else "右滑 → · ") + str(run.options[i]["label"])
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.custom_minimum_size = Vector2(0, 56)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_override("font", Fonts.regular())
		b.add_theme_font_size_override("font_size", 15)
		b.add_theme_color_override("font_color", Color("#e7dfce"))
		b.add_theme_stylebox_override("normal", Ui.box(Color("#24323b"), 12, 12, 10, 12, 10))
		b.add_theme_stylebox_override("hover", Ui.box(Color("#3a514f"), 12, 12, 10, 12, 10))
		b.add_theme_stylebox_override("pressed", Ui.box(Color("#52675e"), 12, 12, 10, 12, 10))
		var index := i
		b.pressed.connect(func() -> void: _choose(index))
		row.add_child(b)

func _show_shop() -> void:
	shopping_card = ShoppingCard.new()
	stage.add_child(shopping_card)
	shopping_card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shopping_card.setup_offer(run.current, run.shop)
	shopping_card.purchase_requested.connect(func(ids: Array) -> void:
		if run.purchase(ids):
			Audio.play_sfx("select")
			render()
	)

func _show_text(title: String, body: String) -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", Ui.box(Color("#1f2832", 0.92), 18, 26, 22, 26, 22))
	stage.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	panel.add_child(column)
	column.add_child(_label(title, 26, Color("#e7c985")))
	var text := RichTextLabel.new()
	text.text = body
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text.add_theme_font_override("normal_font", Fonts.regular())
	text.add_theme_font_size_override("normal_font_size", 17)
	text.add_theme_color_override("default_color", Color("#d2d9dc"))
	text.add_theme_constant_override("line_separation", 9)
	column.add_child(text)

func _add_action(text: String, callback: Callable) -> void:
	var generation := ui_generation
	actions.add_child(_button(text, func() -> void:
		if generation == ui_generation and not is_instance_valid(journal_overlay): callback.call()
	))

func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.custom_minimum_size.y = 46
	button.add_theme_font_override("font", Fonts.regular())
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", Color("#e7dfce"))
	button.add_theme_stylebox_override("normal", Ui.box(Color("#2b3943"), 12, 14, 9, 14, 9))
	button.add_theme_stylebox_override("hover", Ui.box(Color("#3a514f"), 12, 14, 9, 14, 9))
	button.add_theme_stylebox_override("pressed", Ui.box(Color("#52675e"), 12, 14, 9, 14, 9))
	button.pressed.connect(callback)
	return button

func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	Fonts.apply(label, font_size, color)
	return label

func _act(index: int) -> void:
	if run.act(index): render()

func _choose(index: int) -> void:
	if is_instance_valid(journal_overlay): return
	if not run.choose(index): return
	ui_generation += 1
	var generation := ui_generation
	for button in actions.get_children():
		if button is Button: button.disabled = true
	if is_instance_valid(top_card):
		top_card.interactive = false
		if run.options.size() == 2:
			top_card.fly_out(-1 if index == 0 else 1)
		else:
			create_tween().tween_property(top_card, "modulate:a", 0.0, 0.2)
	Audio.play_sfx("swipe" if run.options.size() == 2 else "select")
	await get_tree().create_timer(0.25).timeout
	if generation == ui_generation: render()

func _continue() -> void:
	if run.continue_run(): render()

func _on_swipe(dx: float) -> void:
	if not is_instance_valid(top_card) or not top_card.interactive or run.phase != GrowRun.Phase.EVENT or run.options.size() != 2: return
	if absf(dx) >= THRESHOLD: _choose(1 if dx > 0 else 0)
	else: top_card.return_to_center()

func _open_journal() -> void:
	if is_instance_valid(journal_overlay): return
	if is_instance_valid(top_card):
		top_card.interactive = false
		top_card.return_to_center()
	journal_overlay = PanelContainer.new()
	journal_overlay.z_index = 300
	journal_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	journal_overlay.add_theme_stylebox_override("panel", Ui.box(Color("#19232e"), 0, 36, 36, 36, 36))
	add_child(journal_overlay)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 20)
	journal_overlay.add_child(column)
	column.add_child(_label("我的这些日子", 28, Color("#e7c985")))
	var journal_text := RichTextLabel.new()
	journal_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	journal_text.add_theme_font_size_override("normal_font_size", 20)
	journal_text.add_theme_constant_override("line_separation", 10)
	journal_text.text = "有些改变，才刚刚开始。" if run.journal.is_empty() else ""
	for entry in run.journal: journal_text.text += "第 %d 天\n%s\n\n" % [entry["day"], entry["text"]]
	column.add_child(journal_text)
	column.add_child(_button("回到今天", _close_journal))

func _close_journal() -> void:
	if is_instance_valid(journal_overlay):
		remove_child(journal_overlay)
		journal_overlay.queue_free()
		journal_overlay = null
	if is_instance_valid(top_card): top_card.interactive = run.phase == GrowRun.Phase.EVENT and run.options.size() == 2

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if is_instance_valid(journal_overlay):
		if event.keycode == KEY_ESCAPE: _close_journal()
		return
	if run.phase == GrowRun.Phase.EVENT and run.current.get("type") != "shopping":
		if run.options.size() == 2:
			if event.keycode in [KEY_LEFT, KEY_A]: _choose(0)
			elif event.keycode in [KEY_RIGHT, KEY_D]: _choose(1)
		elif event.keycode in [KEY_1, KEY_2, KEY_3, KEY_4]: _choose(event.keycode - KEY_1)
	elif run.phase == GrowRun.Phase.ENDING and event.keycode == KEY_R: restart()
