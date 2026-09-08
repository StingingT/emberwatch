extends Control
## Fixed, thumb-friendly joystick with independent touch ownership.

var direction: Vector2 = Vector2.ZERO
var _finger: int = -1
var _mouse_down: bool = false
var _knob: Vector2 = Vector2.ZERO
const GOLD := Color("f4cc73")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visibility_changed.connect(reset_input)
	resized.connect(queue_redraw)


func reset_input() -> void:
	_finger = -1
	_mouse_down = false
	direction = Vector2.ZERO
	_knob = Vector2.ZERO
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		if event.pressed and _finger == -1 and not _mouse_down and _contains(event.position):
			_finger = event.index
			_update_direction(event.position)
			get_viewport().set_input_as_handled()
		elif not event.pressed and event.index == _finger:
			reset_input()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == _finger:
		_update_direction(event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and _finger == -1 and _contains(event.position):
			_mouse_down = true
			_update_direction(event.position)
			get_viewport().set_input_as_handled()
		elif not event.pressed and _mouse_down:
			reset_input()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _mouse_down:
		_update_direction(event.position)
		get_viewport().set_input_as_handled()


func _contains(at: Vector2) -> bool:
	return get_global_rect().has_point(at)


func _update_direction(at: Vector2) -> void:
	var center: Vector2 = global_position + size * 0.5
	var radius: float = minf(size.x, size.y) * 0.32
	var raw: Vector2 = ((at - center) / maxf(radius, 1.0)).limit_length()
	if raw.length() < 0.12:
		direction = Vector2.ZERO
	else:
		direction = raw.normalized() * ((raw.length() - 0.12) / 0.88)
	_knob = raw * radius
	queue_redraw()


func _draw() -> void:
	var center: Vector2 = size * 0.5
	var radius: float = minf(size.x, size.y) * 0.44
	var active: bool = _finger != -1 or _mouse_down
	draw_circle(center + Vector2(0, 5), radius, Color(0.02, 0.08, 0.06, 0.16))
	draw_circle(center, radius, Color(0.04, 0.16, 0.12, 0.63 if active else 0.48))
	draw_arc(center, radius, 0, TAU, 64, Color(0.96, 0.85, 0.59, 0.55), 2.0, true)
	draw_arc(center, radius * 0.62, 0, TAU, 48, Color(1, 0.95, 0.8, 0.12), 1.5, true)
	for axis in [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]:
		draw_line(center + axis * radius * 0.76, center + axis * radius * 0.86, Color(1, 0.95, 0.8, 0.45), 3.0, true)
	draw_circle(center + _knob + Vector2(0, 4), radius * 0.36, Color(0.0, 0.05, 0.03, 0.28))
	draw_circle(center + _knob, radius * 0.36, GOLD if active else Color("ead9aa"))
	draw_arc(center + _knob, radius * 0.36, PI, TAU, 28, Color("fff2c9"), 2.0, true)
