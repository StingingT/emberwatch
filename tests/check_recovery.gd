extends SceneTree
## Real-root recovery integration with isolated disk saves and controlled actors.
## These fixtures verify persistence and lifecycle behavior, not combat balance.
const GameScript = preload("res://game/game.gd")
const RunStoreScript = preload("res://game/run_store.gd")
const Data = preload("res://game/game_data.gd")
var checks: int = 0
var failures: int = 0
var test_directory: String


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if arguments.size() >= 2 and arguments[0] == "--close-fixture":
		test_directory = arguments[1]
		var closing: Node3D = _new_game("close")
		closing.start_run()
		_freeze(closing)
		closing.coins = 221
		closing.elapsed = 2.25
		closing.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
		return
	test_directory = "user://recovery_checks_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	if DirAccess.make_dir_absolute(test_directory) != OK:
		push_error("Could not create the isolated recovery test directory")
		quit(1)
		return
	await _test_memory_defaults()
	await _test_roundtrips()
	await _test_all_missions()
	await _test_invalid_snapshots()
	await _test_checkpoint_lifecycle()
	await _test_unavailable_checkpoint()
	await _test_terminal_backups()
	await _test_pending_victory()
	_test_close_checkpoint()
	_cleanup(test_directory)
	if failures == 0:
		print("RECOVERY_CHECKS_PASS: %d checks" % checks)
	else:
		printerr("RECOVERY_CHECKS_FAILED: %d / %d checks" % [failures, checks])
	quit(0 if failures == 0 else 1)


func _new_game(slot: String) -> Node3D:
	var game: Node3D = GameScript.new()
	# These overrides are applied before _ready opens either store.
	game.profile_path_override = _profile_path(slot)
	game.run_path_override = _run_path(slot)
	root.add_child(game)
	_freeze(game)
	return game


func _profile_path(slot: String) -> String:
	return test_directory + "/" + slot + "_profile.json"


func _run_path(slot: String) -> String:
	return test_directory + "/" + slot + "_run.json"


func _free_game(game: Node3D) -> void:
	root.remove_child(game)
	game.queue_free()
	await process_frame


func _freeze(game: Node3D) -> void:
	game.set_physics_process(false)
	game.hud.set_process(false)
	game.feedback.set_process(false)
	for container: Node3D in [game._actors, game._projectiles, game._coins]:
		for actor: Node in container.get_children():
			actor.set_physics_process(false)
	for building: Node3D in game.buildings.values():
		building.set_physics_process(false)


func _test_memory_defaults() -> void:
	var game: Node3D = GameScript.new()
	root.add_child(game)
	_freeze(game)
	_check(game.profile.save_path.is_empty() and game.run_store.save_path.is_empty(), "Headless startup without path overrides keeps both stores memory-only")
	_check(game.capture_run_snapshot().is_empty() and not game.continue_defense(), "A fresh title has no invented resumable defense")
	game.start_run()
	_freeze(game)
	_check(game.save_interrupted_run() and game.run_store.data.get("state") == "active", "Memory-only headless runs still exercise the real checkpoint journal")
	await _free_game(game)


