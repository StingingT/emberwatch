extends SceneTree
## Run: godot --headless --path . --script res://tests/check_combat.gd
## Uses the real composition root and real actors; fixed steps isolate mechanics.

const GameScript := preload("res://game/game.gd")
const EnemyScript := preload("res://entities/enemy.gd")
const Data := preload("res://game/game_data.gd")

var _game: Node3D
var _failures: int = 0
var _checks: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	seed(41029)
	_game = GameScript.new()
	root.add_child(_game)
	_game.set_physics_process(false)
	_game.sounds.enabled = false
	_freeze_auto_ticks()
	await process_frame
	await _check_movement_and_pause()
	await _check_hero_arrows()
	await _check_damage_xp()
	await _check_tower_attribution()
	await _check_projectile_lifecycle()
	await _check_coin_collection()
	await _check_volley()
	await _check_keep_attack()
	await _check_wall_blocking()
	_game.queue_free()
	await process_frame
	await process_frame
	if _failures == 0:
		print("COMBAT CHECKS PASSED: %d checks" % _checks)
		quit(0)
	else:
		push_error("COMBAT CHECKS FAILED: %d / %d" % [_failures, _checks])
		quit(1)


func _fresh_run() -> void:
	_game.start_run()
	_game.set_physics_process(false)
	_game.sounds.enabled = false
	_freeze_auto_ticks()
	await process_frame


func _check_movement_and_pause() -> void:
	await _fresh_run()
	var hero: Node3D = _game.hero
	hero.position = Vector3(0, 0, -5)
	hero.move_input = Vector2.RIGHT
	await _step(0.5)
	check(absf(hero.position.x - float(Data.HERO["speed"]) * 0.5) < 0.03,
		"Hero input moves the real actor at configured speed")
	hero.position = Vector3(9.2, 0, -5)
	await _step(0.4)
	check(hero.position.x <= 9.301 and hero.position.x >= 9.29,
		"Hero movement stops at the battlefield edge")
	hero.position = Vector3(0, 0, -5)
	hero.move_input = Vector2(1, 1)
	await _step(0.5)
	check(absf(hero.position.distance_to(Vector3(0, 0, -5)) - 3.0) < 0.03,
		"Diagonal input is normalized instead of granting extra speed")
	hero.position = Vector3(0, 0, 5.8)
	hero.move_input = Vector2.DOWN
	await _step(0.5)
	check(hero.position.distance_squared_to(Vector3(0, 0, 9)) >= 5.79,
		"Hero movement respects the Keep footprint")
	var paused_at: Vector3 = hero.position
	_game.pause_run()
	hero.move_input = Vector2.LEFT
	await _step(0.5)
	check(hero.position.is_equal_approx(paused_at), "Paused actors do not move")
	_game.resume_run()
	hero.move_input = Vector2.LEFT
	await _step(0.2)
	check(hero.position.x < paused_at.x - 0.5, "Hero movement resumes after pause")


func _check_hero_arrows() -> void:
	await _fresh_run()
	var hero: Node3D = _game.hero
	hero.position = Vector3.ZERO
	var enemy: Node3D = _spawn_enemy(Vector3(0, 0, -4), {"health": 9.0, "speed": 0.0})
	var enemy_ref: WeakRef = weakref(enemy)
	var gold_before: int = _game.coins
	await _step(0.7)
	check(_game.kills == 1 and enemy_ref.get_ref() == null,
		"Automatic hero arrows kill and remove a real enemy")
	check(hero.xp == 4, "Dealing all enemy health awards its full XP value")
	check(_game.coins == gold_before and _coin_total() == 9,
		"A kill drops physical gold without immediately crediting it")
	await _step(0.3)
	check(_game.kills == 1 and hero.xp == 4,
		"An enemy death awards kills and XP exactly once")


func _check_damage_xp() -> void:
	await _fresh_run()
	var enemy: Node3D = _spawn_enemy(Vector3(0, 0, -4), {"health": 30.0, "speed": 0.0})
	enemy.take_damage(3.0, "hero")
	check(is_equal_approx(_game.hero.xp, 0.4) and not enemy.dead, "Nonlethal hero damage immediately earns fractional XP")
	enemy.take_damage(12.0, "tower")
	check(is_equal_approx(_game.hero.xp, 0.4), "Tower damage awards no hero XP")
	enemy.take_damage(300.0, "hero")
	check(is_equal_approx(_game.hero.xp, 2.4), "Overkill rewards only remaining health without a kill bonus")
	enemy.take_damage(300.0, "hero")
	check(is_equal_approx(_game.hero.xp, 2.4), "Dead targets cannot award XP twice")
	var second: Node3D = _spawn_enemy(Vector3(0, 0, -4), {"health": 30.0, "speed": 0.0})
	second.take_damage(15.0, "hero")
	second.take_damage(100.0, "tower")
	check(is_equal_approx(_game.hero.xp, 4.4), "Tower last hit preserves XP already earned by hero damage")


