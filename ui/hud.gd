class_name GameHUD
extends CanvasLayer
## Presentation only. The composition root remains the authority for run state.

signal play_requested
signal restart_requested
signal menu_requested
signal pause_requested
signal resume_requested
signal build_requested(kind: String)
signal upgrade_requested
signal smith_requested(id: String)
signal ability_requested
signal sound_toggled(enabled: bool)

const TOUCH_BUTTON = preload("res://ui/touch_button.gd")
const TOUCH_STICK = preload("res://ui/touch_stick.gd")
const CREST = preload("res://ui/crest.gd")
const INK := Color("102c24")
const PANEL := Color("163a2f")
const CREAM := Color("fff1ce")
const MUTED := Color("b5c4ab")
const GOLD := Color("f2cd7a")
const RED := Color("b94d3e")

var _root: Control
var _game: Control
var _overlay: Control
var _overlay_card: Panel
var _overlay_card_size := Vector2(596, 850)
var _safe: Rect2
var _stick: Control
var _keep_panel: Panel
var _coin_panel: Panel
var _hero_panel: Panel
var _wave_panel: Panel
var _context_panel: Panel
var _keep_label: Label
var _coins_label: Label
var _hero_label: Label
var _xp_label: Label
var _wave_label: Label
var _wave_detail: Label
var _threat: Label
var _context_title: Label
var _context_subtitle: Label
var _keep_bar: ProgressBar
var _xp_bar: ProgressBar
var _wave_bar: ProgressBar
var _pause_button: Button
var _ability_button: Button
var _upgrade_button: Button
var _movement_hint: Label
var _ability_hint: Label
var _toast_panel: Panel
var _toast_label: Label
var _toast_remaining: float = 0.0
var _option_buttons: Array[Button] = []
var _smith_buttons: Array[Button] = []
var _option_ids: Array[String] = []
var _smith_ids: Array[String] = []
var _context: Dictionary = {}
var _context_selection_id: String = ""
var _state: Dictionary = {}
var _sound_enabled: bool = true
var _playing_ui: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	_root = _control(self)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_game = _control(_root)
	_game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_game_ui()
	_overlay = _control(_root)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	get_viewport().size_changed.connect(_layout)
	_layout()
	show_title()


func _process(delta: float) -> void:
	if _toast_remaining > 0.0:
		_toast_remaining = maxf(0.0, _toast_remaining - delta)
		_toast_panel.modulate.a = minf(1.0, _toast_remaining / 0.35)
		_toast_panel.visible = _playing_ui and _toast_remaining > 0.0


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		reset_input()
	elif what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		if is_instance_valid(_root):
			call_deferred("_layout")


func movement_vector() -> Vector2:
	if not _playing_ui or not is_instance_valid(_stick):
		return Vector2.ZERO
	return _stick.direction


func reset_input() -> void:
	if is_instance_valid(_stick):
		_stick.reset_input()
	# Overlay buttons are created dynamically and also own native touch indices.
	# An interruption may omit their release event, so reset every live UI button.
	if is_instance_valid(_root):
		for button: Node in _root.find_children("*", "Button", true, false):
			if button.has_method("reset_touch"):
				button.call("reset_touch")


func show_title() -> void:
	_show_overlay("title")
	var crest: Control = CREST.new()
	_overlay_card.add_child(crest)
	_rect(crest, 226, 18, 144, 144)
	_center_label(_overlay_card, "THE LAST LIGHT NEEDS YOU", 18, 175, 30, GOLD)
	_center_label(_overlay_card, "EMBERWATCH", 61, 219, 76, CREAM)
	_center_label(_overlay_card, "Defend the last light", 27, 301, 44, MUTED)
	_rule(_overlay_card, 213, 366, 170)
	_center_label(_overlay_card, "A bow. A handful of coins.\nA kingdom worth defending.", 25, 398, 80, CREAM)
	_instruction(510, "01", "MOVE & FIRE", "Drag the stick. Your archer aims for you.")
	_instruction(597, "02", "COLLECT & BUILD", "Gather gold. Buy defenses at nearby plots.")
	var play := _button(_overlay_card, "DEFEND THE KEEP", 28, true)
	_rect(play, 46, 705, 504, 78)
	play.pressed.connect(func() -> void: play_requested.emit())
	_center_label(_overlay_card, "Portrait play  /  WASD + Space on desktop", 17, 799, 28, MUTED)
	_layout_overlay()


