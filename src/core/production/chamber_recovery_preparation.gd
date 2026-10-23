extends RefCounted
class_name ChamberRecoveryPreparation

## Detached backend only. No player command, scheduler or presentation entry
## point. Real paid candidates, inventory capacities and live admission are used
## by isolated tests and the later command implementation.

static func admit(production: ProductionSimulationSystem, context: AuthenticatedCommandContext, mode: String) -> ServiceResult:
	if production == null or context == null or production._room_pressure == null or production._door_access == null or production._inventory == null: return ChamberRecoveryRecords.denied()
	var state: Dictionary = production.capture_snapshot().value
	if int(state.timebase_hz) != 60 or Engine.physics_ticks_per_second != 60 or not state.powered.get("construction", false) or int(state.state_revision) >= ProductionSimulationSystem.MAX_REVISION: return ChamberRecoveryRecords.denied()
	var inventory: InventorySimulationSystem = production._inventory
	var allowed: ServiceResult = inventory.production_capability(context, true, [0, 0, 0] if mode == "assembly" else [])
	if not allowed.is_success or not inventory.active_tool(context, "tool.crowbar").is_success: return ChamberRecoveryRecords.denied()
	var pressure: ServiceResult = production._room_pressure.capture_snapshot()
	var access: ServiceResult = production._door_access.capture_snapshot()
	if not pressure.is_success or not access.is_success: return ChamberRecoveryRecords.denied()
	if not production._room_pressure.validate_room_links(state, access.value, pressure.value, int(state.last_tick), inventory.capture_snapshot().value).is_success: return ChamberRecoveryRecords.denied()
	var chamber: Dictionary = pressure.value.get("paid_chamber", {})
	if chamber.is_empty() or chamber.principal_id != String(context.principal_id) or chamber.body_id != allowed.value or chamber.world_id != String(context.world_id) or chamber.region_id != String(context.region_id): return ChamberRecoveryRecords.denied()
	for id in [chamber.inner_door_id, chamber.outer_door_id]:
		if pressure.value.room_valves[id] or not PaidChamber.closed_intact(PaidChamber.actuator(access.value, id)): return ChamberRecoveryRecords.denied()
	if mode != "assembly":
		var pose: ServiceResult = inventory.own_position(context)
		if not pose.is_success or SpatialWallConstruction.body_center(pose.value).distance_to(Vector3(5600, 900, -4300)) > InventorySimulationSystem.WORLD_REACH_MILLIMETRES: return ChamberRecoveryRecords.denied()
		var assembly: Dictionary = ChamberRecoveryRecords.current(state.get("chamber_recovery", {}))
		if assembly.is_empty() or assembly.principal_id != chamber.principal_id or assembly.body_id != chamber.body_id or assembly.chamber_id != chamber.volume_id: return ChamberRecoveryRecords.denied()
		var physical: Dictionary = MachineryWorkshop.item(inventory.capture_snapshot().value.owner, assembly.item_id)
		if physical.is_empty() or int(physical.condition_permille) <= 0: return ChamberRecoveryRecords.denied()
		if mode != "mount" and assembly.state != "mounted": return ChamberRecoveryRecords.denied()
	return ServiceResult.success(allowed.value)


static func finish(production: ProductionSimulationSystem, context: AuthenticatedCommandContext, mode: String, state: Dictionary, pressure_record: Dictionary, inventory_record: Dictionary = {}, contexts: Dictionary = {}) -> ServiceResult:
	var decoded: ServiceResult = production.validate_snapshot_record(state, int(state.last_tick))
	if not decoded.is_success: return decoded
	var pressure_decoded: ServiceResult = production._room_pressure.decode_chamber_recovery_candidate(pressure_record, int(state.last_tick))
	if not pressure_decoded.is_success: return pressure_decoded
	var physical: Dictionary = production._inventory.capture_snapshot().value if inventory_record.is_empty() else inventory_record
	if not production.validate_inventory_links(state, physical).is_success: return ChamberRecoveryRecords.denied()
	var access: Dictionary = production._door_access.capture_snapshot().value
	if not production._room_pressure.validate_room_links(state, access, pressure_record, int(state.last_tick), physical).is_success: return ChamberRecoveryRecords.denied()
	var inventory_decoded: ServiceResult = production._inventory.decode_factory_candidate(physical, ProductionSimulationSystem.payload_masses(state))
	if not inventory_decoded.is_success: return inventory_decoded
	var fence: ServiceResult = ChamberRecoveryOwnerFence.capture(production, production._room_pressure, production._inventory, production._door_access)
	if not fence.is_success: return fence
	var prepared := PreparedChamberRecoveryChange.new()
	prepared._fence = fence.value
	prepared._production_after = decoded.value
	prepared._pressure_after = pressure_decoded.value
	prepared._inventory_after = {} if inventory_record.is_empty() else inventory_decoded.value
	prepared._contexts_after = contexts.duplicate()
	prepared._context = context
	prepared._mode = mode
	return ServiceResult.success(prepared)


