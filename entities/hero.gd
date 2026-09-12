extends Node3D
class_name HeroActor

const Visuals := preload("res://common/visuals.gd")

var game: Node
var move_input: Vector2 = Vector2.ZERO
var tier: int = 1
var xp: int = 0
var next_xp: int = 16
var ability_cooldown: float = 0.0
var speed: float = 6.0
var damage: float = 8.0
var attack_interval: float = 0.6
var attack_range: float = 8.0
var coin_radius: float = 2.5
var health: float = 100.0
var respawn_remaining: float = 0.0
var protection_remaining: float = 0.0

func is_alive() -> bool:
	return health > 0.0

func take_damage(amount: float) -> void:
	if not game.is_playing() or not is_alive() or protection_remaining > 0.0 or amount <= 0.0:
		return
	health = maxf(0.0, health - amount)
	game.play_sound("hit")
	game.notify("Archer hit! %d health" % ceili(health), "danger")
	if not is_alive():
		respawn_remaining = float(_stats["respawn_seconds"])
		move_input = Vector2.ZERO
		_model.hide()
		_level_ring.hide()
		game.hud.reset_input()
		game.notify("Archer down! Your defenses must hold.", "danger")

var _stats: Dictionary = {}
var _thresholds: Array = []
var _model: Node3D
var _level_ring: Node3D
var _shot_remaining: float = 0.0
var _walk_phase: float = 0.0
var _level_flash: float = 0.0
var _recoil: float = 0.0


func setup(owner_game: Node, stats: Dictionary) -> void:
	game = owner_game
	_stats = stats.duplicate(true)
	health = float(_stats["health"])
	speed = float(_stats.get("speed", 6.0))
	attack_range = float(_stats.get("range", 8.0))
	coin_radius = float(_stats.get("coin_radius", 2.5))
	_thresholds = _stats.get("xp_thresholds", [16, 28, 42, 58, 76])
	tier = 1
	xp = 0
	ability_cooldown = 0.0
	_refresh_stats()
	_model = Visuals.hero()
	add_child(_model)
	_level_ring = Visuals.ring(0.85, Color(1.0, 0.82, 0.25, 0.8))
	_level_ring.position.y = 0.055
	_level_ring.visible = false
	add_child(_level_ring)


func capture_state() -> Dictionary:
	return {"position": [position.x, position.y, position.z], "tier": tier, "xp": xp,
		"health": health, "respawn_remaining": respawn_remaining, "protection_remaining": protection_remaining,
		"ability_cooldown": ability_cooldown, "shot_remaining": _shot_remaining,
		"facing": _model.rotation.y}


## Called after setup with a snapshot validated by the run controller.
func restore_state(saved: Dictionary) -> void:
	var at: Array = saved["position"]
	position = Vector3(float(at[0]), float(at[1]), float(at[2]))
	tier = int(saved["tier"])
	health = float(saved["health"])
	respawn_remaining = float(saved["respawn_remaining"])
	protection_remaining = float(saved["protection_remaining"])
	_model.visible = is_alive()
	xp = int(saved["xp"])
	_refresh_stats()
	ability_cooldown = float(saved["ability_cooldown"])
	_shot_remaining = float(saved["shot_remaining"])
	move_input = Vector2.ZERO
	_walk_phase = 0.0
	_level_flash = 0.0
	_recoil = 0.0
	_model.position.y = 0.0
	_model.rotation = Vector3(0.0, float(saved["facing"]), 0.0)
	_level_ring.hide()


func _physics_process(delta: float) -> void:
	if not is_instance_valid(game) or not bool(game.call("is_playing")):
		return
	if not is_alive():
		respawn_remaining = maxf(0.0, respawn_remaining - delta)
		if respawn_remaining <= 0.0:
			position = game.hero_respawn_position()
			health = float(_stats["health"])
			protection_remaining = float(_stats["protection_seconds"])
			_model.show()
			move_input = Vector2.ZERO
			game.hud.reset_input()
			game.notify("Archer returned — briefly protected", "success")
		return
	protection_remaining = maxf(0.0, protection_remaining - delta)
	ability_cooldown = maxf(0.0, ability_cooldown - delta)
	_shot_remaining = maxf(0.0, _shot_remaining - delta)
	_recoil = maxf(0.0, _recoil - delta * 6.0)
	var input: Vector2 = move_input.limit_length(1.0)
	var direction := Vector3(input.x, 0.0, input.y)
	var previous: Vector3 = global_position
	if direction.length_squared() > 0.0001:
		var destination: Vector3 = previous + direction * speed * delta
		global_position = game.call("constrain_hero_motion", previous, destination)
		_face(direction, delta)
	var actual_speed: float = global_position.distance_to(previous) / maxf(delta, 0.0001)
	_walk_phase += actual_speed * delta * 8.0
	if is_instance_valid(_model):
		_model.position.y = absf(sin(_walk_phase)) * 0.065 * minf(actual_speed, 1.0)
		_model.rotation.z = sin(_walk_phase * 0.5) * 0.035 * minf(actual_speed, 1.0) + _recoil * 0.10
		if game.reduced_motion():
			_model.position.y = 0.0
			_model.rotation.z = 0.0
	if _shot_remaining <= 0.0:
		var target: Node3D = game.call("nearest_enemy", global_position, attack_range) as Node3D
		if _valid_target(target):
			_fire(target, damage)
			_shot_remaining = attack_interval
	_update_level_flash(delta)


