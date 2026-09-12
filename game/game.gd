class_name EmberwatchGame
extends Node3D
## Run composition and cross-system rules. Actors own their own movement/combat.
const Data = preload("res://game/game_data.gd")
const Visuals = preload("res://common/visuals.gd")
const WorldScript = preload("res://levels/battlefield.gd")
const HeroScript = preload("res://entities/hero.gd")
const EnemyScript = preload("res://entities/enemy.gd")
const ArrowScript = preload("res://entities/projectile.gd")
const CoinScript = preload("res://entities/coin.gd")
const BuildingScript = preload("res://game/building.gd")
const HudScript = preload("res://ui/hud.gd")
const SoundScript = preload("res://game/sound_bank.gd")
const FeedbackScript = preload("res://game/world_feedback.gd")
const Campaign = preload("res://game/campaign_data.gd")
const ProfileScript = preload("res://game/player_profile.gd")
const RunStoreScript = preload("res://game/run_store.gd")
const Snapshot = preload("res://game/run_snapshot.gd")

var state: String = "menu"
var persistent_profile: bool = true
var profile: RefCounted
var run_store: RefCounted
# Explicit overrides support isolated tests; ordinary play uses portable user:// paths.
var profile_path_override: String = ""
var run_path_override: String = ""
var _resume_snapshot: Dictionary = {}
var _run_id: String = ""
var _new_run_pending: bool = false
var _restoring_run: bool = false
var _checkpoint_remaining: float = 5.0
var _checkpoint_queued: bool = false
var _profile_save_notice: String = ""
var _run_save_notice: String = ""
var missions: Array[Dictionary] = []
var mission_index: int = 0
var hero: Node3D
var camera: Camera3D
var hud: CanvasLayer
var sounds: Node
var feedback: Node2D
var level: Dictionary = {}
var enemies: Array[Node3D] = []
var buildings: Dictionary = {}
var plots: Array[Dictionary] = []
var plot_views: Dictionary = {}
var selected_plot: Dictionary = {}
var wave_configs: Array[Dictionary] = []
var coins: int = Data.STARTING_COINS
var coins_collected: int = 0
var kills: int = 0
var keep_health: float = Data.KEEP_HEALTH
var keep_max: float = Data.KEEP_HEALTH
var smith_levels: Dictionary = {"ranged": 0, "haste": 0, "fortify": 0}
var wave_index: int = -1
var wave_cursor: int = 0
var wave_active: bool = false
var wave_timer: float = Data.PREPARATION_TIME
var elapsed: float = 0.0
var _actors: Node3D
var _projectiles: Node3D
var _coins: Node3D
var _structures: Node3D
var _world: Node3D
var _keep_model: Node3D
var _plot_root: Node3D
var _selection: Node3D
var _range_ring: Node3D
var _camera_focus: Vector3
var _ui_timer: float = 0.0
var _last_keep_warning: float = -10.0
var _used_volley: bool = false
var _run_start: Vector3

func _ready() -> void:
	missions = Campaign.missions()
	profile = ProfileScript.new()
	if not profile_path_override.is_empty():
		profile.save_path = profile_path_override
	elif not persistent_profile or DisplayServer.get_name() == "headless":
		profile.save_path = ""
	profile.load_profile()
	run_store = RunStoreScript.new()
	run_store.snapshot_validator = validate_run_snapshot
	if not run_path_override.is_empty():
		run_store.save_path = run_path_override
	elif not persistent_profile or DisplayServer.get_name() == "headless":
		run_store.save_path = ""
	var loaded_run: Dictionary = run_store.load_run()
	level = missions[0]["level"].duplicate(true)
	wave_configs.assign(missions[0]["waves"])
	plots.assign(level["plots"])
	_world = WorldScript.new()
	_world.name = "Battlefield"
	add_child(_world)
	_world.setup(level)
	_actors = _container("Actors")
	_projectiles = _container("Projectiles")
	_coins = _container("Coins")
	_structures = _container("Structures")
	_keep_model = Visuals.building("keep", 3)
	_keep_model.position = level["keep"]
	_structures.add_child(_keep_model)
	_plot_root = _container("Plots")
	for plot: Dictionary in plots:
		var view: Node3D = Visuals.plot(str(plot["category"]))
		view.position = plot["position"]
		_plot_root.add_child(view)
		plot_views[plot["id"]] = view
	_selection = Visuals.ring(1.6, Color("ffe2a3"))
	add_child(_selection)
	_selection.visible = false
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.size = 24.0
	camera.far = 150.0
	add_child(camera)
	camera.make_current()
	var feedback_layer := CanvasLayer.new()
	feedback_layer.layer = 5
	add_child(feedback_layer)
	feedback = FeedbackScript.new()
	feedback_layer.add_child(feedback)
	feedback.setup(self, camera)
	sounds = SoundScript.new()
	add_child(sounds)
	hud = HudScript.new()
	add_child(hud)
	hud.play_requested.connect(start_recommended_mission)
	hud.continue_requested.connect(continue_defense)
	hud.campaign_requested.connect(show_campaign)
	hud.mission_requested.connect(start_mission)
	hud.next_requested.connect(next_mission)
	hud.setting_changed.connect(change_setting)
	hud.restart_requested.connect(start_run)
	hud.menu_requested.connect(return_to_menu)
	hud.pause_requested.connect(pause_run)
	hud.resume_requested.connect(resume_run)
	hud.build_requested.connect(build_selected)
	hud.upgrade_requested.connect(upgrade_selected)
	hud.smith_requested.connect(buy_smith_upgrade)
	hud.ability_requested.connect(use_ability)
	hud.sound_toggled.connect(_on_sound_toggled)
	_apply_preferences()
	_spawn_hero()
	_camera_focus = hero.position + Vector3(0, 0, -2)
	_update_camera(1.0)
	hud.show_title()
	_update_hud()
	if not str(profile.last_error).is_empty():
		_profile_save_notice = "Save recovery: " + str(profile.last_error)
	if loaded_run["status"] in ["active", "recovered"] and run_store.data.get("state") == "active":
		_resume_snapshot = run_store.data["snapshot"].duplicate(true)
		_run_id = str(run_store.data["run_id"])
	if not str(loaded_run["error"]).is_empty():
		_run_save_notice = "Battle save: " + str(loaded_run["error"])
	_reconcile_terminal_victory()
	_refresh_continue_summary()
	_refresh_save_notice()
	get_tree().auto_accept_quit = false
	# Android sends its hardware Back action as a window notification. Keep the
	# engine from quitting before the root can route it through the UI stack.
	get_tree().quit_on_go_back = false