static func assembly(production: ProductionSimulationSystem, context: AuthenticatedCommandContext, request_id: String) -> ServiceResult:
	var admission: ServiceResult = admit(production, context, "assembly")
	if not admission.is_success or not ControlContractValidation.is_id(request_id): return ChamberRecoveryRecords.denied()
	var state: Dictionary = production.capture_snapshot().value.duplicate(true)
	var recovery: Dictionary = state.get("chamber_recovery", ChamberRecoveryRecords.initial()).duplicate(true)
	if not ChamberRecoveryRecords.current(recovery).is_empty() or recovery.assemblies.size() >= ChamberRecoveryRecords.MAX_ASSEMBLIES or int(state.energy_joules) < 1000 or int(state.store.plate) < 400000 or int(state.store.iron) - ConstructionReservationPlan.claimed(state.construction) < 200000: return ChamberRecoveryRecords.denied()
	var pressure: Dictionary = production._room_pressure.capture_snapshot().value.duplicate(true)
	var chamber: Dictionary = pressure.paid_chamber
	var id: String = "chamber-recovery-assembly-%d" % (recovery.assemblies.size() + 1)
	var item_id: String = "item-%s" % id
	recovery.assemblies.append({"schema_version": 1, "assembly_id": id, "item_id": item_id, "definition_id": ChamberRecoveryRecords.DEFINITION, "definition_revision": 1, "blueprint_id": ChamberRecoveryRecords.BLUEPRINT, "blueprint_fingerprint": ChamberRecoveryRecords.fingerprint(), "materials": ChamberRecoveryRecords.BILL.duplicate(), "principal_id": String(context.principal_id), "body_id": admission.value, "world_id": String(context.world_id), "region_id": String(context.region_id), "chamber_id": chamber.volume_id, "original_condition_permille": 1000, "assembly_spent_joules": 1000, "state": "carried"})
	state.schema_version = 16
	state.chamber_recovery = recovery
	state.store.plate -= 400000
	state.store.iron -= 200000
	state.energy_joules -= 1000
	state.state_revision += 1
	var graph: ServiceResult = production._inventory.prepare_equipment_change(context, request_id, item_id, true, ProductionSimulationSystem.payload_masses(state), ChamberRecoveryRecords.DEFINITION)
	if not graph.is_success: return graph
	var inventory: Dictionary = production._inventory.capture_snapshot().value
	inventory.owner = graph.value
	pressure.schema_version = 6
	pressure.pump_accounting = recovery.accounting.duplicate(true)
	return finish(production, context, "assembly", state, pressure, inventory, production._chamber_recovery_contexts)


static func mount(production: ProductionSimulationSystem, context: AuthenticatedCommandContext, request_id: String) -> ServiceResult:
	var admission: ServiceResult = admit(production, context, "mount")
	if not admission.is_success or not ControlContractValidation.is_id(request_id): return ChamberRecoveryRecords.denied()
	var state: Dictionary = production.capture_snapshot().value.duplicate(true)
	var assembly: Dictionary = ChamberRecoveryRecords.current(state.chamber_recovery)
	if assembly.state != "carried" or not ChamberRecoveryRecords.active_job(state.chamber_recovery).is_empty(): return ChamberRecoveryRecords.denied()
	if not supported(state): return ChamberRecoveryRecords.denied()
	var inventory: Dictionary = production._inventory.capture_snapshot().value
	var owner: Dictionary = inventory.owner.duplicate(true)
	var root: String = ChamberRecoveryRecords.root_id(assembly.assembly_id)
	owner.ledger.containers.append({"container_id": root, "owner_item_id": "", "capacity": ChamberRecoveryRecords.capacity(), "is_open": true})
	for item in owner.ledger.items:
		if item.item_id == assembly.item_id: item.container_id = root
	var locations: Array = inventory.world_storage.duplicate(true)
	locations.append({"container_id": root, "position_millimetres": ChamberRecoveryRecords.ANCHOR.duplicate(), "accessible": false})
	var graph: ServiceResult = production._inventory.prepare_factory_graph(context, owner, locations, request_id, ProductionSimulationSystem.payload_masses(state))
	if not graph.is_success: return graph
	assembly.state = "mounted"
	state.state_revision += 1
	return finish(production, context, "mount", state, production._room_pressure.capture_snapshot().value, graph.value, production._chamber_recovery_contexts)


static func supported(state: Dictionary) -> bool:
	# Reuse the exact union algorithm with the pump's actual support rectangle.
	return PaidDoorGeometry.supported_bounds([5500, 5700, -4450, -4350], state.panels)


