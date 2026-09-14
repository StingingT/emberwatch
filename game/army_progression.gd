class_name ArmyProgression
extends RefCounted
## One additive offline ledger; existing campaign/settings files stay untouched.
## Each run stores its greatest rewarded wave count and one terminal result.
const Rules = preload("res://game/army_data.gd")
const Storage = preload("res://game/atomic_json_store.gd")
const VERSION: int = 1
const MAX_RUNS: int = 20000
var save_path: String = "user://emberwatch_army.json"
var last_error: String = ""
var read_only: bool = false
var data: Dictionary = defaults()

static func defaults() -> Dictionary:
	return {"version": VERSION, "supplies": 0, "ranks": {}, "achievements": {}, "first_clears": {}, "runs": {}}

func load_progression() -> void:
	data = defaults()
	last_error = ""
	read_only = false
	if save_path.is_empty():
		return
	var store: RefCounted = _storage()
	var loaded: Dictionary = store.load_document()
	last_error = str(loaded.get("error", ""))
	if loaded["status"] in ["valid", "recovered"]:
		data = loaded["data"]
	elif loaded["status"] != "missing":
		# Do not replace unreadable or newer player progress with defaults.
		read_only = true

func seed_completed_missions(results: Dictionary) -> void:
	# Existing players keep their stars and do not re-earn historical first-clear bonuses.
	var next: Dictionary = data.duplicate(true)
	for id: String in results:
		next["first_clears"][id] = true
	if next != data:
		_commit(next)

func _storage() -> RefCounted:
	var store: RefCounted = Storage.new()
	store.save_path = save_path
	store.schema_version = VERSION
	store.max_file_bytes = 8388608
	store.validator = func(value: Dictionary) -> Dictionary: return validate(value)
	return store

func _commit(candidate: Dictionary) -> bool:
	if read_only:
		return false
	var checked: Dictionary = validate(candidate)
	if not checked["ok"]:
		last_error = str(checked["error"])
		return false
	# Like the existing profile, preserve session progress on an IO failure.
	data = checked["data"]
	last_error = ""
	if save_path.is_empty():
		return true
	var store: RefCounted = _storage()
	var saved: bool = store.write_document(data)
	last_error = store.last_error
	return saved

func purchase(id: String, total_stars: int) -> bool:
	if read_only or not Rules.UPGRADES.has(id):
		return false
	var rank: int = Rules.rank_of(data["ranks"], id)
	if rank >= Rules.MAX_RANK or total_stars < Rules.STAR_GATES[rank] or int(data["supplies"]) < Rules.COSTS[rank]:
		return false
	var next: Dictionary = data.duplicate(true)
	next["supplies"] -= Rules.COSTS[rank]
	next["ranks"][id] = rank + 1
	_commit(next)
	return true

func record_progress(run_id: String, mission_id: String, mission_index: int, cleared: int, outcome: String = "active", earned_stars: int = 0, seconds: float = 0.0) -> Dictionary:
	if read_only or not _id(run_id) or not _id(mission_id) or mission_index < 0 or mission_index > 255 or cleared < 0 or cleared > 10000 or outcome not in ["active", "victory", "loss"]:
		return {}
	if outcome == "victory" and (earned_stars < 1 or earned_stars > 3 or not is_finite(seconds) or seconds <= 0):
		return {}
	var existing: Dictionary = data["runs"].get(run_id, {})
	if not existing.is_empty():
		if existing["mission_id"] != mission_id or int(existing["mission_index"]) != mission_index:
			return {}
		if existing["outcome"] != "active":
			return existing.duplicate(true)
	elif data["runs"].size() >= MAX_RUNS:
		last_error = "The army reward ledger is full. Existing progress is preserved."
		return {}
	var next: Dictionary = data.duplicate(true)
	var record: Dictionary = existing.duplicate(true) if not existing.is_empty() else {
		"mission_id": mission_id, "mission_index": mission_index, "cleared": 0,
		"normal": 0, "outcome": "active", "stars": 0, "seconds": 0.0, "ad_claimed": false,
	}
	record["cleared"] = maxi(cleared, int(record["cleared"]))
	var normal: int = Rules.wave_supplies(mission_index, int(record["cleared"]))
	if outcome == "victory":
		var first: bool = not next["first_clears"].has(mission_id)
		normal += Rules.victory_supplies(mission_index, earned_stars, first)
		next["first_clears"][mission_id] = true
		record["stars"] = earned_stars
		record["seconds"] = seconds
	record["outcome"] = outcome
	next["supplies"] += maxi(0, normal - int(record["normal"]))
	record["normal"] = maxi(normal, int(record["normal"]))
	next["runs"][run_id] = record
	if existing != record:
		_commit(next)
	return record.duplicate(true)

