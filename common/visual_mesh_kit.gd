extends RefCounted
## Small authored low-poly parts baked into shared, single-surface model meshes.
## All colours are vertex colours: buildings and crowds use one opaque material.

static var _primitives: Dictionary = {}
static var _models: Dictionary = {}
static var _paint: StandardMaterial3D
static var _shadow_paint: StandardMaterial3D

static func part(parts: Array, form: String, size: Vector3, at: Vector3, tint: Color, rotation: Vector3 = Vector3.ZERO) -> void:
	parts.append({"mesh": _primitive(form), "transform": Transform3D(Basis.from_euler(rotation).scaled(size), at), "color": tint})

static func beam(parts: Array, from: Vector3, to: Vector3, width: float, tint: Color, form: String = "cylinder") -> void:
	var delta: Vector3 = to - from
	if delta.length_squared() < 0.00001:
		return
	var basis: Basis = Basis(Quaternion(Vector3.UP, delta.normalized())).scaled(Vector3(width, delta.length(), width))
	parts.append({"mesh": _primitive(form), "transform": Transform3D(basis, (from + to) * 0.5), "color": tint})

static func model(key: String, parts: Array, shadow_radius: float = 0.0) -> Node3D:
	var root := Node3D.new()
	root.name = key.to_pascal_case()
	var body := Node3D.new()
	body.name = "Body"
	root.add_child(body)
	var skin := MeshInstance3D.new()
	skin.name = "Skin"
	skin.mesh = baked(key, parts)
	skin.material_override = paint()
	body.add_child(skin)
	if shadow_radius > 0.0:
		var shadow := MeshInstance3D.new()
		shadow.name = "GroundShadow"
		shadow.mesh = _primitive("cylinder")
		shadow.scale = Vector3(shadow_radius * 2.0, 0.008, shadow_radius * 1.55)
		shadow.position = Vector3(0.0, 0.032, 0.0)
		shadow.material_override = shadow_paint()
		shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(shadow)
	return root

static func baked(key: String, parts: Array) -> ArrayMesh:
	if _models.has(key):
		return _models[key] as ArrayMesh
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	for raw: Dictionary in parts:
		var mesh: Mesh = raw["mesh"]
		var transform: Transform3D = raw["transform"]
		var normal_basis: Basis = transform.basis.inverse().transposed()
		var tint: Color = raw["color"]
		for surface_index: int in range(mesh.get_surface_count()):
			var arrays: Array = mesh.surface_get_arrays(surface_index)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var indices := PackedInt32Array()
			if arrays[Mesh.ARRAY_INDEX] != null:
				indices = arrays[Mesh.ARRAY_INDEX]
			var count: int = indices.size() if not indices.is_empty() else vertices.size()
			for cursor: int in range(count):
				var index: int = indices[cursor] if not indices.is_empty() else cursor
				builder.set_color(tint.srgb_to_linear())
				builder.set_normal((normal_basis * normals[index]).normalized())
				builder.add_vertex(transform * vertices[index])
	builder.index()
	var result: ArrayMesh = builder.commit()
	_models[key] = result
	return result

static func paint() -> StandardMaterial3D:
	if _paint == null:
		_paint = StandardMaterial3D.new()
		_paint.vertex_color_use_as_albedo = true
		_paint.roughness = 0.88
		_paint.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
	return _paint

static func shadow_paint() -> StandardMaterial3D:
	if _shadow_paint == null:
		_shadow_paint = StandardMaterial3D.new()
		_shadow_paint.albedo_color = Color(0.11, 0.20, 0.13, 0.18)
		_shadow_paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_shadow_paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return _shadow_paint

static func _primitive(form: String) -> Mesh:
	if _primitives.has(form):
		return _primitives[form] as Mesh
	var result: Mesh
	match form:
		"box":
			var box := BoxMesh.new()
			box.size = Vector3.ONE
			result = box
		"ball":
			var ball := SphereMesh.new()
			ball.radius = 0.5
			ball.height = 1.0
			ball.radial_segments = 8
			ball.rings = 4
			result = ball
		"roof":
			result = _roof_mesh()
		_:
			var cylinder := CylinderMesh.new()
			cylinder.height = 1.0
			cylinder.bottom_radius = 0.5
			cylinder.top_radius = 0.0 if form == "cone" or form == "pyramid" else 0.5
			cylinder.radial_segments = 4 if form == "pyramid" else 8
			cylinder.rings = 1
			result = cylinder
	_primitives[form] = result
	return result

static func _roof_mesh() -> ArrayMesh:
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	var points: Array[Vector3] = [Vector3(-0.5, -0.5, -0.5), Vector3(0.5, -0.5, -0.5), Vector3(0.0, 0.5, -0.5), Vector3(-0.5, -0.5, 0.5), Vector3(0.5, -0.5, 0.5), Vector3(0.0, 0.5, 0.5)]
	var triangles: Array[int] = [0, 1, 2, 5, 4, 3, 0, 2, 5, 0, 5, 3, 2, 1, 4, 2, 4, 5, 1, 0, 3, 1, 3, 4]
	for index: int in triangles:
		builder.add_vertex(points[index])
	builder.generate_normals()
	return builder.commit()
