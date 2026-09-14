class_name ArmyMenuView
extends RefCounted
## Thin presentation adapter over the existing safe-area/native-touch HUD.
const Rules = preload("res://game/army_data.gd")
const INK := Color("352f28")
const PAPER := Color("eee3c9")
const ROW := Color("e1d5b9")
const RED := Color("a74337")
const MUTED := Color("706758")
var game: Node
var hud: CanvasLayer
var _wave_button: Button
var _wave_wait_panel: Panel
var _wave_countdown: Label
var _waiting_wave_index: int = -2

func setup(owner_game: Node, owner_hud: CanvasLayer) -> void:
	game = owner_game
	hud = owner_hud
	# Passive countdown and optional action are separate controls. The view never
	# advances, pauses or resets the wave timer; game.gd owns automatic progression.
	_wave_wait_panel = hud._panel(hud._game, PAPER)
	_wave_wait_panel.name = "WaveCountdownPanel"
	_wave_wait_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wave_wait_panel.add_theme_stylebox_override("panel", _style(PAPER))
	_wave_countdown = hud._label(_wave_wait_panel, "", 21, INK)
	_wave_countdown.name = "AutomaticWaveCountdown"
	_wave_countdown.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wave_countdown.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_wave_button = hud._button(_wave_wait_panel, "Start now", 21)
	_wave_button.name = "StartNextWave"
	_wave_button.tooltip_text = "Optional: skip the wait. The next wave starts automatically."
	_wave_button.pressed.connect(game.start_next_wave_now)
	_flat_button(_wave_button, RED)
	_wave_wait_panel.hide()
	_wave_button.hide()

func update_wave_button() -> void:
	if not is_instance_valid(_wave_button):
		return
	var next_index: int = game.wave_index + 1
	var waiting: bool = (game.is_playing() and not game.wave_active
		and game.enemies.is_empty() and next_index >= 0
		and next_index < game.wave_configs.size())
	# An expiring countdown or a pause must release any held purchase-style touch.
	# It must not survive until another wave's shortcut appears.
	if not waiting or next_index != _waiting_wave_index:
		if _wave_button.has_method("reset_touch"):
			_wave_button.reset_touch()
	_waiting_wave_index = next_index if waiting else -2
	_wave_wait_panel.visible = waiting
	_wave_button.visible = waiting
	_wave_button.disabled = not waiting or game.wave_timer <= 0.0
	if not waiting:
		return
	_wave_wait_panel.position = hud._wave_panel.position
	_wave_wait_panel.size = hud._wave_panel.size
	var width: float = _wave_wait_panel.size.x
	var height: float = _wave_wait_panel.size.y
	var button_width: float = minf(132.0, width * 0.43)
	hud._rect(_wave_countdown, 12, 6, width - button_width - 36, height - 12)
	hud._rect(_wave_button, width - button_width - 8, 6, button_width, height - 12)
	_wave_countdown.text = "Auto in %ds\nWave %d" % [maxi(0, ceili(game.wave_timer)), next_index + 1]

func _page(mode: String, title: String, height: float = 880) -> void:
	hud._show_overlay(mode)
	hud._overlay_card.name = "ArmyPage"
	hud._overlay_card_size = Vector2(596, height)
	hud._overlay_card.add_theme_stylebox_override("panel", _style(PAPER))
	_text(title, 30, 26, 536, 45, 34, INK)
	_text("Supplies  %d     Stars  %d" % [game.army.data["supplies"], Rules.stars(game.profile.data["results"])], 30, 79, 536, 32, 23, MUTED)
	game._refresh_save_notice()
	hud._layout_overlay()

func _style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color("9b8b70")
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	return style

func _flat_button(button: Button, color: Color = ROW) -> void:
	for key: String in ["normal", "hover", "pressed", "disabled"]:
		var fill: Color = color
		if key == "hover":
			fill = color.lightened(0.08)
		elif key == "pressed":
			fill = color.darkened(0.10)
		elif key == "disabled":
			fill = Color("d6ccb7")
		button.add_theme_stylebox_override(key, _style(fill))
	for key: String in ["font_color", "font_hover_color", "font_pressed_color"]:
		button.add_theme_color_override(key, Color("fff5de") if color == RED else INK)
	button.add_theme_color_override("font_disabled_color", MUTED)

