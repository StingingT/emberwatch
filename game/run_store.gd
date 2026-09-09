class_name RunStore
extends RefCounted
## One battle journal. Campaign results remain owned by PlayerProfile.
const StorageScript = preload("res://game/atomic_json_store.gd")
const VERSION: int = 1
const MAX_FILE_BYTES: int = 2097152
const MAX_SEQUENCE: int = 9007199254740991

var save_path: String = "user://emberwatch_run.json"
var last_error: String = ""
var data: Dictionary = {}
var snapshot_validator: Callable


func load_run() -> Dictionary:
	last_error = ""
	if save_path.is_empty():
		if data.is_empty():
			return _result("missing")
		var checked: Dictionary = _validate_envelope(data)
		if not checked["ok"]:
			last_error = str(checked["error"])
			return _result(str(checked.get("status", "failed")), {}, last_error)
		data = checked["data"]
		return _result(str(data["state"]), data)
	var storage: RefCounted = _storage()
	var loaded: Dictionary = storage.load_document()
	last_error = str(loaded["error"])
	var status: String = str(loaded["status"])
	data = loaded["data"].duplicate(true) if status in ["valid", "recovered", "incompatible"] else {}
	if status == "valid":
		status = str(data["state"])
	return _result(status, data, last_error)


func store_run(snapshot: Dictionary, run_id: String = "") -> bool:
	last_error = ""
	var checked: Dictionary = _validate_snapshot(snapshot)
	if not checked["ok"]:
		last_error = str(checked["error"])
		return false
	var explicit_new: bool = not run_id.is_empty()
	if explicit_new and not _valid_id(run_id):
		last_error = "The new battle ID is invalid."
		return false
	var chosen_id: String = run_id if explicit_new else str(data.get("run_id", ""))
	if chosen_id.is_empty():
		chosen_id = Crypto.new().generate_random_bytes(16).hex_encode()
	if not explicit_new and data.get("state") == "terminal":
		last_error = "A completed battle needs a new run ID before replacement."
		return false
	var sequence: int = 1 if explicit_new or data.is_empty() else int(data.get("sequence", 0)) + 1
	if sequence > MAX_SEQUENCE:
		last_error = "The battle checkpoint sequence has reached its limit."
		return false
	var candidate: Dictionary = {
		"version": VERSION, "state": "active", "run_id": chosen_id, "sequence": sequence,
		"snapshot": checked["data"], "outcome": {},
	}
	var storage: RefCounted = _storage()
	# An explicit replacement must use a genuinely different identity when content
	# changed. A caller cannot bypass compatibility by repeating the old ID.
	if not save_path.is_empty():
		for path: String in [save_path, save_path + ".bak"]:
			var existing: Dictionary = storage.read_document(path)
			if existing["status"] == "incompatible" and (not explicit_new or str(existing["data"].get("run_id", "")) == chosen_id):
				last_error = "The saved battle is incompatible. Start a new defense to replace it."
				return false
	elif not data.is_empty():
		var existing: Dictionary = _validate_envelope(data)
		if not existing["ok"] and existing.get("status") == "incompatible" and (not explicit_new or str(data.get("run_id", "")) == chosen_id):
			last_error = "The saved battle is incompatible. Start a new defense to replace it."
			return false
	# Keep this session's valid state even when durable publication fails.
	data = candidate
	var saved: bool
	if explicit_new:
		# New identities replace both copies, so backup recovery cannot restart an
		# intentionally replaced earlier battle or retain incompatible backup data.
		saved = storage.write_redundant(data, true)
	else:
		saved = storage.write_document(data)
	last_error = str(storage.last_error)
	return saved


