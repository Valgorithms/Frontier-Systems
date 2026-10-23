extends "res://tests/godot/finite_bootstrap_acquisition_test.gd"

## Reuse the full unseeded PR146 acquisition, construction and legacy controls.
## The parent ends here only after its real room and strict JSON roundtrip pass.
func finish() -> void:
	if failures == 0: equalization_checks()
	super.finish()


func pressure_owner() -> PressureSystem:
	return world.get_simulation_system(PressureSystem.SYSTEM_ID)


func room() -> PressureVolumeState:
	return pressure_owner().volumes[StringName(pressure_owner().constructed_rooms.values()[0].volume_id)]


func all_moles() -> float:
	var total: float = 0.0
	for volume in pressure_owner().volumes.values(): total += volume.gas_moles
	return total


func gas_conserved(before: float) -> bool:
	return absf(all_moles() - before) <= maxf(1e-9, before * 1e-12)


func airlock_action(action: int) -> void:
	sequence += 1
	var command := AirlockCommand.new()
	command.command_id = StringName("equalization-airlock-%d" % sequence)
	command.airlock_id = &"habitat_airlock"
	command.action = action
	command.authenticated_context = context
	check(world.enqueue_command(command).is_success, "queue legitimate finite airlock action")
	step()
	check(last.is_success, "finite airlock command: " + last.message)


