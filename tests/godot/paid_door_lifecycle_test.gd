extends "res://tests/godot/timed_canister_controls_test.gd"

var access: AccessControlSystem
var door_id: String


func run() -> void:
	var blueprint: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/production/manual-door.v1.json"))
	check(PaidDoorGeometry.valid_blueprint(blueprint), "parsed JSON integer bill accepted")
	for amount in [2000000.5, true, 2000001, -1, "2000000"]:
		var altered: Dictionary = blueprint.duplicate(true)
		altered.materials.plate = amount
		check(not PaidDoorGeometry.valid_blueprint(altered), "altered/fractional/noninteger bill rejects")
	for field in ["materials", "schema_version", "provenance"]:
		var altered: Dictionary = blueprint.duplicate(true)
		altered.erase(field)
		check(not PaidDoorGeometry.valid_blueprint(altered), "missing blueprint field rejects")
	var extra: Dictionary = blueprint.duplicate(true)
	extra.materials.extra = 1
	check(not PaidDoorGeometry.valid_blueprint(extra), "extra bill field rejects")
	extra = blueprint.duplicate(true); extra.extra = 1
	check(not PaidDoorGeometry.valid_blueprint(extra), "extra blueprint field rejects")
	world = WorldRuntime.new()
	world.resource_carriers_enabled = true
	root.add_child(world)
	world.command_completed.connect(func(_command: SimulationCommand, result: ServiceResult) -> void: last = result)
	var started: ServiceResult = world.start_simulation()
	check(started.is_success, "finite door world starts: %s" % started.message)
	if not started.is_success: finish(); return
	runner = world.get_node("SimulationRunner")
	runner.set_physics_process(false)
	production = world.get_simulation_system(ProductionSimulationSystem.SYSTEM_ID)
	inventory = world.get_simulation_system(InventorySimulationSystem.SYSTEM_ID)
	access = world.get_simulation_system(AccessControlSystem.SYSTEM_ID)
	context = AuthenticatedCommandContext.for_local_development(&"local-inventory-actor", world.world_id, world.region_id)
	var legacy: Dictionary = production.capture_snapshot().value
	legacy.erase("doors")
	legacy["schema_version"] = 9
	check(production.restore_snapshot_record(legacy, 0).is_success, "v9 migrates to empty paid doors")
	for batch in range(10):
		move([-3000, 0, -1000])
		command("extract", {"deposit_id": "deposit.iron", "carrier_id": "resource-canister-1", "amount_milligrams": 1000000})
		move([0, 0, 0])
		command("unload_cargo", {"carrier_id": "resource-canister-1", "material": "ore.iron", "amount_milligrams": 1000000})
		command("process", {"recipe_id": "refine.iron"})
		step(120)
	for index in range(3):
		command("process", {"recipe_id": "craft.plate"})
		step(120)
	command("fabricate_equipment", {"blueprint_id": "equipment.crowbar"})
	var crowbar: String = ""
	for item in inventory.own_inventory_observation(context).value["items"]:
		if item["definition_id"] == "item.crowbar.fabricated": crowbar = item["item_id"]
	command("canister_reserve", {"job_id": "door-reservation", "expected_reservation_revision": production.capture_snapshot().value["construction"]["revision"], "control_epoch": 0})
	move([3500, 0, -6000])
	var pose: Dictionary = {"position": [3500, 0, -5000], "quarter_turn": 0}
	var split_support: Dictionary = {"left": {"kind": "floor", "height_millimetres": 0, "bounds_millimetres": [3000, 3500, -5050, -4050]}, "right": {"kind": "floor", "height_millimetres": 0, "bounds_millimetres": [3500, 4000, -5050, -4050]}}
	check(PaidDoorGeometry.supported(pose, split_support), "complete union of two paid floors supports swing")
	split_support.right.bounds_millimetres[0] = 3550
	check(not PaidDoorGeometry.supported(pose, split_support), "50 mm support gap rejects")
	var occupancy: Dictionary = inventory.capture_snapshot().value
	check(PaidDoorConstruction.unoccupied(pose, occupancy, production.capture_snapshot().value), "known clear canonical bodies map")
	occupancy.owner.bodies[0].profile_id = "unmapped.profile"
	check(not PaidDoorConstruction.unoccupied(pose, occupancy, production.capture_snapshot().value), "unknown body profile fails closed")
	occupancy = inventory.capture_snapshot().value
	occupancy.world_storage.append({"container_id": "unknown.world.root", "position_millimetres": [10000, 0, 10000]})
	check(not PaidDoorConstruction.unoccupied(pose, occupancy, production.capture_snapshot().value), "unknown world storage fails closed")
	door_command("door_build", pose, false)
	command("panel_build", {"kind": "floor", "bounds_millimetres": [3000, 4000, -5050, -4050], "height_millimetres": 0})
	var panel: String = production.capture_snapshot().value["panels"].keys()[0]
	var claimed: int = ConstructionReservationPlan.claimed(production.capture_snapshot().value["construction"])
	door_command("door_build", pose)
	var state: Dictionary = production.capture_snapshot().value
	if state["doors"].size() != 1: check(false, "one paid door exists"); finish(); return
	door_id = state["doors"].keys()[0]
	check(state["store"]["plate"] == 0 and state["doors"][door_id]["materials"] == {"plate": 2000000}, "three real kg plate debit into one floor and one door")
	check(ConstructionReservationPlan.claimed(state["construction"]) == claimed, "door build preserves active finite iron reservation")
	var device: AccessControlledDeviceState = access.devices[StringName(door_id)]
	check(device.security_controllers.is_empty() and device.actuators.size() == 1, "no fixture controller spares or second actuator granted")
	var retained: Dictionary = pose.duplicate(true)
	retained.merge({"control_epoch": 0, "expected_revision": int(state["state_revision"]) - 1})
	var request: String = "machine-test-%d" % sequence
	check(production.apply_local(context, request, "door_build", retained, runner.tick_number + 1).is_success, "exact paid build replay accepted")
	check(production.capture_snapshot().value == state, "exact retry creates no material or device")
	retained["position"] = [6000, 0, -5000]
	check(not production.apply_local(context, request, "door_build", retained, runner.tick_number + 1).is_success, "changed request intent rejects")
	command("panel_remove", {"panel_id": panel}, false)
	check(production.capture_snapshot().value["panels"].has(panel), "attached paid floor removal is atomic")
	door_command("door_build", pose, false)
	door_command("door_open", {"door_id": door_id}, false)
	check(not crowbar.is_empty(), "real fabricated crowbar available")
	if crowbar.is_empty(): finish(); return
	equip(crowbar)
	if not last.is_success: finish(); return
	await authority_and_contact_checks()
	door_command("door_open", {"door_id": door_id})
	check(access.devices[StringName(door_id)].actuator(PaidDoorConstruction.actuator_id(door_id)).position == 1.0, "existing Access actuator owns manual position")
	move([3500, 0, -4600])
	door_command("door_close", {"door_id": door_id}, false)
	door_command("door_remove", {"door_id": door_id}, false)
	move([3500, 0, -6000])
	door_command("door_close", {"door_id": door_id})
	var expected_doors: Dictionary = production.capture_snapshot().value["doors"]
	var captured: ServiceResult = world.capture_world_snapshot_json()
	check(captured.is_success, "whole paid-door snapshot: %s" % captured.message)
	if not captured.is_success: finish(); return
	var snapshot: Dictionary = JSON.parse_string(captured.value)
	var target := WorldRuntime.new()
	target.resource_carriers_enabled = true
	root.add_child(target)
	check(target.restore_world_snapshot_json(JSON.stringify(snapshot)).is_success, "populated paired door world restores")
	var restored_prod: ProductionSimulationSystem = target.get_simulation_system(ProductionSimulationSystem.SYSTEM_ID)
	check(restored_prod.capture_snapshot().value["doors"] == expected_doors, "stable paid door identity survives restart")
	target.free()
	for mutation in ["missing-device", "orphan", "bill", "body"]:
		var forged: Dictionary = snapshot.duplicate(true)
		if mutation == "missing-device": forged["systems"]["access_control"]["devices"] = forged["systems"]["access_control"]["devices"].filter(func(d: Dictionary) -> bool: return d.device_id != door_id)
		if mutation == "orphan": forged["systems"]["production"]["doors"].clear()
		if mutation == "bill": forged["systems"]["production"]["doors"][door_id]["materials"]["plate"] = 0
		if mutation == "body": forged["systems"]["production"]["doors"][door_id]["body_id"] = "missing.body"
		target = WorldRuntime.new(); target.resource_carriers_enabled = true; root.add_child(target)
		var before: String = target.capture_world_snapshot_json().value
		check(not target.restore_world_snapshot_json(JSON.stringify(forged)).is_success, "%s link rejects" % mutation)
		check(target.capture_world_snapshot_json().value == before, "failed whole restore changes no owner")
		target.free()
	var before_access: Dictionary = access.capture_snapshot().value
	var no_doors: Dictionary = production.capture_snapshot().value
	no_doors["doors"].clear()
	var fence: int = production.collision_restore_generation()
	check(not production.restore_snapshot_record(no_doors, runner.tick_number).is_success and production.collision_restore_generation() == fence, "independent mismatched Production restore preserves fence")
	var missing_access: Dictionary = before_access.duplicate(true)
	missing_access["devices"] = missing_access["devices"].filter(func(d: Dictionary) -> bool: return d.device_id != door_id)
	check(not access.restore_snapshot_record(missing_access, runner.tick_number).is_success and access.capture_snapshot().value == before_access, "independent mismatched Access restore changes nothing")
	var original: AccessControlledDeviceState = access.devices[StringName(door_id)]
	var prepared := PreparedDoorChange.new(access, StringName(door_id), original, original.to_record(), false)
	original.actuator(PaidDoorConstruction.actuator_id(door_id)).integrity = 0.5
	var mutated: Dictionary = access.capture_snapshot().value
	check(not prepared.commit(access).is_success and access.capture_snapshot().value == mutated, "same object semantic mutation rejects prepared commit")
	check(not prepared.commit(access).is_success, "failed token cannot commit twice")
	original.actuator(PaidDoorConstruction.actuator_id(door_id)).integrity = 1.0
	prepared = PreparedDoorChange.new(access, StringName(door_id), original, original.to_record(), false)
	check(prepared.commit(access).is_success and not prepared.commit(access).is_success, "successful prepared token is single use")
	check(access.devices[AccessControlSystem.PROTOTYPE_AIRLOCK_ID] != null, "unrelated prototype retained")
	var pair_prod: Dictionary = production.capture_snapshot().value
	var pair_access: Dictionary = access.capture_snapshot().value
	check(not production.with_checkpoint_door_links(pair_prod, pair_access, runner.tick_number, func() -> ServiceResult:
		return production.with_checkpoint_door_links(pair_prod, pair_access, runner.tick_number, func() -> ServiceResult: return ServiceResult.success())).is_success, "nested paired restore scope rejects")
	check(production._checkpoint_door_links.is_empty(), "paired restore scope clears after rejected callback")
	var solids: Array = production.door_solids().value
	var contact: Dictionary = {"schema_version": 1, "world_id": String(world.world_id), "region_id": String(world.region_id), "sequence": 1, "inventory_restore": 0, "production_restore": fence, "production_revision": pair_prod["state_revision"], "production_tick": pair_prod["last_tick"], "inventory_tick": runner.tick_number, "boxes": solids}
	check(DoorContactObservation.decode(contact, world.world_id, world.region_id).is_success, "complete dedicated door solids decode")
	var malformed: Dictionary = contact.duplicate(true)
	malformed["boxes"].pop_back()
	check(not DoorContactObservation.decode(malformed, world.world_id, world.region_id).is_success, "incomplete frame/leaf rejects")
	malformed = contact.duplicate(true); malformed["boxes"][3]["size_millimetres"][0] += 50
	check(not DoorContactObservation.decode(malformed, world.world_id, world.region_id).is_success, "forged vertical geometry rejects")
	var fixture := FileAccess.open("res://var/paid-door-fixture.json", FileAccess.WRITE)
	fixture.store_string(JSON.stringify({"persistent": pair_prod, "legacy": legacy, "contact": contact, "observation": production.observation(context).value}))
	fixture.close()
	door_command("door_remove", {"door_id": door_id})
	check(not access.devices.has(StringName(door_id)) and production.capture_snapshot().value["store"]["plate"] == 2000000, "disassembly removes only paid device and refunds exact trusted bill")
	command("panel_remove", {"panel_id": panel})
	check(production.capture_snapshot().value["store"]["plate"] == 3000000, "floor recovers once detached")
	if is_instance_valid(host): host.free()
	print("Paid manual door lifecycle: %d failures" % failures)
	finish()


