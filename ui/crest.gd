extends Control
## Original vector insignia; no texture imports or external assets.


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var center: Vector2 = size * 0.5
	var radius: float = minf(size.x, size.y) * 0.41
	var gold := Color("edc779")
	draw_circle(center, radius, Color("173e32"))
	draw_arc(center, radius, 0, TAU, 80, gold, 2.0, true)
	draw_arc(center, radius * 0.87, 0.3, PI - 0.3, 40, Color("55745c"), 1.0, true)
	var shield := PackedVector2Array([
		center + Vector2(-0.46, -0.53) * radius,
		center + Vector2(0.46, -0.53) * radius,
		center + Vector2(0.40, 0.18) * radius,
		center + Vector2(0, 0.66) * radius,
		center + Vector2(-0.40, 0.18) * radius,
	])
	draw_colored_polygon(shield, Color("b34639"))
	var outline: PackedVector2Array = shield.duplicate()
	outline.append(shield[0])
	draw_polyline(outline, gold, 3.0, true)
	var tower_width: float = radius * 0.40
	draw_rect(Rect2(center + Vector2(-tower_width * 0.5, -radius * 0.2), Vector2(tower_width, radius * 0.52)), Color("fff0c7"))
	for index in range(3):
		draw_rect(Rect2(center + Vector2(-tower_width * 0.6 + index * tower_width * 0.4, -radius * 0.36), Vector2(tower_width * 0.24, radius * 0.20)), Color("fff0c7"))
	draw_rect(Rect2(center + Vector2(-radius * 0.07, radius * 0.06), Vector2(radius * 0.14, radius * 0.26)), Color("b34639"))