func finish_run(outcome: Dictionary, run_id: String = "") -> bool:
	last_error = ""
	var checked: Dictionary = _validate_outcome(outcome)
	if not checked["ok"]:
		last_error = str(checked["error"])
		return false
	if not run_id.is_empty() and not _valid_id(run_id):
		last_error = "The new battle ID is invalid."
		return false
	var new_identity: bool = not run_id.is_empty() and run_id != str(data.get("run_id", ""))
	if not new_identity and (data.is_empty() or not _valid_id(str(data.get("run_id", "")))):
		last_error = "There is no current battle to finish."
		return false
	var current_mission: String = str(data.get("snapshot", {}).get("mission_id", data.get("outcome", {}).get("mission_id", "")))
	if not new_identity and outcome.has("mission_id") and not current_mission.is_empty() and str(outcome["mission_id"]) != current_mission:
		last_error = "The terminal outcome belongs to a different mission."
		return false
	var sequence: int = 1 if new_identity else int(data.get("sequence", 0)) + 1
	if sequence > MAX_SEQUENCE:
		last_error = "The battle checkpoint sequence has reached its limit."
		return false
	var chosen_id: String = run_id if new_identity else str(data["run_id"])
	var storage: RefCounted = _storage()
	if new_identity and not save_path.is_empty():
		for path: String in [save_path, save_path + ".bak"]:
			var existing: Dictionary = storage.read_document(path)
			if existing["status"] == "incompatible" and str(existing["data"].get("run_id", "")) == chosen_id:
				last_error = "The incompatible battle needs a genuinely new run ID for replacement."
				return false
	# Root may finish a new battle before its first checkpoint could be saved,
	# including a zero-health loss that cannot form an active snapshot.
	data = {
		"version": VERSION, "state": "terminal", "run_id": chosen_id,
		"sequence": sequence, "snapshot": {}, "outcome": checked["data"],
	}
	var saved: bool = storage.write_redundant(data, new_identity)
	last_error = str(storage.last_error)
	return saved


func _storage() -> RefCounted:
	var storage = StorageScript.new()
	storage.save_path = save_path
	storage.schema_version = VERSION
	storage.max_file_bytes = MAX_FILE_BYTES
	storage.validator = _validate_envelope
	return storage


func _validate_envelope(candidate: Dictionary) -> Dictionary:
	if not _whole_number(candidate.get("version")) or int(candidate["version"]) != VERSION:
		return _invalid("Unsupported or missing battle save version.")
	var keys: Array[String] = ["version", "state", "run_id", "sequence", "snapshot", "outcome"]
	if candidate.size() != keys.size():
		return _invalid("The battle save envelope is incomplete.")
	for key: Variant in candidate:
		if key not in keys:
			return _invalid("The battle save contains an unknown envelope field.")
	if not candidate["run_id"] is String or not _valid_id(candidate["run_id"]):
		return _invalid("The battle save ID is invalid.")
	if not _whole_number(candidate["sequence"]) or float(candidate["sequence"]) < 1.0 or float(candidate["sequence"]) > MAX_SEQUENCE:
		return _invalid("The battle checkpoint sequence is invalid.")
	if not candidate["state"] is String or candidate["state"] not in ["active", "terminal"]:
		return _invalid("The battle save state is invalid.")
	if not candidate["snapshot"] is Dictionary or not candidate["outcome"] is Dictionary:
		return _invalid("The battle save payload must contain dictionaries.")
	var checked: Dictionary
	if candidate["state"] == "active":
		if not candidate["outcome"].is_empty():
			return _invalid("An active battle cannot contain a terminal outcome.")
		checked = _validate_snapshot(candidate["snapshot"])
	else:
		if not candidate["snapshot"].is_empty():
			return _invalid("A terminal battle cannot contain resumable actors.")
		checked = _validate_outcome(candidate["outcome"])
	if not checked["ok"]:
		return checked
	return {"ok": true, "data": {
		"version": VERSION, "state": candidate["state"], "run_id": candidate["run_id"],
		"sequence": int(candidate["sequence"]),
		"snapshot": checked["data"] if candidate["state"] == "active" else {},
		"outcome": checked["data"] if candidate["state"] == "terminal" else {},
	}}


