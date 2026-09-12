extends SceneTree
## Verify mute behavior against actual audio players with the dummy audio driver.
const Bank = preload("res://game/sound_bank.gd")
var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	Engine.max_fps = 60
	var bank: Node = Bank.new()
	root.add_child(bank)
	bank.enabled = true
	bank.play("win")
	bank.play("build")
	_check(_playing(bank) == 2, "Different effects can play together")
	bank.enabled = false
	_check(_playing(bank) == 0, "Muting stops every active effect immediately")
	bank.play("coin")
	_check(_playing(bank) == 0, "Muted effects do not start")
	bank.enabled = true
	_check(_playing(bank) == 0, "Unmuting does not replay old effects")
	bank.play("win")
	_check(_playing(bank) == 1, "A fresh effect can play immediately after unmuting")
	bank.play("win")
	_check(_playing(bank) == 1, "Normal duplicate-effect throttling still applies")
	bank.free()
	# Let the audio mixer retire stopped playbacks before engine shutdown.
	for frame: int in range(30):
		await process_frame
	if failures == 0:
		print("SOUND_CHECKS_PASS: 6 checks")
	quit(1 if failures > 0 else 0)

func _playing(bank: Node) -> int:
	var count: int = 0
	for child: Node in bank.get_children():
		if child is AudioStreamPlayer and child.playing:
			count += 1
	return count

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: " + message)
