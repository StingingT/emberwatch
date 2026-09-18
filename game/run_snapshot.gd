class_name RunSnapshot
extends RefCounted
## Primitive battle snapshots. Validation finishes before the live world is touched.
const Data = preload("res://game/game_data.gd")
const MAX_COUNT: int = 1000000000

static func capture(game: Node) -> Dictionary:
	if game.state not in ["playing", "paused"]:
		return {}
	var actors: Array = []
	var ids: Dictionary = {}
	for enemy: Node3D in game.enemies:
		if not is_instance_valid(enemy) or enemy.dead or enemy.is_queued_for_deletion():
			continue
		var saved: Dictionary = enemy.capture_state()
		saved["id"] = actors.size()
		ids[enemy] = actors.size()
		actors.append(saved)
	var arrows: Array = []
	for arrow: Node3D in game._projectiles.get_children():
		if arrow.has_method("snapshot_hits"):
			if arrow.finished or arrow.is_queued_for_deletion():
				continue
			var piercing: Dictionary = arrow.capture_state()
			piercing["hit_ids"] = []
			for hit: Node3D in arrow.snapshot_hits():
				if ids.has(hit):
					piercing["hit_ids"].append(ids[hit])
			arrows.append(piercing)
			continue
		var target: Node3D = arrow.snapshot_target()
		if target == game.hero:
			var hostile: Dictionary = arrow.capture_state()
			hostile["target_id"] = -1
			arrows.append(hostile)
			continue
		if target == null or not ids.has(target):
			continue
		var saved: Dictionary = arrow.capture_state()
		saved["target_id"] = ids[target]
		arrows.append(saved)
	var piles: Array = []
	for coin: Node3D in game._coins.get_children():
		if coin.snapshot_available():
			piles.append(coin.capture_state())
	var structures: Array = []
	for building: Node3D in game.buildings.values():
		if is_instance_valid(building) and not building.dead and not building.is_queued_for_deletion():
			structures.append(building.capture_state())
	return {"mission_id": game.missions[game.mission_index]["id"],
		"content_fingerprint": fingerprint(game.missions[game.mission_index]),
		"coins": game.coins, "coins_collected": game.coins_collected, "kills": game.kills,
		"keep_health": game.keep_health, "smith_levels": game.smith_levels.duplicate(),
		"elapsed": game.elapsed, "used_volley": game._used_volley,
		"last_keep_warning": game._last_keep_warning, "run_start": vector(game._run_start),
		"camera_focus": vector(game._camera_focus), "wave_index": game.wave_index,
		"wave_cursor": game.wave_cursor, "wave_active": game.wave_active, "wave_timer": game.wave_timer,
		"hero": game.hero.capture_state(), "enemies": actors, "arrows": arrows,
		"coins_on_ground": piles, "buildings": structures}

