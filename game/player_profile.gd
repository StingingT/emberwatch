class_name PlayerProfile
extends RefCounted
## Small offline profile. Failed disk writes keep this session's progress in memory.
## The previous valid JSON remains in .bak; newer schemas are never overwritten.

const StorageScript = preload("res://game/atomic_json_store.gd")
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
	var storage: RefCounted = _storage()
	var loaded: Dictionary = storage.load_document()
	last_error = str(loaded["error"])
	if loaded["status"] in ["valid", "recovered"]:
		data = loaded["data"]


func store() -> bool:
	last_error = ""
	var checked: Dictionary = _validate(data)
	if not checked["ok"]:
		last_error = checked["error"]
		return false
	data = checked["data"]
	if save_path.is_empty():
		return true
	var storage: RefCounted = _storage()
	var saved: bool = storage.write_document(data)
	last_error = storage.last_error
	return saved

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


func _storage() -> RefCounted:
	var storage = StorageScript.new()
	storage.save_path = save_path
	storage.schema_version = VERSION
	storage.max_file_bytes = MAX_FILE_BYTES
	storage.validator = func(candidate: Dictionary) -> Dictionary: return _validate(candidate)
	return storage
