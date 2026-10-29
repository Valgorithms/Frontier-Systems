extends "res://tests/godot/paid_chamber_test.gd"


func run() -> void:
	pinned_catalog_controls()
	if failures: finish(); return
	await super.run()


func pinned_catalog_controls() -> void:
	var definition: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/inventory/chamber-recovery-pump.v1.json"))
	var blueprint: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/production/chamber-recovery-pump.v1.json"))
	check(ChamberRecoveryRecords.matches_definition(definition) and ChamberRecoveryRecords.matches_definition(ChamberRecoveryRecords.definition()), "JSON and literal pump definitions both admit exact numeric values")
	check(ChamberRecoveryRecords.matches_blueprint(blueprint) and ChamberRecoveryRecords.matches_blueprint(ChamberRecoveryRecords.blueprint()), "JSON and literal bills both admit exact nested numeric values")
	for field in ["schema_version", "revision", "mass_milligrams", "volume_millilitres"]:
		for wrong in [float(definition[field]) + 0.25, float(definition[field]) + 1.0, str(definition[field]), true, null, INF, NAN]:
			var changed: Dictionary = definition.duplicate(true)
			changed[field] = wrong
			check(not ChamberRecoveryRecords.matches_definition(changed), "definition rejects changed or non-integral pinned quantity: " + field)
	for field in ["plate", "iron"]:
		for wrong in [float(blueprint.materials_milligrams[field]) + 0.25, 0, "400000", true, null]:
			var changed: Dictionary = blueprint.duplicate(true)
			changed.materials_milligrams[field] = wrong
			check(not ChamberRecoveryRecords.matches_blueprint(changed), "bill rejects changed or non-integral nested quantity: " + field)
	var extra: Dictionary = definition.duplicate(true); extra["unsupported"] = 1
	var missing: Dictionary = blueprint.duplicate(true); missing.erase("assembly_joules")
	var tags: Dictionary = definition.duplicate(true); tags.tags.reverse()
	check(not ChamberRecoveryRecords.matches_definition(extra) and not ChamberRecoveryRecords.matches_blueprint(missing) and not ChamberRecoveryRecords.matches_definition(tags), "pinned fields and ordered tags remain exact")
	check(not ChamberRecoveryRecords.matches_definition(null) and not ChamberRecoveryRecords.matches_blueprint([]), "malformed catalog shapes reject")
	for carriers in [false, true]:
		var fresh_inventory := InventorySimulationSystem.new()
		var configured: ServiceResult = fresh_inventory.configure_defaults(carriers)
		check(configured.is_success, "actual catalog creates canonical Inventory for both commissioning fixtures")
		if configured.is_success:
			check(fresh_inventory.capture_snapshot().is_success, "real configured Inventory owner captures before dependent Tools configure")
			var fresh_tools := ToolSimulationSystem.new()
			check(fresh_tools.configure(fresh_inventory).is_success, "dependent Tools initialize from real Inventory without reordered or fabricated owners")
			fresh_tools.free()
		fresh_inventory.free()


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
	# The inherited transit/cycle route ends vented. Retain that real state as
	# a work-limit negative, then refill only through the paid inner bypass.
	# Do this while carried: mounted world roots intentionally remain unsupported
	# by the legacy door swing classifier until the later physical device phase.
	var gas_owner: PressureSystem = pressure_owner()
	var chamber_id := StringName(gas_owner.paid_chamber.volume_id)
	var vented_owners: Array = owner_records([production, gas_owner, inventory, access])
	var vented: ServiceResult = ChamberRecoveryWork.prepare(gas_owner.volumes[chamber_id], gas_owner.volumes[PressureSystem.PROTOTYPE_HABITAT_ID], 0.1)
	check(not vented.is_success and vented.error_code == &"chamber_recovery_work_rejected", "authentic vented chamber rejects compression outside physical limits")
	check(owner_records([production, gas_owner, inventory, access]) == vented_owners, "vented work rejection changes no owner")
	var moles_before_refill: float = all_moles()
	var habitat_before_refill: float = gas_owner.volumes[PressureSystem.PROTOTYPE_HABITAT_ID].gas_moles
	door_id = inner_id; chamber_ui(9); step(600); chamber_ui(10)
	check(gas_conserved(moles_before_refill) and gas_owner.volumes[PressureSystem.PROTOTYPE_HABITAT_ID].gas_moles < habitat_before_refill, "real inner bypass refills chamber from finite habitat gas without creating moles")
	var refilled: ServiceResult = ChamberRecoveryWork.prepare(gas_owner.volumes[chamber_id], gas_owner.volumes[PressureSystem.PROTOTYPE_HABITAT_ID], 0.1)
	check(refilled.is_success, "authentic refilled chamber supports bounded compression: " + diagnostic(refilled))
	if failures: return
	var before_mount: Dictionary = inventory.capture_snapshot().value
	check(ChamberRecoveryPreparation.admit(production, context, "mount").is_success, "actual paid-route actor pose, reach, tool and chamber authority admit mounting")
	check(ChamberRecoveryPreparation.supported(production.capture_snapshot().value), "unchanged paid panels cover the exact mount support rectangle")
	if failures: return
	prepared = production.prepare_chamber_recovery_mount(context, "paid-recovery-mount")
	check(prepared.is_success, "same paid item prepares a supported fixed mount: " + prepared.message)
	if not prepared.is_success: return
	check(prepared.value.commit(production, pressure_owner(), inventory, access).is_success, "mount candidate commits without replacing item or condition")
	var mounted_inventory: Dictionary = inventory.capture_snapshot().value.duplicate(true)
	check(mounted_inventory.owner.ledger.schema_version == before_mount.owner.ledger.schema_version, "mount preserves the real ledger version and existing closure contract")
	for container in mounted_inventory.owner.ledger.containers:
		if container.container_id == ChamberRecoveryRecords.root_id(assembly.assembly_id):
			check(container.has("is_open") == (int(before_mount.owner.ledger.schema_version) == 2) and container.get("is_open", true) == true, "mounted root uses the current ledger's exact open-root shape")
	var mounted_item: Dictionary = MachineryWorkshop.item(mounted_inventory.owner, assembly.item_id)
	var original_item: Dictionary = MachineryWorkshop.item(before_mount.owner, assembly.item_id).duplicate(true)
	original_item.container_id = ChamberRecoveryRecords.root_id(assembly.assembly_id)
	check(mounted_item == original_item, "mount changes only location of the original paid physical item")
	pinned_restore_controls(production.capture_snapshot().value, mounted_inventory, "mounted")
	var picked_up: ServiceResult = inventory.apply_local(context, "generic-pump-pickup", "world", {"operation": "pickup", "item_id": assembly.item_id, "world_container_id": ChamberRecoveryRecords.root_id(assembly.assembly_id), "destination_container_id": "body.human-1", "slot_id": "", "expected_revision": mounted_inventory.owner.state_revision}, int(mounted_inventory.last_tick) + 1)
	check(not picked_up.is_success and inventory.capture_snapshot().value == mounted_inventory, "mounted item cannot escape through generic pickup")
	var mounted_snapshot: String = world.capture_world_snapshot_json().value
	for condition in [999, 1, 0]: damaged_admission_case(mounted_snapshot, "start", condition)
	prepared = production.prepare_chamber_recovery_job(context)
	check(prepared.is_success, "server derives immutable twenty-percent target and finite job cap")
	if not prepared.is_success: return
	check(prepared.value.commit(production, pressure_owner(), inventory, access).is_success, "publish reciprocal job admission")
	var job: Dictionary = ChamberRecoveryRecords.active_job(production.capture_snapshot().value.chamber_recovery)
	check(job.max_joules == 25000 and job.spent_joules == 0 and job.returned_moles == 0.0 and job.target_moles == job.initial_moles * 0.2, "client supplies no budget or target")
	pinned_restore_controls(production.capture_snapshot().value, inventory.capture_snapshot().value, "admitted")
	var baseline: String = world.capture_world_snapshot_json().value
	var fixture := FileAccess.open("res://var/chamber-recovery-fixture.json", FileAccess.WRITE)
	fixture.store_string(baseline); fixture.close()
	for condition in [999, 1, 0]:
		damaged_admission_case(baseline, "resume", condition)
		damaged_admission_case(baseline, "step", condition)
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
	var step_candidate: ServiceResult = eligible_step(p, g, i, a, actor, clock, mutation)
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
	if mutation == "none" and committed.is_success: charged_reload_case(target, after)
	target.free()


