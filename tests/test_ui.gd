extends SceneTree

var failed := false
var main: Control

func _init() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		printerr(message)

func _frames() -> void:
	for i in 4: await process_frame

func drag_card(delta: Vector2, touch := false) -> void:
	# Start over the story text: RichTextLabel used to intercept this gesture.
	var point: Vector2 = main.top_card._description.get_global_rect().get_center()
	if touch:
		var down := InputEventScreenTouch.new()
		down.index = 0
		down.position = point
		down.pressed = true
		root.push_input(down, true)
		var move := InputEventScreenDrag.new()
		move.index = 0
		move.position = point + delta
		move.relative = delta
		root.push_input(move, true)
		var up := InputEventScreenTouch.new()
		up.index = 0
		up.position = point + delta
		root.push_input(up, true)
	else:
		var down := InputEventMouseButton.new()
		down.position = point
		down.button_index = MOUSE_BUTTON_LEFT
		down.pressed = true
		root.push_input(down, true)
		var move := InputEventMouseMotion.new()
		move.position = point + delta
		move.relative = delta
		move.button_mask = MOUSE_BUTTON_MASK_LEFT
		root.push_input(move, true)
		var up := InputEventMouseButton.new()
		up.position = point + delta
		up.button_index = MOUSE_BUTTON_LEFT
		root.push_input(up, true)

func click_at(point: Vector2) -> void:
	var down := InputEventMouseButton.new()
	down.position = point
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	root.push_input(down, true)
	var up := InputEventMouseButton.new()
	up.position = point
	up.button_index = MOUSE_BUTTON_LEFT
	root.push_input(up, true)

func _run() -> void:
	main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	await _frames()
	check(main.actions.get_child_count() == 4, "Four daily actions visible")
	check(main.actions.get_global_rect().end.y <= root.get_visible_rect().size.y, "Morning actions fit viewport")
	main.actions.get_child(0).pressed.emit()
	await _frames()
	check(main.run.current["id"] == "lockdown", "Action opens opening card")
	check(is_instance_valid(main.top_card), "Card is rendered")
	check(main.actions.find_children("*", "Button", true, false).is_empty(), "Binary choice has no decision buttons")
	check(main.swipe_choices.size() == 2, "Both swipe meanings remain visible")
	main._open_journal()
	await _frames()
	check(not main.top_card.interactive, "Journal blocks card dragging")
	main._close_journal()
	drag_card(Vector2(0, 80))
	check(main.run.phase == GrowRun.Phase.EVENT, "Vertical reading gesture does not decide")
	drag_card(Vector2(-35, 0))
	check(main.run.phase == GrowRun.Phase.EVENT, "Short drag does not decide")
	await create_timer(0.5).timeout
	var left_choice: String = main.run.options[0]["label"]
	drag_card(Vector2(-160, 0))
	main._on_swipe(-160)
	await create_timer(0.35).timeout
	check(main.run.history.size() == 1, "Repeated swipe applies one choice")
	check(main.run.history[0]["choice"] == left_choice, "Mouse swipe left over text chooses left")
	main.actions.get_child(0).pressed.emit()
	await _frames()
	check(is_instance_valid(main.shopping_card), "Phone procurement renders")
	var phone: ShoppingCard = main.shopping_card
	check(phone._phone.get_child(0).size == phone._phone.size, "Phone background fills shell")
	check(phone._buttons.size() == 5, "Phone offers five distinct items")
	var keys: Array = phone._buttons.keys()
	for key in keys.slice(0,3): phone._buttons[key].button_pressed = true
	phone._buttons[keys[3]].button_pressed = true
	check(not phone._buttons[keys[3]].button_pressed, "Fourth selection is refused")
	check(not phone._confirm.disabled, "Three selections enable order")
	phone._confirm.pressed.emit()
	await _frames()
	check(main.run.phase == GrowRun.Phase.RESULT, "Purchase opens result")
	check(main.run.history.size() == 2, "Purchase applied once")
	# Render every event with all flags/counters enabled where relevant.
	for event in main.run.events:
		if event.get("type") == "shopping": continue
		main.run.phase = GrowRun.Phase.EVENT
		main.run.current = event.duplicate(true)
		if event.get("special") == "rumor": main.run.current["truth"] = false
		main.run.flags["talk_with_son"] = true
		main.run.options = GameData.visible_options(event,main.run.stats,main.run.flags)
		main.render()
		await _frames()
		var binary: bool = main.run.options.size() == 2
		var buttons: Array = main.actions.find_children("*", "Button", true, false)
		check(buttons.size() == (0 if binary else main.run.options.size()), "Interaction matches visible options: " + event["id"])
		check(main.actions.get_global_rect().end.y <= root.get_visible_rect().size.y, "Choice buttons fit viewport: " + event["id"])
		check(main.top_card.interactive == binary, "Only binary cards allow dragging")
		check(main.stage.get_global_rect().end.y <= main.actions.get_global_rect().position.y, "Card area does not overlap decision area")
		if not binary:
			main._on_swipe(160)
			check(main.run.phase == GrowRun.Phase.EVENT, "Multi-choice ignores swipe")
			var before: int = main.run.history.size()
			click_at(buttons[-1].get_global_rect().get_center())
			check(main.run.history.size() == before + 1, "Last button receives real pointer click: " + event["id"])
			await create_timer(0.3).timeout
	main.run.flags["community_volunteer"] = true
	main.run.phase = GrowRun.Phase.EVENT
	main.run.current = main.run.by_id["ordering"]
	main.run.shop = GameData.shopping_items(main.run.current,main.run.flags,main.run.rng)
	main.render()
	await _frames()
	check(main.shopping_card._buttons.size() == 7, "Volunteer phone offers seven items")
	main.run.phase = GrowRun.Phase.ENDING
	main.run.ending = GameData.compute_ending(main.run.stats,main.run.flags)
	main.render()
	await _frames()
	main.actions.get_child(0).pressed.emit()
	await _frames()
	check(main.run.phase == GrowRun.Phase.MORNING and main.run.history.is_empty(), "Restart clears run")
	main._act(0)
	await _frames()
	var right_choice: String = main.run.options[1]["label"]
	drag_card(Vector2(160, 0), true)
	check(main.run.history.size() == 1 and main.run.history[0]["choice"] == right_choice, "Touch swipe right chooses right")
	await create_timer(0.3).timeout
	main.queue_free()
	root.get_node("Audio").stop_all()
	await create_timer(0.2).timeout
	await _frames()
	print("UI smoke: ", "FAILED" if failed else "PASS")
	quit(1 if failed else 0)
