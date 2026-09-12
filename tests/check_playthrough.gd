extends SceneTree
## A normal-rules six-wave player: no teleports, grants, stat edits, or forced kills.
## godot --headless --path . --script tests/check_playthrough.gd --fixed-fps 60
const GameScript := preload("res://game/game.gd")
const Data := preload("res://game/game_data.gd")
const STEP: float = 1.0 / 60.0
const TIME_LIMIT: float = 900.0

var _game: Node3D
var _grid: AStarGrid2D
var _plan: Array[Dictionary] = []
var _plan_index: int = 0
var _destination: Vector3
var _path: PackedVector2Array = []
var _think_remaining: float = 0.0
var _purchases: int = 0
var _abilities: int = 0
var _movement: float = 0.0
var _max_step: float = 0.0
var _previous_position: Vector3
var _last_wave: int = -2


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	seed(51019)
	_game = GameScript.new()
	root.add_child(_game)
	_game.set_physics_process(false)
	_game.sounds.enabled = false
	await process_frame
	_make_plan()
	var active_result: Dictionary = await _run_scenario(true)
	var idle_result: Dictionary = await _run_scenario(false)
	_game.queue_free()
	await process_frame
	await process_frame
	var passed: bool = active_result["outcome"] == "won" and int(active_result["wave"]) == Data.waves().size()
	passed = passed and int(active_result["purchases"]) >= 6 and int(active_result["abilities"]) > 0
	passed = passed and float(active_result["max_step"]) <= float(Data.HERO["speed"]) * STEP + 0.002
	passed = passed and idle_result["outcome"] == "lost"
	if passed:
		print("PLAYTHROUGH PASSED: a normal-rules player won all six waves; unattended defense lost.")
		quit(0)
	else:
		push_error("PLAYTHROUGH FAILED: inspect the outcome and movement evidence above.")
		quit(1)


func _run_scenario(active_player: bool) -> Dictionary:
	_game.start_run()
	_game.set_physics_process(false)
	_game.sounds.enabled = false
	_plan_index = 0
	_purchases = 0
	_abilities = 0
	_movement = 0.0
	_max_step = 0.0
	_think_remaining = 0.0
	_last_wave = -2
	_previous_position = _game.hero.position
	_path.clear()
	_rebuild_navigation()
	var label: String = "ACTIVE" if active_player else "UNATTENDED"
	var was_alive: bool = _game.hero.is_alive()
	while _game.is_playing() and float(_game.elapsed) < TIME_LIMIT:
		await physics_frame
		if active_player and _game.hero.pending_choices() > 0:
			_game.offer_hero_choice()
			while _game.hero.pending_choices() > 0:
				var options: Array[String] = ["multishot", "piercing", "volley"]
				var spent: int = _game.hero.tier - 1 - _game.hero.pending_choices()
				_game.choose_hero_upgrade(options[spent % 3])
		var moved: float = _game.hero.position.distance_to(_previous_position)
		# Respawn is an authored relocation, not an input-driven movement step.
		if not was_alive and _game.hero.is_alive() and _game.hero.position.distance_to(_game.hero_respawn_position()) < 0.001:
			moved = 0.0
			_path.clear()
			_think_remaining = 0.0
		was_alive = _game.hero.is_alive()
		_movement += moved
		_max_step = maxf(_max_step, moved)
		_previous_position = _game.hero.position
		_game.elapsed += STEP
		_game.call("_advance_waves", STEP)
		if not _game.is_playing():
			break
		if active_player:
			_drive_player()
		else:
			_game.hero.move_input = Vector2.ZERO
		if int(_game.wave_index) != _last_wave:
			_last_wave = int(_game.wave_index)
			print("%s wave=%d t=%.1f keep=%.0f gold=%d hero=%d kills=%d" % [
				label, _last_wave + 1, _game.elapsed, _game.keep_health, _game.coins, _game.hero.tier, _game.kills])
	var tiers: Dictionary = {}
	for plot_id: String in _game.buildings:
		var building: Node3D = _game.buildings[plot_id]
		tiers[plot_id] = "%s:%d" % [building.kind, building.tier]
	var result: Dictionary = {
		"scenario": label, "outcome": _game.state, "wave": int(_game.wave_index) + 1,
		"seconds": snappedf(float(_game.elapsed), 0.01), "kills": _game.kills,
		"gold_collected": _game.coins_collected, "gold_remaining": _game.coins,
		"keep_health": _game.keep_health, "hero_tier": _game.hero.tier,
		"purchases": _purchases, "abilities": _abilities, "buildings": tiers,
		"movement": snappedf(_movement, 0.01), "max_step": _max_step,
	}
	print("PLAYTHROUGH_RESULT " + JSON.stringify(result))
	return result


