extends SceneTree
## Clearly staged mission inspection through the real composition root.
## In-memory victory records unlock the fixtures; 250 fixture gold funds two
## purchases. These screenshots are not evidence of legal wins or game balance.
## Player saves are disabled before _ready. No campaign source is modified.
## godot --path . --script tools/capture_campaign.gd --fixed-fps 60 --quit-after 1200

const GameScript = preload("res://game/game.gd")
const VIEWS: Dictionary = {
	"briarwood": {"hero": Vector3(-1, 0, -3.8), "towers": ["bend", "crossing"]},
	"amberfield": {"hero": Vector3(1.4, 0, -8), "towers": ["crosswind", "eastern"]},
	"stonegate": {"hero": Vector3(-1, 0, -8.3), "towers": ["west_battery", "east_battery"]},
	"sunscar": {"hero": Vector3(1.8, 0, -5.1), "towers": ["inner_bend", "ridge"]},
	"moonfen": {"hero": Vector3(0.2, 0, -7.4), "towers": ["long_watch", "southern_reach"]},
	"emberfall": {"hero": Vector3(-0.4, 0, -9.8), "towers": ["forgeguard", "crossfire"]},
}
var _game: Node3D
var _failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Campaign capture requires an actual renderer; omit --headless.")
		quit(1)
		return
	_game = GameScript.new()
	_game.persistent_profile = false
	root.add_child(_game)
	_game.set_physics_process(false)
	_game.hero.set_physics_process(false)
	if not str(_game.profile.save_path).is_empty():
		push_error("Campaign inspection must never use a persistent player profile.")
		_game.queue_free()
		await process_frame
		quit(1)
		return
	_game.change_setting("sound", false)
	_game.change_setting("tutorial_hints", false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))
	await process_frame
	var captured: int = 0
	for mission: Dictionary in _game.missions:
		var id: String = mission["id"]
		_game.return_to_menu()
		if not _game.start_mission(id):
			_failures.append("Could not start unlocked mission fixture " + id)
			break
		_game.set_physics_process(false)
		_game.hero.set_physics_process(false)
		_game.hero.move_input = Vector2.ZERO
		_game.coins = 250
		var view: Dictionary = VIEWS[id]
		var staged_towers: Array = view["towers"]
		for index: int in range(staged_towers.size()):
			var plot_id: String = staged_towers[index]
			var plot: Dictionary = _game._plot_by_id(plot_id)
			if plot.is_empty():
				_failures.append("Missing fixture tower plot %s/%s" % [id, plot_id])
				continue
			_game.hero.position = plot["position"] + Vector3(0, 0, 2.4)
			if not _game.build_at(plot_id, "tower"):
				_failures.append("Purchase API rejected fixture tower %s/%s" % [id, plot_id])
				continue
			_game.buildings[plot_id].set_physics_process(false)
			if index == 0 and not _game.upgrade_at(plot_id):
				_failures.append("Purchase API rejected fixture upgrade %s/%s" % [id, plot_id])
		_game.hero.position = view["hero"]
		_game._camera_focus = _game.hero.position + Vector3(0, 0, -2)
		_game._update_camera(1.0)
		_game.selected_plot = {}
		_game._selection.hide()
		if is_instance_valid(_game._range_ring):
			_game._range_ring.hide()
		_game._update_hud()
		_game.hud.show_context({})
		_game.hud.show_hint("")
		_game.hud._toast_remaining = 0.0
		_game.hud._toast_panel.hide()
		# The existing wave panel labels the inspection; no full-screen overlay.
		_game.hud._wave_detail.text = str(mission["name"]) + " · staged"
		for frame: int in range(32):
			await process_frame
		await RenderingServer.frame_post_draw
		var screenshot: Image = root.get_texture().get_image()
		var path: String = "res://artifacts/mission_%s.png" % id
		var error: Error = screenshot.save_png(path)
		if error != OK:
			_failures.append("Could not write %s (error %s)" % [path, error])
		else:
			captured += 1
			print("CAMPAIGN_CAPTURE ", id, " ", screenshot.get_size(), " ", path)
		if not _game.profile.record_victory(id, 3, 1.0):
			_failures.append("Could not record in-memory fixture unlock " + id)
			break
	_game.return_to_menu()
	_game.queue_free()
	await process_frame
	await process_frame
	if not _failures.is_empty() or captured != 6:
		for failure: String in _failures:
			push_error(failure)
		quit(1)
		return
	print("CAMPAIGN_CAPTURE_PASS: six staged real-game views; player profile untouched")
	quit(0)
