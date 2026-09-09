extends SceneTree
## Isolated journal tests. Gameplay snapshot semantics belong to root validation.
const RunScript = preload("res://game/run_store.gd")
var checks: int = 0
var failures: int = 0
var test_directory: String

class SecondPublishFailure:
	extends "res://game/atomic_json_store.gd"
	var calls: int = 0
	func write_document(candidate: Dictionary, replace_incompatible: bool = false) -> bool:
		calls += 1
		if calls == 2:
			last_error = "Injected second publication failure."
			return false
		return super.write_document(candidate, replace_incompatible)

class FailureRunStore:
	extends "res://game/run_store.gd"
	var fail_second: bool = false
	func _storage() -> RefCounted:
		if not fail_second:
			return super._storage()
		var storage := SecondPublishFailure.new()
		storage.save_path = save_path
		storage.schema_version = VERSION
		storage.max_file_bytes = MAX_FILE_BYTES
		storage.validator = _validate_envelope
		return storage


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	test_directory = "user://run_store_checks_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	if DirAccess.make_dir_absolute(test_directory) != OK:
		push_error("FAIL: Could not create isolated run-store fixtures")
		quit(1)
		return
	_test_roundtrip()
	_test_terminal()
	_test_terminal_new_identity()
	_test_incompatible()
	_test_future()
	_test_invalid()
	_test_failures()
	_test_memory()
	_cleanup(test_directory)
	if failures == 0:
		print("RUN_STORE_CHECKS_PASS: %d checks" % checks)
		quit(0)
	else:
		quit(1)


func _test_roundtrip() -> void:
	var path: String = test_directory + "/roundtrip.json"
	var store = _store(path)
	_check(store.load_run()["status"] == "missing" and store.data.is_empty() and store.last_error.is_empty(), "A missing run has no Continue candidate or error")
	var snapshot: Dictionary = _snapshot()
	_check(store.store_run(snapshot, "battle-a"), "A new battle publishes successfully")
	_check(store.data["run_id"] == "battle-a" and store.data["sequence"] == 1 and _read(path + ".bak")["run_id"] == "battle-a", "A new identity is present in both durable copies")
	snapshot["coins"] = 999
	_check(store.data["snapshot"]["coins"] == 100, "Stored snapshots do not alias the caller's mutable dictionary")
	var fresh = _store(path)
	var loaded: Dictionary = fresh.load_run()
	_check(loaded["status"] == "active" and fresh.data == store.data and loaded["data"] == fresh.data, "A fresh run store roundtrips the complete active envelope")
	loaded["data"]["snapshot"]["coins"] = 0
	_check(fresh.data["snapshot"]["coins"] == 100, "Returned load data cannot mutate the owner's current snapshot")
	var second: Dictionary = _snapshot()
	second["coins"] = 160
	second["wave_timer"] = -19.1234567890123
	_check(store.store_run(second) and store.data["sequence"] == 2 and store.data["run_id"] == "battle-a", "Ordinary checkpoints retain identity and advance sequence")
	fresh.load_run()
	_check(is_equal_approx(fresh.data["snapshot"]["wave_timer"], second["wave_timer"]) and fresh.data["snapshot"]["coins"] == 160, "Signed timers and current resources survive full-precision JSON")
	var backup_text: String = FileAccess.get_file_as_string(path + ".bak")
	_write(path, "{interrupted")
	loaded = fresh.load_run()
	_check(loaded["status"] == "recovered" and fresh.data["sequence"] == 1 and not fresh.last_error.is_empty(), "A corrupt primary recovers the prior valid checkpoint and reports recovery")
	_check(fresh.store_run(fresh.data["snapshot"]) and FileAccess.get_file_as_string(path + ".bak") == backup_text, "Saving recovered data does not replace the valid backup with corrupt JSON")
	DirAccess.remove_absolute(path)
	_check(fresh.load_run()["status"] == "recovered", "A missing primary can recover its valid backup")


