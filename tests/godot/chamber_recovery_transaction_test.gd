extends "res://tests/godot/paid_chamber_test.gd"


## Positive provenance comes entirely from the existing 39kg acquisition route
## and real detached Inventory/Production candidates. Direct owner mutations
## below are isolated rejection controls, never positive factory shortcuts.
func verify_chamber_extension() -> void:
	move([3600, 0, -5500]); move([0, 0, 0])
	var prepared: ServiceResult = production.prepare_chamber_recovery_assembly(context, "paid-recovery-assembly")
	check(prepared.is_success, "authentic leftovers prepare paid physical pump in actual body capacity")
	if not prepared.is_success: return
	check(prepared.value.commit(production, pressure_owner(), inventory, access).is_success, "publish paid assembly with real Inventory")
	var paid: Dictionary = production.capture_snapshot().value
	check(paid.energy_joules == 27250 and paid.store.plate == 200000 and paid.store.iron == 200000, "exact 600g bill and 1000J debit without new resources")
	var assembly: Dictionary = ChamberRecoveryRecords.current(paid.chamber_recovery)
	check(production.payload_mass(assembly.item_id) == 600000 and ProductionSimulationSystem.payload_masses(paid)[assembly.item_id] == 600000, "both mass providers count pump provenance once")
	check(MachineryWorkshop.item(inventory.capture_snapshot().value.owner, assembly.item_id).container_id == "body.human-1", "paid assembly first occupies actual body inventory")
	var before_drop: Dictionary = inventory.capture_snapshot().value.duplicate(true)
	var dropped: ServiceResult = inventory.apply_local(context, "generic-pump-drop", "world", {"operation": "drop", "item_id": assembly.item_id, "world_container_id": "world.tray-1", "destination_container_id": "", "slot_id": "", "expected_revision": before_drop.owner.state_revision}, int(before_drop.last_tick) + 1)
	check(not dropped.is_success and inventory.capture_snapshot().value == before_drop, "generic world movement cannot detach paid pump ownership or consume a receipt")
	move([3600, 0, -5500]); move([5600, 0, -5000])
	prepared = production.prepare_chamber_recovery_mount(context, "paid-recovery-mount")
	check(prepared.is_success, "same paid item prepares a supported fixed mount")
	if not prepared.is_success: return
	check(prepared.value.commit(production, pressure_owner(), inventory, access).is_success, "mount candidate commits without replacing item or condition")
	var mounted_inventory: Dictionary = inventory.capture_snapshot().value.duplicate(true)
	var picked_up: ServiceResult = inventory.apply_local(context, "generic-pump-pickup", "world", {"operation": "pickup", "item_id": assembly.item_id, "world_container_id": ChamberRecoveryRecords.root_id(assembly.assembly_id), "destination_container_id": "body.human-1", "slot_id": "", "expected_revision": mounted_inventory.owner.state_revision}, int(mounted_inventory.last_tick) + 1)
	check(not picked_up.is_success and inventory.capture_snapshot().value == mounted_inventory, "mounted item cannot escape through generic pickup")
	prepared = production.prepare_chamber_recovery_job(context)
	check(prepared.is_success, "server derives immutable twenty-percent target and finite job cap")
	if not prepared.is_success: return
	check(prepared.value.commit(production, pressure_owner(), inventory, access).is_success, "publish reciprocal job admission")
	var job: Dictionary = ChamberRecoveryRecords.active_job(production.capture_snapshot().value.chamber_recovery)
	check(job.max_joules == 25000 and job.spent_joules == 0 and job.returned_moles == 0.0 and job.target_moles == job.initial_moles * 0.2, "client supplies no budget or target")
	var baseline: String = world.capture_world_snapshot_json().value
	var fixture := FileAccess.open("res://var/chamber-recovery-fixture.json", FileAccess.WRITE)
	fixture.store_string(baseline); fixture.close()
	for mutation in ["none", "bank", "claims", "gas", "valve", "door", "action_epoch", "control_epoch", "pose", "condition", "production_restore", "pressure_restore", "inventory_restore", "access_restore", "failed_restores"]:
		transaction_case(baseline, mutation)
	for corruption in ["production_only", "pressure_only", "paid_sum", "material_bill", "missing_item", "wrong_root", "unpaid_bank", "future_production", "future_pressure"]:
		restore_case(baseline, corruption)
	for blocker in ["empty_bank", "job_cap", "timebase", "support", "retired_control"]:
		blocked_preparation_case(baseline, blocker)


func owner_records(owners: Array) -> Array:
	var result: Array = []
	for owner in owners: result.append(owner.capture_snapshot().value.duplicate(true))
	return result


