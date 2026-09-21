extends SceneTree
## Real production scene + actor tests, driven by explicit simulation steps.
## This isolates targeting/collisions; it is not a campaign balance playthrough.
const Main = preload("res://game/main.tscn")
const Data = preload("res://game/game_data.gd")
const Rules = preload("res://game/enemy_combat_rules.gd")
const Building = preload("res://game/building.gd")
const Bolt = preload("res://entities/enemy_bolt.gd")
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
	game.start_run()
	game.process_mode = Node.PROCESS_MODE_DISABLED
	game.profile.data["settings"]["reduced_motion"] = true
	game.sounds.enabled = false
	game.hero.position = Vector3.ZERO
	return game

func _enemy(game: Node3D, kind: String, at: Vector3) -> Node3D:
	var enemy: Node3D = game.spawn_enemy(kind)
	enemy.position = at
	enemy._route.assign([at, Vector3(at.x, 0, 8)])
	enemy.route_index = 1
	return enemy

func _wall(game: Node3D, at: Vector3, kind: String = "wall") -> Node3D:
	var wall: Node3D = Building.new()
	game._structures.add_child(wall)
	wall.setup(game, kind, "gate", at, false)
	game.buildings["gate"] = wall
	return wall

func _release(enemy: Node3D) -> void:
	enemy._attack_ranged(0.0)
	enemy._attack_ranged(float(Data.HERO_THREAT["windup"]) + 0.001)

func _remove_shots(game: Node3D) -> void:
	for child: Node in game._projectiles.get_children():
		game._projectiles.remove_child(child)
		child.queue_free()

func _dispose(game: Node3D) -> void:
	game.queue_free()
	await process_frame

func _range_and_roles() -> void:
	var game: Node3D = _new_game()
	_check(is_equal_approx(Rules.ranged_range(game), game.hero.attack_range), "ranger uses the hero basic-attack range, not a separate range or Volley range")
	var ranger: Node3D = _enemy(game, "ranger", Vector3(0, 0, -7.9))
	_release(ranger)
	_check(game._projectiles.get_child_count() == 1, "ranger fires at the hero just inside the default eight-unit range")
	_remove_shots(game)
	for radius: float in [6.0, 8.0, 12.0]:
		game.hero.attack_range = radius
		ranger.position = Vector3(0, 0, -radius - 0.01)
		ranger.hero_windup = 0.0
		ranger._attack_remaining = 0.0
		_check(not ranger._attack_ranged(0.0), "hero outside shared range %s is not acquired" % radius)
		ranger.position.z = -radius + 0.01
		_release(ranger)
		_check(game._projectiles.get_child_count() == 1, "hero inside shared range %s is shot" % radius)
		_remove_shots(game)
	game.hero.attack_range = 0.0
	_check(Rules.ranged_range(game) == 0.0, "zero hero range is respected rather than replaced by a fallback")
	game.hero.attack_range = 8.0
	ranger.hero_windup = 0.0
	ranger._attack_remaining = 0.0
	ranger.position = Vector3(0, 0, -3)
	ranger._attack_ranged(0.0)
	game.hero.position = Vector3(0, 0, 6)
	ranger._attack_ranged(0.8)
	_check(game._projectiles.get_child_count() == 0, "range is rechecked when wind-up finishes")
	game.hero.position = Vector3.ZERO
	for kind: String in ["goblin", "scout", "brute", "hunter"]:
		var enemy: Node3D = _enemy(game, kind, Vector3(0, 0, -1))
		var health: float = game.hero.health
		var before: Vector3 = enemy.position
		enemy.hero_windup = 0.2
		enemy._physics_process(1.0)
		_check(game.hero.health == health and enemy.hero_windup == 0.0, "%s cannot melee, retaliate, or wind up against the hero" % kind)
		_check(enemy.position.z > before.z and is_equal_approx(enemy.position.x, before.x), "%s continues its route instead of pursuing the hero" % kind)
		var hp: float = enemy.health
		enemy.take_damage(hp * 0.1, "hero")
		enemy._physics_process(0.8)
		_check(game.hero.health == health, "%s does not retaliate after taking hero damage" % kind)
	await _dispose(game)