func charged_reload_case(charged_world: WorldRuntime, charged: Array) -> void:
	pinned_restore_controls(charged[0], charged[2], "charged")
	var saved: ServiceResult = charged_world.capture_world_snapshot_json()
	check(saved.is_success, "whole-world capture accepts genuinely charged reciprocal batch")
	if not saved.is_success: return
	var target: WorldRuntime = FirstPlayableBootstrap.create_playable_world()
	root.add_child(target)
	var restored: ServiceResult = target.restore_world_snapshot_json(saved.value)
	check(restored.is_success, "whole-world reload accepts genuinely charged batch")
	if not restored.is_success: target.free(); return
	var p: ProductionSimulationSystem = target.get_simulation_system(ProductionSimulationSystem.SYSTEM_ID)
	var g: PressureSystem = target.get_simulation_system(PressureSystem.SYSTEM_ID)
	var i: InventorySimulationSystem = target.get_simulation_system(InventorySimulationSystem.SYSTEM_ID)
	var a: AccessControlSystem = target.get_simulation_system(AccessControlSystem.SYSTEM_ID)
	var owners: Array = [p, g, i, a]
	var expected: Array = charged.duplicate(true)
	var original_job: Dictionary = ChamberRecoveryRecords.active_job(charged[0].chamber_recovery)
	var expected_job: Dictionary = ChamberRecoveryRecords.active_job(expected[0].chamber_recovery)
	expected_job.state = "paused"
	expected[0].state_revision += 1
	# Compare complete JSON values after the same lossless JSON numeric decode;
	# each owner may normalize its own integral runtime fields independently.
	check(json_values(owner_records(owners)) == json_values(expected), "charged reload changes only running-to-paused state and its Production revision; gas, J, audit and physical identity persist")
	var parked: Dictionary = ChamberRecoveryRecords.active_job(p.capture_snapshot().value.chamber_recovery)
	check(parked.spent_joules > 0 and parked.returned_moles == 0.1 and p.capture_snapshot().value.energy_joules < 27250, "charged finite budget and returned quantity survive reload")
	check(p.capture_snapshot().value.chamber_recovery.accounting == g.capture_snapshot().value.pump_accounting, "charged reciprocal audit remains identical after load")
	for volume in g.volumes.values(): check(is_finite(volume.gas_moles) and volume.gas_moles >= 0.0, "reloaded gas remains finite and nonnegative")
	check(target.start_simulation().is_success, "charged restored world starts")
	var clock: SimulationRunner = target.get_node("SimulationRunner")
	clock.set_physics_process(false)
	var before_resume: Array = owner_records(owners)
	check(not p.prepare_chamber_recovery_step(clock.tick_number).is_success and owner_records(owners) == before_resume, "charged reload cannot run before fresh resume")
	var actor := AuthenticatedCommandContext.for_local_development(context.principal_id, target.world_id, target.region_id)
	var resumed: ServiceResult = p.prepare_chamber_recovery_job(actor)
	check(resumed.is_success, "fresh authority can resume a charged job")
	if not resumed.is_success: target.free(); return
	check(resumed.value.commit(p, g, i, a).is_success, "charged job resume publishes without a new cap or debit")
	var continued: Dictionary = ChamberRecoveryRecords.active_job(p.capture_snapshot().value.chamber_recovery)
	for field in ["job_id", "assembly_id", "initial_moles", "target_moles", "max_joules", "spent_joules", "returned_moles", "last_batch_tick"]:
		check(continued[field] == original_job[field], "charged resume retains immutable identity/accounting: " + field)
	check(continued.next_eligible_tick == clock.tick_number + 60, "charged resume starts a fresh sixty-tick interval")
	for tick in range(59): clock._physics_process(1.0 / 60.0)
	var too_soon: Array = owner_records(owners)
	check(not p.prepare_chamber_recovery_step(clock.tick_number).is_success and owner_records(owners) == too_soon, "charged reload cannot catch up before sixty fresh ticks")
	clock._physics_process(1.0 / 60.0)
	check(p.prepare_chamber_recovery_step(clock.tick_number).is_success, "charged resumed job becomes eligible after exactly sixty fresh ticks")
	target.free()


