extends Node3D
class_name ArrowProjectile

const Visuals := preload("res://common/visuals.gd")

var game: Node
var _target: WeakRef
var _damage: float = 0.0
var _source: String = "hero"
var _speed: float = 24.0
var _lifetime: float = 4.0
var _impacted: bool = false


func setup(owner_game: Node, start: Vector3, target: Node3D, damage: float, source: String, speed: float = 24.0) -> void:
	game = owner_game
	position = start
	_damage = damage
	_source = source
	_speed = maxf(speed, 1.0)
	if is_instance_valid(target):
		_target = weakref(target)
	add_child(Visuals.arrow())
	_orient_to_target()


func _physics_process(delta: float) -> void:
	if _impacted:
		return
	if not is_instance_valid(game):
		queue_free()
		return
	if not bool(game.call("is_playing")):
		return
	_lifetime -= delta
	var target: Node3D = _live_target()
	if target == null or _lifetime <= 0.0:
		queue_free()
		return
	var destination: Vector3 = target.global_position + Vector3(0.0, 0.85, 0.0)
	var offset: Vector3 = destination - global_position
	var step: float = _speed * delta
	if offset.length_squared() <= (step + 0.2) * (step + 0.2):
		_impacted = true
		_target = null
		if target.has_method("take_damage"):
			target.call("take_damage", _damage, _source)
		queue_free()
		return
	global_position += offset.normalized() * step
	if offset.length_squared() > 0.0001:
		_face_destination(destination)


func _live_target() -> Node3D:
	if _target == null:
		return null
	var target: Node3D = _target.get_ref() as Node3D
	if not is_instance_valid(target) or target.is_queued_for_deletion():
		return null
	if bool(target.get("dead")):
		return null
	return target


func _orient_to_target() -> void:
	var target: Node3D = _live_target()
	if target == null or not is_inside_tree():
		return
	var destination: Vector3 = target.global_position + Vector3(0.0, 0.85, 0.0)
	if global_position.distance_squared_to(destination) > 0.0001:
		_face_destination(destination)


func _face_destination(destination: Vector3) -> void:
	var direction: Vector3 = (destination - global_position).normalized()
	var up: Vector3 = Vector3.FORWARD if absf(direction.dot(Vector3.UP)) > 0.99 else Vector3.UP
	look_at(destination, up)
