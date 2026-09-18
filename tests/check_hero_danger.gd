extends SceneTree
const Game = preload("res://game/game.gd")
var failures: int = 0
var checks: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)

func _run() -> void:
	var game: Node3D = Game.new()
	game.persistent_profile = false
	root.add_child(game)
	game.start_run()
	game.set_physics_process(false)
	game.hero.set_physics_process(false)
	game.wave_index = 0
	game.wave_active = true
	game.wave_cursor = 1
	var hunter: Node3D = game.spawn_enemy("hunter")
	hunter.set_physics_process(false)
	hunter.position = Vector3(-3, 0, -6)
	hunter.route_index = 4
	game.hero.position = Vector3(-6, 0, -5)
	var distance_before: float = hunter.position.distance_to(game.hero.position)
	_check(hunter._hunt_hero(0.1) and hunter.position.distance_to(game.hero.position) < distance_before, "Hunter pursues nearby hero off the route")
	game.hero.position = Vector3(-9, 0, -5)
	_check(not hunter._hunt_hero(0.1), "Hunter refuses pursuit beyond the route leash")
	game.hero.health = 0
	_check(not hunter._hunt_hero(0.1), "Hunter abandons a dead hero")
	game.hero.health = 100
	await _capture(game, "hunter_encounter")
	game.enemies.erase(hunter)
	hunter.queue_free()
	game.hero.position = Vector3(-3, 0, -3)
	var enemy: Node3D = game.spawn_enemy("goblin")
	enemy.set_physics_process(false)
	enemy.position = game.hero.position + Vector3(0, 0, -1)
	enemy._physics_process(0.01)
	_check(game.hero.health == 100 and enemy.hero_windup > 0, "Attack announces itself before damage")
	await _capture(game, "hero_attack_warning")
	game.hero.position.x += 3
	enemy._physics_process(0.7)
	_check(game.hero.health == 100, "Leaving the marked area dodges damage")
	enemy.position = game.hero.position + Vector3(0, 0, -1)
	enemy._physics_process(1.3)
	enemy._physics_process(0.7)
	_check(game.hero.health == 91, "Remaining inside the strike takes one configured hit")
	game.pause_run()
	enemy._physics_process(5)
	_check(game.hero.health == 91, "Pause prevents enemy attack damage")
	game.resume_run()
	game.hero.take_damage(1000)
	_check(not game.hero.is_alive() and game.is_playing(), "Hero death leaves the defense running")
	await _capture(game, "hero_down")
	var before: int = game.coins
	game.hero.position = game._plot_by_id("bend")["position"] + Vector3(0, 0, 2)
	_check(not game.build_at("bend", "tower") and game.coins == before, "Downed hero cannot construct or spend")
	_check(not game.hero.use_ability(), "Downed hero cannot use Volley")
	game.drop_coin(game.hero.position, 10)
	game._coins.get_child(0)._physics_process(1.0)
	_check(game.coins == before, "Downed hero cannot collect nearby gold")
	game.hero.add_xp(0.4)
	var saved: Dictionary = game.capture_run_snapshot()
	_check(game.validate_run_snapshot(saved)["ok"], "Checkpoint accepts valid downed combat state")
	_check(game.restore_run_snapshot(saved) and not game.hero.is_alive() and is_equal_approx(game.hero.xp, 0.4), "Restoration preserves fractional XP, death and remaining respawn time")
	game.hero.set_physics_process(false)
	game.hero._physics_process(20)
	_check(not game.hero.is_alive(), "Paused restoration cannot advance respawn")
	game.resume_run()
	game.hero._physics_process(8)
	_check(game.hero.is_alive() and game.hero.health == 100 and not game._position_blocked(game.hero.position), "Respawn restores health at a clear friendly location")
	game.hero.take_damage(20)
	_check(game.hero.health == 100, "Respawn protection blocks immediate damage")
	game.hero._physics_process(1.5)
	game.hero.take_damage(20)
	_check(game.hero.health == 80, "Respawn protection expires and danger returns")
	game.queue_free()
	await process_frame
	await process_frame
	if failures == 0:
		print("HERO_DANGER_PASS: ", checks)
	quit(1 if failures else 0)

func _capture(game: Node3D, label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	game._update_selection()
	game._update_hud()
	await process_frame
	await RenderingServer.frame_post_draw
	var error: Error = root.get_texture().get_image().save_png("res://artifacts/" + label + ".png")
	_check(error == OK, "Capture " + label)