func json_values(value: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(value, "", true, true))


func wrong_pinned_quantities(expected: Variant) -> Array:
	return [float(expected) + 0.25, float(expected) + 1.0, str(expected), true, null, INF, NAN]


## Detached validation controls copied only from the real paid/mounted/charged
## route. They grant no resources, items or initialized owner fixtures.
func pinned_restore_controls(state: Dictionary, physical: Dictionary, stage: String) -> void:
	var decoded: Dictionary = json_values(state)
	var inventory_record: Dictionary = json_values(physical)
	var bank: int = int(decoded.energy_joules)
	var tick: int = int(decoded.last_tick)
	check(ChamberRecoveryRecords.valid(decoded.chamber_recovery, bank, tick), "complete recovery JSON roundtrip preserves exact bill/accounting: " + stage)
	check(ChamberRecoveryRecords.inventory_links(decoded, inventory_record), "real mounted identity, capacity and anchor survive JSON roundtrip: " + stage)
	for field in ["plate", "iron"]:
		for wrong in wrong_pinned_quantities(decoded.chamber_recovery.assemblies[0].materials[field]):
			var changed: Dictionary = decoded.chamber_recovery.duplicate(true)
			changed.assemblies[0].materials[field] = wrong
			check(not ChamberRecoveryRecords.valid(changed, bank, tick), "restore rejects altered/fractional/wrong-type paid bill: " + field)
	for shape in [[], {"plate": 400000}, {"plate": 400000, "iron": 200000, "extra": 0}]:
		var changed: Dictionary = decoded.chamber_recovery.duplicate(true)
		changed.assemblies[0].materials = shape
		check(not ChamberRecoveryRecords.valid(changed, bank, tick), "restore rejects wrong bill shape")
	var assembly: Dictionary = ChamberRecoveryRecords.current(decoded.chamber_recovery)
	for container in inventory_record.owner.ledger.containers:
		if container.container_id != ChamberRecoveryRecords.root_id(assembly.assembly_id): continue
		for field in ["max_mass_milligrams", "max_volume_millilitres", "max_items"]:
			for wrong in wrong_pinned_quantities(container.capacity[field]):
				var original: Variant = container.capacity[field]
				container.capacity[field] = wrong
				check(not ChamberRecoveryRecords.inventory_links(decoded, inventory_record), "restore rejects changed/fractional/wrong-type mount capacity: " + field)
				container.capacity[field] = original
		var capacity: Dictionary = container.capacity.duplicate(true)
		for shape in [[], {}, {"max_mass_milligrams": 600000, "max_volume_millilitres": 6000, "max_items": 1, "accepted_tags": ["wrong"]}, capacity.merged({"extra": 0})]:
			container.capacity = shape
			check(not ChamberRecoveryRecords.inventory_links(decoded, inventory_record), "restore rejects wrong capacity shape/tags")
		container.capacity = capacity
	for location in inventory_record.world_storage:
		if location.container_id != ChamberRecoveryRecords.root_id(assembly.assembly_id): continue
		var position: Array = location.position_millimetres.duplicate()
		for index in range(3):
			for wrong in wrong_pinned_quantities(position[index]):
				location.position_millimetres[index] = wrong
				check(not ChamberRecoveryRecords.inventory_links(decoded, inventory_record), "restore rejects changed/fractional/wrong-type anchor coordinate")
				location.position_millimetres[index] = position[index]
		for shape in [[], [5600, 0], [5600, 0, -4400, 0], {"x": 5600, "y": 0, "z": -4400}]:
			location.position_millimetres = shape
			check(not ChamberRecoveryRecords.inventory_links(decoded, inventory_record), "restore rejects wrong anchor shape")
		location.position_millimetres = position
	if decoded.chamber_recovery.jobs.is_empty(): return
	var job: Dictionary = decoded.chamber_recovery.jobs[0]
	job.spent_joules = int(job.spent_joules)
	check(ChamberRecoveryRecords.valid(decoded.chamber_recovery, bank, tick), "validated float audit matches integral job spend exactly")
	job.spent_joules = float(job.spent_joules)
	decoded.chamber_recovery.accounting.jobs[0].paid_joules = int(job.spent_joules)
	if float(job.returned_moles) == 0.0: decoded.chamber_recovery.accounting.jobs[0].returned_moles = 0
	check(ChamberRecoveryRecords.valid(decoded.chamber_recovery, bank, tick), "validated integer audit quantities match decoded job numbers exactly")
	for field in ["paid_joules", "returned_moles"]:
		for wrong in wrong_pinned_quantities(decoded.chamber_recovery.accounting.jobs[0][field]):
			var changed: Dictionary = decoded.chamber_recovery.duplicate(true)
			changed.accounting.jobs[0][field] = wrong
			# Preserve the corresponding aggregate so an otherwise valid changed
			# quantity must still agree with the immutable job's own summary.
			if typeof(wrong) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(wrong)): changed.accounting[field] = wrong
			check(not ChamberRecoveryRecords.valid(changed, bank, tick), "summary rejects changed or wrong-type numeric accounting: " + field)
	var extra: Dictionary = decoded.chamber_recovery.duplicate(true)
	extra.accounting.jobs[0]["extra"] = 0
	check(not ChamberRecoveryRecords.valid(extra, bank, tick), "summary shape remains exact")