func transaction_case(baseline: String, mutation: String) -> void:
	var target: WorldRuntime = FirstPlayableBootstrap.create_playable_world()
	root.add_child(target)
	var restored: ServiceResult = target.restore_world_snapshot_json(baseline)
	check(restored.is_success, "reciprocal paid world restores: " + mutation)
	if not restored.is_success: target.free(); return
	check(target.start_simulation().is_success, "restored finite world starts")
	var clock: SimulationRunner = target.get_node("SimulationRunner")
	clock.set_physics_process(false)
	var p: ProductionSimulationSystem = target.get_simulation_system(ProductionSimulationSystem.SYSTEM_ID)
	var g: PressureSystem = target.get_simulation_system(PressureSystem.SYSTEM_ID)
	var i: InventorySimulationSystem = target.get_simulation_system(InventorySimulationSystem.SYSTEM_ID)
	var a: AccessControlSystem = target.get_simulation_system(AccessControlSystem.SYSTEM_ID)
	var actor := AuthenticatedCommandContext.for_local_development(context.principal_id, target.world_id, target.region_id)
	var owners: Array = [p, g, i, a]
	var paused: Dictionary = ChamberRecoveryRecords.active_job(p.capture_snapshot().value.chamber_recovery)
	check(paused.state == "paused", "reload parks running job without debit")
	var resume: ServiceResult = p.prepare_chamber_recovery_job(actor)
	check(resume.is_success, "fresh authority resumes original budget and target")
	if not resume.is_success: target.free(); return
	check(resume.value.commit(p, g, i, a).is_success, "resume reciprocal candidates")
	var ineligible: Array = owner_records(owners)
	check(not p.prepare_chamber_recovery_step(clock.tick_number).is_success and owner_records(owners) == ineligible, "resume cannot bypass sixty-tick eligibility")
	for tick in range(60): clock._physics_process(1.0 / 60.0)
	var step_candidate: ServiceResult = p.prepare_chamber_recovery_step(clock.tick_number)
	check(step_candidate.is_success, "eligible real-owner batch prepares: " + mutation)
	if not step_candidate.is_success: target.free(); return
	var valid_before: Array = owner_records(owners)
	var initial_job: Dictionary = ChamberRecoveryRecords.active_job(valid_before[0].chamber_recovery)
	var chamber_id := StringName(g.paid_chamber.volume_id)
	var price: ServiceResult = ChamberRecoveryWork.prepare(g.volumes[chamber_id], g.volumes[PressureSystem.PROTOTYPE_HABITAT_ID], minf(0.1, initial_job.target_moles - initial_job.returned_moles))
	var source_before: float = (g.volumes[chamber_id] as PressureVolumeState).gas_moles
	var receiver_before: float = (g.volumes[PressureSystem.PROTOTYPE_HABITAT_ID] as PressureVolumeState).gas_moles
	match mutation:
		"bank": p._state.energy_joules -= 1
		"claims": p._state.construction["fence-negative"] = {"claim": 1}
		"gas": (g.volumes[chamber_id] as PressureVolumeState).gas_moles -= 0.01
		"valve": g.room_valves[g.paid_chamber.inner_door_id] = true
		"door": a.devices[StringName(g.paid_chamber.inner_door_id)].actuator(PaidDoorConstruction.actuator_id(g.paid_chamber.inner_door_id)).position = 1.0
		"action_epoch": i._bodies[initial_job.body_id].action_epoch += 1
		"control_epoch": i._bodies[initial_job.body_id].control_epoch += 1
		"pose": i._bodies[initial_job.body_id].position_millimetres[0] += 1
		"condition":
			var inventory_record: Dictionary = i.capture_snapshot().value
			for item in inventory_record.owner.ledger.items:
				if item.item_id == ChamberRecoveryRecords.current(p._state.chamber_recovery).item_id: item.condition_permille -= 1
			check(i.restore_snapshot_record(inventory_record, clock.tick_number).is_success, "real Inventory accepts lower retained item condition")
		"production_restore": check(p.restore_snapshot_record(valid_before[0], clock.tick_number).is_success, "same Production restore retires preparation")
		"pressure_restore": check(g.restore_snapshot_record(valid_before[1], clock.tick_number).is_success, "identical Pressure restore retires preparation")
		"inventory_restore": check(i.restore_snapshot_record(valid_before[2], clock.tick_number).is_success, "identical Inventory restore retires preparation")
		"access_restore": check(a.restore_snapshot_record(valid_before[3], clock.tick_number).is_success, "identical Access restore retires preparation")
		"failed_restores":
			for index in range(owners.size()):
				var invalid: Dictionary = valid_before[index].duplicate(true)
				invalid.schema_version = 999
				check(not owners[index].restore_snapshot_record(invalid, clock.tick_number).is_success, "failed restore rejects before any owner write or fence increment")
	var before_commit: Array = owner_records(owners)
	var committed: ServiceResult = step_candidate.value.commit(p, g, i, a)
	var success_expected: bool = mutation in ["none", "failed_restores"]
	check(committed.is_success == success_expected, "publication accepts only unchanged owners: " + mutation)
	var after: Array = owner_records(owners)
	if success_expected:
		check(int(after[0].energy_joules) == int(before_commit[0].energy_joules) - int(price.value.charged_joules), "real bank charged computed work exactly once")
		check(after[0].chamber_recovery.accounting == after[1].pump_accounting and after[0].chamber_recovery.accounting.sequence == 1, "identical reciprocal audit published once")
		check(after[2] == before_commit[2] and after[3] == before_commit[3], "gas batch leaves Inventory and Access unchanged")
		var source_after: float = (g.volumes[chamber_id] as PressureVolumeState).gas_moles
		var receiver_after: float = (g.volumes[PressureSystem.PROTOTYPE_HABITAT_ID] as PressureVolumeState).gas_moles
		check(absf(source_before - source_after - 0.1) < 1e-10 and absf(receiver_after - receiver_before - 0.1) < 1e-10, "real owners transfer precisely the admitted quantity")
		check(absf(source_after + receiver_after - source_before - receiver_before) < 1e-8, "real-owner publication conserves total bulk moles")
	else: check(after == before_commit, "rejection leaves every owner and normal receipt unchanged: " + mutation)
	check(not step_candidate.value.commit(p, g, i, a).is_success and owner_records(owners) == after, "successful and rejected prepared objects are single-use: " + mutation)
	target.free()