func mission_unlocked(index: int) -> bool:
	return index >= 0 and index < missions.size() and (index == 0 or profile.data["results"].has(missions[index - 1]["id"]))

func campaign_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for index: int in range(missions.size()):
		var mission: Dictionary = missions[index]
		var result: Dictionary = profile.data["results"].get(mission["id"], {})
		rows.append({"id": mission["id"], "name": mission["name"], "briefing": mission["briefing"],
			"unlocked": mission_unlocked(index), "stars": int(result.get("stars", 0)),
			"best_time": float(result.get("best_time", 0.0))})
	return rows

func campaign_complete() -> bool:
	for mission: Dictionary in missions:
		if not profile.data["results"].has(mission["id"]):
			return false
	return true

func show_campaign() -> void:
	if state in ["playing", "paused"]:
		save_interrupted_run()
	state = "campaign"
	feedback.clear()
	hero.move_input = Vector2.ZERO
	hud.reset_input()
	hud.show_context({})
	hud.show_campaign(campaign_rows())

func start_recommended_mission() -> void:
	for mission: Dictionary in missions:
		if not profile.data["results"].has(mission["id"]):
			start_mission(str(mission["id"]))
			return
	show_campaign()

func start_mission(id: String) -> bool:
	if is_playing():
		return false
	var index: int = -1
	for candidate: int in range(missions.size()):
		if str(missions[candidate]["id"]) == id:
			index = candidate
			break
	if not mission_unlocked(index):
		return false
	_select_mission_world(index)
	start_run()
	return true

func _select_mission_world(index: int) -> void:
	state = "resetting"
	mission_index = index
	level = missions[index]["level"].duplicate(true)
	wave_configs.assign(missions[index]["waves"])
	plots.assign(level["plots"])
	for view: Node in _plot_root.get_children():
		_plot_root.remove_child(view)
		view.queue_free()
	plot_views.clear()
	for plot: Dictionary in plots:
		var view: Node3D = Visuals.plot(str(plot["category"]))
		view.position = plot["position"]
		_plot_root.add_child(view)
		plot_views[plot["id"]] = view
	_world.setup(level)
	_keep_model.position = level["keep"]

func next_mission() -> void:
	if state != "won":
		return
	if mission_index + 1 < missions.size():
		start_mission(str(missions[mission_index + 1]["id"]))
	else:
		show_campaign()

func _container(label: String) -> Node3D:
	var node: Node3D = Node3D.new()
	node.name = label
	add_child(node)
	return node

func _spawn_hero() -> void:
	hero = HeroScript.new()
	hero.name = "Archer"
	_actors.add_child(hero)
	hero.setup(self, Data.HERO)
	hero.position = level["hero"]

func start_run() -> void:
	state = "resetting"
	feedback.clear()
	hud.reset_input()
	for container: Node3D in [_actors, _projectiles, _coins]:
		for child: Node in container.get_children():
			container.remove_child(child)
			child.queue_free()
	for building: Node3D in buildings.values():
		if is_instance_valid(building):
			_structures.remove_child(building)
			building.queue_free()
	enemies.clear()
	buildings.clear()
	selected_plot = {}
	for view: Node3D in plot_views.values():
		view.visible = true
	coins = int(level.get("starting_coins", Data.STARTING_COINS))
	coins_collected = 0
	kills = 0
	keep_health = base_keep_health()
	keep_max = base_keep_health()
	smith_levels = {"ranged": 0, "haste": 0, "fortify": 0}
	wave_index = -1
	wave_cursor = 0
	wave_active = false
	wave_timer = Data.PREPARATION_TIME
	elapsed = 0.0
	_last_keep_warning = -10.0
	_used_volley = false
	_spawn_hero()
	_run_start = hero.position
	_camera_focus = hero.position + Vector3(0, 0, -2)
	_update_camera(1.0)
	_refresh_range_ring()
	_checkpoint_remaining = 5.0
	if _restoring_run:
		return
	_run_id = Crypto.new().generate_random_bytes(16).hex_encode()
	_new_run_pending = true
	_resume_snapshot.clear()
	state = "playing"
	hud.show_game()
	_update_selection()
	_update_hud()
	notify("Build a tower nearby, then head up the trail.", "info")
	save_interrupted_run()

