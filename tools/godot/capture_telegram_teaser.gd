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
var _extractor_head: String = ""
var _refinery: String = ""
var _refinery_head: String = ""
var _printer: String = ""
var _plate: String = ""
var _wall: String = ""


func finish() -> void:
	if failures > 0:
		world.free()
		quit(1)
		return
	_prepare_actions()
	if DisplayServer.get_name() == "headless":
		for frame in range(FRAMES):
			_action(frame)
			step(2)
		_verify_actions()
		world.free()
		quit(1 if failures else 0)
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
	_make_captions()
	_update_scene()
	# Start recording only after native scene setup, for reproducible trimming.
	print("TEASER_START_FRAME %d" % Engine.get_frames_drawn())
	for frame in range(FRAMES):
		_action(frame)
		step(2) # Canonical 60 Hz ticks for each 30 fps recorded frame.
		_update_scene()
		_shot(frame)
		await RenderingServer.frame_post_draw
		if frame in [60, 240, 450, 660]:
			check(root.get_texture().get_image().save_png(_output.path_join("frame-%03d.png" % frame)) == OK, "native keyframe")
		await process_frame
	_verify_actions()
	print("TEASER_END_FRAME %d; failures %d" % [Engine.get_frames_drawn(), failures])
	habitat.free()
	world.free()
	quit(1 if failures else 0)


func _prepare_actions() -> void:
	var workshop: Dictionary = production.capture_snapshot().value["machinery"]
	for id in workshop["mounts"]:
		match workshop["parts"][id]["kind"]:
			"extractor":
				_extractor = workshop["mounts"][id]
				_extractor_head = id
			"refinery":
				_refinery = workshop["mounts"][id]
				_refinery_head = id
			"printhead": _printer = workshop["mounts"][id]
	check(not _extractor.is_empty() and not _printer.is_empty(), "actual modular workshop available")
	# Reclaim the unused disconnected frame, retaining its working refinery head.
	move([-300, 0, -1100])
	command("machine_pack", {"machine_id": _refinery})
	for id in workshop["mounts"]:
		if workshop["mounts"][id] != _refinery: continue
		command("machine_unfit", {"machine_id": _refinery, "item_id": id, "socket_id": ""})
		if id != _refinery_head: command("machine_recycle", {"item_id": id})
	command("machine_recycle", {"item_id": _refinery})
	move([0, 0, 0])
	command("process", {"recipe_id": "craft.plate"})
	step(120)
	command("materialize_plate", {})
	var plates: Array = production.observation(context).value["components"]
	check(not plates.is_empty(), "one physical plate crafted from remaining finite stock")
	if not plates.is_empty(): _plate = plates.back()
	move([-2000, 0, 3500])


func _action(frame: int) -> void:
	match frame:
		40:
			command("wall_build", {"item_id": _plate, "position": [-2000, 0, 2500], "quarter_turn": 0})
			if not production.capture_snapshot().value["walls"].is_empty(): _wall = production.capture_snapshot().value["walls"].keys().back()
		120:
			command("wall_remove", {"wall_id": _wall})
			var plates: Array = production.observation(context).value["components"]
			if not plates.is_empty(): _plate = plates.back()
		150:
			command("wall_build", {"item_id": _plate, "position": [-2000, 0, 2500], "quarter_turn": 1})
			if not production.capture_snapshot().value["walls"].is_empty(): _wall = production.capture_snapshot().value["walls"].keys().back()
		210:
			move([0, 0, 3500])
			move([900, 0, 0])
			command("machine_pack", {"machine_id": _printer})
		270:
			move([2500, 0, 0])
			command("machine_deploy", {"machine_id": _printer, "position": [2500, 0, -1000], "mode": "surface"})
		330:
			command("machine_pack", {"machine_id": _printer})
			move([900, 0, 0])
			command("machine_deploy", {"machine_id": _printer, "position": [900, 0, -1000], "mode": "surface"})
		370:
			move([-6000, 0, -1000])
			command("machine_unfit", {"machine_id": _extractor, "item_id": _extractor_head, "socket_id": ""})
		420:
			fit(_extractor, _refinery_head)
		450:
			command("machine_run", {"machine_id": _extractor, "recipe": "refine.ice"})
		580:
			move([-4000, 0, 3500])
			move([-2000, 0, 3500])
			command("wall_remove", {"wall_id": _wall})
			var plates: Array = production.observation(context).value["components"]
			if not plates.is_empty(): _plate = plates.back()
		630:
			move([-3500, 0, 3500])
			command("wall_build", {"item_id": _plate, "position": [-3500, 0, 2500], "quarter_turn": 0})