func restore_case(baseline: String, corruption: String) -> void:
	var target: WorldRuntime = FirstPlayableBootstrap.create_playable_world()
	root.add_child(target)
	var before: String = target.capture_world_snapshot_json().value
	var record: Dictionary = JSON.parse_string(baseline)
	var p: Dictionary = record.systems.production
	var g: Dictionary = record.systems.pressure
	match corruption:
		"production_only": g.erase("pump_accounting"); g.schema_version = 5
		"pressure_only": p.erase("chamber_recovery"); p.schema_version = 15
		"paid_sum": g.pump_accounting.paid_joules += 1
		"material_bill": p.chamber_recovery.assemblies[0].materials.iron += 1
		"missing_item": record.systems.inventory.owner.ledger.items = record.systems.inventory.owner.ledger.items.filter(func(item: Dictionary) -> bool: return item.definition_id != ChamberRecoveryRecords.DEFINITION)
		"wrong_root":
			for location in record.systems.inventory.world_storage:
				if String(location.container_id).begins_with("world.chamber-pump-"): location.position_millimetres[0] += 1
		"unpaid_bank": p.energy_joules = 100000
		"future_production": p.schema_version = 17
		"future_pressure": g.schema_version = 7
	check(not target.restore_world_snapshot_json(JSON.stringify(record)).is_success, "forged/one-sided candidate rejected: " + corruption)
	check(target.capture_world_snapshot_json().value == before, "rejected whole-world restore changes no owner: " + corruption)
	target.free()


## Negative-only owner substitutions isolate admission/budget branches. They do
## not provide successful route provenance or create a production fault hook.
func blocked_preparation_case(baseline: String, blocker: String) -> void:
	var target: WorldRuntime = FirstPlayableBootstrap.create_playable_world()
	root.add_child(target)
	var restored: ServiceResult = target.restore_world_snapshot_json(baseline)
	check(restored.is_success, "blocked preparation starts from genuine paid snapshot")
	if not restored.is_success: target.free(); return
	check(target.start_simulation().is_success, "blocked preparation world starts")
	var clock: SimulationRunner = target.get_node("SimulationRunner")
	clock.set_physics_process(false)
	var p: ProductionSimulationSystem = target.get_simulation_system(ProductionSimulationSystem.SYSTEM_ID)
	var g: PressureSystem = target.get_simulation_system(PressureSystem.SYSTEM_ID)
	var i: InventorySimulationSystem = target.get_simulation_system(InventorySimulationSystem.SYSTEM_ID)
	var a: AccessControlSystem = target.get_simulation_system(AccessControlSystem.SYSTEM_ID)
	var actor := AuthenticatedCommandContext.for_local_development(context.principal_id, target.world_id, target.region_id)
	var resume: ServiceResult = p.prepare_chamber_recovery_job(actor)
	check(resume.is_success, "blocked case resumes existing job")
	if not resume.is_success: target.free(); return
	check(resume.value.commit(p, g, i, a).is_success, "blocked case retains original target and cap")
	for tick in range(60): clock._physics_process(1.0 / 60.0)
	var job: Dictionary = ChamberRecoveryRecords.active_job(p._state.chamber_recovery)
	match blocker:
		"empty_bank": p._state.energy_joules = 0
		"job_cap": job.max_joules = 1
		"timebase": p._state.timebase_hz = 72
		"support": p._state.panels.clear()
		"retired_control": i._bodies[job.body_id].control_epoch += 1
	var owners: Array = [p, g, i, a]
	var before: Array = owner_records(owners)
	check(not p.prepare_chamber_recovery_step(clock.tick_number).is_success, "ineligible backend batch rejects: " + blocker)
	check(owner_records(owners) == before, "budget/admission stall changes no owner or normal receipt: " + blocker)
	target.free()
