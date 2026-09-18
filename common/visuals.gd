class_name GameVisuals
extends RefCounted
## Emberwatch's original toy-like silhouettes. Feet are at y=0; forward is -Z.

const Kit = preload("res://common/visual_mesh_kit.gd")
const RED := Color("bd3f3c")
const RED_LIGHT := Color("e15a48")
const RED_DARK := Color("7f3337")
const CREAM := Color("f2d9aa")
const STONE := Color("bdc5ac")
const STONE_LIGHT := Color("dce0c5")
const STONE_DARK := Color("82978c")
const WOOD := Color("825533")
const WOOD_LIGHT := Color("b47c46")
const WOOD_DARK := Color("4b392f")
const IRON := Color("536879")
const IRON_LIGHT := Color("9aacb3")
const GOLD := Color("f7c75d")
const GREEN := Color("75b84a")
const GREEN_DARK := Color("3e733c")
const SKIN := Color("efbd8b")
const EYES := Color("213333")

static func hero() -> Node3D:
	var parts: Array = []
	# Boots and a broad red tunic make the player readable above a mob.
	for x: float in [-0.17, 0.17]:
		Kit.part(parts, "box", Vector3(0.22, 0.25, 0.33), Vector3(x, 0.15, -0.045), WOOD_DARK)
		Kit.part(parts, "box", Vector3(0.18, 0.31, 0.20), Vector3(x, 0.40, 0.0), CREAM)
	Kit.part(parts, "cone", Vector3(0.80, 0.48, 0.58), Vector3(0, 0.63, 0), RED)
	Kit.part(parts, "box", Vector3(0.58, 0.49, 0.41), Vector3(0, 0.88, 0), RED_LIGHT)
	Kit.part(parts, "box", Vector3(0.64, 0.11, 0.44), Vector3(0, 0.67, 0), WOOD_DARK)
	Kit.part(parts, "box", Vector3(0.15, 0.12, 0.07), Vector3(0, 0.68, -0.25), GOLD)
	# Cape falls behind the silhouette; the hood surrounds a warm visible face.
	Kit.part(parts, "roof", Vector3(0.74, 0.81, 0.10), Vector3(0, 0.82, 0.30), RED_DARK, Vector3(0.18, 0, PI))
	Kit.part(parts, "ball", Vector3(0.68, 0.65, 0.65), Vector3(0, 1.32, 0.03), RED)
	Kit.part(parts, "ball", Vector3(0.49, 0.44, 0.40), Vector3(0, 1.29, -0.18), SKIN)
	Kit.part(parts, "box", Vector3(0.47, 0.14, 0.34), Vector3(0, 1.53, -0.19), RED_LIGHT)
	for x: float in [-0.12, 0.12]:
		Kit.part(parts, "box", Vector3(0.065, 0.075, 0.035), Vector3(x, 1.34, -0.38), EYES)
	Kit.part(parts, "box", Vector3(0.16, 0.07, 0.05), Vector3(0, 1.16, -0.36), RED_DARK)
	Kit.beam(parts, Vector3(-0.29, 1.04, 0), Vector3(-0.48, 0.98, -0.35), 0.19, RED_LIGHT)
	Kit.beam(parts, Vector3(0.29, 1.04, 0), Vector3(0.15, 1.00, -0.36), 0.18, RED_LIGHT)
	Kit.part(parts, "ball", Vector3.ONE * 0.20, Vector3(-0.47, 0.98, -0.37), SKIN)
	Kit.part(parts, "ball", Vector3.ONE * 0.19, Vector3(0.13, 1.00, -0.38), SKIN)
	# Sculpted bow: five segments instead of an unreadable thin arc.
	var bow: Array[Vector3] = [Vector3(-0.43, 0.47, -0.32), Vector3(-0.53, 0.64, -0.52), Vector3(-0.56, 0.98, -0.61), Vector3(-0.53, 1.29, -0.52), Vector3(-0.43, 1.47, -0.32)]
	for i: int in range(bow.size() - 1):
		Kit.beam(parts, bow[i], bow[i + 1], 0.085, WOOD_LIGHT)
	Kit.beam(parts, bow[0], bow[-1], 0.018, CREAM)
	Kit.part(parts, "cylinder", Vector3(0.21, 0.62, 0.21), Vector3(0.24, 0.98, 0.34), WOOD, Vector3(0, 0, -0.25))
	for x: float in [0.18, 0.26, 0.32]:
		Kit.beam(parts, Vector3(x, 1.15, 0.33), Vector3(x + 0.06, 1.53, 0.33), 0.027, CREAM)
	return Kit.model("hero", parts, 0.48)

