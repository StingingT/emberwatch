extends SceneTree
## Actor-level JSON round trips. No composition root, files or player saves.
## godot --headless --path . --script tests/check_actor_snapshot.gd

const HeroScript = preload("res://entities/hero.gd")
const EnemyScript = preload("res://entities/enemy.gd")
const CoinScript = preload("res://entities/coin.gd")
const ArrowScript = preload("res://entities/projectile.gd")
const BuildingScript = preload("res://game/building.gd")
const Data = preload("res://game/game_data.gd")

class SnapshotGame extends Node3D:
	var events: Array[String] = []
	var hero: Node3D
	func is_playing() -> bool:
		return true
	func reduced_motion() -> bool:
		return false
	func fortify_multiplier() -> float:
		return 1.4
	func get_hero() -> Node3D:
		return hero
	func nearest_enemy(_at: Vector3, _radius: float) -> Node3D:
		return null
	func get_blocking_wall(_from: Vector3, _to: Vector3) -> Node3D:
		return null
	func notify(_message: String, _kind: String) -> void:
		events.append("notify")
	func play_sound(_id: String) -> void:
		events.append("sound")
	func spawn_arrow(_at: Vector3, _target: Node3D, _damage: float, _source: String) -> void:
		events.append("arrow")
	func show_hit(_at: Vector3, _dead: bool) -> void:
		events.append("hit")
	func on_enemy_damaged(_xp: float) -> void:
		pass

	func on_enemy_killed(_enemy: Node3D, _source: String, _coins: int, _xp: int) -> void:
		events.append("kill")
	func on_building_destroyed(_building: Node3D) -> void:
		events.append("destroyed")
	func damage_keep(_amount: float) -> void:
		events.append("keep")
	func collect_coin(_amount: int, _at: Vector3) -> void:
		events.append("collection")
	func drop_coin(_at: Vector3, _amount: int) -> void:
		events.append("production")

var _game: SnapshotGame
var _checks: int = 0
var _failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_game = SnapshotGame.new()
	root.add_child(_game)
	_check_hero()
	_check_enemy()
	_check_buildings()
	_check_coins()
	_check_arrows()
	_check(_game.events.is_empty(), "capture and restore trigger no reward, attack, purchase, collection or feedback callbacks")
	# Let any cancelled construction tweens and queued actors clean up normally.
	await process_frame
	await process_frame
	_game.queue_free()
	await process_frame
	await process_frame
	if _failures.is_empty():
		print("ACTOR_SNAPSHOT_CHECKS_PASS: %d checks; no save files" % _checks)
		quit(0)
	else:
		for failure: String in _failures:
			push_error(failure)
		quit(1)

func _add_actor(script: Script) -> Node3D:
	var actor: Node3D = script.new()
	_game.add_child(actor)
	actor.set_physics_process(false)
	return actor

func _check_hero() -> void:
	var source: Node3D = _add_actor(HeroScript)
	source.setup(_game, Data.HERO)
	source.position = Vector3(-2.125, 0, -9.75)
	source.tier = 3
	source.xp = 11.75
	source._refresh_stats()
	source.ability_cooldown = 7.35
	source._shot_remaining = 0.315
	source._model.rotation.y = -1.23
	var saved: Dictionary = _json_snapshot(source, ["position", "tier", "xp", "choices", "ability_cooldown", "shot_remaining", "facing", "health", "respawn_remaining", "protection_remaining"])
	var restored: Node3D = _add_actor(HeroScript)
	restored.setup(_game, Data.HERO)
	restored.move_input = Vector2.ONE
	restored._level_flash = 1.0
	restored.restore_state(saved)
	_check(_equal(saved, restored.capture_state()), "hero round trip preserves XP, facing and exact cooldowns")
	_check(restored.tier == 3 and restored.xp == 11.75 and restored.next_xp == 42, "hero XP restores without replaying level gains")
	_check(is_equal_approx(restored.damage, 18.0) and is_equal_approx(restored.attack_interval, 0.65 / 1.2), "hero damage and attack interval derive from configured tier")
	_check(restored._model.scale.is_equal_approx(Vector3.ONE * 1.07), "hero tier size is restored immediately")
	_check(restored.move_input == Vector2.ZERO and restored._level_flash == 0.0 and not restored._level_ring.visible, "hero restores without stale movement or level feedback")
	_game.hero = restored
	_game.hero.position = Vector3.ZERO

