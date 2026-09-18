extends Node3D
## Travels on a fixed line and damages each crossed enemy at most once.
const Visuals = preload("res://common/visuals.gd")
var game: Node
var direction: Vector3
var damage: float
var distance_left: float = 12.0
var remaining_hits: int = 3
var hit_targets: Array[WeakRef] = []
var finished: bool = false

func setup(owner_game: Node, start: Vector3, heading: Vector3, amount: float, hits: int = 3) -> void:
	game = owner_game
	position = start
	direction = heading.normalized()
	direction.y = 0.0
	direction = direction.normalized()
	damage = amount
	remaining_hits = hits
	var model: Node3D = Visuals.piercing_arrow()
	add_child(model)
	if direction.length_squared() > 0.001:
		look_at(position + direction, Vector3.UP)

func snapshot_hits() -> Array[Node3D]:
	var result: Array[Node3D] = []
	for reference: WeakRef in hit_targets:
		var target: Node3D = reference.get_ref() as Node3D
		if is_instance_valid(target):
			result.append(target)
	return result

func capture_state() -> Dictionary:
	return {"source": "piercing", "position": [position.x, position.y, position.z],
		"direction": [direction.x, direction.y, direction.z], "damage": damage,
		"distance_left": distance_left, "remaining_hits": remaining_hits}

func restore_state(saved: Dictionary, prior_hits: Array[Node3D]) -> void:
	distance_left = float(saved["distance_left"])
	for target: Node3D in prior_hits:
		hit_targets.append(weakref(target))

func _physics_process(delta: float) -> void:
	if finished or not game.is_playing():
		return
	var step: float = minf(24.0 * delta, distance_left)
	var end: Vector3 = position + direction * step
	var candidates: Array[Node3D] = []
	var previous_hits: Array[Node3D] = snapshot_hits()
	for target: Node3D in game.enemies:
		if not is_instance_valid(target) or target.dead or previous_hits.has(target):
			continue
		var center: Vector3 = target.position + Vector3(0, 1.0, 0)
		if Geometry3D.get_closest_point_to_segment(center, position, end).distance_to(center) <= 0.65:
			candidates.append(target)
	candidates.sort_custom(func(a: Node3D, b: Node3D) -> bool: return position.distance_squared_to(a.position) < position.distance_squared_to(b.position))
	for target: Node3D in candidates:
		hit_targets.append(weakref(target))
		target.take_damage(damage, "hero")
		remaining_hits -= 1
		if remaining_hits <= 0:
			finished = true
			queue_free()
			return
	position = end
	distance_left -= step
	if distance_left <= 0.0:
		finished = true
		queue_free()