func equalization_checks() -> void:
	var initial: float = all_moles()
	var baseline: String = world.capture_world_snapshot_json().value
	bypass_reject("door_bypass_open")
	bypass_reject("door_bypass_recover")
	door_command("door_bypass_install", {"door_id": door_id})
	if failures: return
	check(production._state.schema_version == 13 and production._state.store.plate == 0 and production._state.store.iron == 200000 and production._state.store.tailings == 6800000 and production._state.energy_joules == 68750, "real acquired leftover plate pays exact bypass bill without resource or energy grant")
	check(not pressure_owner().room_valve_open(door_id) and pressure_owner().room_valves.has(door_id), "installed paid device defaults closed")
	var installed: Dictionary = production._state.room_bypasses.duplicate(true)
	var install_request: String = "machine-test-%d" % sequence
	var install_payload: Dictionary = {"expected_revision": production._state.state_revision - 1, "control_epoch": 0, "door_id": door_id}
	var before_replay: Dictionary = production.capture_snapshot().value
	check(production.apply_local(context, install_request, "door_bypass_install", install_payload, runner.tick_number + 1).is_success and production.capture_snapshot().value == before_replay, "exact install replay cannot charge or fabricate twice")
	bypass_reject("door_bypass_install")
	bypass_reject("door_bypass_recover")
	bypass_reject("door_bypass_open", {"conductance": 10})
	bypass_reject("door_bypass_open", {"control_epoch": 1})
	bypass_reject("door_bypass_open", {"expected_revision": production._state.state_revision - 1})
	var own_context: AuthenticatedCommandContext = context
	context = AuthenticatedCommandContext.for_local_development(&"foreign-builder", world.world_id, world.region_id)
	bypass_reject("door_bypass_open")
	context = own_context
	var crowbar: String = inventory.active_tool(context, "tool.crowbar").value
	inventory_action("self", {"operation": "unequip", "item_id": "", "source_container_id": "", "destination_container_id": "storage.backpack-1", "slot_id": "hand.left"})
	bypass_reject("door_bypass_open")
	inventory_action("self", {"operation": "equip", "item_id": crowbar, "source_container_id": "storage.backpack-1", "destination_container_id": "", "slot_id": "hand.left"})
	inventory_action("self", {"operation": "select_hand", "item_id": "", "source_container_id": "", "destination_container_id": "", "slot_id": "hand.left"})
	var live_position: Array = inventory.capture_snapshot().value.bodies.filter(func(b: Dictionary) -> bool: return b.body_id == "body.human-1")[0].position_millimetres.duplicate()
	move([3600, 0, -6000])
	bypass_reject("door_bypass_open")
	move(live_position)
	# Initial chamber is 10 m3 vacuum; habitat is the remaining 998.4 m3.
	# Sixty fixed ticks through the existing 0.8 mol/(s*kPa) airlock valve
	# lower the habitat by about 0.19 kPa. No owner gas/store mutation.
	airlock_action(AirlockState.Action.OPEN_EQUALIZATION)
	step(59)
	airlock_action(AirlockState.Action.CLOSE_EQUALIZATION)
	var difference: float = pressure_owner().room_difference(door_id)
	check(difference > 0.1 and difference < 0.3, "bounded61-tick legitimate finite airlock creates subthreshold gradient")
	var retained: float = room().gas_moles
	step(20)
	check(room().gas_moles == retained and gas_conserved(initial), "closed healthy boundary and valve retain legitimate gradient without gas creation")
	reload_playable(world.capture_world_snapshot_json().value, "closed paid bypass strict whole-world JSON roundtrip")
	check(room().gas_moles == retained and not pressure_owner().room_valve_open(door_id), "closed reload retains actual gas and position")
	var controls := PaidDoorControls.new()
	root.add_child(controls); controls.configure(world, context.principal_id); controls.set_process(false); controls._process(0.2)
	check(controls._buttons.size() == 14, "manual bypass actions share collapsed door controls")
	controls._buttons[9].pressed.emit()
	check(not controls._pending.is_empty(), "actual open-bypass button queues authenticated command")
	step(); controls._process(0.2)
	check(last.is_success and controls._pending.is_empty() and pressure_owner().room_valve_open(door_id), "actual open button completes on simulation tick")
	controls.free()
	step(20)
	check(pressure_owner().room_difference(door_id) < difference and room().gas_moles < retained and gas_conserved(initial), "open paid valve conservatively reduces retained subthreshold differential")
	var open_snapshot: String = world.capture_world_snapshot_json().value
	var open_difference: float = pressure_owner().room_difference(door_id)
	reload_playable(open_snapshot, "open paid bypass strict whole-world JSON roundtrip")
	check(pressure_owner().room_valve_open(door_id) and production._state.room_bypasses == installed, "open reload retains paid identity without replacement")
	step(20)
	check(pressure_owner().room_difference(door_id) < open_difference and gas_conserved(initial), "open reload resumes existing finite gas exchange")
	door_command("door_bypass_close", {"door_id": door_id})
	retained = room().gas_moles
	step(30)
	check(room().gas_moles == retained and gas_conserved(initial), "explicit close stops subthreshold valve flow")
	var observation: Dictionary = production.observation(context).value
	check(WorkstationResourceView.valid(observation) and observation.schema_version == 15 and observation.paid_doors.schema_version == 4 and not observation.paid_doors.doors[0].bypass_open, "strict own observation shows closed installed valve and finite pressures")
	check("difference" in PaidDoorControls.seal_text(observation.paid_doors.doors[0]), "UI reports actual differential and load")
	malformed_bypass_restores(open_snapshot)
	var expired := HostedPaidDoorCommand.new()
	expired.command_id = &"expired-bypass-open"; expired.operation = "door_bypass_open"; expired.authenticated_context = context
	expired.payload = {"expected_revision": production._state.state_revision, "control_epoch": 0, "door_id": door_id}
	check(not expired.validate(world).is_success and not expired.apply(world).is_success and not pressure_owner().room_valve_open(door_id), "lost hosted session cannot validate or apply a new bypass operation")
	door_command("door_bypass_open", {"door_id": door_id})
	step(600)
	check(pressure_owner().room_difference(door_id) <= PressureFlowSolver.EQUILIBRIUM_EPSILON_KPA and gas_conserved(initial), "bounded passive exchange reaches equilibrium without overshoot")
	door_command("door_open", {"door_id": door_id})
	bypass_reject("door_room_decommission")
	door_command("door_bypass_close", {"door_id": door_id})
	door_command("door_room_decommission", {"door_id": door_id})
	check(pressure_owner().room_valves.is_empty() and production._state.room_bypasses == installed, "closed decommission retains recoverable paid hardware and removes operational link")
	bypass_reject("door_remove")
	bypass_reject("door_bypass_open")
	door_command("door_close", {"door_id": door_id})
	door_command("door_room_commission", {"door_id": door_id})
	check(not pressure_owner().room_valve_open(door_id) and production._state.room_bypasses == installed and production._state.store.plate == 0, "recommission reuses same paid part closed without material grant")
	door_command("door_open", {"door_id": door_id})
	door_command("door_room_decommission", {"door_id": door_id})
	door_command("door_bypass_recover", {"door_id": door_id})
	var recover_payload: Dictionary = {"expected_revision": production._state.state_revision - 1, "control_epoch": 0, "door_id": door_id}
	var recovered: Dictionary = production.capture_snapshot().value
	check(recovered.schema_version == 12 and recovered.store.plate == 200000 and not recovered.has("room_bypasses") and gas_conserved(initial), "recover exact200000mg once without gas or material loss")
	check(production.apply_local(context, "machine-test-%d" % sequence, "door_bypass_recover", recover_payload, runner.tick_number + 1).is_success and production.capture_snapshot().value == recovered, "recovery exact replay cannot refund twice")
	bypass_reject("door_bypass_recover")
	# These isolated rejection controls never fund the positive runtime path.
	overrating_rejection_controls(open_snapshot)
	var fixture := FileAccess.open("res://var/room-equalization-fixture.json", FileAccess.WRITE)
	fixture.store_string(JSON.stringify({"world": JSON.parse_string(open_snapshot), "observation": observation, "legacy_world": JSON.parse_string(baseline)})); fixture.close()