func _check_enemy() -> void:
	var stats: Dictionary = Data.ENEMIES["brute"].duplicate(true)
	stats["health"] = 137.5
	var route: Array[Vector3] = [Vector3(0, 0, -20), Vector3(0, 0, -10), Vector3(0, 0, 9)]
	var source: Node3D = _add_actor(EnemyScript)
	source.setup(_game, stats, route)
	source.position = Vector3(0, 0, -7.5)
	source.health = 84.25
	source.route_index = 2
	source._attack_remaining = 0.625
	source._model.rotation.y = 0.73
	var saved: Dictionary = _json_snapshot(source, ["position", "kind", "health", "max_health", "route_index", "attack_remaining", "facing", "hero_windup", "hero_aim"])
	var restored: Node3D = _add_actor(EnemyScript)
	restored.setup(_game, stats, route)
	restored.restore_state(saved)
	_check(_equal(saved, restored.capture_state()), "enemy restores scaled maximum health, wounds, route progress and facing")
	_check(restored._health_root.visible and is_equal_approx(restored._health_fill.scale.x, 84.25 / 137.5), "enemy wound bar immediately reflects restored health")
	_check(is_equal_approx(restored._speed, float(stats["speed"])) and restored._coins == int(stats["coins"]), "enemy combat and rewards stay configured rather than duplicated in the snapshot")
	source._physics_process(0.2)
	restored._physics_process(0.2)
	_check(_equal(source.capture_state(), restored.capture_state()), "restored enemy continues the same route stride and attack timer")

func _check_buildings() -> void:
	for kind: String in ["tower", "wall", "mine", "smith"]:
		var source: Node3D = _add_actor(BuildingScript)
		source.setup(_game, kind, "fixture_" + kind, Vector3(5, 0, -5), false)
		source.tier = 3
		source._refresh_health(true)
		source.health -= 37.25
		source.cooldown = -127.875 if kind == "tower" else 3.425
		var saved: Dictionary = _json_snapshot(source, ["plot_id", "kind", "tier", "health", "cooldown"])
		var restored: Node3D = _add_actor(BuildingScript)
		restored.setup(_game, kind, "fixture_" + kind, source.position, false)
		_check(restored._construction_tween == null and restored.model.scale == Vector3.ONE, kind + " setup can omit construction animation")
		restored.restore_state(saved)
		_check(_equal(saved, restored.capture_state()), kind + " restores final tier, wounded health and exact cooldown")
		var expected_max: float = float(Data.BUILDINGS[kind]["health"][2]) * (1.4 if kind == "wall" else 1.0)
		_check(is_equal_approx(restored.max_health, expected_max) and restored._health_bar.visible, kind + " derives tier health including fortification without healing wounds")
		_check(restored._construction_tween == null and restored.model.scale == Vector3.ONE, kind + " restore creates a final model without replaying construction")
		if kind == "tower":
			restored._physics_process(0.25)
			_check(is_equal_approx(restored.cooldown, -128.125), "negative idle tower cooldown stays signed after resume")
		# Normal setup still animates; restoration cancels an already running tween.
		var animated: Node3D = _add_actor(BuildingScript)
		animated.setup(_game, kind, "fixture_" + kind, source.position)
		var old_tween: Tween = animated._construction_tween
		_check(old_tween != null and old_tween.is_valid() and animated.model.scale.y < 1.0, kind + " normal setup retains its construction animation")
		animated.restore_state(saved)
		_check(not old_tween.is_valid() and animated.model.scale == Vector3.ONE, kind + " restore cancels any previous construction tween")