func _check_tower_attribution() -> void:
	await _fresh_run()
	var hero: Node3D = _game.hero
	hero.position = Vector3(3.2, 0, 3.6)
	check(bool(_game.build_at("watch", "tower")), "Tower test builds through the real purchase API")
	hero.position = Vector3(9, 0, -20)
	hero.attack_range = 0.0
	_spawn_enemy(Vector3(4, 0, 0), {"health": 9.0, "speed": 0.0})
	await _step(1.0)
	check(_game.kills == 1, "A built tower acquires an enemy and kills with an arrow")
	check(hero.xp == 0 and hero.tier == 1, "Tower finishing arrows grant no hero XP")
	check(_coin_total() == 9, "Tower kills still drop the enemy's physical gold")


func _check_projectile_lifecycle() -> void:
	await _fresh_run()
	_game.hero.attack_range = 0.0
	_game.hero.position = Vector3(9, 0, -20)
	var enemy: Node3D = _spawn_enemy(Vector3.ZERO, {"health": 100.0, "speed": 0.0})
	_game.spawn_arrow(Vector3(0, 1, 3), enemy, 10.0, "hero")
	_game.spawn_arrow(Vector3(1, 1, 3), enemy, 10.0, "tower")
	await _step(0.4)
	check(is_equal_approx(enemy.health, 80.0), "Each projectile applies exactly one impact")
	check(_game.get_node("Projectiles").get_child_count() == 0, "Impacted projectiles are freed")
	_game.spawn_arrow(Vector3(0, 1, 7), enemy, 10.0, "hero")
	_game.enemies.erase(enemy)
	enemy.queue_free()
	await process_frame
	await _step(0.2)
	check(_game.get_node("Projectiles").get_child_count() == 0 and _game.kills == 0,
		"An arrow safely expires when its target is freed before impact")
	var overlapping: Node3D = _spawn_enemy(Vector3.ZERO, {"health": 100.0, "speed": 0.0})
	_game.spawn_arrow(Vector3(0, 2, 0), overlapping, 10.0, "hero")
	await _step(0.2)
	check(is_equal_approx(overlapping.health, 90.0), "A vertical arrow resolves without an invalid look direction")


func _check_coin_collection() -> void:
	await _fresh_run()
	_game.hero.position = Vector3.ZERO
	_game.hero.attack_range = 0.0
	var gold_before: int = _game.coins
	_game.drop_coin(Vector3(0, 0, -6), 13)
	await _step(0.5)
	check(_game.coins == gold_before and _coin_total() == 13,
		"Gold outside the magnet radius remains on the battlefield")
	_game.hero.position = Vector3(0, 0, -3)
	await _step(0.8)
	check(_game.coins == gold_before + 13 and _game.coins_collected == 13,
		"Approaching gold attracts it and credits its value on collection")
	await _step(0.5)
	check(_game.coins == gold_before + 13 and _game.get_node("Coins").get_child_count() == 0,
		"Collected gold disappears and cannot credit twice")
	_game.drop_coin(Vector3(0, 0, -5), 11)
	_game.drop_coin(Vector3(0.1, 0, -5), 6)
	check(_game.get_node("Coins").get_child_count() == 1 and _coin_total() == 17,
		"Nearby drops merge while preserving their full gold value")
	await _step(0.8)
	check(_game.coins == gold_before + 30, "Merged physical gold collects its combined value once")


func _check_volley() -> void:
	await _fresh_run()
	var hero: Node3D = _game.hero
	hero.position = Vector3.ZERO
	hero.attack_range = 0.0
	check(not bool(hero.use_ability()) and hero.ability_cooldown == 0.0,
		"Volley remains locked at hero level one")
	var damage_before: float = hero.damage
	var interval_before: float = hero.attack_interval
	hero.add_xp(16)
	check(hero.tier == 2 and hero.xp == 0 and hero.next_xp == 28,
		"Hero XP crosses the configured threshold and carries the remainder")
	check(hero.damage > damage_before and hero.attack_interval < interval_before,
		"Leveling improves hero arrow damage and firing speed")
	check(not bool(hero.use_ability()) and hero.ability_cooldown == 0.0,
		"An empty Volley attempt consumes no cooldown")
	for index: int in range(9):
		var angle: float = float(index) * TAU / 9.0
		_spawn_enemy(Vector3(cos(angle) * 5.0, 0, sin(angle) * 5.0), {"health": 33.0, "speed": 0.0})
	check(bool(hero.use_ability()), "An unlocked Volley fires at nearby live enemies")
	check(_game.get_node("Projectiles").get_child_count() == int(Data.HERO["ability_targets"]),
		"Volley launches visible projectiles up to its configured target cap")
	check(not bool(hero.use_ability()), "Volley cannot fire again during its cooldown")
	await _step(0.7)
	check(_game.kills == 7 and _game.enemies.size() == 2,
		"Volley projectiles damage and kill their selected real targets")
	check(hero.tier == 3, "Volley damage contributes to hero leveling")
	check(hero.ability_cooldown > 0.0, "Volley cooldown remains active after its arrows land")
	hero.call("_physics_process", float(Data.HERO["ability_cooldown"]))
	check(hero.ability_cooldown == 0.0 and bool(hero.use_ability()),
		"Volley becomes usable again after its cooldown elapses")


