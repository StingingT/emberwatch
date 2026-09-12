class_name SoundBank
extends Node
## Short original synthesized effects; no external audio dependencies.
var enabled: bool = true:
	set(value):
		enabled = value
		if not enabled:
			for player: AudioStreamPlayer in _players:
				player.stop()
			_last_played.clear()
var _sounds: Dictionary = {}
var _last_played: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _cursor: int = 0

func _ready() -> void:
	enabled = DisplayServer.get_name() != "headless"
	for i: int in range(8):
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.volume_db = -18.0
		add_child(player)
		_players.append(player)
	_sounds["shoot"] = _tone(630.0, 220.0, 0.07, 0.25)
	_sounds["tower"] = _tone(420.0, 170.0, 0.055, 0.20)
	_sounds["coin"] = _tone(1050.0, 1580.0, 0.12, 0.35)
	_sounds["build"] = _tone(250.0, 700.0, 0.24, 0.45)
	_sounds["level"] = _tone(480.0, 1100.0, 0.40, 0.45)
	_sounds["ability"] = _tone(300.0, 1000.0, 0.25, 0.4)
	_sounds["hit"] = _tone(170.0, 65.0, 0.10, 0.15)
	_sounds["win"] = _tone(460.0, 920.0, 0.7, 0.4)
	_sounds["lose"] = _tone(330.0, 90.0, 0.7, 0.3)

func _exit_tree() -> void:
	for player: AudioStreamPlayer in _players:
		player.stop()
		player.stream = null
	_sounds.clear()

func play(kind: String) -> void:
	if not enabled or not _sounds.has(kind) or _players.is_empty():
		return
	var now: float = Time.get_ticks_msec() * 0.001
	if now - float(_last_played.get(kind, -10.0)) < 0.07:
		return
	_last_played[kind] = now
	var player: AudioStreamPlayer = _players[_cursor]
	_cursor = (_cursor + 1) % _players.size()
	player.stream = _sounds[kind]
	player.play()

func _tone(start: float, finish: float, length: float, amplitude: float) -> AudioStreamWAV:
	var rate: int = 22050
	var count: int = int(length * rate)
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(count * 2)
	var phase: float = 0.0
	for i: int in range(count):
		var progress: float = float(i) / count
		phase += TAU * lerpf(start, finish, progress) / rate
		var envelope: float = minf(progress * 25.0, 1.0) * pow(1.0 - progress, 2.0)
		var sample: float = (sin(phase) + sin(phase * 2.0) * 0.22) * amplitude * envelope
		bytes.encode_s16(i * 2, int(clampf(sample, -1.0, 1.0) * 32767.0))
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = bytes
	return stream
