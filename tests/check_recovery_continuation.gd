extends SceneTree
## Semantic recovery proof, not balance evidence. Fixture grants end before the
## comparison. Both real roots then receive identical input and cosmetic RNG.
## No player files: profile persistence is disabled before either root enters.
## godot --headless --path . --script tests/check_recovery_continuation.gd --fixed-fps 60

const GameScript = preload("res://game/game.gd")
const Data = preload("res://game/game_data.gd")
const STEP: float = 1.0 / 60.0
const STEPS: int = 1200
const EPSILON: float = 0.0002

var _original: Node3D
var _restored: Node3D
var _checks: int = 0
var _failures: Array[String] = []
var _boundary_checked: bool = false
var _initial_gold: int = 0
var _initial_kills: int = 0
var _initial_xp: int = 0
var _initial_wave: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	seed(726031)
	_original = _new_game()
	_prepare_busy_fixture()
	_freeze(_original)
	await process_frame
	_original.pause_run()
	var initial: Dictionary = _original.capture_run_snapshot()
	var validation: Dictionary = _original.validate_run_snapshot(initial)
	_check(bool(validation.get("ok", false)), "busy wave fixture passes the real snapshot validator: " + str(validation.get("error", "")))
	_check(initial["kills"] == 1 and initial["enemies"].size() == 7 and initial["wave_cursor"] == 8, "busy fixture obeys killed plus live equals spawned")
	_check(initial["arrows"].size() >= 4 and _has_source(initial["arrows"], "hero") and _has_source(initial["arrows"], "tower"), "busy snapshot contains hero, tower and actual Volley arrows")
	_check(initial["hero"]["tier"] >= 2 and float(initial["hero"]["ability_cooldown"]) > 0.0 and float(initial["hero"]["shot_remaining"]) > 0.0, "busy snapshot contains earned hero progression and attack timers")
	_check(_has_close_distinct_piles(initial["coins_on_ground"]), "busy snapshot includes nearby distinct gold piles that must not merge during restoration")
	_initial_gold = _original.coins
	_initial_kills = _original.kills
	_initial_xp = _total_xp(_original.hero)
	_initial_wave = _original.wave_index
	_restored = _new_game()
	if not _restore_json(_restored, initial, "initial busy snapshot"):
		await _finish()
		return
	_compare("initial paused restoration")
	_original.resume_run()
	_restored.resume_run()
	for frame: int in range(STEPS):
		# Newly generated coin phases are cosmetic global randf consumers. Give
		# both worlds the same random stream without replacing any game action.
		seed(910000 + frame)
		_step_game(_original, frame)
		seed(910000 + frame)
		_step_game(_restored, frame)
		_freeze(_original)
		_freeze(_restored)
		await process_frame
		if not _compare("continuation step %d" % frame):
			break
		if not _boundary_checked and _original.kills > _initial_kills and _original.coins > _initial_gold and not _original.buildings.has("gate"):
			await _check_consumed_boundary(frame)
			if not _failures.is_empty():
				break
		if frame % 300 == 299:
			print("RECOVERY_CONTINUATION checkpoint %.1fs: wave=%d kills=%d gold=%d live=%d" % [float(frame + 1) * STEP, _original.wave_index + 1, _original.kills, _original.coins, _original.enemies.size()])
	_check(_boundary_checked, "comparison crossed and restored a consumed kill, pickup and destroyed-wall boundary")
	_check(_original.kills > _initial_kills and _total_xp(_original.hero) > _initial_xp, "continued real combat earned kills and hero XP")
	_check(_original.coins > _initial_gold and _original.coins_collected > 0, "continued movement collected physical gold without fixture grants")
	_check(_original.buildings["quarry"].cooldown > 0.0, "the due mine resumed its production cycle")
	_check(_original.wave_index > _initial_wave, "continued play crossed an authored wave boundary")
	_check(_original.state == "playing" and _restored.state == "playing", "both continuations remain active battles")
	_original.pause_run()
	_restored.pause_run()
	_compare("stable paused checkpoint after continuation")
	var stable: Dictionary = _original.capture_run_snapshot()
	_check(bool(_original.validate_run_snapshot(stable).get("ok", false)), "stable checkpoint remains a valid recoverable battle")
	# A final fresh reconstruction proves the mature checkpoint, not just the
	# prepared fixture, can be loaded without replaying already consumed effects.
	var final_copy: Node3D = _new_game()
	if _restore_json(final_copy, stable, "stable progressed checkpoint"):
		var difference: String = _difference(stable, final_copy.capture_run_snapshot(), "stable")
		_check(difference.is_empty(), "stable checkpoint restores all ordered actor and run state: " + difference)
	final_copy.queue_free()
	await _finish()

func _new_game() -> Node3D:
	var game: Node3D = GameScript.new()
	game.persistent_profile = false
	root.add_child(game)
	_freeze(game)
	game.change_setting("sound", false)
	game.change_setting("reduced_motion", true)
	game.change_setting("tutorial_hints", false)
	_check(game.profile.save_path.is_empty(), "comparison root disables player-profile persistence")
	return game