func _test_roundtrips() -> void:
	for phase: String in ["preparation", "live", "interwave"]:
		var slot: String = "roundtrip_" + phase
		var original: Node3D = _new_game(slot)
		_check(original.profile.save_path == _profile_path(slot) and original.run_store.save_path == _run_path(slot), "Root startup honors isolated profile and run paths in headless mode")
		original.start_run()
		_freeze(original)
		if phase == "live":
			_populate_live(original)
		elif phase == "interwave":
			original.wave_index = 0
			original.wave_cursor = original.wave_configs[0]["enemies"].size()
			original.kills = original.wave_cursor
			original.wave_active = false
			original.wave_timer = 3.25
			original.elapsed = 38.5
			original.drop_coin(Vector3(6, 0, -14), 19)
			_freeze(original)
		else:
			original.elapsed = 1.75
			original.wave_timer = 3.25
		var expected: Dictionary = original.capture_run_snapshot()
		_check(original.validate_run_snapshot(expected).get("ok", false), phase + " fixture passes the production snapshot validator")
		_check(original.save_interrupted_run(), phase + " checkpoints successfully through the real root")
		var journal: Dictionary = original.run_store.data.duplicate(true)
		var durable_primary: String = FileAccess.get_file_as_string(_run_path(slot))
		var durable_backup: String = FileAccess.get_file_as_string(_run_path(slot) + ".bak")
		await _free_game(original)
		var recovered: Node3D = _new_game(slot)
		_check(recovered.state == "menu" and not recovered.hud._continue_summary.is_empty(), phase + " fresh root offers Continue without starting the battle")
		_check(recovered.run_store.data["run_id"] == journal["run_id"] and _same(recovered.run_store.data["snapshot"], expected), phase + " loaded journal preserves identity and exact saved battle data")
		recovered.hud.continue_requested.emit()
		_freeze(recovered)
		_check(recovered.state == "paused" and recovered.hud._overlay_mode == "pause", phase + " title Continue restores to the real pause screen")
		_check(_same(recovered.capture_run_snapshot(), expected), phase + " fresh-root restoration preserves the complete captured battle")
		_check(FileAccess.get_file_as_string(_run_path(slot)) == durable_primary and FileAccess.get_file_as_string(_run_path(slot) + ".bak") == durable_backup, phase + " restore does not rewrite either durable run copy")
		_check(recovered.hero.move_input == Vector2.ZERO and recovered.hud.movement_vector() == Vector2.ZERO, phase + " recovery cannot revive movement input")
		if phase == "live":
			_check_live_details(recovered, expected)
		var before_wait: Dictionary = recovered.capture_run_snapshot()
		# Long deltas on every live actor stand in for time while the app is away.
		recovered._physics_process(3600.0)
		for container: Node3D in [recovered._actors, recovered._projectiles, recovered._coins]:
			for actor: Node in container.get_children():
				actor._physics_process(3600.0)
		for building: Node3D in recovered.buildings.values():
			building._physics_process(3600.0)
		var after_wait: Dictionary = recovered.capture_run_snapshot()
		before_wait.erase("camera_focus")
		after_wait.erase("camera_focus")
		_check(_same(before_wait, after_wait), phase + " paused recovery advances no waves, income, projectiles, health or cooldowns offline")
		recovered.hud.resume_requested.emit()
		_check(recovered.state == "playing" and recovered.hud._playing_ui, phase + " restored defense resumes only through the explicit Resume action")
		await _free_game(recovered)


func _populate_live(game: Node3D) -> void:
	game.coins = 2200
	for purchase: Array in [["forge", "smith"], ["quarry", "mine"], ["bend", "tower"], ["choke", "wall"]]:
		game.hero.position = game._plot_by_id(purchase[0])["position"]
		_check(game.build_at(purchase[0], purchase[1]), "Live snapshot fixture purchases a real " + purchase[1])
		game.buildings[purchase[0]].upgrade()
	game.hero.position = game._plot_by_id("forge")["position"]
	game._update_selection()
	for upgrade: String in ["ranged", "ranged", "haste", "fortify"]:
		game.buy_smith_upgrade(upgrade)
	game.keep_health -= 47.0
	game.buildings["choke"].health -= 29.0
	game.buildings["bend"].health -= 13.0
	game.buildings["bend"].cooldown = -1.75
	game.buildings["quarry"].cooldown = 4.25
	game.hero.position = Vector3(-1, 0, -12)
	game.hero.add_xp(49)
	while game.hero.pending_choices() > 0:
		game.hero.choose_upgrade("volley")
	game.hero.ability_cooldown = 7.25
	game.hero._shot_remaining = 0.31
	game.hero._model.rotation.y = 0.45
	game.hero.move_input = Vector2.LEFT
	game.wave_index = 0
	game.wave_active = true
	game.wave_cursor = 3
	game.kills = 1
	game.wave_timer = 0.43
	game.elapsed = 23.75
	game.coins_collected = 117
	game._used_volley = true
	game._last_keep_warning = 12.5
	game._camera_focus = Vector3(1.25, 0, -9.5)
	for index: int in range(2):
		var enemy: Node3D = game.spawn_enemy(str(game.wave_configs[0]["enemies"][index]), float(game.wave_configs[0]["health_scale"]))
		enemy.position = Vector3(2 + index, 0, -15 - index)
		enemy.health -= 7.0 + index
		enemy.route_index = 2
		enemy._attack_remaining = 0.61 + index * 0.1
		enemy._model.rotation.y = 0.7 + index * 0.2
		game.spawn_arrow(Vector3(-1, 1.25, -13), enemy, 14.5 + index, "hero" if index == 0 else "tower")
		game._projectiles.get_child(index)._lifetime = 2.75 - index * 0.2
	game.drop_coin(Vector3(6, 0, -12), 23)
	game.drop_coin(Vector3(-5, 0, -18), 11)
	var magnet: Node3D = game._coins.get_child(0)
	magnet._magnetized = true
	magnet._magnet_speed = 9.25
	magnet._age = 4.5
	magnet._phase = 0.9
	_freeze(game)


