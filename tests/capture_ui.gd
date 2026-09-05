extends SceneTree

var main: Control

func _init() -> void:
	call_deferred("_run")

func capture(name: String) -> void:
	for i in 5: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/output/%s.png" % name)

func _run() -> void:
	DirAccess.make_dir_recursive_absolute("res://tests/output")
	main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	await capture("morning")
	main._act(0)
	await capture("card")
	main.run.choose(0)
	main.run.continue_run()
	main.render()
	await capture("shopping")
	main.run.flags["community_volunteer"] = true
	main.run.shop = GameData.shopping_items(main.run.current,main.run.flags,main.run.rng)
	main.render()
	await capture("shopping_volunteer")
	main.run.current = main.run.by_id["online_romance"]
	main.run.options = GameData.visible_options(main.run.current,main.run.stats,main.run.flags)
	main.render()
	await capture("three_choices")
	main.run.choose(0)
	main.render()
	await capture("long_result")
	main.queue_free()
	root.get_node("Audio").stop_all()
	await create_timer(0.2).timeout
	quit()
