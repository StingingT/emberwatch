extends Node3D
class_name EnemyActor

const Visuals := preload("res://common/visuals.gd")
const CombatRules = preload("res://game/enemy_combat_rules.gd")

var game: Node
var health: float = 20.0
var max_health: float = 20.0
var dead: bool = false
var kind: String = "scout"
var route_index: int = 0

var _attack_role: String = "route_only"
var _locomotion: String = "ground"
var _route: Array[Vector3] = []
var _speed: float = 1.8
var _damage: float = 5.0
var _attack_interval: float = 1.0
var _coins: int = 5
var _xp: int = 4
var _attack_remaining: float = 0.0
var _walk_phase: float = 0.0
var _hit_flash: float = 0.0
var _attack_swing: float = 0.0
var _model: Node3D
var _rest_scale: Vector3 = Vector3.ONE
var _health_root: Node3D
var _health_fill: MeshInstance3D
var hero_windup: float = 0.0
var hero_aim: Vector3 = Vector3.ZERO
var _hero_warning: Node3D

func _ranged_target() -> Node3D:
	var radius: float = CombatRules.ranged_range(game)
	if _locomotion == "ground":
		var wall: Node3D = CombatRules.first_route_wall(game, global_position, _route, route_index)
		if wall != null and CombatRules.in_range(global_position, wall.global_position, radius):
			return wall
	var hero: Node3D = game.get_hero()
	if not is_instance_valid(hero) or not hero.is_alive() or not CombatRules.in_range(global_position, hero.global_position, radius):
		return null
	var start: Vector3 = global_position + Vector3(0, CombatRules.SHOT_HEIGHT, 0)
	var aim: Vector3 = hero.global_position + Vector3(0, CombatRules.SHOT_HEIGHT, 0)
	if not CombatRules.first_wall_hit(game, start, aim).is_empty():
		return null
	return hero


func _attack_ranged(delta: float) -> bool:
	# A non-ranged enemy can never retaliate, chase, or deal hero contact damage.
	if _attack_role != "ranged":
		hero_windup = 0.0
		_hero_warning.hide()
		return false
	var target: Node3D = _ranged_target()
	if hero_windup > 0.0:
		hero_windup = maxf(0.0, hero_windup - delta)
		if hero_windup <= 0.0:
			_hero_warning.hide()
			_attack_remaining = _attack_interval
			# Recheck range/visibility at release. A wall introduced during wind-up
			# has priority; a dead, out-of-range, or hidden hero is not shot.
			if is_instance_valid(target):
				hero_aim = target.global_position
				_face(hero_aim - global_position)
				game.fire_enemy_bolt(global_position + Vector3(0, CombatRules.SHOT_HEIGHT, 0), hero_aim + Vector3(0, CombatRules.SHOT_HEIGHT, 0), _damage)
		return true
	if not is_instance_valid(target):
		return false
	if _attack_remaining > 0.0:
		# Stop for a blocking wall, but MOVE along the route between hero shots.
		return CombatRules.is_wall(target)
	hero_aim = target.global_position
	hero_windup = float(GameData.HERO_THREAT["windup"])
	_hero_warning.global_position = global_position + Vector3(0, 0.07, 0)
	_hero_warning.show()
	_face(hero_aim - global_position)
	return true


func setup(owner_game: Node, stats: Dictionary, route: Array[Vector3]) -> void:
	game = owner_game
	kind = str(stats.get("id", "scout"))
	_attack_role = str(stats.get("attack_role", "route_only"))
	_locomotion = str(stats.get("locomotion", "ground"))
	max_health = maxf(1.0, float(stats.get("health", 20.0)))
	health = max_health
	_speed = float(stats.get("speed", 1.8))
	_damage = float(stats.get("damage", 5.0))
	_attack_interval = maxf(0.1, float(stats.get("attack_interval", 1.0)))
	_coins = int(stats.get("coins", 5))
	_xp = int(stats.get("xp", 4))
	_route.assign(route)
	route_index = 1 if _route.size() > 1 else 0
	if not _route.is_empty():
		position = _route[0]
	_model = Visuals.enemy(kind)
	add_child(_model)
	_rest_scale = _model.scale
	_create_health_bar()
	_hero_warning = Visuals.ring(float(GameData.HERO_THREAT["hit_radius"]), Color("ff7954"))
	add_child(_hero_warning)
	_hero_warning.hide()


