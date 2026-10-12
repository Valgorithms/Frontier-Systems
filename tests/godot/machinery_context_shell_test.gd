extends "res://tests/godot/machinery_runtime_test.gd"

const ShellFixture = preload("res://tests/godot/integrated_panel_layout_test.gd")
var client: FirstPlayableBootstrap
var remote: RemoteWorldRuntime

func settle() -> void:
	for _frame in range(6): await process_frame

func show_observation() -> void:
	var record: Dictionary = {
		"inventory": inventory.own_inventory_observation(context, true).value,
		"production": production.observation(context).value,
		"tools": world.get_simulation_system(ToolSimulationSystem.SYSTEM_ID).observation(context).value,
		"world_items": inventory.world_inventory_observation(context).value,
		"position": [0, 950, 0], "players": [], "terrain": {}}
	check(remote._projection.accept_record(record["production"]).is_success, "paid observation accepted by actual client projection")
	remote._observation = record.duplicate(true)
	remote.observation_received.emit(record)
	remote.observation_received.emit(record)
	client._habitat.character.read_local_keyboard = false
	client._habitat.character.set_physics_process(false)

func snap(name: String) -> void:
	if not OS.get_cmdline_user_args().has("--capture-machinery"): return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://var/ci/machinery-context-stills")
	check(root.get_texture().get_image().save_png("res://var/ci/machinery-context-stills/" + name + ".png") == OK, "native shell still")

func click_machine() -> void:
	var surface: SubViewportContainer = client._habitat.get_viewport().get_parent()
	var point: Vector2 = surface.get_global_rect().get_center()
	root.notify_mouse_entered()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.window_id = root.get_window_id()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
	await settle()

