extends Node

## One authoritative run. Main only renders it and forwards input.
@export var story_days := 20
var run: GrowRun

func start_new_game(seed_value: int = -1) -> void:
	run = GrowRun.new(seed_value, story_days)
	SignalBus.day_started.emit(run.day)

func is_game_over() -> bool:
	return run != null and not run.ending.is_empty()

func get_ending() -> Dictionary:
	return run.ending if run != null else {}
