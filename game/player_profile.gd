class_name PlayerProfile
extends RefCounted
## Small offline profile. Failed disk writes keep this session's progress in memory.
## The previous valid JSON remains in .bak; newer schemas are never overwritten.

const VERSION: int = 1
const MAX_MISSIONS: int = 256
const MAX_FILE_BYTES: int = 1048576
const SETTING_KEYS: Array[String] = ["sound", "reduced_motion", "large_controls", "tutorial_hints"]

var save_path: String = "user://emberwatch_profile.json"
var data: Dictionary = _defaults()
var last_error: String = ""


static func _defaults() -> Dictionary:
	return {
		"version": VERSION,
		"results": {},
		"settings": {"sound": true, "reduced_motion": false, "large_controls": false, "tutorial_hints": true},
	}


func load_profile() -> void:
	last_error = ""
	if save_path.is_empty():
		return
	data = _defaults()
	var primary: Dictionary = _read(save_path)
	if primary["status"] == "future":
		last_error = "This profile was saved by a newer game version. Its file has been preserved."
		return
	if primary["status"] == "valid":
		data = primary["data"]
		return
	var backup: Dictionary = _read(save_path + ".bak")
	if backup["status"] == "future":
		last_error = "The profile backup belongs to a newer game version. Its file has been preserved."
		return
	if backup["status"] == "valid":
		data = backup["data"]
		last_error = "Recovered the last valid profile backup."
		return
	if primary["status"] != "missing" or backup["status"] != "missing":
		last_error = "The profile could not be loaded. Using defaults for this session."


func store() -> bool:
	last_error = ""
	var checked: Dictionary = _validate(data)
	if not checked["ok"]:
		last_error = checked["error"]
		return false
	data = checked["data"]
	if save_path.is_empty():
		return true
	var backup_path: String = save_path + ".bak"
	var temporary_path: String = save_path + ".tmp"
	var backup_temporary_path: String = backup_path + ".tmp"
	if DirAccess.dir_exists_absolute(save_path) or DirAccess.dir_exists_absolute(backup_path):
		last_error = "The profile destination is a directory. Progress remains available for this session."
		return false
	# Recheck the files on every write, including when load_profile was never called.
	var primary: Dictionary = _read(save_path)
	var backup: Dictionary = _read(backup_path)
	if primary["status"] == "future" or backup["status"] == "future":
		last_error = "A newer profile version exists. Saving is disabled to preserve it."
		return false
	if primary["status"] == "unreadable" or backup["status"] == "unreadable":
		last_error = "An existing profile could not be inspected. Its file has been preserved."
		return false
	if not _write_text(temporary_path, JSON.stringify(data, "\t")):
		_remove_staging(temporary_path)
		return false
	if _read(temporary_path)["status"] != "valid":
		last_error = "The temporary profile failed verification. The previous save is unchanged."
		_remove_staging(temporary_path)
		return false
	# Only a validated primary may replace the backup. A corrupt primary must never
	# destroy the valid recovery copy loaded earlier in this session.
	if primary["status"] == "valid":
		if not _write_text(backup_temporary_path, primary["text"]):
			_remove_staging(temporary_path)
			_remove_staging(backup_temporary_path)
			return false
		if _read(backup_temporary_path)["status"] != "valid":
			last_error = "The profile backup failed verification. The previous save is unchanged."
			_remove_staging(temporary_path)
			_remove_staging(backup_temporary_path)
			return false
		if DirAccess.rename_absolute(backup_temporary_path, backup_path) != OK:
			last_error = "Could not publish the profile backup. The previous save is unchanged."
			_remove_staging(temporary_path)
			_remove_staging(backup_temporary_path)
			return false
	# A same-directory rename publishes the fully flushed file. Do not delete the
	# primary first: that would introduce a gap where a crash could lose the save.
	if DirAccess.rename_absolute(temporary_path, save_path) != OK:
		last_error = "Could not publish the profile. Progress remains available for this session."
		_remove_staging(temporary_path)
		_restore_missing_primary(backup_path)
		return false
	return true


func record_victory(mission_id: String, stars: int, seconds: float) -> bool:
	last_error = ""
	if not _valid_mission_id(mission_id) or stars < 1 or stars > 3 or not is_finite(seconds) or seconds <= 0.0:
		last_error = "Victory requires a mission ID, one to three stars, and a positive finite completion time."
		return false
	var checked: Dictionary = _validate(data)
	if not checked["ok"]:
		last_error = checked["error"]
		return false
	data = checked["data"]
	var results: Dictionary = data["results"]
	if not results.has(mission_id) and results.size() >= MAX_MISSIONS:
		last_error = "The profile has reached its mission record limit."
		return false
	var previous: Dictionary = results.get(mission_id, {})
	results[mission_id] = {
		"stars": maxi(stars, int(previous.get("stars", 0))),
		"best_time": minf(seconds, float(previous.get("best_time", seconds))),
	}
	return store()


