extends SceneTree
## Staged visual QA through the actual game root, not a legal-playthrough claim.
## Fixture gold, health, XP, elapsed time and enemy placement are controlled.
## Both player stores are disabled BEFORE _ready; only artifact PNGs are written.
## godot --path . --script tools/capture_recovery.gd --rendering-driver opengl3
const GameScript = preload("res://game/game.gd")
var _game: Node3D
var _failures: Array[String] = []
var _captured: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Recovery capture requires the actual Compatibility renderer.")
		quit(1)
		return
	root.content_scale_size = Vector2i(720, 1280)
	root.size = Vector2i(720, 1280)
	_game = GameScript.new()
	_game.persistent_profile = false
	root.add_child(_game)
	_freeze()
	if not _game.profile.save_path.is_empty() or not _game.run_store.save_path.is_empty():
		_failures.append("Recovery capture must use memory-only profile and run stores.")
		await _finish()
		return
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts")) != OK:
		_failures.append("Could not create the artifact directory.")
		await _finish()
		return
	_game.change_setting("sound", false)
	_game.change_setting("tutorial_hints", false)
	_add_fixture_caption()
	_game.start_run()
	_freeze()
	_stage_defense()
	var snapshot: Dictionary = _game.capture_run_snapshot()
	var checked: Dictionary = _game.validate_run_snapshot(snapshot)
	if not checked.get("ok", false):
		_failures.append("Invalid staged recovery snapshot: " + str(checked.get("error", "unknown")))
		await _finish()
		return
	if not _game.save_interrupted_run():
		_failures.append("The staged memory-only defense could not checkpoint.")
		await _finish()
		return
	_game.return_to_menu()
	if _game.state != "menu" or _game.hud._continue_summary.is_empty():
		_failures.append("Return to title did not present the saved defense.")
	_clear_transient_hud()
	for frame: int in range(32):
		await process_frame
	await _capture("recovery_title")
	if not _game.continue_defense() or _game.state != "paused" or _game.hud._overlay_mode != "pause":
		_failures.append("Continue did not restore the defense to its pause screen.")
		await _finish()
		return
	_freeze()
	_clear_transient_hud()
	if not is_equal_approx(_game.elapsed, float(snapshot["elapsed"])) or _game.coins != int(snapshot["coins"]):
		_failures.append("Continue changed the checkpoint's time or wallet while paused.")
	await _capture("recovery_paused")
	_game.resume_run()
	if _game.state != "playing" or not _game.hud._playing_ui:
		_failures.append("Resume did not restore playable gameplay.")
		await _finish()
		return
	_set_simulation(true)
	for frame: int in range(18):
		await physics_frame
	_freeze()
	_game._update_selection()
	_game._update_hud()
	_clear_transient_hud()
	if _game.elapsed <= float(snapshot["elapsed"]):
		_failures.append("The resumed defense did not advance through real physics frames.")
	await _capture("recovery_resumed")
	await _finish()


func _stage_defense() -> void:
	_game.coins = 1500
	for purchase: Array in [["bend", "tower", true], ["crossing", "tower", false], ["choke", "wall", true], ["forge", "smith", false], ["quarry", "mine", false]]:
		var id: String = purchase[0]
		_game.hero.position = _game._plot_by_id(id)["position"] + Vector3(0, 0, 2.3)
		if not _game.build_at(id, purchase[1]):
			_failures.append("Fixture purchase failed: " + id)
			continue
		if purchase[2] and not _game.upgrade_at(id):
			_failures.append("Fixture upgrade failed: " + id)
	_game.hero.position = Vector3(-1, 0, -3.8)
	_game.hero.add_xp(49)
	_game.hero.ability_cooldown = 4.2
	_game.keep_health = 382.0
	_game.coins = 124
	_game.coins_collected = 267
	_game.wave_index = 1
	_game.wave_active = true
	_game.wave_cursor = 7
	_game.wave_timer = 0.65
	_game.kills = _game.wave_configs[0]["enemies"].size() + 1
	_game.elapsed = 83.25
	_game._used_volley = true
	for index: int in range(1, 7):
		var enemy: Node3D = _game.spawn_enemy(str(_game.wave_configs[1]["enemies"][index]), float(_game.wave_configs[1]["health_scale"]))
		enemy.position = Vector3(-3.0 + float(index % 2) * 0.5, 0, -8.5 - index * 1.15)
		enemy.route_index = 4 if enemy.position.z >= -11.0 else 3
		enemy.health -= float(index % 3) * 3.0
	_game.spawn_arrow(_game.hero.position + Vector3(0, 1.25, 0), _game.enemies[0], 18.0, "hero")
	_game.drop_coin(Vector3(-3.4, 0, -4.8), 18)
	_game.drop_coin(Vector3(2.2, 0, -7.0), 13)
	_game._camera_focus = _game.hero.position + Vector3(0, 0, -2)
	_game._update_camera(1.0)
	_game._update_selection()
	_game._update_hud()
	_freeze()


func _freeze() -> void:
	_set_simulation(false)


func _set_simulation(enabled: bool) -> void:
	_game.set_physics_process(enabled)
	for container: Node3D in [_game._actors, _game._projectiles, _game._coins]:
		for actor: Node in container.get_children():
			actor.set_physics_process(enabled)
	for building: Node3D in _game.buildings.values():
		building.set_physics_process(enabled)


func _clear_transient_hud() -> void:
	_game.feedback.clear()
	_game.hud.show_hint("")
	_game.hud._toast_remaining = 0.0
	_game.hud._toast_panel.hide()


func _add_fixture_caption() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 80
	root.add_child(layer)
	var caption := Label.new()
	caption.text = "STAGED RECOVERY FIXTURE · MEMORY-ONLY SAVES"
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 15)
	caption.add_theme_color_override("font_color", Color("cbd1b8"))
	caption.add_theme_color_override("font_shadow_color", Color("071b14"))
	caption.add_theme_constant_override("shadow_outline_size", 3)
	layer.add_child(caption)
	caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	caption.offset_top = -22


func _capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var screenshot: Image = root.get_texture().get_image()
	var path: String = "res://artifacts/%s.png" % label
	var error: Error = screenshot.save_png(path)
	if error != OK:
		_failures.append("Could not save %s (error %d)." % [path, error])
		return
	_captured += 1
	print("RECOVERY_CAPTURE ", label, " ", screenshot.get_size(), " status=", error)


func _finish() -> void:
	_game.queue_free()
	await process_frame
	await process_frame
	if not _failures.is_empty() or _captured != 3:
		for failure: String in _failures:
			push_error(failure)
		quit(1)
		return
	print("RECOVERY_CAPTURE_PASS: title, restored pause, resumed defense; staged fixture; both player stores memory-only")
	quit(0)