static func enemy(kind: String) -> Node3D:
	var parts: Array = []
	var brute: bool = kind == "brute"
	var skin_color: Color = GREEN_DARK if brute else GREEN
	for x: float in [-0.16, 0.16]:
		Kit.part(parts, "box", Vector3(0.23, 0.22, 0.34), Vector3(x, 0.13, -0.07), WOOD_DARK)
		Kit.part(parts, "cylinder", Vector3(0.20, 0.31, 0.22), Vector3(x, 0.35, 0), skin_color)
	Kit.part(parts, "box", Vector3(0.55, 0.34, 0.33), Vector3(0, 0.59, 0), WOOD_DARK)
	Kit.part(parts, "ball", Vector3(0.65, 0.49, 0.41), Vector3(0, 0.81, 0), skin_color)
	Kit.part(parts, "ball", Vector3(0.65, 0.55, 0.59), Vector3(0, 1.12, -0.08), skin_color)
	Kit.part(parts, "ball", Vector3(0.46, 0.25, 0.25), Vector3(0, 0.99, -0.34), GREEN_DARK)
	for side: float in [-1.0, 1.0]:
		Kit.part(parts, "cone", Vector3(0.22, 0.40, 0.22), Vector3(side * 0.37, 1.15, 0), skin_color, Vector3(0, 0, side * -1.2))
		Kit.part(parts, "box", Vector3(0.10, 0.09, 0.045), Vector3(side * 0.135, 1.17, -0.355), GOLD)
		Kit.part(parts, "box", Vector3(0.048, 0.06, 0.026), Vector3(side * 0.13, 1.16, -0.389), EYES)
		Kit.part(parts, "cone", Vector3(0.07, 0.13, 0.065), Vector3(side * 0.15, 0.99, -0.43), CREAM)
		Kit.beam(parts, Vector3(side * 0.29, 0.88, 0), Vector3(side * 0.42, 0.64, -0.19), 0.18, skin_color)
	Kit.beam(parts, Vector3(0.43, 0.40, -0.18), Vector3(0.43, 1.00, -0.23), 0.085, WOOD_LIGHT)
	if brute:
		Kit.part(parts, "ball", Vector3(0.70, 0.31, 0.58), Vector3(0, 1.37, -0.03), IRON)
		Kit.part(parts, "box", Vector3(0.13, 0.35, 0.55), Vector3(0, 1.35, -0.07), IRON_LIGHT)
		Kit.part(parts, "box", Vector3(0.71, 0.29, 0.45), Vector3(0, 0.79, 0), IRON)
		Kit.part(parts, "cylinder", Vector3(0.48, 0.39, 0.46), Vector3(0.43, 1.02, -0.23), IRON)
		Kit.part(parts, "cone", Vector3(0.17, 0.19, 0.17), Vector3(0.43, 1.30, -0.23), IRON_LIGHT)
		Kit.part(parts, "box", Vector3(0.38, 0.52, 0.13), Vector3(-0.49, 0.66, -0.30), WOOD)
		Kit.part(parts, "box", Vector3(0.11, 0.54, 0.16), Vector3(-0.49, 0.66, -0.31), IRON_LIGHT)
	else:
		Kit.part(parts, "cone", Vector3(0.19, 0.29, 0.10), Vector3(0.43, 1.10, -0.23), IRON_LIGHT)
		Kit.part(parts, "box", Vector3(0.62, 0.09, 0.45), Vector3(0, 1.34, -0.06), WOOD_DARK)
		if kind == "scout":
			Kit.part(parts, "cone", Vector3(0.15, 0.35, 0.15), Vector3(0.09, 1.51, -0.02), RED_DARK, Vector3(0.3, 0, -0.25))
	if kind == "ranger":
		# Wide crossbow and tall quiver make the ranged role legible by shape.
		Kit.beam(parts, Vector3(-0.65, 0.85, -0.5), Vector3(0.65, 0.85, -0.5), 0.15, WOOD_LIGHT)
		Kit.beam(parts, Vector3(0, 0.85, -0.15), Vector3(0, 0.85, -0.85), 0.18, IRON)
		Kit.part(parts, "cylinder", Vector3(0.30, 0.95, 0.30), Vector3(0, 1.06, 0.37), WOOD)
	if kind == "hunter":
		# Broad wolf pelt and paired long blades distinguish the pursuit role.
		Kit.part(parts, "roof", Vector3(0.94, 0.82, 0.25), Vector3(0, 0.89, 0.26), STONE_DARK, Vector3(0, 0, PI))
		Kit.part(parts, "ball", Vector3(0.80, 0.38, 0.64), Vector3(0, 1.36, 0), STONE_DARK)
		for side: float in [-1.0, 1.0]:
			Kit.part(parts, "cone", Vector3(0.23, 0.38, 0.22), Vector3(side * 0.28, 1.60, 0), STONE_LIGHT)
			Kit.beam(parts, Vector3(side * 0.46, 0.65, -0.2), Vector3(side * 0.60, 0.75, -0.91), 0.13, IRON_LIGHT)
	var root: Node3D = Kit.model("goblin_" + kind, parts, 0.42)
	if brute:
		root.scale = Vector3.ONE * 1.28
	return root