func _check_live_details(game: Node3D, expected: Dictionary) -> void:
	_check(_same(game.smith_levels, {"ranged": 2, "haste": 1, "fortify": 1}) and is_equal_approx(game.keep_max, 540.0) and is_equal_approx(game.keep_health, 493.0), "Recovery applies Smith modifiers before restoring damaged Keep health")
	_check(game.buildings.size() == 4 and game.buildings["choke"].tier == 2 and is_equal_approx(game.buildings["choke"].max_health, 396.0) and is_equal_approx(game.buildings["choke"].health, 367.0), "Recovery rebuilds all structure types, tiers and fortified wall damage")
	_check(game.hero.tier == 3 and game.hero.xp == 5 and is_equal_approx(game.hero.damage, 18.0) and is_equal_approx(game.hero.ability_cooldown, 7.25), "Recovery recalculates hero stats from level while preserving XP and Volley cooldown")
	_check(game.enemies.size() == 2 and game._projectiles.get_child_count() == 2 and game._coins.get_child_count() == 2, "Recovery reconstructs living enemies, in-flight arrows and physical gold")
	var targets_correct: bool = true
	for index: int in range(game._projectiles.get_child_count()):
		var arrow: Node3D = game._projectiles.get_child(index)
		targets_correct = targets_correct and arrow.snapshot_target() == game.enemies[int(expected["arrows"][index]["target_id"])]
	_check(targets_correct, "Restored arrows point to the new enemy instances through saved target IDs")
	_check(is_equal_approx(game.buildings["bend"].cooldown, -1.75) and is_equal_approx(game.buildings["quarry"].cooldown, 4.25) and game._coins.get_child(0)._magnetized, "Negative idle-tower timers, mine production timing and magnetized gold survive recovery")
	var plots_match: bool = true
	for id: String in game.plot_views:
		plots_match = plots_match and game.plot_views[id].visible == not game.buildings.has(id)
	_check(plots_match, "Restored occupied construction plots are hidden while empty plots remain available")


