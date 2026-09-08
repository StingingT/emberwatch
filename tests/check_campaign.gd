extends SceneTree
## Campaign lifecycle fixtures use controlled victories, placement, and resources.
## These checks do not establish combat balance; the legal playthrough does that.
## The real game root runs with a memory-only profile and never opens player saves.
const GameScript = preload("res://game/game.gd")
const Data = preload("res://game/game_data.gd")
var game: Node3D
var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	game = GameScript.new()
	game.persistent_profile = false
	root.add_child(game)
	_freeze()
	await process_frame
	_check(game.profile.save_path.is_empty(), "Campaign integration uses a memory-only profile")
	var rows: Array[Dictionary] = game.campaign_rows()
	_check(rows.size() == 6 and rows[0]["id"] == "briarwood" and rows[5]["id"] == "emberfall", "The campaign exposes all six authored missions in order")
	var only_first: bool = bool(rows[0]["unlocked"])
	for index: int in range(1, rows.size()):
		only_first = only_first and not bool(rows[index]["unlocked"]) and int(rows[index]["stars"]) == 0
	_check(only_first and not game.mission_unlocked(-1) and not game.mission_unlocked(6), "Only the first mission is initially unlocked and invalid indices stay locked")
	var initial_hero: Node3D = game.hero
	_check(not game.start_mission("emberfall") and not game.start_mission("unknown"), "Locked and unknown mission selections are rejected")
	_check(game.state == "menu" and game.hero == initial_hero and game.mission_index == 0, "Rejected selection leaves the current world and state untouched")
	game.hud.campaign_requested.emit()
	_check(game.state == "campaign" and game.hud._mission_buttons.size() == 6, "The campaign HUD signal opens the root's six-mission selection")
	_check(not game.hud._mission_buttons["briarwood"].disabled and game.hud._mission_buttons["amberfield"].disabled, "Campaign button availability follows root unlock state")
	game.return_to_menu()
	_test_settings()
	game.hud.play_requested.emit()
	_freeze()
	_check(game.is_playing() and game.mission_index == 0, "Title play starts the first uncompleted mission")
	_check(game.coins == Data.STARTING_COINS and is_equal_approx(game.keep_max, Data.KEEP_HEALTH), "Briarwood retains its original starting gold and Keep health")
	_test_tutorial_and_motion()
	game.damage_keep(game.keep_health)
	_check(game.state == "lost" and game.profile.data["results"].is_empty() and not game.mission_unlocked(1), "A real Keep defeat records no victory and unlocks no mission")
	game._finish_run(true)
	game.next_mission()
	_check(game.state == "lost" and game.profile.data["results"].is_empty(), "A finished loss cannot become a victory or advance via stale callbacks")
	_check(game.start_mission("briarwood"), "An unlocked mission can restart after defeat")
	_freeze()
	_prepare_dirty_run()
	var previous_hero: Node3D = game.hero
	var previous_enemy: Node3D = game.enemies[0]
	var previous_building: Node3D = game.buildings["forge"]
	var previous_route: Array = game.level["route"].duplicate()
	var previous_plots: Array = game.plot_views.keys()
	_win(1.0, 80.0)
	_check(game.state == "won" and game.profile.data["results"]["briarwood"]["stars"] == 3, "A healthy first victory records three stars")
	_check(game.mission_unlocked(1) and not game.mission_unlocked(2), "Victory unlocks the next mission only")
	_check(_has_label("★★★"), "The result screen receives the stars earned by this run")
	game.elapsed = 20.0
	game._finish_run(true)
	_check(is_equal_approx(game.profile.data["results"]["briarwood"]["best_time"], 80.0), "Duplicate finish callbacks cannot rewrite the completion time")
	# This isolated level override verifies that fortification uses a mission's
	# configured Keep health rather than the global Briarwood default.
	game.missions[1]["level"]["keep_health"] = 620.0
	game.hud.next_requested.emit()
	_freeze()
	_check(game.state == "playing" and game.mission_index == 1, "The real Next Mission signal starts Amberfield")
	_check(previous_hero.get_parent() == null and previous_enemy.get_parent() == null and previous_building.get_parent() == null, "Next Mission detaches the old hero, enemies, and structures immediately")
	_check(game._actors.get_child_count() == 1 and game.enemies.is_empty() and game.buildings.is_empty() and game._structures.get_child_count() == 1, "Next Mission leaves one fresh hero and the Keep without old combat actors")
	_check(game._projectiles.get_child_count() == 0 and game._coins.get_child_count() == 0 and game.feedback.hits.is_empty() and game.feedback.pickups.is_empty(), "Next Mission clears arrows, physical gold, and transient feedback")
	_check(game.coins == 110 and game.coins_collected == 0 and game.kills == 0, "Amberfield applies its own starting gold and resets run economy")
	_check(game.hero != previous_hero and game.hero.tier == 1 and game.hero.xp == 0 and is_zero_approx(game.hero.ability_cooldown), "Next Mission resets hero levels, XP, and Volley cooldown")
	_check(game.smith_levels == {"ranged": 0, "haste": 0, "fortify": 0} and is_equal_approx(game.keep_health, 620.0) and is_equal_approx(game.keep_max, 620.0), "Next Mission resets Smith bonuses and uses the configured base Keep health")
	_check(game.wave_index == -1 and game.wave_cursor == 0 and not game.wave_active and is_zero_approx(game.elapsed), "Next Mission restarts wave scheduling and run time")
	_check(game.level["route"] != previous_route and game.level["route"] == game.missions[1]["level"]["route"] and game.wave_configs.size() == 5, "Amberfield replaces the route and six-wave roster with its authored five waves")
	_check(game.plot_views.keys() != previous_plots and game.plots == game.missions[1]["level"]["plots"] and game._plot_root.get_child_count() == game.plots.size(), "Amberfield replaces old construction plots and their views")
	_check(game.hero.position == game.level["hero"] and game._keep_model.position == game.level["keep"], "Mission-specific hero and Keep positions reach the runtime world")
	var current_hero: Node3D = game.hero
	_check(not game.start_mission("briarwood") and game.hero == current_hero, "A mission cannot be switched while combat is running")
	_test_custom_keep_fortification()
	_win(0.5, 120.0)
	_check(game.profile.data["results"]["amberfield"]["stars"] == 2 and game.mission_unlocked(2), "A half-health victory awards two stars and unlocks Stonegate")
	game.return_to_menu()
	_check(game.start_mission("briarwood"), "A completed mission remains replayable")
	_freeze()
	game._update_hud()
	_check(game.hud._hint_text.is_empty(), "Completed first missions do not repeat first-run tutorial hints")
	_win(0.1, 150.0)
	_check(game.profile.data["results"]["briarwood"]["stars"] == 3 and is_equal_approx(game.profile.data["results"]["briarwood"]["best_time"], 80.0), "A weaker slower replay preserves the best saved stars and time")
	_check(_has_label("★☆☆"), "Replay results show this run's one star while the profile keeps its best three")
	game.return_to_menu()
	game.hud.play_requested.emit()
	_freeze()
	_check(game.mission_index == 2 and game.coins == 120, "Title play selects the next uncompleted mission with its starting gold")
	_win(0.1, 135.0)
	_check(game.profile.data["results"]["stonegate"]["stars"] == 1, "A low-health successful defense awards one star")
	game.next_mission()
	_freeze()
	_check(game.mission_index == 3 and game.coins == 150, "Sunscar starts with its authored economy")
	_win(1.0, 140.0)
	game.next_mission()
	_freeze()
	_check(game.mission_index == 4 and game.coins == 160, "Moonfen starts with its authored economy")
	_test_moonfen_mines()
	_win(1.0, 155.0)
	game.next_mission()
	_freeze()
	_check(game.mission_index == 5 and game.coins == 180 and game.wave_configs.size() == 7, "Emberfall starts with its final seven-wave roster and starting gold")
	_test_campaign_completion()
	_check(game.profile.data["settings"]["large_controls"] and game.profile.data["settings"]["reduced_motion"], "Player preferences survive every mission transition and replay")
	game.queue_free()
	await process_frame
	await process_frame
	if failures == 0:
		print("CAMPAIGN_CHECKS_PASS: %d checks" % checks)
		quit(0)
	else:
		quit(1)


