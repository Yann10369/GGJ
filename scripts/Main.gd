extends Control

## 封城三十天 · 防疫成长（卡牌序列流程）
## 每天构成一张卡牌队列：日卡 → 事件卡 → 结果卡 → … → 结算卡 → 次日
## 事件按 固定 / 社区 / 家庭 / 邻里 四池抽取；选项可单/双/三向滑动。

const DESIGN_WIDTH := 720.0

var stats: Dictionary = {}
var flags: Dictionary = {}
var day := 1
var shown: Dictionary = {}
var last_event_id := ""
var busy := false

var deck: Array[Dictionary] = []
var cur := 0
var current_view: Control = null

var content: MarginContainer
var stage: Control
var deck_parent: Control
var stat_bars: Dictionary = {}

func _ready() -> void:
	stats = GameData.initial_stats()
	flags = GameData.initial_flags()
	theme = _make_theme()
	resized.connect(_layout)
	_build_background()
	_build_content()
	_layout()
	refresh_stats(false)
	Audio.play_music()
	_build_day(day)

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

func _build_header() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	Ui.ghost(box)

	# 背景只保留四个指标；标题/提示等文字一律不显示
	var stats_wrap := MarginContainer.new()
	stats_wrap.add_theme_constant_override("margin_top", 6)
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

	deck_parent = Control.new()
	Ui.ghost(deck_parent)
	Ui.place(deck_parent, Control.PRESET_FULL_RECT, 8, 34, 8, -34)
	stage.add_child(deck_parent)
	return stage

# ------------------------------------------------------------------ 每日构建

func _build_day(d: int) -> void:
	deck.clear()
	cur = 0
	deck.append({"kind": "day", "day": d})

	var events := GameData.forced_for_day(d, shown)
	var exclude: Array[String] = []
	for e in events:
		exclude.append(e["id"])

	# 固定池现仅日期强制 / 状态触发（无独立概率事件）

	# 例行值守排程：党员突击队次日（duty_start）起，每 2 天一次
	if bool(flags.get("duty", false)) and int(flags.get("duty_start", 0)) > 0:
		var ds := int(flags["duty_start"])
		if d >= ds + 1 and (d - ds - 1) % 2 == 0:
			var dr := _event_by_id("duty_routine")
			if not shown.get(dr["id"], false):
				events.append(dr)
				exclude.append(dr["id"])

	for cat in ["社区", "家庭", "邻里"]:
		var ev := GameData.pick_event(last_event_id, stats, flags, shown, d, cat, exclude)
		if not ev.is_empty():
			exclude.append(ev["id"])
			events.append(ev)

	for e in events:
		if e.get("once", false):
			shown[e["id"]] = true
		if e.get("type") == "shopping":
			# 接龙三段式：统一事件卡（标题+描述+单选）→ 选择物资卡 → 统一结果卡
			var ev2: Dictionary = e
			if bool(flags.get("volunteer", false)) and e.has("desc_volunteer"):
				ev2 = e.duplicate()
				ev2["desc"] = e["desc_volunteer"]
				ev2["result_after"] = e.get("result_after_volunteer", e.get("result_after", ""))
				ev2["art"] = e.get("art_volunteer", e.get("art", ""))
			deck.append({"kind": "event", "event": ev2})
			deck.append({"kind": "shopping", "event": ev2})
		else:
			deck.append({"kind": "event", "event": e})
	deck.append({"kind": "settlement", "day": d})
	_show_current()

# 动态选项数由 GameData.active_options 统一计算（1→上 / 2→左右 / 3→左上右）

# ------------------------------------------------------------------ 显示

func _clear_view() -> void:
	if is_instance_valid(current_view):
		current_view.queue_free()
		current_view = null