func _make_plan() -> void:
	_plan = [
		{"plot": "crossing", "kind": "tower", "tier": 1},
		{"plot": "quarry", "kind": "mine", "tier": 1},
		{"plot": "north", "kind": "tower", "tier": 1},
		{"plot": "approach", "kind": "tower", "tier": 1},
		{"plot": "north", "kind": "tower", "tier": 2},
		{"plot": "approach", "kind": "tower", "tier": 2},
		{"plot": "crossing", "kind": "tower", "tier": 2},
		{"plot": "choke", "kind": "wall", "tier": 1},
		{"plot": "north", "kind": "tower", "tier": 3},
		{"plot": "approach", "kind": "tower", "tier": 3},
		{"plot": "crossing", "kind": "tower", "tier": 3},
		{"plot": "bend", "kind": "tower", "tier": 1},
		{"plot": "watch", "kind": "tower", "tier": 1},
		{"plot": "quarry", "kind": "mine", "tier": 2},
		{"plot": "forge", "kind": "smith", "tier": 1},
		{"plot": "forge", "smith": "ranged", "rank": 1},
		{"plot": "forge", "smith": "haste", "rank": 1},
		{"plot": "choke", "kind": "wall", "tier": 2},
		{"plot": "watch", "kind": "tower", "tier": 2},
		{"plot": "bend", "kind": "tower", "tier": 2},
	]


func _drive_player() -> void:
	var nearby: Array[Node3D] = _game.enemies_in_range(_game.hero.position, float(Data.HERO["ability_range"]))
	if nearby.size() >= 3 and bool(_game.hero.use_ability()):
		_abilities += 1
	_think_remaining -= STEP
	if _think_remaining <= 0.0:
		_think_remaining = 0.25
		_try_purchase()
		_destination = _choose_destination()
		_replan_path(_destination)
	_follow_path()


func _try_purchase() -> void:
	if _plan_index >= _plan.size():
		return
	var action: Dictionary = _plan[_plan_index]
	var plot_id: String = action["plot"]
	if action.has("smith"):
		var upgrade_id: String = action["smith"]
		if int(_game.smith_levels[upgrade_id]) >= int(action["rank"]):
			_plan_index += 1
			return
		var before: int = _game.coins
		_game.call("_update_selection")
		_game.buy_smith_upgrade(upgrade_id)
		if int(_game.coins) < before:
			_purchases += 1
			_plan_index += 1
			print("PURCHASE t=%.1f smith=%s gold=%d" % [_game.elapsed, upgrade_id, _game.coins])
		return
	var building: Node3D = _game.buildings.get(plot_id) as Node3D
	if is_instance_valid(building) and int(building.tier) >= int(action["tier"]):
		_plan_index += 1
		return
	var bought: bool = false
	if is_instance_valid(building):
		bought = bool(_game.upgrade_at(plot_id))
	else:
		bought = bool(_game.build_at(plot_id, str(action["kind"])))
	if bought:
		_purchases += 1
		_rebuild_navigation()
		print("PURCHASE t=%.1f plot=%s tier=%d gold=%d" % [
			_game.elapsed, plot_id, _game.buildings[plot_id].tier, _game.coins])
		if int(_game.buildings[plot_id].tier) >= int(action["tier"]):
			_plan_index += 1