func base_keep_health() -> float:
	return float(level.get("keep_health", Data.KEEP_HEALTH))

func building_limit(kind: String) -> int:
	var overrides: Dictionary = level.get("building_limits", {})
	return maxi(0, int(overrides.get(kind, Data.BUILDINGS[kind]["limit"])))

func reduced_motion() -> bool:
	return is_instance_valid(profile) and bool(profile.data["settings"]["reduced_motion"])

func is_playing() -> bool:
	return state == "playing"

func _physics_process(delta: float) -> void:
	if not is_instance_valid(hero):
		return
	hero.move_input = Vector2.ZERO
	if is_playing():
		var keyboard := Vector2(
			float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),
			float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
		var touch: Vector2 = hud.movement_vector()
		hero.move_input = (touch if touch.length() > 0.05 else keyboard).limit_length()
		elapsed += delta
		_advance_waves(delta)
		_checkpoint_remaining -= delta
		if _checkpoint_remaining <= 0.0 and not _checkpoint_queued:
			_checkpoint_queued = true
			_periodic_checkpoint.call_deferred()
	_update_camera(delta)
	_ui_timer -= delta
	if _ui_timer <= 0.0:
		_ui_timer = 0.1
		_update_selection()
		_update_hud()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.physical_keycode == KEY_ESCAPE:
		if state == "playing":
			pause_run()
		elif state == "paused":
			resume_run()
	elif event.physical_keycode == KEY_SPACE and is_playing():
		use_ability()
	elif event.physical_keycode == KEY_E and is_playing() and not selected_plot.is_empty():
		if buildings.has(selected_plot["id"]):
			upgrade_selected()
		else:
			var category: String = selected_plot["category"]
			build_selected("tower" if category == "tower" else ("wall" if category == "wall" else "mine"))

func _update_camera(delta: float) -> void:
	var target: Vector3 = hero.position + Vector3(0, 0, -2.0)
	target.x = clampf(target.x, -4.0, 4.0)
	target.z = clampf(target.z, -23.0, 3.5)
	_camera_focus = _camera_focus.lerp(target, 1.0 - exp(-8.0 * delta))
	camera.position = _camera_focus + Vector3(0, 23, 19)
	camera.look_at(_camera_focus, Vector3.UP)

func _advance_waves(delta: float) -> void:
	wave_timer -= delta
	if wave_active:
		var config: Dictionary = wave_configs[wave_index]
		var spawn_list: Array = config["enemies"]
		if wave_cursor < spawn_list.size() and wave_timer <= 0.0:
			spawn_enemy(str(spawn_list[wave_cursor]), float(config["health_scale"]))
			wave_cursor += 1
			wave_timer = float(config["interval"])
		if wave_cursor >= spawn_list.size() and enemies.is_empty():
			wave_active = false
			if wave_index == wave_configs.size() - 1:
				_finish_run(true)
			else:
				wave_timer = Data.BETWEEN_WAVES
				notify("Wave cleared. Collect gold and strengthen your line.", "success")
	elif wave_timer <= 0.0:
		wave_index += 1
		if wave_index >= wave_configs.size():
			_finish_run(true)
			return
		wave_cursor = 0
		wave_active = true
		wave_timer = 0.0
		notify("Wave %d · %s" % [wave_index + 1, wave_configs[wave_index]["name"]], "info")

func spawn_enemy(kind: String, health_scale: float = 1.0) -> Node3D:
	var enemy: Node3D = EnemyScript.new()
	_actors.add_child(enemy)
	var stats: Dictionary = Data.ENEMIES[kind].duplicate()
	stats["health"] = float(stats["health"]) * health_scale
	var route: Array[Vector3] = []
	route.assign(level["route"])
	enemy.setup(self, stats, route)
	enemies.append(enemy)
	return enemy

func nearest_enemy(at: Vector3, max_range: float) -> Node3D:
	var result: Node3D = null
	var distance: float = max_range * max_range
	for enemy: Node3D in enemies:
		if not is_instance_valid(enemy) or enemy.dead:
			continue
		var flat: Vector3 = enemy.global_position - at
		flat.y = 0.0
		var current: float = flat.length_squared()
		if current < distance:
			distance = current
			result = enemy
	return result

func enemies_in_range(at: Vector3, max_range: float) -> Array[Node3D]:
	var result: Array[Node3D] = []
	for enemy: Node3D in enemies:
		if is_instance_valid(enemy) and not enemy.dead:
			var offset: Vector3 = enemy.global_position - at
			offset.y = 0.0
			if offset.length_squared() <= max_range * max_range:
				result.append(enemy)
	return result

func spawn_arrow(at: Vector3, target: Node3D, damage: float, source: String) -> void:
	if not is_instance_valid(target) or target.dead:
		return
	var arrow: Node3D = ArrowScript.new()
	_projectiles.add_child(arrow)
	arrow.setup(self, at, target, damage, source)

func on_enemy_damaged(xp_reward: float) -> void:
	if is_playing() and is_instance_valid(hero):
		hero.add_xp(xp_reward)

func on_enemy_killed(enemy: Node3D, _source: String, reward: int, _xp_reward: int) -> void:
	if not enemies.has(enemy):
		return
	enemies.erase(enemy)
	kills += 1
	drop_coin(enemy.global_position, reward)
	play_sound("hit")

