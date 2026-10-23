extends "res://tests/godot/machinery_runtime_test.gd"

## Only socket output is replaced. Authentication, host admission, command queue,
## canonical owners, client receive and actual panel buttons all run normally.
class RecordingHost extends FirstPlayableHost:
	var frames: Array[Dictionary] = []
	func _send(id: int, value: Dictionary) -> void:
		frames.append({"peer": id, "frame": value.duplicate(true)})

class RecordingSocket extends RefCounted:
	func close(_code: int, _reason: String = "") -> void: pass

var host: RecordingHost
var request_sequence: int = 0
var completed: ProductionDevelopmentCommand


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
	host = RecordingHost.new()
	root.add_child(host)
	host.set_process(false)
	host._world = world
	host._keys = ["canister-actor-00000000000000000000", "canister-target-0000000000000000000"]
	world.command_completed.connect(host._on_completed)
	for peer in [1, 2]:
		host._peers[peer] = {"socket": RecordingSocket.new(), "slot": -1, "created": Time.get_ticks_msec(), "last_move": Time.get_ticks_msec(), "pending_move": false, "window": Time.get_ticks_msec(), "commands": 0}
		host._receive(peer, {"type": "authenticate", "key": host._keys[peer - 1]})
	check(host._peers[1]["slot"] == 0 and host._peers[2]["slot"] == 1, "host authenticates both identities without a listener")
	var reserve: Dictionary = intent("host-job")
	check(route(1, "reserve", reserve, "host-reserve")["ok"], "real authenticated host reserves finite stock")
	check(not route(2, "cancel", intent("host-job"))["ok"], "other authenticated actor cannot cancel own job")
	check(not production.observation(host._context(1, 2)).value["timed_canister"]["jobs"].has("host-job"), "other actor projection omits job and bindings")
	for field in ["body_id", "world_id", "region_id"]:
		var detached: Dictionary = production.capture_snapshot().value
		detached["construction_bindings"]["host-job"][field] = "different-scope"
		check(not TimedCanisterConstruction.observation(detached, inventory, context, production.observation(context).value["timed_canister"]["blueprint_fingerprint"])["jobs"].has("host-job"), "projection filters own job with different " + field)
	check(route(1, "interrupt", intent("host-job"))["ok"], "host pause accepted")
	var before: Dictionary = production.capture_snapshot().value
	check(route(1, "reserve", reserve, "host-reserve")["ok"], "exact request retry returns retained result")
	check(production.capture_snapshot().value["construction"] == before["construction"], "retry cannot restart paused work")
	for field in ["tick", "output_id", "actor_id", "body_id", "world_id", "region_id", "permissions"]:
		var forged: Dictionary = intent("host-job")
		forged[field] = 1
		check(not route(1, "resume", forged)["ok"], "host rejects client authority field " + field)
	var stale: Dictionary = intent("host-job")
	stale["expected_revision"] -= 1
	check(not route(1, "resume", stale)["ok"], "host rejects stale production revision")
	stale = intent("host-job")
	stale["expected_reservation_revision"] -= 1
	check(not route(1, "resume", stale)["ok"], "host rejects stale reservation revision")
	check(not route(1, "advance", intent("host-job"))["ok"], "client cannot advance work ticks")
	var controller: Dictionary = inventory.controller_candidate().value["body.human-2"]
	check(inventory.commit_control_epoch(controller, int(controller["control_epoch"]) + 1).is_success, "canonical control epoch changes")
	check(not route(1, "reserve", reserve, "host-reserve")["ok"], "old epoch retry cannot bypass fresh authority")
	check(route(1, "resume", intent("host-job"))["ok"], "fresh observed epoch resumes through actual host")
	move([3000, 0, 0])
	var distant: Dictionary = production.observation(context).value["timed_canister"]
	check(distant["jobs"]["host-job"]["state"] == "paused" and not distant["can_operate"], "distant own job remains visible but cannot operate")
	check(not route(1, "resume", intent("host-job"))["ok"], "current epoch cannot bypass reach")
	move([0, 0, 0])
	check(route(1, "cancel", intent("host-job"))["ok"], "cancel releases claim through host")
	check(production.capture_snapshot().value["store"]["iron"] == 1200000, "cancel conserves actual finite stock")
	# Exercise compact actual workbench UI rather than a fabricated intent builder.
	root.size = Vector2i(900, 900)
	var scroll := ScrollContainer.new()
	scroll.size = Vector2(400, 800)
	root.add_child(scroll)
	var panel := MachineryPanel.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(panel)
	panel.configure(world)
	panel.observe(frame())
	var controls: TimedCanisterControls = panel._timed_canister
	check(not controls._details.visible, "controls initially collapsed in existing panel")
	controls._toggle.button_pressed = true
	await process_frame
	await process_frame
	check(controls.size.x <= scroll.size.x and controls._details.is_visible_in_tree(), "expanded controls fit compact workbench")
	check(not controls._buttons["reserve"].disabled, "start uses finite stock availability")
	controls._buttons["reserve"].pressed.emit()
	var ui_id: String = controls._selected_id
	check(not controls._pending.is_empty() and controls._buttons["reserve"].disabled, "pending request prevents double submission")
	step()
	check(last.is_success and completed.payload["control_epoch"] == 1 and completed.payload["job_id"] == ui_id, "UI queues actual current-control ingress")
	panel.observe(frame())
	controls._buttons["interrupt"].pressed.emit()
	step()
	panel.observe(frame())
	check(last.is_success and controls._record["timed_canister"]["jobs"][ui_id]["state"] == "paused", "UI pause reaches owner")
	var paused: Dictionary = frame()
	step(5)
	check(production.capture_snapshot().value["construction"]["jobs"][ui_id]["progress_ticks"] == paused["production"]["timed_canister"]["jobs"][ui_id]["progress_ticks"], "paused UI job consumes no work")
	panel.observe(frame())
	controls._buttons["resume"].pressed.emit()
	step()
	panel.observe(frame())
	check(last.is_success and not controls._buttons["interrupt"].disabled, "UI resumes canonical work")
	controls._buttons["cancel"].pressed.emit()
	step()
	panel.observe(frame())
	check(last.is_success and controls._record["timed_canister"]["jobs"][ui_id]["state"] == "cancelled" and production.capture_snapshot().value["store"]["iron"] == 1200000, "UI cancel releases the unspent claim")
	controls._buttons["reserve"].pressed.emit()
	ui_id = controls._selected_id
	step()
	panel.observe(frame())
	check(last.is_success, "UI starts a fresh job after cancellation")
	step(120)
	panel.observe(frame())
	check(not controls._buttons["complete"].disabled, "ready observed job enables completion")
	var pre_completion: Dictionary = frame()
	controls._buttons["complete"].pressed.emit()
	step()
	panel.observe(frame())
	projection_checks(frame(), pre_completion)
	check(not controls._record.is_empty(), "completed output remains readable by actual workbench")
	if controls._record.is_empty():
		scroll.free()
		host.free()
		world.free()
		quit(1)
		return
	check(last.is_success and controls._record["timed_canister"]["jobs"][ui_id]["state"] == "completed", "UI completes real job")
	var output: String = TimedCanisterConstruction.output_id(ui_id)
	var own: Dictionary = inventory.own_inventory_observation(context).value
	check(own["items"].any(func(item: Dictionary) -> bool: return item["item_id"] == output and item["definition_revision"] == 2), "completed UI job creates actual revision-2 canister")
	check(production.capture_snapshot().value["store"]["iron"] == 200000, "completion debits exactly one real bill")
	check(JSON.parse_string(world.capture_world_snapshot_json().value)["systems"]["production"]["schema_version"] == 11, "UI preserves v11 save contract")
	panel.observe(paused)
	check(controls._record.is_empty() and controls._buttons["resume"].disabled, "stale panel observation disables actions")
	panel.observe(frame())
	controls.observe({})
	check(controls._record.is_empty() and controls._buttons["reserve"].disabled, "missing or disconnected observation fails closed")
	scroll.free()
	host.free()
	world.free()
	print("Timed canister controls: %d failures" % failures)
	quit(1 if failures else 0)