static func building(kind: String, tier: int) -> Node3D:
	var parts: Array = []
	var rank: int = clampi(tier, 1, 3)
	match kind:
		"tower": _tower(parts, rank)
		"wall": _wall(parts, rank)
		"mine": _mine(parts, rank)
		"smith": _smith(parts, rank)
		"keep": _keep(parts, rank)
		_: _tower(parts, rank)
	var root: Node3D = Kit.model("%s_tier_%d" % [kind, rank], parts)
	# Workshop activity faces the portrait camera; defenses still face the horde.
	if kind == "mine" or kind == "smith":
		(root.get_node("Body") as Node3D).rotation.y = PI
	return root

static func _tower(parts: Array, tier: int) -> void:
	var height: float = [1.25, 1.95, 2.65][tier - 1]
	Kit.part(parts, "cylinder", Vector3(1.95, 0.18, 1.95), Vector3(0, 0.09, 0), STONE_DARK)
	if tier == 1:
		for x: float in [-0.51, 0.51]:
			for z: float in [-0.51, 0.51]:
				Kit.part(parts, "box", Vector3(0.22, height, 0.22), Vector3(x, height * 0.5 + 0.12, z), WOOD)
		Kit.beam(parts, Vector3(-0.51, 0.31, 0.52), Vector3(0.51, 1.20, 0.52), 0.12, WOOD_LIGHT, "box")
		Kit.beam(parts, Vector3(0.51, 0.31, -0.52), Vector3(-0.51, 1.20, -0.52), 0.12, WOOD_LIGHT, "box")
	else:
		Kit.part(parts, "cylinder", Vector3(1.24, height, 1.24), Vector3(0, height * 0.5 + 0.10, 0), STONE)
		for y: float in [0.27, 0.77, 1.27]:
			Kit.part(parts, "cylinder", Vector3(1.29, 0.10, 1.29), Vector3(0, y, 0), STONE_LIGHT)
		Kit.part(parts, "box", Vector3(0.23, 0.52, 0.025), Vector3(0, 0.95, -0.626), WOOD_DARK)
	Kit.part(parts, "box", Vector3(1.58, 0.20, 1.58), Vector3(0, height + 0.13, 0), WOOD_LIGHT if tier == 1 else STONE_LIGHT)
	for x: float in [-0.65, 0.65]:
		for z: float in [-0.65, 0.65]:
			Kit.part(parts, "box", Vector3(0.28, 0.48, 0.28), Vector3(x, height + 0.46, z), WOOD if tier == 1 else STONE)
	Kit.part(parts, "box", Vector3(1.47, 0.22, 0.13), Vector3(0, height + 0.43, 0.70), RED)
	# Large fixed crossbow gives a clear purpose even before its first shot.
	Kit.part(parts, "cylinder", Vector3(0.27, 0.42, 0.27), Vector3(0, height + 0.47, 0), IRON)
	Kit.part(parts, "box", Vector3(0.15, 0.16, 1.02), Vector3(0, height + 0.76, -0.16), WOOD_DARK)
	Kit.beam(parts, Vector3(-0.57, height + 0.76, -0.19), Vector3(0, height + 0.76, -0.48), 0.095, GOLD if tier == 3 else WOOD_LIGHT)
	Kit.beam(parts, Vector3(0.57, height + 0.76, -0.19), Vector3(0, height + 0.76, -0.48), 0.095, GOLD if tier == 3 else WOOD_LIGHT)
	Kit.beam(parts, Vector3(-0.57, height + 0.76, -0.19), Vector3(0.57, height + 0.76, -0.19), 0.026, CREAM)
	if tier >= 2:
		_banner(parts, Vector3(0.67, height + 0.50, 0.57), tier == 3)
	if tier == 3:
		Kit.part(parts, "box", Vector3(1.58, 0.12, 1.58), Vector3(0, height + 0.24, 0), GOLD)
		# The final tower gains a wide upper weapon deck and two side launchers.
		Kit.part(parts, "box", Vector3(2.40, 0.22, 1.32), Vector3(0, height + 0.34, 0), STONE_LIGHT)
		for side: float in [-1.0, 1.0]:
			Kit.part(parts, "box", Vector3(0.25, 0.52, 0.45), Vector3(side * 0.88, height + 0.67, 0), RED_DARK)
			Kit.beam(parts, Vector3(side * 0.88, height + 0.98, 0.3), Vector3(side * 0.88, height + 0.98, -0.88), 0.17, IRON)
			Kit.beam(parts, Vector3(side * 0.88 - 0.31, height + 0.98, -0.4), Vector3(side * 0.88 + 0.31, height + 0.98, -0.4), 0.13, GOLD)
			Kit.beam(parts, Vector3(side * 0.52, height - 0.72, 0), Vector3(side * 1.06, height + 0.28, 0), 0.18, STONE_DARK)

		Kit.part(parts, "box", Vector3(0.11, 0.11, 0.86), Vector3(-0.20, height + 0.92, -0.12), IRON)
		Kit.part(parts, "box", Vector3(0.11, 0.11, 0.86), Vector3(0.20, height + 0.92, -0.12), IRON)