func drop_coin(at: Vector3, amount: int) -> void:
	# Combine nearby piles to bound live coin nodes during a crowded wave.
	for existing: Node3D in _coins.get_children():
		if not existing.is_queued_for_deletion() and existing.position.distance_squared_to(at) < 1.0:
			existing.value += amount
			return
	var pickup: Node3D = CoinScript.new()
	_coins.add_child(pickup)
	pickup.setup(self, at, amount)

func collect_coin(amount: int, at: Vector3) -> void:
	if not is_playing():
		return
	coins += amount
	coins_collected += amount
	feedback.pickup(at, amount)
	play_sound("coin")

func show_hit(at: Vector3, lethal: bool) -> void:
	feedback.hit(at, lethal)

func get_hero() -> Node3D:
	return hero

func hero_respawn_position() -> Vector3:
	var bounds: Rect2 = Rect2(level["bounds"]).grow(-float(Data.FOOTPRINTS["hero_margin"]))
	for radius: int in range(3, 20):
		for step: int in range(24):
			var angle: float = TAU * step / 24.0
			var at: Vector3 = level["keep"] + Vector3(sin(angle), 0, -cos(angle)) * radius
			if bounds.has_point(Vector2(at.x, at.z)) and not _position_blocked(at):
				return at
	return hero.position

func get_blocking_wall(at: Vector3, next: Vector3) -> Node3D:
	var travel: Vector3 = next - at
	travel.y = 0.0
	for building: Node3D in buildings.values():
		if not is_instance_valid(building) or building.kind != "wall" or building.dead:
			continue
		var offset: Vector3 = building.global_position - at
		offset.y = 0.0
		if absf(offset.x) < 2.0 and absf(offset.z) < 1.5 and offset.dot(travel) >= -0.2:
			return building
	return null

func damage_keep(amount: float) -> void:
	if not is_playing():
		return
	keep_health = maxf(0.0, keep_health - amount)
	if elapsed - _last_keep_warning > 4.0:
		_last_keep_warning = elapsed
		notify("The Keep is under attack! Follow the trail south.", "danger")
	if keep_health <= 0.0:
		_finish_run(false)

func _update_selection() -> void:
	if not is_playing():
		_selection.visible = false
		if is_instance_valid(_range_ring):
			_range_ring.visible = false
		return
	var nearest: Dictionary = {}
	var best: float = Data.BUILD_RADIUS
	for plot: Dictionary in plots:
		var distance: float = hero.position.distance_to(plot["position"])
		if distance < best:
			best = distance
			nearest = plot
	var changed: bool = str(nearest.get("id", "")) != str(selected_plot.get("id", ""))
	selected_plot = nearest
	_selection.visible = not nearest.is_empty()
	if _selection.visible:
		_selection.position = nearest["position"] + Vector3(0, 0.04, 0)
	if changed:
		_refresh_range_ring()
	if is_instance_valid(_range_ring):
		_range_ring.visible = true
	hud.show_context(_context())

func _refresh_range_ring() -> void:
	if is_instance_valid(_range_ring):
		_range_ring.queue_free()
		_range_ring = null
	if selected_plot.is_empty():
		return
	var building: Node3D = buildings.get(selected_plot["id"])
	if is_instance_valid(building) and building.kind != "tower":
		return
	if not is_instance_valid(building) and selected_plot["category"] != "tower":
		return
	var tier: int = building.tier if is_instance_valid(building) else 1
	_range_ring = Visuals.ring(float(Data.BUILDINGS["tower"]["range"][tier - 1]), Color(1.0, 0.91, 0.64, 0.28))
	_range_ring.position = selected_plot["position"] + Vector3(0, 0.035, 0)
	add_child(_range_ring)

func _context() -> Dictionary:
	if selected_plot.is_empty() or not is_playing() or not hero.is_alive():
		return {}
	var result: Dictionary = {"title": "Build your defense", "subtitle": "Choose a structure · combat stays live",
		"selection_id": str(selected_plot["id"]),
		"options": [], "upgrade_cost": -1, "tier": 0, "can_upgrade": false,
		"screen_position": camera.unproject_position(selected_plot["position"] + Vector3(0, 3, 0))}
	var options: Array[Dictionary] = []
	if buildings.has(selected_plot["id"]):
		var building: Node3D = buildings[selected_plot["id"]]
		var spec: Dictionary = Data.BUILDINGS[building.kind]
		result["title"] = spec["name"]
		result["tier"] = building.tier
		result["subtitle"] = "Level %d / %d" % [building.tier, building.maximum_level()]
		if building.tier < building.maximum_level():
			result["upgrade_cost"] = int(spec["costs"][building.tier])
			result["can_upgrade"] = coins >= int(result["upgrade_cost"])
			result["subtitle"] = _upgrade_preview(building)
		else:
			result["subtitle"] = "Maximum level · hold the line"
		if building.kind == "smith":
			for id: String in ["ranged", "haste", "fortify"]:
				var cost: int = smith_cost(id)
				options.append({"id": id, "label": Data.SMITH[id]["name"], "cost": cost,
					"description": Data.SMITH[id]["description"], "enabled": coins >= cost})
	else:
		for kind: String in ["tower", "wall", "mine", "smith"]:
			var spec: Dictionary = Data.BUILDINGS[kind]
			if spec["category"] != selected_plot["category"]:
				continue
			var below_limit: bool = building_count(kind) < building_limit(kind)
			options.append({"id": kind, "label": spec["name"], "cost": int(spec["costs"][0]),
				"description": spec["description"] if below_limit else "Building limit reached",
				"enabled": coins >= int(spec["costs"][0]) and below_limit})
	result["options"] = options
	return result