func intent(id: String) -> Dictionary:
	var observed: Dictionary = production.observation(context).value
	return {"expected_revision": observed["state_revision"], "expected_reservation_revision": observed["timed_canister"]["revision"], "control_epoch": observed["timed_canister"]["control_epoch"], "job_id": id}


func route(peer: int, operation: String, payload: Dictionary, request: String = "") -> Dictionary:
	request_sequence += 1
	if request.is_empty(): request = "canister-route-%d" % request_sequence
	host._peers[peer]["window"] = Time.get_ticks_msec() - 1000
	host.frames.clear()
	host._events.clear()
	host._receive(peer, JSON.parse_string(JSON.stringify({"type": "command", "request_id": request, "system": "production", "operation": "canister_" + operation, "payload": payload})))
	step()
	for reply in host.frames + host._events:
		if reply.get("peer") == peer and reply["frame"].get("request_id") == request: return reply["frame"]
	check(false, "host acknowledges " + request)
	return {"ok": false}


func frame() -> Dictionary:
	return {"production": production.observation(context).value, "inventory": inventory.own_inventory_observation(context).value, "position": inventory.own_position(context).value}


func projection_checks(current: Dictionary, pre_completion: Dictionary) -> void:
	var observed: Dictionary = current["production"]
	var projection := RemoteProductionProjection.new()
	check(projection.accept_record(JSON.parse_string(JSON.stringify(observed))).is_success, "remote accepts completed timed structure alongside unchanged v1 catalog")
	var view: Dictionary = observed["timed_canister"]
	check(not view.has("receipts") and not view.has("construction_bindings") and not JSON.stringify(view).contains("actor_id"), "projection omits private owner authority")
	var malformed: Array = []
	for field in ["receipts", "tick", "output_id", "actor_id", "control_grants"]:
		var bad: Dictionary = observed.duplicate(true)
		bad["timed_canister"][field] = {}
		malformed.append(bad)
	for value in [-1, 1.5, "1"]:
		var bad: Dictionary = observed.duplicate(true)
		bad["timed_canister"]["control_epoch"] = value
		malformed.append(bad)
	var excess: Dictionary = observed.duplicate(true)
	excess["timed_canister"]["jobs"] = {}
	for index in range(17): excess["timed_canister"]["jobs"]["excess-%d" % index] = {"state": "paused", "progress_ticks": 0}
	malformed.append(excess)
	for progress in [-1, 121, 1.5]:
		var bad: Dictionary = observed.duplicate(true)
		bad["timed_canister"]["jobs"].values()[0]["progress_ticks"] = progress
		malformed.append(bad)
	var unknown_state: Dictionary = observed.duplicate(true)
	unknown_state["timed_canister"]["jobs"].values()[0]["state"] = "untrusted"
	malformed.append(unknown_state)
	for revision in [2, 3]:
		var bad: Dictionary = observed.duplicate(true)
		for physical in bad["machinery"]["inventory_items"]:
			if physical["definition_revision"] == 2:
				physical["definition_revision"] = revision
				physical["definition_id"] = "item.plate.prototype" if revision == 2 else physical["definition_id"]
		malformed.append(bad)
	for bad in malformed:
		check(not projection.accept_record(bad).is_success, "remote rejects malformed/private/oversized projection")
	var stale: Dictionary = observed.duplicate(true)
	stale["state_revision"] -= 1
	check(not projection.accept_record(stale).is_success, "remote rejects stale state revision")
	stale = observed.duplicate(true)
	stale["timed_canister"]["control_epoch"] = 0
	check(not projection.accept_record(stale).is_success, "remote rejects stale control epoch")
	var remote := RemoteWorldRuntime.new()
	root.add_child(remote)
	remote.set_process(false)
	remote._authenticated = true
	var wire: Dictionary = current.duplicate(true)
	wire["panel_contact"] = preload("res://tests/support/paid_panel_contact_fixture.gd").envelope(world, host._context(0, 1))
	wire["door_contact"] = preload("res://tests/support/paid_panel_contact_fixture.gd").door_envelope(world, host._context(0, 1))
	wire.merge({"type": "observation", "tick_number": runner.tick_number, "players": [], "terrain": world.terrain_observation(host._context(0, 1)).value, "tools": world.get_simulation_system(ToolSimulationSystem.SYSTEM_ID).observation(host._context(0, 1)).value})
	check(TerrainObservationValidation.valid(JSON.parse_string(JSON.stringify(wire["terrain"]))), "actual terrain projection valid for remote frame")
	check(ToolObservationValidation.valid(JSON.parse_string(JSON.stringify(wire["tools"]))), "actual tool projection valid for remote frame")
	remote._receive(JSON.parse_string(JSON.stringify(wire)))
	check(remote.production_observation(context).is_success, "actual remote receive accepts completed output")
	var remote_controls := TimedCanisterControls.new()
	root.add_child(remote_controls)
	remote_controls.configure(remote)
	remote_controls.observe(remote.production_observation(context).value)
	check(not remote_controls._record.is_empty(), "remote UI reads real completed host projection")
	for version in [true, 10.5, 15, "13"]:
		var bad_version: Dictionary = remote.production_observation(context).value.duplicate(true)
		bad_version.schema_version = version
		remote_controls.observe(bad_version)
		check(remote_controls._record.is_empty(), "timed UI rejects boolean/fractional/unknown/string version")
		remote_controls.observe(remote.production_observation(context).value)
		check(not remote_controls._record.is_empty(), "current integral JSON version restores timed UI")
	remote.connection_closed.emit("test disconnect")
	check(remote_controls._record.is_empty() and remote_controls._buttons["complete"].disabled, "remote disconnect clears timed UI authority")
	remote_controls.free()
	var legacy: Dictionary = pre_completion["production"].duplicate(true)
	# Use a pre-completion projection for legacy compatibility: old versions have
	# no definition identity for revision-2 timed output.
	legacy.erase("timed_canister")
	legacy.erase("horizontal_panels")
	legacy.erase("paid_doors")
	legacy["schema_version"] = 8
	var old_projection := RemoteProductionProjection.new()
	check(old_projection.accept_record(legacy).is_success, "legacy v8 remains readable without timed controls")
	var legacy_controls := TimedCanisterControls.new()
	root.add_child(legacy_controls)
	legacy_controls.configure(world)
	legacy_controls.observe(legacy)
	check(legacy_controls._record.is_empty(), "legacy UI does not fabricate current authority")
	legacy_controls.free()
	DirAccess.make_dir_recursive_absolute("res://var")
	var fixture := FileAccess.open("res://var/timed-canister-controls-fixture.json", FileAccess.WRITE)
	fixture.store_string(JSON.stringify({"current": observed, "legacy": legacy, "malformed": malformed}))
	fixture.close()
	remote.free()
	projection.free()
	old_projection.free()