func _validate_snapshot(snapshot: Dictionary) -> Dictionary:
	if not _primitive(snapshot) or not snapshot.get("mission_id") is String or not _valid_id(snapshot["mission_id"]):
		return _invalid("The battle snapshot must contain primitives and a valid mission ID.")
	if not snapshot.get("content_fingerprint") is String or snapshot["content_fingerprint"].is_empty() or snapshot["content_fingerprint"].length() > 128:
		return _invalid("The battle snapshot has no valid content fingerprint.")
	if not snapshot_validator.is_valid():
		return _invalid("The battle snapshot validator is unavailable.")
	var checked: Variant = snapshot_validator.call(snapshot.duplicate(true))
	if not checked is Dictionary or not checked.get("ok", false):
		var reason: String = str(checked.get("error", "Battle snapshot validation failed.")) if checked is Dictionary else "Battle snapshot validation failed."
		var status: String = "incompatible" if checked is Dictionary and checked.get("status") == "incompatible" else "invalid"
		return {"ok": false, "error": reason, "status": status}
	if not checked.get("data") is Dictionary or not _primitive(checked["data"]):
		return _invalid("The battle snapshot validator returned invalid data.")
	var normalized: Dictionary = checked["data"]
	if normalized.get("mission_id") != snapshot["mission_id"] or normalized.get("content_fingerprint") != snapshot["content_fingerprint"]:
		return _invalid("Battle validation cannot change mission or content identity.")
	return {"ok": true, "data": normalized.duplicate(true)}


static func _validate_outcome(outcome: Dictionary) -> Dictionary:
	if not outcome.get("kind") is String or outcome["kind"] not in ["victory", "loss", "abandoned"]:
		return _invalid("A terminal battle needs a valid outcome kind.")
	var allowed: Array = ["kind", "mission_id", "stars", "seconds"] if outcome["kind"] == "victory" else ["kind", "mission_id"]
	for key: Variant in outcome:
		if key not in allowed:
			return _invalid("The battle outcome contains an unknown field.")
	if outcome.has("mission_id") and (not outcome["mission_id"] is String or not _valid_id(outcome["mission_id"])):
		return _invalid("The battle outcome mission ID is invalid.")
	if outcome["kind"] == "victory":
		if not outcome.has("mission_id") or not _whole_number(outcome.get("stars")) or float(outcome["stars"]) < 1.0 or float(outcome["stars"]) > 3.0:
			return _invalid("A victory needs a mission ID and one to three stars.")
		if not _number(outcome.get("seconds")) or not is_finite(float(outcome["seconds"])) or float(outcome["seconds"]) <= 0.0:
			return _invalid("A victory needs a positive finite completion time.")
		return {"ok": true, "data": {"kind": "victory", "mission_id": outcome["mission_id"], "stars": int(outcome["stars"]), "seconds": float(outcome["seconds"])}}
	return {"ok": true, "data": outcome.duplicate(true)}


static func _primitive(value: Variant, depth: int = 0) -> bool:
	if depth > 24:
		return false
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT:
			return true
		TYPE_FLOAT:
			return is_finite(float(value))
		TYPE_STRING:
			return value.length() <= 4096
		TYPE_ARRAY:
			if value.size() > 8192:
				return false
			for entry: Variant in value:
				if not _primitive(entry, depth + 1):
					return false
			return true
		TYPE_DICTIONARY:
			if value.size() > 4096:
				return false
			for key: Variant in value:
				if not key is String or key.length() > 128 or not _primitive(value[key], depth + 1):
					return false
			return true
	return false


static func _valid_id(value: String) -> bool:
	return not value.strip_edges().is_empty() and value.length() <= 80 and not value.contains("\n") and not value.contains("\r")


static func _number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT


static func _whole_number(value: Variant) -> bool:
	return _number(value) and is_finite(float(value)) and floorf(float(value)) == float(value)


static func _invalid(error: String) -> Dictionary:
	return {"ok": false, "error": error, "status": "invalid"}


static func _result(status: String, data: Dictionary = {}, error: String = "") -> Dictionary:
	return {"status": status, "data": data.duplicate(true), "error": error}
