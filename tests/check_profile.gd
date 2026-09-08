extends SceneTree
## Isolated persistence checks; this script never opens the real player profile.
const ProfileScript = preload("res://game/player_profile.gd")
var checks: int = 0
var failures: int = 0
var test_directory: String


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	test_directory = "user://profile_checks_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	if DirAccess.make_dir_absolute(test_directory) != OK:
		push_error("FAIL: Could not create an isolated profile test directory")
		quit(1)
		return
	var path: String = test_directory + "/profile.json"
	var profile = _profile(path)
	profile.load_profile()
	_check(profile.data["version"] == 1 and profile.data["results"].is_empty(), "A missing save starts with a versioned empty profile")
	_check(profile.last_error.is_empty() and profile.data["settings"]["sound"] and profile.data["settings"]["tutorial_hints"], "A first launch has enabled sound and hints without an error")
	_check(not profile.data["settings"]["reduced_motion"] and not profile.data["settings"]["large_controls"], "Accessibility options have explicit defaults")
	_check(profile.set_setting("sound", false), "A setting saves successfully")
	_check(profile.record_victory("forest_01", 2, 90.5), "A victory saves successfully")
	var reloaded = _profile(path)
	reloaded.load_profile()
	_check(not reloaded.data["settings"]["sound"] and reloaded.data["results"]["forest_01"]["stars"] == 2, "Settings and mission stars survive a new profile instance")
	_check(is_equal_approx(reloaded.data["results"]["forest_01"]["best_time"], 90.5), "Fractional completion time survives JSON roundtrip")
	_check(profile.record_victory("forest_01", 1, 110.0), "A weaker replay remains a valid completion")
	_check(profile.data["results"]["forest_01"]["stars"] == 2 and is_equal_approx(profile.data["results"]["forest_01"]["best_time"], 90.5), "A weaker replay cannot lower stars or slow the saved best time")
	_check(profile.record_victory("forest_01", 3, 100.0) and profile.record_victory("forest_01", 2, 75.25), "Star and time improvements can be earned independently")
	_check(profile.data["results"]["forest_01"]["stars"] == 3 and is_equal_approx(profile.data["results"]["forest_01"]["best_time"], 75.25), "The best stars and best time are retained independently")
	_check(profile.record_victory("forest_02", 1, 150.0) and profile.data["results"].size() == 2, "Distinct missions retain separate results")
	_check(profile.set_setting("reduced_motion", true) and profile.set_setting("large_controls", true) and profile.set_setting("tutorial_hints", false), "All known accessibility and tutorial settings save")
	reloaded.load_profile()
	_check(reloaded.data == profile.data, "The entire profile survives repeated atomic replacements")
	var valid_text: String = FileAccess.get_file_as_string(path)
	_check(not profile.set_setting("unknown_option", true) and not profile.last_error.is_empty(), "Unknown settings are rejected with an error")
	_check(not profile.record_victory("", 1, 1.0) and not profile.record_victory("too_many_stars", 4, 1.0) and not profile.record_victory("no_stars", 0, 1.0), "Invalid mission IDs and star ranges are rejected")
	_check(not profile.record_victory("invalid_time", 1, 0.0) and not profile.record_victory("invalid_time", 1, INF) and not profile.record_victory("invalid_time", 1, NAN), "Zero and non-finite completion times are rejected")
	_check(FileAccess.get_file_as_string(path) == valid_text, "Invalid API calls leave the durable save unchanged")
	profile.data["settings"]["sound"] = "false"
	_check(not profile.store() and FileAccess.get_file_as_string(path) == valid_text, "Directly modified data is validated before writing")
	profile.load_profile()
	profile.data["unexpected_object"] = Vector3.ZERO
	_check(not profile.store() and FileAccess.get_file_as_string(path) == valid_text, "Unexpected non-primitive profile fields cannot be serialized")
	profile.load_profile()
	_test_recovery(path, profile)
	_test_invalid_profiles()
	_test_future_versions()
	_test_write_failures()
	_test_memory_mode()
	_cleanup(test_directory)
	if failures == 0:
		print("PROFILE_CHECKS_PASS: %d checks" % checks)
		quit(0)
	else:
		quit(1)