func capture_state() -> Dictionary:
	return {"position": [position.x, position.y, position.z], "kind": kind,
		"hero_windup": hero_windup, "hero_aim": [hero_aim.x, hero_aim.y, hero_aim.z],
		"health": health, "max_health": max_health, "route_index": route_index,
		"attack_remaining": _attack_remaining, "facing": _model.rotation.y}


## Setup supplies the configured kind, route and wave-scaled combat stats first.
func restore_state(saved: Dictionary) -> void:
	var at: Array = saved["position"]
	position = Vector3(float(at[0]), float(at[1]), float(at[2]))
	kind = str(saved["kind"])
	health = float(saved["health"])
	max_health = float(saved["max_health"])
	route_index = int(saved["route_index"])
	_attack_remaining = float(saved["attack_remaining"])
	hero_windup = float(saved["hero_windup"]) if _attack_role == "ranged" else 0.0
	var aim: Array = saved["hero_aim"]
	hero_aim = Vector3(float(aim[0]), float(aim[1]), float(aim[2]))
	_hero_warning.global_position = global_position + Vector3(0, 0.07, 0)
	_hero_warning.visible = hero_windup > 0.0
	dead = false
	_walk_phase = 0.0
	_hit_flash = 0.0
	_attack_swing = 0.0
	_model.position.y = 0.0
	_model.rotation = Vector3(0.0, float(saved["facing"]), 0.0)
	_model.scale = _rest_scale
	_update_health_bar()


func _physics_process(delta: float) -> void:
	if dead or not is_instance_valid(game) or not bool(game.call("is_playing")):
		return
	_attack_remaining = maxf(0.0, _attack_remaining - delta)
	var attacking: bool = _attack_ranged(delta)
	_hit_flash = maxf(0.0, _hit_flash - delta * 7.0)
	_attack_swing = maxf(0.0, _attack_swing - delta * 4.0)
	var moving: bool = false
	if not attacking and not _route.is_empty():
		if route_index >= _route.size():
			_attack_keep()
		else:
			moving = _follow_route(delta)
	_walk_phase += delta * _speed * 6.0 if moving else 0.0
	if is_instance_valid(_model):
		_model.position.y = absf(sin(_walk_phase)) * 0.07 if moving else 0.0
		_model.rotation.z = sin(_walk_phase * 0.5) * 0.05 if moving else _attack_swing * 0.17
		_model.scale = _rest_scale * Vector3(1.0 + _hit_flash * 0.15, 1.0 - _hit_flash * 0.12, 1.0 + _hit_flash * 0.15)
		if game.reduced_motion():
			_model.position.y = 0.0
			_model.rotation.z = 0.0
			_model.scale = _rest_scale


func take_damage(amount: float, source: String) -> void:
	if dead or amount <= 0.0:
		return
	if not is_instance_valid(game) or not bool(game.call("is_playing")):
		return
	var actual_damage: float = minf(health, amount)
	health = maxf(0.0, health - actual_damage)
	if source == "hero":
		game.on_enemy_damaged(actual_damage / max_health * float(_xp))
	game.call("show_hit", global_position, health <= 0.0)
	_hit_flash = 1.0
	_update_health_bar()
	if health > 0.0:
		return
	dead = true
	set_physics_process(false)
	game.call("on_enemy_killed", self, source, _coins, _xp)
	_make_death_feedback()
	queue_free()


