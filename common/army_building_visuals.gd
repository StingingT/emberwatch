class_name ArmyBuildingVisuals
extends RefCounted
## Simplified believable Archer Tower architecture. Art-only: combat and footprints unchanged.
const Base = preload("res://common/visuals.gd")
const Kit = preload("res://common/visual_mesh_kit.gd")
const HEIGHTS: Array[float] = [1.85, 2.65, 3.40]
const WIDTHS: Array[float] = [1.70, 2.24, 2.76]
const TIMBER := Color("765034")
const CUT_WOOD := Color("a57749")
const DARK_WOOD := Color("493321")
const STONE := Color("827f71")
const STONE_LIGHT := Color("a19b88")
const MORTAR := Color("5a5a50")
const IRON := Color("454c4b")
const RED := Color("b53d35")
const DARK_RED := Color("81322e")
const LINEN := Color("dec9a0")

static func building(kind: String, tier: int) -> Node3D:
	if kind != "tower":
		return Base.building(kind, tier)
	var rank := clampi(tier, 1, 3)
	var parts: Array = []
	if rank == 1:
		_wood_watchtower(parts)
	elif rank == 2:
		_stone_guard_tower(parts)
	else:
		_stone_stronghold(parts)
	var root := Kit.model("archer_tower_real_%d" % rank, parts)
	var crew := Node3D.new()
	crew.name = "Crew"
	root.add_child(crew)
	for i: int in range(rank):
		var archer := _archer()
		archer.name = "Archer%d" % (i + 1)
		var spacing := 0.0 if rank == 1 else (0.72 if rank == 2 else 0.82)
		archer.position = Vector3((i - (rank - 1) * 0.5) * spacing, HEIGHTS[rank - 1] + 0.14, -0.08 if i != 1 else 0.18)
		crew.add_child(archer)
	return root

static func _wood_watchtower(p: Array) -> void:
	var h := HEIGHTS[0]
	# Four real timber posts on stone feet, cross-braced into a raised platform.
	for x: float in [-0.55, 0.55]:
		for z: float in [-0.55, 0.55]:
			Kit.part(p, "box", Vector3(0.34,0.16,0.34), Vector3(x,0.08,z), STONE)
			Kit.part(p, "box", Vector3(0.22,h,0.22), Vector3(x,h*0.5,z), TIMBER)
		Kit.beam(p, Vector3(x,0.25,-0.55), Vector3(x,h-0.18,0.55), 0.13, CUT_WOOD, "box")
		Kit.beam(p, Vector3(x,0.25,0.55), Vector3(x,h-0.18,-0.55), 0.13, TIMBER, "box")
	Kit.part(p, "box", Vector3(1.70,0.20,1.70), Vector3(0,h,0), DARK_WOOD)
	for i: int in range(7):
		Kit.part(p, "box", Vector3(0.22,0.06,1.62), Vector3(-0.66+i*0.22,h+0.13,0), CUT_WOOD if i%2==0 else TIMBER)
	# Waist-high rails and corner uprights.
	for x: float in [-0.78,0.78]:
		Kit.part(p, "box", Vector3(0.12,0.48,0.12), Vector3(x,h+0.31,-0.72), TIMBER)
		Kit.part(p, "box", Vector3(0.12,0.48,0.12), Vector3(x,h+0.31,0.72), TIMBER)
		Kit.part(p, "box", Vector3(0.10,0.12,1.55), Vector3(x,h+0.49,0), CUT_WOOD)
	Kit.part(p, "box", Vector3(1.55,0.12,0.10), Vector3(0,h+0.49,-0.78), CUT_WOOD)
	# Ladder on the rear side.
	for x: float in [-0.22,0.22]:
		Kit.beam(p, Vector3(x,0.10,0.92), Vector3(x,h+0.25,0.70), 0.07, DARK_WOOD, "box")
	for i: int in range(8):
		var y := 0.24 + i*0.21
		Kit.part(p, "box", Vector3(0.48,0.06,0.07), Vector3(0,y,0.90-i*0.025), CUT_WOOD)
	_banner(p, Vector3(0,h-0.12,0.87), 0.44,0.55)
	_flag(p, Vector3(0.66,h+0.08,0.65), 1.25)

static func _stone_guard_tower(p: Array) -> void:
	var h := HEIGHTS[1]
	# A coherent masonry body, doorway and battlement rather than stacked cubes.
	Kit.part(p, "cylinder", Vector3(1.82,h,1.82), Vector3(0,h*0.5,0), MORTAR)
	for y: float in [0.28,0.72,1.16,1.60,2.04]:
		Kit.part(p, "cylinder", Vector3(1.88,0.34,1.88), Vector3(0,y,0), STONE if int(y*10)%2==0 else STONE_LIGHT)
	Kit.part(p, "cylinder", Vector3(2.18,0.24,2.18), Vector3(0,h,0), STONE_LIGHT)
	# Door and two arrow slits.
	Kit.part(p, "box", Vector3(0.55,0.92,0.05), Vector3(0,0.47,0.93), DARK_WOOD)
	for x: float in [-0.42,0.42]:
		Kit.part(p, "box", Vector3(0.10,0.42,0.04), Vector3(x,1.55,0.94), DARK_WOOD)
	# Parapet ring represented by connected wall runs plus merlons.
	for side: float in [-1.0,1.0]:
		Kit.part(p, "box", Vector3(2.10,0.28,0.18), Vector3(0,h+0.25,side*0.96), STONE)
		Kit.part(p, "box", Vector3(0.18,0.28,1.74), Vector3(side*0.96,h+0.25,0), STONE)
	for x: float in [-0.82,0,0.82]:
		for z: float in [-0.98,0.98]:
			Kit.part(p, "box", Vector3(0.34,0.30,0.26), Vector3(x,h+0.54,z), STONE_LIGHT)
	for z: float in [-0.60,0.60]:
		for x: float in [-0.98,0.98]:
			Kit.part(p, "box", Vector3(0.26,0.30,0.34), Vector3(x,h+0.54,z), STONE_LIGHT)
	_banner(p, Vector3(0,1.85,0.97),0.38,0.58)
	_flag(p, Vector3(0.72,h+0.08,0.70),1.35)