func _check_coins() -> void:
	var source: Node3D = _add_actor(CoinScript)
	source.setup(_game, Vector3(-8, 0, -3), 23)
	source._magnetized = true
	source._magnet_speed = 11.0
	source._age = 1.35
	source._phase = 2.63
	var saved: Dictionary = _json_snapshot(source, ["position", "value", "magnetized", "magnet_speed", "age", "phase"])
	var restored: Node3D = _add_actor(CoinScript)
	restored.setup(_game, Vector3.ZERO, 1)
	restored.restore_state(saved)
	_check(_equal(saved, restored.capture_state()) and restored.snapshot_available(), "physical gold restores value, age and in-flight magnet state")
	source._physics_process(0.1)
	restored._physics_process(0.1)
	_check(_equal(source.capture_state(), restored.capture_state()), "restored attracted gold continues its acceleration outside the initial magnet radius")
	_check(restored.position.distance_to(Vector3(-8, 0, -3)) > 1.3, "restored gold travels toward the hero without requiring magnet reacquisition")
	source._collected = true
	_check(not source.snapshot_available(), "collected gold is excluded from snapshots")
	restored.queue_free()
	_check(not restored.snapshot_available(), "queued gold is excluded from snapshots")

func _check_arrows() -> void:
	var route: Array[Vector3] = [Vector3(0, 0, -15), Vector3(0, 0, 9)]
	var target: Node3D = _add_actor(EnemyScript)
	target.setup(_game, Data.ENEMIES["goblin"], route)
	var source: Node3D = _add_actor(ArrowScript)
	source.setup(_game, Vector3(1, 1.2, 4), target, 7.5, "tower", 4.0)
	source._lifetime = 0.12
	var saved: Dictionary = _json_snapshot(source, ["position", "damage", "source", "speed", "lifetime"])
	var restored: Node3D = _add_actor(ArrowScript)
	restored.setup(_game, Vector3.ZERO, target, 1.0, "hero")
	restored.restore_state(saved)
	_check(_equal(saved, restored.capture_state()) and restored.snapshot_target() == target, "arrow restores flight data while retaining its resolved live target")
	source._physics_process(0.05)
	restored._physics_process(0.05)
	_check(_equal(source.capture_state(), restored.capture_state()), "restored arrow continues the same flight and remaining lifetime")
	restored._physics_process(0.08)
	_check(restored.is_queued_for_deletion() and restored.snapshot_target() == null, "restored arrow expires at its original remaining lifetime")
	_check(is_equal_approx(target.health, target.max_health), "restoring or expiring an arrow deals no damage")
	source._impacted = true
	_check(source.snapshot_target() == null, "an impacted arrow exposes no snapshot target")
	source._impacted = false
	target.dead = true
	_check(source.snapshot_target() == null, "an arrow excludes a dying target")
	target.dead = false
	target.queue_free()
	_check(source.snapshot_target() == null, "an arrow excludes a target queued for deletion")

func _json_snapshot(actor: Node3D, keys: Array) -> Dictionary:
	var captured: Dictionary = actor.capture_state()
	_check(captured.size() == keys.size() and captured.has_all(keys), actor.get_script().resource_path.get_file() + " snapshot has exactly the contracted keys")
	_check(_is_json_value(captured), actor.get_script().resource_path.get_file() + " snapshot contains only JSON primitives")
	var parsed: Variant = JSON.parse_string(JSON.stringify(captured))
	_check(parsed is Dictionary and _equal(captured, parsed), "snapshot survives JSON serialization without state loss")
	return parsed as Dictionary

func _is_json_value(value: Variant) -> bool:
	if value is Dictionary:
		for key: Variant in value:
			if not key is String or not _is_json_value(value[key]):
				return false
		return true
	if value is Array:
		for item: Variant in value:
			if not _is_json_value(item):
				return false
		return true
	return value == null or value is String or value is bool or value is int or (value is float and is_finite(value))

func _equal(left: Variant, right: Variant) -> bool:
	if left is Dictionary and right is Dictionary:
		if left.size() != right.size():
			return false
		for key: Variant in left:
			if not right.has(key) or not _equal(left[key], right[key]):
				return false
		return true
	if left is Array and right is Array:
		if left.size() != right.size():
			return false
		for index: int in range(left.size()):
			if not _equal(left[index], right[index]):
				return false
		return true
	if (left is int or left is float) and (right is int or right is float):
		return is_equal_approx(float(left), float(right))
	return left == right

func _check(ok: bool, description: String) -> void:
	_checks += 1
	if not ok:
		_failures.append(description)