func _show_current() -> void:
	_clear_view()
	if cur < 0 or cur >= deck.size():
		return
	var card: Dictionary = deck[cur]
	match card["kind"]:
		"event":
			var ev: Dictionary = card["event"]
			if ev.get("type", "") == "shopping":
				# 接龙开场：0 个选项，CardView 显示既有灰色提示，任意方向滑动进入购物
				card["active_options"] = []
				card["option_count"] = 0
				last_event_id = ev["id"]
				_show_card_view(card)
			else:
				# 事件传入时检查可用选项数，并按数量归一化方向（1→上 / 2→左右 / 3→左上右）
				var opts: Array = GameData.active_options(ev, stats, flags, day)
				card["active_options"] = opts
				card["option_count"] = opts.size()
				last_event_id = ev["id"]
				if opts.is_empty():
					push_warning("事件 %s 无可用选项" % str(ev.get("id", "")))
				_show_card_view(card)
		"settlement":
			# 结算时判定结局：满足条件则用结局卡替换原结算卡（图片插在卡上）
			var ending: Dictionary = GameEndings.judge(stats, flags, day)
			if not ending.is_empty():
				deck[cur] = {"kind": "ending", "title": str(ending["title"]),
					"text": str(ending["text"]), "art": str(ending.get("art", ""))}
				Audio.play_sfx("end")
				_show_card_view(deck[cur])
			else:
				# 未触发结局：从五池结算提示中各选一条（居中显示）
				card["tips"] = GameData.settlement_tips(stats, flags)
				_show_card_view(card)
		"day", "result":
			_show_card_view(card)
		"shopping":
			_show_shopping(card)

func _card_color(card: Dictionary) -> Color:
	if card["kind"] == "event":
		return GameData.cat_color(card["event"].get("cat", ""))
	return GameData.NEUTRAL_COLOR

func _show_card_view(card: Dictionary) -> void:
	var cv := CardView.new()
	deck_parent.add_child(cv)
	cv.configure(card, day, _card_color(card))
	cv.released.connect(_on_released)
	current_view = cv
	Audio.play_sfx("flip")

func _show_shopping(card: Dictionary) -> void:
	var sc := ShoppingCard.new()
	deck_parent.add_child(sc)
	var ev: Dictionary = card["event"]
	# 志愿者版描述与结算文本已在 _build_day 统一替换
	var params: Dictionary = GameData.shopping_params(flags)
	var master: Array = GameData.shopping_master()
	sc.setup(ev, flags, master, int(params["show"]), int(params["choose"]))
	sc.completed.connect(_on_shopping_completed)
	current_view = sc
	Audio.play_sfx("flip")

func _event_by_id(id: String) -> Dictionary:
	for e in GameData.all_events():
		if e["id"] == id:
			return e
	return GameData.POOLS["固定"][0]

# ------------------------------------------------------------------ 交互

func _on_released(dir: String) -> void:
	if busy:
		return
	if cur < 0 or cur >= deck.size():
		return
	var card: Dictionary = deck[cur]
	if card["kind"] == "event":
		_resolve_event(card, dir)
	elif card["kind"] == "ending":
		_restart_after_ending()
	elif card["kind"] in ["day", "result", "settlement"]:
		_advance_card()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var dir := ""
		match event.keycode:
			KEY_LEFT, KEY_A: dir = "left"
			KEY_RIGHT, KEY_D: dir = "right"
			KEY_UP, KEY_W: dir = "up"
			KEY_R:
				if day > GameData.TOTAL_DAYS:
					restart()
				return
			_: return
		if dir != "":
			_on_key(dir)

func _on_key(dir: String) -> void:
	if busy or cur < 0 or cur >= deck.size():
		return
	var card: Dictionary = deck[cur]
	if card["kind"] == "event":
		_resolve_event(card, dir)
	elif card["kind"] == "ending":
		_restart_after_ending()
	elif card["kind"] == "shopping":
		# 键盘方向键等效「任意方向滑动」：选够才会提交
		if is_instance_valid(current_view) and current_view is ShoppingCard:
			(current_view as ShoppingCard).try_confirm()
	else:
		_advance_card()

func _resolve_event(card: Dictionary, dir: String) -> void:
	busy = true
	var ev: Dictionary = card["event"]
	if ev.get("type", "") == "shopping":
		# 统一事件卡（接龙开场）：无效果、无结果卡，滑动后直接进入选择物资卡
		if is_instance_valid(current_view) and current_view is CardView:
			(current_view as CardView).fly_out(_dir_sign(dir))
		await get_tree().create_timer(0.45).timeout
		cur += 1
		_show_current()
		busy = false
		return
	if ev.get("random", false):
		var outs: Array = ev["outcomes"]
		var out: Dictionary = outs[randi() % outs.size()]
		_apply_option(out)
		_insert_result(ev, out, dir)
		return
	var opt: Dictionary = {}
	for o in card.get("active_options", []):
		if str(o.get("dir", "")) == dir:
			opt = o
	if opt.is_empty():
		busy = false
		return
	opt = GameData.resolve_option(opt, flags, stats)
	_apply_option(opt)
	_insert_result(ev, opt, dir)