static func _wall(parts: Array, tier: int) -> void:
	Kit.part(parts, "box", Vector3(3.0, 0.14, 0.78), Vector3(0, 0.07, 0), STONE_DARK)
	if tier == 1:
		for index: int in range(9):
			var x: float = -1.32 + float(index) * 0.33
			Kit.part(parts, "cylinder", Vector3(0.28, 0.90, 0.28), Vector3(x, 0.56, 0), WOOD_LIGHT if index % 2 == 0 else WOOD)
			Kit.part(parts, "cone", Vector3(0.28, 0.24, 0.28), Vector3(x, 1.13, 0), WOOD_LIGHT)
		for y: float in [0.36, 0.76]:
			Kit.part(parts, "box", Vector3(2.94, 0.13, 0.13), Vector3(0, y, -0.20), WOOD_DARK)
	else:
		var height: float = 1.12 if tier == 2 else 1.43
		Kit.part(parts, "box", Vector3(2.92, height, 0.67), Vector3(0, height * 0.5 + 0.11, 0), STONE)
		for y: float in [0.38, 0.77, 1.08]:
			Kit.part(parts, "box", Vector3(2.97, 0.045, 0.70), Vector3(0, y, 0), STONE_DARK)
		for x: float in [-1.26, -0.63, 0.0, 0.63, 1.26]:
			Kit.part(parts, "box", Vector3(0.36, 0.34, 0.72), Vector3(x, height + 0.26, 0), STONE_LIGHT)
		if tier == 3:
			# A small gatehouse silhouette replaces a barely taller crenellated wall.
			for x: float in [-1.25, 1.25]:
				Kit.part(parts, "box", Vector3(0.65, 2.0, 0.95), Vector3(x, 1.05, 0), STONE_DARK)
				Kit.part(parts, "roof", Vector3(0.85, 0.65, 1.08), Vector3(x, 2.30, 0), RED)
				Kit.part(parts, "box", Vector3(0.16, 0.60, 0.06), Vector3(x, 1.55, 0.49), WOOD_DARK)
			for x: float in [-1.21, 1.21]:
				Kit.part(parts, "box", Vector3(0.32, 1.60, 0.77), Vector3(x, 0.84, 0), IRON)
			Kit.part(parts, "box", Vector3(0.63, 0.71, 0.08), Vector3(0, 0.94, -0.385), RED)
			Kit.part(parts, "box", Vector3(0.14, 0.46, 0.10), Vector3(0, 0.97, -0.435), GOLD)

