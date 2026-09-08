extends SceneTree
## Actual-renderer inspection gallery. No gameplay state or source is modified.
## godot --path . --script tools/capture_progression.gd --quit-after 600

const Visuals = preload("res://common/visuals.gd")
const SIZE := Vector2i(1200, 1480)
const KINDS: Array[String] = ["tower", "wall", "mine", "smith"]
const TITLES: Array[String] = ["ARCHER TOWER", "WALL", "GOLD MINE", "SMITH"]
var _viewport: SubViewport

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Progression capture requires an actual renderer; omit --headless.")
		quit(1)
		return
	_viewport = SubViewport.new()
	_viewport.size = SIZE
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.msaa_3d = Viewport.MSAA_2X
	root.add_child(_viewport)
	var world := Node3D.new()
	_viewport.add_child(world)
	_lighting(world)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(50, 50)
	ground.mesh = plane
	var ground_paint := StandardMaterial3D.new()
	ground_paint.albedo_color = Color("6f8f63")
	ground_paint.roughness = 1.0
	ground.material_override = ground_paint
	world.add_child(ground)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.size = 22.5
	camera.position = Vector3(0, 23, 19.6)
	camera.look_at(Vector3(0, 0, 0.6), Vector3.UP)
	camera.current = true
	var overlay := CanvasLayer.new()
	_viewport.add_child(overlay)
	_label(overlay, "EMBERWATCH", Rect2(60, 28, 1080, 55), 40, Color("fff1ce"))
	_label(overlay, "BUILDING PROGRESSION  /  LEVEL 1 → 2 → 3", Rect2(60, 83, 1080, 37), 23, Color("f2cd7a"))
	var count: int = 0
	for row: int in range(KINDS.size()):
		for tier: int in range(1, 4):
			var model: Node3D = Visuals.building(KINDS[row], tier)
			world.add_child(model)
			model.position = Vector3(float(tier - 2) * 5.4, 0, -8.0 + float(row) * 5.5)
			if KINDS[row] == "smith":
				model.position.z += 1.5
			var screen: Vector2 = camera.unproject_position(model.position + Vector3(0, 0, 1.70))
			_label(overlay, "%s\nLEVEL %d" % [TITLES[row], tier], Rect2(screen.x - 145, screen.y, 290, 67), 22, Color("fff1ce"))
			var skin := model.get_node("Body/Skin") as MeshInstance3D
			if skin == null or skin.mesh == null or skin.mesh.get_surface_count() == 0:
				push_error("Missing progression geometry for %s tier %d" % [KINDS[row], tier])
				quit(1)
				return
			count += 1
	_label(overlay, "Same world scale and gameplay camera angle · Original meshes · Inspection view", Rect2(50, SIZE.y - 67, 1100, 35), 19, Color("e2e7d1"))
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var capture: Image = _viewport.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))
	var error: Error = capture.save_png("res://artifacts/progression.png")
	_viewport.queue_free()
	await process_frame
	await process_frame
	if error != OK or count != 12:
		push_error("Progression capture failed: %s, models=%d" % [error, count])
		quit(1)
		return
	print("PROGRESSION_CAPTURE_PASS: 12 models, ", SIZE, ", artifacts/progression.png")
	quit(0)

func _lighting(world: Node3D) -> void:
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("173a2f")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.93, 0.96, 1.0)
	environment.ambient_light_energy = 0.72
	environment_node.environment = environment
	world.add_child(environment_node)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -34, 0)
	sun.light_color = Color(1.0, 0.97, 0.92)
	sun.light_energy = 0.72
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 75.0
	world.add_child(sun)

func _label(parent: Node, text: String, rect: Rect2, font_size: int, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.position = rect.position
	label.size = rect.size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.05, 0.15, 0.10, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)
	parent.add_child(label)
