class_name Battlefield
extends Node3D
## Flat, walkable grassland. Scenery deliberately stays beyond movement bounds.

const Visuals = preload("res://common/visuals.gd")
const Kit = preload("res://common/visual_mesh_kit.gd")

func setup(level: Dictionary) -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	var bounds: Rect2 = level.get("bounds", Rect2(-10, -30, 20, 43))
	var route: Array[Vector3] = []
	for point: Vector3 in level.get("route", []):
		route.append(point)
	_daylight()
	_grassland(bounds)
	if route.size() >= 2:
		_trail(route, 3.45, 0.012, Color("aab273"), "RoadShoulder")
		_trail(route, 2.95, 0.022, Color("d7bf85"), "GoldenTrail")
		_trail_details(route)
	_edges(bounds)
	_keep_approach(level.get("keep", Vector3(0, 0, 9)))

func _daylight() -> void:
	var sky := WorldEnvironment.new()
	sky.name = "WarmDaylight"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("acc6b1")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.93, 0.96, 1.0)
	environment.ambient_light_energy = 0.72
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	sky.environment = environment
	add_child(sky)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-52, -34, 0)
	sun.light_color = Color(1.0, 0.97, 0.92)
	sun.light_energy = 0.72
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 75.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.shadow_bias = 0.045
	sun.shadow_normal_bias = 1.0
	add_child(sun)

func _grassland(bounds: Rect2) -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 2080912
	var outer: Rect2 = bounds.grow(28.0)
	var columns: int = 16
	var rows: int = 20
	var positions: Array[Vector3] = []
	for z_index: int in range(rows + 1):
		for x_index: int in range(columns + 1):
			var x: float = outer.position.x + outer.size.x * float(x_index) / float(columns)
			var z: float = outer.position.y + outer.size.y * float(z_index) / float(rows)
			if x_index > 0 and x_index < columns:
				x += random.randf_range(-1.45, 1.45)
			if z_index > 0 and z_index < rows:
				z += random.randf_range(-1.45, 1.45)
			positions.append(Vector3(x, -0.005, z))
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	var base := Color("83a866")
	for z_index: int in range(rows):
		for x_index: int in range(columns):
			var a: int = z_index * (columns + 1) + x_index
			var b: int = a + 1
			var c: int = a + columns + 1
			var d: int = c + 1
			var triangles: Array[int] = [a, b, c, b, d, c]
			for triangle: int in range(2):
				var shade: float = random.randf_range(-0.025, 0.025)
				var color := Color(base.r + shade, base.g + shade, base.b + shade * 0.6)
				for corner: int in range(3):
					builder.set_color(color.srgb_to_linear())
					builder.set_normal(Vector3.UP)
					builder.add_vertex(positions[triangles[triangle * 3 + corner]])
	var ground := MeshInstance3D.new()
	ground.name = "Meadow"
	ground.mesh = builder.commit()
	ground.material_override = Kit.paint()
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ground)

func _trail(route: Array[Vector3], width: float, height: float, color: Color, node_name: String) -> void:
	var points: Array[Vector3] = _rounded_route(route)
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	var left: Array[Vector3] = []
	var right: Array[Vector3] = []
	for index: int in range(points.size()):
		var previous: Vector3 = points[maxi(0, index - 1)]
		var next: Vector3 = points[mini(points.size() - 1, index + 1)]
		var direction: Vector3 = (next - previous).normalized()
		var side := Vector3(-direction.z, 0, direction.x) * width * 0.5
		var center := Vector3(points[index].x, height, points[index].z)
		left.append(center - side)
		right.append(center + side)
	for index: int in range(points.size() - 1):
		for vertex: Vector3 in [left[index], left[index + 1], right[index], right[index], left[index + 1], right[index + 1]]:
			builder.set_color(color.srgb_to_linear())
			builder.set_normal(Vector3.UP)
			builder.add_vertex(vertex)
	var trail := MeshInstance3D.new()
	trail.name = node_name
	trail.mesh = builder.commit()
	trail.material_override = Kit.paint()
	trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(trail)