func _stat_number(value: float, decimals: int) -> String:
	return String.num(value, decimals).trim_suffix(".0")

func _upgrade_preview(building: Node3D) -> String:
	var spec: Dictionary = Data.BUILDINGS[building.kind]
	var current: int = building.tier - 1
	var next: int = building.tier
	match building.kind:
		"tower":
			return "Arrow damage %s → %s · Range %s → %s" % [
				_stat_number(float(spec["damage"][current]) * ranged_multiplier(), 1), _stat_number(float(spec["damage"][next]) * ranged_multiplier(), 1),
				_stat_number(float(spec["range"][current]), 1), _stat_number(float(spec["range"][next]), 1)]
		"wall":
			return "Health %s → %s · Fully repairs" % [_stat_number(building.health, 1), _stat_number(float(spec["health"][next]) * fortify_multiplier(), 1)]
		"mine":
			return "Gold %d / %ss → %d / %ss" % [int(spec["production"][current]), _stat_number(float(spec["interval"][current]), 1),
				int(spec["production"][next]), _stat_number(float(spec["interval"][next]), 1)]
		"smith":
			return "Smith purchases cost up to %d less gold" % int(Data.SMITH_PRICING["tier_discount"])
	return "Level %d → %d" % [building.tier, building.tier + 1]

func build_selected(kind: String) -> void:
	build_at(str(selected_plot.get("id", "")), kind)

func build_at(plot_id: String, kind: String) -> bool:
	if not is_playing() or not hero.is_alive() or not Data.BUILDINGS.has(kind) or buildings.has(plot_id):
		return false
	var plot: Dictionary = _plot_by_id(plot_id)
	if plot.is_empty() or hero.position.distance_to(plot["position"]) > Data.BUILD_RADIUS:
		return false
	var spec: Dictionary = Data.BUILDINGS[kind]
	var cost: int = int(spec["costs"][0])
	if spec["category"] != plot["category"] or coins < cost or building_count(kind) >= building_limit(kind):
		return false
	var clear_position: Vector3 = _construction_clearance(plot["position"], kind)
	if not clear_position.is_finite():
		notify("There is no clear space beside this plot.", "info")
		return false
	coins -= cost
	var building: Node3D = BuildingScript.new()
	_structures.add_child(building)
	building.setup(self, kind, plot_id, plot["position"])
	buildings[plot_id] = building
	hero.position = clear_position
	plot_views[plot_id].visible = false
	play_sound("build")
	notify("%s ready" % spec["name"], "success")
	_refresh_range_ring()
	_update_selection()
	_update_hud()
	return true

func upgrade_selected() -> void:
	upgrade_at(str(selected_plot.get("id", "")))

func upgrade_at(plot_id: String) -> bool:
	if not is_playing() or not hero.is_alive() or not buildings.has(plot_id):
		return false
	var building: Node3D = buildings[plot_id]
	if building.tier >= building.maximum_level() or hero.position.distance_to(building.position) > Data.BUILD_RADIUS:
		return false
	var cost: int = int(Data.BUILDINGS[building.kind]["costs"][building.tier])
	if coins < cost:
		return false
	coins -= cost
	building.upgrade()
	play_sound("build")
	notify("%s · Level %d" % [Data.BUILDINGS[building.kind]["name"], building.tier], "success")
	_refresh_range_ring()
	_update_selection()
	_update_hud()
	return true

func building_count(kind: String) -> int:
	var count: int = 0
	for building: Node3D in buildings.values():
		if is_instance_valid(building) and building.kind == kind and not building.dead:
			count += 1
	return count

func _plot_by_id(id: String) -> Dictionary:
	for plot: Dictionary in plots:
		if plot["id"] == id:
			return plot
	return {}

func smith_cost(id: String) -> int:
	var smith_tier: int = 1
	for building: Node3D in buildings.values():
		if building.kind == "smith":
			smith_tier = building.tier
	return maxi(int(Data.SMITH_PRICING["minimum"]), int(Data.SMITH[id]["base_cost"])
		+ int(smith_levels[id]) * int(Data.SMITH_PRICING["repeat_increase"])
		- (smith_tier - 1) * int(Data.SMITH_PRICING["tier_discount"]))

func buy_smith_upgrade(id: String) -> void:
	if not is_playing() or not hero.is_alive() or not Data.SMITH.has(id) or selected_plot.is_empty():
		return
	var smith: Node3D = buildings.get(selected_plot["id"])
	if not is_instance_valid(smith) or smith.kind != "smith" or hero.position.distance_to(smith.position) > Data.BUILD_RADIUS:
		return
	var cost: int = smith_cost(id)
	if coins < cost:
		return
	coins -= cost
	smith_levels[id] = int(smith_levels[id]) + 1
	if id == "fortify":
		var previous_max: float = keep_max
		keep_max = base_keep_health() * fortify_multiplier()
		keep_health += keep_max - previous_max
		for building: Node3D in buildings.values():
			if building.kind == "wall":
				building.apply_fortification()
	if not reduced_motion():
		var tween: Tween = smith.create_tween()
		tween.tween_property(smith.model, "scale", Vector3(1.08, 1.15, 1.08), 0.12)
		tween.tween_property(smith.model, "scale", Vector3.ONE, 0.18)
	play_sound("build")
	notify(Data.SMITH[id]["description"], "success")
	_update_selection()
	_update_hud()