func _apply_option(opt: Dictionary) -> void:
	_apply_effects(opt.get("effects", {}))
	var sets: Dictionary = opt.get("set", {})
	for k in sets:
		flags[k] = sets[k]
	var decs: Dictionary = opt.get("dec", {})
	for k in decs:
		# 计数消耗：钳制不为负（鸡蛋/热干面等）
		flags[k] = maxi(0, int(flags.get(k, 0)) + int(decs[k]))
	if opt.get("duty_start", false):
		flags["duty_start"] = day
	var eff: Dictionary = opt.get("effects", {})
	var net := int(eff.get("mood", 0)) + int(eff.get("harmony", 0))
	Audio.play_sfx("good" if net >= 0 else "bad")

func _insert_result(ev: Dictionary, opt: Dictionary, dir: String) -> void:
	deck.insert(cur + 1, {
		"kind": "result",
		"title": str(ev.get("title", "")),
		"text": str(opt.get("result", "")),
		"deltas": opt.get("effects", {}),
		"art": str(ev.get("art", ""))
	})
	cur += 1
	if is_instance_valid(current_view) and current_view is CardView:
		(current_view as CardView).fly_out(_dir_sign(dir))
	await get_tree().create_timer(0.45).timeout
	_show_current()
	busy = false

func _dir_sign(dir: String) -> int:
	return -1 if dir == "left" else (1 if dir == "right" else 0)

## 结局卡滑动后重新开始游戏
func _restart_after_ending() -> void:
	if busy:
		return
	busy = true
	if is_instance_valid(current_view) and current_view is CardView:
		(current_view as CardView).fly_out(0)
	await get_tree().create_timer(0.45).timeout
	restart()

func _advance_card() -> void:
	busy = true
	if is_instance_valid(current_view) and current_view is CardView:
		(current_view as CardView).fly_out(0)
	await get_tree().create_timer(0.4).timeout
	cur += 1
	if cur >= deck.size():
		_finish_day()
	else:
		_show_current()
	busy = false

func _on_shopping_completed(eff: Dictionary, counters: Dictionary, result: String) -> void:
	if busy:
		return
	busy = true
	for k in counters:
		flags[k] = int(flags.get(k, 0)) + int(counters[k])
	_apply_effects(eff)
	var ev: Dictionary = deck[cur]["event"]
	deck.insert(cur + 1, {"kind": "result", "title": str(ev.get("title", "")), "text": str(result), "deltas": eff})
	cur += 1
	if is_instance_valid(current_view):
		current_view.queue_free()
		current_view = null
	await get_tree().create_timer(0.4).timeout
	_show_current()
	busy = false

func _finish_day() -> void:
	# 结局判定已前移到结算卡显示时（结局卡替换结算卡，见 _show_current）
	# 第 14 天结算必出好/完美结局卡，正常流程不会越界；防御性兜底：重开
	day += 1
	if day > GameData.TOTAL_DAYS:
		restart()
		return
	_build_day(day)
	busy = false

# ------------------------------------------------------------------ 数值

func _apply_effects(eff: Dictionary) -> void:
	var changed: Array = []
	for k in GameData.STAT_KEYS:
		var d := int(eff.get(k, 0))
		if d == 0:
			continue
		stats[k] = clampi(int(stats[k]) + d, 0, 100)
		changed.append([k, d])
	refresh_stats(true)
	if changed.is_empty():
		return
	_bump_later(changed)

func _bump_later(changed: Array) -> void:
	await get_tree().create_timer(0.18).timeout
	for c in changed:
		var bar: StatBar = stat_bars[c[0]]
		bar.bump(int(c[1]))

func refresh_stats(animate: bool) -> void:
	for k in GameData.STAT_KEYS:
		var bar: StatBar = stat_bars[k]
		bar.set_value(int(stats[k]), animate)

func restart() -> void:
	stats = GameData.initial_stats()
	flags = GameData.initial_flags()
	day = 1
	shown.clear()
	last_event_id = ""
	deck.clear()
	cur = 0
	busy = false
	if is_instance_valid(current_view):
		current_view.queue_free()
		current_view = null
	refresh_stats(false)
	Audio.play_music()
	_build_day(day)
