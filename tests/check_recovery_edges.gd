extends SceneTree
## Isolated regressions for terminal identity and unplayable malformed positions.
## Victories are lifecycle fixtures, not campaign difficulty evidence.
const GameScript = preload("res://game/game.gd")
var checks: int = 0
var failures: int = 0
var test_directory: String


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	test_directory = "user://recovery_edge_checks_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	if DirAccess.make_dir_absolute(test_directory) != OK:
		push_error("FAIL: Could not create isolated edge fixtures")
		quit(1)
		return
	await _test_terminal_identity(true)
	await _test_terminal_identity(false)
	await _test_blocked_positions()
	_cleanup(test_directory)
	if failures == 0:
		print("RECOVERY_EDGE_CHECKS_PASS: %d checks" % checks)
		quit(0)
	else:
		quit(1)


func _test_terminal_identity(next_won: bool) -> void:
	var suffix: String = "victory" if next_won else "loss"
	var profile_directory: String = test_directory + "/profile_" + suffix
	var game: Node3D = GameScript.new()
	game.persistent_profile = false
	game.profile_path_override = profile_directory + "/profile.json"
	game.run_path_override = test_directory + "/run_" + suffix + ".json"
	root.add_child(game)
	game.start_run()
	_freeze(game)
	game.elapsed = 50.0
	game._finish_run(true)
	_check(game.state == "won" and not game.profile.last_error.is_empty() and game.run_store.data["outcome"]["mission_id"] == "briarwood", "The prior victory remains journaled while profile storage is unavailable: " + suffix)
	_check(game.start_mission("amberfield"), "Session unlocks permit the next defense while its prior result awaits persistence: " + suffix)
	_freeze(game)
	var current_id: String = game._run_id
	_check(game._new_run_pending and game.run_store.data["run_id"] != current_id, "The next battle has no current journal because its first checkpoint could not replace the pending victory: " + suffix)
	DirAccess.make_dir_absolute(profile_directory)
	game.elapsed = 75.0
	if next_won:
		game._finish_run(true)
	else:
		game.damage_keep(game.keep_health)
	_check(game.run_store.data["run_id"] == current_id and game.run_store.data["outcome"].get("mission_id") == "amberfield" and game.run_store.data["outcome"]["kind"] == suffix, "Finishing after profile recovery journals the current battle identity and outcome: " + suffix)
	var primary: Dictionary = _read(game.run_path_override)
	var backup: Dictionary = _read(game.run_path_override + ".bak")
	_check(primary.get("run_id") == current_id and backup.get("run_id") == current_id and primary.get("state") == "terminal" and backup.get("state") == "terminal", "The never-checkpointed battle's terminal record reaches both durable copies: " + suffix)
	_check(game._run_save_notice.is_empty() and game._profile_save_notice.is_empty(), "Recovered storage does not report a spurious terminal identity failure: " + suffix)
	game.queue_free()
	await process_frame
	await process_frame


func _test_blocked_positions() -> void:
	var game: Node3D = GameScript.new()
	game.persistent_profile = false
	root.add_child(game)
	game.start_run()
	_freeze(game)
	var plot: Dictionary = game._plot_by_id("crossing")
	game.hero.position = plot["position"]
	_check(game.build_at("crossing", "tower"), "Position validation fixture uses a real purchased tower")
	_freeze(game)
	var valid: Dictionary = game.capture_run_snapshot()
	_check(game.validate_run_snapshot(valid)["ok"], "The actual construction-clearance position remains a valid snapshot")
	var inside_tower: Dictionary = valid.duplicate(true)
	inside_tower["hero"]["position"] = [plot["position"].x, 0.0, plot["position"].z]
	var original_hero: Node3D = game.hero
	_check(not game.validate_run_snapshot(inside_tower)["ok"], "A snapshot placing the hero inside an occupied tower is rejected")
	_check(not game.restore_run_snapshot(inside_tower) and game.hero == original_hero, "An unplayable occupied-position snapshot cannot replace the current world")
	var inside_keep: Dictionary = valid.duplicate(true)
	inside_keep["hero"]["position"] = [game.level["keep"].x, 0.0, game.level["keep"].z]
	_check(not game.validate_run_snapshot(inside_keep)["ok"], "A snapshot placing the hero inside the Keep is rejected")
	# Use the real movement constraint to obtain float32 edge coordinates rather
	# than hand-writing decimal boundaries that could hide an actual rounding gap.
	for desired: Vector3 in [
		Vector3(-1000, 0, -1000), Vector3(1000, 0, -1000),
		Vector3(-1000, 0, 1000), Vector3(1000, 0, 1000),
		Vector3(-1000, 0, 0), Vector3(1000, 0, 0),
		Vector3(0, 0, -1000), Vector3(0, 0, 1000),
	]:
		game.hero.position = game.constrain_hero_motion(game.hero.position, desired)
		_check(game.validate_run_snapshot(game.capture_run_snapshot())["ok"], "Actual constrained boundary position remains recoverable: " + str(game.hero.position))
	game.queue_free()
	await process_frame
	await process_frame


func _freeze(game: Node3D) -> void:
	game.set_physics_process(false)
	game.feedback.set_process(false)
	game.hud.set_process(false)
	for container: Node3D in [game._actors, game._projectiles, game._coins, game._structures]:
		for node: Node in container.get_children():
			node.set_physics_process(false)


func _read(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


func _cleanup(path: String) -> void:
	var directory: DirAccess = DirAccess.open(path)
	if directory == null:
		return
	for file: String in directory.get_files():
		DirAccess.remove_absolute(path + "/" + file)
	for child: String in directory.get_directories():
		_cleanup(path + "/" + child)
	DirAccess.remove_absolute(path)


func _check(passed: bool, message: String) -> void:
	checks += 1
	if not passed:
		failures += 1
		push_error("FAIL: " + message)
