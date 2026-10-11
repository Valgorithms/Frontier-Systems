extends "res://tests/godot/integrated_panel_layout_test.gd"

## Real shell and domain owners, injected GUI keys; no sockets or live services.
func pick_text(picker: OptionButton, id: String) -> void:
	for index in range(picker.item_count):
		if picker.get_item_text(index) == id: picker.select(index)

func button_named(ui: Node, caption: String) -> Button:
	for node in ui.find_children("*", "Button", true, false):
		if node.text == caption: return node
	check(false, "button exists: " + caption)
	return null

func activate_button(button: Button) -> SimulationCommand:
	check(button != null and not button.disabled, "intended action enabled")
	if button == null or button.disabled: return null
	await settle()
	button.grab_focus()
	await settle()
	check(button.has_focus() and visible(button, client._scroll), "keyboard action revealed in actual shell: " + button.text + " rect=" + str(button.get_global_rect()) + " viewport=" + str(client._scroll.get_global_rect()))
	var sent: int = remote.sent.size()
	var before: String = world.capture_world_snapshot_json().value
	await key(KEY_ENTER)
	check(remote.sent.size() == sent + 1, "one Enter queues one intent: " + button.text + " sent=" + str(sent) + " now=" + str(remote.sent.size()) + " pressed=" + str(button.button_pressed) + " pending=" + client._production_panel._pending + " feedback=" + client._production_panel._feedback.text)
	check(world.capture_world_snapshot_json().value == before, "queued GUI intent cannot mutate canonical state")
	button.release_focus()
	return remote.sent[-1] if remote.sent.size() > sent else null

func paid_action(button: Button, operation: String) -> SimulationCommand:
	var request: SimulationCommand = await activate_button(button)
	if request == null: return null
	check(request.operation == operation, "exact submitted operation: " + operation)
	apply(request)
	check(last.is_success, "real owner accepts " + operation + ": " + last.message)
	remote.command_completed.emit(request, last)
	observe_shell()
	await settle()
	check(client._production_panel._pending.is_empty(), "matching receipt settles exact pending request")
	return request

func recipe(id: String) -> void:
	client._habitat.production.workstation_selected.emit()
	await settle()
	var ui: LocalProductionPanel = client._production_panel
	check(root.gui_get_focus_owner() == ui._recipe and visible(ui._recipe, client._scroll), "cross-panel workstation navigation gives visible recipe keyboard focus")
	choose(ui._recipe, id)
	ui.refresh()
	await paid_action(button_named(ui, "Run selected recipe"), "process")
	check(not frame()["production"]["job"].is_empty(), "accepted recipe is reserved work, not completed output")
	for _tick in range(120): step()
	observe_shell()
	await settle()
	check(frame()["production"]["job"].is_empty(), "fresh observation reports completed batch")