func ranged_multiplier() -> float:
	return 1.0 + int(smith_levels["ranged"]) * float(Data.SMITH["ranged"]["step"])

func haste_multiplier() -> float:
	return 1.0 + int(smith_levels["haste"]) * float(Data.SMITH["haste"]["step"])

func fortify_multiplier() -> float:
	return 1.0 + int(smith_levels["fortify"]) * float(Data.SMITH["fortify"]["step"])

func on_building_destroyed(building: Node3D) -> void:
	buildings.erase(building.plot_id)
	plot_views[building.plot_id].visible = true
	notify("A barricade fell. Rebuild it at the empty plot.", "danger")
	_refresh_range_ring()

func constrain_hero_motion(from: Vector3, to: Vector3) -> Vector3:
	var bounds: Rect2 = level["bounds"]
	var margin: float = float(Data.FOOTPRINTS["hero_margin"])
	var candidate: Vector3 = Vector3(clampf(to.x, bounds.position.x + margin, bounds.end.x - margin), 0,
		clampf(to.z, bounds.position.y + margin, bounds.end.y - margin))
	if _position_blocked(candidate):
		var slide_x := Vector3(candidate.x, 0, from.z)
		var slide_z := Vector3(from.x, 0, candidate.z)
		if not _position_blocked(slide_x):
			return slide_x
		if not _position_blocked(slide_z):
			return slide_z
		return from
	return candidate

func _position_blocked(at: Vector3) -> bool:
	if at.distance_squared_to(level["keep"]) < float(Data.FOOTPRINTS["keep_radius_squared"]):
		return true
	for building: Node3D in buildings.values():
		if _building_footprint_contains(at, building.position, building.kind):
			return true
	return false

func _building_footprint_contains(at: Vector3, center: Vector3, kind: String) -> bool:
	return Data.building_footprint_contains(at, center, kind)

func _construction_clearance(center: Vector3, kind: String) -> Vector3:
	# Plots are walkable until built. Move an overlapping hero to the nearest
	# clear edge before the new structure becomes solid; never trap them inside.
	if not _building_footprint_contains(hero.position, center, kind):
		return hero.position
	var offset: Vector3 = hero.position - center
	var candidates: Array[Vector3] = []
	if kind == "wall":
		var width: float = float(Data.FOOTPRINTS["wall_half_width"])
		var depth: float = float(Data.FOOTPRINTS["wall_half_depth"])
		candidates.assign([
			center + Vector3(clampf(offset.x, -width, width), 0, -depth - 0.1),
			center + Vector3(clampf(offset.x, -width, width), 0, depth + 0.1),
			center + Vector3(-width - 0.1, 0, clampf(offset.z, -depth, depth)),
			center + Vector3(width + 0.1, 0, clampf(offset.z, -depth, depth))])
	else:
		if not offset.is_zero_approx():
			candidates.append(center + offset.normalized() * 1.55)
		for index: int in range(16):
			var angle: float = TAU * float(index) / 16.0
			candidates.append(center + Vector3(sin(angle), 0, -cos(angle)) * 1.55)
	var nearest: Vector3 = Vector3.INF
	var best: float = INF
	var walking_bounds: Rect2 = Rect2(level["bounds"]).grow(-float(Data.FOOTPRINTS["hero_margin"]))
	for candidate: Vector3 in candidates:
		if not walking_bounds.has_point(Vector2(candidate.x, candidate.z)) or _position_blocked(candidate):
			continue
		var distance: float = hero.position.distance_squared_to(candidate)
		if distance < best:
			nearest = candidate
			best = distance
	return nearest

func use_ability() -> void:
	if is_playing():
		if hero.use_ability():
			_used_volley = true

func pause_run() -> void:
	if not is_playing():
		return
	state = "paused"
	hud.reset_input()
	hero.move_input = Vector2.ZERO
	hud.show_pause()
	save_interrupted_run()

func resume_run() -> void:
	if state != "paused":
		return
	state = "playing"
	hud.reset_input()
	hud.show_game()
	_update_selection()

func return_to_menu() -> void:
	if state in ["playing", "paused"]:
		save_interrupted_run()
	state = "menu"
	feedback.clear()
	hud.reset_input()
	hero.move_input = Vector2.ZERO
	_refresh_continue_summary()
	hud.show_title()

func _finish_run(won: bool) -> void:
	if not is_playing():
		return
	state = "won" if won else "lost"
	feedback.clear()
	hud.reset_input()
	hero.move_input = Vector2.ZERO
	play_sound("win" if won else "lose")
	var stars: int = 0
	var saved: bool = true
	if won:
		var health_ratio: float = keep_health / maxf(1.0, keep_max)
		stars = 3 if health_ratio >= float(Data.STAR_HEALTH_THRESHOLDS["three"]) else (2 if health_ratio >= float(Data.STAR_HEALTH_THRESHOLDS["two"]) else 1)
	var outcome: Dictionary = {"kind": "victory" if won else "loss", "mission_id": missions[mission_index]["id"]}
	if won:
		outcome["stars"] = stars
		outcome["seconds"] = maxf(0.01, elapsed)
	# Keep an earlier unrecorded victory journal intact if profile storage is still
	# unavailable. New session results remain usable but are visibly unsaved.
	var retired: bool = _reconcile_terminal_victory()
	if retired:
		var terminal_id: String = _run_id if _new_run_pending or run_store.data.get("run_id", "") != _run_id else ""
		retired = run_store.finish_run(outcome, terminal_id)
	_run_save_notice = "" if retired else "The finished battle could not be saved. Previous recovery data may remain."
	_resume_snapshot.clear()
	_refresh_continue_summary()
	if won:
		saved = profile.record_victory(str(missions[mission_index]["id"]), stars, maxf(0.01, elapsed))
		_profile_save_notice = "" if saved else "Progress is available this session, but could not be saved."
	_refresh_save_notice()
	hud.show_context({})
	hud.show_result(won, {"kills": kills, "coins": coins_collected, "wave": wave_index + 1,
		"elapsed": elapsed, "keep_health": keep_health, "keep_max": keep_max,
		"total_waves": wave_configs.size(), "stars": stars, "mission_name": missions[mission_index]["name"],
		"next_available": won and mission_index + 1 < missions.size(),
		"campaign_complete": won and campaign_complete(),
		"save_failed": not saved or not retired})
	_update_hud()