func show_game() -> void:
	reset_input()
	_playing_ui = true
	_game.show()
	_overlay.hide()
	_toast_panel.visible = _toast_remaining > 0.0
	show_context(_context)


func show_pause() -> void:
	_show_overlay("pause")
	_overlay_card_size = Vector2(596, 658)
	_center_label(_overlay_card, "TAKE A BREATH", 18, 43, 32, GOLD)
	_center_label(_overlay_card, "Watch paused", 45, 94, 66, CREAM)
	_center_label(_overlay_card, "Your defenses will wait for you.", 23, 176, 44, MUTED)
	var resume := _button(_overlay_card, "RESUME", 28, true)
	_rect(resume, 46, 256, 504, 74)
	resume.pressed.connect(func() -> void: resume_requested.emit())
	var retry := _button(_overlay_card, "Restart this defense", 25)
	_rect(retry, 46, 349, 504, 68)
	retry.pressed.connect(func() -> void: restart_requested.emit())
	var sound := _button(_overlay_card, "Sound: ON" if _sound_enabled else "Sound: OFF", 25)
	_rect(sound, 46, 435, 504, 68)
	sound.pressed.connect(func() -> void:
		_sound_enabled = not _sound_enabled
		sound.text = "Sound: ON" if _sound_enabled else "Sound: OFF"
		sound_toggled.emit(_sound_enabled)
	)
	var menu := _button(_overlay_card, "Back to title", 23)
	_rect(menu, 46, 532, 504, 68)
	menu.pressed.connect(func() -> void: menu_requested.emit())
	_layout_overlay()


func show_result(won: bool, summary: Dictionary) -> void:
	_show_overlay("result")
	_overlay_card_size = Vector2(596, 764)
	var crest: Control = CREST.new()
	_overlay_card.add_child(crest)
	_rect(crest, 243, 25, 110, 110)
	_center_label(_overlay_card, "THE LIGHT ENDURES" if won else "THE WATCH WILL RISE AGAIN", 18, 154, 28, GOLD)
	_center_label(_overlay_card, "Keep defended" if won else "Keep overrun", 45, 201, 65, CREAM)
	_center_label(_overlay_card, "A small kingdom. A mighty stand." if won else "Rebuild. Reposition. Return stronger.", 22, 279, 54, MUTED)
	_rule(_overlay_card, 55, 359, 486)
	_result_stat(390, "Waves", "%d / %d" % [int(summary.get("wave", 0)), int(summary.get("total_waves", 0))])
	_result_stat(445, "Goblins defeated", str(summary.get("kills", 0)))
	_result_stat(500, "Gold collected", str(summary.get("coins", 0)))
	var retry := _button(_overlay_card, "DEFEND AGAIN" if won else "TRY AGAIN", 28, true)
	_rect(retry, 46, 585, 504, 76)
	retry.pressed.connect(func() -> void: restart_requested.emit())
	var menu := _button(_overlay_card, "Back to title", 23)
	_rect(menu, 46, 680, 504, 56)
	menu.pressed.connect(func() -> void: menu_requested.emit())
	_layout_overlay()


func update_state(state: Dictionary) -> void:
	_state = state
	_coins_label.text = str(state.get("coins", 0))
	var health: float = float(state.get("keep_health", 0.0))
	var maximum: float = maxf(1.0, float(state.get("keep_max", 1.0)))
	_keep_bar.value = 100.0 * health / maximum
	_keep_label.text = "KEEP  %d / %d" % [ceili(health), int(maximum)]
	_keep_bar.add_theme_stylebox_override("fill", _bar_style(Color("c9654c") if health / maximum < 0.3 else Color("9cbc6c")))
	_hero_label.text = "ARCHER  ·  LV %d" % int(state.get("hero_level", 1))
	var xp: int = int(state.get("xp", 0))
	var next_xp: int = int(state.get("next_xp", 1))
	_xp_label.text = "MAX LEVEL" if next_xp <= 0 else "%d / %d XP" % [xp, next_xp]
	_xp_bar.value = 100.0 if next_xp <= 0 else 100.0 * float(xp) / next_xp
	_wave_label.text = "WAVE %d / %d" % [int(state.get("wave", 0)), int(state.get("total_waves", 1))]
	var wave_active: bool = bool(state.get("wave_active", false))
	var wave_remaining: int = maxi(0, int(state.get("wave_remaining", 0)))
	var wave_total: int = maxi(0, int(state.get("wave_total", 0)))
	if wave_active:
		_wave_detail.text = "%d %s remaining" % [wave_remaining, "enemy" if wave_remaining == 1 else "enemies"]
	else:
		_wave_detail.text = str(state.get("wave_text", "Guard the road"))
	_wave_bar.visible = wave_active and wave_total > 0
	_wave_bar.value = clampf(100.0 * (1.0 - float(wave_remaining) / wave_total), 0.0, 100.0) if wave_total > 0 else 0.0
	_threat.text = str(state.get("threat_text", ""))
	_threat.visible = not _threat.text.is_empty()
	var unlocked: bool = bool(state.get("ability_unlocked", false))
	var cooldown: float = float(state.get("ability_cooldown", 0.0))
	_ability_button.disabled = not unlocked or cooldown > 0.0
	if not unlocked:
		_ability_button.text = "VOLLEY\nLevel 2"
		_ability_hint.text = "Hero kills earn XP"
	elif cooldown > 0.0:
		_ability_button.text = "VOLLEY\n%ds" % ceili(cooldown)
		_ability_hint.text = "Recharging"
	else:
		_ability_button.text = "VOLLEY\nREADY"
		_ability_hint.text = "Tap  /  Space"


