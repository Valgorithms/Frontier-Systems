extends "res://tests/godot/timed_canister_controls_test.gd"

## Reuse no-port host transport doubles; retain real authentication and owners.
func run() -> void:
	world = WorldRuntime.new()
	world.resource_carriers_enabled = true
	root.add_child(world)
	check(world.start_simulation().is_success, "real world starts")
	runner = world.get_node("SimulationRunner")
	runner.set_physics_process(false)
	production = world.get_simulation_system(ProductionSimulationSystem.SYSTEM_ID)
	inventory = world.get_simulation_system(InventorySimulationSystem.SYSTEM_ID)
	context = AuthenticatedCommandContext.for_local_development(&"local-inventory-actor", world.world_id, world.region_id)
	world.command_completed.connect(func(command_value: SimulationCommand, result: ServiceResult) -> void:
		last = result
		if command_value is ProductionDevelopmentCommand: completed = command_value
	)
	for batch in range(2):
		move([-3000, 0, -1000])
		command("extract", {"deposit_id": "deposit.iron", "carrier_id": "resource-canister-1", "amount_milligrams": 1000000})
		move([0, 0, 0])
		command("unload_cargo", {"carrier_id": "resource-canister-1", "material": "ore.iron", "amount_milligrams": 1000000})
		command("process", {"recipe_id": "refine.iron"})
		step(120)
	command("process", {"recipe_id": "craft.plate"})
	step(120)
	check(state_plate() == 1000000, "one finite plate recipe")
	host = RecordingHost.new()
	root.add_child(host)
	host.set_process(false)
	host._world = world
	host._keys = ["panel-actor-000000000000000000000", "panel-target-00000000000000000000"]
	world.command_completed.connect(host._on_completed)
	for peer in [1, 2]:
		host._peers[peer] = {"socket": RecordingSocket.new(), "slot": -1, "created": Time.get_ticks_msec(), "last_move": Time.get_ticks_msec(), "pending_move": false, "window": Time.get_ticks_msec(), "commands": 0}
		host._receive(peer, {"type": "authenticate", "key": host._keys[peer - 1]})
	check(host._peers[1]["slot"] == 0 and host._peers[2]["slot"] == 1, "real authenticated host sessions")
	var payload: Dictionary = panel_intent()
	check(panel_route(1, "panel_build", payload, "paid-host-sheet")["ok"], "host queues authenticated panel build")
	var id: String = production.capture_snapshot().value["panels"].keys()[0]
	check(state_plate() == 500000, "host debits exact area")
	var observed: Dictionary = production.observation(context).value
	var foreign: Dictionary = production.observation(host._context(1, 2)).value
	check(foreign["horizontal_panels"]["surfaces"].is_empty(), "other real session never receives foreign descriptors")
	check(not JSON.stringify(observed["horizontal_panels"]).contains("principal") and not JSON.stringify(foreign["horizontal_panels"]).contains(id), "no private principals or foreign IDs")
	check(panel_route(1, "panel_build", payload, "paid-host-sheet")["ok"] and state_plate() == 500000, "exact authenticated retry never debits again")
	check(not panel_route(2, "panel_remove", {"expected_revision": current_revision(), "panel_id": id})["ok"], "foreign session cannot remove paid sheet")
	check(not panel_route(1, "panel_build", payload)["ok"], "host rejects stale owner revision")
	for field in ["principal_id", "actor_id", "world_id", "region_id", "materials", "permissions"]:
		var forged: Dictionary = panel_intent()
		forged[field] = "forged"
		check(not panel_route(1, "panel_build", forged)["ok"], "host rejects extra authority field " + field)
	var distant: Dictionary = panel_intent()
	distant["bounds_millimetres"] = [10000, 10500, 0, 1000]
	check(not panel_route(1, "panel_build", distant)["ok"] and state_plate() == 500000, "host rechecks installation reach atomically")
	var removal: Dictionary = {"expected_revision": current_revision(), "panel_id": id}
	check(panel_route(1, "panel_remove", removal, "paid-host-remove")["ok"], "host removes own sheet")
	check(panel_route(1, "panel_remove", removal, "paid-host-remove")["ok"] and state_plate() == 1000000, "remove retry refunds only once")
	# Exercise the actual integrated UI, preview and queue.
	root.size = Vector2i(900, 900)
	var scroll := ScrollContainer.new()
	scroll.size = Vector2(400, 800)
	root.add_child(scroll)
	var panel := MachineryPanel.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(panel)
	panel.configure(world)
	var controls: HorizontalPanelControls = panel._horizontal_panels
	var preview := HorizontalPanelPreview.new()
	root.add_child(preview)
	panel.bind_horizontal_preview(preview)
	preview.panel_selected.connect(panel.select_panel)
	panel.observe(frame())
	check(not controls._details.visible and preview._ghost == null, "collapsed controls have no candidate ghost")
	controls._fields[2].value = 500
	controls._toggle.button_pressed = true
	await process_frame
	await process_frame
	check(controls.size.x <= scroll.size.x and preview._ghost != null, "compact expanded controls with nonmutating candidate")
	check(state_plate() == 1000000 and production.capture_snapshot().value["panels"].is_empty(), "candidate preview never spends or installs")
	controls._build.pressed.emit()
	check(not controls._pending.is_empty() and controls._build.disabled and preview._ghost == null, "pending suppresses repeated build and clears ghost")
	step()
	check(last.is_success and completed.operation == "panel_build" and completed.payload["bounds_millimetres"] == [0, 500, 0, 1000], "actual UI queues exact owner intent")
	check(controls._record.is_empty(), "ack requires fresh observation")
	panel.observe(frame())
	id = production.capture_snapshot().value["panels"].keys()[0]
	check(preview._panels.has(id) and preview._panels[id] is Area3D, "own paid sheet rendered with picking area only")
	await physics_frame
	await physics_frame
	var origin: Vector3 = ProceduralWorldInventoryPreview.DISPLAY_ORIGIN + Vector3(0.25, 0, 0.5)
	var ray := PhysicsRayQueryParameters3D.create(origin + Vector3.UP, origin + Vector3.DOWN)
	ray.collide_with_bodies = false
	ray.collide_with_areas = true
	var hit: Dictionary = preview.get_world_3d().direct_space_state.intersect_ray(ray)
	check(hit.get("collider") == preview._panels[id], "real physics ray picks the observed floor Area3D")
	var click := InputEventAction.new()
	click.action = &"world_select"
	click.pressed = true
	preview._panels[id].input_event.emit(null, click, origin, Vector3.UP, 0)
	check(controls._selected_id == id and not controls._remove.disabled, "scene selection enables deliberate own removal")
	panel.observe(frame())
	check(controls._selected_id == id, "selection stable across observations")
	controls._kind.select(1)
	controls._refresh()
	controls._build.pressed.emit()
	step()
	check(last.is_success and completed.payload["height_millimetres"] == 2000 and state_plate() == 0, "UI ceiling consumes remaining finite area bill")
	panel.observe(frame())
	check(controls._build.disabled, "insufficient stock disables preview action")
	var snapshot: String = world.capture_world_snapshot_json().value
	var restored := WorldRuntime.new()
	root.add_child(restored)
	restored.resource_carriers_enabled = true
	check(restored.restore_world_snapshot_json(snapshot).is_success, "UI-created records survive strict save9 restore")
	var restored_projection: Dictionary = restored.production_observation(context).value
	check(restored_projection["horizontal_panels"]["surfaces"] == frame()["production"]["horizontal_panels"]["surfaces"], "restored own descriptors remain selectable")
	restored.free()
	var current: Dictionary = frame()["production"]
	check_projection(current)
	controls._remove.pressed.emit()
	step()
	check(last.is_success and state_plate() == 500000, "selected floor removal refunds exact paid mass")
	panel.observe(frame())
	check(controls._selected_id.is_empty() and controls._remove.disabled and not preview._panels.has(id), "removed selection never jumps to another sheet")
	controls.observe(current)
	check(controls._record.is_empty() and preview._ghost == null and preview._panels.is_empty(), "stale observation clears controls and preview")
	controls.observe(frame()["production"])
	world.region_id = &"changed-region"
	controls._build.pressed.emit()
	check(controls._record.is_empty() and preview._ghost == null, "scope change clears candidate before enqueue")
	world.region_id = context.region_id
	controls.observe(frame()["production"])
	controls.observe(JSON.parse_string(JSON.stringify(frame()["production"])))
	check(not controls._record.is_empty() and not preview._panels.is_empty(), "integral JSON version preserves controls and paid panel preview")
	for version in [true, 10.5, 12, "11"]:
		var bad_version: Dictionary = frame()["production"].duplicate(true)
		bad_version.schema_version = version
		controls.observe(bad_version)
		check(controls._record.is_empty() and preview._panels.is_empty(), "panel UI and preview reject boolean/fractional/unknown/string version")
		controls.observe(frame()["production"])
	var invalid: Dictionary = frame()["production"].duplicate(true)
	invalid["horizontal_panels"]["surfaces"][0]["height_millimetres"] = 123
	controls.observe(invalid)
	check(controls._record.is_empty() and preview._ghost == null and preview._panels.is_empty(), "malformed observation clears all actionable previews")
	controls.observe(frame()["production"])
	controls._toggle.button_pressed = false
	check(preview._ghost == null, "collapsing controls clears candidate")
	controls.observe({})
	check(controls._build.disabled and preview._panels.is_empty(), "missing observation clears all scene sheets")
	var remote := RemoteWorldRuntime.new()
	root.add_child(remote)
	remote.set_process(false)
	var remote_controls := HorizontalPanelControls.new()
	root.add_child(remote_controls)
	remote_controls.configure(remote)
	remote_controls.observe(current)
	remote.connection_closed.emit("test disconnect")
	check(remote_controls._record.is_empty() and remote_controls._build.disabled, "disconnect clears remote controls")
	remote_controls.free()
	remote.free()
	scroll.free()
	preview.free()
	host.free()
	world.free()
	print("Horizontal panel controls: %d failures" % failures)
	quit(1 if failures else 0)