func _test_recovery(path: String, profile: RefCounted) -> void:
	var backup_data: Dictionary = profile.data.duplicate(true)
	_check(profile.set_setting("sound", true), "A new save creates a previous-valid backup")
	var backup_text: String = FileAccess.get_file_as_string(path + ".bak")
	_write(path, "{interrupted save")
	var recovered = _profile(path)
	recovered.load_profile()
	_check(recovered.data == backup_data and not recovered.last_error.is_empty(), "A corrupt primary recovers settings and progress from its valid backup")
	_check(recovered.store() and FileAccess.get_file_as_string(path + ".bak") == backup_text, "Saving after recovery preserves the valid backup instead of copying corruption")
	var fresh = _profile(path)
	fresh.load_profile()
	_check(fresh.data == recovered.data and fresh.last_error.is_empty(), "A recovered profile becomes a readable primary again")
	DirAccess.remove_absolute(path)
	fresh.load_profile()
	_check(fresh.data == backup_data, "A missing primary also recovers the last valid backup")


func _test_invalid_profiles() -> void:
	var invalid_documents: Array[String] = [
		"not json", "[]", "{}", '{"version":0}',
		'{"version":1,"settings":{"sound":"false"}}',
		'{"version":1,"settings":{"invented":true}}',
		'{"version":1,"results":{"bad":{"stars":1.5,"best_time":20}}}',
		'{"version":1,"results":{"bad":{"stars":1,"best_time":-20}}}',
		'{"version":1,"results":{"bad":{"stars":1,"best_time":"20"}}}',
		'{"version":1,"results":[]}',
	]
	var path: String = test_directory + "/invalid.json"
	for document: String in invalid_documents:
		_write(path, document)
		var profile = _profile(path)
		profile.load_profile()
		_check(profile.data["results"].is_empty() and profile.data["settings"]["sound"] and not profile.last_error.is_empty(), "Invalid save falls back safely: " + document.left(56))
	_write(path, '{"version":1}')
	var sparse = _profile(path)
	sparse.load_profile()
	_check(sparse.last_error.is_empty() and sparse.data["settings"].size() == 4, "Missing optional sections receive current defaults")
	var too_large: String = test_directory + "/too_large.json"
	_write(too_large, " ".repeat(ProfileScript.MAX_FILE_BYTES + 1))
	var oversized = _profile(too_large)
	oversized.load_profile()
	_check(not oversized.last_error.is_empty() and not oversized.store() and FileAccess.get_file_as_string(too_large).length() > ProfileScript.MAX_FILE_BYTES, "Oversized files are bounded and preserved rather than parsed or overwritten")


func _test_future_versions() -> void:
	var path: String = test_directory + "/future.json"
	var future_text: String = '{"version":2,"new_schema":{"keep_me":true}}'
	var backup_text: String = '{"version":1,"settings":{"sound":false}}'
	_write(path, future_text)
	_write(path + ".bak", backup_text)
	var profile = _profile(path)
	profile.load_profile()
	_check(profile.data["results"].is_empty() and not profile.last_error.is_empty(), "A future schema loads safe defaults and reports its protected status")
	_check(not profile.set_setting("sound", false) and not profile.record_victory("forest_01", 3, 45.0), "APIs refuse to overwrite a newer version")
	_check(FileAccess.get_file_as_string(path) == future_text and FileAccess.get_file_as_string(path + ".bak") == backup_text, "Newer primary and its backup are preserved byte for byte")
	var never_loaded = _profile(path)
	_check(not never_loaded.store() and FileAccess.get_file_as_string(path) == future_text, "Future-version protection works even before an explicit load")
	_write(path, backup_text)
	_write(path + ".bak", future_text)
	profile.load_profile()
	_check(not profile.store() and FileAccess.get_file_as_string(path + ".bak") == future_text, "A future-version backup is also protected from replacement")
	DirAccess.remove_absolute(path)
	profile.load_profile()
	_check(not profile.last_error.is_empty() and not profile.store() and not FileAccess.file_exists(path), "A future backup with no primary stays protected")