func run() -> void:
	create_timer(45.0).timeout.connect(func() -> void: push_error("Engineering shell deadline"); quit(1))
	PlayerInputSettings.instance()._reset_map()
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1920, 1080)
	world = WorldRuntime.new()
	world.resource_carriers_enabled = true
	root.add_child(world)
	check(world.start_simulation().is_success, "finite canonical world starts")
	world.get_node("SimulationRunner").set_physics_process(false)
	world.command_completed.connect(func(_request: SimulationCommand, result: ServiceResult) -> void: last = result)
	context = AuthenticatedCommandContext.for_local_development(&"local-inventory-actor", world.world_id, world.region_id)
	client = FixtureClient.new()
	root.add_child(client)
	client.set_process(false)
	client.set_process_unhandled_input(false)
	remote = client._remote
	remote.set_process(false)
	remote.server_slot = 0
	observe_shell()
	var physical_ids: Array[String] = []
	var extraction: SimulationCommand
	for cycle in range(2):
		for _batch in range(2):
			client._tabs.current_tab = 0
			move(ProductionSimulationSystem.SOURCE_POSITIONS["deposit.iron"])
			observe_shell()
			var ui: LocalProductionPanel = client._production_panel
			ui._navigation.select(0)
			ui._navigation.item_selected.emit(0)
			pick_text(ui._deposit, "deposit.iron")
			pick_text(ui._carrier, "resource-canister-1")
			ui._amount.value = 1000
			ui.refresh()
			extraction = await paid_action(ui._extract_button, "extract")
			if extraction == null: quit(1); return
			check(extraction.payload["deposit_id"] == "deposit.iron" and extraction.payload["carrier_id"] == "resource-canister-1" and extraction.payload["amount_milligrams"] == 1000000, "exact finite source/canister/mass")
			move([0, 0, 0])
			observe_shell()
			pick_text(ui._cargo_material, "ore.iron")
			ui.refresh()
			var unload: SimulationCommand = await paid_action(ui._unload_button, "unload_cargo")
			check(ui._feedback.text.contains(String(unload.command_id)) and ui._feedback.text.contains("resource-canister-1") and ui._feedback.text.contains("ore.iron; 1000000 mg"), "host unload receipt retains exact identity")
			client._tabs.current_tab = 1
			await recipe("refine.iron")
		await recipe("craft.plate")
		await paid_action(button_named(client._production_panel, "Collect printed plate into inventory"), "materialize_plate")
		var components: Array = frame()["production"]["components"]
		check(components.size() == 1, "one paid physical plate exists")
		var plate_id: String = components[0]
		check(not physical_ids.has(plate_id), "repeat loop produces a new stable physical identity")
		physical_ids.append(plate_id)
		pick_text(client._production_panel._components, plate_id)
		await paid_action(button_named(client._production_panel, "Recycle selected carried plate"), "recycle_component")
		var production: Dictionary = frame()["production"]
		check(production["components"].is_empty() and production["store"]["plate"] == 0, "physical recycle consumes that plate exactly once")
		check(production["deposits"]["deposit.iron"] == 10000000 - (cycle + 1) * 2000000 and production["store"]["iron"] == (cycle + 1) * 1200000 and production["store"]["tailings"] == (cycle + 1) * 800000 and production["store"]["ore.iron"] == 0 and production["cargo"]["resource-canister-1"]["ore.iron"] == 0, "repeat finite loop conserves all 10 kg of source matter")
	# Real checkpoint files in unique temporary test storage; UI receipt delivered by adapter.
	var save_request: CheckpointRequest = await activate_button(client._host_actions[3])
	var snapshot: String = world.capture_world_snapshot_json().value
	var directory: String = "user://engineering-shell-%d" % Time.get_ticks_usec()
	var written: ServiceResult = LocalWorldSaveStore.write_checkpoint(directory, 1, snapshot)
	check(written.is_success, "real disk checkpoint completes")
	remote.command_completed.emit(save_request, written)
	observe_shell()
	await settle()
	check(client._checkpoint_status.text.contains("confirmed on disk") and visible(client._checkpoint_status, client._scroll), "matching save result automatically revealed after observation")
	client._checkpoint_status.grab_focus()
	await settle()
	check(client._checkpoint_status.has_focus(), "checkpoint feedback accessible to keyboard")
	var abandoned: CheckpointRequest = await activate_button(client._host_actions[3])
	var sent: int = remote.sent.size()
	remote.connection_closed.emit("Fixture disconnect after save submission")
	remote.command_completed.emit(abandoned, ServiceResult.success())
	await settle()
	check(client._checkpoint_status.text.contains("outcome unknown"), "late success cannot confirm disconnected save")
	var checkpoint: ServiceResult = LocalWorldSaveStore.read_latest(directory)
	check(checkpoint.is_success, "real disk checkpoint reads")
	world.free()
	world = WorldRuntime.new()
	world.resource_carriers_enabled = true
	root.add_child(world)
	check(world.restore_world_snapshot_json(checkpoint.value["snapshot_json"]).is_success and world.start_simulation().is_success, "replacement canonical owner restores checkpoint")
	world.get_node("SimulationRunner").set_physics_process(false)
	world.command_completed.connect(func(_request: SimulationCommand, result: ServiceResult) -> void: last = result)
	observe_shell()
	await settle()
	check(remote.sent.size() == sent and client._checkpoint_status.text.contains("outcome unknown"), "fresh reconnect observation cannot replay or confirm abandoned request")
	var recovered: Dictionary = frame()
	check(recovered["production"]["deposits"]["deposit.iron"] == 6000000 and recovered["production"]["store"]["iron"] == 2400000 and recovered["production"]["store"]["tailings"] == 1600000, "fresh recovery observes exact finite loop balances")
	apply(extraction)
	check(frame()["production"] == recovered["production"], "retained extraction replay cannot mint matter after recovery")
	client.free()
	world.free()
	for name in ["world-a.json", "world-b.json"]:
		if FileAccess.file_exists(directory.path_join(name)): DirAccess.remove_absolute(directory.path_join(name))
	DirAccess.remove_absolute(directory)
	PlayerInputSettings.instance().release_all()
	await process_frame
	print("Engineering shell keyboard/finite loop/disk recovery: %d failures; scripted input, no human acceptance" % failures)
	quit(1 if failures else 0)