func _text(value: String, x: float, y: float, width: float, height: float, font_size: int = 23, tint: Color = INK) -> Label:
	var label: Label = hud._label(hud._overlay_card, value, font_size, tint, true)
	hud._rect(label, x, y, width, height)
	return label

func _button(value: String, x: float, y: float, width: float, action: Callable, primary: bool = false, enabled: bool = true, height: float = 64) -> Button:
	var button: Button = hud._button(hud._overlay_card, value, 23)
	hud._rect(button, x, y, width, height)
	_flat_button(button, RED if primary else ROW)
	button.disabled = not enabled
	button.pressed.connect(action)
	return button

func _row(y: float, height: float) -> void:
	var panel := Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _style(ROW))
	hud._overlay_card.add_child(panel)
	hud._rect(panel, 26, y, 544, height)

func show_home() -> void:
	_page("army_home", "EMBERWATCH", 720)
	_text("Defend. Improve. Return stronger.", 30, 147, 536, 38)
	var y: float = 217
	if not game._resume_snapshot.is_empty():
		_button("Continue defense", 30, y, 536, game.continue_defense, true)
		y += 78
	_button("Battle", 30, y, 536, game.start_recommended_mission, true)
	_button("Army upgrades", 30, y + 78, 536, func() -> void: game.show_army("hero"))
	_button("Campaign", 30, y + 156, 536, game.show_campaign)
	_button("Settings", 30, 626, 256, hud.show_settings)
	_button("How to play", 310, 626, 256, hud.show_how_to_play)

func show_upgrades(group: String = "hero", page: int = 0) -> void:
	_page("army_upgrades", "ARMY UPGRADES", 920)
	var tabs: Array[String] = ["hero", "army", "achievements"]
	var labels: Array[String] = ["Hero", "Defenses", "Achievements"]
	for i: int in range(tabs.size()):
		var tab: String = tabs[i]
		_button(labels[i], 30 + i * 181, 130, 174, func() -> void: show_upgrades(tab), group == tab)
	if group == "achievements":
		_show_achievements(page)
	else:
		_text("Permanent training. Your chosen look stays the same." if group == "hero" else "Training applies to your next battle, not a saved one.", 30, 211, 536, 51, 21, MUTED)
		var y: float = 281
		for id: String in Rules.UPGRADES:
			var definition: Dictionary = Rules.UPGRADES[id]
			if definition["group"] != group:
				continue
			_training_row(id, y, group)
			y += 128
		if group == "hero":
			_text("Building ages are earned in battle with gold.\nWooden outposts grow into stronger defenses;\nArcher Towers gain 1, then 2, then 3 archers.", 30, 595, 536, 127, 23)
	_button("Main menu", 30, 826, 256, game.return_to_menu)
	_button("Battle", 310, 826, 256, game.start_recommended_mission, true)

func _training_row(id: String, y: float, group: String) -> void:
	var definition: Dictionary = Rules.UPGRADES[id]
	var rank: int = Rules.rank_of(game.army.data["ranks"], id)
	var maximum: bool = rank >= Rules.MAX_RANK
	_row(y, 116)
	_text("%s   %d / %d" % [definition["label"], rank, Rules.MAX_RANK], 40, y + 10, 335, 34, 25)
	var step: int = roundi(float(definition["step"]) * 100)
	var benefit: String = "%s  +%d%%" % [definition["effect"], rank * step]
	if not maximum:
		benefit += "  >  +%d%%" % ((rank + 1) * step)
	_text(benefit, 40, y + 46, 345, 56, 20, MUTED)
	var enough_stars: bool = maximum or Rules.stars(game.profile.data["results"]) >= Rules.STAR_GATES[rank]
	var cost: int = 0 if maximum else Rules.COSTS[rank]
	var enabled: bool = not maximum and enough_stars and int(game.army.data["supplies"]) >= cost and not game.army.read_only
	var caption: String = "Max rank" if maximum else "%d\nSupplies" % cost
	if not enough_stars:
		caption = "%d stars\nneeded" % Rules.STAR_GATES[rank]
	_button(caption, 398, y + 26, 155, func() -> void: game.buy_training(id, group), enabled, enabled)