func _choose_destination() -> Vector3:
	var at: Vector3 = _game.hero.position
	var leading: Node3D = null
	for enemy: Node3D in _game.enemies:
		if not is_instance_valid(enemy) or bool(enemy.dead):
			continue
		if leading == null or enemy.position.z > leading.position.z:
			leading = enemy
	# Prioritize leaks heading to the Keep over economic travel.
	if is_instance_valid(leading) and leading.position.z > -2.0:
		return _stand_near(leading.position, 1.8)
	if _plan_index < _plan.size():
		var action: Dictionary = _plan[_plan_index]
		if int(_game.coins) >= _action_cost(action):
			var plot: Dictionary = _game.call("_plot_by_id", str(action["plot"]))
			return _stand_near(plot["position"], 2.2)
	var best_coin: Node3D = null
	var best_score: float = 0.0
	for coin: Node3D in _game.get_node("Coins").get_children():
		if coin.is_queued_for_deletion():
			continue
		var distance: float = at.distance_to(coin.position)
		var score: float = float(coin.value) / (distance + 3.0)
		if score > best_score:
			best_score = score
			best_coin = coin
	if is_instance_valid(best_coin):
		return _stand_near(best_coin.position, 0.8)
	if is_instance_valid(leading):
		return _stand_near(leading.position, 1.8)
	return Vector3(2, 0, -22)


func _action_cost(action: Dictionary) -> int:
	if action.has("smith"):
		return int(_game.smith_cost(str(action["smith"])))
	var building: Node3D = _game.buildings.get(action["plot"]) as Node3D
	var cost_index: int = int(building.tier) if is_instance_valid(building) else 0
	return int(Data.BUILDINGS[action["kind"]]["costs"][mini(cost_index, 2)])


func _stand_near(target: Vector3, distance: float) -> Vector3:
	var offset: Vector3 = _game.hero.position - target
	offset.y = 0.0
	if offset.length() <= distance:
		return _game.hero.position
	return target + offset.normalized() * distance


func _rebuild_navigation() -> void:
	_grid = AStarGrid2D.new()
	_grid.region = Rect2i(-9, -29, 19, 42)
	_grid.cell_size = Vector2.ONE
	_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	_grid.update()
	for x: int in range(-9, 10):
		for z: int in range(-29, 13):
			var point := Vector3(x, 0, z)
			var blocked: bool = point.distance_squared_to(_game.level["keep"]) < 7.4
			for building: Node3D in _game.buildings.values():
				var offset: Vector3 = point - building.position
				if building.kind == "wall":
					blocked = blocked or (absf(offset.x) < 2.1 and absf(offset.z) < 1.05)
				else:
					blocked = blocked or offset.length_squared() < 3.2
			_grid.set_point_solid(Vector2i(x, z), blocked)


func _nearest_open(point: Vector3) -> Vector2i:
	var best := Vector2i(clampi(roundi(point.x), -9, 9), clampi(roundi(point.z), -29, 12))
	var best_distance: float = INF
	for x: int in range(maxi(-9, best.x - 4), mini(9, best.x + 4) + 1):
		for z: int in range(maxi(-29, best.y - 4), mini(12, best.y + 4) + 1):
			var candidate := Vector2i(x, z)
			if _grid.is_point_solid(candidate):
				continue
			var distance: float = Vector3(x, 0, z).distance_squared_to(point)
			if distance < best_distance:
				best_distance = distance
				best = candidate
	return best


func _replan_path(destination: Vector3) -> void:
	var start: Vector2i = _nearest_open(_game.hero.position)
	var finish: Vector2i = _nearest_open(destination)
	_path = _grid.get_point_path(start, finish)
	if _path.size() > 1:
		_path.remove_at(0)


func _follow_path() -> void:
	var at: Vector3 = _game.hero.position
	while not _path.is_empty():
		var point := Vector3(_path[0].x, 0, _path[0].y)
		if point.distance_squared_to(at) <= 0.12:
			_path.remove_at(0)
			continue
		var direction: Vector3 = point - at
		_game.hero.move_input = Vector2(direction.x, direction.z).normalized()
		return
	_game.hero.move_input = Vector2.ZERO