func _test_terminal() -> void:
	var path: String = test_directory + "/terminal.json"
	var store = _store(path)
	store.store_run(_snapshot(), "battle-terminal")
	store.store_run(_snapshot())
	_check(not store.finish_run({"kind": "victory", "mission_id": "wrong-mission", "stars": 3, "seconds": 80.0}), "A terminal result cannot attach another mission's reward to this battle")
	_check(store.finish_run({"kind": "victory", "mission_id": "briarwood", "stars": 3, "seconds": 80.25}), "A valid terminal victory publishes")
	_check(store.data["state"] == "terminal" and store.data["snapshot"].is_empty() and store.data["outcome"]["stars"] == 3, "Terminal records retain only the pending outcome, never resumable actors")
	_check(_read(path)["state"] == "terminal" and _read(path + ".bak")["state"] == "terminal", "Successful finish retires active state in both primary and backup")
	var fresh = _store(path)
	_check(fresh.load_run()["status"] == "terminal" and fresh.data["outcome"]["seconds"] == 80.25, "A fresh load exposes the terminal journal for root-owned result reconciliation")
	_write(path, "{corrupt terminal")
	var recovered: Dictionary = fresh.load_run()
	_check(recovered["status"] == "recovered" and recovered["data"]["state"] == "terminal", "Terminal backup recovery cannot resurrect the older active battle")
	_check(not fresh.store_run(_snapshot()), "An ordinary checkpoint cannot silently reopen a finished identity")
	_check(fresh.store_run(_snapshot(), "replacement-run") and fresh.data["sequence"] == 1, "An explicit new identity can replace a finished run")
	_check(_read(path + ".bak")["run_id"] == "replacement-run", "Replacement also retires the old identity from backup")
	_check(fresh.finish_run({"kind": "loss", "mission_id": "briarwood"}) and _read(path + ".bak")["outcome"]["kind"] == "loss", "Defeat reaches both copies without victory rewards")
	fresh.store_run(_snapshot(), "abandoned-run")
	_check(fresh.finish_run({"kind": "abandoned"}) and fresh.data["outcome"].size() == 1, "Explicit abandonment retires the battle without fabricating a result")
	_write(path, "{corrupt abandoned")
	_check(fresh.load_run()["data"]["outcome"]["kind"] == "abandoned", "A corrupted abandoned primary cannot recover a resumable battle")


func _test_incompatible() -> void:
	var path: String = test_directory + "/incompatible.json"
	var original = _store(path)
	original.store_run(_snapshot(), "old-content-run")
	var old_primary: String = FileAccess.get_file_as_string(path)
	var old_backup: String = FileAccess.get_file_as_string(path + ".bak")
	var changed = _store(path, "fixture-v2")
	_check(changed.load_run()["status"] == "incompatible" and not changed.last_error.is_empty(), "Changed content disables Continue and reports incompatibility")
	var next: Dictionary = _snapshot("fixture-v2")
	_check(not changed.store_run(next) and not changed.store_run(next, "old-content-run"), "Implicit checkpoints and reusing the old ID cannot bypass incompatible-save protection")
	_check(FileAccess.get_file_as_string(path) == old_primary and FileAccess.get_file_as_string(path + ".bak") == old_backup, "Incompatible saves remain byte-for-byte intact until explicit replacement")
	_check(changed.store_run(next, "new-content-run"), "A genuinely new run ID explicitly replaces incompatible content")
	_check(_read(path)["snapshot"]["content_fingerprint"] == "fixture-v2" and _read(path + ".bak")["snapshot"]["content_fingerprint"] == "fixture-v2", "Explicit replacement clears incompatible content from both copies")
	_check(changed.store_run(next) and changed.data["sequence"] == 2, "Normal checkpoints work after explicit incompatible replacement")


