class_name EmberwatchArmyGame
extends "res://game/game.gd"
## Additive composition layer. Base combat stays in game.gd; this owns metagame seams.
const ArmyRules = preload("res://game/army_data.gd")
const ArmyStore = preload("res://game/army_progression.gd")
const ArmyMenu = preload("res://ui/army_menu.gd")
var army: RefCounted
var army_menu: RefCounted
var army_path_override: String = ""
var ad_provider: Node = null
var _battle_ranks: Dictionary = {}
var _preparing_army: bool = false
var _result_view: Dictionary = {}
var _pending_ad: String = ""
var battle_speed: int = 1
var _normal_physics_ticks: int = 60

func _ready() -> void:
	_normal_physics_ticks = Engine.physics_ticks_per_second
	army = ArmyStore.new()
	if not army_path_override.is_empty():
		army.save_path = army_path_override
	elif not profile_path_override.is_empty():
		army.save_path = profile_path_override + ".army"
	elif not persistent_profile or DisplayServer.get_name() == "headless":
		army.save_path = ""
	army.load_progression()
	super._ready()
	_reconcile_army_result()
	army.seed_completed_missions(profile.data["results"])
	army.collect_achievements(profile.data["results"])
	army_menu = ArmyMenu.new()
	army_menu.setup(self, hud)
	army_menu.show_home()

func _process(_delta: float) -> void:
	var scale_value: float = float(battle_speed) if is_playing() else 1.0
	Engine.time_scale = scale_value
	Engine.physics_ticks_per_second = _normal_physics_ticks * int(scale_value)
	if is_instance_valid(army_menu):
		army_menu.update_wave_button()
		if state == "menu" and hud._overlay_mode == "title":
			army_menu.show_home()
		elif state == "paused" and hud._overlay_mode == "pause" and hud._overlay_card.name != "ArmyPage":
			army_menu.show_pause()

func _exit_tree() -> void:
	Engine.time_scale = 1.0
	Engine.physics_ticks_per_second = _normal_physics_ticks

func _spawn_hero() -> void:
	hero = HeroScript.new()
	hero.name = "Archer"
	_actors.add_child(hero)
	hero.setup(self, ArmyRules.hero_stats(Data.HERO, _battle_ranks))
	hero.position = level["hero"]

func start_run() -> void:
	if not _restoring_run:
		_battle_ranks = army.data["ranks"].duplicate(true)
		battle_speed = 1
	_result_view.clear()
	_preparing_army = true
	super.start_run()
	if not _restoring_run:
		keep_max = base_keep_health() * fortify_multiplier()
		keep_health = keep_max
	_preparing_army = false
	if not _restoring_run:
		save_interrupted_run()

func save_interrupted_run() -> bool:
	return false if _preparing_army else super.save_interrupted_run()

func ranged_multiplier() -> float:
	return super.ranged_multiplier() * ArmyRules.multiplier(_battle_ranks, "tower_damage")

func haste_multiplier() -> float:
	return super.haste_multiplier() * ArmyRules.multiplier(_battle_ranks, "tower_haste")

func fortify_multiplier() -> float:
	return super.fortify_multiplier() * ArmyRules.multiplier(_battle_ranks, "fortifications")

func mine_yield(base: int) -> int:
	return maxi(1, roundi(base * ArmyRules.multiplier(_battle_ranks, "mine_output")))

func _advance_waves(delta: float) -> void:
	var was_active: bool = wave_active
	var previous_wave: int = wave_index
	super._advance_waves(delta)
	if was_active and not wave_active and is_playing():
		_bank_waves(previous_wave + 1)

func _bank_waves(cleared: int) -> void:
	army.record_progress(_run_id, str(missions[mission_index]["id"]), mission_index, cleared)

func start_next_wave_now() -> void:
	if not is_playing() or wave_active or not enemies.is_empty() or wave_index >= wave_configs.size() - 1:
		return
	wave_timer = 0.0
	# Do not simulate the skipped wait: no free mine production or cooldown recovery.

func toggle_battle_speed() -> void:
	battle_speed = 2 if battle_speed == 1 else 1
	if state == "paused" and is_instance_valid(army_menu):
		army_menu.show_pause()

func show_army(group: String = "hero") -> void:
	if state in ["playing", "paused"]:
		return
	state = "army"
	hud.reset_input()
	hero.move_input = Vector2.ZERO
	army_menu.show_upgrades(group)

func buy_training(id: String, group: String) -> void:
	if state != "army":
		return
	if army.purchase(id, ArmyRules.stars(profile.data["results"])):
		play_sound("build")
	army_menu.show_upgrades(group)