func _test_all_missions() -> void:
	var donor: Node3D = _new_game("mission_donor")
	for index: int in range(donor.missions.size()):
		var mission: Dictionary = donor.missions[index]
		if index > 0:
			donor.profile.data["results"][donor.missions[index - 1]["id"]] = {"stars": 1, "best_time": 90.0}
		donor.return_to_menu()
		_check(donor.start_mission(mission["id"]), "Authored mission fixture starts " + mission["id"])
		_freeze(donor)
		donor.wave_index = 0
		donor.wave_cursor = 1
		donor.wave_active = true
		donor.spawn_enemy(str(donor.wave_configs[0]["enemies"][0]), float(donor.wave_configs[0]["health_scale"]))
		_freeze(donor)
		var snapshot: Dictionary = donor.capture_run_snapshot()
		var slot: String = "mission_" + mission["id"]
		var store: RefCounted = RunStoreScript.new()
		store.save_path = _run_path(slot)
		store.snapshot_validator = donor.validate_run_snapshot
		_check(store.store_run(snapshot, "test_" + mission["id"]), "The journal accepts an actual snapshot for " + mission["id"])
		var recovered: Node3D = _new_game(slot)
		if index > 0:
			_check(not recovered.mission_unlocked(index) and not recovered.start_mission(mission["id"]), "Ordinary selection keeps " + mission["id"] + " locked in the empty profile")
		_check(recovered.continue_defense() and recovered.state == "paused" and recovered.mission_index == index, "Continue restores the valid saved mission independently of ordinary unlocks: " + mission["id"])
		_freeze(recovered)
		_check(recovered.level["route"] == mission["level"]["route"] and recovered.plots == mission["level"]["plots"] and recovered._keep_model.position == mission["level"]["keep"] and recovered._plot_root.get_child_count() == mission["level"]["plots"].size(), "Recovery replaces the actual route, Keep and plot views for " + mission["id"])
		_check(_same(recovered.capture_run_snapshot(), snapshot) and is_equal_approx(recovered.enemies[0].max_health, float(Data.ENEMIES[recovered.enemies[0].kind]["health"]) * float(mission["waves"][0]["health_scale"])), "Mission-specific battle state and enemy health scaling survive " + mission["id"])
		await _free_game(recovered)
	await _free_game(donor)


func _test_invalid_snapshots() -> void:
	var game: Node3D = _new_game("invalid")
	game.start_run()
	_freeze(game)
	_populate_live(game)
	var valid: Dictionary = game.capture_run_snapshot()
	_check(game.save_interrupted_run(), "Invalid-snapshot tests begin with a durable valid battle")
	var invalid: Dictionary = valid.duplicate(true)
	invalid.erase("hero")
	_reject_unchanged(game, invalid, "missing required hero")
	invalid = valid.duplicate(true)
	invalid["unexpected"] = true
	_reject_unchanged(game, invalid, "unknown snapshot field")
	invalid = valid.duplicate(true)
	invalid["coins"] = -1
	_reject_unchanged(game, invalid, "negative wallet")
	invalid = valid.duplicate(true)
	invalid["elapsed"] = NAN
	_reject_unchanged(game, invalid, "non-finite elapsed time")
	invalid = valid.duplicate(true)
	invalid["hero"]["position"] = [900.0, 0.0, 0.0]
	_reject_unchanged(game, invalid, "hero outside mission bounds")
	invalid = valid.duplicate(true)
	invalid["hero"]["xp"] = 100000
	_reject_unchanged(game, invalid, "XP beyond the current tier")
	invalid = valid.duplicate(true)
	invalid["hero"]["ability_cooldown"] = 999.0
	_reject_unchanged(game, invalid, "invalid Volley cooldown")
	invalid = valid.duplicate(true)
	invalid["content_fingerprint"] = "old_balance"
	_reject_unchanged(game, invalid, "incompatible gameplay fingerprint")
	invalid = valid.duplicate(true)
	invalid["mission_id"] = "unknown_mission"
	_reject_unchanged(game, invalid, "unknown mission")
	invalid = valid.duplicate(true)
	invalid["enemies"][1]["id"] = invalid["enemies"][0]["id"]
	_reject_unchanged(game, invalid, "duplicate enemy identity")
	invalid = valid.duplicate(true)
	invalid["arrows"][0]["target_id"] = 444
	_reject_unchanged(game, invalid, "dangling projectile target")
	invalid = valid.duplicate(true)
	invalid["buildings"][1]["plot_id"] = invalid["buildings"][0]["plot_id"]
	_reject_unchanged(game, invalid, "duplicate occupied plot")
	invalid = valid.duplicate(true)
	invalid["buildings"][0]["kind"] = "tower"
	_reject_unchanged(game, invalid, "building on an incompatible plot")
	invalid = valid.duplicate(true)
	invalid["enemies"][0]["max_health"] += 3.0
	_reject_unchanged(game, invalid, "enemy health inconsistent with wave scaling")
	invalid = valid.duplicate(true)
	invalid["enemies"][0]["health"] = 0.0
	_reject_unchanged(game, invalid, "dead enemy in the living actor list")
	invalid = valid.duplicate(true)
	invalid["wave_cursor"] = 9000
	_reject_unchanged(game, invalid, "spawn cursor beyond the authored roster")
	invalid = valid.duplicate(true)
	invalid["kills"] += 1
	_reject_unchanged(game, invalid, "kills and surviving enemies disagree with spawns")
	invalid = valid.duplicate(true)
	invalid["wave_active"] = false
	_reject_unchanged(game, invalid, "intermission with unfinished living enemies")
	invalid = valid.duplicate(true)
	invalid["smith_levels"]["fortify"] = -1
	_reject_unchanged(game, invalid, "negative Smith level")
	invalid = valid.duplicate(true)
	invalid["keep_health"] = game.keep_max + 1.0
	_reject_unchanged(game, invalid, "Keep health above its fortified maximum")
	await _free_game(game)


