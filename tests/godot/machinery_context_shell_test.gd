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
	preview.clear_context()
	check(not card.visible, "no persistent card without context")
	for entry in preview._labels.values(): check(not entry["label"].visible, "machine world captions hidden")
	for label in preview._socket_labels.values(): check(not label.visible, "canister world captions hidden")
	await snap("overview")
	body.mouse_entered.emit()
	check(card.target == body and card.visible, "native collider hover discovers exact machine")
	check(card._lines[0].text.contains(id.right(8)), "stable identity discoverable")
	var shapes: Array = preview.find_children("*", "CollisionShape3D", true, false)
	await snap("hover")
	body.mouse_exited.emit()
	check(not card.visible, "hover exit clears unselected details")
	preview.machine_selected.emit(id)
	client._machinery_panel._refresh_placement()
	preview._process(0.0)
	check(card.target == body and card.visible, "existing panel selection displays exact picked assembly")
	client._machinery_panel._machine.grab_focus()
	body.mouse_entered.emit()
	check(preview._hovered_id.is_empty() and card.target == body, "GUI focus blocks hover while selected identity persists")
	client._machinery_panel._machine.release_focus()
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
	check(card.visible and Rect2(Vector2.ZERO, card.size).encloses(card._panel.get_rect()), "card remains bounded in actual narrow shell viewport")
	await snap("narrow")
	check(preview.find_children("*", "CollisionShape3D", true, false) == shapes, "context preserves exact colliders")
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
