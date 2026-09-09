class_name AtomicJsonStore
extends RefCounted
## Schema-neutral persistence. Owners supply validation and retain data ownership.

var save_path: String = ""
var schema_version: int = 1
var max_file_bytes: int = 1048576
var validator: Callable
var last_error: String = ""


func load_document() -> Dictionary:
	last_error = ""
	if save_path.is_empty():
		return _result("missing")
	var primary: Dictionary = read_document(save_path)
	if primary["status"] in ["valid", "future", "incompatible"]:
		last_error = str(primary.get("error", ""))
		return primary
	var backup: Dictionary = read_document(save_path + ".bak")
	if backup["status"] in ["future", "incompatible"]:
		last_error = str(backup.get("error", ""))
		return backup
	if backup["status"] == "valid":
		last_error = "Recovered the last valid save backup."
		return _result("recovered", backup["data"], last_error)
	if primary["status"] == "missing" and backup["status"] == "missing":
		return _result("missing")
	last_error = "The save could not be loaded."
	return _result("failed", {}, last_error)


func read_document(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return _result("missing")
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _result("unreadable", {}, "An existing save could not be opened.")
	if file.get_length() > max_file_bytes:
		file.close()
		return _result("unreadable", {}, "An existing save exceeds the file size limit.")
	var text: String = file.get_as_text()
	var read_error: Error = file.get_error()
	file.close()
	if read_error != OK and read_error != ERR_FILE_EOF:
		return _result("unreadable", {}, "An existing save could not be read.")
	var parser := JSON.new()
	if parser.parse(text) != OK or not parser.data is Dictionary:
		return _result("invalid", {}, "The save is not a valid JSON object.")
	var candidate: Dictionary = parser.data
	var version: Variant = candidate.get("version")
	if _whole_number(version) and float(version) > schema_version:
		return _result("future", {}, "A newer save version exists. Its files have been preserved.")
	var checked: Dictionary = _validate(candidate)
	if not checked["ok"]:
		var status: String = str(checked.get("status", "invalid"))
		return _result(status, candidate if status == "incompatible" else {}, str(checked["error"]))
	var result: Dictionary = _result("valid", checked["data"])
	result["text"] = text
	return result


func write_document(candidate: Dictionary, replace_incompatible: bool = false) -> bool:
	last_error = ""
	var checked: Dictionary = _validate(candidate)
	if not checked["ok"]:
		last_error = str(checked["error"])
		return false
	if save_path.is_empty():
		return true
	var backup_path: String = save_path + ".bak"
	var temporary_path: String = save_path + ".tmp"
	var backup_temporary_path: String = backup_path + ".tmp"
	if DirAccess.dir_exists_absolute(save_path) or DirAccess.dir_exists_absolute(backup_path):
		last_error = "The save destination is a directory."
		return false
	var primary: Dictionary = read_document(save_path)
	var backup: Dictionary = read_document(backup_path)
	for existing: Dictionary in [primary, backup]:
		if existing["status"] == "future":
			last_error = "A newer save version exists. Saving is disabled to preserve it."
			return false
		if existing["status"] == "unreadable":
			last_error = "An existing save could not be inspected. Its file has been preserved."
			return false
		if existing["status"] == "incompatible" and not replace_incompatible:
			last_error = "An incompatible save exists. Explicit replacement is required."
			return false
	if not _write_text(temporary_path, JSON.stringify(checked["data"], "\t", true, true)):
		_remove_staging(temporary_path)
		return false
	if read_document(temporary_path)["status"] != "valid":
		last_error = "The temporary save failed verification. The previous save is unchanged."
		_remove_staging(temporary_path)
		return false
	# Never replace a valid backup with a malformed or incompatible primary.
	if primary["status"] == "valid":
		if not _write_text(backup_temporary_path, primary["text"]):
			_remove_staging(temporary_path)
			_remove_staging(backup_temporary_path)
			return false
		if read_document(backup_temporary_path)["status"] != "valid":
			last_error = "The save backup failed verification. The previous save is unchanged."
			_remove_staging(temporary_path)
			_remove_staging(backup_temporary_path)
			return false
		if DirAccess.rename_absolute(backup_temporary_path, backup_path) != OK:
			last_error = "Could not publish the save backup. The previous save is unchanged."
			_remove_staging(temporary_path)
			_remove_staging(backup_temporary_path)
			return false
	if DirAccess.rename_absolute(temporary_path, save_path) != OK:
		last_error = "Could not publish the save. Session state remains available."
		_remove_staging(temporary_path)
		_restore_missing_primary(backup_path)
		return false
	return true


func write_redundant(candidate: Dictionary, replace_incompatible: bool = false) -> bool:
	# Two successful publications make both durable copies the terminal record.
	# A failed second publication reports failure, even if primary is now terminal.
	if not write_document(candidate, replace_incompatible):
		return false
	return write_document(candidate, replace_incompatible)


func _validate(candidate: Dictionary) -> Dictionary:
	if not validator.is_valid():
		return {"ok": false, "error": "No save schema validator is available."}
	var checked: Variant = validator.call(candidate)
	if not checked is Dictionary or not checked.get("ok", false):
		return {
			"ok": false,
			"error": str(checked.get("error", "Save validation failed.")) if checked is Dictionary else "Save validation failed.",
			"status": str(checked.get("status", "invalid")) if checked is Dictionary else "invalid",
		}
	if not checked.get("data") is Dictionary:
		return {"ok": false, "error": "The save validator returned no valid data."}
	return checked


func _write_text(path: String, text: String) -> bool:
	if text.to_utf8_buffer().size() > max_file_bytes:
		last_error = "The save exceeds the file size limit."
		return false
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		last_error = "Could not open the save for writing. Session state remains available."
		return false
	file.store_string(text)
	file.flush()
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK:
		last_error = "Could not finish writing the save. Session state remains available."
		return false
	return true


func _restore_missing_primary(backup_path: String) -> void:
	if FileAccess.file_exists(save_path) or DirAccess.dir_exists_absolute(save_path):
		return
	var backup: Dictionary = read_document(backup_path)
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


static func _whole_number(value: Variant) -> bool:
	return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and is_finite(float(value)) and floorf(float(value)) == float(value)


static func _result(status: String, data: Dictionary = {}, error: String = "") -> Dictionary:
	return {"status": status, "data": data, "error": error}