func _reject_unchanged(game: Node3D, invalid: Dictionary, reason: String) -> void:
	var hero: Node3D = game.hero
	var world: Node3D = game._world
	var expected: Dictionary = game.capture_run_snapshot()
	var state: String = game.state
	var journal: Dictionary = game.run_store.data.duplicate(true)
	var durable: String = FileAccess.get_file_as_string(game.run_store.save_path)
	var validation: Dictionary = game.validate_run_snapshot(invalid)
	_check(not bool(validation.get("ok", true)) and not str(validation.get("error", "")).is_empty(), "Validator rejects " + reason)
	_check(not game.restore_run_snapshot(invalid) and game.hero == hero and game._world == world and game.state == state and _same(game.capture_run_snapshot(), expected) and _same(game.run_store.data, journal) and FileAccess.get_file_as_string(game.run_store.save_path) == durable, "Rejected " + reason + " leaves the live world, state and journal untouched")


func _test_checkpoint_lifecycle() -> void:
	var game: Node3D = _new_game("lifecycle")
	game.start_run()
	_freeze(game)
	var first_id: String = game.run_store.data["run_id"]
	var first_sequence: int = int(game.run_store.data["sequence"])
	game._physics_process(4.9)
	_check(int(game.run_store.data["sequence"]) == first_sequence, "Periodic saving does not checkpoint on every frame")
	game._physics_process(0.2)
	await process_frame # Checkpoint publication is deferred until actors finish.
	_check(int(game.run_store.data["sequence"]) > first_sequence and is_equal_approx(game.run_store.data["snapshot"]["elapsed"], 5.1), "The five-second active checkpoint captures the current simulated time")
	game.coins = 211
	game.pause_run()
	_check(game.state == "paused" and game.run_store.data["snapshot"]["coins"] == 211, "Pausing checkpoints the latest battle before presenting pause")
	game.resume_run()
	game.coins = 212
	game.return_to_menu()
	_check(game.state == "menu" and game.run_store.data["snapshot"]["coins"] == 212 and not game.hud._continue_summary.is_empty(), "Returning to title preserves the active battle and exposes Continue")
	_check(game.continue_defense(), "The title checkpoint remains resumable in the same session")
	game.resume_run()
	game.coins = 213
	game.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	_check(game.state == "paused" and game.run_store.data["snapshot"]["coins"] == 213 and game.hero.move_input == Vector2.ZERO, "Application suspension pauses and checkpoints the latest battle")
	game.start_run()
	_freeze(game)
	var restarted_id: String = game.run_store.data["run_id"]
	_check(restarted_id != first_id and game.wave_index == -1 and game.coins == Data.STARTING_COINS, "Restart replaces the run identity and resets the battle")
	_check(_read_json(_run_path("lifecycle"))["run_id"] == restarted_id and _read_json(_run_path("lifecycle") + ".bak")["run_id"] == restarted_id, "Restart replaces both copies so the intentionally replaced battle cannot recover")
	game.profile.data["results"]["briarwood"] = {"stars": 1, "best_time": 80.0}
	game.return_to_menu()
	_check(game.start_mission("amberfield") and game.run_store.data["run_id"] != restarted_id and game.run_store.data["snapshot"]["mission_id"] == "amberfield", "Starting another unlocked mission replaces the prior run identity")
	_freeze(game)
	await _free_game(game)