static func _mine(parts: Array, tier: int) -> void:
	Kit.part(parts, "cylinder", Vector3(2.05, 0.14, 2.05), Vector3(0, 0.07, 0), STONE_DARK)
	Kit.part(parts, "ball", Vector3(1.75, 1.40 + tier * 0.13, 1.55), Vector3(0, 0.63, 0.20), STONE_DARK)
	Kit.part(parts, "ball", Vector3(0.90, 0.92, 0.94), Vector3(-0.50, 0.48, 0), STONE)
	Kit.part(parts, "box", Vector3(0.82, 0.94, 0.10), Vector3(0.15, 0.53, -0.61), WOOD_DARK)
	for x: float in [-0.39, 0.65]:
		Kit.part(parts, "box", Vector3(0.20, 1.10, 0.22), Vector3(x, 0.63, -0.72), WOOD_LIGHT)
	Kit.part(parts, "box", Vector3(1.32, 0.23, 0.26), Vector3(0.13, 1.14, -0.72), WOOD)
	for x: float in [-0.10, 0.39]:
		Kit.part(parts, "box", Vector3(0.065, 0.05, 0.96), Vector3(x, 0.16, -0.51), IRON)
	for z: float in [-0.90, -0.62, -0.34]:
		Kit.part(parts, "box", Vector3(0.81, 0.05, 0.10), Vector3(0.15, 0.13, z), WOOD)
	for i: int in range(2 + tier):
		Kit.part(parts, "ball", Vector3(0.26, 0.25, 0.20), Vector3(-0.70 + i * 0.15, 0.88 + (i % 2) * 0.19, -0.36), GOLD)
	if tier >= 2:
		# An exposed winding wheel makes extraction machinery readable from the side.
		Kit.part(parts, "cylinder", Vector3(0.82, 0.16, 0.82), Vector3(-0.87, 0.90, -0.36), IRON, Vector3(0, 0, PI / 2))
		Kit.part(parts, "cylinder", Vector3(0.55, 0.18, 0.55), Vector3(-0.88, 0.90, -0.36), GOLD, Vector3(0, 0, PI / 2))
		# A tall timber shelter makes the second tier obvious above the ore hill.
		for x: float in [-0.64, 0.64]:
			Kit.part(parts, "box", Vector3(0.19, 1.75, 0.19), Vector3(x, 0.98, -0.51), WOOD)
			Kit.part(parts, "box", Vector3(0.23, 0.18, 0.23), Vector3(x, 0.34, -0.51), IRON)
		Kit.part(parts, "box", Vector3(1.76, 0.24, 0.27), Vector3(0, 1.92, -0.51), WOOD_LIGHT)
		Kit.part(parts, "roof", Vector3(1.93, 0.52, 1.06), Vector3(0, 2.25, -0.29), RED)
		Kit.part(parts, "box", Vector3(1.98, 0.10, 0.12), Vector3(0, 2.53, -0.29), RED_LIGHT)
		Kit.part(parts, "box", Vector3(0.62, 0.35, 0.49), Vector3(0.51, 0.32, -0.82), IRON)
		Kit.part(parts, "ball", Vector3(0.49, 0.25, 0.36), Vector3(0.51, 0.53, -0.82), GOLD)
		for x: float in [0.24, 0.79]:
			Kit.part(parts, "cylinder", Vector3(0.20, 0.07, 0.20), Vector3(x, 0.19, -0.85), WOOD_DARK, Vector3(0, 0, PI / 2))
	if tier == 3:
		# The final tier adds a full overhead ore hoist above the existing shelter.
		# Its grounded posts fit the support radius; the upper beam can overhang.
		for x: float in [-0.66, 0.66]:
			Kit.part(parts, "box", Vector3(0.16, 3.02, 0.16), Vector3(x, 1.66, -0.62), WOOD_DARK)
			Kit.part(parts, "box", Vector3(0.22, 0.28, 0.22), Vector3(x, 2.92, -0.62), IRON)
		Kit.part(parts, "box", Vector3(2.13, 0.25, 0.28), Vector3(0, 3.21, -0.62), WOOD_LIGHT)
		Kit.part(parts, "box", Vector3(2.16, 0.08, 0.31), Vector3(0, 3.37, -0.62), GOLD)
		Kit.part(parts, "cylinder", Vector3(0.53, 0.12, 0.53), Vector3(0, 3.04, -0.79), IRON, Vector3(PI / 2, 0, 0))
		Kit.part(parts, "cylinder", Vector3(0.27, 0.15, 0.27), Vector3(0, 3.04, -0.79), GOLD, Vector3(PI / 2, 0, 0))
		Kit.beam(parts, Vector3(0, 2.99, -0.87), Vector3(0, 2.32, -0.87), 0.04, CREAM)
		Kit.part(parts, "box", Vector3(0.38, 0.33, 0.33), Vector3(0, 2.24, -0.85), IRON)
		Kit.part(parts, "ball", Vector3(0.32, 0.21, 0.28), Vector3(0, 2.43, -0.85), GOLD)
		_banner(parts, Vector3(0.85, 1.88, 0.28), true)

