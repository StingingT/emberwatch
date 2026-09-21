extends Node3D
## Fixed-destination hostile shot. Walls and the hero are swept in travel order.
## A wall-targeted shot uses the same flight/range as a hero-targeted shot.
const Visuals = preload("res://common/visuals.gd")
const CombatRules = preload("res://game/enemy_combat_rules.gd")
var game: Node
var destination: Vector3
var damage: float
var speed: float = 9.0
var lifetime: float = 2.0
var impacted: bool = false

func setup(owner_game: Node, start: Vector3, aim: Vector3, amount: float) -> void:
	game = owner_game
	position = start
	destination = aim
	damage = amount
	var model: Node3D = Visuals.enemy_bolt()
	add_child(model)
	if position.distance_squared_to(destination) > 0.001:
		look_at(destination, Vector3.UP)

func snapshot_target() -> Node3D:
	# Existing serializer uses the hero as the hostile-projectile sentinel, not
	# as a homing target. Flight is determined exclusively by saved destination.
	return null if impacted or is_queued_for_deletion() else game.get_hero()

func capture_state() -> Dictionary:
	return {"position": [position.x, position.y, position.z], "destination": [destination.x, destination.y, destination.z],
		"source": "enemy", "damage": damage, "speed": speed, "lifetime": lifetime}

func restore_state(saved: Dictionary) -> void:
	speed = float(saved["speed"])
	lifetime = float(saved["lifetime"])

func _physics_process(delta: float) -> void:
	if impacted or not game.is_playing():
		return
	var next: Vector3 = position.move_toward(destination, speed * delta)
	var wall_hit: Dictionary = CombatRules.first_wall_hit(game, position, next)
	var hero: Node3D = game.get_hero()
	var hero_time: float = -1.0
	if is_instance_valid(hero) and hero.is_alive():
		var center: Vector3 = hero.global_position + Vector3(0, CombatRules.SHOT_HEIGHT, 0)
		hero_time = CombatRules.segment_sphere_hit(position, next, center, CombatRules.HERO_HIT_RADIUS)
	# A wall wins an exact tie: a hero protected by that wall is not hit through it.
	if not wall_hit.is_empty() and (hero_time < 0.0 or float(wall_hit["time"]) <= hero_time):
		impacted = true
		wall_hit["wall"].take_damage(damage, "enemy")
		queue_free()
		return
	if hero_time >= 0.0:
		impacted = true
		hero.take_damage(damage)
		queue_free()
		return
	position = next
	lifetime -= delta
	if lifetime <= 0.0 or position.distance_squared_to(destination) < 0.001:
		impacted = true
		queue_free()