func _prepare_busy_fixture() -> void:
	_check(_original.start_mission("briarwood"), "fixture starts the actual first mission")
	_freeze(_original)
	_original.coins = 2000
	_purchase("forge", "smith", 2)
	_original.selected_plot = _original._plot_by_id("forge")
	for modifier: String in ["ranged", "haste", "fortify"]:
		_original.buy_smith_upgrade(modifier)
	_check(_original.smith_levels == {"ranged": 1, "haste": 1, "fortify": 1}, "fixture applies Smith upgrades through real purchases")
	_purchase("crossing", "tower", 2)
	_purchase("gate", "wall", 2)
	_purchase("quarry", "mine", 2)
	_original.buildings["gate"].take_damage(_original.buildings["gate"].max_health - 7.0)
	_original.buildings["quarry"].cooldown = 0.15
	_original.damage_keep(31.0)
	_original.hero.position = Vector3(-4.8, 0, -10.5)
	_original.wave_index = 0
	_original.wave_active = true
	_original.wave_cursor = 8
	_original.wave_timer = -0.375
	_original.elapsed = 22.5
	var points: Array[Vector3] = [Vector3(-4, 0, -12), Vector3(-3, 0, -9.5), Vector3(-3, 0, -12), Vector3(-1.7, 0, -13), Vector3(-4, 0, -15), Vector3(-1, 0, -17), Vector3(0, 0, 2.8), Vector3(0, 0, -27)]
	var indices: Array[int] = [3, 4, 3, 3, 3, 3, 6, 1]
	for index: int in range(points.size()):
		var enemy: Node3D = _original.spawn_enemy("goblin", float(_original.wave_configs[0]["health_scale"]))
		enemy.set_physics_process(false)
		enemy.position = points[index]
		enemy.route_index = indices[index]
		enemy._attack_remaining = 0.125 + float(index % 3) * 0.1
		if index == 0:
			enemy.take_damage(1000.0, "hero")
		elif index == 1:
			enemy.take_damage(12.0, "hero")
	_original.hero.add_xp(21)
	while _original.hero.pending_choices() > 0:
		_original.hero.choose_upgrade("volley")
	_original.hero._physics_process(0.01)
	_original.buildings["crossing"]._physics_process(0.3)
	_original.use_ability()
	_original.drop_coin(Vector3(-7, 0, -10.5), 13)
	_original.drop_coin(Vector3(-5.5, 0, -8.5), 17)
	var piles: Array[Node] = _original._coins.get_children()
	var first: Node3D = piles[piles.size() - 2]
	var second: Node3D = piles[piles.size() - 1]
	first._magnetized = true
	first._magnet_speed = 11.5
	first._age = 0.41
	second.position = first.position + Vector3(0, 0, 0.6)
	second._age = 0.25
	_original._camera_focus = _original.hero.position + Vector3(0, 0, -2)
	_freeze(_original)

func _purchase(id: String, kind: String, tier: int) -> void:
	_original.hero.position = _original._plot_by_id(id)["position"]
	_check(_original.build_at(id, kind), "fixture purchases " + kind)
	for level: int in range(1, tier):
		_check(_original.upgrade_at(id), "fixture upgrades %s to tier %d" % [kind, level + 1])
	_freeze(_original)

func _restore_json(game: Node3D, saved: Dictionary, label: String) -> bool:
	var parsed: Variant = JSON.parse_string(JSON.stringify(saved))
	_check(parsed is Dictionary, label + " completes a JSON primitive round trip")
	if not parsed is Dictionary:
		return false
	var validation: Dictionary = game.validate_run_snapshot(parsed)
	_check(bool(validation.get("ok", false)), label + " validates in a fresh root: " + str(validation.get("error", "")))
	if not bool(validation.get("ok", false)):
		return false
	var restored: bool = game.restore_run_snapshot(parsed)
	_freeze(game)
	_check(restored and game.state == "paused", label + " restores paused without simulating or resetting time")
	return restored

func _step_game(game: Node3D, frame: int) -> void:
	_freeze(game)
	game.hud._stick.direction = _movement_at(float(frame) * STEP)
	if frame in [780, 960]:
		game.use_ability()
	game._physics_process(STEP)
	while game.hero.pending_choices() > 0:
		game.offer_hero_choice()
		game.choose_hero_upgrade("volley")
	# Match the root's scene-tree processing order: Actors (hero then enemies),
	# Projectiles, Coins, Structures. Each container snapshot is taken at its
	# turn, so newly emitted actors participate in the same order in both roots.
	for container: Node3D in [game._actors, game._projectiles, game._coins, game._structures]:
		for actor: Node in container.get_children():
			if actor.is_queued_for_deletion() or not actor.has_method("_physics_process"):
				continue
			actor.set_physics_process(false)
			actor.call("_physics_process", STEP)
	_freeze(game)