static func _smith(parts: Array, tier: int) -> void:
	# The footprint stays inside the same support plot. Progression grows upward:
	# cottage -> raised stone forge and canopy -> tall workshop with twin stacks.
	var wall_height: float = [0.96, 1.36, 1.78][tier - 1]
	var wall_width: float = [1.43, 1.51, 1.57][tier - 1]
	var wall_top: float = 0.12 + wall_height
	var roof_height: float = [0.77, 0.87, 0.96][tier - 1]
	var roof_top: float = wall_top + roof_height
	var masonry: Color = CREAM if tier == 1 else STONE
	Kit.part(parts, "cylinder", Vector3(2.15, 0.15, 2.15), Vector3(0, 0.075, 0), STONE_DARK)
	Kit.part(parts, "box", Vector3(wall_width, wall_height, 1.24), Vector3(0, 0.12 + wall_height * 0.5, 0.03), masonry)
	for x: float in [-0.66, 0.66]:
		Kit.part(parts, "box", Vector3(0.12, wall_height + 0.06, 1.30), Vector3(x, 0.12 + wall_height * 0.5, 0.03), WOOD if tier == 1 else STONE_LIGHT)
	if tier == 2:
		# The expanded forge has a broad flat canopy rather than the cottage gable.
		Kit.part(parts, "box", Vector3(2.13, 0.25, 1.76), Vector3(0, wall_top + 0.28, 0.03), RED)
		Kit.part(parts, "box", Vector3(2.18, 0.10, 0.13), Vector3(0, wall_top + 0.45, -0.78), RED_LIGHT)
	else:
		Kit.part(parts, "roof", Vector3(1.83 + (tier - 1) * 0.08, roof_height, 1.61), Vector3(0, wall_top + roof_height * 0.5, 0.03), RED)
	var chimney_x: Array[float] = [0.43]
	if tier == 3:
		chimney_x.assign([-0.49, 0.49])
	for x: float in chimney_x:
		var chimney_top: float = roof_top + (0.48 if tier == 3 else 0.30)
		var chimney_base: float = wall_top - 0.25
		Kit.part(parts, "box", Vector3(0.43 if tier == 3 else 0.57, chimney_top - chimney_base, 0.48), Vector3(x, (chimney_top + chimney_base) * 0.5, 0.29), STONE_LIGHT if tier == 3 else STONE)
		Kit.part(parts, "box", Vector3(0.55 if tier == 3 else 0.67, 0.17, 0.59), Vector3(x, chimney_top, 0.29), GOLD if tier == 3 else STONE_LIGHT)
		Kit.part(parts, "box", Vector3(0.31, 0.035, 0.33), Vector3(x, chimney_top + 0.10, 0.29), WOOD_DARK)
	var furnace_x: Array[float] = [-0.11]
	if tier == 3:
		furnace_x.assign([-0.35, 0.35])
	for x: float in furnace_x:
		var furnace_width: float = 0.49 if tier == 3 else (0.88 if tier == 2 else 0.60)
		var furnace_height: float = 0.93 if tier >= 2 else 0.72
		var furnace_center: float = furnace_height * 0.5 + 0.18
		Kit.part(parts, "box", Vector3(furnace_width, furnace_height, 0.055), Vector3(x, furnace_center, -0.61), WOOD_DARK)
		Kit.part(parts, "ball", Vector3(furnace_width * 0.72, furnace_height * 0.60, 0.055), Vector3(x, furnace_center - 0.08, -0.65), RED_LIGHT)
		Kit.part(parts, "cone", Vector3(furnace_width * 0.44, furnace_height * 0.67, 0.065), Vector3(x, furnace_center - 0.02, -0.69), GOLD)
	# Anvil occupies the front workyard; long horn faces -X.
	Kit.part(parts, "cylinder", Vector3(0.47, 0.33, 0.47), Vector3(0.50, 0.26, -0.78), WOOD)
	Kit.part(parts, "box", Vector3(0.31, 0.24, 0.30), Vector3(0.50, 0.52, -0.78), IRON)
	Kit.part(parts, "box", Vector3(0.61, 0.16, 0.32), Vector3(0.47, 0.67, -0.78), IRON_LIGHT)
	Kit.part(parts, "cone", Vector3(0.22, 0.37, 0.20), Vector3(0.05, 0.67, -0.78), IRON_LIGHT, Vector3(0, 0, PI / 2))
	if tier >= 2:
		Kit.part(parts, "box", Vector3(wall_width + 0.03, 0.15, 1.29), Vector3(0, wall_top - 0.12, 0.03), STONE_LIGHT)
		# Raised red work canopy is a large second silhouette beneath the main roof.
		Kit.part(parts, "roof", Vector3(1.87, 0.33, 0.60), Vector3(0, 1.37, -0.66), RED_LIGHT)
		for x: float in [-0.63, 0.63]:
			Kit.part(parts, "box", Vector3(0.10, 1.14, 0.10), Vector3(x, 0.72, -0.69), WOOD_DARK)
	if tier == 3:
		# Prominent upper workshop window and roof crest distinguish the final tier.
		Kit.part(parts, "box", Vector3(0.69, 0.49, 0.07), Vector3(0, 1.64, -0.65), RED_DARK)
		Kit.part(parts, "box", Vector3(0.51, 0.30, 0.09), Vector3(0, 1.64, -0.70), GOLD)
		Kit.part(parts, "box", Vector3(0.06, 0.33, 0.11), Vector3(0, 1.64, -0.76), WOOD_DARK)
		Kit.part(parts, "box", Vector3(2.03, 0.12, 0.13), Vector3(0, roof_top + 0.02, 0.03), GOLD)