func _test_write_failures() -> void:
	var missing_directory = _profile(test_directory + "/not_created/profile.json")
	_check(not missing_directory.set_setting("sound", false) and not missing_directory.last_error.is_empty(), "An unwritable destination reports failure without a crash")
	_check(not missing_directory.data["settings"]["sound"], "A failed save still retains the chosen setting for this session")
	var path: String = test_directory + "/blocked_backup.json"
	var profile = _profile(path)
	_check(profile.record_victory("forest_01", 2, 80.0), "A valid profile is available before a backup write failure")
	var original: String = FileAccess.get_file_as_string(path)
	DirAccess.make_dir_absolute(path + ".bak")
	_check(not profile.record_victory("forest_01", 3, 60.0) and FileAccess.get_file_as_string(path) == original, "A blocked backup destination leaves the previous primary intact")
	_check(not FileAccess.file_exists(path + ".tmp") and not FileAccess.file_exists(path + ".bak.tmp"), "Failed publishing does not leave temporary profile files")
	DirAccess.remove_absolute(path + ".bak")
	_check(profile.store(), "Session progress can be saved after the write failure is corrected")
	var recovered = _profile(path)
	recovered.load_profile()
	_check(recovered.data["results"]["forest_01"]["stars"] == 3 and is_equal_approx(recovered.data["results"]["forest_01"]["best_time"], 60.0), "Retrying saves progress earned while persistence was unavailable")
	var durable_primary: String = FileAccess.get_file_as_string(path)
	var durable_backup: String = FileAccess.get_file_as_string(path + ".bak")
	DirAccess.make_dir_absolute(path + ".bak.tmp")
	_check(not profile.set_setting("large_controls", true), "A failed backup staging write aborts publication after the new primary was staged")
	_check(FileAccess.get_file_as_string(path) == durable_primary and FileAccess.get_file_as_string(path + ".bak") == durable_backup, "A staging failure preserves both durable files byte for byte")
	_check(not FileAccess.file_exists(path + ".tmp"), "An aborted transaction cleans its staged primary")
	DirAccess.remove_absolute(path + ".bak.tmp")
	_check(profile.store() and not FileAccess.file_exists(path + ".tmp") and not FileAccess.file_exists(path + ".bak.tmp"), "A successful retry publishes the staged data and leaves no temporary files")


func _test_memory_mode() -> void:
	var profile = _profile("")
	profile.load_profile()
	_check(profile.set_setting("large_controls", true) and profile.record_victory("test", 3, 20.0) and profile.store(), "Memory-only profiles accept settings, victories, and explicit stores")
	profile.load_profile()
	_check(profile.data["settings"]["large_controls"] and profile.data["results"]["test"]["stars"] == 3 and profile.last_error.is_empty(), "Memory-only loads retain session state without filesystem access")
	for index: int in range(ProfileScript.MAX_MISSIONS - 1):
		profile.data["results"]["mission_%d" % index] = {"stars": 1, "best_time": 10.0}
	_check(not profile.record_victory("overflow", 1, 10.0) and profile.record_victory("test", 3, 19.0), "The record budget rejects new entries while allowing existing mission improvements")


func _profile(path: String) -> RefCounted:
	var profile = ProfileScript.new()
	profile.save_path = path
	return profile


func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_check(false, "Could not write test fixture: " + path)
		return
	file.store_string(text)
	file.close()


func _cleanup(path: String) -> void:
	# All contents belong to this uniquely named directory created by this run.
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