func _show_achievements(page: int) -> void:
	var start: int = clampi(page, 0, 1) * 4
	for index: int in range(start, mini(start + 4, Rules.ACHIEVEMENTS.size())):
		var definition: Dictionary = Rules.ACHIEVEMENTS[index]
		var earned: bool = game.army.data["achievements"].has(definition["id"])
		var current: int = Rules.stars(game.profile.data["results"]) if definition["metric"] == "stars" else game.profile.data["results"].size()
		var y: float = 216 + (index - start) * 120
		_row(y, 106)
		_text(str(definition["name"]), 40, y + 10, 495, 33, 25)
		_text("%d / %d %s    +%d Supplies%s" % [mini(current, int(definition["target"])), definition["target"], definition["metric"], definition["reward"], "  /  Earned" if earned else ""], 40, y + 48, 495, 42, 20, MUTED)
	_button("Previous" if page else "More achievements", 30, 716, 536, func() -> void: show_upgrades("achievements", 0 if page else 1))

func show_campaign() -> void:
	_page("army_campaign", "CAMPAIGN", 970)
	_text("Best stars count once. Replays still earn Supplies.", 30, 131, 536, 48, 21, MUTED)
	var y: float = 205
	for row: Dictionary in game.campaign_rows():
		var id: String = str(row["id"])
		var title: String = "%s   %d / 3 stars" % [row["name"], row["stars"]]
		if not row["unlocked"]:
			title = str(row["name"]) + "  /  Locked"
		_button(title, 30, y, 536, game.start_mission.bind(id), false, bool(row["unlocked"]), 76)
		y += 96
	_button("Main menu", 30, 876, 256, game.return_to_menu)
	_button("Upgrades", 310, 876, 256, func() -> void: game.show_army("army"))

func show_result(result: Dictionary) -> void:
	_page("army_result", "VICTORY" if result["won"] else "DEFENSE LOST", 900)
	_text(str(result["mission"]), 30, 134, 536, 36, 27)
	_text("%d / 3 stars     Keep  %d%%" % [result["stars"], roundi(float(result["keep_ratio"]) * 100)], 30, 181, 536, 40, 25)
	var seconds: int = int(result["elapsed"])
	_text("Waves cleared  %d / %d       Time  %d:%02d" % [result["cleared"], result["waves"], int(seconds / 60.0), seconds % 60], 30, 239, 536, 35, 22, MUTED)
	_row(311, 175)
	_text("SUPPLIES EARNED", 42, 326, 495, 35, 25)
	_text("%d" % result["normal"], 42, 369, 495, 63, 46)
	_text("Includes wave rewards already banked.", 42, 441, 495, 31, 20, MUTED)
	var receipt: Dictionary = game.army.data["runs"].get(str(result["run_id"]), {})
	var claimed: bool = bool(receipt.get("ad_claimed", false))
	var extra: int = Rules.ad_bonus(int(result["normal"]))
	var label: String = "Watch ad: +50%% Supplies (+%d)" % extra
	if claimed:
		label = "Bonus received: +%d Supplies" % extra
	elif not game.ad_available():
		label = "+50% Supplies / Ads unavailable"
	_button(label, 30, 512, 536, game.request_ad_bonus, false, game.ad_available() and not claimed and extra > 0 and game._pending_ad.is_empty())
	if int(result["achievement_reward"]) > 0:
		_text("Achievements: +%d Supplies (separate reward)" % result["achievement_reward"], 30, 597, 536, 47, 21, MUTED)
	else:
		_text("Spend Supplies to prepare for tougher battles.", 30, 597, 536, 47, 21, MUTED)
	_button("Army upgrades", 30, 675, 536, func() -> void: game.show_army("army"))
	_button("Main menu", 30, 806, 256, game.return_to_menu)
	_button("Next mission" if result["next"] else "Retry", 310, 806, 256, game.next_mission if result["next"] else game.start_run, true)

func show_pause() -> void:
	_page("pause", "PAUSED", 700)
	_text("Speed changes the whole battle, not the rewards.", 30, 146, 536, 49, 22, MUTED)
	_button("Battle speed: %dx" % game.battle_speed, 30, 226, 536, game.toggle_battle_speed)
	_button("Resume", 30, 314, 536, game.resume_run, true)
	_button("Restart", 30, 402, 536, game.start_run)
	_button("Settings", 30, 490, 536, hud.show_settings)
	_button("Main menu", 30, 600, 536, game.return_to_menu)