func show_context(context: Dictionary) -> void:
	var selection_id: String = str(context.get("selection_id", ""))
	if selection_id != _context_selection_id:
		# Changing nearby plots invalidates a held purchase, but movement continues.
		for button: Button in _option_buttons + _smith_buttons:
			button.call("reset_touch")
		if is_instance_valid(_upgrade_button):
			_upgrade_button.call("reset_touch")
	_context_selection_id = selection_id
	_context = context
	if not is_instance_valid(_context_panel):
		return
	_context_panel.visible = _playing_ui and not context.is_empty()
	if context.is_empty():
		for button in _smith_buttons:
			button.hide()
		return
	_context_title.text = str(context.get("title", "Build a defense"))
	_context_subtitle.text = str(context.get("subtitle", "Spend gold while the battle continues"))
	var options: Array = context.get("options", [])
	var is_smith: bool = not options.is_empty() and str(options[0].get("id", "")) in ["ranged", "haste", "fortify"]
	_option_ids.clear()
	_smith_ids.clear()
	for index in range(3):
		_option_buttons[index].visible = _playing_ui and not is_smith and index < options.size()
		_smith_buttons[index].visible = _playing_ui and is_smith and index < options.size()
		if index >= options.size():
			continue
		var option: Dictionary = options[index]
		var id: String = str(option.get("id", ""))
		var label: String = str(option.get("label", id.capitalize()))
		var cost: int = int(option.get("cost", 0))
		var button: Button = _smith_buttons[index] if is_smith else _option_buttons[index]
		button.text = "%s\n%d gold" % [label, cost]
		if is_smith:
			button.text = "%s\n%s\n%d gold" % [label, _wrap_text(str(option.get("description", "")), 16), cost]
		button.disabled = not bool(option.get("enabled", true))
		button.tooltip_text = str(option.get("description", ""))
		if is_smith:
			_smith_ids.append(id)
		else:
			_option_ids.append(id)
	var upgrade_cost: int = int(context.get("upgrade_cost", -1))
	_upgrade_button.visible = upgrade_cost >= 0
	_upgrade_button.disabled = not bool(context.get("can_upgrade", false))
	_upgrade_button.text = "UPGRADE TO %d  ·  %d gold" % [int(context.get("tier", 1)) + 1, upgrade_cost]
	_layout_context()


func toast(message: String, tone: String = "info") -> void:
	_toast_label.text = message
	_toast_label.add_theme_color_override("font_color", Color("ffb59c") if tone in ["danger", "error", "warning"] else GOLD)
	_toast_remaining = 2.7
	_toast_panel.modulate.a = 1.0
	_toast_panel.visible = _playing_ui