static func _keep(parts: Array, tier: int) -> void:
	Kit.part(parts, "cylinder", Vector3(4.0, 0.22, 4.0), Vector3(0, 0.11, 0), STONE_DARK)
	Kit.part(parts, "box", Vector3(2.45, 2.0, 2.04), Vector3(0, 1.17, 0.05), CREAM)
	Kit.part(parts, "box", Vector3(2.59, 0.25, 2.13), Vector3(0, 0.35, 0.05), STONE)
	Kit.part(parts, "roof", Vector3(2.87, 1.25, 2.56), Vector3(0, 2.75, 0.05), RED)
	for side: float in [-1.0, 1.0]:
		Kit.part(parts, "cylinder", Vector3(0.93, 2.20, 0.93), Vector3(side * 1.24, 1.25, -0.52), STONE)
		Kit.part(parts, "cylinder", Vector3(1.07, 0.20, 1.07), Vector3(side * 1.24, 2.27, -0.52), STONE_LIGHT)
		Kit.part(parts, "cone", Vector3(1.18, 0.95, 1.18), Vector3(side * 1.24, 2.84, -0.52), RED_LIGHT)
		Kit.part(parts, "box", Vector3(0.18, 0.51, 0.06), Vector3(side * 1.24, 1.71, -0.99), WOOD_DARK)
	Kit.part(parts, "box", Vector3(0.88, 1.42, 0.06), Vector3(0, 0.89, -0.998), WOOD_DARK)
	Kit.part(parts, "box", Vector3(0.70, 1.22, 0.06), Vector3(0, 0.80, -1.039), WOOD)
	for x: float in [-0.22, 0.0, 0.22]:
		Kit.part(parts, "box", Vector3(0.055, 1.18, 0.09), Vector3(x, 0.82, -1.075), IRON)
	Kit.part(parts, "box", Vector3(0.76, 0.12, 0.11), Vector3(0, 0.94, -1.09), GOLD)
	Kit.part(parts, "box", Vector3(1.0, 0.10, 0.66), Vector3(0, 0.13, -1.37), STONE_LIGHT)
	Kit.part(parts, "box", Vector3(0.50, 0.55, 0.065), Vector3(0, 1.89, -1.04), RED)
	Kit.part(parts, "cone", Vector3(0.23, 0.32, 0.08), Vector3(0, 1.90, -1.10), GOLD)
	# Rear facade remains legible while the player approaches from the south.
	for x: float in [-0.64, 0.64]:
		Kit.part(parts, "box", Vector3(0.32, 0.59, 0.045), Vector3(x, 1.46, 1.09), WOOD_DARK)
		Kit.part(parts, "box", Vector3(0.21, 0.45, 0.055), Vector3(x, 1.46, 1.12), GOLD)
		Kit.part(parts, "box", Vector3(0.035, 0.48, 0.065), Vector3(x, 1.46, 1.15), WOOD)
	Kit.part(parts, "box", Vector3(0.52, 0.87, 0.075), Vector3(0, 1.46, 1.11), RED)
	Kit.part(parts, "cone", Vector3(0.24, 0.37, 0.095), Vector3(0, 1.48, 1.16), GOLD)
	_banner(parts, Vector3(0, 3.34, 0), true)
	if tier >= 2:
		for side: float in [-1.0, 1.0]:
			Kit.part(parts, "box", Vector3(0.43, 1.0, 0.43), Vector3(side * 1.48, 0.68, 0.68), STONE_LIGHT)
	if tier == 3:
		Kit.part(parts, "box", Vector3(2.61, 0.14, 2.20), Vector3(0, 2.19, 0.05), GOLD)

static func _banner(parts: Array, at: Vector3, gold: bool = false) -> void:
	Kit.beam(parts, at, at + Vector3(0, 0.92, 0), 0.055, WOOD_DARK)
	Kit.part(parts, "box", Vector3(0.48, 0.37, 0.045), at + Vector3(0.24, 0.67, 0), RED_LIGHT)
	Kit.part(parts, "box", Vector3(0.075, 0.37, 0.052), at + Vector3(0.43, 0.67, 0), GOLD if gold else CREAM)
	Kit.part(parts, "ball", Vector3.ONE * 0.10, at + Vector3(0, 0.96, 0), GOLD)

static func plot(category: String) -> Node3D:
	var parts: Array = []
	var radius: float = 1.14 if category != "wall" else 1.42
	Kit.part(parts, "cylinder", Vector3(radius * 2, 0.065, radius * 2), Vector3(0, 0.033, 0), Color("7c9c67"))
	# Four chunky corners communicate a build footprint from the angled camera.
	for index: int in range(4):
		var angle: float = TAU * float(index) / 4.0 + PI / 4
		var at := Vector3(cos(angle) * radius * 0.76, 0.095, sin(angle) * radius * 0.76)
		Kit.part(parts, "box", Vector3(0.29, 0.10, 0.29), at, CREAM)
	var icon_color := Color("e6ddb0")
	if category == "tower":
		Kit.part(parts, "box", Vector3(0.42, 0.055, 0.64), Vector3(0, 0.08, 0), icon_color)
		for x: float in [-0.19, 0.19]:
			Kit.part(parts, "box", Vector3(0.16, 0.055, 0.22), Vector3(x, 0.08, -0.35), icon_color)
	elif category == "wall":
		Kit.part(parts, "box", Vector3(1.20, 0.055, 0.25), Vector3(0, 0.08, 0), icon_color)
		for x: float in [-0.49, 0.0, 0.49]:
			Kit.part(parts, "box", Vector3(0.22, 0.055, 0.26), Vector3(x, 0.08, -0.23), icon_color)
	else:
		Kit.part(parts, "box", Vector3(0.73, 0.055, 0.20), Vector3(0, 0.08, 0), icon_color)
		Kit.part(parts, "box", Vector3(0.20, 0.055, 0.73), Vector3(0, 0.081, 0), icon_color)
	return Kit.model("plot_" + category, parts)

static func coin() -> Node3D:
	var parts: Array = []
	Kit.part(parts, "cylinder", Vector3(0.39, 0.09, 0.39), Vector3.ZERO, GOLD, Vector3(PI / 2, 0, 0))
	Kit.part(parts, "cylinder", Vector3(0.28, 0.103, 0.28), Vector3.ZERO, Color("f9df8b"), Vector3(PI / 2, 0, 0))
	Kit.part(parts, "box", Vector3(0.055, 0.19, 0.111), Vector3.ZERO, GOLD)
	return Kit.model("coin", parts)

