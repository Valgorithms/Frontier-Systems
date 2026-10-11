extends "res://tests/godot/machinery_runtime_test.gd"

## Genuine native render of the existing finite integration world.
## Only the camera, lighting and caption layer differ from ordinary presentation.
const FPS: int = 30
const FRAMES: int = 720
var habitat: ProceduralHabitatPreview
var machinery: MachineryPreview
var title: Label
var detail: Label
var _output: String
var _extractor: String = ""


func finish() -> void:
	if failures > 0 or DisplayServer.get_name() == "headless":
		world.free()
		quit(1)
		return
	_output = OS.get_environment("FRONTIER_TEASER_OUTPUT")
	if _output.is_empty(): _output = ProjectSettings.globalize_path("res://var/captures/telegram-teaser")
	DirAccess.make_dir_recursive_absolute(_output)
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	root.msaa_3d = Viewport.MSAA_4X
	habitat = ProceduralHabitatPreview.new()
	root.add_child(habitat)
	habitat.character.set_navigation_enabled(false)
	habitat.character.visible = false
	habitat.world_inventory.skip_machine_roots = true
	habitat.world_inventory.labels_visible = false
	habitat.camera.set_process(false)
	habitat.camera.set_physics_process(false)
	habitat.camera.fov = 49.0
	habitat.focus_production()
	machinery = MachineryPreview.new()
	habitat.add_child(machinery)
	for child in habitat.get_children():
		if child is WorldEnvironment:
			child.environment.background_color = Color("#101923")
			child.environment.ambient_light_energy = 0.38
		if child is DirectionalLight3D:
			child.light_energy = 0.95
			child.rotation = Vector3(-1.1, -0.5, 0)
		if child is CanvasLayer: child.visible = false
	var workshop: Dictionary = production.capture_snapshot().value["machinery"]
	for id in workshop["mounts"]:
		if workshop["parts"][id]["kind"] == "extractor": _extractor = workshop["mounts"][id]
	check(not _extractor.is_empty(), "existing verified extractor found")
	_make_captions()
	_update_scene()
	# Start recording only after native scene setup, for reproducible trimming.
	print("TEASER_START_FRAME %d" % Engine.get_frames_drawn())
	for frame in range(FRAMES):
		if frame == 360:
			command("machine_run", {"machine_id": _extractor, "recipe": "extract.ice"})
		step(2) # Canonical 60 Hz ticks for each 30 fps recorded frame.
		_update_scene()
		_shot(frame)
		await RenderingServer.frame_post_draw
		if frame in [60, 240, 450, 660]:
			check(root.get_texture().get_image().save_png(_output.path_join("frame-%03d.png" % frame)) == OK, "native keyframe")
		await process_frame
	check(production.capture_snapshot().value["cargo"]["resource-canister-1"]["ice"] == 2000000, "recorded extractor completed another conserved batch")
	check(production.validate_snapshot_record(production.capture_snapshot().value, runner.tick_number).is_success, "recorded finite world still validates")
	print("TEASER_END_FRAME %d; failures %d" % [Engine.get_frames_drawn(), failures])
	habitat.free()
	world.free()
	quit(1 if failures else 0)


func _update_scene() -> void:
	var observed: Dictionary = production.observation(context).value
	habitat.production.observe(observed)
	habitat.production.set_labels_visible(false)
	machinery.observe(observed)
	habitat.world_inventory.observe(inventory.world_inventory_observation(context).value)
	_quiet(habitat)


func _quiet(node: Node) -> void:
	if node is Label3D: node.visible = false
	for child in node.get_children(): _quiet(child)


func _make_captions() -> void:
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var header := ColorRect.new()
	header.size = Vector2(1280, 82)
	header.color = Color(0.035, 0.055, 0.075, 0.9)
	layer.add_child(header)
	var footer := ColorRect.new()
	footer.position = Vector2(0, 548)
	footer.size = Vector2(1280, 172)
	footer.color = Color(0.035, 0.055, 0.075, 0.91)
	layer.add_child(footer)
	var brand := Label.new()
	brand.position = Vector2(42, 26)
	brand.text = "FRONTIER SYSTEMS"
	brand.add_theme_font_size_override("font_size", 26)
	layer.add_child(brand)
	var status := Label.new()
	status.position = Vector2(993, 31)
	status.text = "SOURCE PROTOTYPE"
	status.add_theme_font_size_override("font_size", 17)
	status.modulate = Color("#a3d6d4")
	layer.add_child(status)
	title = Label.new()
	title.position = Vector2(42, 572)
	title.add_theme_font_size_override("font_size", 38)
	layer.add_child(title)
	detail = Label.new()
	detail.position = Vector2(44, 630)
	detail.add_theme_font_size_override("font_size", 22)
	detail.modulate = Color("#b5c7d2")
	layer.add_child(detail)
	var note := Label.new()
	note.position = Vector2(44, 683)
	note.text = "Actual Godot scene  |  Automated camera and simulation commands"
	note.add_theme_font_size_override("font_size", 14)
	note.modulate = Color("#80949f")
	layer.add_child(note)


func _shot(frame: int) -> void:
	var segment: int = frame / 180
	var amount: float = smoothstep(0, 1, float(frame % 180) / 179.0)
	var starts: Array[Vector3] = [Vector3(-9.5, 5, 4.3), Vector3(-6.5, 2.8, 1.8), Vector3(-8.6, 2.5, 0.8), Vector3(-2.5, 4, 3.1)]
	var ends: Array[Vector3] = [Vector3(-6.8, 4.4, 3.8), Vector3(-4.1, 2.5, 1.8), Vector3(-7.4, 2, 0.2), Vector3(-7.5, 5.2, 3.6)]
	var targets: Array[Vector3] = [Vector3(-3.8, 0.65, -1.5), Vector3(-4.3, 0.55, -2), Vector3(-6, 0.65, -2), Vector3(-4.3, 0.6, -1.6)]
	var display_origin: Vector3 = ProceduralWorldInventoryPreview.DISPLAY_ORIGIN
	habitat.camera.position = display_origin + starts[segment].lerp(ends[segment], amount)
	habitat.camera.look_at(display_origin + targets[segment])
	match segment:
		0:
			title.text = "A first look at the workshop"
			detail.text = "Built through the prototype's finite material loop"
		1:
			title.text = "Power runs through physical cables"
			detail.text = "Modular machines, replaceable parts and portable storage"
		2:
			title.text = "The extractor fills a real canister"
			var ice: int = int(production.capture_snapshot().value["cargo"]["resource-canister-1"]["ice"])
			detail.text = "Ice in storage: %.2f kg" % (float(ice) / 1000000.0)
		3:
			title.text = "Frontier Systems"
			detail.text = "An early cooperative engineering prototype"