func _rounded_route(route: Array[Vector3]) -> Array[Vector3]:
	# Quadratic corner rounding stays within the road's broad shoulder.
	var result: Array[Vector3] = [route[0]]
	for index: int in range(1, route.size() - 1):
		var previous: Vector3 = route[index - 1]
		var at: Vector3 = route[index]
		var next: Vector3 = route[index + 1]
		var incoming: Vector3 = at.lerp(previous, minf(0.22, 1.1 / maxf(0.01, at.distance_to(previous))))
		var outgoing: Vector3 = at.lerp(next, minf(0.22, 1.1 / maxf(0.01, at.distance_to(next))))
		for step: int in range(6):
			var progress: float = float(step) / 5.0
			result.append(incoming.lerp(at, progress).lerp(at.lerp(outgoing, progress), progress))
	result.append(route[-1])
	return result

func _trail_details(route: Array[Vector3]) -> void:
	var parts: Array = []
	var random := RandomNumberGenerator.new()
	random.seed = 4276
	for index: int in range(route.size() - 1):
		var start: Vector3 = route[index]
		var finish: Vector3 = route[index + 1]
		var direction: Vector3 = (finish - start).normalized()
		var side := Vector3(-direction.z, 0, direction.x)
		var count: int = maxi(1, int(start.distance_to(finish) / 2.2))
		for step: int in range(count):
			var t: float = (float(step) + 0.45) / float(count)
			var point: Vector3 = start.lerp(finish, t)
			point += side * random.randf_range(-1.13, 1.13)
			point.y = 0.030
			Kit.part(parts, "cylinder", Vector3(random.randf_range(0.18, 0.34), 0.010, random.randf_range(0.12, 0.22)), point, Color("c7af78"), Vector3(0, random.randf_range(0, TAU), 0))
	var detail: Node3D = Kit.model("trail_details_%s" % hash(route), parts)
	detail.name = "TrailPebbles"
	add_child(detail)

func _edges(bounds: Rect2) -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 387621
	# Every trunk, crown, rock and fence remains outside the walkable rectangle.
	for side: int in [-1, 1]:
		for index: int in range(16):
			var boundary_x: float = bounds.position.x if side == -1 else bounds.end.x
			var x: float = boundary_x + float(side) * random.randf_range(2.0, 4.5)
			var z: float = bounds.position.y - 3.0 + float(index) * 3.1
			var tree: Node3D = Visuals.tree(index % 3)
			tree.position = Vector3(x, 0, z + random.randf_range(-0.5, 0.5))
			tree.rotation.y = random.randf_range(0, TAU)
			tree.scale = Vector3.ONE * random.randf_range(0.85, 1.21)
			add_child(tree)
			if index % 3 == 1:
				var rock: Node3D = Visuals.rock(index % 4)
				rock.position = Vector3(boundary_x + float(side) * random.randf_range(0.95, 1.6), 0, z + 1.3)
				rock.scale = Vector3.ONE * random.randf_range(0.7, 1.2)
				add_child(rock)
	for index: int in range(9):
		var tree: Node3D = Visuals.tree(index % 2)
		tree.position = Vector3(-12.0 + float(index) * 3.0, 0, bounds.position.y - 5.6 - random.randf_range(0, 2.0))
		tree.scale = Vector3.ONE * random.randf_range(0.95, 1.35)
		add_child(tree)
	# A low fence frames the home meadow without reading as a gameplay wall.
	var fence_parts: Array = []
	for side: int in [-1, 1]:
		var x: float = (bounds.position.x - 0.55) if side == -1 else (bounds.end.x + 0.55)
		for index: int in range(7):
			var z: float = bounds.end.y - 1.0 - index * 2.5
			Kit.part(fence_parts, "box", Vector3(0.15, 0.64, 0.15), Vector3(x, 0.32, z), Color("b99561"))
			if index < 6:
				for y: float in [0.24, 0.50]:
					Kit.part(fence_parts, "box", Vector3(0.09, 0.08, 2.5), Vector3(x, y, z - 1.25), Color("ceb17a"))
	add_child(Kit.model("meadow_fences_%s" % hash(bounds), fence_parts))

func _keep_approach(at: Vector3) -> void:
	var parts: Array = []
	# Ground-only paving is scenery, not an untracked obstacle.
	for row: int in range(3):
		for column: int in range(3):
			var point: Vector3 = at + Vector3((column - 1) * 0.53, 0.037, -1.76 - row * 0.56)
			Kit.part(parts, "box", Vector3(0.48, 0.035, 0.48), point, Color("d2c79f") if (row + column) % 2 == 0 else Color("c3bc95"))
	var approach: Node3D = Kit.model("keep_approach_%s" % hash(at), parts)
	approach.name = "KeepPaving"
	add_child(approach)
