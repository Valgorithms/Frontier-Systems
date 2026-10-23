extends "res://tests/godot/machinery_runtime_test.gd"

var access: AccessControlSystem
var door_id: String


func run() -> void:
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
	move([5000, 0, -6000])
	var pose: Dictionary = {"position": [5000, 0, -5000], "quarter_turn": 0}
	door_command("door_build", pose, false)
	command("panel_build", {"kind": "floor", "bounds_millimetres": [4500, 5500, -5050, -4050], "height_millimetres": 0})
	var panel: String = production.capture_snapshot().value["panels"].keys()[0]
	command("canister_reserve", {"job_id": "door-reservation", "expected_reservation_revision": production.capture_snapshot().value["construction"]["revision"], "control_epoch": 0})
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
	if not crowbar.is_empty(): equip(crowbar)
	door_command("door_open", {"door_id": door_id})
	check(access.devices[StringName(door_id)].actuator(PaidDoorConstruction.actuator_id(door_id)).position == 1.0, "existing Access actuator owns manual position")
	move([5000, 0, -4600])
	door_command("door_close", {"door_id": door_id}, false)
	door_command("door_remove", {"door_id": door_id}, false)
	move([5000, 0, -6000])
	door_command("door_close", {"door_id": door_id})
	var snapshot: Dictionary = JSON.parse_string(world.capture_world_snapshot_json().value)
	var target := WorldRuntime.new()
	target.resource_carriers_enabled = true
	root.add_child(target)
	check(target.restore_world_snapshot_json(JSON.stringify(snapshot)).is_success, "populated paired door world restores")
	var restored_prod: ProductionSimulationSystem = target.get_simulation_system(ProductionSimulationSystem.SYSTEM_ID)
	check(restored_prod.capture_snapshot().value["doors"] == snapshot["systems"]["production"]["doors"], "stable paid door identity survives restart")
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
	print("Paid manual door lifecycle: %d failures" % failures)
	finish()


func door_command(operation: String, payload: Dictionary, success: bool = true) -> void:
	var intent: Dictionary = payload.duplicate(true)
	intent["control_epoch"] = 0
	command(operation, intent, success)


func equip(item: String) -> void:
	var action := InventoryDevelopmentCommand.new()
	sequence += 1
	action.command_id = StringName("door-equip-%d" % sequence)
	action.authenticated_context = context
	action.operation = "self"
	action.payload = {"operation": "equip", "item_id": item, "source_container_id": "body.human-1", "destination_container_id": "body.human-1", "slot_id": "hand.left", "expected_revision": inventory.capture_snapshot().value["owner"]["state_revision"]}
	world.enqueue_command(action)
	step()
	check(last.is_success, "equip actual fabricated crowbar")