func _build_game_ui() -> void:
	_keep_panel = _panel(_game)
	_keep_label = _label(_keep_panel, "KEEP", 21, CREAM)
	_rect(_keep_label, 18, 13, 278, 30)
	_keep_bar = _progress(_keep_panel, Color("9cbc6c"))
	_rect(_keep_bar, 18, 53, 274, 13)
	_coin_panel = _panel(_game)
	var gold_label := _label(_coin_panel, "GOLD", 16, GOLD)
	_rect(gold_label, 17, 10, 138, 23)
	_coins_label = _label(_coin_panel, "0", 33, CREAM)
	_rect(_coins_label, 17, 30, 150, 42)
	_pause_button = _button(_game, "II", 31)
	_pause_button.pressed.connect(func() -> void: pause_requested.emit())
	_hero_panel = _panel(_game, Color(0.055, 0.15, 0.115, 0.88))
	_hero_label = _label(_hero_panel, "ARCHER  ·  LV 1", 18, CREAM)
	_xp_label = _label(_hero_panel, "0 / 10 XP", 17, MUTED)
	_xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_xp_bar = _progress(_hero_panel, GOLD)
	_wave_panel = _panel(_game, Color(0.055, 0.15, 0.115, 0.9))
	_wave_label = _label(_wave_panel, "WAVE 1 / 5", 23, GOLD)
	_wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wave_detail = _label(_wave_panel, "Guard the road", 18, CREAM)
	_wave_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wave_bar = _progress(_wave_panel, GOLD)
	_wave_bar.hide()
	_threat = _label(_game, "", 20, Color("ffd1ac"))
	_threat.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_threat.add_theme_color_override("font_shadow_color", INK)
	_threat.add_theme_constant_override("shadow_offset_x", 1)
	_threat.add_theme_constant_override("shadow_offset_y", 2)
	_stick = TOUCH_STICK.new()
	_game.add_child(_stick)
	_movement_hint = _label(_game, "MOVE", 17, CREAM)
	_movement_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_movement_hint.add_theme_color_override("font_shadow_color", INK)
	_movement_hint.add_theme_constant_override("shadow_offset_y", 2)
	_ability_button = _button(_game, "VOLLEY\nLevel 2", 27, true)
	_ability_button.pressed.connect(func() -> void: ability_requested.emit())
	_ability_hint = _label(_game, "Hero kills earn XP", 17, CREAM)
	_ability_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ability_hint.add_theme_color_override("font_shadow_color", INK)
	_ability_hint.add_theme_constant_override("shadow_offset_y", 2)
	_context_panel = _panel(_game, Color(0.05, 0.145, 0.11, 0.96))
	_context_title = _label(_context_panel, "", 25, CREAM)
	_context_subtitle = _label(_context_panel, "", 18, MUTED)
	for index in range(3):
		var option := _button(_context_panel, "", 22)
		option.pressed.connect(_on_option_pressed.bind(index))
		_option_buttons.append(option)
		var smith := _button(_game, "", 20, true)
		smith.pressed.connect(_on_smith_pressed.bind(index))
		smith.hide()
		_smith_buttons.append(smith)
	_upgrade_button = _button(_context_panel, "UPGRADE", 23, true)
	_upgrade_button.pressed.connect(func() -> void: upgrade_requested.emit())
	_context_panel.hide()
	_toast_panel = _panel(_game, Color(0.04, 0.11, 0.085, 0.94))
	_toast_label = _label(_toast_panel, "", 23, GOLD)
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast_panel.hide()