func _test_settings() -> void:
	game.hud.show_settings()
	game.hud._setting_buttons["sound"].pressed.emit()
	_check(not game.profile.data["settings"]["sound"] and not game.sounds.enabled and not game.hud._preferences["sound"], "The actual Sound setting button updates profile, audio, and HUD preferences")
	game.hud._setting_buttons["sound"].pressed.emit()
	_check(game.profile.data["settings"]["sound"] and game.hud._preferences["sound"] and game.sounds.enabled == (DisplayServer.get_name() != "headless"), "Sound can be enabled again while headless validation remains silent")
	var normal_stick_size: Vector2 = game.hud._stick.size
	var normal_ability_size: Vector2 = game.hud._ability_button.size
	game.hud._setting_buttons["large_controls"].pressed.emit()
	_check(game.profile.data["settings"]["large_controls"] and game.hud._stick.size.x > normal_stick_size.x and game.hud._ability_button.size.x > normal_ability_size.x, "The Larger Controls setting changes actual movement and Volley geometry")
	game.hud._setting_buttons["reduced_motion"].pressed.emit()
	_check(game.reduced_motion() and game.hud._preferences["reduced_motion"], "The Reduced Motion setting reaches both simulation and HUD")
	game.return_to_menu()


func _test_tutorial_and_motion() -> void:
	game.hud._toast_remaining = 0.0
	game._update_hud()
	game.hud._process(0.0)
	_check(game.hud._hint_text.contains("Drag the stick") and game.hud._hint_panel.visible, "A new player receives movement guidance when the startup toast clears")
	game.hud.setting_changed.emit("tutorial_hints", false)
	game._update_hud()
	_check(not game.profile.data["settings"]["tutorial_hints"] and game.hud._hint_text.is_empty() and not game.hud._hint_panel.visible, "Disabling tutorials removes the current hint through the real root signal")
	game.hud.setting_changed.emit("tutorial_hints", true)
	game._update_hud()
	_check(game.hud._hint_text.contains("Drag the stick"), "Tutorial hints can be restored during a first defense")
	var previous: Vector3 = game.hero.position
	game.hero.move_input = Vector2.LEFT
	game.hero._physics_process(0.1)
	_check(game.hero.position.distance_to(previous) > 0.5 and is_zero_approx(game.hero._model.position.y) and is_zero_approx(game.hero._model.rotation.z), "Reduced motion keeps real movement responsive while removing hero bob and lean")
	game.hero.move_input = Vector2.ZERO
	game.drop_coin(Vector3(7, 0, -20), 11)
	var coin: Node3D = game._coins.get_child(0)
	coin.set_physics_process(false)
	coin._physics_process(0.2)
	_check(is_equal_approx(coin._model.position.y, 0.34) and is_zero_approx(coin._model.rotation.y), "Reduced motion removes coin bounce and spin")
	var before: int = game.coins
	coin.position = game.hero.position
	coin._physics_process(0.1)
	_check(game.coins == before + 11 and game.coins_collected == 11, "Reduced motion keeps physical gold collection and reward accounting intact")
	game.show_hit(game.hero.position, true)
	_check(game.feedback.hits.is_empty() and not game.feedback.pickups.is_empty(), "Reduced motion suppresses impact bursts while retaining gold feedback")
	game.coins = 200
	game.hero.position = game._plot_by_id("crossing")["position"]
	_check(game.build_at("crossing", "tower") and game.buildings["crossing"].model.scale == Vector3.ONE, "Reduced-motion construction produces the full-sized tower immediately")
	game.buildings["crossing"].set_physics_process(false)
	game.hero.add_xp(16)
	game.hero._physics_process(0.1)
	_check(game.hero._level_ring.visible and game.hero._level_ring.scale == Vector3.ONE, "Reduced motion keeps a static level-up cue without ring expansion")


