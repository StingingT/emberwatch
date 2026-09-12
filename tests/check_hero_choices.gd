extends "res://tests/check_hero_danger.gd"

func _run() -> void:
	var game: Node3D = Game.new()
	game.persistent_profile = false
	root.add_child(game)
	game.start_run()
	game.set_physics_process(false)
	game.hero.set_physics_process(false)
	game.hero.add_xp(16)
	game.hero.move_input = Vector2.RIGHT
	game._physics_process(0.01)
	_check(game.state == "paused" and game.hud._overlay_mode == "hero_choice", "Level-up opens the paused choice panel")
	_check(game.hero.move_input == Vector2.ZERO, "Opening choices clears movement")
	game.resume_run()
	_check(game.state == "paused", "Resume cannot skip an earned choice")
	await _capture(game, "hero_choices")
	game.hud.hero_choice_requested.emit("invalid")
	_check(game.hero.pending_choices() == 1, "Unknown choices cannot spend the upgrade")
	game.hud.hero_choice_requested.emit("multishot")
	_check(game.is_playing() and game.hero.choices["multishot"] == 1, "Selecting Multishot spends one choice and resumes")
	game.hud.hero_choice_requested.emit("multishot")
	_check(game.hero.choices["multishot"] == 1, "A stale button cannot spend a second choice")
	game.hero.position = Vector3(-3, 0, -3)
	game.wave_index = 0
	game.wave_cursor = 4
	game.wave_active = true
	for x: float in [-3.0, -2.0, -1.0, 0.0]:
		var enemy: Node3D = game.spawn_enemy("goblin")
		enemy.set_physics_process(false)
		enemy.position = Vector3(x, 0, -7)
	game.hero._fire(game.enemies[0], 12)
	_check(game._projectiles.get_child_count() == 3, "Multishot launches a primary and two extra arrows")
	for arrow: Node in game._projectiles.get_children():
		arrow.set_physics_process(false)
	game.hero.add_xp(28)
	game.offer_hero_choice()
	game.choose_hero_upgrade("piercing")
	game.hero._fire(game.enemies[0], 12)
	var pierced: bool = false
	for arrow: Node in game._projectiles.get_children():
		arrow.set_physics_process(false)
		pierced = pierced or arrow.has_method("snapshot_hits")
	_check(pierced, "Piercing choice changes ordinary fire into a through-arrow")
	game.hero.add_xp(42)
	game.offer_hero_choice()
	game.choose_hero_upgrade("volley")
	_check(game.hero.choices == {"multishot": 1, "volley": 1, "piercing": 1}, "Subsequent choices can combine all three approaches")
	_check(game.hero.use_ability(), "Volley upgrade keeps the active burst usable")
	var burst: Node3D = game._projectiles.get_child(game._projectiles.get_child_count() - 1)
	_check(is_equal_approx(burst._damage, (44.0 + 9.0) * 1.2), "Volley choice increases burst damage")
	for arrow: Node in game._projectiles.get_children():
		arrow.set_physics_process(false)
	var saved: Dictionary = game.capture_run_snapshot()
	_check(game.validate_run_snapshot(saved)["ok"] and game.restore_run_snapshot(saved), "Mixed choices and projectiles restore together")
	_check(game.hero.choices == {"multishot": 1, "volley": 1, "piercing": 1}, "Restoration retains selected ranks")
	game.resume_run()
	game.hero.take_damage(1000)
	_check(game.hero.choices["piercing"] == 1, "Hero death preserves run choices")
	game.queue_free()
	await process_frame
	await process_frame
	if failures == 0:
		print("HERO_CHOICES_PASS: ", checks)
	quit(1 if failures else 0)