func _test_terminal_new_identity() -> void:
	var path: String = test_directory + "/new_terminal.json"
	var store = _store(path)
	store.store_run(_snapshot(), "earlier-battle")
	store.finish_run({"kind": "victory", "mission_id": "briarwood", "stars": 3, "seconds": 80.0})
	var next_result: Dictionary = {"kind": "victory", "mission_id": "amberfield", "stars": 2, "seconds": 95.0}
	_check(not store.finish_run(next_result) and not store.finish_run(next_result, "earlier-battle"), "A different mission still cannot finish under the earlier battle identity")
	_check(store.finish_run(next_result, "never-checkpointed-next-battle"), "A new battle can publish its terminal result without an active snapshot")
	_check(store.data["sequence"] == 1 and store.data["outcome"]["mission_id"] == "amberfield" and _read(path + ".bak")["run_id"] == "never-checkpointed-next-battle", "The new terminal identity and outcome reach both copies with a fresh sequence")
	var empty_store = _store(test_directory + "/zero_health_loss.json")
	_check(empty_store.finish_run({"kind": "loss", "mission_id": "stonegate"}, "zero-health-new-run"), "A zero-health new run can retire without fabricating a valid live snapshot")
	_check(empty_store.data["snapshot"].is_empty() and _read(empty_store.save_path + ".bak")["state"] == "terminal", "A new-run loss creates two terminal copies and no resumable actors")
	_check(not store.finish_run(next_result, " ") and not store.finish_run({"kind": "victory", "mission_id": "amberfield", "stars": 9, "seconds": 5.0}, "new-bad-result"), "Explicit terminal identity still validates the ID and outcome")
	var incompatible_path: String = test_directory + "/terminal_incompatible.json"
	var old = _store(incompatible_path)
	old.store_run(_snapshot(), "old-incompatible")
	var changed = _store(incompatible_path, "fixture-v2")
	changed.load_run()
	_check(not changed.finish_run({"kind": "loss"}, "old-incompatible") and changed.finish_run({"kind": "loss", "mission_id": "amberfield"}, "new-compatible-result"), "Only a new terminal identity can explicitly retire incompatible old content")
	_write(path, '{"version":99,"new_schema":true}')
	_check(not store.finish_run(next_result, "cannot-replace-future") and _read(path)["version"] == 99, "An explicit terminal identity still cannot overwrite a future envelope")


func _test_future() -> void:
	var path: String = test_directory + "/future.json"
	var future: String = '{"version":99,"unknown_schema":{"preserve":true}}'
	var store = _store(path)
	store.store_run(_snapshot(), "known-run")
	var backup: String = FileAccess.get_file_as_string(path + ".bak")
	_write(path, future)
	_check(store.load_run()["status"] == "future", "Future envelope versions load as protected")
	_check(not store.store_run(_snapshot(), "new-run") and not store.last_error.is_empty(), "Even explicit replacement cannot overwrite a future envelope")
	_check(FileAccess.get_file_as_string(path) == future and FileAccess.get_file_as_string(path + ".bak") == backup, "Protected future primary and its backup stay unchanged")
	_write(path, backup)
	_write(path + ".bak", future)
	store.load_run()
	_check(not store.store_run(_snapshot(), "another-run") and FileAccess.get_file_as_string(path + ".bak") == future, "A future backup is protected even when the primary is readable")
	_write(path, "{broken")
	_check(store.load_run()["status"] == "future" and not store.finish_run({"kind": "loss"}), "Future backup fallback never becomes a writable current battle")


func _test_invalid() -> void:
	var path: String = test_directory + "/invalid.json"
	var store = _store(path)
	store.store_run(_snapshot(), "valid-run")
	var original: String = FileAccess.get_file_as_string(path)
	var bad: Dictionary = _snapshot()
	bad["coins"] = -1
	_check(not store.store_run(bad), "The root-provided validator can reject invalid gameplay state")
	bad = _snapshot()
	bad["mission_id"] = "unknown"
	_check(not store.store_run(bad), "Unknown mission semantics are delegated to the snapshot validator")
	bad = _snapshot()
	bad["node"] = Vector3.ZERO
	_check(not store.store_run(bad), "Snapshots reject non-JSON engine values before invoking storage")
	bad = _snapshot()
	bad["wave_timer"] = NAN
	_check(not store.store_run(bad), "Snapshots reject non-finite numeric state")
	_check(not store.finish_run({"kind": "victory", "mission_id": "briarwood", "stars": 4, "seconds": 1.0}) and not store.finish_run({"kind": "victory", "mission_id": "briarwood", "stars": 1, "seconds": INF}), "Terminal rewards validate star and time ranges")
	_check(FileAccess.get_file_as_string(path) == original, "Rejected snapshot and result inputs preserve the previous primary")
	var no_validator = RunScript.new()
	no_validator.save_path = ""
	_check(not no_validator.store_run(_snapshot()), "Battle storage refuses unchecked snapshots when the root validator is unavailable")
	DirAccess.remove_absolute(path + ".bak")
	for invalid_text: String in ["not json", "[]", '{"version":1}', '{"version":1,"state":"active","run_id":"x","sequence":-1,"snapshot":{},"outcome":{}}']:
		_write(path, invalid_text)
		_check(store.load_run()["status"] == "failed" and store.data.is_empty(), "Malformed battle saves fail safely without a Continue candidate")