func _prepare_dirty_run() -> void:
	game.coins = 2000
	game.hero.position = game._plot_by_id("forge")["position"]
	_check(game.build_at("forge", "smith"), "The transition fixture contains a real purchased Smith")
	game.buy_smith_upgrade("ranged")
	game.buy_smith_upgrade("haste")
	game.buy_smith_upgrade("fortify")
	game.hero.add_xp(49)
	game.hero.ability_cooldown = 8.0
	game.kills = 7
	game.coins_collected = 80
	var enemy: Node3D = game.spawn_enemy("goblin")
	game.spawn_arrow(game.hero.position + Vector3.UP, enemy, 12.0, "hero")
	game.drop_coin(game.hero.position + Vector3(4, 0, 0), 10)
	game.feedback.pickup(game.hero.position, 9)
	_freeze()


func _test_custom_keep_fortification() -> void:
	game.coins = 1000
	game.hero.position = game._plot_by_id("workshop")["position"]
	_check(game.build_at("workshop", "smith"), "Amberfield supports an actual Smith purchase")
	game.damage_keep(50.0)
	game.buy_smith_upgrade("fortify")
	var expected_max: float = 620.0 * (1.0 + float(Data.SMITH["fortify"]["step"]))
	_check(is_equal_approx(game.keep_max, expected_max) and is_equal_approx(game.keep_health, expected_max - 50.0), "Fortification scales the level-specific Keep base and preserves prior damage")
	_freeze()