func _test_unavailable_checkpoint() -> void:
	var slot: String = "unavailable"
	var game: Node3D = _new_game(slot)
	game.start_run()
	_freeze(game)
	var durable: String = FileAccess.get_file_as_string(_run_path(slot))
	var blocked_staging: String = _run_path(slot) + ".tmp"
	_check(DirAccess.make_dir_absolute(blocked_staging) == OK, "The isolated fixture blocks only battle staging writes")
	game.coins = 777
	game.elapsed = 2.5
	game.wave_timer = 2.5
	_check(not game.save_interrupted_run() and FileAccess.get_file_as_string(_run_path(slot)) == durable, "A failed live checkpoint leaves the earlier durable battle untouched")
	game.return_to_menu()
	_check(game.hud._save_notice_panel.visible and not game.hud._continue_summary.is_empty(), "Title exposes the save problem while keeping this session's defense available")
	_check(game.continue_defense() and game.state == "paused" and game.coins == 777 and is_equal_approx(game.elapsed, 2.5), "Continue retains newer session state when durable checkpoint writes are unavailable")
	_freeze(game)
	DirAccess.remove_absolute(blocked_staging)
	_check(game.save_interrupted_run(), "A paused restored session saves once staging becomes writable again")
	await _free_game(game)
	var fresh: Node3D = _new_game(slot)
	_check(fresh.continue_defense() and fresh.coins == 777 and is_equal_approx(fresh.elapsed, 2.5), "The retried checkpoint becomes recoverable in a fresh root")
	await _free_game(fresh)


func _test_terminal_backups() -> void:
	for outcome: String in ["victory", "loss"]:
		var slot: String = "terminal_" + outcome
		var game: Node3D = _new_game(slot)
		game.start_run()
		_freeze(game)
		game.elapsed = 81.5
		_check(game.save_interrupted_run(), "A resumable battle exists before the controlled " + outcome)
		if outcome == "victory":
			_finish_fixture(game, 1.0, 81.5)
		else:
			game.damage_keep(game.keep_health)
		_check(game.state == ("won" if outcome == "victory" else "lost") and game.run_store.data["state"] == "terminal" and game.run_store.data["outcome"]["kind"] == outcome, "A real " + outcome + " transition publishes the terminal outcome")
		_check(_read_json(_run_path(slot))["state"] == "terminal" and _read_json(_run_path(slot) + ".bak")["state"] == "terminal", "Both journal copies become terminal after " + outcome)
		_check(game.capture_run_snapshot().is_empty() and not game.continue_defense(), "A completed " + outcome + " offers no resumable live snapshot")
		await _free_game(game)
		_write(_run_path(slot), "{interrupted terminal primary")
		var fresh: Node3D = _new_game(slot)
		_check(fresh.run_store.data.get("state") == "terminal" and fresh.hud._continue_summary.is_empty() and not fresh.continue_defense() and fresh.state == "menu", "Backup recovery cannot resurrect a terminal " + outcome)
		_check(fresh.profile.data["results"].has("briarwood") == (outcome == "victory"), "Terminal " + outcome + " recovery preserves the correct campaign outcome")
		await _free_game(fresh)


