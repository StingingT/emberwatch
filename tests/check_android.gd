extends SceneTree
## Android platform back routing on the real composition root.
## Native Android delivery is still device-tested separately; these checks keep
## the notification path and visible overlay behavior deterministic on desktop.
const GameScript = preload("res://game/game.gd")
var checks: int = 0
var failures: int = 0
var game: Node3D


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	game = GameScript.new()
	game.persistent_profile = false
	root.add_child(game)
	await process_frame
	_check(quit_on_go_back == false, "The root intercepts Android Back before the engine quits")
	game.hud.play_requested.emit()
	await process_frame
	_check(game.state == "playing", "Android Back fixture starts from a live defense")
	game.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	_check(game.state == "paused" and game.hud._overlay_mode == "pause" and game.hud.movement_vector() == Vector2.ZERO,
		"Android Back pauses an active defense and clears held movement")
	game.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	_check(game.state == "menu" and game.hud._overlay_mode == "title",
		"Android Back from the pause screen returns to the title")
	game.hud.show_settings()
	game.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	_check(game.hud._overlay_mode == "title" and game.state == "menu",
		"Android Back closes title settings before leaving the app")
	game.hud.show_how_to_play()
	game.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	_check(game.hud._overlay_mode == "title",
		"Android Back closes title help before leaving the app")
	game.show_campaign()
	game.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	_check(game.state == "menu" and game.hud._overlay_mode == "title",
		"Android Back from campaign returns to the title")
	game.start_mission("briarwood")
	game._finish_run(false)
	_check(game.state == "lost" and game.hud._overlay_mode == "result",
		"Back routing fixture reaches a real defeat result")
	game.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	_check(game.state == "menu" and game.hud._overlay_mode == "title",
		"Android Back from a result returns to the title")
	game.queue_free()
	await process_frame
	if failures == 0:
		print("ANDROID_CHECKS_PASS: %d checks" % checks)
	else:
		printerr("ANDROID_CHECKS_FAILED: %d / %d checks" % [failures, checks])
	quit(0 if failures == 0 else 1)


func _check(passed: bool, message: String) -> void:
	checks += 1
	if not passed:
		failures += 1
		push_error("FAIL: " + message)