func _update_hud() -> void:
	var wave_text: String = "Prepare your defenses"
	var wave_total: int = 0
	var wave_remaining: int = 0
	if wave_active and wave_index >= 0:
		wave_text = str(wave_configs[wave_index]["name"])
		wave_total = wave_configs[wave_index]["enemies"].size()
		wave_remaining = enemies.size() + maxi(0, wave_total - wave_cursor)
	elif is_playing():
		wave_text = "Next wave in %ds" % maxi(0, ceili(wave_timer))
	var threats: int = 0
	for enemy: Node3D in enemies:
		if enemy.position.z > 1.0:
			threats += 1
	hud.update_state({"coins": coins, "keep_health": keep_health, "keep_max": keep_max,
		"hero_health": hero.health, "hero_respawn": hero.respawn_remaining, "hero_protection": hero.protection_remaining,
		"wave": maxi(1, wave_index + 1), "total_waves": wave_configs.size(), "wave_text": wave_text,
		"wave_remaining": wave_remaining, "wave_total": wave_total, "wave_active": wave_active,
		"kills": kills, "hero_level": hero.tier, "xp": hero.xp, "next_xp": hero.next_xp,
		"ability_unlocked": hero.tier >= int(Data.HERO["ability_unlock"]),
		"ability_cooldown": hero.ability_cooldown, "ability_total": float(Data.HERO["ability_cooldown"]),
		"threat_text": "%d enemies near the Keep ↓" % threats if threats > 0 else ""})
	_update_tutorial()

func _update_tutorial() -> void:
	var hint: String = ""
	if is_playing() and mission_index == 0 and bool(profile.data["settings"]["tutorial_hints"]) and not profile.data["results"].has(missions[mission_index]["id"]):
		if elapsed < 8.0 and hero.position.distance_to(_run_start) < 1.0:
			hint = "Drag the stick or use WASD. Your archer fires automatically."
		elif buildings.is_empty():
			hint = "Move beside a marked plot, then buy a tower to defend the trail."
		elif coins_collected == 0:
			hint = "Walk near gold to collect it. Spend it on stronger defenses."
		elif hero.tier < int(Data.HERO["ability_unlock"]):
			hint = "Your archer's damage earns XP. Level 2 unlocks Volley."
		elif not _used_volley:
			hint = "Use Volley near a group of goblins. Tap the gold button or Space."
	hud.show_hint(hint)

func notify(message: String, tone: String = "info") -> void:
	if is_instance_valid(hud):
		hud.toast(message, tone)

func play_sound(kind: String) -> void:
	if is_instance_valid(sounds):
		var key: String = "ability" if kind == "volley" else ("level" if kind == "level_up" else kind)
		sounds.play(key)

func _on_sound_toggled(enabled: bool) -> void:
	change_setting("sound", enabled)

func change_setting(key: String, value: bool) -> void:
	var saved: bool = profile.set_setting(key, value)
	_apply_preferences()
	_profile_save_notice = "" if saved else "Settings changed for this session; saving is unavailable."
	_refresh_save_notice()
	if not saved:
		notify("Settings changed for this session; saving is unavailable.", "danger")

func _apply_preferences() -> void:
	var settings: Dictionary = profile.data["settings"]
	sounds.enabled = bool(settings["sound"]) and DisplayServer.get_name() != "headless"
	hud.set_preferences(settings)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		if is_instance_valid(hud):
			if state == "playing":
				pause_run()
			elif state == "paused":
				save_interrupted_run()
			hud.reset_input()
		Engine.max_fps = 15
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		Engine.max_fps = 60
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_handle_android_back()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST and is_instance_valid(hud):
		if state in ["playing", "paused"]:
			state = "paused"
			hud.reset_input()
			hero.move_input = Vector2.ZERO
			save_interrupted_run()
		get_tree().quit()


func _handle_android_back() -> bool:
	if state == "playing":
		pause_run()
		return true
	if is_instance_valid(hud) and hud.handle_back():
		return true
	if state in ["paused", "campaign", "won", "lost"]:
		return_to_menu()
		return true
	# At the title screen the second Back action follows Android's normal app
	# exit behavior. quit_on_go_back is disabled so this is an intentional exit.
	get_tree().quit()
	return true

func capture_run_snapshot() -> Dictionary:
	return Snapshot.capture(self)

func validate_run_snapshot(saved: Dictionary) -> Dictionary:
	return Snapshot.validate(saved, missions)