func add_xp(amount: int) -> void:
	if amount <= 0 or next_xp <= 0:
		return
	xp += amount
	var previous_tier: int = tier
	while next_xp > 0 and xp >= next_xp:
		xp -= next_xp
		tier += 1
		_refresh_stats()
	if tier == previous_tier:
		return
	_level_flash = 1.0
	if is_instance_valid(game):
		var message: String = "Hero level %d — stronger, faster arrows!" % tier
		var unlock: int = int(_stats.get("ability_unlock", 2))
		if previous_tier < unlock and tier >= unlock:
			message = "Level %d — Volley unlocked!" % tier
		game.call("notify", message, "success")
		game.call("play_sound", "level_up")


func use_ability() -> bool:
	if not is_instance_valid(game) or not bool(game.call("is_playing")):
		return false
	if not is_alive() or tier < int(_stats.get("ability_unlock", 2)) or ability_cooldown > 0.0:
		return false
	var volley_range: float = float(_stats.get("ability_range", attack_range + 2.0))
	var targets: Array[Node3D] = game.call("enemies_in_range", global_position, volley_range)
	var limit: int = int(_stats.get("ability_targets", 6))
	var fired: int = 0
	var volley_damage: float = float(_stats.get("ability_damage", 20.0))
	volley_damage += float(_stats.get("damage_per_tier", 3.0)) * float(tier - 1)
	for target: Node3D in targets:
		if fired >= limit:
			break
		if not _valid_target(target):
			continue
		var side: float = float(fired % 3 - 1) * 0.25
		var origin: Vector3 = global_position + Vector3(side, 1.15 + floorf(float(fired) / 3.0) * 0.15, 0.0)
		game.call("spawn_arrow", origin, target, volley_damage, "hero")
		fired += 1
	if fired == 0:
		game.call("notify", "Move closer to enemies to use Volley.", "info")
		return false
	ability_cooldown = float(_stats.get("ability_cooldown", 8.0))
	_recoil = 1.0
	game.call("play_sound", "volley")
	return true


func _refresh_stats() -> void:
	var level_bonus: float = float(tier - 1)
	damage = float(_stats.get("damage", 8.0)) + float(_stats.get("damage_per_tier", 3.0)) * level_bonus
	var haste: float = 1.0 + float(_stats.get("attack_speed_per_tier", 0.10)) * level_bonus
	attack_interval = maxf(0.12, float(_stats.get("attack_interval", 0.6)) / haste)
	var threshold_index: int = tier - 1
	next_xp = int(_thresholds[threshold_index]) if threshold_index < _thresholds.size() else 0
	if next_xp == 0:
		xp = 0
	if is_instance_valid(_model):
		_model.scale = Vector3.ONE * (1.0 + level_bonus * 0.035)


func _fire(target: Node3D, amount: float) -> void:
	var direction: Vector3 = target.global_position - global_position
	direction.y = 0.0
	if direction.length_squared() > 0.0001:
		_model.rotation.y = atan2(-direction.x, -direction.z)
	game.call("spawn_arrow", global_position + Vector3(0.0, 1.0, 0.0), target, amount, "hero")
	game.call("play_sound", "shoot")
	_recoil = 1.0


func _face(direction: Vector3, delta: float) -> void:
	if not is_instance_valid(_model):
		return
	var angle: float = atan2(-direction.x, -direction.z)
	_model.rotation.y = lerp_angle(_model.rotation.y, angle, minf(1.0, delta * 16.0))


func _valid_target(target: Node3D) -> bool:
	return is_instance_valid(target) and not target.is_queued_for_deletion() and not bool(target.get("dead"))


func _update_level_flash(delta: float) -> void:
	if not is_instance_valid(_level_ring):
		return
	_level_flash = maxf(0.0, _level_flash - delta)
	_level_ring.visible = _level_flash > 0.0
	_level_ring.scale = Vector3.ONE * (1.0 + (1.0 - _level_flash) * 2.0)
	if game.reduced_motion():
		_level_ring.scale = Vector3.ONE