func show_campaign() -> void:
	super.show_campaign()
	if is_instance_valid(army_menu):
		army_menu.show_campaign()

func return_to_menu() -> void:
	super.return_to_menu()
	if is_instance_valid(army_menu):
		army_menu.show_home()

func pause_run() -> void:
	var was_playing: bool = is_playing()
	super.pause_run()
	if was_playing and is_instance_valid(army_menu):
		army_menu.show_pause()

func _handle_android_back() -> bool:
	if state == "army":
		return_to_menu()
		return true
	return super._handle_android_back()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE and state == "army":
		return_to_menu()
		return
	super._unhandled_key_input(event)

func _finish_run(won: bool) -> void:
	if not is_playing():
		return
	var ratio: float = keep_health / maxf(1.0, keep_max)
	var earned_stars: int = 0
	if won:
		earned_stars = 3 if ratio >= float(Data.STAR_HEALTH_THRESHOLDS["three"]) else (2 if ratio >= float(Data.STAR_HEALTH_THRESHOLDS["two"]) else 1)
	var cleared: int = wave_configs.size() if won else maxi(0, wave_index + (0 if wave_active else 1))
	# Wallet and terminal receipt publish together, before retiring the battle.
	# Startup reconciliation closes the crash window between the two stores.
	var receipt: Dictionary = army.record_progress(_run_id, str(missions[mission_index]["id"]), mission_index, cleared, "victory" if won else "loss", earned_stars, maxf(0.01, elapsed))
	super._finish_run(won)
	var achievement_reward: int = army.collect_achievements(profile.data["results"])
	_result_view = {"won": won, "mission": str(missions[mission_index]["name"]), "stars": earned_stars,
		"cleared": cleared, "waves": wave_configs.size(), "elapsed": elapsed, "keep_ratio": ratio,
		"normal": int(receipt.get("normal", 0)), "achievement_reward": achievement_reward,
		"next": won and mission_index + 1 < missions.size(), "run_id": _run_id}
	if is_instance_valid(army_menu):
		army_menu.show_result(_result_view)

func _reconcile_army_result() -> void:
	var id: String = str(run_store.data.get("run_id", ""))
	var record: Dictionary = army.data["runs"].get(id, {})
	if (record.is_empty() or record["outcome"] == "active") and run_store.data.get("state") == "terminal":
		var terminal: Dictionary = run_store.data.get("outcome", {})
		for index: int in range(missions.size()):
			if missions[index]["id"] == terminal.get("mission_id"):
				var victory: bool = terminal.get("kind") == "victory"
				var cleared: int = missions[index]["waves"].size() if victory else int(record.get("cleared", 0))
				record = army.record_progress(id, str(missions[index]["id"]), index, cleared, "victory" if victory else "loss", int(terminal.get("stars", 0)), float(terminal.get("seconds", 0)))
				break
	if record.is_empty() or record["outcome"] == "active":
		return
	var outcome: Dictionary = {"kind": record["outcome"], "mission_id": record["mission_id"]}
	if record["outcome"] == "victory":
		outcome["stars"] = record["stars"]
		outcome["seconds"] = record["seconds"]
		profile.record_victory(str(record["mission_id"]), int(record["stars"]), float(record["seconds"]))
	if run_store.data.get("state") == "active":
		run_store.finish_run(outcome)
	_resume_snapshot.clear()
	_refresh_continue_summary()

func set_ad_provider(provider: Node) -> void:
	# Optional adapter contract: is_available(), request(run_id), reward_completed(run_id).
	# No provider is shipped; do not pretend a button press watched an advertisement.
	if is_instance_valid(ad_provider) and ad_provider.is_connected("reward_completed", _on_ad_completed):
		ad_provider.disconnect("reward_completed", _on_ad_completed)
	if is_instance_valid(ad_provider) and ad_provider.has_signal("reward_failed") and ad_provider.is_connected("reward_failed", _on_ad_failed):
		ad_provider.disconnect("reward_failed", _on_ad_failed)
	ad_provider = provider
	_pending_ad = ""
	if is_instance_valid(provider) and provider.has_signal("reward_completed"):
		provider.connect("reward_completed", _on_ad_completed)
	if is_instance_valid(provider) and provider.has_signal("reward_failed"):
		provider.connect("reward_failed", _on_ad_failed)

func ad_available() -> bool:
	return not army.read_only and is_instance_valid(ad_provider) and ad_provider.has_signal("reward_completed") and ad_provider.has_signal("reward_failed") and ad_provider.has_method("is_available") and ad_provider.has_method("request") and bool(ad_provider.call("is_available"))