static func validate(saved: Dictionary, missions: Array[Dictionary]) -> Dictionary:
	if not keys(saved, ["mission_id", "content_fingerprint", "coins", "coins_collected", "kills",
		"keep_health", "smith_levels", "elapsed", "used_volley", "last_keep_warning", "run_start",
		"camera_focus", "wave_index", "wave_cursor", "wave_active", "wave_timer", "hero", "enemies",
		"arrows", "coins_on_ground", "buildings"]):
		return invalid("The battle snapshot has missing or unknown fields.")
	if not saved["mission_id"] is String or not saved["content_fingerprint"] is String:
		return invalid("The battle identity is invalid.")
	var mission: Dictionary = {}
	for candidate: Dictionary in missions:
		if candidate["id"] == saved["mission_id"]:
			mission = candidate
			break
	if mission.is_empty() or saved["content_fingerprint"] != fingerprint(mission):
		return {"ok": false, "status": "incompatible", "error": "This defense belongs to different mission or balance data. Start a new defense to continue playing."}
	var level: Dictionary = mission["level"]
	var waves: Array = mission["waves"]
	var bounds: Rect2 = level["bounds"]
	for key: String in ["coins", "coins_collected", "kills"]:
		if not integer(saved[key], 0, MAX_COUNT):
			return invalid("Invalid battle counters.")
	if not number(saved["elapsed"], 0.0, MAX_COUNT) or not number(saved["last_keep_warning"], -MAX_COUNT, MAX_COUNT):
		return invalid("Invalid battle timing.")
	if not saved["used_volley"] is bool or not saved["wave_active"] is bool:
		return invalid("Invalid battle flags.")
	if not position(saved["run_start"], bounds) or not position(saved["camera_focus"], bounds.grow(5.0)):
		return invalid("Invalid battle view position.")
	if not keys(saved["smith_levels"], ["ranged", "haste", "fortify"]):
		return invalid("Invalid Smith upgrades.")
	for value: Variant in saved["smith_levels"].values():
		if not integer(value, 0, 5000):
			return invalid("Invalid Smith upgrade level.")
	var fortification: float = 1.0 + float(saved["smith_levels"]["fortify"]) * float(Data.SMITH["fortify"]["step"])
	var keep_max: float = float(level.get("keep_health", Data.KEEP_HEALTH)) * fortification
	if not number(saved["keep_health"], 0.000001, keep_max + 0.001):
		return invalid("Invalid Keep health.")
	if not integer(saved["wave_index"], -1, waves.size() - 1) or not integer(saved["wave_cursor"], 0, 10000) or not number(saved["wave_timer"], -MAX_COUNT, MAX_COUNT):
		return invalid("Invalid wave timing or cursor.")
	for key: String in ["enemies", "arrows", "coins_on_ground", "buildings"]:
		var limit: int = 512 if key == "enemies" else (level["plots"].size() if key == "buildings" else 2048)
		if not saved[key] is Array or saved[key].size() > limit:
			return invalid("The battle actor list is invalid or too large.")
	var wave_index: int = int(saved["wave_index"])
	var cursor: int = int(saved["wave_cursor"])
	var spawned: int = cursor
	for index: int in range(maxi(0, wave_index)):
		spawned += waves[index]["enemies"].size()
	if wave_index == -1:
		if cursor != 0 or saved["wave_active"] or not saved["enemies"].is_empty():
			return invalid("Preparation contains an active wave.")
	else:
		if cursor > waves[wave_index]["enemies"].size():
			return invalid("The wave spawn cursor exceeds its roster.")
		if not saved["wave_active"] and (cursor != waves[wave_index]["enemies"].size() or not saved["enemies"].is_empty()):
			return invalid("An unfinished wave cannot be between waves.")
	if int(saved["kills"]) + saved["enemies"].size() != spawned:
		return invalid("Spawned and surviving enemy counts do not agree.")
	var hero: Variant = saved["hero"]
	if not keys(hero, ["position", "tier", "xp", "choices", "ability_cooldown", "shot_remaining", "facing", "health", "respawn_remaining", "protection_remaining"]):
		return invalid("Invalid archer fields.")
	if not number(hero["health"], 0, float(Data.HERO["health"])) or not number(hero["respawn_remaining"], 0, float(Data.HERO["respawn_seconds"])) or not number(hero["protection_remaining"], 0, float(Data.HERO["protection_seconds"])):
		return invalid("Invalid archer health or respawn timers.")
	if (float(hero["health"]) == 0.0) != (float(hero["respawn_remaining"]) > 0.0):
		return invalid("Archer life state and respawn timer disagree.")
	var thresholds: Array = Data.HERO["xp_thresholds"]
	# Rect2.grow/end and the runtime scalar clamp round differently at float32
	# edges. Accept the real clamped position without moving it during restoration.
	var walking_bounds: Rect2 = bounds.grow(-float(Data.FOOTPRINTS["hero_margin"])).grow(0.00001)
	if not position(hero["position"], walking_bounds) or not integer(hero["tier"], 1, thresholds.size() + 1):
		return invalid("Invalid archer position or level.")
	var hero_position: Vector3 = to_vector(hero["position"])
	if hero_position.distance_squared_to(level["keep"]) < float(Data.FOOTPRINTS["keep_radius_squared"]):
		return invalid("The archer cannot be restored inside the Keep.")
	var tier: int = int(hero["tier"])
	if not keys(hero["choices"], ["multishot", "volley", "piercing"]):
		return invalid("Invalid hero choices.")
	var spent_choices: int = 0
	for rank: Variant in hero["choices"].values():
		if not integer(rank, 0, thresholds.size()):
			return invalid("Invalid hero choice rank.")
		spent_choices += int(rank)
	if spent_choices > tier - 1:
		return invalid("Hero choices exceed earned levels.")
	var max_xp: float = float(thresholds[tier - 1]) if tier <= thresholds.size() else 0.0
	if tier <= thresholds.size() and number(hero["xp"], max_xp, MAX_COUNT):
		return invalid("Unprocessed archer level-up.")
	if not number(hero["xp"], 0, max_xp) or not number(hero["ability_cooldown"], 0, float(Data.HERO["ability_cooldown"]) + 0.001) or not number(hero["shot_remaining"], 0, float(Data.HERO["attack_interval"]) + 0.001) or not number(hero["facing"], -MAX_COUNT, MAX_COUNT):
		return invalid("Invalid archer XP or cooldowns.")
	var enemy_ids: Dictionary = {}
	for enemy: Variant in saved["enemies"]:
		if not keys(enemy, ["id", "position", "kind", "health", "max_health", "route_index", "attack_remaining", "facing", "hero_windup", "hero_aim"]):
			return invalid("Invalid enemy fields.")
		if not number(enemy["hero_windup"], 0, float(Data.HERO_THREAT["windup"])) or not position(enemy["hero_aim"], bounds):
			return invalid("Invalid enemy hero attack.")
		if not integer(enemy["id"], 0, 511) or enemy_ids.has(int(enemy["id"])) or not enemy["kind"] is String or not Data.ENEMIES.has(enemy["kind"]):
			return invalid("Invalid or duplicate enemy identity.")
		enemy_ids[int(enemy["id"])] = true
		var spec: Dictionary = Data.ENEMIES[enemy["kind"]]
		var maximum: float = float(spec["health"]) * float(waves[wave_index]["health_scale"])
		if not number(enemy["max_health"], maximum - 0.001, maximum + 0.001) or not number(enemy["health"], 0.000001, maximum + 0.001):
			return invalid("Invalid enemy health or wave scaling.")
		if not position(enemy["position"], bounds.grow(1.0)) or not integer(enemy["route_index"], 0, level["route"].size()) or not number(enemy["attack_remaining"], 0, float(spec["attack_interval"]) + 0.001) or not number(enemy["facing"], -MAX_COUNT, MAX_COUNT):
			return invalid("Invalid enemy route or attack timing.")
	for arrow: Variant in saved["arrows"]:
		if arrow is Dictionary and arrow.get("source") == "piercing":
			if not keys(arrow, ["source", "position", "direction", "damage", "distance_left", "remaining_hits", "hit_ids"]):
				return invalid("Invalid piercing arrow fields.")
			if not position(arrow["position"], bounds.grow(15.0), 2.0) or not position(arrow["direction"], Rect2(-1, -1, 2, 2)) or not number(arrow["damage"], 0.000001, MAX_COUNT) or not number(arrow["distance_left"], 0.000001, 12.001) or not integer(arrow["remaining_hits"], 1, 8):
				return invalid("Invalid piercing arrow motion.")
			if absf(to_vector(arrow["direction"]).length() - 1.0) > 0.001 or not arrow["hit_ids"] is Array or arrow["hit_ids"].size() > 8:
				return invalid("Invalid piercing arrow history.")
			var seen: Dictionary = {}
			for hit: Variant in arrow["hit_ids"]:
				if not integer(hit, 0, 511) or not enemy_ids.has(int(hit)) or seen.has(int(hit)):
					return invalid("Invalid piercing target history.")
				seen[int(hit)] = true
			continue
		if arrow is Dictionary and arrow.get("source") == "enemy":
			if not keys(arrow, ["target_id", "position", "destination", "damage", "source", "speed", "lifetime"]):
				return invalid("Invalid hostile projectile fields.")
			if not integer(arrow["target_id"], -1, -1) or not position(arrow["position"], bounds.grow(1.0), 2.0) or not position(arrow["destination"], bounds, 2.0) or not number(arrow["damage"], 0.000001, MAX_COUNT) or not number(arrow["speed"], 9.0, 9.0) or not number(arrow["lifetime"], 0.0, 2.001):
				return invalid("Invalid hostile projectile motion.")
			continue
		if not keys(arrow, ["target_id", "position", "damage", "source", "speed", "lifetime"]):
			return invalid("Invalid projectile fields.")
		if not integer(arrow["target_id"], 0, 511) or not enemy_ids.has(int(arrow["target_id"])) or not arrow["source"] is String or arrow["source"] not in ["hero", "tower"]:
			return invalid("A projectile has an invalid target or damage source.")
		if not position(arrow["position"], bounds.grow(5.0), 16.0) or not number(arrow["damage"], 0.000001, MAX_COUNT) or not number(arrow["speed"], 1.0, 1000.0) or not number(arrow["lifetime"], 0.0, 4.001):
			return invalid("Invalid projectile motion or damage.")
	for coin: Variant in saved["coins_on_ground"]:
		if not keys(coin, ["position", "value", "magnetized", "magnet_speed", "age", "phase"]):
			return invalid("Invalid gold pile fields.")
		if not position(coin["position"], bounds.grow(3.0)) or not integer(coin["value"], 1, MAX_COUNT) or not coin["magnetized"] is bool or not number(coin["magnet_speed"], 3.0, 20.001) or not number(coin["age"], 0.0, MAX_COUNT) or not number(coin["phase"], 0.0, TAU + 0.001):
			return invalid("Invalid gold value or collection motion.")
	var occupied: Dictionary = {}
	var counts: Dictionary = {}
	for building: Variant in saved["buildings"]:
		if not keys(building, ["plot_id", "kind", "tier", "health", "cooldown"]):
			return invalid("Invalid building fields.")
		if not building["plot_id"] is String or not building["kind"] is String or not Data.BUILDINGS.has(building["kind"]) or occupied.has(building["plot_id"]):
			return invalid("Invalid or duplicate building identity.")
		var spec: Dictionary = Data.BUILDINGS[building["kind"]]
		var plot: Dictionary = {}
		for candidate: Dictionary in level["plots"]:
			if candidate["id"] == building["plot_id"]:
				plot = candidate
		if plot.is_empty() or plot["category"] != spec["category"] or not integer(building["tier"], 1, int(spec["max_level"])):
			return invalid("Invalid building location or tier.")
		if Data.building_footprint_contains(hero_position, plot["position"], str(building["kind"])):
			return invalid("The archer cannot be restored inside a structure.")
		occupied[building["plot_id"]] = true
		counts[building["kind"]] = int(counts.get(building["kind"], 0)) + 1
		var limit: int = int(level.get("building_limits", {}).get(building["kind"], spec["limit"]))
		var maximum: float = float(spec["health"][int(building["tier"]) - 1]) * (fortification if building["kind"] == "wall" else 1.0)
		if counts[building["kind"]] > limit or not number(building["health"], 0.000001, maximum + 0.001) or not number(building["cooldown"], -MAX_COUNT, MAX_COUNT):
			return invalid("Invalid building limit, health or timing.")
	return {"ok": true, "data": saved.duplicate(true), "error": ""}

