extends Node3D
## A fixed-destination shot. The launcher may die without removing its projectile.
const Visuals = preload("res://common/visuals.gd")
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
	var hero: Node3D = game.get_hero()
	var center: Vector3 = hero.position + Vector3(0, 0.85, 0)
	# Swept collision prevents fast bolts from skipping through the hero.
	var nearest: Vector3 = Geometry3D.get_closest_point_to_segment(center, position, next)
	if hero.is_alive() and nearest.distance_to(center) <= 0.55:
		hero.take_damage(damage)
		impacted = true
		queue_free()
		return
	position = next
	lifetime -= delta
	if lifetime <= 0.0 or position.distance_squared_to(destination) < 0.001:
		impacted = true
		queue_free()