func _test_failures() -> void:
	var missing_path: String = test_directory + "/missing/run.json"
	var store = _store(missing_path)
	_check(not store.store_run(_snapshot(), "unwritable-run") and not store.last_error.is_empty(), "An unavailable destination reports a checkpoint failure")
	_check(store.data["snapshot"]["coins"] == 100, "Checkpoint failure retains the valid in-memory session snapshot")
	DirAccess.make_dir_absolute(test_directory + "/missing")
	_check(store.store_run(_snapshot()), "A checkpoint can be retried when its destination becomes available")
	var path: String = test_directory + "/staging.json"
	store = _store(path)
	store.store_run(_snapshot(), "staging-run")
	var primary: String = FileAccess.get_file_as_string(path)
	var backup: String = FileAccess.get_file_as_string(path + ".bak")
	DirAccess.make_dir_absolute(path + ".bak.tmp")
	_check(not store.store_run(_snapshot()), "A failed backup staging write aborts the checkpoint")
	_check(FileAccess.get_file_as_string(path) == primary and FileAccess.get_file_as_string(path + ".bak") == backup and not FileAccess.file_exists(path + ".tmp"), "Failed staging preserves both durable copies and removes the candidate")
	DirAccess.remove_absolute(path + ".bak.tmp")
	var partial = FailureRunStore.new()
	partial.save_path = path
	partial.snapshot_validator = _validator.bind("fixture-v1")
	partial.load_run()
	partial.fail_second = true
	_check(not partial.finish_run({"kind": "loss"}) and not partial.last_error.is_empty(), "Finishing reports failure when the second terminal publication fails")
	_check(_read(path)["state"] == "terminal" and _read(path + ".bak")["state"] == "active", "The injected failure actually exercises the primary-published backup-pending boundary")
	partial.fail_second = false
	_check(partial.finish_run({"kind": "loss"}) and _read(path)["state"] == "terminal" and _read(path + ".bak")["state"] == "terminal", "Retrying terminal publication retires both durable copies")


func _test_memory() -> void:
	var store = _store("")
	_check(store.load_run()["status"] == "missing" and store.store_run(_snapshot()), "Memory-only storage starts empty and can generate a run identity")
	var id: String = store.data["run_id"]
	_check(not id.is_empty() and store.store_run(_snapshot()) and store.data["run_id"] == id and store.data["sequence"] == 2, "Memory-only checkpoints retain identity and sequence")
	_check(store.load_run()["status"] == "active" and store.data["sequence"] == 2, "Memory-only load retains the session battle")
	_check(store.finish_run({"kind": "victory", "mission_id": "briarwood", "stars": 2, "seconds": 90.0}) and store.load_run()["status"] == "terminal", "Memory-only terminal publication follows the same lifecycle")
	_check(not store.store_run(_snapshot()) and store.store_run(_snapshot(), "fresh-memory-run"), "Memory-only finished battles require an explicit new identity")
	store.snapshot_validator = _validator.bind("fixture-v2")
	_check(store.load_run()["status"] == "incompatible" and not store.store_run(_snapshot("fixture-v2")), "Memory-only incompatible snapshots are protected too")
	_check(store.store_run(_snapshot("fixture-v2"), "different-memory-run"), "Memory-only incompatibility can be explicitly replaced")


func _store(path: String, fingerprint: String = "fixture-v1") -> RefCounted:
	var store = RunScript.new()
	store.save_path = path
	store.snapshot_validator = _validator.bind(fingerprint)
	return store


func _snapshot(fingerprint: String = "fixture-v1") -> Dictionary:
	return {"mission_id": "briarwood", "content_fingerprint": fingerprint, "coins": 100, "wave_timer": -2.75, "hero_position": [1.125, 0.0, -3.5]}


func _validator(snapshot: Dictionary, fingerprint: String) -> Dictionary:
	if snapshot["content_fingerprint"] != fingerprint:
		return {"ok": false, "status": "incompatible", "error": "The gameplay content has changed."}
	if snapshot["mission_id"] != "briarwood" or not snapshot.get("coins") is float and not snapshot.get("coins") is int or float(snapshot.get("coins", -1)) < 0:
		return {"ok": false, "error": "Invalid mission or coin total."}
	var normalized: Dictionary = snapshot.duplicate(true)
	normalized["coins"] = int(normalized["coins"])
	return {"ok": true, "data": normalized}


func _read(path: String) -> Dictionary:
	var result: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return result if result is Dictionary else {}


func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_check(false, "Could not create an isolated fixture")
		return
	file.store_string(text)
	file.close()


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
