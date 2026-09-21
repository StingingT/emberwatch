extends SceneTree
## Updated v2 contract: hero danger comes from ranged shots, never melee pursuit.
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
	# Manual actor steps only; captures must not advance other actors or waves.
	game.process_mode = Node.PROCESS_MODE_DISABLED
	game.wave_index = 0
	game.wave_active = true
	game.wave_cursor = 1
	var hunter: Node3D = game.spawn_enemy("hunter")
	hunter.position = Vector3(-3, 0, -6)
	hunter.route_index = 4
	game.hero.position = Vector3(-6, 0, -5)
	var before_position: Vector3 = hunter.position
	hunter._physics_process(0.1)
	_check(hunter.position.z > before_position.z and is_equal_approx(hunter.position.x, before_position.x), "Former hunter follows its route instead of pursuing the hero")
	_check(hunter.hero_windup == 0 and game.hero.health == 100, "Non-ranged runner cannot wind up or damage the hero")
	game.hero.health = 0
	before_position = hunter.position
	hunter._physics_process(0.1)
	_check(hunter.position.z > before_position.z, "Runner keeps moving when the hero is down")
	game.hero.health = 100
	await _capture(game, "route_runner_encounter")
	game.enemies.erase(hunter)
	game._actors.remove_child(hunter)
	hunter.queue_free()
	game.hero.position = Vector3(-3, 0, -3)
	var enemy: Node3D = game.spawn_enemy("ranger")
	enemy.position = game.hero.position + Vector3(0, 0, -6)
	enemy._physics_process(0.01)
	_check(game.hero.health == 100 and enemy.hero_windup > 0, "Ranged attack announces itself before damage")
	await _capture(game, "hero_attack_warning")
	enemy._physics_process(0.7)
	_check(game._projectiles.get_child_count() == 1 and game.hero.health == 100, "Release launches a bolt without instant damage")
	var bolt: Node3D = game._projectiles.get_child(0)
	game.hero.position.x += 3
	bolt._physics_process(1.0)
	_check(game.hero.health == 100, "Moving after release dodges the fixed-destination bolt")
	game._projectiles.remove_child(bolt)
	bolt.queue_free()
	enemy._attack_remaining = 0.0
	enemy._physics_process(0.01)
	enemy._physics_process(0.7)
	bolt = game._projectiles.get_child(0)
	bolt._physics_process(1.0)
	_check(game.hero.health == 89, "A stationary hero takes one configured ranged hit")
	game._projectiles.remove_child(bolt)
	bolt.queue_free()
	game.pause_run()
	enemy._physics_process(5)
	_check(game.hero.health == 89, "Pause prevents enemy attack damage")
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