func set_setting(key: String, value: bool) -> bool:
	last_error = ""
	if key not in SETTING_KEYS:
		last_error = "Unknown profile setting: " + key
		return false
	var checked: Dictionary = _validate(data)
	if not checked["ok"]:
		last_error = checked["error"]
		return false
	data = checked["data"]
	data["settings"][key] = value
	return store()


func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"status": "missing"}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"status": "unreadable"}
	if file.get_length() > MAX_FILE_BYTES:
		file.close()
		return {"status": "unreadable"}
	var text: String = file.get_as_text()
	var read_error: Error = file.get_error()
	file.close()
	if read_error != OK and read_error != ERR_FILE_EOF:
		return {"status": "unreadable"}
	var parser := JSON.new()
	if parser.parse(text) != OK or not parser.data is Dictionary:
		return {"status": "invalid"}
	var candidate: Dictionary = parser.data
	var version: Variant = candidate.get("version")
	# Recognize newer numeric schemas before validating their unknown contents.
	if _whole_number(version) and float(version) > VERSION:
		return {"status": "future"}
	var checked: Dictionary = _validate(candidate)
	if not checked["ok"]:
		return {"status": "invalid"}
	return {"status": "valid", "data": checked["data"], "text": text}


static func _validate(candidate: Dictionary) -> Dictionary:
	if not _whole_number(candidate.get("version")) or float(candidate["version"]) != VERSION:
		return _invalid("Unsupported or missing profile version.")
	for key: Variant in candidate:
		if key not in ["version", "results", "settings"]:
			return _invalid("The profile contains an unknown field.")
	var result: Dictionary = _defaults()
	var settings: Variant = candidate.get("settings", {})
	if not settings is Dictionary:
		return _invalid("Profile settings must be a dictionary.")
	for key: Variant in settings:
		if not key is String or key not in SETTING_KEYS or not settings[key] is bool:
			return _invalid("Profile settings must contain only known boolean options.")
		result["settings"][key] = settings[key]
	var results: Variant = candidate.get("results", {})
	if not results is Dictionary or results.size() > MAX_MISSIONS:
		return _invalid("Profile mission records are invalid or exceed the limit.")
	for mission_id: Variant in results:
		if not mission_id is String or not _valid_mission_id(mission_id):
			return _invalid("The profile contains an invalid mission ID.")
		var record: Variant = results[mission_id]
		if not record is Dictionary or record.size() != 2 or not record.has("stars") or not record.has("best_time"):
			return _invalid("The profile contains an invalid mission record.")
		var stars: Variant = record["stars"]
		var seconds: Variant = record["best_time"]
		if not _whole_number(stars) or float(stars) < 1.0 or float(stars) > 3.0:
			return _invalid("Mission stars must be an integer from one to three.")
		if not _number(seconds) or not is_finite(float(seconds)) or float(seconds) <= 0.0:
			return _invalid("Mission completion times must be positive finite numbers.")
		result["results"][mission_id] = {"stars": int(stars), "best_time": float(seconds)}
	return {"ok": true, "data": result}


static func _valid_mission_id(value: String) -> bool:
	return not value.strip_edges().is_empty() and value.length() <= 80 and not value.contains("\n") and not value.contains("\r")


static func _number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT


static func _whole_number(value: Variant) -> bool:
	return _number(value) and is_finite(float(value)) and floorf(float(value)) == float(value)


static func _invalid(message: String) -> Dictionary:
	return {"ok": false, "error": message}


func _write_text(path: String, text: String) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		last_error = "Could not open the profile for writing. Progress remains available for this session."
		return false
	file.store_string(text)
	file.flush()
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK:
		last_error = "Could not finish writing the profile. Progress remains available for this session."
		return false
	return true


func _restore_missing_primary(backup_path: String) -> void:
	# Defensive rollback if a failed platform rename removed the destination.
	if FileAccess.file_exists(save_path) or DirAccess.dir_exists_absolute(save_path):
		return
	var backup: Dictionary = _read(backup_path)
	if backup["status"] != "valid":
		return
	var original_error: String = last_error
	var recovery_path: String = save_path + ".restore.tmp"
	if _write_text(recovery_path, backup["text"]):
		DirAccess.rename_absolute(recovery_path, save_path)
	_remove_staging(recovery_path)
	last_error = original_error


static func _remove_staging(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
