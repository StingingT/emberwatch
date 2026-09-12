extends SceneTree
## Staged runtime views for visual QA, separate from the gameplay tests.
const GameScript = preload("res://game/game.gd")
var game: Node3D

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	game = GameScript.new()
	game.persistent_profile = false
	root.add_child(game)
	await process_frame
	await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))
	var ignore: FileAccess = FileAccess.open("res://artifacts/.gdignore", FileAccess.WRITE)
	ignore.close()
	await _capture("title")
	game.start_run()
	game.set_physics_process(false)
	await _capture("tower_plot_preview")
	game.coins = 2000
	game.hero.position = Vector3(-6, 0, -1.5)
	game.build_at("bend", "tower")
	game.upgrade_at("bend")
	game.hero.position = Vector3(-3, 0, -5)
	game.build_at("choke", "wall")
	game.upgrade_at("choke")
	game.hero.position = Vector3(2, 0, -8.2)
	game.build_at("crossing", "tower")
	game.hero.position = Vector3(4.2, 0, -0.1)
	game.build_at("forge", "smith")
	game.hero.position = Vector3(-6, 0, 2.5)
	game.build_at("quarry", "mine")
	game.hero.position = Vector3(3.2, 0, 1.5)
	game.build_at("watch", "tower")
	game.hero.position = Vector3(-1.0, 0, -3.8)
	game.hero.add_xp(16)
	game.coins = 124
	game.wave_index = 2
	game.wave_active = true
	game.wave_cursor = 12
	# Earlier-wave fixture kills keep this staged state valid for pause recovery.
	game.kills = game.wave_configs[0]["enemies"].size() + game.wave_configs[1]["enemies"].size()
	game._camera_focus = game.hero.position + Vector3(0, 0, -2)
	game._update_camera(1.0)
	for i: int in range(12):
		var enemy: Node3D = game.spawn_enemy("brute" if i % 4 == 0 else "goblin", float(game.wave_configs[2]["health_scale"]))
		enemy.position = Vector3(-3.0 + float(i % 3) * 0.42, 0, -10.0 - float(i) * 0.85)
		enemy.route_index = 4
		if enemy.position.z < -11.0:
			enemy.route_index = 3
	for i: int in range(3):
		game.drop_coin(Vector3(-3.2 + i * 0.5, 0, -4.8), 9)
	for frame: int in range(70):
		await physics_frame
		game._update_camera(1.0 / 60.0)
	game._update_selection()
	game._update_hud()
	game.hud._toast_remaining = 0.0
	game.hud._toast_panel.hide()
	await _capture("gameplay")
	# Dedicated fixture holds short-lived feedback still for visual inspection.
	game.feedback.set_process(false)
	game.feedback.clear()
	# Stage a partly defeated, fully spawned wave to inspect the filled bar.
	game.kills += game.wave_configs[game.wave_index]["enemies"].size() - game.wave_cursor
	game.wave_cursor = game.wave_configs[game.wave_index]["enemies"].size()
	game.collect_coin(27, game.hero.position)
	game.feedback.hit(Vector3(-3, 0, -10.0), true)
	game.feedback.construction(game.buildings["bend"].position)
	game.feedback._process(0.1)
	game._update_hud()
	await _capture("feedback")
	game.feedback.clear()
	game.feedback.set_process(true)
	game.hero.position = Vector3(3.2, 0, -3.8)
	game._camera_focus = game.hero.position + Vector3(0, 0, -2)
	game._update_camera(1.0)
	game._update_selection()
	game._update_hud()
	await _capture("smith")
	game.buy_smith_upgrade("ranged")
	for frame: int in range(6):
		await process_frame
	await _capture("smith_purchase")
	# Inspect the production upgrade offers for all other structure types.
	for plot_id: String in ["bend", "choke", "quarry"]:
		game.hero.position = game._plot_by_id(plot_id)["position"] + Vector3(0, 0, 2.2)
		game._camera_focus = game.hero.position + Vector3(0, 0, -2)
		game._update_camera(1.0)
		game._update_selection()
		game._update_hud()
		await _capture("upgrade_" + plot_id)
	game.pause_run()
	await _capture("pause")
	print("CAPTURE_PASS")
	game.queue_free()
	await process_frame
	quit()

func _capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = "res://artifacts/%s.png" % label
	var error: Error = image.save_png(path)
	print("capture ", label, " ", image.get_size(), " result=", error)
