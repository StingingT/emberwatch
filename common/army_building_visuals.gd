class_name ArmyBuildingVisuals
extends RefCounted
## Tower evolution only. Other families retain their own development paths.
const Base = preload("res://common/visuals.gd")
const Kit = preload("res://common/visual_mesh_kit.gd")
const HEIGHTS: Array[float] = [1.50, 2.30, 3.05]
const WIDTHS: Array[float] = [1.40, 1.85, 2.40]

static func building(kind: String, tier: int) -> Node3D:
	if kind != "tower":
		return Base.building(kind, tier)
	var rank: int = clampi(tier, 1, 3)
	var height: float = HEIGHTS[rank - 1]
	var width: float = WIDTHS[rank - 1]
	var parts: Array = []
	if rank == 1:
		for x: float in [-0.47, 0.47]:
			for z: float in [-0.47, 0.47]:
				Kit.part(parts, "box", Vector3(0.22, height, 0.22), Vector3(x, height * 0.5, z), Base.WOOD)
		Kit.beam(parts, Vector3(-0.47, 0.2, 0.47), Vector3(0.47, height - 0.1, 0.47), 0.14, Base.WOOD_LIGHT, "box")
	else:
		Kit.part(parts, "box", Vector3(1.35, height, 1.35), Vector3(0, height * 0.5, 0), Base.STONE)
		for y: float in [0.18, height * 0.5, height - 0.15]:
			Kit.part(parts, "box", Vector3(1.43, 0.16, 1.43), Vector3(0, y, 0), Base.STONE_LIGHT)
		if rank == 3:
			for x: float in [-0.70, 0.70]:
				Kit.part(parts, "box", Vector3(0.13, height, 1.45), Vector3(x, height * 0.5, 0), Base.IRON)
	Kit.part(parts, "box", Vector3(width, 0.22, width), Vector3(0, height, 0), Base.WOOD_LIGHT if rank == 1 else Base.STONE_LIGHT)
	for side: float in [-1.0, 1.0]:
		Kit.part(parts, "box", Vector3(width, 0.35, 0.16), Vector3(0, height + 0.25, side * (width * 0.5 - 0.08)), Base.WOOD if rank == 1 else Base.STONE)
		Kit.part(parts, "box", Vector3(0.16, 0.35, width), Vector3(side * (width * 0.5 - 0.08), height + 0.25, 0), Base.WOOD if rank == 1 else Base.STONE)
	Kit.part(parts, "box", Vector3(0.55, 0.75, 0.06), Vector3(0, height - 0.4, width * 0.5 + 0.02), Base.RED)
	Kit.beam(parts, Vector3(width * 0.36, height, width * 0.30), Vector3(width * 0.36, height + 1.5, width * 0.30), 0.07, Base.WOOD_DARK)
	Kit.part(parts, "box", Vector3(0.52, 0.32, 0.045), Vector3(width * 0.36 + 0.24, height + 1.32, width * 0.30), Base.RED)
	var root: Node3D = Kit.model("army_archer_tower_%d" % rank, parts)
	var crew := Node3D.new()
	crew.name = "Crew"
	root.add_child(crew)
	for index: int in range(rank):
		var archer: Node3D = _archer()
		archer.name = "Archer%d" % (index + 1)
		archer.position = Vector3((index - (rank - 1) * 0.5) * 0.70, height + 0.12, -0.10)
		crew.add_child(archer)
	return root

static func _archer() -> Node3D:
	var parts: Array = []
	for x: float in [-0.11, 0.11]:
		Kit.part(parts, "box", Vector3(0.14, 0.24, 0.20), Vector3(x, 0.12, 0), Base.WOOD_DARK)
	Kit.part(parts, "box", Vector3(0.37, 0.34, 0.27), Vector3(0, 0.40, 0), Base.RED)
	Kit.part(parts, "ball", Vector3(0.39, 0.39, 0.35), Vector3(0, 0.77, 0), Base.RED)
	Kit.part(parts, "ball", Vector3(0.27, 0.25, 0.23), Vector3(0, 0.74, -0.13), Base.SKIN)
	Kit.beam(parts, Vector3(-0.15, 0.5, 0), Vector3(-0.23, 0.48, -0.23), 0.12, Base.RED)
	Kit.beam(parts, Vector3(-0.24, 0.17, -0.22), Vector3(-0.33, 0.49, -0.32), 0.065, Base.WOOD_LIGHT)
	Kit.beam(parts, Vector3(-0.33, 0.49, -0.32), Vector3(-0.24, 0.83, -0.22), 0.065, Base.WOOD_LIGHT)
	Kit.beam(parts, Vector3(-0.24, 0.17, -0.22), Vector3(-0.24, 0.83, -0.22), 0.016, Base.CREAM)
	var model: Node3D = Kit.model("army_tower_archer", parts)
	var muzzle := Marker3D.new()
	muzzle.name = "Muzzle"
	muzzle.position = Vector3(-0.30, 0.51, -0.37)
	model.add_child(muzzle)
	return model

static func firing_points(model: Node3D, target: Vector3) -> Array[Vector3]:
	var positions: Array[Vector3] = []
	var crew: Node3D = model.get_node_or_null("Crew")
	if crew == null:
		return positions
	for archer: Node3D in crew.get_children():
		var aim: Vector3 = Vector3(target.x, archer.global_position.y, target.z)
		if archer.global_position.distance_squared_to(aim) > 0.001:
			archer.look_at(aim, Vector3.UP)
		positions.append(archer.get_node("Muzzle").global_position)
	return positions
