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
	game.wave_active = true
	game.wave_cursor = 1
	var ranger: Node3D = game.spawn_enemy("ranger")
	ranger.set_physics_process(false)
	ranger.position = Vector3(-3, 0, -8)
	ranger._physics_process(0.01)
	_check(ranger.hero_windup > 0 and game._projectiles.get_child_count() == 0, "Ranger winds up before firing")
	game.hero.position.x += 1
	ranger._physics_process(0.7)
	_check(game._projectiles.get_child_count() == 1 and game.hero.health == 100, "Release creates a visible bolt without instant damage")
	var bolt: Node3D = game._projectiles.get_child(0)
	bolt.set_physics_process(false)
	_check(bolt.destination.is_equal_approx(game.hero.position + Vector3(0, 0.85, 0)), "Aim uses hero position at release")
	bolt._physics_process(0.15)
	await _capture(game, "ranger_bolt")
	game.hero.position.x += 3
	bolt._physics_process(1.0)
	_check(game.hero.health == 100 and bolt.impacted, "Moving after release dodges a non-homing bolt")
	await process_frame
	game.hero.position = Vector3(-3, 0, -3)
	ranger._attack_remaining = 0
	ranger._physics_process(0.01)
	ranger._physics_process(0.7)
	bolt = game._projectiles.get_child(0)
	bolt.set_physics_process(false)
	ranger.take_damage(1000, "tower")
	await process_frame
	_check(is_instance_valid(bolt) and not bolt.impacted, "Launched bolt survives shooter death")
	var saved: Dictionary = game.capture_run_snapshot()
	_check(game.validate_run_snapshot(saved)["ok"], "In-flight hostile bolt has a valid snapshot")
	_check(game.restore_run_snapshot(saved), "In-flight bolt restores")
	game.set_physics_process(false)
	game.hero.set_physics_process(false)
	bolt = game._projectiles.get_child(0)
	bolt.set_physics_process(false)
	var before: Vector3 = bolt.position
	bolt._physics_process(1.0)
	_check(bolt.position == before and game.hero.health == 100, "Paused bolt neither moves nor damages")
	game.resume_run()
	bolt._physics_process(1.0)
	_check(game.hero.health == 89, "Swept bolt hits a stationary hero once")
	bolt._physics_process(1.0)
	_check(game.hero.health == 89, "Impacted bolt cannot hit twice")
	game.queue_free()
	await process_frame
	await process_frame
	if failures == 0:
		print("RANGED_ENEMY_PASS: ", checks)
	quit(1 if failures else 0)