static func arrow() -> Node3D:
	var parts: Array = []
	Kit.beam(parts, Vector3(0, 0, 0.35), Vector3(0, 0, -0.35), 0.044, CREAM)
	Kit.part(parts, "cone", Vector3(0.12, 0.24, 0.10), Vector3(0, 0, -0.42), IRON_LIGHT, Vector3(-PI / 2, 0, 0))
	Kit.part(parts, "box", Vector3(0.22, 0.018, 0.18), Vector3(0, 0, 0.29), RED_LIGHT)
	return Kit.model("arrow", parts)

static func piercing_arrow() -> Node3D:
	var parts: Array = []
	Kit.beam(parts, Vector3(0, 0, 1.25), Vector3(0, 0, -0.50), 0.085, GOLD)
	Kit.part(parts, "cone", Vector3(0.38, 0.65, 0.28), Vector3(0, 0, -0.60), CREAM, Vector3(-PI / 2, 0, 0))
	for z: float in [0.25, 0.70, 1.15]:
		Kit.beam(parts, Vector3(-0.24, 0, z + 0.18), Vector3(0, 0, z), 0.065, GOLD)
		Kit.beam(parts, Vector3(0.24, 0, z + 0.18), Vector3(0, 0, z), 0.065, GOLD)
	return Kit.model("piercing_spear", parts)

static func enemy_bolt() -> Node3D:
	var parts: Array = []
	Kit.beam(parts, Vector3(0, 0, 0.45), Vector3(0, 0, -0.40), 0.14, WOOD_DARK)
	Kit.part(parts, "cone", Vector3(0.32, 0.36, 0.28), Vector3(0, 0, -0.5), GOLD, Vector3(-PI / 2, 0, 0))
	for turn: float in [0.0, PI / 2]:
		Kit.part(parts, "box", Vector3(0.5, 0.06, 0.3), Vector3(0, 0, 0.32), Color("ff7954"), Vector3(0, 0, turn))
	return Kit.model("hostile_crossbow_bolt", parts)

static func ring(radius: float, color: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "FloorRing"
	var mesh := MeshInstance3D.new()
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	var width: float = clampf(radius * 0.027, 0.065, 0.15)
	for index: int in range(64):
		var a: float = TAU * float(index) / 64.0
		var b: float = TAU * float(index + 1) / 64.0
		var outer_a := Vector3(cos(a) * radius, 0, sin(a) * radius)
		var outer_b := Vector3(cos(b) * radius, 0, sin(b) * radius)
		var inner_a := Vector3(cos(a) * (radius - width), 0, sin(a) * (radius - width))
		var inner_b := Vector3(cos(b) * (radius - width), 0, sin(b) * (radius - width))
		for point: Vector3 in [outer_a, inner_a, outer_b, outer_b, inner_a, inner_b]:
			builder.set_normal(Vector3.UP)
			builder.add_vertex(point)
	mesh.mesh = builder.commit()
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material_override = material
	mesh.position.y = 0.055
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mesh)
	return root

static func tree(variant: int = 0) -> Node3D:
	var parts: Array = []
	Kit.part(parts, "cylinder", Vector3(0.32, 1.18, 0.32), Vector3(0, 0.59, 0), WOOD)
	if variant % 2 == 0:
		Kit.part(parts, "cone", Vector3(2.03, 2.06, 2.03), Vector3(0, 1.66, 0), Color("407a56"))
		Kit.part(parts, "cone", Vector3(1.55, 1.74, 1.55), Vector3(0, 2.31, 0), Color("56935d"))
		Kit.part(parts, "cone", Vector3(0.98, 1.42, 0.98), Vector3(0, 2.93, 0), Color("79a967"))
	else:
		Kit.part(parts, "ball", Vector3(2.05, 1.74, 1.86), Vector3(-0.16, 1.88, 0), Color("729d5c"))
		Kit.part(parts, "ball", Vector3(1.34, 1.46, 1.46), Vector3(0.61, 1.92, 0.09), Color("86ac60"))
		Kit.part(parts, "ball", Vector3(1.48, 1.27, 1.47), Vector3(-0.22, 2.53, 0.04), Color("9ab766"))
	return Kit.model("tree_%d" % (variant % 2), parts)

static func rock(variant: int = 0) -> Node3D:
	var parts: Array = []
	Kit.part(parts, "ball", Vector3(1.24, 0.86, 1.0), Vector3(0, 0.28, 0), STONE_DARK, Vector3(0.12, float(variant) * 0.8, 0.13))
	Kit.part(parts, "ball", Vector3(0.59, 0.40, 0.60), Vector3(0.38, 0.14, -0.15), STONE)
	return Kit.model("rock_%d" % variant, parts)
