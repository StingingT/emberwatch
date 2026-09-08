class_name BuildingActor
extends Node3D

const Visuals = preload("res://common/visuals.gd")
var game: Node
var kind: String = "tower"
var tier: int = 1
var plot_id: String = ""
var health: float = 1.0
var max_health: float = 1.0
var dead: bool = false
var stats: Dictionary = {}
var model: Node3D
var cooldown: float = 0.25
var _health_bar: MeshInstance3D
var _health_back: MeshInstance3D

func setup(owner_game: Node, building_kind: String, id: String, at: Vector3) -> void:
	game = owner_game
	kind = building_kind
	plot_id = id
	position = at
	stats = GameData.BUILDINGS[kind]
	_refresh_health(true)
	_rebuild_model()

func _physics_process(delta: float) -> void:
	if not is_instance_valid(game) or not game.is_playing() or dead:
		return
	cooldown -= delta
	if cooldown > 0.0:
		return
	if kind == "tower":
		var target: Node3D = game.nearest_enemy(global_position, float(stats["range"][tier - 1]))
		if is_instance_valid(target):
			var damage: float = float(stats["damage"][tier - 1]) * game.ranged_multiplier()
			game.spawn_arrow(global_position + Vector3(0, 1.62 + 0.43 * tier, 0), target, damage, "tower")
			cooldown = float(stats["interval"][tier - 1]) / game.haste_multiplier()
			game.play_sound("tower")
	elif kind == "mine":
		game.drop_coin(global_position + Vector3(-1.35, 0, 0.9), int(stats["production"][tier - 1]))
		cooldown = float(stats["interval"][tier - 1])

func maximum_level() -> int:
	return mini(int(stats["max_level"]), stats["costs"].size())

func upgrade() -> void:
	if tier >= maximum_level() or dead:
		return
	tier += 1
	_refresh_health(true)
	_rebuild_model()

func apply_fortification() -> void:
	_refresh_health(false)
	_update_health_bar()

func take_damage(amount: float, _source: String = "enemy") -> void:
	if dead or not game.is_playing():
		return
	health = maxf(0.0, health - amount)
	_update_health_bar()
	if health <= 0.0:
		dead = true
		game.on_building_destroyed(self)
		queue_free()

func _refresh_health(full: bool) -> void:
	var old_max: float = max_health
	max_health = float(stats["health"][tier - 1])
	if kind == "wall":
		max_health *= game.fortify_multiplier()
	if full:
		health = max_health
	else:
		health += max_health - old_max

func _rebuild_model() -> void:
	if is_instance_valid(model):
		remove_child(model)
		model.queue_free()
	model = Visuals.building(kind, tier)
	add_child(model)
	if not game.reduced_motion():
		model.scale = Vector3(0.75, 0.05, 0.75)
		var tween: Tween = create_tween()
		tween.tween_property(model, "scale", Vector3.ONE, 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if not is_instance_valid(_health_bar):
		_health_back = _bar(Color("293d36"))
		_health_bar = _bar(Color("f2b85f"))
		_health_bar.position.z -= 0.015
	_update_health_bar()

func _bar(color: Color) -> MeshInstance3D:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(2.0, 0.11, 0.09)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = mat
	var view: MeshInstance3D = MeshInstance3D.new()
	view.mesh = mesh
	view.position = Vector3(0, 2.2 if kind == "wall" else 4.5, 0)
	add_child(view)
	return view

func _update_health_bar() -> void:
	if not is_instance_valid(_health_bar):
		return
	_health_bar.scale.x = maxf(0.001, health / max_health)
	_health_bar.position.x = -(1.0 - health / max_health)
	_health_bar.visible = health < max_health
	_health_back.visible = _health_bar.visible
