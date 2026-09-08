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
	if not game.is_playing():
		return
	if hits.size() >= MAX_HITS:
		hits.pop_front()
	hits.append({"at": at + Vector3(0, 0.9, 0), "age": 0.0, "lethal": lethal})
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
		if float(entries[index]["age"]) >= lifetime:
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
		var progress: float = float(entry["age"]) / 0.24
		var lethal: bool = entry["lethal"]
		var color: Color = GOLD if lethal else Color("fff7db")
		color.a = 1.0 - progress
		var radius: float = lerpf(5.0, 25.0 if lethal else 17.0, progress)
		for ray: int in range(6):
			var direction: Vector2 = Vector2.from_angle(TAU * float(ray) / 6.0 + 0.25)
			draw_line(center + direction * radius * 0.5, center + direction * radius, color, 3.0, true)
	for entry: Dictionary in pickups:
		var at: Vector3 = entry["at"] + Vector3(0, 1.7, 0)
		if camera.is_position_behind(at):
			continue
		var center: Vector2 = camera.unproject_position(at) - Vector2(0, float(entry["age"]) * 42.0)
		if not view_rect.has_point(center):
			continue
		var label: String = "+%d gold" % int(entry["amount"])
		var width: float = _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 25).x
		var alpha: float = clampf((0.95 - float(entry["age"])) / 0.3, 0.0, 1.0)
		var origin: Vector2 = center - Vector2(width * 0.5, 0)
		draw_string_outline(_font, origin, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 25, 5, Color(OUTLINE, alpha))
		draw_string(_font, origin, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 25, Color(GOLD, alpha))