func bypass_reject(operation: String, extra: Dictionary = {}) -> void:
	sequence += 1
	var intent: Dictionary = {"expected_revision": production._state.state_revision, "control_epoch": 0, "door_id": door_id}
	intent.merge(extra, true)
	var before: Array = [production.capture_snapshot().value, access.capture_snapshot().value, pressure_owner().capture_snapshot().value]
	var rejected: ServiceResult = production.apply_local(context, "bypass-denied-%d" % sequence, operation, intent, runner.tick_number + 1)
	check(not rejected.is_success and not rejected.message.contains("fresh fixed tick"), "bypass contract rejection: " + operation + JSON.stringify(extra) + ": " + rejected.message)
	check(before == [production.capture_snapshot().value, access.capture_snapshot().value, pressure_owner().capture_snapshot().value], "rejected bypass command changes no owner or receipt")


func malformed_bypass_restores(snapshot: String) -> void:
	for mutation in ["bill", "orphan", "missing", "open_type", "extra", "version", "grant", "pressure_legacy"]:
		var target: WorldRuntime = FirstPlayableBootstrap.create_playable_world(true, false); root.add_child(target)
		var before: Variant = JSON.parse_string(target.capture_world_snapshot_json().value)
		var bad: Dictionary = JSON.parse_string(snapshot)
		match mutation:
			"bill": bad.systems.production.room_bypasses[door_id].materials.plate += 1
			"orphan": bad.systems.production.room_bypasses["door-foreign"] = bad.systems.production.room_bypasses[door_id]; bad.systems.production.room_bypasses.erase(door_id)
			"missing": bad.systems.pressure.room_valves.clear()
			"open_type": bad.systems.pressure.room_valves[door_id] = 1
			"extra": bad.systems.pressure["conductance"] = 100
			"version": bad.systems.production.schema_version = 14
			"grant": bad.systems.production.store.plate += PaidRoomBypass.MASS
			"pressure_legacy": bad.systems.pressure.schema_version = 2; bad.systems.pressure.erase("room_valves")
		check(not target.restore_world_snapshot_json(JSON.stringify(bad)).is_success, "malformed bypass restore rejects: " + mutation)
		check(same_json_value(before, JSON.parse_string(target.capture_world_snapshot_json().value)), "failed bypass restore preserves entire world: " + mutation)
		target.free()


func overrating_rejection_controls(snapshot: String) -> void:
	var outcomes: Array = []
	for entry in [[0.6, false], [0.6, true], [-0.6, false], [-0.6, true]]:
		var opened: bool = entry[1]
		var target_difference: float = entry[0]
		var bad: Dictionary = JSON.parse_string(snapshot)
		var room_id: String = bad.systems.pressure.constructed_rooms.values()[0].volume_id
		var room_record: Dictionary = {}
		var ambient_record: Dictionary = {}
		for volume in bad.systems.pressure.volumes:
			if volume.volume_id == room_id: room_record = volume
			if volume.volume_id == "habitat_main": ambient_record = volume
		var factor: float = PressureVolumeState.GAS_CONSTANT_J_PER_MOL_K * float(room_record.temperature_kelvin) / 1000.0
		var current: float = factor * (float(room_record.gas_moles) / float(room_record.volume_m3) - float(ambient_record.gas_moles) / float(ambient_record.volume_m3))
		# Rejection-only synthetic overrating, finite redistribution; no refill.
		var shift: float = (target_difference - current) / (factor * (1.0 / float(room_record.volume_m3) + 1.0 / float(ambient_record.volume_m3)))
		room_record.gas_moles += shift; ambient_record.gas_moles -= shift
		bad.systems.pressure.room_valves[door_id] = opened
		var target: WorldRuntime = FirstPlayableBootstrap.create_playable_world(true, false); root.add_child(target)
		check(target.restore_world_snapshot_json(JSON.stringify(bad)).is_success, "isolated finite overrating rejection fixture restores")
		var owner: ProductionSimulationSystem = target.get_simulation_system(ProductionSimulationSystem.SYSTEM_ID)
		var gas: PressureSystem = target.get_simulation_system(PressureSystem.SYSTEM_ID)
		var actor := AuthenticatedCommandContext.for_local_development(&"local-inventory-target", target.world_id, target.region_id)
		var before: Dictionary = owner.capture_snapshot().value
		var rejected: ServiceResult = owner.apply_local(actor, "overrating-door-reject", "door_open", {"door_id": door_id, "control_epoch": 0, "expected_revision": before.state_revision}, int(bad.tick_number) + 1)
		check(not rejected.is_success and rejected.error_code == &"actuator_force_exceeded" and owner.capture_snapshot().value == before, "real1000N force guard rejects0.6kPa with valve open or closed: " + rejected.message)
		check(target.start_simulation().is_success, "start isolated overrating control")
		var clock: SimulationRunner = target.get_node("SimulationRunner")
		clock.set_physics_process(false); clock._physics_process(1.0 / 60.0)
		check(gas.room_difference(door_id) < 0.6, "closed/open valve preserves safety leakage above0.5kPa")
		outcomes.append(gas.capture_snapshot().value.volumes)
		target.free()
	check(outcomes[0] == outcomes[1] and outcomes[2] == outcomes[3], "actual runtime gas outcome above rating is identical with valve closed/open")