func _check_keep_attack() -> void:
	await _fresh_run()
	_game.hero.position = Vector3(9, 0, -20)
	_game.hero.attack_range = 0.0
	var route: Array[Vector3] = [Vector3(0, 0, 7), Vector3(0, 0, 9)]
	var enemy: Node3D = _spawn_enemy(route[0], {"speed": 4.0, "damage": 9.0, "attack_interval": 1.2}, route)
	var keep_before: float = _game.keep_health
	await _step(0.9)
	check(enemy.route_index >= route.size() and is_equal_approx(_game.keep_health, keep_before - 9.0),
		"An enemy follows the final route segment and damages the Keep")
	await _step(0.4)
	check(is_equal_approx(_game.keep_health, keep_before - 9.0),
		"Keep attacks obey the enemy attack interval instead of hitting every frame")
	await _step(0.7)
	check(is_equal_approx(_game.keep_health, keep_before - 18.0),
		"An enemy at the Keep attacks again after its interval")


func _check_wall_blocking() -> void:
	await _fresh_run()
	_game.hero.position = Vector3(0, 0, 4)
	check(bool(_game.build_at("gate", "wall")), "Wall test builds through the real purchase API")
	var wall: Node3D = _game.buildings["gate"]
	_game.hero.position = Vector3(0, 0, 2)
	_game.hero.move_input = Vector2.DOWN
	_game.hero.attack_range = 0.0
	await _step(0.6)
	check(_game.hero.position.z < 3.25, "A built wall blocks hero movement through its footprint")
	_game.hero.position = Vector3(9, 0, -20)
	_game.hero.move_input = Vector2.ZERO
	var route: Array[Vector3] = [Vector3.ZERO, Vector3(0, 0, 9)]
	var enemy: Node3D = _spawn_enemy(route[0], {"speed": 3.0, "damage": 60.0, "attack_interval": 0.3}, route)
	var keep_before: float = _game.keep_health
	await _step(1.0)
	check(is_instance_valid(wall) and wall.health < wall.max_health and enemy.position.z < 4.0,
		"An approaching enemy stops before a wall and attacks it")
	check(is_equal_approx(_game.keep_health, keep_before), "A blocking wall protects the Keep")
	await _step(1.3)
	check(not _game.buildings.has("gate") and enemy.position.z > 4.0,
		"An enemy destroys the wall and continues along the route")
	check(_game.plot_views["gate"].visible, "A destroyed wall returns its plot for rebuilding")
	await _step(2.0)
	check(_game.keep_health < keep_before, "After breaking the wall, the enemy can reach and damage the Keep")


func _spawn_enemy(at: Vector3, overrides: Dictionary = {}, route: Array[Vector3] = []) -> Node3D:
	var stats: Dictionary = Data.ENEMIES["goblin"].duplicate(true)
	stats.merge(overrides, true)
	var path: Array[Vector3] = []
	if route.is_empty():
		path.assign([at, at + Vector3(0, 0, 1)])
	else:
		path.assign(route)
	var enemy: Node3D = EnemyScript.new()
	_game.get_node("Actors").add_child(enemy)
	enemy.setup(_game, stats, path)
	enemy.set_physics_process(false)
	_game.enemies.append(enemy)
	return enemy


func _step(seconds: float) -> void:
	var steps: int = ceili(seconds * 60.0)
	for _index: int in range(steps):
		_freeze_auto_ticks()
		for container_name: String in ["Actors", "Structures", "Projectiles", "Coins"]:
			for actor: Node in _game.get_node(container_name).get_children():
				if actor.is_queued_for_deletion() or not actor.has_method("_physics_process"):
					continue
				actor.set_physics_process(false)
				actor.call("_physics_process", 1.0 / 60.0)
		_freeze_auto_ticks()
		await process_frame


func _freeze_auto_ticks() -> void:
	for container_name: String in ["Actors", "Structures", "Projectiles", "Coins"]:
		for actor: Node in _game.get_node(container_name).get_children():
			actor.set_physics_process(false)


func _coin_total() -> int:
	var result: int = 0
	for coin: Node3D in _game.get_node("Coins").get_children():
		if not coin.is_queued_for_deletion():
			result += int(coin.value)
	return result


func check(condition: bool, description: String) -> void:
	_checks += 1
	if condition:
		print("PASS: " + description)
	else:
		_failures += 1
		push_error("FAIL: " + description)