## Damage is installed through the real Inventory restore before preparing any
## start/resume/step. This exercises admission independently of stale-CAS tests.
func damaged_admission_case(baseline: String, stage: String, condition: int) -> void:
	var target: WorldRuntime = FirstPlayableBootstrap.create_playable_world()
	root.add_child(target)
	var restored: ServiceResult = target.restore_world_snapshot_json(baseline)
	check(restored.is_success, "damage control restores authentic paid provenance")
	if not restored.is_success: target.free(); return
	check(target.start_simulation().is_success, "damage admission world starts")
	var clock: SimulationRunner = target.get_node("SimulationRunner")
	clock.set_physics_process(false)
	var p: ProductionSimulationSystem = target.get_simulation_system(ProductionSimulationSystem.SYSTEM_ID)
	var g: PressureSystem = target.get_simulation_system(PressureSystem.SYSTEM_ID)
	var i: InventorySimulationSystem = target.get_simulation_system(InventorySimulationSystem.SYSTEM_ID)
	var a: AccessControlSystem = target.get_simulation_system(AccessControlSystem.SYSTEM_ID)
	var actor := AuthenticatedCommandContext.for_local_development(context.principal_id, target.world_id, target.region_id)
	if stage == "step":
		var resumed: ServiceResult = p.prepare_chamber_recovery_job(actor)
		check(resumed.is_success, "undamaged control resumes before damage")
		if not resumed.is_success: target.free(); return
		check(resumed.value.commit(p, g, i, a).is_success, "undamaged control admits running job")
		for tick in range(60): clock._physics_process(1.0 / 60.0)
		var undamaged: ServiceResult = eligible_step(p, g, i, a, actor, clock, "undamaged condition%d" % condition)
		if not undamaged.is_success: target.free(); return
	var physical: Dictionary = i.capture_snapshot().value
	var assembly: Dictionary = ChamberRecoveryRecords.current(p.capture_snapshot().value.chamber_recovery)
	for item in physical.owner.ledger.items:
		if item.item_id == assembly.item_id: item.condition_permille = condition
	check(i.restore_snapshot_record(physical, clock.tick_number).is_success, "real owner retains damaged pump without healing")
	var owners: Array = [p, g, i, a]
	var before: Array = owner_records(owners)
	var attempted: ServiceResult = p.prepare_chamber_recovery_step(clock.tick_number) if stage == "step" else p.prepare_chamber_recovery_job(actor)
	check(not attempted.is_success, "damaged item rejects before preparation: %s condition%d" % [stage, condition])
	check(owner_records(owners) == before, "damage admission rejection preserves all owners, gas/J and normal receipts")
	var retained: Dictionary = MachineryWorkshop.item(i.capture_snapshot().value.owner, assembly.item_id)
	check(retained.condition_permille == condition and retained.item_id == assembly.item_id, "rejection retains the same damaged item and condition")
	target.free()