func _layout() -> void:
	if not is_instance_valid(_root):
		return
	reset_input()
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var inset_left: float = 0.0
	var inset_top: float = 0.0
	var inset_right: float = 0.0
	var inset_bottom: float = 0.0
	# DisplayServer reports physical screen pixels, while controls use viewport units.
	if OS.has_feature("ios") or OS.has_feature("android"):
		var display_safe: Rect2i = DisplayServer.get_display_safe_area()
		var physical: Vector2i = DisplayServer.screen_get_size()
		if physical.x > 0 and physical.y > 0 and display_safe.has_area():
			var ratio: Vector2 = viewport_size / Vector2(physical)
			inset_left = maxf(0, display_safe.position.x) * ratio.x
			inset_top = maxf(0, display_safe.position.y) * ratio.y
			inset_right = maxf(0, physical.x - display_safe.end.x) * ratio.x
			inset_bottom = maxf(0, physical.y - display_safe.end.y) * ratio.y
	_safe = Rect2(Vector2(inset_left + 20, inset_top + 18), viewport_size - Vector2(inset_left + inset_right + 40, inset_top + inset_bottom + 36))
	var w: float = _safe.size.x
	var h: float = _safe.size.y
	var left: float = _safe.position.x
	var top: float = _safe.position.y
	var bottom: float = _safe.end.y
	var keep_width: float = w * 0.49
	var pause_width: float = 70.0
	var coin_width: float = w - keep_width - pause_width - 20
	_rect(_keep_panel, left, top, keep_width, 84)
	_rect(_keep_label, 16, 12, keep_width - 28, 30)
	_rect(_keep_bar, 16, 53, keep_width - 32, 13)
	_rect(_coin_panel, left + keep_width + 10, top, coin_width, 84)
	_rect(_pause_button, _safe.end.x - pause_width, top, pause_width, 84)
	_rect(_hero_panel, left, top + 95, w, 57)
	_rect(_hero_label, 16, 6, w * 0.6, 28)
	_rect(_xp_label, w * 0.6, 6, w * 0.4 - 16, 28)
	_rect(_xp_bar, 16, 40, w - 32, 5)
	var wave_width: float = minf(386, w)
	_rect(_wave_panel, left + (w - wave_width) * 0.5, top + 165, wave_width, 75)
	_rect(_wave_label, 8, 5, wave_width - 16, 30)
	_rect(_wave_detail, 8, 35, wave_width - 16, 25)
	_rect(_wave_bar, 20, 64, wave_width - 40, 6)
	_rect(_threat, left, top + 247, w, 32)
	var compact: bool = h < 850
	var stick_size: float = 170 if compact else 192
	_rect(_stick, left + 4, bottom - stick_size - 31, stick_size, stick_size)
	_rect(_movement_hint, left, bottom - 30, stick_size + 8, 25)
	var ability_size: float = 132 if compact else 150
	_rect(_ability_button, _safe.end.x - ability_size - 10, bottom - ability_size - 44, ability_size, ability_size)
	_rect(_ability_hint, _safe.end.x - 198, bottom - 30, 198, 25)
	var context_width: float = minf(w, 660)
	var context_height: float = 174
	_rect(_context_panel, left + (w - context_width) * 0.5, bottom - stick_size - context_height - 46, context_width, context_height)
	_rect(_context_title, 18, 11, context_width - 36, 34)
	_rect(_context_subtitle, 18, 47, context_width - 36, 29)
	_context_subtitle.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var toast_width: float = minf(w - 24, 600)
	_rect(_toast_panel, left + (w - toast_width) * 0.5, top + 289, toast_width, 66)
	_rect(_toast_label, 14, 7, toast_width - 28, 52)
	_layout_context()
	_layout_overlay()


func _layout_context() -> void:
	if not is_instance_valid(_context_panel) or _context.is_empty():
		return
	var count: int = _option_ids.size()
	var width: float = _context_panel.size.x - 36
	var has_upgrade: bool = _upgrade_button.visible
	if count > 0:
		var each: float = (width - (count - 1) * 10) / count
		for index in range(count):
			_rect(_option_buttons[index], 18 + index * (each + 10), 88, each, 69)
	if has_upgrade:
		_rect(_upgrade_button, 18, 88, width, 69)
	# Smith purchases remain next to their world building, within the clear play area.
	var smith_count: int = _smith_ids.size()
	if smith_count > 0:
		var screen_at: Vector2 = _context.get("screen_position", _safe.get_center())
		var gap: float = 10
		var bulb_width: float = minf(180, (_safe.size.x - gap * (smith_count - 1)) / smith_count)
		var bulb_height: float = 132
		var row_width: float = bulb_width * smith_count + gap * (smith_count - 1)
		var x: float = clampf(screen_at.x - row_width * 0.5, _safe.position.x, _safe.end.x - row_width)
		var min_y: float = _safe.position.y + 367
		var max_y: float = maxf(min_y, _context_panel.position.y - bulb_height - 15)
		var y: float = clampf(screen_at.y - bulb_height - 35, min_y, max_y)
		for index in range(smith_count):
			_rect(_smith_buttons[index], x + index * (bulb_width + gap), y, bulb_width, bulb_height)


func _show_overlay(_mode: String) -> void:
	reset_input()
	_playing_ui = false
	_game.hide()
	_overlay.show()
	for child in _overlay.get_children():
		if child is CanvasItem:
			child.hide()
		child.queue_free()
	var shade := ColorRect.new()
	shade.color = Color(0.025, 0.085, 0.065, 0.82)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay_card_size = Vector2(596, 850)
	_overlay_card = _panel(_overlay, Color("102f25"))
	_overlay_card.add_theme_stylebox_override("panel", _style(Color("102f25"), Color("6a7550"), 28, 2))


