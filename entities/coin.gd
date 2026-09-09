extends Node3D
class_name CoinPickup

const Visuals := preload("res://common/visuals.gd")

var game: Node
var value: int = 1
var _model: Node3D
var _age: float = 0.0
var _phase: float = 0.0
var _collected: bool = false
var _magnetized: bool = false
var _magnet_speed: float = 3.0


func setup(owner_game: Node, at: Vector3, amount: int) -> void:
	game = owner_game
	position = at
	position.y = 0.0
	value = maxi(1, amount)
	_phase = randf() * TAU
	_model = Visuals.coin()
	add_child(_model)
	_model.position.y = 0.35


func snapshot_available() -> bool:
	return not _collected and not is_queued_for_deletion()


func capture_state() -> Dictionary:
	return {"position": [position.x, position.y, position.z], "value": value,
		"magnetized": _magnetized, "magnet_speed": _magnet_speed,
		"age": _age, "phase": _phase}


## Restore directly after setup; collecting and merging remain gameplay actions.
func restore_state(saved: Dictionary) -> void:
	var at: Array = saved["position"]
	position = Vector3(float(at[0]), float(at[1]), float(at[2]))
	value = int(saved["value"])
	_magnetized = bool(saved["magnetized"])
	_magnet_speed = float(saved["magnet_speed"])
	_age = float(saved["age"])
	_phase = float(saved["phase"])
	_collected = false
	var bounce: float = absf(sin(_age * 8.0)) * maxf(0.0, 1.0 - _age * 1.5) * 0.5
	_model.position.y = 0.34 + sin(_age * 3.5 + _phase) * 0.07 + bounce
	_model.rotation.y = _age * 2.7
	if game.reduced_motion():
		_model.position.y = 0.34
		_model.rotation.y = 0.0


func _physics_process(delta: float) -> void:
	if _collected or not is_instance_valid(game) or not bool(game.call("is_playing")):
		return
	_age += delta
	_model.rotation.y += delta * 2.7
	var bounce: float = absf(sin(_age * 8.0)) * maxf(0.0, 1.0 - _age * 1.5) * 0.5
	_model.position.y = 0.34 + sin(_age * 3.5 + _phase) * 0.07 + bounce
	if game.reduced_motion():
		_model.position.y = 0.34
		_model.rotation.y = 0.0
	var hero: Node3D = game.call("get_hero") as Node3D
	if not is_instance_valid(hero):
		return
	var destination: Vector3 = hero.global_position
	destination.y = global_position.y
	var distance: float = global_position.distance_to(destination)
	var radius_value: Variant = hero.get("coin_radius")
	var radius: float = float(radius_value) if radius_value != null else 2.5
	if distance <= radius:
		_magnetized = true
	if not _magnetized:
		return
	_magnet_speed = minf(20.0, _magnet_speed + delta * 30.0)
	global_position = global_position.move_toward(destination, _magnet_speed * delta)
	if global_position.distance_squared_to(destination) > 0.32 * 0.32:
		return
	_collected = true
	game.call("collect_coin", value, global_position)
	queue_free()
