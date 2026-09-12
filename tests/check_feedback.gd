extends SceneTree
## Real damage and physical pickups must drive feedback without changing rewards.
const GameScript = preload("res://game/game.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var game: Node3D = GameScript.new()
	game.persistent_profile = false
	root.add_child(game)
	game.start_run()
	game.set_physics_process(false)
	game.hero.set_physics_process(false)
	game.feedback.set_process(false)
	var feedback: Node2D = game.feedback
	var starting_gold: int = game.coins
	var enemy: Node3D = game.spawn_enemy("goblin")
	enemy.set_physics_process(false)
	enemy.take_damage(12.0, "hero")
	_check(feedback.hits.size() == 1 and not feedback.hits[0]["lethal"], "A real nonlethal hit creates impact feedback")
	enemy.take_damage(100.0, "hero")
	_check(feedback.hits.size() == 2 and feedback.hits[1]["lethal"], "A real finishing blow creates stronger feedback")
	_check(game.coins == starting_gold and feedback.pickups.is_empty(), "Kill feedback never credits uncollected gold")
	var coin: Node3D = game._coins.get_child(0)
	coin.set_physics_process(false)
	coin.position = game.hero.position
	coin._physics_process(1.0 / 60.0)
	_check(game.coins == starting_gold + 9 and feedback.pickups.size() == 1, "Physical pickup credits gold and shows its value")
	coin._physics_process(1.0 / 60.0)
	_check(game.coins == starting_gold + 9 and int(feedback.pickups[0]["amount"]) == 9, "Repeated pickup update cannot duplicate reward or feedback")
	game.drop_coin(game.hero.position + Vector3(2, 0, 0), 10)
	var second_coin: Node3D = game._coins.get_child(game._coins.get_child_count() - 1)
	second_coin.set_physics_process(false)
	second_coin.position = game.hero.position
	second_coin._physics_process(1.0 / 60.0)
	_check(feedback.pickups.size() == 1 and int(feedback.pickups[0]["amount"]) == 19, "Nearby simultaneous pickups combine into one accurate label")
	game.pause_run()
	feedback._process(1.0)
	_check(feedback.pickups.size() == 1 and not feedback.visible, "Pause hides feedback and preserves its lifetime")
	game.resume_run()
	feedback._process(1.0)
	_check(feedback.pickups.is_empty() and feedback.hits.is_empty() and feedback.visible, "Resuming expires old feedback normally")
	for index: int in range(100):
		feedback.hit(Vector3.ZERO, false)
		feedback.pickup(Vector3(index * 4, 0, 0), 1)
	_check(feedback.hits.size() == 32 and feedback.pickups.size() == 8, "Crowded combat has a bounded feedback budget")
	game.start_run()
	game.hero.set_physics_process(false)
	_check(feedback.hits.is_empty() and feedback.pickups.is_empty(), "Restart removes feedback from the previous run")
	game.hero.position = Vector3(3.2, 0, 1.4)
	_check(game.build_at("watch", "tower") and feedback.hits[-1].get("construction", false), "Real construction creates completion sparks")
	feedback._process(0.3)
	_check(not feedback.hits.is_empty(), "Construction ring lasts beyond the short impact flash")
	feedback._process(0.4)
	_check(feedback.hits.is_empty(), "Construction effect expires without lingering")
	game.change_setting("reduced_motion", true)
	feedback.construction(Vector3.ZERO)
	_check(feedback.hits.is_empty(), "Reduced motion suppresses construction sparks")
	game.change_setting("reduced_motion", false)
	# Progress includes enemies waiting to spawn, not just those already visible.
	game.wave_index = 0
	game.wave_active = true
	game.wave_cursor = 2
	var live_enemy: Node3D = game.spawn_enemy("goblin")
	live_enemy.set_physics_process(false)
	game._update_hud()
	var total: int = game.wave_configs[0]["enemies"].size()
	_check(int(game.hud._state["wave_remaining"]) == total - 1, "Wave progress includes unspawned and surviving enemies")
	live_enemy.take_damage(100.0, "tower")
	game._update_hud()
	_check(int(game.hud._state["wave_remaining"]) == total - 2, "Only a defeated enemy advances wave completion")
	game.return_to_menu()
	_check(feedback.hits.is_empty() and feedback.pickups.is_empty(), "Title clears transient combat feedback")
	game.queue_free()
	await process_frame
	await process_frame
	if failures == 0:
		print("FEEDBACK_CHECKS_PASS: %d checks" % checks)
		quit(0)
	else:
		quit(1)

func _check(passed: bool, message: String) -> void:
	checks += 1
	if not passed:
		failures += 1
		push_error("FAIL: " + message)
