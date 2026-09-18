extends "res://tests/check_hero_danger.gd"

func _run() -> void:
	var game: Node3D = Game.new()
	game.persistent_profile = false
	root.add_child(game)
	game.start_run()
	game.set_physics_process(false)
	game.hero.set_physics_process(false)
	game.hero.position = Vector3(-3, 0, -3)
	game.wave_index = 0
	game.wave_cursor = 4
	game.wave_active = true
	for z: float in [-5.0, -7.0, -9.0, -11.0]:
		var enemy: Node3D = game.spawn_enemy("goblin")
		enemy.set_physics_process(false)
		enemy.position = Vector3(-3, 0, z)
	game.fire_piercing_arrow(Vector3(-3, 1, -3), Vector3.FORWARD, 6.0)
	var arrow: Node3D = game._projectiles.get_child(0)
	arrow.set_physics_process(false)
	arrow._physics_process(0.08)
	_check(game.enemies[0].health == 24 and game.enemies[1].health == 30, "Piercing hits the first enemy before those behind it")
	arrow._physics_process(0.001)
	_check(game.enemies[0].health == 24, "An overlapping enemy takes damage only once")
	_check(is_equal_approx(game.hero.xp, 0.8), "Piercing damage earns proportional hero XP")
	await _capture(game, "piercing_arrow")
	var saved: Dictionary = game.capture_run_snapshot()
	_check(game.validate_run_snapshot(saved)["ok"], "Piercing trajectory and hit history validate")
	_check(game.restore_run_snapshot(saved), "Piercing trajectory restores")
	game.set_physics_process(false)
	game.hero.set_physics_process(false)
	for enemy: Node3D in game.enemies:
		enemy.set_physics_process(false)
	arrow = game._projectiles.get_child(0)
	arrow.set_physics_process(false)
	arrow._physics_process(0.2)
	_check(game.enemies[1].health == 30, "Paused piercing arrow cannot hit")
	game.resume_run()
	arrow._physics_process(0.001)
	_check(game.enemies[0].health == 24, "Restoration retains already-hit exclusion")
	arrow._physics_process(0.4)
	_check(game.enemies[1].health == 24 and game.enemies[2].health == 24, "One fast step pierces successive enemies")
	_check(game.enemies[3].health == 30 and arrow.finished, "Piercing stops at its three-target budget")
	_check(is_equal_approx(game.hero.xp, 2.4), "Piercing XP counts actual damage exactly once per enemy")
	game.queue_free()
	await process_frame
	await process_frame
	if failures == 0:
		print("PIERCING_ARROW_PASS: ", checks)
	quit(1 if failures else 0)