func current_revision() -> int:
	return int(production.capture_snapshot().value["state_revision"])


func state_plate() -> int:
	return int(production.capture_snapshot().value["store"]["plate"])


func panel_intent() -> Dictionary:
	return {"expected_revision": current_revision(), "kind": "floor", "bounds_millimetres": [0, 500, 0, 1000], "height_millimetres": 0}


func panel_route(peer: int, operation: String, payload: Dictionary, request: String = "") -> Dictionary:
	request_sequence += 1
	if request.is_empty(): request = "panel-route-%d" % request_sequence
	host._peers[peer]["window"] = Time.get_ticks_msec() - 1000
	host.frames.clear()
	host._events.clear()
	host._receive(peer, JSON.parse_string(JSON.stringify({"type": "command", "request_id": request, "system": "production", "operation": operation, "payload": payload})))
	step()
	for reply in host.frames + host._events:
		if reply.get("peer") == peer and reply["frame"].get("request_id") == request: return reply["frame"]
	check(false, "host acknowledges " + request)
	return {"ok": false}


func check_projection(current: Dictionary) -> void:
	var projection := RemoteProductionProjection.new()
	check(projection.accept_record(JSON.parse_string(JSON.stringify(current))).is_success, "serialized current projection accepted")
	var accepted: Dictionary = projection.record.duplicate(true)
	var malformed: Array[Dictionary] = []
	for field in ["principal_id", "receipts", "materials", "control_grants"]:
		var bad: Dictionary = current.duplicate(true)
		bad["horizontal_panels"]["surfaces"][0][field] = "forged"
		malformed.append(bad)
	for surfaces in [null, [{}], current["horizontal_panels"]["surfaces"] + current["horizontal_panels"]["surfaces"]]:
		var bad: Dictionary = current.duplicate(true)
		bad["horizontal_panels"]["surfaces"] = surfaces
		malformed.append(bad)
	var mismatch: Dictionary = current.duplicate(true)
	mismatch["horizontal_panels"]["closure"]["production_revision"] -= 1
	malformed.append(mismatch)
	for bad in malformed: check(not projection.accept_record(bad).is_success, "malformed projection rejected without replacing accepted record")
	for bounds in [[0, 1050, 0, 1000], [0, 501, 0, 1000], [0, 0, 0, 1000]]:
		var bad: Dictionary = current.duplicate(true)
		bad["horizontal_panels"]["surfaces"][0]["bounds_millimetres"] = bounds
		check(not projection.accept_record(bad).is_success, "projection rechecks dimension and 50mm grid constraints")
	check(projection.record == accepted, "failed projection preserves last valid data")
	var legacy_records: Array[Dictionary] = []
	for version in [7, 8, 9]:
		var legacy: Dictionary = current.duplicate(true)
		legacy.erase("horizontal_panels")
		legacy.erase("paid_doors")
		legacy["schema_version"] = version
		if version < 9: legacy.erase("timed_canister")
		if version < 8: legacy.erase("recipe_requirements")
		var old := RemoteProductionProjection.new()
		check(old.accept_record(JSON.parse_string(JSON.stringify(legacy))).is_success, "legacy v%d readable" % version)
		check(not projection.accept_record(legacy).is_success, "current connection rejects downgrade")
		old.free()
		legacy_records.append(legacy)
	DirAccess.make_dir_recursive_absolute("res://var")
	var fixture := FileAccess.open("res://var/horizontal-panel-controls-fixture.json", FileAccess.WRITE)
	fixture.store_string(JSON.stringify({"current": current, "legacy": legacy_records, "malformed": malformed}))
	fixture.close()
	projection.free()