func _layout_overlay() -> void:
	if not is_instance_valid(_overlay_card):
		return
	var fit: float = minf(1.0, minf((_safe.size.x - 12) / _overlay_card_size.x, (_safe.size.y - 20) / _overlay_card_size.y))
	_overlay_card.size = _overlay_card_size
	_overlay_card.scale = Vector2.ONE * fit
	_overlay_card.position = _safe.get_center() - _overlay_card_size * fit * 0.5


func _on_option_pressed(index: int) -> void:
	if index < _option_ids.size():
		build_requested.emit(_option_ids[index])


func _wrap_text(text: String, max_characters: int) -> String:
	var output: String = ""
	var line_length: int = 0
	for word in text.split(" ", false):
		if line_length > 0 and line_length + word.length() + 1 > max_characters:
			output += "\n"
			line_length = 0
		elif line_length > 0:
			output += " "
			line_length += 1
		output += word
		line_length += word.length()
	return output


func _on_smith_pressed(index: int) -> void:
	if index < _smith_ids.size():
		smith_requested.emit(_smith_ids[index])


func _instruction(y: float, number: String, heading: String, body: String) -> void:
	var badge := _panel(_overlay_card, Color("234c39"))
	_rect(badge, 48, y, 48, 48)
	var digit := _label(badge, number, 21, GOLD)
	digit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rect(digit, 0, 6, 48, 34)
	var title := _label(_overlay_card, heading, 20, GOLD)
	_rect(title, 115, y - 1, 433, 31)
	var text := _label(_overlay_card, body, 18, MUTED)
	_rect(text, 115, y + 33, 433, 35)


func _result_stat(y: float, title: String, value: String) -> void:
	var label := _label(_overlay_card, title, 24, MUTED)
	_rect(label, 56, y, 352, 37)
	var amount := _label(_overlay_card, value, 26, CREAM)
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_rect(amount, 376, y, 164, 37)


func _center_label(parent: Node, text: String, font_size: int, y: float, height: float, color: Color) -> Label:
	var label := _label(parent, text, font_size, color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_rect(label, 20, y, 556, height)
	return label


func _rule(parent: Node, x: float, y: float, width: float) -> void:
	var line := ColorRect.new()
	line.color = Color("5c7652")
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(line)
	_rect(line, x, y, width, 1)


func _control(parent: Node) -> Control:
	var control := Control.new()
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(control)
	return control


func _panel(parent: Node, color: Color = PANEL) -> Panel:
	var panel := Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _style(color, Color(0.68, 0.73, 0.46, 0.33), 18))
	parent.add_child(panel)
	return panel


func _label(parent: Node, text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _button(parent: Node, text: String, font_size: int = 24, primary: bool = false) -> Button:
	var button: Button = TOUCH_BUTTON.new()
	button.text = text
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", INK if primary else CREAM)
	button.add_theme_color_override("font_hover_color", INK if primary else CREAM)
	button.add_theme_color_override("font_pressed_color", INK if primary else CREAM)
	button.add_theme_color_override("font_disabled_color", Color("9baf9a"))
	button.add_theme_stylebox_override("normal", _style(GOLD if primary else Color("285240"), Color("e5c97d") if primary else Color("6f8560"), 16, 1))
	button.add_theme_stylebox_override("hover", _style(Color("ffdfa0") if primary else Color("34634b"), GOLD, 16, 2))
	button.add_theme_stylebox_override("pressed", _style(Color("d0a558") if primary else Color("193f30"), CREAM, 16, 2))
	button.add_theme_stylebox_override("disabled", _style(Color(0.1, 0.22, 0.17, 0.92), Color("476249"), 16, 1))
	parent.add_child(button)
	return button


func _progress(parent: Node, color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.show_percentage = false
	bar.max_value = 100.0
	bar.add_theme_stylebox_override("background", _bar_style(Color("071d16")))
	bar.add_theme_stylebox_override("fill", _bar_style(color))
	parent.add_child(bar)
	return bar


func _bar_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(8)
	return style


func _style(color: Color, border: Color, radius: int, border_width: int = 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_corner_radius_all(radius)
	style.set_border_width_all(border_width)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	style.shadow_color = Color(0, 0.04, 0.025, 0.24)
	style.shadow_size = 5
	style.shadow_offset = Vector2(0, 4)
	return style


func _rect(control: Control, x: float, y: float, width: float, height: float) -> void:
	control.position = Vector2(x, y)
	control.size = Vector2(maxf(1, width), maxf(1, height))
