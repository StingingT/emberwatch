extends SceneTree
const GameScript = preload("res://game/game.gd")
var game: Node3D
var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	game = GameScript.new()
	root.add_child(game)
	await process_frame
	game.start_run()
	game.set_physics_process(false)
	game.hero.set_physics_process(false)
	_check(game.state == "playing" and game.coins == 100, "fresh run starts with configured economy")
	game.hero.position = Vector3(-6, 0, -1.7)
	_check(not game.build_at("bend", "mine"), "invalid plot category rejected")
	_check(game.coins == 100, "invalid build spends no gold")
	_check(game.build_at("bend", "tower"), "nearby valid tower builds")
	_check(game.coins == 60 and game.building_count("tower") == 1, "construction spends exactly once")
	_check(not game.build_at("bend", "tower") and game.coins == 60, "occupied plot cannot charge twice")
	_check(not game.upgrade_at("bend"), "insufficient gold cannot upgrade")
	game.coins = 300
	_check(game.upgrade_at("bend") and game.buildings["bend"].tier == 2, "level 2 upgrade")
	_check(game.upgrade_at("bend") and game.buildings["bend"].tier == 3, "level 3 upgrade")
	var before: int = game.coins
	_check(not game.upgrade_at("bend") and game.coins == before, "level 3 cap preserves wallet")
	game.hero.position = Vector3(0, 0, 0)
	_check(not game.build_at("north", "tower"), "remote building blocked")
	game.coins = 2000
	game.hero.position = Vector3(-6, 0, 2.5)
	_check(game.build_at("quarry", "mine"), "Gold Mine builds on support plot")
	var mine: Node3D = game.buildings["quarry"]
	mine.set_physics_process(false)
	before = game.coins
	mine._physics_process(0.3)
	_check(game._coins.get_child_count() == 1 and game._coins.get_child(0).value == 10 and game.coins == before,
		"A newly built mine produces physical gold without crediting the wallet")
	mine._physics_process(6.0)
	_check(game._coins.get_child(0).value == 10, "Mine production waits for its configured interval")
	mine._physics_process(1.1)
	_check(game._coins.get_child(0).value == 20, "Mine produces a second physical reward after the interval")
	game.pause_run()
	mine._physics_process(8.0)
	_check(game._coins.get_child(0).value == 20, "Pause prevents mine production")
	game.resume_run()
	game.hero.position = Vector3(4.2, 0, -0.2)
	_check(not game.build_at("forge", "mine"), "one-mine limit enforced")
	_check(game.build_at("forge", "smith"), "Smith uses shared support category")
	game._update_selection()
	var view: Dictionary = game._context()
	_check(view["options"].size() == 3, "Smith offers exactly three choices")
	var old_damage: float = game.ranged_multiplier()
	before = game.coins
	var price: int = game.smith_cost("ranged")
	game.buy_smith_upgrade("ranged")
	_check(game.ranged_multiplier() > old_damage and game.coins == before - price, "Smith damage bonus charges and applies")
	game.buy_smith_upgrade("haste")
	_check(game.haste_multiplier() > 1.0, "Smith tower attack speed applies")
	game.buy_smith_upgrade("fortify")
	_check(is_equal_approx(game.keep_max, 540.0) and is_equal_approx(game.keep_health, 540.0), "fortify immediately grows Keep health")
	game.hero.position = Vector3(-3, 0, -5)
	_check(game.build_at("choke", "wall"), "wall builds on fixed route plot")
	_check(is_equal_approx(game.buildings["choke"].max_health, 204.0), "new walls inherit prior Smith fortification")
	var stopped: Vector3 = game.constrain_hero_motion(Vector3(-3, 0, -6.2), Vector3(-3, 0, -6.4))
	_check(stopped.z >= -6.25, "hero cannot walk through a built wall")
	game.buildings["choke"].take_damage(1000.0)
	_check(not game.buildings.has("choke") and game.plot_views["choke"].visible, "destroyed wall frees its plot")
	_check(game.build_at("choke", "wall"), "destroyed wall can be rebuilt")
	game.pause_run()
	before = game.coins
	_check(not game.upgrade_at("choke") and game.coins == before, "pause prevents spending")
	game.resume_run()
	_check(game.is_playing(), "resume restores play")
	# Exercise real wave scheduler with small controlled rosters, not full balance claims.
	game.wave_configs.assign([{"name": "Test A", "enemies": ["goblin"], "interval": 0.5, "health_scale": 1.0},
		{"name": "Test B", "enemies": ["scout"], "interval": 0.5, "health_scale": 1.0}])
	game.wave_timer = 0.0
	game._advance_waves(0.1)
	game._advance_waves(0.1)
	_check(game.enemies.size() == 1 and game.wave_index == 0, "wave scheduler spawns configured enemy")
	game.enemies[0].take_damage(1000, "hero")
	game._advance_waves(0.1)
	_check(not game.wave_active and game.state == "playing", "wave clear schedules next wave")
	game._advance_waves(6.0)
	game._advance_waves(0.1)
	_check(game.wave_index == 1 and game.enemies.size() == 1, "second wave progresses")
	game.enemies[0].take_damage(1000, "hero")
	game._advance_waves(0.1)
	_check(game.state == "won", "victory requires final wave cleared")
	game.start_run()
	game.set_physics_process(false)
	_check(game.coins == 100 and game.kills == 0 and game.buildings.is_empty() and game.hero.tier == 1,
		"restart clears economy, buildings, kills and hero progression")
	_check(game.smith_levels["ranged"] == 0 and game.keep_max == 450, "restart clears Smith modifiers")
	game.damage_keep(1000)
	_check(game.state == "lost", "Keep destruction ends run in defeat")
	# A mobile player can stand directly on a plot before tapping its build button.
	for entry: Array in [["crossing", "tower"], ["choke", "wall"], ["quarry", "mine"], ["forge", "smith"]]:
		game.start_run()
		game.set_physics_process(false)
		game.hero.set_physics_process(false)
		game.coins = 200
		var plot: Dictionary = game._plot_by_id(str(entry[0]))
		game.hero.position = plot["position"]
		_check(game.build_at(str(entry[0]), str(entry[1])), "construction works while standing on %s plot" % entry[1])
		_check(not game._position_blocked(game.hero.position), "%s construction leaves hero outside its footprint" % entry[1])
		var before_move: Vector3 = game.hero.position
		var escape: Vector3 = (before_move - Vector3(plot["position"])).normalized()
		if escape.is_zero_approx():
			escape = Vector3.FORWARD
		game.hero.move_input = Vector2(escape.x, escape.z)
		game.hero._physics_process(1.0 / 60.0)
		_check(game.hero.position.distance_to(before_move) > 0.09, "hero can move after %s construction" % entry[1])
	# All four structure types must support the configured upgrade sequence.
	for entry: Array in [["crossing", "tower"], ["choke", "wall"], ["quarry", "mine"], ["forge", "smith"]]:
		game.start_run()
		game.set_physics_process(false)
		game.hero.set_physics_process(false)
		game.coins = 1000
		var id: String = str(entry[0])
		var kind: String = str(entry[1])
		var spec: Dictionary = GameData.BUILDINGS[kind]
		game.hero.position = game._plot_by_id(id)["position"]
		_check(game.build_at(id, kind) and game.coins == 1000 - int(spec["costs"][0]), "%s construction uses its configured price" % kind)
		before = game.coins
		_check(game.upgrade_at(id) and game.buildings[id].tier == 2 and game.coins == before - int(spec["costs"][1]), "%s level two applies and charges correctly" % kind)
		before = game.coins
		_check(game.upgrade_at(id) and game.buildings[id].tier == 3 and game.coins == before - int(spec["costs"][2]), "%s level three applies and charges correctly" % kind)
		before = game.coins
		_check(not game.upgrade_at(id) and game.coins == before, "%s configured maximum prevents further charges" % kind)
	# An alternate cap is honored by the actor, purchase controller and view.
	game.start_run()
	game.hero.set_physics_process(false)
	game.coins = 500
	game.hero.position = game._plot_by_id("crossing")["position"]
	game.build_at("crossing", "tower")
	var capped: Node3D = game.buildings["crossing"]
	capped.stats = capped.stats.duplicate(true)
	capped.stats["max_level"] = 2
	_check(game.upgrade_at("crossing") and capped.tier == 2, "Custom tier cap permits its final configured upgrade")
	before = game.coins
	_check(not game.upgrade_at("crossing") and game.coins == before, "Purchase controller respects a custom cap without spending")
	capped.upgrade()
	_check(capped.tier == 2, "Building actor respects the same configured cap")
	game._update_selection()
	_check(game._context()["upgrade_cost"] == -1 and not game._context()["can_upgrade"], "Upgrade UI reflects the configured cap")
	await process_frame
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("ECONOMY_CHECKS_PASS ", checks)
		quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		quit(1)

func _check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures.append(description)