func _wall_range_and_movement() -> void:
	for radius: float in [6.0, 8.0, 12.0]:
		var game: Node3D = _new_game()
		game.hero.attack_range = radius
		game.hero.position = Vector3(0, 0, -1)
		var wall: Node3D = _wall(game, Vector3.ZERO)
		var ranger: Node3D = _enemy(game, "ranger", Vector3(0, 0, -radius + 0.01))
		_check(ranger._ranged_target() == wall, "blocking wall has priority over an eligible hero at range %s" % radius)
		_release(ranger)
		var bolt: Node3D = game._projectiles.get_child(0) if game._projectiles.get_child_count() == 1 else null
		_check(is_instance_valid(bolt) and bolt.destination.is_equal_approx(wall.position + Vector3(0, Rules.SHOT_HEIGHT, 0)), "wall shot uses the same release path as a hero shot at range %s" % radius)
		var before: Vector3 = ranger.position
		ranger._physics_process(0.1)
		_check(ranger.position.is_equal_approx(before), "ranger holds firing distance from its blocking wall during recovery")
		game.hero.position = Vector3(9, 0, 8)
		ranger.position.z = -radius - 0.01
		ranger._attack_remaining = 0.0
		ranger.hero_windup = 0.0
		before = ranger.position
		ranger._physics_process(0.1)
		_check(ranger.position.z > before.z and ranger.hero_windup == 0.0, "out-of-range wall is approached, not attacked with a different wall radius")
		await _dispose(game)
	var game: Node3D = _new_game()
	var ranger: Node3D = _enemy(game, "ranger", Vector3(0, 0, -3))
	_release(ranger)
	var before: Vector3 = ranger.position
	ranger._physics_process(0.1)
	_check(ranger.position.z > before.z, "ranger advances down the route between hero shots")
	var wall: Node3D = _wall(game, Vector3.ZERO)
	game.hero.position = Vector3(0, 0, 3)
	ranger.position = Vector3(0, 0, -3)
	ranger._route.assign([ranger.position, Vector3(6, 0, -3)])
	ranger.route_index = 1
	_check(ranger._ranged_target() == null, "an off-route wall still occludes the hero and is not chosen as an arbitrary target")
	wall.kind = "tower"
	game.hero.position = Vector3(9, 0, 8)
	ranger._route.assign([ranger.position, Vector3(0, 0, 8)])
	for kind: String in ["tower", "mine", "smith"]:
		wall.kind = kind
		_check(ranger._ranged_target() == null, "%s is never an enemy attack target" % kind)
	await _dispose(game)

func _projectile_interception() -> void:
	for hero_first: bool in [false, true]:
		var game: Node3D = _new_game()
		game.hero.position = Vector3(0, 0, -1 if hero_first else 3)
		var wall: Node3D = _wall(game, Vector3.ZERO)
		var bolt: Node3D = Bolt.new()
		game._projectiles.add_child(bolt)
		bolt.setup(game, Vector3(0, 0.85, -3), Vector3(0, 0.85, 4), 11.0)
		var hero_hp: float = game.hero.health
		var wall_hp: float = wall.health
		bolt._physics_process(1.0)
		_check(bolt.impacted, "swept collision resolves a large-step impact")
		_check(game.hero.health == hero_hp - (11.0 if hero_first else 0.0), "swept shot damages hero only when hero is the first intersection")
		_check(wall.health == wall_hp - (0.0 if hero_first else 11.0), "swept shot damages wall only when wall is the first intersection")
		bolt._physics_process(1.0)
		_check(game.hero.health + wall.health == hero_hp + wall_hp - 11.0, "repeat projectile step cannot apply damage twice")
		await _dispose(game)
	var game: Node3D = _new_game()
	var bolt: Node3D = Bolt.new()
	game._projectiles.add_child(bolt)
	bolt.setup(game, Vector3(0, 0.85, -3), Vector3(0, 0.85, 3), 11.0)
	game.pause_run()
	var before: Vector3 = bolt.position
	var lifetime: float = bolt.lifetime
	bolt._physics_process(1.0)
	_check(bolt.position == before and bolt.lifetime == lifetime and not bolt.impacted, "pause freezes flight, impact, and lifetime")
	await _dispose(game)

func _health_bars_and_snapshot() -> void:
	var game: Node3D = _new_game()
	for kind: String in Data.ENEMIES:
		var enemy: Node3D = _enemy(game, kind, Vector3(0, 0, -4))
		_check(enemy._health_root.visible, "%s health bar is visible at full HP" % kind)
		_check(enemy._health_root.position.y > enemy._model_head_height(), "%s health bar is above its model bounds" % kind)
		var material: StandardMaterial3D = enemy._health_fill.mesh.material
		_check(material.billboard_keep_scale and material.render_priority == 11 and material.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA, "fill is camera-facing, scale-preserving, and drawn after its backing")
		enemy.take_damage(enemy.max_health * 0.5, "tower")
		_check(enemy._health_root.visible and is_equal_approx(enemy._health_fill.scale.x, 0.5), "accepted damage updates health fill immediately")
		var saved: Dictionary = enemy.capture_state()
		enemy.restore_state(saved)
		_check(enemy._health_root.visible and is_equal_approx(enemy._health_fill.scale.x, 0.5), "restoration preserves a visible wounded bar")
		enemy.take_damage(enemy.health, "tower")
		_check(not enemy._health_root.visible, "death hides the health bar")
	var ranger: Node3D = _enemy(game, "ranger", Vector3(0, 0, -3))
	ranger._attack_ranged(0.0)
	var saved: Dictionary = ranger.capture_state()
	ranger.restore_state(saved)
	_check(ranger.hero_windup > 0.0 and ranger._hero_warning.visible, "existing snapshot fields preserve ranged wind-up")
	await _dispose(game)

func _run() -> void:
	await _range_and_roles()
	await _wall_range_and_movement()
	await _projectile_interception()
	await _health_bars_and_snapshot()
	if failures.is_empty():
		print("ENEMY_RANGE_ROLES_OK: %d checks" % checks)
	else:
		print("ENEMY_RANGE_ROLES_FAILED: %d / %d" % [failures.size(), checks])
	quit(0 if failures.is_empty() else 1)