static func start(production: ProductionSimulationSystem, context: AuthenticatedCommandContext) -> ServiceResult:
	var admission: ServiceResult = admit(production, context, "start")
	if not admission.is_success: return admission
	var state: Dictionary = production.capture_snapshot().value.duplicate(true)
	var recovery: Dictionary = state.chamber_recovery
	if int(state.last_tick) > ChamberRecoveryRecords.LIMIT - 60: return ChamberRecoveryRecords.denied()
	var pressure: Dictionary = production._room_pressure.capture_snapshot().value.duplicate(true)
	var controller: ServiceResult = production._inventory.controller_candidate()
	if not controller.is_success or not controller.value.has(admission.value): return ChamberRecoveryRecords.denied()
	var previous: Dictionary = ChamberRecoveryRecords.active_job(recovery)
	if not previous.is_empty():
		if previous.state != "paused" or previous.principal_id != String(context.principal_id) or previous.body_id != admission.value: return ChamberRecoveryRecords.denied()
		previous.state = "running"
		previous.control_epoch = int(controller.value[admission.value].control_epoch)
		previous.next_eligible_tick = int(state.last_tick) + 60
		state.state_revision += 1
		var resumed_contexts: Dictionary = production._chamber_recovery_contexts.duplicate()
		resumed_contexts[previous.job_id] = context
		return finish(production, context, "start", state, pressure, {}, resumed_contexts)
	if recovery.jobs.size() >= ChamberRecoveryRecords.MAX_JOBS or int(state.energy_joules) <= 0: return ChamberRecoveryRecords.denied()
	var initial: float = -1.0
	for volume in pressure.volumes:
		if volume.volume_id == pressure.paid_chamber.volume_id: initial = float(volume.gas_moles)
	if not is_finite(initial) or initial <= 0.0: return ChamberRecoveryRecords.denied()
	var assembly: Dictionary = ChamberRecoveryRecords.current(recovery)
	var id: String = "chamber-recovery-job-%d" % (recovery.jobs.size() + 1)
	var job: Dictionary = {"schema_version": 1, "job_id": id, "assembly_id": assembly.assembly_id, "principal_id": String(context.principal_id), "body_id": admission.value, "control_epoch": int(controller.value[admission.value].control_epoch), "initial_moles": initial, "target_moles": initial * 0.2, "returned_moles": 0.0, "spent_joules": 0, "max_joules": mini(25000, int(state.energy_joules)), "state": "running", "last_batch_tick": 0, "next_eligible_tick": int(state.last_tick) + 60}
	recovery.jobs.append(job)
	recovery.accounting.jobs.append(ChamberRecoveryRecords.summary(job))
	pressure.pump_accounting = recovery.accounting.duplicate(true)
	state.state_revision += 1
	var contexts: Dictionary = production._chamber_recovery_contexts.duplicate()
	contexts[id] = context
	return finish(production, context, "start", state, pressure, {}, contexts)


static func step(production: ProductionSimulationSystem, tick: int) -> ServiceResult:
	var state: Dictionary = production.capture_snapshot().value.duplicate(true)
	var job: Dictionary = ChamberRecoveryRecords.active_job(state.get("chamber_recovery", {}))
	if job.is_empty() or job.state != "running" or tick != int(state.last_tick) or tick < int(job.next_eligible_tick) or tick > ChamberRecoveryRecords.LIMIT - 60: return ChamberRecoveryRecords.denied()
	var context: AuthenticatedCommandContext = production._chamber_recovery_contexts.get(job.job_id)
	var admission: ServiceResult = admit(production, context, "step")
	if not admission.is_success: return admission
	var control: ServiceResult = production._inventory.controller_candidate()
	if not control.is_success or not control.value.has(job.body_id) or int(control.value[job.body_id].control_epoch) != int(job.control_epoch): return ChamberRecoveryRecords.denied()
	var quantity: float = minf(0.1, float(job.target_moles) - float(job.returned_moles))
	var transfer: ServiceResult = production._room_pressure.prepare_chamber_recovery_transfer(job.assembly_id, job.job_id, quantity, tick)
	if not transfer.is_success: return transfer
	var charged: int = int(transfer.value.charged_joules)
	if int(state.energy_joules) < charged or int(job.spent_joules) + charged > int(job.max_joules): return ChamberRecoveryRecords.denied()
	job.returned_moles += quantity
	job.spent_joules += charged
	job.last_batch_tick = tick
	job.next_eligible_tick = tick + 60
	if float(job.returned_moles) == float(job.target_moles): job.state = "completed"
	var audit: Dictionary = state.chamber_recovery.accounting
	if int(audit.sequence) >= ChamberRecoveryRecords.LIMIT: return ChamberRecoveryRecords.denied()
	audit.sequence += 1
	audit.last_assembly_id = job.assembly_id
	audit.last_job_id = job.job_id
	audit.last_batch_tick = tick
	audit.last_quantity_moles = quantity
	audit.last_charged_joules = charged
	audit.jobs.clear()
	audit.returned_moles = 0.0
	audit.paid_joules = 0
	for retained in state.chamber_recovery.jobs:
		audit.jobs.append(ChamberRecoveryRecords.summary(retained))
		audit.returned_moles += float(retained.returned_moles)
		audit.paid_joules += int(retained.spent_joules)
	state.energy_joules -= charged
	state.state_revision += 1
	var pressure: Dictionary = transfer.value.after
	pressure.pump_accounting = audit.duplicate(true)
	return finish(production, context, "step", state, pressure, {}, production._chamber_recovery_contexts)