func request_ad_bonus() -> void:
	if _result_view.is_empty() or not _pending_ad.is_empty() or not ad_available():
		return
	var id: String = str(_result_view["run_id"])
	var record: Dictionary = army.data["runs"].get(id, {})
	if record.is_empty() or bool(record["ad_claimed"]):
		return
	_pending_ad = id
	if not bool(ad_provider.call("request", id)):
		_pending_ad = ""
	if state in ["won", "lost"]:
		army_menu.show_result(_result_view)

func _on_ad_failed(id: String) -> void:
	if id == _pending_ad:
		_pending_ad = ""
		if state in ["won", "lost"] and not _result_view.is_empty():
			army_menu.show_result(_result_view)

func _on_ad_completed(id: String) -> void:
	if id.is_empty() or id != _pending_ad:
		return
	_pending_ad = ""
	army.claim_ad_bonus(id)
	if str(_result_view.get("run_id", "")) == id and state in ["won", "lost"]:
		army_menu.show_result(_result_view)

func capture_run_snapshot() -> Dictionary:
	var saved: Dictionary = super.capture_run_snapshot()
	if not saved.is_empty():
		saved["army"] = {"version": ArmyRules.BALANCE_VERSION, "ranks": _battle_ranks.duplicate(true)}
	return saved

func validate_run_snapshot(saved: Dictionary) -> Dictionary:
	# Legacy saves mean zero training. Current saves carry immutable run-start ranks.
	var meta: Variant = saved.get("army", {"version": ArmyRules.BALANCE_VERSION, "ranks": {}})
	if not meta is Dictionary or meta.size() != 2 or not ArmyRules.whole(meta.get("version"), ArmyRules.BALANCE_VERSION) or meta.get("version") != ArmyRules.BALANCE_VERSION or not ArmyRules.valid_ranks(meta.get("ranks")):
		return Snapshot.invalid("Invalid or incompatible army training in battle save.")
	var normalized: Dictionary = saved.duplicate(true)
	normalized.erase("army")
	# Reuse all existing actor/lifecycle checks in baseline-health units, then
	# return the original health. Never clamp or mutate a player's stored health.
	var ranks: Dictionary = meta["ranks"]
	var fortification: float = ArmyRules.multiplier(ranks, "fortifications")
	if normalized.get("hero") is Dictionary and Snapshot.number(normalized["hero"].get("health"), 0, Snapshot.MAX_COUNT):
		normalized["hero"]["health"] = float(normalized["hero"]["health"]) / ArmyRules.multiplier(ranks, "hero_health")
	if Snapshot.number(normalized.get("keep_health"), 0, Snapshot.MAX_COUNT):
		normalized["keep_health"] = float(normalized["keep_health"]) / fortification
	if normalized.get("buildings") is Array:
		for building: Variant in normalized["buildings"]:
			if building is Dictionary and building.get("kind") == "wall" and Snapshot.number(building.get("health"), 0, Snapshot.MAX_COUNT):
				building["health"] = float(building["health"]) / fortification
	var checked: Dictionary = super.validate_run_snapshot(normalized)
	if checked["ok"]:
		checked["data"] = saved.duplicate(true)
		checked["data"]["army"] = meta.duplicate(true)
	return checked

func restore_run_snapshot(saved: Dictionary) -> bool:
	var checked: Dictionary = validate_run_snapshot(saved)
	if not checked["ok"]:
		return false
	var prior: Dictionary = _battle_ranks
	_battle_ranks = checked["data"]["army"]["ranks"].duplicate(true)
	battle_speed = 1
	var restored: bool = super.restore_run_snapshot(checked["data"])
	if not restored:
		_battle_ranks = prior
	elif not _run_id.is_empty():
		_bank_waves(maxi(0, wave_index + (0 if wave_active else 1)))
	return restored

func _refresh_save_notice() -> void:
	super._refresh_save_notice()
	if is_instance_valid(army) and is_instance_valid(hud) and not str(army.last_error).is_empty():
		hud.set_save_notice((str(hud._save_notice_text) + " Army: " + str(army.last_error)).strip_edges())

func _upgrade_preview(building: Node3D) -> String:
	if building.kind == "mine":
		var production: Array = Data.BUILDINGS["mine"]["production"]
		return "Gold per cycle %d > %d" % [mine_yield(int(production[building.tier - 1])), mine_yield(int(production[building.tier]))]
	return super._upgrade_preview(building)