func save_interrupted_run() -> bool:
	if state not in ["playing", "paused"] or _restoring_run:
		return false
	_checkpoint_remaining = 5.0
	var checked: Dictionary = validate_run_snapshot(capture_run_snapshot())
	if not checked["ok"]:
		_run_save_notice = "The current battle could not be saved. " + str(checked["error"])
		_refresh_save_notice()
		return false
	_resume_snapshot = checked["data"]
	var saved: bool = _reconcile_terminal_victory()
	if saved:
		saved = run_store.store_run(_resume_snapshot, _run_id if _new_run_pending else "")
		if saved:
			_new_run_pending = false
	_run_save_notice = "" if saved else "This battle is available this session, but saving is unavailable."
	_refresh_continue_summary()
	_refresh_save_notice()
	return saved

func _periodic_checkpoint() -> void:
	_checkpoint_queued = false
	if state == "playing" and _checkpoint_remaining <= 0.0:
		save_interrupted_run()

func continue_defense() -> bool:
	if state not in ["menu", "campaign"] or _resume_snapshot.is_empty():
		return false
	return restore_run_snapshot(_resume_snapshot)

func restore_run_snapshot(saved: Dictionary) -> bool:
	var checked: Dictionary = validate_run_snapshot(saved)
	if not checked["ok"]:
		return false
	var snapshot: Dictionary = checked["data"]
	var index: int = 0
	for candidate: int in range(missions.size()):
		if missions[candidate]["id"] == snapshot["mission_id"]:
			index = candidate
			break
	_restoring_run = true
	_select_mission_world(index)
	start_run()
	coins = int(snapshot["coins"])
	coins_collected = int(snapshot["coins_collected"])
	kills = int(snapshot["kills"])
	smith_levels = snapshot["smith_levels"].duplicate()
	keep_max = base_keep_health() * fortify_multiplier()
	keep_health = float(snapshot["keep_health"])
	elapsed = float(snapshot["elapsed"])
	_used_volley = bool(snapshot["used_volley"])
	_last_keep_warning = float(snapshot["last_keep_warning"])
	_run_start = Snapshot.to_vector(snapshot["run_start"])
	wave_index = int(snapshot["wave_index"])
	wave_cursor = int(snapshot["wave_cursor"])
	wave_active = bool(snapshot["wave_active"])
	wave_timer = float(snapshot["wave_timer"])
	hero.restore_state(snapshot["hero"])
	for data: Dictionary in snapshot["buildings"]:
		var plot: Dictionary = _plot_by_id(str(data["plot_id"]))
		var building: Node3D = BuildingScript.new()
		_structures.add_child(building)
		building.setup(self, str(data["kind"]), str(data["plot_id"]), plot["position"], false)
		building.restore_state(data)
		buildings[building.plot_id] = building
		plot_views[building.plot_id].visible = false
	var restored_enemies: Dictionary = {}
	for data: Dictionary in snapshot["enemies"]:
		var enemy: Node3D = spawn_enemy(str(data["kind"]))
		enemy.restore_state(data)
		restored_enemies[int(data["id"])] = enemy
	for data: Dictionary in snapshot["coins_on_ground"]:
		var coin: Node3D = CoinScript.new()
		_coins.add_child(coin)
		coin.setup(self, Snapshot.to_vector(data["position"]), int(data["value"]))
		coin.restore_state(data)
	for data: Dictionary in snapshot["arrows"]:
		var arrow: Node3D = ArrowScript.new()
		_projectiles.add_child(arrow)
		arrow.setup(self, Snapshot.to_vector(data["position"]), restored_enemies[int(data["target_id"])], float(data["damage"]), str(data["source"]), float(data["speed"]))
		arrow.restore_state(data)
	_camera_focus = Snapshot.to_vector(snapshot["camera_focus"])
	_update_camera(0.0)
	_resume_snapshot = snapshot.duplicate(true)
	if _run_id.is_empty():
		_run_id = Crypto.new().generate_random_bytes(16).hex_encode()
		_new_run_pending = true
	state = "paused"
	_restoring_run = false
	hud.reset_input()
	hud.show_context({})
	hud.show_pause()
	_update_selection()
	_update_hud()
	_refresh_continue_summary()
	_refresh_save_notice()
	return true

func _refresh_continue_summary() -> void:
	if not is_instance_valid(hud):
		return
	var summary: Dictionary = {}
	if not _resume_snapshot.is_empty():
		for mission: Dictionary in missions:
			if mission["id"] == _resume_snapshot["mission_id"]:
				summary = {"mission_name": mission["name"], "wave": maxi(1, int(_resume_snapshot["wave_index"]) + 1),
					"total_waves": mission["waves"].size(), "elapsed": _resume_snapshot["elapsed"]}
	hud.set_continue_summary(summary)

func _reconcile_terminal_victory() -> bool:
	if run_store.data.get("state") != "terminal":
		return true
	var outcome: Dictionary = run_store.data["outcome"]
	if outcome.get("kind") != "victory":
		return true
	var known: bool = false
	for mission: Dictionary in missions:
		if mission["id"] == outcome["mission_id"]:
			known = true
	if not known:
		return true
	var saved: bool = profile.record_victory(str(outcome["mission_id"]), int(outcome["stars"]), float(outcome["seconds"]))
	_profile_save_notice = "" if saved else "A completed mission is awaiting a successful progress save."
	return saved

func _refresh_save_notice() -> void:
	if is_instance_valid(hud):
		hud.set_save_notice(" ".join([_profile_save_notice, _run_save_notice]).strip_edges())