func _test_pending_victory() -> void:
	var slot: String = "pending_victory"
	var game: Node3D = _new_game(slot)
	game.start_run()
	_freeze(game)
	_check(game.profile.set_setting("large_controls", true), "Pending-victory fixture starts with a durable player preference")
	var blocked_staging: String = _profile_path(slot) + ".tmp"
	_check(DirAccess.make_dir_absolute(blocked_staging) == OK, "The isolated fixture blocks only profile staging writes")
	_finish_fixture(game, 0.5, 88.5)
	_check(game.state == "won" and not str(game.profile.last_error).is_empty() and game.profile.data["results"].has("briarwood"), "A profile save failure retains this session's real victory")
	_check(_read_json(_run_path(slot))["state"] == "terminal" and _read_json(_run_path(slot))["outcome"]["kind"] == "victory" and not _read_json(_profile_path(slot))["results"].has("briarwood"), "The durable terminal victory precedes the unavailable campaign-profile write")
	await _free_game(game)
	DirAccess.remove_absolute(blocked_staging)
	var reconciled: Node3D = _new_game(slot)
	var result: Dictionary = reconciled.profile.data["results"].get("briarwood", {})
	_check(result.get("stars") == 2 and is_equal_approx(float(result.get("best_time", 0.0)), 88.5) and reconciled.mission_unlocked(1), "Fresh startup reconciles the pending terminal victory into campaign progress")
	_check(reconciled.profile.data["settings"]["large_controls"] and _read_json(_profile_path(slot))["results"].has("briarwood"), "Reconciliation durably saves the result and preserves existing settings")
	_check(reconciled.hud._continue_summary.is_empty() and not reconciled.continue_defense(), "Reconciling a victory never exposes its finished battle as Continue")
	_check(reconciled.profile.record_victory("briarwood", 3, 60.0), "An improved replay record can be saved after reconciliation")
	await _free_game(reconciled)
	var repeated: Node3D = _new_game(slot)
	result = repeated.profile.data["results"]["briarwood"]
	_check(result["stars"] == 3 and is_equal_approx(result["best_time"], 60.0) and repeated.profile.data["results"].size() == 1, "Repeated terminal reconciliation is idempotent and cannot lower a better replay record")
	await _free_game(repeated)


func _finish_fixture(game: Node3D, health_ratio: float, seconds: float) -> void:
	# A lifecycle fixture, not a claim that combat produced these final counters.
	game.wave_index = game.wave_configs.size() - 1
	game.wave_cursor = game.wave_configs[game.wave_index]["enemies"].size()
	game.wave_active = true
	game.kills = 0
	for wave: Dictionary in game.wave_configs:
		game.kills += wave["enemies"].size()
	game.keep_health = game.keep_max * health_ratio
	game.elapsed = seconds
	game._finish_run(true)


func _test_close_checkpoint() -> void:
	var output: Array = []
	var arguments := PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/check_recovery.gd", "--fixed-fps", "60", "--quit-after", "120", "--", "--close-fixture", test_directory])
	var exit_code: int = OS.execute(OS.get_executable_path(), arguments, output, true)
	_check(exit_code == 0, "Window-close fixture exits normally after the real root handles its notification")
	var saved: Dictionary = _read_json(_run_path("close"))
	_check(saved.get("state") == "active" and saved.get("snapshot", {}).get("coins") == 221 and is_equal_approx(float(saved.get("snapshot", {}).get("elapsed", 0.0)), 2.25), "The real close handler checkpoints the latest battle before process exit")
	if exit_code != 0:
		printerr("Close fixture output: ", output)


func _same(left: Variant, right: Variant) -> bool:
	if typeof(left) in [TYPE_INT, TYPE_FLOAT] and typeof(right) in [TYPE_INT, TYPE_FLOAT]:
		return is_equal_approx(float(left), float(right))
	if left is Dictionary and right is Dictionary:
		if left.size() != right.size():
			return false
		for key: Variant in left:
			if not right.has(key) or not _same(left[key], right[key]):
				return false
		return true
	if left is Array and right is Array:
		if left.size() != right.size():
			return false
		for index: int in range(left.size()):
			if not _same(left[index], right[index]):
				return false
		return true
	return typeof(left) == typeof(right) and left == right


func _read_json(path: String) -> Dictionary:
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return value if value is Dictionary else {}


func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_check(false, "Could not write isolated fixture: " + path)
		return
	file.store_string(text)
	file.close()


func _cleanup(path: String) -> void:
	# Only descend inside the uniquely named directory created by this test run.
	if path != test_directory and not path.begins_with(test_directory + "/"):
		return
	var directory: DirAccess = DirAccess.open(path)
	if directory == null:
		return
	for filename: String in directory.get_files():
		DirAccess.remove_absolute(path + "/" + filename)
	for child: String in directory.get_directories():
		_cleanup(path + "/" + child)
	DirAccess.remove_absolute(path)


func _check(passed: bool, message: String) -> void:
	checks += 1
	if not passed:
		failures += 1
		push_error("FAIL: " + message)
