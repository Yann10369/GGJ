extends SceneTree

var failures: Array[String] = []
var checks := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok and not failures.has(message): failures.append(message)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_rules()
	_test_choices()
	var endings := {}
	for seed_value in 200:
		var run := _simulate(seed_value, true)
		check(run.ending.get("id") == "grown", "Supportive route must reach full ending: seed %d (%s)" % [seed_value, run.ending.get("id")])
		check(run.shown.get("party_squad", 99) <= 9, "Party route missed Day 9")
		check(run.shown.get("talk", 99) <= 3, "Talk missed early window")
		check(run.shown.get("test2", 99) < run.final_day, "Son followup missed epilogue")
		check(run.shown.get("good_dad", 99) < run.final_day, "Daughter followup missed epilogue")
	for seed_value in 200:
		var run := _simulate(seed_value, false)
		var id: String = run.ending.get("id", "missing")
		endings[id] = int(endings.get(id, 0)) + 1
	print("Random-play endings: ", endings)
	print("Grow checks: ", checks, "; failures: ", failures.size())
	for failure in failures: printerr(failure)
	quit(0 if failures.is_empty() else 1)

func _test_rules() -> void:
	var run := GrowRun.new(1)
	check(run.events.size() == 28, "All 28 templates load")
	check(run.stats == {"mood":60,"harmony":40,"immunity":70,"supplies":55}, "Initial stats")
	check(run.flags["egg"] == 0, "Eggs require procurement")
	check(not GameData.matches({"flags":{"typo":false}}, run.stats, run.flags), "Unknown flags fail closed")
	check(not GameData.matches({"unknown":{}}, run.stats, run.flags), "Unknown condition fails closed")
	check(not run.choose(0), "Cannot choose in morning")
	check(not run.continue_run(), "Cannot skip daily action")
	check(run.act(3), "Daily action accepted")
	check(not run.act(3), "Only one daily action")
	check(run.current["id"] == "lockdown", "Opening is lockdown")
	check(run.choose(0), "Opening choice accepted")
	var snapshot := run.stats.duplicate()
	check(not run.choose(0) and run.stats == snapshot, "Double choice is rejected")
	run.continue_run()
	check(run.current["id"] == "ordering", "Day 1 second slot is shopping")
	check(run.shop["items"].size() == 5 and run.shop["choose"] == 3, "Normal shop 5 choose 3")
	var ids: Array = []
	for item in run.shop["items"].slice(0,3): ids.append(item["id"])
	check(not run.purchase([ids[0],ids[0],ids[0]]), "Duplicate purchase rejected")
	check(not run.purchase(["fake","fake2","fake3"]), "Forged purchase rejected")
	check(run.purchase(ids), "Valid purchase accepted")
	check(not run.purchase(ids), "Double purchase rejected")
	run.continue_run()
	check(run.phase == GrowRun.Phase.NIGHT and run.stats["supplies"] == 63, "Organized night consumes 2 exactly once")
	run.continue_run()
	check(run.day == 2 and run.stats["supplies"] == 63, "No duplicate night settlement")
	run.flags["community_volunteer"] = true
	var shop := GameData.shopping_items(run.by_id["ordering"], run.flags, run.rng)
	check(shop["items"].size() == 7 and shop["choose"] == 4, "Volunteer shop 7 choose 4")
	for zeros in [{"immunity":0,"mood":0,"supplies":0}, {"mood":0,"supplies":0}, {"supplies":0}]:
		var stats := GameData.initial_stats()
		stats.merge(zeros,true)
		var expected := "hospital" if zeros.has("immunity") else ("leave" if zeros.has("mood") else "aid")
		check(GameData.compute_ending(stats,run.flags)["id"] == expected, "Ending priority " + expected)
	run = GrowRun.new(8)
	run.stats["harmony"] = 0
	run.day = 3
	run.slots_used = 2
	run.phase = GrowRun.Phase.RESULT
	run.continue_run()
	check(run.ending.is_empty(), "Zero harmony is not fatal")
	check(run.stats["supplies"] == 52, "Basic night consumption 3")
	run = GrowRun.new(9)
	run.stats["supplies"] = 25
	run.stats["mood"] = 1
	run.slots_used = 2
	run.phase = GrowRun.Phase.RESULT
	run.continue_run()
	check(run.stats["mood"] == 0 and run.ending["id"] == "leave", "Low supply penalty precedes ending")
	check(GrowRun.new(0, 24).final_day == 24, "Length is configurable")
	check(GrowRun.new(0, 5).final_day >= 20, "Authored deadlines protect ending time")
	run = GrowRun.new(4)
	run.day = 18
	run.schedule("test2", 3)
	check(run.final_day == 23, "Late main-story consequence extends epilogue")
	for expected in ["hospital","leave","aid"]:
		run = GrowRun.new(0)
		run.stats[{"hospital":"immunity","leave":"mood","aid":"supplies"}[expected]] = 0
		run.slots_used = 2
		run.phase = GrowRun.Phase.RESULT
		run.continue_run()
		check(run.ending.get("id") == expected, "Night actually triggers " + expected)
		run.continue_run()
		check(run.phase == GrowRun.Phase.RECAP, "Early ending shows recap before title")