func _verify_actions() -> void:
	check(production.capture_snapshot().value["cargo"]["resource-canister-1"]["water"] == 1000000, "replacement refinery processes actual ice into water")
	check(production.capture_snapshot().value["walls"].size() == 1, "one recovered plate rebuilds exactly one wall")
	check(production.validate_snapshot_record(production.capture_snapshot().value, runner.tick_number).is_success, "recorded finite world still validates")
	print("Visible workshop choreography: %d failures" % failures)


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
	header.size = Vector2(1280, 48)
	header.color = Color(0.035, 0.055, 0.075, 0.9)
	layer.add_child(header)
	var footer := ColorRect.new()
	footer.position = Vector2(0, 634)
	footer.size = Vector2(1280, 86)
	footer.color = Color(0.035, 0.055, 0.075, 0.91)
	layer.add_child(footer)
	var brand := Label.new()
	brand.position = Vector2(24, 10)
	brand.text = "FRONTIER SYSTEMS"
	brand.add_theme_font_size_override("font_size", 20)
	layer.add_child(brand)
	var status := Label.new()
	status.position = Vector2(1050, 14)
	status.text = "SOURCE PROTOTYPE"
	status.add_theme_font_size_override("font_size", 12)
	status.modulate = Color("#a3d6d4")
	layer.add_child(status)
	title = Label.new()
	title.position = Vector2(24, 642)
	title.add_theme_font_size_override("font_size", 25)
	layer.add_child(title)
	detail = Label.new()
	detail.position = Vector2(24, 676)
	detail.add_theme_font_size_override("font_size", 17)
	detail.modulate = Color("#b5c7d2")
	layer.add_child(detail)
	var note := Label.new()
	note.position = Vector2(845, 703)
	note.text = "Godot prototype · Automated commands"
	note.add_theme_font_size_override("font_size", 12)
	note.modulate = Color("#80949f")
	layer.add_child(note)


func _shot(frame: int) -> void:
	var segment: int = frame / 180
	var local_frame: int = frame % 180
	var starts: Array[Vector3] = [Vector3(-4.4, 3.2, 1), Vector3(3.8, 3.3, 1), Vector3(-8.4, 2.3, 0.7), Vector3(-5, 4, 0.3)]
	var targets: Array[Vector3] = [Vector3(-2, 0.9, 2.5), Vector3(1.4, 0.7, -1), Vector3(-6, 0.8, -2), Vector3(-2.7, 0.9, 2.5)]
	# Deliberate cuts separate activities; each shot settles on its subject before
	# the command fires. Ease a small dolly rather than orbiting away from it.
	var travel: float = smoothstep(0.0, 179.0, float(local_frame))
	var target: Vector3 = targets[segment]
	if segment == 3:
		# The plate is removed at 580 and rebuilt at 630. Follow its destination
		# during that empty interval, then hold on the rebuilt wall.
		var relocation: float = smoothstep(580.0, 620.0, float(frame))
		target = Vector3(-2, 0.9, 2.5).lerp(Vector3(-3.5, 0.9, 2.5), relocation)
	var display_origin: Vector3 = ProceduralWorldInventoryPreview.DISPLAY_ORIGIN
	var camera_start: Vector3 = starts[segment]
	habitat.camera.position = display_origin + camera_start.lerp(target + (camera_start - target) * 0.94, travel)
	habitat.camera.look_at(display_origin + target)
	match segment:
		0:
			title.text = "A physical plate becomes a wall"
			detail.text = "Build it, dismantle it, then turn the recovered plate"
		1:
			title.text = "Pack the printer and move it"
			detail.text = "The whole fitted machine keeps its components"
		2:
			title.text = "Swap the working head"
			var water: int = int(production.capture_snapshot().value["cargo"]["resource-canister-1"]["water"])
			detail.text = "Extractor to refinery. Stored water: %.2f kg" % (float(water) / 1000000.0)
		3:
			title.text = "Recover the material and build again"
			detail.text = "The same plate, in a different place"
