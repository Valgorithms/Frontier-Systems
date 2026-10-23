extends "res://tests/godot/machinery_runtime_test.gd"


func run() -> void:
	world = WorldRuntime.new()
	world.resource_carriers_enabled = true
	root.add_child(world)
	world.command_completed.connect(func(_command: SimulationCommand, result: ServiceResult) -> void: last = result)
	check(world.start_simulation().is_success, "world starts")
	runner = world.get_node("SimulationRunner")
	runner.set_physics_process(false)
	production = world.get_simulation_system(ProductionSimulationSystem.SYSTEM_ID)
	inventory = world.get_simulation_system(InventorySimulationSystem.SYSTEM_ID)
	context = AuthenticatedCommandContext.for_local_development(&"local-inventory-actor", world.world_id, world.region_id)
	# Real finite extraction/refining: 2 kg ore -> 1.2 kg iron + .8 kg tailings.
	for batch in range(2):
		move([-3000, 0, -1000])
		command("extract", {"deposit_id": "deposit.iron", "carrier_id": "resource-canister-1", "amount_milligrams": 1000000})
		move([0, 0, 0])
		command("unload_cargo", {"carrier_id": "resource-canister-1", "material": "ore.iron", "amount_milligrams": 1000000})
		command("process", {"recipe_id": "refine.iron"})
		step(120)
	var initial: Dictionary = state()
	check(initial["store"]["iron"] == 1200000, "finite refined stock established")
	canister("reserve", "first")
	var reserve_id: String = "machine-test-%d" % sequence
	var reserve_payload: Dictionary = {"expected_revision": initial["state_revision"], "job_id": "first", "expected_reservation_revision": initial["construction"]["revision"], "control_epoch": 0}
	check(ConstructionReservationPlan.claimed(state()["construction"]) == 1000000, "real workbench iron claimed without copying or debiting it")
	canister("reserve", "second", false)
	command("process", {"recipe_id": "craft.plate"}, false)
	command("fabricate_equipment", {"blueprint_id": "equipment.canister"}, false)
	command("machine_craft", {"kind": "equipment.canister"}, false)
	command("machine_craft", {"kind": "frame"}, false)
	command("load_cargo", {"carrier_id": "resource-canister-1", "material": "iron", "amount_milligrams": 300000}, false)
	check(state()["store"] == initial["store"] and state()["structures"].is_empty(), "all denied spend paths leave stock and physical outputs untouched")
	# Legitimate free stock remains usable while the 1 kg claim is protected.
	command("load_cargo", {"carrier_id": "resource-canister-1", "material": "iron", "amount_milligrams": 200000})
	command("unload_cargo", {"carrier_id": "resource-canister-1", "material": "iron", "amount_milligrams": 200000})
	var before_interrupt: int = state()["construction"]["jobs"]["first"]["progress_ticks"]
	move([3000, 0, 0])
	check(state()["construction"]["jobs"]["first"]["state"] == "paused", "leaving reach interrupts canonical work")
	step(10)
	check(state()["construction"]["jobs"]["first"]["progress_ticks"] == before_interrupt, "interruption does not consume wall-clock work")
	move([0, 0, 0])
	for index in range(70): command("power", {"station": "construction", "enabled": true})
	check(not state()["receipts"].any(func(receipt: Dictionary) -> bool: return receipt["request_id"] == reserve_id), "ordinary rolling receipts no longer contain original reservation")
	var foreign := AuthenticatedCommandContext.for_local_development(&"local-inventory-target", world.world_id, world.region_id)
	var intent: Dictionary = canister_payload("first")
	check(not production.apply_local(foreign, "foreign-job", "canister_cancel", intent, runner.tick_number + 1).is_success, "foreign actor cannot cancel another claim")
	intent["control_epoch"] = 1
	check(not production.apply_local(context, "wrong-control", "canister_resume", intent, runner.tick_number + 1).is_success, "wrong control cannot resume")
	intent = canister_payload("first")
	intent["expected_revision"] -= 1
	check(not production.apply_local(context, "stale-owner", "canister_resume", intent, runner.tick_number + 1).is_success, "stale owner revision rejects")
	# Retained retries are durable and never restart cancelled/paused work.
	check(production.apply_local(context, reserve_id, "canister_reserve", reserve_payload, runner.tick_number + 1).is_success, "old exact reservation retry returns original receipt")
	check(not production.apply_local(context, reserve_id, "power", {"expected_revision": state()["state_revision"], "station": "printer", "enabled": false}, runner.tick_number + 1).is_success, "permanent construction identity cannot be reused through an older operation")
	check(state()["construction"]["jobs"]["first"]["state"] == "paused", "reservation retry has no effects")
	canister("resume", "first")
	step(12)
	var controller: Dictionary = inventory.controller_candidate().value["body.human-2"]
	check(inventory.commit_control_epoch(controller, int(controller["control_epoch"]) + 1).is_success, "real control epoch changes")
	step()
	check(state()["construction"]["jobs"]["first"]["state"] == "paused", "losing control pauses work")
	check(not production.apply_local(context, reserve_id, "canister_reserve", reserve_payload, runner.tick_number + 1).is_success, "old-control exact retry cannot bypass current authority")
	canister("resume", "first")
	var serialized: String = world.capture_world_snapshot_json().value
	check(not serialized.is_empty(), "claimed finite stock and world save together")
	var restored := WorldRuntime.new()
	restored.resource_carriers_enabled = true
	root.add_child(restored)
	check(restored.restore_world_snapshot_json(serialized).is_success, "whole-world checkpoint restores")
	var restored_production := restored.get_simulation_system(ProductionSimulationSystem.SYSTEM_ID) as ProductionSimulationSystem
	check(restored_production.capture_snapshot().value["construction"]["jobs"]["first"]["state"] == "paused", "restart pauses unfinished work and keeps claim")
	check(restored_production.capture_snapshot().value["store"] == state()["store"], "restart neither spends nor grants material")
	var broken: Dictionary = JSON.parse_string(serialized)
	broken["systems"]["production"]["store"]["iron"] = 999999
	broken["systems"]["production"]["store"]["tailings"] += 200001
	var rejected := WorldRuntime.new()
	rejected.resource_carriers_enabled = true
	root.add_child(rejected)
	check(not rejected.restore_world_snapshot_json(JSON.stringify(broken)).is_success, "mass-conserving checkpoint cannot underfund a claim")
	rejected.free()
	broken = JSON.parse_string(serialized)
	broken["systems"]["production"]["construction_bindings"]["first"]["body_id"] = "missing-body"
	rejected = WorldRuntime.new()
	rejected.resource_carriers_enabled = true
	root.add_child(rejected)
	check(not rejected.restore_world_snapshot_json(JSON.stringify(broken)).is_success, "cross-owner actor/body mismatch rejects")
	rejected.free()
	world.free()
	world = restored
	check(world.start_simulation().is_success, "restored world starts")
	world.command_completed.connect(func(_command: SimulationCommand, result: ServiceResult) -> void: last = result)
	runner = world.get_node("SimulationRunner")
	runner.set_physics_process(false)
	production = restored_production
	inventory = world.get_simulation_system(InventorySimulationSystem.SYSTEM_ID)
	step(5)
	check(state()["construction"]["jobs"]["first"]["state"] == "paused", "restart cannot reconstruct live authenticated grants")
	canister("resume", "first")
	step(120)
	check(state()["construction"]["jobs"]["first"]["state"] == "ready", "120 validated fixed ticks make work ready")
	check(state()["structures"].is_empty(), "ready proposal is not physical output")
	# Force actual factory preparation failure with an existing physical ID collision.
	var output: String = TimedCanisterConstruction.output_id("first")
	var owner_before: Dictionary = inventory.capture_snapshot().value["owner"]
	var prepared_collision: ServiceResult = inventory.prepare_equipment_change(context, "output-collision", output, true, ProductionSimulationSystem.payload_masses(state()), "item.resource-canister.fabricated")
	check(prepared_collision.is_success, "negative control prepares a valid physical canister collision")
	if not prepared_collision.is_success:
		world.free()
		quit(1)
		return
	var collision: Dictionary = prepared_collision.value
	check(inventory.commit_prepared_owner(collision).is_success, "negative control installs physical output collision")
	var before_failure: Dictionary = state()
	canister("complete", "first", false)
	check(state() == before_failure.merged({"last_tick": runner.tick_number}, true), "failed real output preparation commits no stock, progress, terminal state or receipt")
	check(inventory.capture_snapshot().value["owner"] == collision, "failed output leaves Inventory untouched")
	check(inventory.commit_prepared_owner(owner_before).is_success, "restore collision fixture")
	canister("complete", "first")
	var completion_id: String = "machine-test-%d" % sequence
	var owner: Dictionary = inventory.capture_snapshot().value["owner"]
	check(state()["store"]["iron"] == 200000 and state()["structures"].size() == 1, "one kilogram debited into one canonical shell")
	check(owner["ledger"]["items"].filter(func(item: Dictionary) -> bool: return item["item_id"] == output).size() == 1, "one real canister item committed")
	check(not MachineryWorkshop.container(owner, output).is_empty(), "real canister owns nested cargo container")
	var completion: Dictionary = state()["construction_commands"][completion_id]
	var replay_payload: Dictionary = {"expected_revision": before_failure["state_revision"], "job_id": "first", "expected_reservation_revision": before_failure["construction"]["revision"], "control_epoch": epoch()}
	check(production.apply_local(context, completion_id, "canister_complete", replay_payload, runner.tick_number + 1).is_success, "completion replay succeeds without a second output")
	check(inventory.capture_snapshot().value["owner"] == owner and state()["store"]["iron"] == 200000, "completion replay has zero physical or stock effects")
	check(completion["state_revision"] == state()["state_revision"], "completion receipt identifies committed owner revision")
	check(world.capture_world_snapshot_json().is_success, "completed physical output and provenance save together")
	var completed_save: String = world.capture_world_snapshot_json().value
	var completed_restore := WorldRuntime.new()
	completed_restore.resource_carriers_enabled = true
	root.add_child(completed_restore)
	check(completed_restore.restore_world_snapshot_json(completed_save).is_success, "v2 physical canister and nested container restore together")
	var completed_inventory := completed_restore.get_simulation_system(InventorySimulationSystem.SYSTEM_ID) as InventorySimulationSystem
	check(not MachineryWorkshop.container(completed_inventory.capture_snapshot().value["owner"], output).is_empty(), "restart preserves the actual child container")
	completed_restore.free()
	command("load_cargo", {"carrier_id": output, "material": "iron", "amount_milligrams": 200000})
	check(state()["store"]["iron"] == 0 and production.payload_mass(output) == 1200000, "new canister carries real bulk material with shell counted once")
	check(world.capture_world_snapshot_json().is_success, "loaded v2 canister passes complete cross-owner validation")
	command("unload_cargo", {"carrier_id": output, "material": "iron", "amount_milligrams": 200000})
	command("salvage_equipment", {"item_id": output})
	canister("reserve", "cancelled")
	canister("cancel", "cancelled")
	check(state()["store"]["iron"] == 1200000 and ConstructionReservationPlan.claimed(state()["construction"]) == 0, "salvage and cancellation conserve all finite iron")
	check(world.capture_world_snapshot_json().is_success, "terminal history permits legitimate later salvage")
	command("fabricate_equipment", {"blueprint_id": "equipment.canister"})
	var legacy_id: String = state()["structures"].keys()[0]
	var legacy_item: Dictionary = MachineryWorkshop.item(inventory.capture_snapshot().value["owner"], legacy_id)
	check(int(legacy_item["definition_revision"]) == 1 and MachineryWorkshop.container(inventory.capture_snapshot().value["owner"], legacy_id).is_empty(), "old atomic factory preserves its immutable v1 output")
	world.free()
	print("timed_canister_construction_test: %d failures" % failures)
	quit(1 if failures else 0)


func state() -> Dictionary:
	return production.capture_snapshot().value


func canister_payload(id: String) -> Dictionary:
	return {"job_id": id, "expected_revision": state()["state_revision"], "expected_reservation_revision": state()["construction"]["revision"], "control_epoch": epoch()}


func epoch() -> int:
	return int(inventory.controller_candidate().value["body.human-2"]["control_epoch"])


func canister(operation: String, id: String, success: bool = true) -> void:
	command("canister_" + operation, canister_payload(id), success)