func _test_choices() -> void:
	var run := GrowRun.new(2)
	check(GameData.visible_options(run.by_id["test"],run.stats,run.flags).size() == 2, "No truth option without talk")
	run.flags["talk_with_son"] = true
	check(GameData.visible_options(run.by_id["test"],run.stats,run.flags).size() == 3, "Talk unlocks third truth option")
	check(not run.can_show(run.by_id["return_gift"]), "Reciprocity requires actual help")
	run.day = 8
	run.flags["help_neighbor"] = true
	run.schedule("paper_bag",3)
	check(not run.can_show(run.by_id["paper_bag"]), "Seed does not show before due date")
	run.day = 11
	check(run.can_show(run.by_id["paper_bag"]), "Seed becomes eligible after delay")
	# Verify cancels the actual clamped action gain, not the nominal gain.
	run = GrowRun.new(3)
	run.stats["immunity"] = 98
	run.act(0)
	run.current = run.by_id["rumor"].duplicate(true)
	run.current["truth"] = true
	run.options = GameData.visible_options(run.current,run.stats,run.flags)
	check(run.choose(1) and run.stats["immunity"] == 98, "Verification rolls back actual action effect")
	check(run.pending.size() == 1 and run.pending[0]["truth"], "Rumor stores hidden truth in delayed delivery")
	var outcomes := {}
	for seed_value in 40:
		run = GrowRun.new(seed_value)
		run.phase = GrowRun.Phase.EVENT
		run.current = run.by_id["slip_through"].duplicate(true)
		run.options.assign(run.current["options"])
		run.choose(seed_value % 3)
		outcomes[run.last_result] = true
	check(outcomes.size() == 2, "All three exploration choices have uncertain outcomes")

func _simulate(seed_value: int, supportive: bool) -> GrowRun:
	var run := GrowRun.new(seed_value)
	var policy_rng := RandomNumberGenerator.new()
	policy_rng.seed = seed_value + 1000
	var safety := 0
	while run.phase != GrowRun.Phase.ENDING and safety < 300:
		safety += 1
		match run.phase:
			GrowRun.Phase.MORNING:
				var action := policy_rng.randi_range(0,3)
				if supportive:
					action = 0 if int(run.stats["immunity"]) < 45 else (1 if int(run.stats["mood"]) < 65 else 2)
				run.act(action)
			GrowRun.Phase.EVENT:
				var id: String = run.current["id"]
				if run.current.get("type") == "shopping":
					var ids: Array = []
					for item in run.shop["items"].slice(0,run.shop["choose"]): ids.append(item["id"])
					check(run.purchase(ids), "Simulation purchase")
				else:
					check(not run.options.is_empty(), "No empty option list")
					var index := policy_rng.randi_range(0,run.options.size()-1)
					if supportive:
						index = 0
						if id in ["talk","gaming"]: index = 1
						if id in ["test","online_romance"]: index = run.options.size()-1
					check(run.choose(index), "Simulation choice")
				check(run.slots_used <= 2, "No more than two daily cards")
				if id == "test": check(run.day - int(run.shown.get("gaming",0)) >= 3, "Son delay respected")
				if id == "test2": check(run.day - int(run.shown.get("test",0)) >= 3, "Second test delay respected")
				if id == "good_dad": check(run.day - int(run.shown.get("online_romance",0)) >= 4, "Daughter delay respected")
			_:
				run.continue_run()
		for key in GameData.STAT_KEYS: check(int(run.stats[key]) >= 0 and int(run.stats[key]) <= 100, "Stats stay bounded")
	check(safety < 300 and not run.ending.is_empty(), "Run terminates")
	if run.day == run.final_day: check(run.shown.has("eve"), "Epilogue precedes final ending")
	var shopping_days: Array = []
	for entry in run.history:
		if entry["id"] == "ordering": shopping_days.append(entry["day"])
	var expected: Array = []
	for day in [1,5,9,13,17]:
		if day <= run.day: expected.append(day)
	check(shopping_days == expected, "All fixed shopping days fire exactly once")
	return run