func _test_moonfen_mines() -> void:
	_check(game.building_limit("mine") == 2 and game.building_limit("smith") == 1, "Moonfen enables its two-mine override and keeps the one-Smith limit")
	game.coins = 600
	game.hero.position = game._plot_by_id("reed_mine")["position"]
	_check(game.build_at("reed_mine", "mine"), "Moonfen permits the first mine purchase")
	game.hero.position = game._plot_by_id("south_mine")["position"]
	game._update_selection()
	_check(_option_enabled(game._context(), "mine"), "The next support plot still offers a second mine after the first is built")
	_check(game.build_at("south_mine", "mine") and game.building_count("mine") == 2, "Moonfen's second mine is an actual distinct purchased building")
	game.hero.position = game._plot_by_id("moon_workshop")["position"]
	game._update_selection()
	var context: Dictionary = game._context()
	var before: int = game.coins
	_check(not _option_enabled(context, "mine") and _option_enabled(context, "smith"), "At the mine cap, the remaining support plot disables Mine but still offers Smith")
	_check(not game.build_at("moon_workshop", "mine") and game.coins == before, "A third mine is rejected without charging gold")
	_check(game.build_at("moon_workshop", "smith") and game.building_count("smith") == 1, "The remaining support plot can still buy a Smith")
	_freeze()


func _test_campaign_completion() -> void:
	var first_result: Dictionary = game.profile.data["results"]["briarwood"].duplicate(true)
	game.profile.data["results"].erase("briarwood")
	for index: int in range(6):
		game.profile.record_victory("unknown_saved_mission_%d" % index, 3, 25.0)
	_check(not game.campaign_complete(), "Extra unknown saved mission IDs cannot stand in for a missing authored mission")
	_win(1.0, 170.0)
	_check(game.state == "won" and game.profile.data["results"].has("emberfall") and not game.campaign_complete(), "Winning the last mission alone does not complete a campaign with an earlier missing result")
	_check(_has_label("Keep defended") and not _has_label("Campaign defended"), "The final result screen does not falsely claim full campaign completion")
	game.next_mission()
	_check(game.state == "campaign" and game.mission_index == 5, "Next after the last mission returns to the campaign instead of indexing past it")
	game.profile.record_victory("briarwood", int(first_result["stars"]), float(first_result["best_time"]))
	_check(game.campaign_complete(), "Completion requires a victory for every authored mission ID")
	_check(game.start_mission("emberfall"), "The last completed mission remains replayable")
	_freeze()
	_win(1.0, 180.0)
	_check(_has_label("Campaign defended"), "A verified complete campaign receives its completion result screen")
	game.return_to_menu()
	game.hud.play_requested.emit()
	_check(game.state == "campaign", "Title play opens mission selection once every defense is complete")
	var all_rows_won: bool = true
	for row: Dictionary in game.campaign_rows():
		all_rows_won = all_rows_won and bool(row["unlocked"]) and int(row["stars"]) >= 1
	_check(all_rows_won, "Completed campaign rows stay unlocked and display each saved medal")


func _win(health_ratio: float, seconds: float) -> void:
	game.keep_health = game.keep_max * health_ratio
	game.elapsed = seconds
	game.wave_index = game.wave_configs.size() - 1
	game._finish_run(true)


func _freeze() -> void:
	game.set_physics_process(false)
	game.hud.set_process(false)
	game.feedback.set_process(false)
	for container: Node3D in [game._actors, game._projectiles, game._coins]:
		for actor: Node in container.get_children():
			actor.set_physics_process(false)
	for building: Node3D in game.buildings.values():
		building.set_physics_process(false)


func _option_enabled(context: Dictionary, id: String) -> bool:
	for option: Dictionary in context.get("options", []):
		if option["id"] == id:
			return bool(option["enabled"])
	return false


func _has_label(text: String) -> bool:
	for label: Node in game.hud._overlay_card.find_children("*", "Label", true, false):
		if label.text == text:
			return true
	return false


func _check(passed: bool, message: String) -> void:
	checks += 1
	if not passed:
		failures += 1
		push_error("FAIL: " + message)
