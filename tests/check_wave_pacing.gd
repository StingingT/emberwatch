extends SceneTree
## Scheduler regression, not a combat/balance playtest. Runs the production scene.
## Enemies are removed through real damage while the hero's firing is disabled.
## Neither automatic-playthrough case clicks Start Now or calls _advance_waves.
const Main = preload("res://game/main.tscn")
const Data = preload("res://game/game_data.gd")
var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)

func _new_game() -> Node3D:
	var game: Node3D = Main.instantiate()
	game.persistent_profile = false
	root.add_child(game)
	await process_frame
	game.start_run()
	# This suite isolates scheduling from XP choice overlays and combat balance.
	game.hero.set_physics_process(false)
	return game

func _dispose(game: Node3D) -> void:
	game.queue_free()
	await process_frame

func _wait_for_first_wave(game: Node3D) -> void:
	# Frame limit makes a manual-only wave scheduler fail instead of hanging.
	for frame: int in range(ceili((Data.PREPARATION_TIME + 2.0) * 120.0)):
		await physics_frame
		if game.wave_active or not game.is_playing():
			return

func _automatic_mission(speed: int) -> void:
	var game: Node3D = await _new_game()
	game.battle_speed = speed
	game._process(0.0)
	var started: Array[int] = []
	var expected_kills: int = 0
	var expected_seconds: float = Data.PREPARATION_TIME + 30.0
	for wave: Dictionary in game.wave_configs:
		expected_kills += wave["enemies"].size()
		expected_seconds += float(wave["interval"]) * wave["enemies"].size() + Data.BETWEEN_WAVES
	# Keep the actual authored waves and engine-driven physics countdowns intact.
	for frame: int in range(ceili(expected_seconds * 120.0)):
		await physics_frame
		if not game.is_playing():
			break
		if game.wave_active and not started.has(game.wave_index):
			_check(game.wave_index == started.size(), "%dx starts waves in order without a button" % speed)
			started.append(game.wave_index)
		for enemy: Node3D in game.enemies.duplicate():
			if is_instance_valid(enemy) and not enemy.dead:
				enemy.take_damage(enemy.health, "tower")
	_check(game.state == "won", "%dx reaches victory with no Start Now clicks (state=%s, wave=%d, timer=%s)" % [speed, game.state, game.wave_index, game.wave_timer])
	_check(started.size() == game.wave_configs.size(), "%dx automatically starts every authored wave" % speed)
	_check(game.kills == expected_kills, "%dx neither skips nor duplicates enemies" % speed)
	game.army_menu.update_wave_button()
	_check(not game.army_menu._wave_wait_panel.visible, "terminal results hide the wave shortcut")
	var supplies: int = int(game.army.data["supplies"])
	var index: int = game.wave_index
	game.start_next_wave_now()
	_check(game.wave_index == index and int(game.army.data["supplies"]) == supplies, "Start Now after victory cannot grant another wave or reward")
	await _dispose(game)

