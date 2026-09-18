extends "res://tools/capture_game.gd"

func _run() -> void:
	game = GameScript.new()
	game.persistent_profile = false
	root.add_child(game)
	game.start_run()
	game.set_physics_process(false)
	game.hero.set_physics_process(false)
	game.coins = 10000
	var plots: Dictionary = {"bend": "tower", "choke": "wall", "quarry": "mine", "forge": "smith"}
	for tier: int in range(1, 4):
		for id: String in plots:
			game.hero.position = game._plot_by_id(id)["position"] + Vector3(0, 0, 2.2)
			var changed: bool = game.build_at(id, plots[id]) if tier == 1 else game.upgrade_at(id)
			if not changed:
				push_error("Cannot stage %s tier %d" % [id, tier])
				quit(1)
				return
			game.buildings[id].set_physics_process(false)
		game.hero.position = Vector3(0, 0, -1)
		game._camera_focus = Vector3(0, 0, -3)
		game._update_camera(1.0)
		game._update_selection()
		game._update_hud()
		game.hud._toast_panel.hide()
		# Allow the construction animation to settle before capturing its final silhouette.
		for frame: int in range(45):
			await process_frame
		await _capture("building_tier_%d" % tier)
		for id: String in plots:
			game.hero.position = game._plot_by_id(id)["position"] + Vector3(0, 0, 2.2)
			game._camera_focus = game._plot_by_id(id)["position"]
			game._update_camera(1.0)
			game._update_selection()
			game._update_hud()
			game.hud._toast_remaining = 0.0
			game.hud._toast_panel.hide()
			await _capture("%s_tier_%d" % [plots[id], tier])
	game.queue_free()
	await process_frame
	print("BUILDING_TIERS_CAPTURE_PASS")
	quit(0)