static func fingerprint(mission: Dictionary) -> String:
	var level: Dictionary = mission["level"].duplicate(true)
	level.erase("palette")
	level.erase("name")
	var waves: Array = mission["waves"].duplicate(true)
	for wave: Dictionary in waves:
		wave.erase("name")
	var buildings: Dictionary = Data.BUILDINGS.duplicate(true)
	for spec: Dictionary in buildings.values():
		spec.erase("name")
		spec.erase("description")
	var smith: Dictionary = Data.SMITH.duplicate(true)
	for spec: Dictionary in smith.values():
		spec.erase("name")
		spec.erase("description")
	return JSON.stringify(primitives({"mission_id": mission["id"], "level": level, "waves": waves,
		"hero": Data.HERO, "hero_threat": Data.HERO_THREAT, "enemies": Data.ENEMIES, "buildings": buildings, "smith": smith,
		"smith_pricing": Data.SMITH_PRICING, "starting_coins": Data.STARTING_COINS,
		"keep_health": Data.KEEP_HEALTH, "build_radius": Data.BUILD_RADIUS,
		"preparation": Data.PREPARATION_TIME, "between_waves": Data.BETWEEN_WAVES,
		"stars": Data.STAR_HEALTH_THRESHOLDS, "footprints": Data.FOOTPRINTS})).sha256_text()

