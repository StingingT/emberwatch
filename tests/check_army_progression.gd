extends SceneTree
## Targeted unit + real composition-root checks. Uses memory-only stores.
const Rules = preload("res://game/army_data.gd")
const Store = preload("res://game/army_progression.gd")
const Game = preload("res://game/army_game.gd")
var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)

func _run() -> void:
	var army: RefCounted = Store.new()
	army.save_path = ""
	_check(Store.validate(army.data)["ok"], "fresh army schema validates")
	_check(Rules.ad_bonus(180) == 90 and Rules.ad_bonus(181) == 90, "50 percent bonus and odd-number rounding")
	_check(not army.purchase("hero_damage", 0), "insufficient Supplies do not purchase")
	var reward: Dictionary = army.record_progress("run-1", "briarwood", 0, 1)
	_check(int(army.data["supplies"]) == 12 and int(reward["normal"]) == 12, "completed wave banks Supplies")
	army.record_progress("run-1", "briarwood", 0, 1)
	_check(int(army.data["supplies"]) == 12, "replayed checkpoint cannot pay a wave twice")
	_check(army.claim_ad_bonus("run-1") == 0, "no ad bonus during active battle")
	reward = army.record_progress("run-1", "briarwood", 0, 6, "victory", 3, 180)
	var normal: int = int(reward["normal"])
	_check(normal == 176 and int(army.data["supplies"]) == 176, "victory includes waves, stars and one first-clear reward")
	army.record_progress("run-1", "briarwood", 0, 6, "victory", 3, 180)
	_check(int(army.data["supplies"]) == normal, "terminal callback is idempotent")
	_check(army.claim_ad_bonus("run-1") == 88, "bonus applies to entire normal reward")
	_check(army.claim_ad_bonus("run-1") == 0 and int(army.data["supplies"]) == 264, "duplicate ad completion cannot duplicate rewards")
	var replay: Dictionary = army.record_progress("run-2", "briarwood", 0, 6, "victory", 3, 170)
	_check(int(replay["normal"]) == 136, "victory replay pays normal Supplies but not first-clear bonus")
	var before: int = int(army.data["supplies"])
	army.record_progress("loss-1", "briarwood", 0, 2, "loss")
	_check(int(army.data["supplies"]) == before + 24, "defeat retains completed-wave rewards")
	_check(army.purchase("hero_health", 0), "rank one is available without a star gate")
	_check(not army.purchase("hero_health", 0), "next training rank has an explicit star gate")
	_check(army.purchase("hero_health", 3), "earned stars open the next rank without being spent")
	var results: Dictionary = {"briarwood": {"stars": 3, "best_time": 180.0}}
	_check(army.collect_achievements(results) == 50, "first victory and three-star achievements grant separately")
	_check(army.collect_achievements(results) == 0, "achievement grants are one-time")
	_check(Rules.stars(results) == 3, "stars remain a best-result total")
	var round_trip: Dictionary = JSON.parse_string(JSON.stringify(army.data))
	_check(Store.validate(round_trip)["ok"], "profile round-trip accepts JSON numeric representation")
	var invalid: Dictionary = army.data.duplicate(true)
	invalid["ranks"]["unknown"] = 1
	_check(not Store.validate(invalid)["ok"], "unknown training rejected")
	invalid = army.data.duplicate(true)
	invalid["version"] = 99
	_check(not Store.validate(invalid)["ok"], "future schema rejected rather than overwritten")
	_check(not Rules.valid_ranks({"hero_damage": true}) and not Rules.valid_ranks({"hero_damage": 1.5}), "boolean and fractional ranks rejected")
	army.read_only = true
	before = int(army.data["supplies"])
	_check(not army.purchase("hero_damage", 18) and int(army.data["supplies"]) == before, "read-only profile preserves wallet")
	var game: Node3D = Game.new()
	game.persistent_profile = false
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.army.data["ranks"] = {"hero_damage": 1, "hero_health": 2, "fortifications": 2, "mine_output": 1}
	game.start_run()
	game.hero.set_physics_process(false)
	_check(is_equal_approx(game.hero.health, 120.0), "run-start hero health includes permanent training")
	_check(is_equal_approx(game.keep_health, 540.0), "fresh Keep starts full with fortification training")
	_check(game.mine_yield(10) == 11, "mine output uses frozen training")
	var saved: Dictionary = game.capture_run_snapshot()
	_check(game.validate_run_snapshot(saved)["ok"], "trained battle snapshot validates")
	var damaged: Dictionary = saved.duplicate(true)
	damaged["hero"]["health"] = 121.0
	_check(not game.validate_run_snapshot(damaged)["ok"], "trained health above its maximum is rejected")
	game.army.data["ranks"]["hero_health"] = 5
	_check(game.restore_run_snapshot(saved), "trained battle can be restored")
	_check(is_equal_approx(game.hero.health, 120.0), "later training purchases do not change a saved battle")
	game.resume_run()
	game.wave_timer = 5.0
	var time_before: float = game.elapsed
	game.start_next_wave_now()
	_check(game.wave_timer == 0 and game.elapsed == time_before and game.kills == 0, "start-now skips only waiting, not simulation or enemies")
	game.toggle_battle_speed()
	game._process(0.0)
	_check(Engine.time_scale == 2 and Engine.physics_ticks_per_second == game._normal_physics_ticks * 2, "2x accelerates simulation with matching tick resolution")
	game.pause_run()
	game._process(0.0)
	_check(Engine.time_scale == 1, "pause/menu time returns to normal")
	game.show_army("army")
	_check(game.state == "paused", "training cannot be bought from live or paused combat")
	game.return_to_menu()
	game.show_army("army")
	_check(game.hud._overlay_mode == "army_upgrades", "upgrades are reachable from the real composition root")
	for child: Node in game.hud._overlay_card.get_children():
		if child is Button:
			_check(child.position.x + child.size.x <= 596.01 and child.position.y + child.size.y <= 920.01, "upgrade button stays inside card")
	game.start_run()
	game.hero.set_physics_process(false)
	game.coins = 1000
	game.hero.position = game._plot_by_id("bend")["position"]
	_check(game.build_at("bend", "tower"), "tower builds through existing purchase flow")
	var tower: Node3D = game.buildings["bend"]
	tower.set_physics_process(false)
	for tier: int in range(1, 4):
		_check(tower.model.get_node("Crew").get_child_count() == tier, "tower tier %d has the correct archer count" % tier)
		if tier < 3:
			game.upgrade_at("bend")
	game.queue_free()
	await process_frame
	_check(Engine.time_scale == 1, "freeing the game restores global clock")
	if failures.is_empty():
		print("ARMY_PROGRESSION_OK: %d checks" % checks)
	else:
		print("ARMY_PROGRESSION_FAILED: %d / %d" % [failures.size(), checks])
	quit(0 if failures.is_empty() else 1)