func collect_achievements(results: Dictionary) -> int:
	if read_only:
		return 0
	var next: Dictionary = data.duplicate(true)
	var awarded: int = 0
	for definition: Dictionary in Rules.ACHIEVEMENTS:
		var id: String = definition["id"]
		var current: int = Rules.stars(results) if definition["metric"] == "stars" else results.size()
		if current >= int(definition["target"]) and not next["achievements"].has(id):
			next["achievements"][id] = true
			awarded += int(definition["reward"])
	if awarded > 0:
		next["supplies"] += awarded
		_commit(next)
	return awarded

func claim_ad_bonus(run_id: String) -> int:
	# Called only from an ad provider's verified completion callback, not UI clicks.
	if read_only or not data["runs"].has(run_id):
		return 0
	var record: Dictionary = data["runs"][run_id]
	if record["outcome"] == "active" or bool(record["ad_claimed"]):
		return 0
	var bonus: int = Rules.ad_bonus(int(record["normal"]))
	if bonus <= 0:
		return 0
	var next: Dictionary = data.duplicate(true)
	next["runs"][run_id]["ad_claimed"] = true
	next["supplies"] += bonus
	_commit(next)
	return bonus

static func _id(value: Variant) -> bool:
	return value is String and not value.strip_edges().is_empty() and value.length() <= 96 and not value.contains("\n") and not value.contains("\r")

static func validate(candidate: Dictionary) -> Dictionary:
	if candidate.size() != 6 or not Rules.whole(candidate.get("version"), VERSION) or int(candidate["version"]) != VERSION:
		return _invalid("Unsupported army profile version or fields.")
	for key: String in ["supplies", "ranks", "achievements", "first_clears", "runs"]:
		if not candidate.has(key):
			return _invalid("Missing army profile field.")
	# There are six top-level fields; rejecting extras prevents silent data loss.
	return _validate_fields(candidate)

static func _validate_fields(candidate: Dictionary) -> Dictionary:
	if not Rules.whole(candidate["supplies"]) or not Rules.valid_ranks(candidate["ranks"]):
		return _invalid("Invalid Supplies or training ranks.")
	for key: String in ["achievements", "first_clears", "runs"]:
		if not candidate[key] is Dictionary or candidate[key].size() > MAX_RUNS:
			return _invalid("Invalid army ledger.")
	var achievement_ids: Array[String] = []
	for definition: Dictionary in Rules.ACHIEVEMENTS:
		achievement_ids.append(str(definition["id"]))
	for id: Variant in candidate["achievements"]:
		if id not in achievement_ids:
			return _invalid("Unknown achievement ID; preserve this profile for a compatible build.")
	for key: String in ["achievements", "first_clears"]:
		for id: Variant in candidate[key]:
			if not _id(id) or candidate[key][id] != true or not candidate[key][id] is bool:
				return _invalid("Invalid permanent award.")
	for id: Variant in candidate["runs"]:
		var record: Variant = candidate["runs"][id]
		if not _id(id) or not record is Dictionary or record.size() != 8:
			return _invalid("Invalid run receipt.")
		for key: String in ["mission_id", "mission_index", "cleared", "normal", "outcome", "stars", "seconds", "ad_claimed"]:
			if not record.has(key):
				return _invalid("Incomplete run receipt.")
		if not _id(record["mission_id"]) or not Rules.whole(record["mission_index"], 255) or not Rules.whole(record["cleared"], 10000) or not Rules.whole(record["normal"]) or not Rules.whole(record["stars"], 3):
			return _invalid("Invalid run reward counters.")
		if record["outcome"] not in ["active", "victory", "loss"] or not record["ad_claimed"] is bool:
			return _invalid("Invalid reward state.")
		var seconds: Variant = record["seconds"]
		if not (typeof(seconds) == TYPE_INT or typeof(seconds) == TYPE_FLOAT) or not is_finite(float(seconds)) or float(seconds) < 0:
			return _invalid("Invalid completion time.")
		if record["outcome"] == "victory" and (int(record["stars"]) < 1 or float(seconds) <= 0):
			return _invalid("Invalid victory receipt.")
		if record["outcome"] == "active" and record["ad_claimed"]:
			return _invalid("An active battle cannot claim an ad reward.")
	return {"ok": true, "data": candidate.duplicate(true)}

static func _invalid(message: String) -> Dictionary:
	return {"ok": false, "error": message}