static func _stone_stronghold(p: Array) -> void:
	var h := HEIGHTS[2]
	# Thick square tower with corner piers, stone courses and a timber fighting deck.
	Kit.part(p, "box", Vector3(2.02,h,2.02), Vector3(0,h*0.5,0), MORTAR)
	for row: int in range(8):
		var y := 0.24 + row*0.39
		Kit.part(p, "box", Vector3(2.08,0.34,2.08), Vector3(0,y,0), STONE if row%2==0 else STONE_LIGHT)
	for x: float in [-0.94,0.94]:
		for z: float in [-0.94,0.94]:
			Kit.part(p, "box", Vector3(0.28,h,0.28), Vector3(x,h*0.5,z), STONE_LIGHT)
	Kit.part(p, "box", Vector3(2.76,0.25,2.76), Vector3(0,h,0), STONE_LIGHT)
	for i: int in range(9):
		Kit.part(p, "box", Vector3(0.25,0.04,2.30), Vector3(-1.0+i*0.25,h+0.15,0), CUT_WOOD if i%2==0 else TIMBER)
	# Supported battlements and restrained iron straps.
	for side: float in [-1.0,1.0]:
		Kit.part(p, "box", Vector3(2.70,0.28,0.20), Vector3(0,h+0.27,side*1.25), STONE)
		Kit.part(p, "box", Vector3(0.20,0.28,2.30), Vector3(side*1.25,h+0.27,0), STONE)
		Kit.part(p, "box", Vector3(2.72,0.06,0.04), Vector3(0,h-0.02,side*1.37), IRON)
	for x: float in [-1.02,-0.34,0.34,1.02]:
		for z: float in [-1.27,1.27]:
			Kit.part(p, "box", Vector3(0.34,0.32,0.28), Vector3(x,h+0.58,z), STONE_LIGHT)
	for z: float in [-0.72,0,0.72]:
		for x: float in [-1.27,1.27]:
			Kit.part(p, "box", Vector3(0.28,0.32,0.34), Vector3(x,h+0.58,z), STONE_LIGHT)
	Kit.part(p, "box", Vector3(0.62,1.12,0.05), Vector3(0,0.58,1.04), DARK_WOOD)
	for x: float in [-0.48,0.48]:
		Kit.part(p, "box", Vector3(0.10,0.46,0.04), Vector3(x,1.78,1.05), DARK_WOOD)
	_banner(p, Vector3(0,2.42,1.05),0.52,0.78)
	_flag(p, Vector3(1.03,h+0.08,0.98),1.45)

static func _banner(p:Array, at:Vector3, w:float, h:float) -> void:
	Kit.part(p,"box",Vector3(w+0.14,0.06,0.07),at+Vector3(0,h*0.5,0),IRON)
	Kit.part(p,"box",Vector3(w,h,0.025),at,RED)
	Kit.part(p,"box",Vector3(w*0.24,w*0.24,0.02),at+Vector3(0,h*0.08,0.02),LINEN,Vector3(0,0,PI*0.25))

static func _flag(p:Array, foot:Vector3, h:float) -> void:
	Kit.beam(p,foot,foot+Vector3(0,h,0),0.055,DARK_WOOD)
	Kit.part(p,"box",Vector3(0.40,0.25,0.025),foot+Vector3(-0.21,h-0.20,0),RED)
	Kit.part(p,"box",Vector3(0.055,0.25,0.035),foot+Vector3(-0.06,h-0.20,0),DARK_RED)

static func _archer() -> Node3D:
	var p:Array=[]
	for x:float in [-0.11,0.11]:
		Kit.part(p,"box",Vector3(0.15,0.22,0.22),Vector3(x,0.11,0),DARK_WOOD)
	Kit.part(p,"box",Vector3(0.36,0.37,0.28),Vector3(0,0.40,0),RED)
	Kit.part(p,"ball",Vector3(0.39,0.39,0.36),Vector3(0,0.77,0),DARK_RED)
	Kit.part(p,"ball",Vector3(0.28,0.27,0.24),Vector3(0,0.75,-0.13),Base.SKIN)
	Kit.beam(p,Vector3(-0.24,0.28,-0.22),Vector3(-0.35,0.52,-0.35),0.055,CUT_WOOD)
	Kit.beam(p,Vector3(-0.35,0.52,-0.35),Vector3(-0.24,0.91,-0.22),0.055,CUT_WOOD)
	Kit.beam(p,Vector3(-0.24,0.28,-0.22),Vector3(-0.24,0.91,-0.22),0.012,LINEN)
	var model:=Kit.model("real_tower_archer",p)
	var muzzle:=Marker3D.new()
	muzzle.name="Muzzle"
	muzzle.position=Vector3(-0.34,0.57,-0.39)
	model.add_child(muzzle)
	return model

static func firing_points(model:Node3D,target:Vector3)->Array[Vector3]:
	var result:Array[Vector3]=[]
	var crew:Node3D=model.get_node_or_null("Crew")
	if crew==null:
		return result
	for archer:Node3D in crew.get_children():
		var aim:=Vector3(target.x,archer.global_position.y,target.z)
		if archer.global_position.distance_squared_to(aim)>0.001:
			archer.look_at(aim,Vector3.UP)
		result.append(archer.get_node("Muzzle").global_position)
	return result
