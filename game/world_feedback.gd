class_name WorldFeedback
extends Node2D
## Short-lived world feedback drawn in one canvas, below the HUD.
const MAX_HITS: int = 32
const MAX_PICKUPS: int = 8
const GOLD := Color("ffdc80")
const OUTLINE := Color("24352b")

var game: Node3D
var camera: Camera3D
var hits: Array[Dictionary] = []
var pickups: Array[Dictionary] = []
var _font: Font

func setup(owner_game: Node3D, view: Camera3D) -> void:
	game = owner_game
	camera = view
	_font = ThemeDB.fallback_font

func hit(at: Vector3, lethal: bool) -> void:
	if not game.is_playing() or game.reduced_motion():
		return
	if hits.size() >= MAX_HITS:
		hits.pop_front()
	hits.append({"at": at + Vector3(0, 0.9, 0), "age": 0.0, "lethal": lethal})
	queue_redraw()

func construction(at: Vector3) -> void:
	if not game.is_playing() or game.reduced_motion():
		return
	if hits.size() >= MAX_HITS:
		hits.pop_front()
	hits.append({"at": at + Vector3(0, 0.4, 0), "age": 0.0, "lethal": false, "construction": true, "lifetime": 0.65})
	queue_redraw()

func pickup(at: Vector3, amount: int) -> void:
	if amount <= 0 or not game.is_playing():
		return
	# A cluster of simultaneous pickups reads as one total, not stacked labels.
	for entry: Dictionary in pickups:
		if float(entry["age"]) < 0.28 and (entry["at"] as Vector3).distance_squared_to(at) < 9.0:
			entry["amount"] += amount
			entry["at"] = at
			queue_redraw()
			return
	if pickups.size() >= MAX_PICKUPS:
		pickups.pop_front()
	pickups.append({"at": at, "age": 0.0, "amount": amount})
	queue_redraw()

func clear() -> void:
	hits.clear()
	pickups.clear()
	queue_redraw()

func _process(delta: float) -> void:
	var playing: bool = is_instance_valid(game) and game.is_playing()
	visible = playing
	if not playing:
		return
	var had_effects: bool = not hits.is_empty() or not pickups.is_empty()
	_age_entries(hits, delta, 0.24)
	_age_entries(pickups, delta, 0.95)
	if had_effects:
		queue_redraw()

func _age_entries(entries: Array[Dictionary], delta: float, lifetime: float) -> void:
	for index: int in range(entries.size() - 1, -1, -1):
		entries[index]["age"] += delta
		if float(entries[index]["age"]) >= float(entries[index].get("lifetime", lifetime)):
			entries.remove_at(index)

func _draw() -> void:
	if not is_instance_valid(camera) or not is_instance_valid(game) or not game.is_playing():
		return
	var view_rect: Rect2 = get_viewport_rect().grow(40.0)
	for entry: Dictionary in hits:
		var at: Vector3 = entry["at"]
		if camera.is_position_behind(at):
			continue
		var center: Vector2 = camera.unproject_position(at)
		if not view_rect.has_point(center):
			continue
		var progress: float = float(entry["age"]) / float(entry.get("lifetime", 0.24))
		if bool(entry.get("construction", false)):
			var radius: float = lerpf(15.0, 68.0, progress)
			var paint := Color(GOLD, 1.0 - progress)
			draw_arc(center, radius, 0, TAU, 32, paint, 3.0, true)
			for spark: int in range(8):
				var offset: Vector2 = Vector2.from_angle(float(spark) * TAU / 8) * radius
				offset.y -= sin(progress * PI) * 22.0
				draw_rect(Rect2(center + offset - Vector2.ONE * 3, Vector2.ONE * 6), paint)
			continue
		var lethal: bool = entry["lethal"]
		var color: Color = GOLD if lethal else Color("fff7db")
		color.a = 1.0 - progress
		var radius: float = lerpf(5.0, 25.0 if lethal else 17.0, progress)
		if lethal:
			draw_arc(center, radius * 0.75, 0, TAU, 24, color, 2.0, true)
			for shard: int in range(5):
				var outward: Vector2 = Vector2.from_angle(TAU * float(shard) / 5.0)
				var tip: Vector2 = center + outward * radius * 1.5
				var side: Vector2 = outward.orthogonal() * 3.0 * (1.0 - progress)
				draw_colored_polygon(PackedVector2Array([tip, tip - outward * 8 + side, tip - outward * 8 - side]), color)
		for ray: int in range(6):
			var direction: Vector2 = Vector2.from_angle(TAU * float(ray) / 6.0 + 0.25)
			draw_line(center + direction * radius * 0.5, center + direction * radius, color, 3.0, true)
	for entry: Dictionary in pickups:
		var at: Vector3 = entry["at"] + Vector3(0, 1.7, 0)
		if camera.is_position_behind(at):
			continue
		var rise: float = 0.0 if game.reduced_motion() else float(entry["age"]) * 42.0
		var center: Vector2 = camera.unproject_position(at) - Vector2(0, rise)
		if not view_rect.has_point(center):
			continue
		if not game.reduced_motion() and float(entry["age"]) < 0.45:
			var spread: float = float(entry["age"]) / 0.45
			for spark: int in range(4):
				var offset: Vector2 = Vector2.from_angle(float(spark) * TAU / 4.0 + 0.4) * lerpf(12, 36, spread)
				draw_circle(center + offset, 3.0 * (1.0 - spread), Color(GOLD, 1.0 - spread))
		var label: String = "+%d gold" % int(entry["amount"])
		var width: float = _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 25).x
		var alpha: float = clampf((0.95 - float(entry["age"])) / 0.3, 0.0, 1.0)
		var origin: Vector2 = center - Vector2(width * 0.5, 0)
		draw_string_outline(_font, origin, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 25, 5, Color(OUTLINE, alpha))
		draw_string(_font, origin, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 25, Color(GOLD, alpha))
