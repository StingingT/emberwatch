extends "res://tests/check_playthrough.gd"
## One continuous legal campaign: wins unlock the next mission, without grants.

func _run() -> void:
	seed(51019)
	_game = GameScript.new()
	_game.persistent_profile = false
	root.add_child(_game)
	_game.set_physics_process(false)
	_game.sounds.enabled = false
	await process_frame
	var passed: bool = true
	for index: int in range(_game.missions.size()):
		var mission: Dictionary = _game.missions[index]
		if not _game.start_mission(str(mission["id"])):
			push_error("Campaign mission was not unlocked: " + str(mission["id"]))
			passed = false
			break
		if index == 0:
			_make_plan()
		else:
			_make_campaign_plan()
		var result: Dictionary = await _run_scenario(true)
		print("CAMPAIGN_MISSION " + str(mission["id"]) + " " + JSON.stringify(result))
		if result["outcome"] != "won" or float(result["max_step"]) > float(Data.HERO["speed"]) * STEP + 0.002:
			passed = false
			break
	passed = passed and _game.campaign_complete()
	_game.queue_free()
	await process_frame
	await process_frame
	if passed:
		print("CAMPAIGN_PLAYTHROUGH_PASS: all six missions won and unlocked through normal gameplay")
		quit(0)
	else:
		push_error("CAMPAIGN_PLAYTHROUGH_FAIL: inspect mission outcome above")
		quit(1)

func _make_campaign_plan() -> void:
	_plan.clear()
	var towers: Array[Dictionary] = []
	var walls: Array[Dictionary] = []
	var supports: Array[Dictionary] = []
	for plot: Dictionary in _game.plots:
		match str(plot["category"]):
			"tower": towers.append(plot)
			"wall": walls.append(plot)
			"support": supports.append(plot)
	var origin: Vector3 = _game.hero.position
	towers.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return origin.distance_squared_to(a["position"]) < origin.distance_squared_to(b["position"]))
	supports.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return origin.distance_squared_to(a["position"]) < origin.distance_squared_to(b["position"]))
	for index: int in range(mini(2, towers.size())):
		_plan.append({"plot": towers[index]["id"], "kind": "tower", "tier": 1})
	if not supports.is_empty():
		_plan.append({"plot": supports[0]["id"], "kind": "mine", "tier": 1})
	for index: int in range(mini(2, towers.size())):
		_plan.append({"plot": towers[index]["id"], "kind": "tower", "tier": 2})
	if supports.size() > 1:
		_plan.append({"plot": supports[1]["id"], "kind": "smith", "tier": 1})
		_plan.append({"plot": supports[1]["id"], "smith": "ranged", "rank": 1})
		_plan.append({"plot": supports[1]["id"], "smith": "haste", "rank": 1})
	for index: int in range(2, towers.size()):
		_plan.append({"plot": towers[index]["id"], "kind": "tower", "tier": 1})
	for wall: Dictionary in walls:
		_plan.append({"plot": wall["id"], "kind": "wall", "tier": 1})
	for tier: int in range(2, 4):
		for tower: Dictionary in towers:
			_plan.append({"plot": tower["id"], "kind": "tower", "tier": tier})