func diagnostic(result: ServiceResult) -> String:
	return "[%s] %s" % [String(result.error_code), result.message]


## Pin the eligibility stages before damage or stale-owner mutations so a
## rejected positive cannot silently make the negative controls pass.
func eligible_step(p: ProductionSimulationSystem, g: PressureSystem, i: InventorySimulationSystem, a: AccessControlSystem, actor: AuthenticatedCommandContext, clock: SimulationRunner, label: String) -> ServiceResult:
	var state: Dictionary = p.capture_snapshot().value
	var job: Dictionary = ChamberRecoveryRecords.active_job(state.chamber_recovery)
	check(job.state == "running" and clock.tick_number == int(state.last_tick) and clock.tick_number == int(job.next_eligible_tick), "running job reaches exact sixty-tick eligibility: " + label)
	var admission: ServiceResult = ChamberRecoveryPreparation.admit(p, actor, "step")
	check(admission.is_success, "step authority, pose, tool, doors and item admit: %s %s" % [label, diagnostic(admission)])
	var control: ServiceResult = i.controller_candidate()
	check(control.is_success and control.value.has(job.body_id) and int(control.value[job.body_id].control_epoch) == int(job.control_epoch), "step retains admitted control epoch: " + label)
	for owner in [p, g, i, a]:
		var captured: ServiceResult = owner.capture_snapshot()
		var validated: ServiceResult = owner.validate_snapshot_record(captured.value, clock.tick_number)
		check(validated.is_success, "eligible owner validates: %s %s %s" % [label, String(owner.system_id), diagnostic(validated)])
	var work: ServiceResult = g.prepare_chamber_recovery_transfer(job.assembly_id, job.job_id, minf(0.1, float(job.target_moles) - float(job.returned_moles)), clock.tick_number)
	check(work.is_success, "eligible gas and bounded work prepare: %s %s" % [label, diagnostic(work)])
	var candidate: ServiceResult = p.prepare_chamber_recovery_step(clock.tick_number)
	check(candidate.is_success, "eligible real-owner batch prepares: %s %s" % [label, diagnostic(candidate)])
	return candidate


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