func finish() -> void:
	PlayerInputSettings.instance()._reset_map()
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1280, 900)
	client = ShellFixture.FixtureClient.new()
	root.add_child(client)
	client.set_process(false)
	client.set_process_unhandled_input(false)
	remote = client._remote
	remote.set_process(false)
	remote.server_slot = 0
	show_observation()
	await settle()
	var preview: MachineryPreview = client._machinery_preview
	preview.set_process(false)
	var id: String = ""
	for module in production.capture_snapshot().value["machinery"]["mounts"]:
		var workshop: Dictionary = production.capture_snapshot().value["machinery"]
		if workshop["parts"][module]["kind"] == "extractor": id = workshop["mounts"][module]
	var body: StaticBody3D = preview._labels[id]["body"]
	client._habitat.camera.make_current()
	client._habitat.camera.global_position = body.global_position + Vector3(2, 2, 3)
	client._habitat.camera.look_at(body.global_position)
	await physics_frame
	var hit: Dictionary = WorldSelectionInput.ray_target(client._habitat.camera, Vector2(client._habitat.camera.get_viewport().size) / 2.0)
	check(hit.get("collider") == body, "actual center ray picks unchanged exact machine body")
	var card: MachineryContextCard = preview._context_card
	var before: String = world.capture_world_snapshot_json().value
	var geometry: Array = []
	for shape: CollisionShape3D in preview.find_children("*", "CollisionShape3D", true, false):
		geometry.append([shape.get_instance_id(), shape.global_transform, shape.shape.get_debug_mesh().get_aabb()])
	preview.clear_context()
	check(not card.visible, "no persistent card without context")
	for entry in preview._labels.values(): check(not entry["label"].visible, "machine world captions hidden")
	for label in preview._socket_labels.values(): check(not label.visible, "canister world captions hidden")
	await snap("overview")
	body.mouse_entered.emit()
	check(card.target == body and card.visible, "native collider hover discovers exact machine")
	check(card._lines[0].text.contains(id.right(8)), "stable identity discoverable")
	check(card._lines[4].visible and card._lines[4].text.contains(PlayerInputSettings.instance().binding_label("world_select")) and card._lines[4].text.contains("opens Construction"), "default mouse binding describes existing inspection route")
	var controls := PlayerInputSettings.instance()
	var remapped := InputEventMouseButton.new()
	remapped.button_index = MOUSE_BUTTON_MIDDLE
	PlayerInputSettings._set_binding("world_select", remapped)
	preview._process(0.0)
	check(card._lines[4].text.contains(controls.binding_label("world_select")) and not card._lines[4].text.contains("Left"), "visible card refreshes remapped mouse binding without observation")
	var keyboard := InputEventKey.new()
	keyboard.physical_keycode = KEY_H
	PlayerInputSettings._set_binding("world_select", keyboard)
	preview._process(0.0)
	check(card._lines[4].text.contains(controls.binding_label("world_select")) and card._lines[4].text.contains("cannot pick machinery") and card._lines[4].text.contains("Construction"), "keyboard guidance states current static-body picking limit")
	var controller := InputEventJoypadButton.new()
	controller.button_index = JOY_BUTTON_A
	PlayerInputSettings._set_binding("world_select", controller)
	preview._process(0.0)
	check(card._lines[4].text.contains(controls.binding_label("world_select")) and card._lines[4].text.contains("cannot pick machinery"), "controller guidance does not promise unsupported activation")
	InputMap.action_erase_events("world_select")
	preview._process(0.0)
	check(card._lines[4].text == "World select unbound · choose machine in Construction", "unbound selection keeps existing chooser route")
	controls._reset_map()
	PlayerInputSettings._set_binding("ui_cursor", keyboard)
	preview._set_hover(id)
	preview._process(0.0)
	check(card._lines[4].text.contains("Hold " + controls.binding_label("ui_cursor")), "guidance refreshes live cursor binding")
	InputMap.action_erase_events("ui_cursor")
	preview._process(0.0)
	check(card._lines[4].text.contains(controls.binding_label("release_cursor")) and card._lines[4].text.contains("release camera"), "unbound cursor describes existing capture release")
	InputMap.action_erase_events("release_cursor")
	preview._process(0.0)
	check(card._lines[4].text == "Cursor controls unbound · open Controls settings", "fully unbound cursor gives settings route")
	controls._reset_map()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	preview._process(0.0)
	check(world.capture_world_snapshot_json().value == before and remote.sent.is_empty(), "binding advice queues no commands and changes no canonical state")
	var shapes: Array = preview.find_children("*", "CollisionShape3D", true, false)
	await snap("hover")
	body.mouse_exited.emit()
	check(not card.visible, "hover exit clears unselected details")
	await click_machine()
	check(client._machinery_panel._selected(client._machinery_panel._machine) == id and client._machinery_panel.is_visible_in_tree(), "native shell mouse selection opens Construction for exact machine")
	check(not card._lines[4].visible and card._lines[4].text.is_empty(), "open Construction suppresses duplicate hint")
	check(remote.sent.is_empty(), "selection opens inspection without submitting machine intent")
	client._machinery_panel._refresh_placement()
	preview._process(0.0)
	check(card.target == body and card.visible, "existing panel selection displays exact picked assembly")
	client._machinery_panel._machine.grab_focus()
	body.mouse_entered.emit()
	check(preview._hovered_id.is_empty() and card.target == body, "GUI focus blocks hover while selected identity persists")
	check(not card._lines[4].visible and not card._lines[3].text.is_empty(), "GUI ownership hides hints while observed uncertainty remains")
	client._machinery_panel._machine.release_focus()
	client._set_drawer_open(false)
	preview._set_hover(id)
	preview._process(0.0)
	check(card._lines[4].visible, "closing Construction restores hover guidance")
	client._open_panel(1)
	preview._process(0.0)
	check(card._lines[4].visible, "unrelated open panel does not suppress machinery guidance")
	client._drawer_toggle.grab_focus()
	preview._process(0.0)
	check(not card._lines[4].visible, "GUI focus suppresses actionable gameplay hint")
	client._drawer_toggle.release_focus()
	client._set_drawer_open(false)
	preview._set_hover(id)
	PlayerInputSettings.instance().suspend_navigation(true)
	preview._process(0.0)
	check(not card._lines[4].visible, "suspended input cannot advertise activation")
	PlayerInputSettings.instance().suspend_navigation(false)
	preview._set_hover(id)
	move([-6000, 0, -1000])
	command("machine_run", {"machine_id": id, "recipe": "extract.ice"})
	show_observation()
	step(8)
	show_observation()
	preview._process(0.05)
	check(card._lines[3].text == "Running · observed progress", "paid progress shown contextually")
	check(card._lines[2].text.contains("ticks"), "observed job progress discoverable")
	preview._process(1.0)
	check(card._lines[3].text == "Stale / progress unknown", "timeout cannot keep reporting activity")
	step(1)
	show_observation()
	command("machine_enable", {"machine_id": id, "enabled": false})
	show_observation()
	check(card._lines[3].text.begins_with("Blocked"), "host block explained")
	var restored := WorldRuntime.new()
	restored.resource_carriers_enabled = true
	root.add_child(restored)
	check(restored.restore_world_snapshot_json(world.capture_world_snapshot_json().value).is_success, "real save restore accepted")
	preview.observe(restored.production_observation(context).value)
	check(card._lines[3].text.begins_with("Paused"), "real restored batch explains explicit resume")
	restored.free()
	show_observation()
	command("machine_cancel", {"machine_id": id})
	show_observation()
	check(card._lines[3].text == "Batch outcome unconfirmed", "job disappearance never certifies completed production")
	root.size = Vector2i(640, 720)
	await settle()
	preview._process(0.0)
	card._process(0.0)
	check(card._lines[4].visible, "narrow hover retains interaction guidance")
	check(card._lines[4].get_line_count() == card._lines[4].get_visible_line_count(), "narrow guidance is fully readable")
	check(card.visible and Rect2(Vector2.ZERO, card.size).encloses(card._panel.get_rect()), "card remains bounded in actual narrow shell viewport")
	check(card._lines[3].get_line_count() == card._lines[3].get_visible_line_count(), "narrow uncertainty statement remains fully readable")
	await snap("narrow")
	for width in [480, 360]:
		root.size = Vector2i(width, 720)
		for mode in ["mouse", "keyboard", "controller", "unbound"]:
			controls._reset_map()
			if mode == "keyboard": PlayerInputSettings._set_binding("world_select", keyboard)
			elif mode == "controller": PlayerInputSettings._set_binding("world_select", controller)
			elif mode == "unbound": InputMap.action_erase_events("world_select")
			preview._set_hover(id)
			preview._process(0.0)
			await settle()
			check(card.visible and Rect2(Vector2.ZERO, card.size).encloses(card._panel.get_rect()), "narrow %d %s hint and card bounded" % [width, mode])
			for line: Label in [card._lines[3], card._lines[4]]:
				check(line.get_line_count() == line.get_visible_line_count() and card._panel.get_global_rect().encloses(line.get_global_rect()), "narrow %d %s uncertainty and hint fully readable" % [width, mode])
	controls._reset_map()
	check(preview.find_children("*", "CollisionShape3D", true, false) == shapes, "context preserves exact colliders")
	var after_geometry: Array = []
	for shape: CollisionShape3D in preview.find_children("*", "CollisionShape3D", true, false):
		after_geometry.append([shape.get_instance_id(), shape.global_transform, shape.shape.get_debug_mesh().get_aabb()])
	check(after_geometry == geometry, "guidance preserves collider identities transforms and bounds")
	var snapshot: String = world.capture_world_snapshot_json().value
	preview.clear_context()
	body.mouse_entered.emit()
	preview._process(0.0)
	check(world.capture_world_snapshot_json().value == snapshot, "hover/reset cannot change canonical snapshot")
	client._on_connection_closed("Fixture disconnect")
	check(not card.visible and card.target == null and preview._hovered_id.is_empty() and preview._selected_id.is_empty(), "disconnect clears context and observed world objects")
	check(before != snapshot, "paid real commands exercised actual domain")
	client.free()
	world.free()
	print("Machinery contextual shell: %d failures" % failures)
	quit(1 if failures else 0)