func _movement_at(seconds: float) -> Vector2:
	if seconds < 0.6:
		return Vector2.ZERO
	if seconds < 1.3:
		return Vector2.LEFT
	if seconds < 4.3:
		return Vector2.DOWN
	if seconds < 5.5:
		return Vector2.RIGHT
	if seconds < 10.3:
		return Vector2.UP
	if seconds < 11.3:
		return Vector2.RIGHT
	if seconds < 14.3:
		return Vector2.DOWN
	if seconds < 17.3:
		return Vector2.UP
	return Vector2.ZERO

func _check_consumed_boundary(frame: int) -> void:
	_boundary_checked = true
	_original.pause_run()
	_restored.pause_run()
	var boundary: Dictionary = _original.capture_run_snapshot()
	_check(boundary["kills"] > _initial_kills and boundary["coins_collected"] > 0, "boundary snapshot records already awarded kills and collected gold")
	var contains_gate: bool = false
	for building: Dictionary in boundary["buildings"]:
		contains_gate = contains_gate or building["plot_id"] == "gate"
	_check(not contains_gate and _original.plot_views["gate"].visible, "boundary snapshot excludes a destroyed wall and exposes its plot")
	var replacement: Node3D = _new_game()
	if not _restore_json(replacement, boundary, "consumed boundary"):
		replacement.queue_free()
		return
	_restored.queue_free()
	_restored = replacement
	await process_frame
	_compare("consumed kill/pickup/wall boundary at step %d" % frame)
	_check(_restored.plot_views["gate"].visible and not _restored.buildings.has("gate"), "restored destroyed-wall plot stays available without rebuilding the wall")
	_original.resume_run()
	_restored.resume_run()
	print("RECOVERY_CONTINUATION consumed boundary at %.3fs: kills=%d collected=%d wall_absent=true" % [float(frame + 1) * STEP, _original.kills, _original.coins_collected])

func _compare(label: String) -> bool:
	var difference: String = _difference(_original.capture_run_snapshot(), _restored.capture_run_snapshot(), "run")
	_check(_original.state == _restored.state and difference.is_empty(), label + ": " + difference)
	return difference.is_empty() and _original.state == _restored.state

func _difference(left: Variant, right: Variant, path: String) -> String:
	if left is Dictionary and right is Dictionary:
		if left.size() != right.size():
			return path + " dictionary sizes differ"
		for key: Variant in left:
			if not right.has(key):
				return path + " missing " + str(key)
			var mismatch: String = _difference(left[key], right[key], path + "." + str(key))
			if not mismatch.is_empty():
				return mismatch
		return ""
	if left is Array and right is Array:
		if left.size() != right.size():
			return "%s ordered counts differ (%d/%d)" % [path, left.size(), right.size()]
		for index: int in range(left.size()):
			var mismatch: String = _difference(left[index], right[index], path + "[%d]" % index)
			if not mismatch.is_empty():
				return mismatch
		return ""
	if (left is int or left is float) and (right is int or right is float):
		if absf(float(left) - float(right)) > EPSILON:
			return "%s differs: %.9f / %.9f" % [path, float(left), float(right)]
		return ""
	return "" if left == right else "%s differs: %s / %s" % [path, str(left), str(right)]

func _has_source(arrows: Array, source: String) -> bool:
	for arrow: Dictionary in arrows:
		if arrow["source"] == source:
			return true
	return false

func _has_close_distinct_piles(piles: Array) -> bool:
	for first: int in range(piles.size()):
		for second: int in range(first + 1, piles.size()):
			var a: Array = piles[first]["position"]
			var b: Array = piles[second]["position"]
			if Vector3(a[0], a[1], a[2]).distance_to(Vector3(b[0], b[1], b[2])) < 1.0:
				return true
	return false

func _total_xp(hero: Node3D) -> int:
	var total: int = hero.xp
	for tier: int in range(hero.tier - 1):
		total += int(Data.HERO["xp_thresholds"][tier])
	return total

func _freeze(node: Node) -> void:
	node.set_physics_process(false)
	node.set_process(false)
	for child: Node in node.get_children():
		_freeze(child)

func _check(ok: bool, description: String) -> void:
	_checks += 1
	if not ok:
		_failures.append(description)
		push_error("RECOVERY_CONTINUATION FAIL: " + description)

func _finish() -> void:
	if is_instance_valid(_original):
		_original.queue_free()
	if is_instance_valid(_restored):
		_restored.queue_free()
	await process_frame
	await process_frame
	if _failures.is_empty():
		print("RECOVERY_CONTINUATION_PASS: %d checks; 20 seconds of identical real actor continuation; memory-only JSON" % _checks)
		quit(0)
	else:
		push_error("RECOVERY_CONTINUATION_FAILED: %d failures / %d checks" % [_failures.size(), _checks])
		quit(1)
