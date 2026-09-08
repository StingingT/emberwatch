extends Button
## Native multi-touch button. A second finger can purchase while the stick is held.

var _finger: int = -1
var _mouse_down: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	toggle_mode = true
	visibility_changed.connect(reset_touch)


func reset_touch() -> void:
	_finger = -1
	_mouse_down = false
	set_pressed_no_signal(false)


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or disabled:
		reset_touch()
		return
	if event is InputEventScreenTouch:
		if event.pressed and _finger == -1 and get_global_rect().has_point(event.position):
			_finger = event.index
			set_pressed_no_signal(true)
			get_viewport().set_input_as_handled()
		elif not event.pressed and event.index == _finger:
			var activate: bool = get_global_rect().has_point(event.position) and not event.canceled
			reset_touch()
			get_viewport().set_input_as_handled()
			if activate:
				pressed.emit()
	elif event is InputEventScreenDrag and event.index == _finger:
		set_pressed_no_signal(get_global_rect().has_point(event.position))
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and get_global_rect().has_point(event.position):
			_mouse_down = true
			set_pressed_no_signal(true)
			get_viewport().set_input_as_handled()
		elif not event.pressed and _mouse_down:
			var activate: bool = get_global_rect().has_point(event.position)
			reset_touch()
			get_viewport().set_input_as_handled()
			if activate:
				pressed.emit()
	elif event is InputEventMouseMotion and _mouse_down:
		set_pressed_no_signal(get_global_rect().has_point(event.position))
		get_viewport().set_input_as_handled()
