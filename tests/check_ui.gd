extends SceneTree
## Real native input events against the production HUD; no game-state mock UI.
## Run: godot --headless --path . --script tests/check_ui.gd

const HUD = preload("res://ui/hud.gd")
var hud: CanvasLayer
var failures: int = 0
var checks: int = 0
var counters := {"play": 0, "build": 0, "upgrade": 0, "smith": 0, "ability": 0, "retry": 0, "resume": 0}


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", message)


func _touch(index: int, at: Vector2, down: bool, canceled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = at
	event.pressed = down
	event.canceled = canceled
	root.push_input(event, true)
	await process_frame


func _drag(index: int, at: Vector2, relative: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = at
	event.relative = relative
	root.push_input(event, true)
	await process_frame


func _tap(index: int, button: Button) -> void:
	var at: Vector2 = button.get_global_rect().get_center()
	await _touch(index, at, true)
	await _touch(index, at, false)


func _overlay_button(text: String) -> Button:
	for child in hud._overlay_card.get_children():
		if child is Button and child.text == text:
			return child
	return null


func _run() -> void:
	root.content_scale_size = Vector2i(720, 1280)
	root.size = Vector2i(720, 1280)
	hud = HUD.new()
	root.add_child(hud)
	await process_frame
	hud.play_requested.connect(func() -> void: counters.play += 1)
	hud.build_requested.connect(func(_kind: String) -> void: counters.build += 1)
	hud.upgrade_requested.connect(func() -> void: counters.upgrade += 1)
	hud.smith_requested.connect(func(_id: String) -> void: counters.smith += 1)
	hud.ability_requested.connect(func() -> void: counters.ability += 1)
	hud.restart_requested.connect(func() -> void: counters.retry += 1)
	hud.resume_requested.connect(func() -> void: counters.resume += 1)
	await _tap(0, _overlay_button("DEFEND THE KEEP"))
	_check(counters.play == 1, "Title Play accepts a native touchscreen tap")
	# Interrupt while the second finger owns a button; deliberately omit its release.
	var title_play: Button = _overlay_button("DEFEND THE KEEP")
	await _touch(1, title_play.get_global_rect().get_center(), true)
	hud.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await process_frame
	await _tap(0, title_play)
	_check(counters.play == 2, "Title Play accepts finger zero after an interrupted finger-one press")
	_check(hud.movement_vector() == Vector2.ZERO, "Title interaction cannot move the hero")
	hud.show_game()
	hud.update_state({"coins": 50, "keep_health": 90, "keep_max": 100, "wave": 1, "total_waves": 3, "hero_level": 2, "xp": 1, "next_xp": 10, "ability_unlocked": true, "ability_cooldown": 0})
	var context := {"selection_id": "bend", "title": "Tower plot", "options": [{"id": "tower", "label": "Archer Tower", "cost": 20, "enabled": true}], "upgrade_cost": -1}
	hud.show_context(context)
	await process_frame
	var stick_center: Vector2 = hud._stick.get_global_rect().get_center()
	await _touch(0, stick_center + Vector2(50, 0), true)
	_check(hud.movement_vector().x > 0.3, "Native touch drives the joystick")
	await _drag(0, stick_center + Vector2(0, -55), Vector2(-50, -55))
	_check(hud.movement_vector().y < -0.3 and absf(hud.movement_vector().x) < 0.1, "Native drag changes movement direction")
	# Wave refreshes must show all remaining enemies, including pending spawns.
	var wave_state: Dictionary = hud._state.duplicate()
	wave_state.merge({"wave_active": true, "wave_total": 20, "wave_remaining": 10}, true)
	hud.update_state(wave_state)
	_check(hud._wave_detail.text == "10 enemies remaining", "Active wave exposes the remaining enemy count")
	_check(hud._wave_bar.visible and is_equal_approx(hud._wave_bar.value, 50.0), "Wave progress fills as enemies are defeated")
	wave_state["wave_remaining"] = 20
	hud.update_state(wave_state)
	_check(is_zero_approx(hud._wave_bar.value), "New wave starts with empty progress while spawns remain")
	wave_state["wave_remaining"] = 0
	hud.update_state(wave_state)
	_check(is_equal_approx(hud._wave_bar.value, 100.0), "Defeating the entire wave completes its progress")
	wave_state.merge({"wave_active": false, "wave_text": "Next wave in 4s"}, true)
	hud.update_state(wave_state)
	_check(hud._wave_detail.text == "Next wave in 4s" and not hud._wave_bar.visible, "Intermission restores the live countdown")
	_check(hud._wave_panel.get_global_rect().encloses(hud._wave_bar.get_global_rect()), "Wave progress fits inside the existing panel")
	var buy_at: Vector2 = hud._option_buttons[0].get_global_rect().get_center()
	await _touch(1, buy_at, true)
	var price_refresh: Dictionary = context.duplicate(true)
	price_refresh["options"][0]["cost"] = 25
	hud.show_context(price_refresh)
	await _touch(1, buy_at, false)
	_check(counters.build == 1, "Second finger purchases after a same-plot price refresh")
	_check(hud.movement_vector().y < -0.3, "Purchasing does not release the movement finger")
	await _tap(1, hud._ability_button)
	_check(counters.ability == 1, "Volley accepts a second native touch while moving")
	_check(hud.movement_vector().y < -0.3, "Volley preserves movement finger ownership")
	# Nearest-plot changes must cancel purchase intent without canceling movement.
	await _touch(1, buy_at, true)
	hud.show_context({"selection_id": "choke", "title": "Wall plot", "options": [{"id": "wall", "label": "Barricade", "cost": 30, "enabled": true}], "upgrade_cost": -1})
	await _touch(1, buy_at, false)
	_check(counters.build == 1, "A held tower purchase cannot change into a wall purchase")
	_check(hud.movement_vector().y < -0.3, "Changed-kind selection preserves the movement finger")
	hud.show_context(context)
	await _touch(1, buy_at, true)
	var same_kind: Dictionary = context.duplicate(true)
	same_kind["selection_id"] = "north"
	hud.show_context(same_kind)
	await _touch(1, buy_at, false)
	_check(counters.build == 1, "A held purchase cannot redirect to another plot of the same kind")
	await _tap(1, hud._option_buttons[0])
	_check(counters.build == 2, "A fresh touch can purchase the newly selected plot")
	await _touch(1, buy_at, true)
	hud.show_context({})
	hud.show_context(context)
	await _touch(1, buy_at, false)
	_check(counters.build == 2, "Hiding then showing a selection cannot revive an old purchase touch")
	var upgrade_context := {"selection_id": "bend", "title": "Archer Tower", "options": [], "tier": 1, "upgrade_cost": 65, "can_upgrade": true}
	hud.show_context(upgrade_context)
	var upgrade_at: Vector2 = hud._upgrade_button.get_global_rect().get_center()
	await _touch(1, upgrade_at, true)
	upgrade_context["selection_id"] = "north"
	hud.show_context(upgrade_context)
	await _touch(1, upgrade_at, false)
	_check(counters.upgrade == 0, "A held upgrade cannot redirect to a different built tower")
	_check(hud.movement_vector().y < -0.3, "Selection cancellation leaves held movement active")
	hud.show_context(context)
	await _touch(0, stick_center, false, true)
	_check(hud.movement_vector() == Vector2.ZERO, "Canceled joystick touch resets movement")
	await _touch(1, buy_at, true)
	await _touch(1, buy_at, false, true)
	_check(counters.build == 2, "Canceled purchase touch cannot buy a building")
	await _touch(0, stick_center + Vector2(50, 0), true)
	hud.show_pause()
	_check(hud.movement_vector() == Vector2.ZERO, "Pause resets captured fingers")
	await _touch(0, stick_center, false)
	await _tap(2, _overlay_button("RESUME"))
	_check(counters.resume == 1, "Pause Resume accepts native touch")
	var resume: Button = _overlay_button("RESUME")
	await _touch(1, resume.get_global_rect().get_center(), true)
	hud.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	await process_frame
	await _tap(0, resume)
	_check(counters.resume == 2, "Resume accepts finger zero after an interrupted finger-one press")
	hud.show_game()
	_check(hud.movement_vector() == Vector2.ZERO, "Resuming cannot restore stale movement")
	var smith_context := {"selection_id": "forge", "title": "Smith", "screen_position": Vector2(10, 15), "tier": 1, "upgrade_cost": 50, "can_upgrade": true, "options": [{"id": "ranged", "label": "Keen arrows", "description": "Towers +20% damage", "cost": 20, "enabled": true}, {"id": "haste", "label": "Quick strings", "description": "Towers fire 15% faster", "cost": 20, "enabled": true}, {"id": "fortify", "label": "Fortify", "description": "Walls & Keep +20% health", "cost": 20, "enabled": true}]}
	hud.show_context(smith_context)
	await process_frame
	for button in hud._smith_buttons:
		_check(hud._safe.encloses(button.get_global_rect()), "Smith purchase stays inside safe bounds")
		_check(button.text.contains("%") and button.text.contains("gold"), "Smith effect and cost are visibly labeled")
	var smith_at: Vector2 = hud._smith_buttons[1].get_global_rect().get_center()
	await _touch(2, smith_at, true)
	hud.show_context(smith_context)
	await _touch(2, smith_at, false)
	_check(counters.smith == 1, "Smith touch survives periodic context refresh")
	await _touch(2, smith_at, true)
	var different_smith: Dictionary = smith_context.duplicate(true)
	different_smith["selection_id"] = "quarry"
	hud.show_context(different_smith)
	await _touch(2, smith_at, false)
	_check(counters.smith == 1, "A held Smith purchase cannot retarget a different support plot")
	hud.show_context(smith_context)
	hud.update_state({"hero_level": 5, "next_xp": 0})
	_check(hud._xp_label.text == "MAX LEVEL" and is_equal_approx(hud._xp_bar.value, 100.0), "Maximum hero level has a full bar and MAX LEVEL label")
	# Resize through base portrait, taller phone, and a broader tablet viewport.
	for dimensions in [Vector2i(720, 1280), Vector2i(780, 1688), Vector2i(820, 1180)]:
		root.content_scale_size = dimensions
		root.size = dimensions
		await process_frame
		await process_frame
		hud._layout()
		_check(hud._safe.encloses(hud._stick.get_global_rect()), "Joystick remains in safe area after aspect resize")
		_check(hud._safe.encloses(hud._ability_button.get_global_rect()), "Ability stays in safe area after aspect resize")
		_check(hud._safe.encloses(hud._context_panel.get_global_rect()), "Build card stays in safe area after aspect resize")
		for button in hud._smith_buttons:
			_check(not button.get_global_rect().intersects(hud._context_panel.get_global_rect()), "Smith purchases avoid the build card after aspect resize")
	hud.show_result(true, {"kills": 15, "coins": 120, "wave": 3, "total_waves": 3})
	await process_frame
	await _tap(3, _overlay_button("DEFEND AGAIN"))
	_check(counters.retry == 1, "Result retry works through scaled overlay")
	var retry: Button = _overlay_button("DEFEND AGAIN")
	await _touch(1, retry.get_global_rect().get_center(), true)
	hud.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await process_frame
	await _tap(0, retry)
	_check(counters.retry == 2, "Retry accepts finger zero after an interrupted finger-one press")
	print("UI_CHECKS: %d checks, %d failures" % [checks, failures])
	hud.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