func _follow_route(delta: float) -> bool:
	var remaining: float = _speed * delta
	var moved: bool = false
	while remaining > 0.0 and route_index < _route.size():
		var waypoint: Vector3 = _route[route_index]
		waypoint.y = global_position.y
		var offset: Vector3 = waypoint - global_position
		var distance: float = offset.length()
		if distance < 0.06:
			route_index += 1
			continue
		var direction: Vector3 = offset / distance
		var destination: Vector3 = global_position + direction * minf(distance, remaining)
		# Query only the next stride plus reach, so a wall cannot be hit from afar.
		var wall: Node3D = game.call("get_blocking_wall", global_position, destination + direction * 0.65) as Node3D
		if _locomotion != "flying" and is_instance_valid(wall) and not wall.is_queued_for_deletion():
			_face(wall.global_position - global_position)
			if _attack_role != "ranged" and _attack_remaining <= 0.0 and wall.has_method("take_damage"):
				wall.call("take_damage", _damage, "enemy")
				_attack_remaining = _attack_interval
				_attack_swing = 1.0
			return moved
		global_position = destination
		_face(direction)
		moved = true
		remaining -= minf(distance, remaining)
		if distance <= _speed * delta and global_position.distance_to(waypoint) < 0.06:
			route_index += 1
	return moved


func _attack_keep() -> void:
	if _attack_remaining > 0.0:
		return
	game.call("damage_keep", _damage)
	_attack_remaining = _attack_interval
	_attack_swing = 1.0


func _face(direction: Vector3) -> void:
	if not is_instance_valid(_model) or direction.length_squared() < 0.0001:
		return
	_model.rotation.y = atan2(-direction.x, -direction.z)


func _create_health_bar() -> void:
	_health_root = Node3D.new()
	_health_root.position.y = _model_head_height() + 0.22
	add_child(_health_root)
	var backing: MeshInstance3D = _health_quad(Color("19251c"), Vector2(1.12, 0.17), 10)
	_health_root.add_child(backing)
	_health_fill = _health_quad(Color("77ca52"), Vector2(1.00, 0.095), 11)
	_health_fill.position.z = 0.015
	_health_root.add_child(_health_fill)
	_update_health_bar()


func _model_head_height() -> float:
	# Use the actual model bounds, including a brute's scale and a hunter's pelt.
	var top: float = 1.4
	for raw: Node in _model.find_children("*", "MeshInstance3D", true, false):
		var mesh: MeshInstance3D = raw as MeshInstance3D
		var bounds: AABB = mesh.get_aabb()
		var relative: Transform3D = global_transform.affine_inverse() * mesh.global_transform
		for corner: int in range(8):
			top = maxf(top, (relative * bounds.get_endpoint(corner)).y)
	return top


func _health_quad(color: Color, size: Vector2, priority: int) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.billboard_keep_scale = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.no_depth_test = true
	material.render_priority = priority
	quad.material = material
	visual.mesh = quad
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return visual


func _update_health_bar() -> void:
	if not is_instance_valid(_health_fill):
		return
	var fraction: float = clampf(health / max_health, 0.0, 1.0)
	_health_fill.scale.x = maxf(0.001, fraction)
	_health_fill.position.x = -(1.0 - fraction) * 0.50
	_health_root.visible = not dead and health > 0.0


func _make_death_feedback() -> void:
	if not is_instance_valid(_model) or not is_inside_tree():
		return
	if game.reduced_motion():
		return
	# The short-lived model has no gameplay identity after the kill callback.
	var corpse: Node3D = _model
	corpse.reparent(game)
	_model = null
	var tween: Tween = corpse.create_tween()
	tween.set_parallel(true)
	tween.tween_property(corpse, "scale", _rest_scale * Vector3(1.2, 0.05, 1.2), 0.22)
	tween.tween_property(corpse, "position:y", corpse.position.y - 0.25, 0.22)
	tween.finished.connect(corpse.queue_free)