func door_command(operation: String, payload: Dictionary, success: bool = true) -> void:
	var intent: Dictionary = payload.duplicate(true)
	intent["control_epoch"] = 0
	command(operation, intent, success)


func equip(item: String) -> void:
	var actor: ServiceResult = inventory.authorize(context, true)
	check(actor.is_success, "resolve actual actor body for fabricated crowbar")
	if not actor.is_success: return
	for operation in ["equip", "select_hand"]:
		var action := InventoryDevelopmentCommand.new()
		sequence += 1
		action.command_id = StringName("door-equip-%d" % sequence)
		action.authenticated_context = context
		action.operation = "self"
		action.payload = {"operation": operation, "item_id": item if operation == "equip" else "", "source_container_id": actor.value if operation == "equip" else "", "destination_container_id": "", "slot_id": "hand.left", "expected_revision": inventory.own_inventory_observation(context, true).value.inventory_revision}
		world.enqueue_command(action)
		step()
		check(last.is_success, "actual fabricated crowbar %s: %s" % [operation, last.message])
		if not last.is_success: return
	check(inventory.active_tool(context, "tool.crowbar").is_success, "actual fabricated crowbar supplies active Tools capability")


func connect_door_peer(peer: int, slot: int) -> void:
	host._peers[peer] = {"socket": RecordingSocket.new(), "slot": -1, "created": Time.get_ticks_msec(), "last_move": Time.get_ticks_msec(), "pending_move": false, "window": Time.get_ticks_msec(), "commands": 0}
	host._receive(peer, {"type": "authenticate", "key": host._keys[slot]})
	check(host._peers[peer].slot == slot, "door peer authenticated without listener")


