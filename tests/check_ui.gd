extends SceneTree
## Real native input events against the production HUD; no game-state mock UI.
## Run: godot --headless --path . --script tests/check_ui.gd

const HUD = preload("res://ui/hud.gd")
const CAMPAIGN = preload("res://game/campaign_data.gd")
var hud: CanvasLayer
var failures: int = 0
var checks: int = 0
var counters := {"play": 0, "build": 0, "upgrade": 0, "smith": 0, "ability": 0, "retry": 0, "resume": 0}
var campaign_signals: int = 0
var next_signals: int = 0
var continue_signals: int = 0
var mission_selections: Array[String] = []
var preference_changes: Array[Dictionary] = []
var legacy_sound_signals: int = 0


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


func _capture(name: String) -> void:
	if "--capture-ui" not in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless":
		return
	await process_frame
	await RenderingServer.frame_post_draw
	var result: Error = root.get_texture().get_image().save_png("res://artifacts/" + name + ".png")
	if result != OK:
		push_error("Could not save UI capture: " + name)
	print("UI_CAPTURE ", name, " status=", result)


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
	await _check_campaign_and_preferences()
	await _check_continue_defense()
	print("UI_CHECKS: %d checks, %d failures" % [checks, failures])
	hud.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)


func _check_campaign_and_preferences() -> void:
	root.content_scale_size = Vector2i(720, 1280)
	root.size = Vector2i(720, 1280)
	await process_frame
	await process_frame
	hud.campaign_requested.connect(func() -> void: campaign_signals += 1)
	hud.next_requested.connect(func() -> void: next_signals += 1)
	hud.mission_requested.connect(func(id: String) -> void: mission_selections.append(id))
	hud.setting_changed.connect(func(key: String, value: bool) -> void: preference_changes.append({"key": key, "value": value}))
	hud.sound_toggled.connect(func(_enabled: bool) -> void: legacy_sound_signals += 1)
	hud.show_title()
	await _capture("ui_campaign_title")
	await _tap(0, _overlay_button("Campaign"))
	_check(campaign_signals == 1, "Title Campaign uses its navigation signal")
	var missions: Array[Dictionary] = CAMPAIGN.missions()
	for index in range(missions.size()):
		missions[index]["unlocked"] = index < 2
		missions[index]["stars"] = 2 if index == 0 else 0
	hud.show_campaign(missions)
	await process_frame
	_check(hud._mission_buttons.size() == 6, "Campaign exposes all six mission cards")
	await _tap(0, hud._mission_buttons[str(missions[2]["id"])])
	_check(mission_selections.is_empty(), "A locked mission cannot emit a selection")
	await _tap(0, hud._mission_buttons[str(missions[1]["id"])])
	_check(mission_selections == [str(missions[1]["id"])], "Native campaign selection emits the exact mission id")
	for button: Button in hud._mission_buttons.values():
		_check(hud._safe.encloses(button.get_global_rect()), "Every mission card fits the portrait safe area")
		for child in button.get_children():
			if child is Label and child.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART:
				_check(button.get_global_rect().encloses(child.get_global_rect()), "Wrapped mission briefings remain inside their cards")
	await _capture("ui_campaign")
	hud.show_result(true, {"stars": 2, "next_available": true, "mission_name": "Briarwood Crossing", "wave": 3, "total_waves": 3, "kills": 24, "coins": 180})
	await _tap(0, _overlay_button("NEXT MISSION"))
	_check(next_signals == 1, "A mission victory offers a native Next mission action")
	_check(_overlay_button("DEFEND AGAIN") != null, "Mission victory retains replay")
	await _capture("ui_mission_result")
	hud.show_result(true, {"stars": 3, "campaign_complete": true, "mission_name": str(missions[5]["name"]), "wave": 6, "total_waves": 6})
	var ending_visible: bool = false
	for child in hud._overlay_card.get_children():
		if child is Label and child.text == "Campaign defended":
			ending_visible = true
	_check(ending_visible and _overlay_button("NEXT MISSION") == null, "Final victory has a campaign ending and no further mission")
	await _capture("ui_campaign_ending")
	hud.set_preferences({"sound": false, "reduced_motion": true, "large_controls": false, "tutorial_hints": false})
	_check(preference_changes.is_empty() and legacy_sound_signals == 0, "Loading preferences emits no setting changes")
	hud.show_title()
	await _tap(0, _overlay_button("Settings"))
	_check(hud._overlay_mode == "settings" and hud._setting_buttons.size() == 4, "Title opens all four settings")
	_check(hud._setting_buttons["sound"].text == "Sound: OFF", "Settings reflect silently loaded preferences")
	await _tap(0, hud._setting_buttons["sound"])
	_check(preference_changes.size() == 1 and preference_changes[0] == {"key": "sound", "value": true} and legacy_sound_signals == 0, "A setting toggle emits one persistence event without duplicate legacy sound emission")
	await _tap(0, hud._setting_buttons["large_controls"])
	_check(bool(hud._preferences["large_controls"]) and preference_changes.size() == 2, "Larger controls can be toggled natively")
	await _capture("ui_settings")
	await _tap(0, _overlay_button("Back"))
	_check(hud._overlay_mode == "title", "Title settings return to title")
	await _tap(0, _overlay_button("How to play"))
	_check(hud._overlay_mode == "help", "How to play is available from the title")
	await _capture("ui_how_to_play")
	await _tap(0, _overlay_button("Back"))
	hud.show_pause()
	await _tap(0, _overlay_button("Settings"))
	await _tap(0, _overlay_button("Back"))
	_check(hud._overlay_mode == "pause" and hud.movement_vector() == Vector2.ZERO, "Paused settings return to pause without resuming movement")
	hud.show_game()
	hud.show_hint("Collect gold, then stand near a plot to build.")
	_check(not hud._hint_panel.visible, "Disabled tutorial preferences suppress hints")
	hud.set_preferences({"tutorial_hints": true})
	_check(hud._hint_panel.visible and hud._hint_label.text.contains("Collect gold"), "Enabling hints restores the current guidance")
	_check(hud._hint_panel.mouse_filter == Control.MOUSE_FILTER_IGNORE and hud._hint_label.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Hints never consume combat input")
	hud.toast("Wave approaching")
	hud._process(0.01)
	_check(not hud._hint_panel.visible and hud._toast_panel.visible, "Short toasts temporarily take the hint slot without overlapping")
	hud._process(2.4)
	_check(is_equal_approx(hud._toast_panel.modulate.a, 1.0), "Reduced motion suppresses the HUD fade")
	hud._process(0.4)
	_check(hud._hint_panel.visible, "Guidance returns after a toast expires")
	_check(hud._stick.size.x > 192 and hud._ability_button.size.y > 150, "Larger controls increase both movement and Volley targets")
	hud.show_context({"selection_id": "forge", "title": "Smith", "screen_position": Vector2(360, 1200), "tier": 1, "upgrade_cost": 50, "can_upgrade": true, "options": [{"id": "ranged", "label": "Keen arrows", "description": "Towers +20% damage", "cost": 35, "enabled": true}, {"id": "haste", "label": "Quick strings", "description": "Towers fire 15% faster", "cost": 35, "enabled": true}, {"id": "fortify", "label": "Fortify", "description": "Walls & Keep +20% health", "cost": 30, "enabled": true}]})
	_check(hud._upgrade_button.size.y > 69, "Larger controls also enlarge purchase targets")
	for button: Button in hud._smith_buttons:
		_check(not button.get_global_rect().intersects(hud._context_panel.get_global_rect()) and hud._safe.encloses(button.get_global_rect()), "Larger controls preserve Smith separation inside the safe area")
	await _capture("ui_large_controls")
	hud.show_hint("")
	_check(not hud._hint_panel.visible, "An empty hint clears completed onboarding")
	hud.set_save_notice("Progress could not be saved. Please keep the game open.")
	_check(not hud._save_notice_panel.visible, "Persistent save status does not cover active combat")
	hud.show_campaign(missions)
	_check(hud._save_notice_panel.visible and not hud._game.visible, "Save failures remain visible when gameplay HUD is hidden")
	_check(not hud._save_notice_panel.get_global_rect().intersects(hud._overlay_card.get_global_rect()), "Save status reserves space outside the campaign card")
	await _capture("ui_save_notice")
	hud.set_save_notice("")
	_check(not hud._save_notice_panel.visible, "A successful later save clears the notice")
	hud.show_result(true, {"save_failed": true})
	_check(hud._save_notice_panel.visible, "A failed-save result also exposes its progress warning")


func _check_continue_defense() -> void:
	hud.continue_requested.connect(func() -> void: continue_signals += 1)
	hud.set_save_notice("")
	hud.show_title()
	var initial_play: int = counters.play
	var summary := {"mission_name": "Briarwood Crossing", "wave": 3, "total_waves": 6, "elapsed": 87.9}
	hud.set_continue_summary(summary)
	await process_frame
	_check(_overlay_button("CONTINUE DEFENSE") != null, "An available saved defense updates the visible title")
	var summary_panel: Panel = hud._overlay_card.get_node("ContinueSummary")
	_check(summary_panel.get_node("ContinueMission").text == "Briarwood Crossing" and summary_panel.get_node("ContinueDetail").text == "Wave 3 / 6  ·  1:27 elapsed", "Continue summary identifies its mission, wave and elapsed time")
	_check(continue_signals == 0 and counters.play == initial_play, "Presenting a recovery summary cannot start or continue a defense")
	await _tap(0, _overlay_button("CONTINUE DEFENSE"))
	_check(continue_signals == 1 and counters.play == initial_play, "Continue emits only its own signal through native touch")
	_check(hud._overlay_mode == "title" and hud.movement_vector() == Vector2.ZERO, "Continue leaves restoration and paused-run routing to the composition root")
	# Each interruption deliberately omits finger one's release event.
	for interruption in [Node.NOTIFICATION_APPLICATION_PAUSED, Node.NOTIFICATION_APPLICATION_FOCUS_OUT]:
		var before: int = continue_signals
		var button: Button = _overlay_button("CONTINUE DEFENSE")
		await _touch(1, button.get_global_rect().get_center(), true)
		hud.notification(interruption)
		await process_frame
		_check(continue_signals == before and counters.play == initial_play, "Interrupting held Continue cannot emit a phantom action")
		await _tap(0, button)
		_check(continue_signals == before + 1, "Continue accepts finger zero after an interrupted finger-one press")
	var continue_at: Vector2 = _overlay_button("CONTINUE DEFENSE").get_global_rect().get_center()
	await _touch(1, continue_at, true)
	hud.set_continue_summary(summary)
	await _touch(1, continue_at, false)
	_check(continue_signals == 4, "An identical summary refresh preserves a deliberate Continue tap")
	await _tap(0, _overlay_button("Settings"))
	_check(hud._overlay_mode == "settings", "Settings remain accessible beside Continue")
	summary["wave"] = 4
	hud.set_continue_summary(summary)
	_check(hud._overlay_mode == "settings", "A recovery update does not replace an open settings screen")
	await _tap(0, _overlay_button("Back"))
	_check(_overlay_button("CONTINUE DEFENSE") != null and hud._overlay_card.get_node("ContinueSummary/ContinueDetail").text.contains("Wave 4 / 6"), "The updated recovery summary survives settings navigation")
	await _tap(0, _overlay_button("How to play"))
	await _tap(0, _overlay_button("Back"))
	_check(_overlay_button("CONTINUE DEFENSE") != null, "Recovery remains available after How to play navigation")
	await _tap(0, _overlay_button("DEFEND THE KEEP"))
	_check(counters.play == initial_play + 1 and continue_signals == 4, "New defense remains a separate native action while Continue is available")
	var before_campaign: int = campaign_signals
	await _tap(0, _overlay_button("Campaign"))
	_check(campaign_signals == before_campaign + 1, "Campaign navigation remains available with a saved defense")
	# Replacing or hiding a held recovery action must discard its captured finger.
	continue_at = _overlay_button("CONTINUE DEFENSE").get_global_rect().get_center()
	await _touch(1, continue_at, true)
	summary["mission_name"] = "Stonegate March"
	hud.set_continue_summary(summary)
	await _touch(1, continue_at, false)
	_check(continue_signals == 4 and counters.play == initial_play + 1, "Replacing a held recovery summary cancels the previous Continue intent")
	continue_at = _overlay_button("CONTINUE DEFENSE").get_global_rect().get_center()
	await _touch(1, continue_at, true)
	hud.set_continue_summary({})
	await _touch(1, continue_at, false)
	_check(_overlay_button("CONTINUE DEFENSE") == null and hud._overlay_card.get_node_or_null("ContinueSummary") == null, "An empty summary removes both recovery details and action")
	_check(continue_signals == 4 and counters.play == initial_play + 1, "Hiding held Continue cannot activate the replacement primary action")
	await _tap(0, _overlay_button("DEFEND THE KEEP"))
	_check(counters.play == initial_play + 2, "New defense remains usable after the recovery summary is cleared")
	hud.show_settings()
	hud.set_continue_summary(summary)
	await _tap(0, _overlay_button("Back"))
	_check(_overlay_button("CONTINUE DEFENSE") != null, "A recovery summary added in settings appears when returning to title")
	# Stress long text, larger controls, three aspect ratios and reserved save status.
	summary["mission_name"] = "Briarwood Crossing and the Northern Watch of the Last Light beyond the ancient kingdom's farthest border"
	hud.set_continue_summary(summary)
	hud.set_preferences({"large_controls": true})
	hud.set_save_notice("The previous save could not be updated. Your earlier defense is still available.")
	for dimensions in [Vector2i(720, 1280), Vector2i(780, 1688), Vector2i(820, 1180)]:
		root.content_scale_size = dimensions
		root.size = dimensions
		await process_frame
		await process_frame
		hud._layout()
		_check(hud._safe.encloses(hud._overlay_card.get_global_rect()) and not hud._overlay_card.get_global_rect().intersects(hud._save_notice_panel.get_global_rect()), "Recovery title and save notice fit the safe area across aspect ratios")
		var actions: Array[Button] = []
		for title in ["CONTINUE DEFENSE", "DEFEND THE KEEP", "Campaign", "Settings", "How to play"]:
			actions.append(_overlay_button(title))
		var action_layout_valid: bool = true
		for index in range(actions.size()):
			action_layout_valid = action_layout_valid and hud._overlay_card.get_global_rect().encloses(actions[index].get_global_rect()) and actions[index].get_global_rect().size.y >= 54.0
			for other in range(index + 1, actions.size()):
				action_layout_valid = action_layout_valid and not actions[index].get_global_rect().intersects(actions[other].get_global_rect())
		_check(action_layout_valid, "Recovery title keeps all five touch targets large, visible and separate")
		summary_panel = hud._overlay_card.get_node("ContinueSummary")
		var mission_label: Label = summary_panel.get_node("ContinueMission")
		_check(summary_panel.get_global_rect().encloses(mission_label.get_global_rect()) and mission_label.max_lines_visible == 2 and mission_label.clip_text and not mission_label.get_global_rect().intersects(summary_panel.get_node("ContinueDetail").get_global_rect()), "Long recovery mission names remain bounded above wave and time details")
		var before: int = continue_signals
		await _tap(0, actions[0])
		_check(continue_signals == before + 1 and counters.play == initial_play + 2, "Scaled recovery title still routes native Continue to only its own signal")
	root.content_scale_size = Vector2i(720, 1280)
	root.size = Vector2i(720, 1280)
	await process_frame
	await process_frame
	hud.set_save_notice("")
	hud.set_continue_summary({"mission_name": "Stonegate March", "wave": 4, "total_waves": 6, "elapsed": 122.7})
	await _capture("ui_recovery_title")