static func primitives(value: Variant) -> Variant:
	if value is Vector3:
		return vector(value)
	if value is Rect2:
		return [value.position.x, value.position.y, value.size.x, value.size.y]
	if value is Dictionary:
		var result: Dictionary = {}
		var ordered: Array = value.keys()
		ordered.sort()
		for key: Variant in ordered:
			result[key] = primitives(value[key])
		return result
	if value is Array:
		var result: Array = []
		for item: Variant in value:
			result.append(primitives(item))
		return result
	return value

static func vector(value: Vector3) -> Array:
	return [value.x, value.y, value.z]

static func to_vector(value: Array) -> Vector3:
	return Vector3(float(value[0]), float(value[1]), float(value[2]))

static func keys(value: Variant, required: Array) -> bool:
	if not value is Dictionary or value.size() != required.size():
		return false
	for key: Variant in required:
		if not value.has(key):
			return false
	return true

static func number(value: Variant, minimum: float, maximum: float) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and float(value) >= minimum and float(value) <= maximum

static func integer(value: Variant, minimum: int, maximum: int) -> bool:
	return number(value, minimum, maximum) and floorf(float(value)) == float(value)

static func position(value: Variant, bounds: Rect2, height: float = 0.001) -> bool:
	return value is Array and value.size() == 3 and number(value[0], bounds.position.x, bounds.end.x) and number(value[1], -0.001, height) and number(value[2], bounds.position.y, bounds.end.y)

static func invalid(message: String) -> Dictionary:
	return {"ok": false, "status": "invalid", "error": message}