func door_route(peer: int, operation: String, payload: Dictionary) -> Dictionary:
	request_sequence += 1
	var request: String = "door-host-%d" % request_sequence
	host._peers[peer].window = Time.get_ticks_msec() - 1000
	host.frames.clear(); host._events.clear()
	host._receive(peer, JSON.parse_string(JSON.stringify({"type": "command", "request_id": request, "system": "production", "operation": operation, "payload": payload})))
	step()
	for reply in host.frames + host._events:
		if reply.peer == peer and reply.frame.get("request_id") == request: return reply.frame
	check(false, "door host acknowledges fixed-tick command")
	return {"ok": false}


func operate_intent() -> Dictionary:
	return {"expected_revision": production.capture_snapshot().value.state_revision, "control_epoch": 0, "door_id": door_id}


func publish_door(peer: int) -> Dictionary:
	host.frames.clear()
	host._publish(peer)
	for item in host.frames:
		if item.peer == peer and item.frame.type == "observation": return JSON.parse_string(JSON.stringify(item.frame))
	check(false, "complete host contact publication")
	return {}


func authority_and_contact_checks() -> void:
	host = RecordingHost.new()
	root.add_child(host); host.set_process(false); host._world = world
	host._keys = ["door-actor-0000000000000000000000", "door-target-000000000000000000000"]
	world.command_completed.connect(host._on_completed)
	connect_door_peer(1, 0); connect_door_peer(2, 1)
	var original: Dictionary = production.capture_snapshot().value
	var before_access: Dictionary = access.capture_snapshot().value
	check(not door_route(2, "door_remove", operate_intent()).ok, "foreign authenticated principal cannot recover door")
	check(production.capture_snapshot().value.doors == original.doors and access.capture_snapshot().value.devices == before_access.devices, "foreign rejection preserves both owner records")
	var stale: Dictionary = operate_intent(); stale.control_epoch = 1
	check(not door_route(1, "door_open", stale).ok, "host rejects stale control epoch")
	var forged: Dictionary = operate_intent(); forged.principal_id = "local-inventory-actor"
	check(not door_route(1, "door_open", forged).ok, "host rejects extra client authority")
	# A command queued by a disconnected peer must not become a later owner's action.
	host._receive(1, {"type": "command", "request_id": "queued-door-open", "system": "production", "operation": "door_open", "payload": operate_intent()})
	host._drop_peer(1)
	step()
	check(not last.is_success and last.error_code == &"door_session_expired", "disconnected queued door command fails at fixed tick")
	check(access.devices[StringName(door_id)].actuator(PaidDoorConstruction.actuator_id(door_id)).position == 0.0, "expired session cannot move leaf")
	connect_door_peer(3, 0)
	# Recheck transport identity even if a peer ID and slot are reused.
	var queued := HostedPaidDoorCommand.new()
	queued.host_reference = weakref(host); queued.peer_id = 3; queued.slot = 0
	queued.session_lease = host._peers[3].door_session_lease
	queued.authenticated_context = host._context(0, 3)
	queued.operation = "door_open"; queued.payload = operate_intent()
	queued.command_id = &"validate-then-replace"
	# Resolve the actual stable body ID rather than assuming an inventory container ID.
	queued.body_id = inventory.authorize(queued.authenticated_context, true).value
	check(queued.validate(world).is_success, "current hosted door validates")
	host._peers[3].door_session_lease = RefCounted.new()
	check(not queued.apply(world).is_success, "replacement between validate/apply fails closed")
	var remote := RemoteWorldRuntime.new()
	root.add_child(remote); remote.set_process(false)
	remote._receive({"type": "authenticated", "slot": 0, "world_id": String(world.world_id), "region_id": String(world.region_id)})
	var scene := PaidDoorContactScene.new(); root.add_child(scene); scene.bind(remote)
	remote._receive(publish_door(3))
	check(scene.get_child_count() == 4, "real remote receive installs complete frame and leaf")
	var character := CharacterBody3D.new()
	var capsule := CapsuleShape3D.new(); capsule.radius = 0.35; capsule.height = 1.8
	var collider := CollisionShape3D.new(); collider.shape = capsule; character.add_child(collider)
	root.add_child(character)
	await physics_frame
	character.position = ProceduralWorldInventoryPreview.DISPLAY_ORIGIN + Vector3(3.5, 0.9, -5.7)
	check(character.move_and_collide(Vector3(0, 0, 1.4)) != null, "PhysicsServer closed leaf blocks player capsule")
	check(not production.door_motion_clear([3500, 0, -5700], [3500, 0, -4300]), "canonical closed leaf rejects tunnelling")
	# Actual local production UI queues the same authenticated intent contract.
	var controls := PaidDoorControls.new(); root.add_child(controls); controls.configure(world); controls.set_process(false)
	controls._process(0.2)
	check(not controls._buttons[1].disabled, "door controls operate away from workstation")
	controls._buttons[1].pressed.emit()
	check(not controls._pending.is_empty(), "actual player button queues door operation")
	step(); controls._process(0.2)
	check(controls._pending.is_empty() and access.devices[StringName(door_id)].actuator(PaidDoorConstruction.actuator_id(door_id)).position == 1.0, "UI command completion opens real Access leaf")
	remote._receive(publish_door(3))
	await physics_frame
	character.position = ProceduralWorldInventoryPreview.DISPLAY_ORIGIN + Vector3(3.5, 0.9, -5.7)
	check(character.move_and_collide(Vector3(0, 0, 1.4)) == null, "PhysicsServer open leaf permits capsule traversal")
	check(production.door_motion_clear([3500, 0, -5700], [3500, 0, -4300]), "canonical open doorway permits traversal")
	check(door_route(3, "door_close", operate_intent()).ok, "reconnected current session operates original stable door")
	remote._receive(publish_door(3))
	var bad: Dictionary = publish_door(3); bad.door_contact.boxes.pop_back()
	remote._receive(bad)
	check(scene.get_child_count() == 0, "malformed door snapshot clears contact immediately")
	remote.panel_contact_cleared.emit()
	controls.free(); scene.free(); remote.free(); character.free()