func _shortcut_and_view() -> void:
	var game: Node3D = await _new_game()
	game.army_menu.update_wave_button()
	var menu: RefCounted = game.army_menu
	_check(menu._wave_wait_panel.visible and menu._wave_countdown.visible, "preparation shows a passive automatic countdown")
	_check(menu._wave_countdown.text.begins_with("Auto in "), "countdown states that no click is required")
	_check(menu._wave_countdown.mouse_filter == Control.MOUSE_FILTER_IGNORE, "countdown text is not an action")
	_check(menu._wave_wait_panel.mouse_filter == Control.MOUSE_FILTER_IGNORE, "passive countdown panel does not take input")
	_check(menu._wave_button.text == "Start now", "button is an early-start shortcut")
	var original_size: Vector2 = game.hud._wave_panel.size
	for width: float in [250.0, 284.0, 386.0]:
		game.hud._wave_panel.size = Vector2(width, 75)
		menu.update_wave_button()
		var label_rect: Rect2 = menu._wave_countdown.get_rect()
		var button_rect: Rect2 = menu._wave_button.get_rect()
		_check(not label_rect.intersects(button_rect), "countdown and shortcut do not overlap at width %s" % width)
		_check(button_rect.end.x <= width and button_rect.end.y <= 75, "shortcut stays in the wave panel at width %s" % width)
	game.hud._wave_panel.size = original_size
	menu.update_wave_button()
	var timer: float = game.wave_timer
	for refresh: int in range(20):
		menu.update_wave_button()
	_check(game.wave_timer == timer, "UI refresh never resets or advances the automatic timer")
	var elapsed: float = game.elapsed
	var coins: int = game.coins
	var supplies: int = int(game.army.data["supplies"])
	game.hero.ability_cooldown = 4.0
	# Exercise the actual connected UI action, including a same-frame double tap.
	menu._wave_button.pressed.emit()
	menu._wave_button.pressed.emit()
	_check(game.wave_timer == 0.0 and game.elapsed == elapsed, "shortcut removes only the remaining wait")
	_check(game.coins == coins and int(game.army.data["supplies"]) == supplies and game.kills == 0, "shortcut grants no gold, Supplies or kills")
	_check(game.hero.ability_cooldown == 4.0, "skipped time does not refill the hero ability")
	await _wait_for_first_wave(game)
	_check(game.wave_active and game.wave_index == 0, "early start opens exactly the first wave")
	menu.update_wave_button()
	_check(not menu._wave_wait_panel.visible, "active combat hides the shortcut")
	_check(menu._waiting_wave_index == -2, "expired countdown invalidates its touch identity")
	timer = game.wave_timer
	game.start_next_wave_now()
	_check(game.wave_index == 0 and game.wave_timer == timer, "stale action cannot skip an active wave")
	await _dispose(game)

func _pause_resume_and_recovery() -> void:
	var game: Node3D = await _new_game()
	for frame: int in range(45):
		await physics_frame
	var saved: Dictionary = game.capture_run_snapshot()
	_check(game.validate_run_snapshot(saved)["ok"], "partially elapsed preparation can be saved")
	game.pause_run()
	game.army_menu.update_wave_button()
	var remaining: float = game.wave_timer
	game.start_next_wave_now()
	for frame: int in range(30):
		await physics_frame
	_check(game.wave_timer == remaining and not game.wave_active, "explicit pause freezes countdown and rejects early-start actions")
	_check(not game.army_menu._wave_wait_panel.visible, "paused game hides and releases the shortcut")
	_check(game.restore_run_snapshot(saved), "saved countdown restores through production recovery")
	_check(game.state == "paused" and is_equal_approx(game.wave_timer, float(saved["wave_timer"])), "restore preserves remaining wait rather than starting a new wait")
	game.hero.set_physics_process(false)
	game.resume_run()
	await _wait_for_first_wave(game)
	_check(game.wave_active and game.wave_index == 0, "resuming a saved countdown needs no Next Wave click")
	await _dispose(game)

func _hero_death_does_not_hold_waves() -> void:
	var game: Node3D = await _new_game()
	game.hero.take_damage(10000.0)
	_check(not game.hero.is_alive(), "hero-death scheduling fixture is active")
	await _wait_for_first_wave(game)
	_check(game.wave_active and game.wave_index == 0 and not game.hero.is_alive(), "automatic waves are not gated on hero survival")
	await _dispose(game)

func _run() -> void:
	await _shortcut_and_view()
	await _pause_resume_and_recovery()
	await _hero_death_does_not_hold_waves()
	await _automatic_mission(1)
	await _automatic_mission(2)
	_check(Engine.time_scale == 1.0, "disposing the game resets simulation speed")
	if failures.is_empty():
		print("WAVE_PACING_OK: %d checks" % checks)
	else:
		print("WAVE_PACING_FAILED: %d / %d" % [failures.size(), checks])
	quit(0 if failures.is_empty() else 1)
