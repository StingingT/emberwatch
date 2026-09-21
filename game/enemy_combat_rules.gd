class_name EnemyCombatRules
extends RefCounted
## Shared geometric rules. No rewards, timers, damage, or UI mutations here.
const Data = preload("res://game/game_data.gd")
const SHOT_HEIGHT: float = 0.85
const HERO_HIT_RADIUS: float = 0.55
const WALL_HEIGHTS: Array[float] = [1.25, 1.60, 1.85]

static func ranged_range(game: Node) -> float:
	# Basic bow range, NOT Volley range. Read live rather than copying an enemy stat.
	if is_instance_valid(game):
		var hero: Node3D = game.get_hero()
		if is_instance_valid(hero):
			var value: Variant = hero.get("attack_range")
			if (typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT) and is_finite(float(value)) and float(value) >= 0.0:
				return float(value)
	return float(Data.HERO["range"])

static func in_range(from: Vector3, to: Vector3, radius: float) -> bool:
	# Match the hero's XZ, centre-to-centre acquisition and strict outer boundary.
	var offset: Vector2 = Vector2(to.x - from.x, to.z - from.z)
	return radius > 0.0 and offset.length_squared() < radius * radius

static func is_wall(node: Node) -> bool:
	return is_instance_valid(node) and not node.is_queued_for_deletion() and str(node.get("kind")) == "wall" and not bool(node.get("dead"))

static func segment_box_hit(from: Vector3, to: Vector3, low: Vector3, high: Vector3) -> float:
	# Slab intersection: first fraction in [0,1], or -1. Handles zero axis motion.
	var step: Vector3 = to - from
	var enter: float = 0.0
	var leave: float = 1.0
	for axis: int in range(3):
		if absf(step[axis]) < 0.000001:
			if from[axis] < low[axis] or from[axis] > high[axis]:
				return -1.0
			continue
		var near: float = (low[axis] - from[axis]) / step[axis]
		var far: float = (high[axis] - from[axis]) / step[axis]
		enter = maxf(enter, minf(near, far))
		leave = minf(leave, maxf(near, far))
		if enter > leave:
			return -1.0
	return enter

static func segment_sphere_hit(from: Vector3, to: Vector3, center: Vector3, radius: float) -> float:
	var offset: Vector3 = from - center
	var step: Vector3 = to - from
	var c: float = offset.length_squared() - radius * radius
	if c <= 0.0:
		return 0.0
	var a: float = step.length_squared()
	if a < 0.00000001:
		return -1.0
	var b: float = offset.dot(step)
	var discriminant: float = b * b - a * c
	if discriminant < 0.0:
		return -1.0
	var time: float = (-b - sqrt(discriminant)) / a
	return time if time >= 0.0 and time <= 1.0 else -1.0

static func first_wall_hit(game: Node, from: Vector3, to: Vector3) -> Dictionary:
	var hit: Dictionary = {}
	for raw: Variant in game.buildings.values():
		var wall: Node3D = raw as Node3D
		if not is_wall(wall):
			continue
		# These match the main wall body, not the larger hero-clearance footprint.
		var height: float = WALL_HEIGHTS[clampi(int(wall.get("tier")), 1, 3) - 1]
		var low: Vector3 = wall.global_position + Vector3(-1.50, 0.0, -0.40)
		var high: Vector3 = wall.global_position + Vector3(1.50, height, 0.40)
		var time: float = segment_box_hit(from, to, low, high)
		if time < 0.0:
			continue
		if hit.is_empty() or time < float(hit["time"]) or (is_equal_approx(time, float(hit["time"])) and str(wall.get("plot_id")) < str(hit["wall"].get("plot_id"))):
			hit = {"wall": wall, "time": time}
	return hit

static func first_route_wall(game: Node, from: Vector3, route: Array[Vector3], next_index: int) -> Node3D:
	# Route order wins over Euclidean proximity. The conservative navigation box
	# matches game.get_blocking_wall; projectile intersections use the body above.
	if next_index < 0 or next_index >= route.size():
		return null
	var start: Vector3 = Vector3(from.x, SHOT_HEIGHT, from.z)
	for index: int in range(next_index, route.size()):
		var end: Vector3 = Vector3(route[index].x, SHOT_HEIGHT, route[index].z)
		var nearest: Node3D = null
		var nearest_time: float = INF
		for raw: Variant in game.buildings.values():
			var wall: Node3D = raw as Node3D
			if not is_wall(wall):
				continue
			var at: Vector3 = wall.global_position
			var time: float = segment_box_hit(start, end, at + Vector3(-2.0, 0, -1.5), at + Vector3(2.0, 2.0, 1.5))
			if time < 0.0:
				continue
			if nearest == null or time < nearest_time or (is_equal_approx(time, nearest_time) and str(wall.get("plot_id")) < str(nearest.get("plot_id"))):
				nearest = wall
				nearest_time = time
		if nearest != null:
			return nearest
		start = end
	return null
