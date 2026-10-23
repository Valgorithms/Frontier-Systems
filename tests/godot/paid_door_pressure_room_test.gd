extends "res://tests/godot/paid_door_opening_owner_test.gd"

var pressure: PressureSystem


func run() -> void:
	build_enclosure()
	if failures: return
	pressure = world.get_simulation_system(PressureSystem.SYSTEM_ID)
	door_id = production._state.doors.keys()[0]
	var initial_moles: float = total_moles()
	var stock: Dictionary = production._state.store.duplicate(true)
	room_reject("door_room_commission") # no installed seal
	door_command("door_seal_install", {"door_id": door_id})
	if failures: finish(); return
	var a: ActuatorState = leaf()
	check(a.effective_pressure_area_m2 == 0.0 and pressure.constructed_rooms.is_empty(), "condition1 alone grants no pressure service")
	check(AccessControlSystem.PROTOTYPE_MANUAL_FORCE_NEWTONS == 1000.0 and ConstructedRoomPressure.RETENTION_KPA * 1000.0 * ConstructedRoomPressure.AREA < AccessControlSystem.PROTOTYPE_MANUAL_FORCE_NEWTONS, "actual manual force has strict retention recovery margin")
	var legacy: Dictionary = pressure.capture_snapshot().value
	legacy.schema_version = 1; legacy.erase("constructed_rooms")
	check(pressure.restore_snapshot_record(legacy, runner.tick_number).is_success and pressure.constructed_rooms.is_empty(), "legacy v1 pressure migrates without allocation or gas creation")
	var custom_legacy: Dictionary = legacy.duplicate(true)
	for volume in custom_legacy.volumes:
		if volume.volume_id == String(PressureSystem.PROTOTYPE_HABITAT_ID): volume.volume_m3 = 500.0
	check(pressure.restore_snapshot_record(custom_legacy, runner.tick_number).is_success, "legacy roomless arbitrary finite habitat volume remains supported")
	var migrated: Dictionary = pressure.capture_snapshot().value
	check(migrated.schema_version == 2 and pressure.restore_snapshot_record(migrated, runner.tick_number).is_success and pressure.capture_snapshot().value == migrated and conserved(initial_moles), "legacy non1000 roomless network captures and restores v2 unchanged")
	room_reject("door_room_commission")
	check(pressure.restore_snapshot_record(legacy, runner.tick_number).is_success, "restore original fixture after compatibility check")
	# Use the real current tool/component owner, not a context capability string.
	var tools: ToolSimulationSystem = world.get_simulation_system(ToolSimulationSystem.SYSTEM_ID)
	var active: ServiceResult = inventory.active_tool(context, "tool.crowbar")
	check(active.is_success, "commission fixture has real active fabricated crowbar")
	if not active.is_success: finish(); return
	var tool_before: Dictionary = tools._ledger._record.duplicate(true)
	for part in tools._ledger._record.assemblies[active.value].slots.values(): tools._ledger._record.parts[part].integrity_ppm = 0
	room_reject("door_room_commission")
	tools._ledger._record = tool_before
	for field in ["seal_condition", "integrity", "position"]:
		a = leaf()
		var previous: Variant = a.get(field)
		a.set(field, 1.0 if field == "position" else 0.5)
		room_reject("door_room_commission")
		a.set(field, previous)
	room_reject("door_room_commission", {"volume_m3": 1.6})
	room_reject("door_room_commission", {"pressure_kpa": 101.325})
	var commission_intent: Dictionary = current_intent()
	var controls := PaidDoorControls.new(); root.add_child(controls); controls.configure(world); controls.set_process(false); controls._process(0.2)
	controls._buttons[6].pressed.emit()
	var commission_request: String = controls._pending
	check(not commission_request.is_empty(), "actual commissioning button queues authenticated intent")
	step(); controls._process(0.2)
	check(last.is_success and controls._pending.is_empty(), "actual commissioning button completes at fixed tick")
	controls.free()
	if failures: finish(); return
	var committed_pressure: Dictionary = pressure.capture_snapshot().value
	var committed_production: Dictionary = production.capture_snapshot().value
	check(production.apply_local(context, commission_request, "door_room_commission", commission_intent, runner.tick_number + 1).is_success, "exact commissioning replay returns retained receipt")
	check(pressure.capture_snapshot().value == committed_pressure and production.capture_snapshot().value == committed_production, "commission replay cannot split volume or gas twice")
	check(pressure.constructed_rooms.size() == 1 and pressure.volumes.size() == 4 and pressure.sensors.size() == 4, "queued commissioning registers exactly one finite room/link/sensor")
	check(absf(room_volume().volume_m3 - 1.6) < 1e-12 and absf(ambient_volume().volume_m3 - 998.4) < 1e-9, "integer geometry allocates 1.6m3 from 1000m3 habitat")
	check(conserved(initial_moles) and absf(pressure.room_difference(door_id)) < 1e-9, "proportional initial gas split conserves finite moles and pressure")
	check(production._state.store.plate == stock.plate - PaidDoorSeal.MASS and production._state.store.iron == stock.iron and ConstructionReservationPlan.claimed(production._state.construction) == claims, "commissioning creates no material or reserved stock")
	check(leaf().effective_pressure_area_m2 == 1.71 and leaf().maximum_force_newtons == 0.0, "only commissioned hardware gets explicit load area and no powered force")
	check(production.construction_openings(context, production._state.state_revision).value.status == "enclosure_with_unsealed_openings", "PR142 diagnostic remains unchanged after commissioning")
	room_reject("door_room_commission")
	room_reject("door_room_decommission") # closed
	for operation in ["door_seal_remove", "door_seal_install", "door_remove"]: room_reject(operation)
	for kind in ["walls", "panels"]:
		for id in production._state[kind]:
			var candidate: Dictionary = production._state.duplicate(true)
			candidate[kind].erase(id)
			check(not pressure.validate_room_links(candidate, access.capture_snapshot().value).is_success, "every linked removal candidate rejects before commit")
			var before: Dictionary = production.capture_snapshot().value
			var key: String = "wall_id" if kind == "walls" else "panel_id"
			command("wall_remove" if kind == "walls" else "panel_remove", {key: id}, false)
			check(production._state.state_revision == before.state_revision and production._state.store == before.store and production._state[kind] == before[kind], "actual removal path preserves geometry, stock and receipt revision")
	if failures: finish(); return
	var saved: Dictionary = JSON.parse_string(world.capture_world_snapshot_json().value)
	var fixture := FileAccess.open("res://var/paid-door-pressure-fixture.json", FileAccess.WRITE)
	fixture.store_string(JSON.stringify({"world": saved, "observation": production.observation(context).value})); fixture.close()
	restore_cases(saved)
	if failures: finish(); return
	# Stale Pressure CAS rejects before the Access write, with Production untouched.
	var candidate: Dictionary = production._state.duplicate(true)
	var prepared: ServiceResult = PaidDoorConstruction.plan(candidate, inventory, access, context, "pressure-cas", "door_open", current_intent(), pressure)
	check(prepared.is_success, "current unloaded real-tool actuation prepares")
	if prepared.is_success:
		prepared.value.pressure_owner = pressure
		prepared.value.pressure_before = pressure.capture_snapshot().value
		var sensor: PressureSensorState = pressure.sensors[&"sensor_habitat"]
		sensor.sample_count += 1
		var access_before: Dictionary = access.capture_snapshot().value
		var prod_before: Dictionary = production.capture_snapshot().value
		check(not prepared.value.commit(access).is_success and access.capture_snapshot().value == access_before and production.capture_snapshot().value == prod_before, "stale pressure CAS leaves Access and Production unchanged")
		sensor.sample_count -= 1
	# Test-only gas redistribution preserves the full finite quantity exactly to
	# bulk solver tolerance; it is not a gameplay refill or species assertion.
	set_difference(0.4)
	var retained_moles: float = room_volume().gas_moles
	step(5)
	check(room_volume().gas_moles == retained_moles, "closed intact commissioned seal retains below-rating pressure")
	for field in ["seal_condition", "integrity", "mode", "latch_state"]:
		set_difference(0.4)
		a = leaf()
		var old: Variant = a.get(field)
		a.set(field, &"jammed" if field == "mode" else (&"damaged" if field == "latch_state" else 0.25))
		retained_moles = room_volume().gas_moles
		step()
		check(room_volume().gas_moles < retained_moles and conserved(initial_moles), "degraded hardware leaks on next pressure tick with conserved gas")
		if field == "seal_condition":
			var degraded: Dictionary = JSON.parse_string(world.capture_world_snapshot_json().value)
			var target := WorldRuntime.new(); target.resource_carriers_enabled = true; root.add_child(target)
			check(target.restore_world_snapshot_json(JSON.stringify(degraded)).is_success, "degraded commissioned room restores with actual gas")
			var restored_access: AccessControlSystem = target.get_simulation_system(AccessControlSystem.SYSTEM_ID)
			check(restored_access.devices[StringName(door_id)].actuator(PaidDoorConstruction.actuator_id(door_id)).seal_condition == 0.25, "restore never heals degraded commissioned gasket")
			target.free()
		a.set(field, old)
	set_difference(1.2) # former 0.585..2kPa trapped interval
	var revision: int = production._state.state_revision
	door_command("door_open", {"door_id": door_id}, false)
	check(production._state.state_revision == revision and leaf().position == 0.0, "actual 1000N force rejects opening above threshold")
	var formerly_trapped: Dictionary = JSON.parse_string(world.capture_world_snapshot_json().value)
	var recovered := WorldRuntime.new(); recovered.resource_carriers_enabled = true; root.add_child(recovered)
	check(recovered.restore_world_snapshot_json(JSON.stringify(formerly_trapped)).is_success, "over-rating pressure restores without reset")
	var recovered_pressure: PressureSystem = recovered.get_simulation_system(PressureSystem.SYSTEM_ID)
	for tick in range(1, 301): recovered_pressure.simulate_tick(runner.tick_number + tick, 1.0 / 60.0)
	check(recovered_pressure.room_difference(door_id) <= 0.5 + ConstructedRoomPressure.TOLERANCE_KPA and recovered_pressure.room_difference(door_id) * 1000.0 * 1.71 < 1000.0, "restored formerly trapped state leaks to operable margin")
	recovered.free()
	step(300)
	check(pressure.room_difference(door_id) <= 0.5 + ConstructedRoomPressure.TOLERANCE_KPA and conserved(initial_moles), "over-rating leakage reaches an operable state without valve, gas or autoheal")
	door_command("door_open", {"door_id": door_id})
	check(production.observation(context).value.paid_doors.doors[0].pressure_room.leaking, "own observation exposes open boundary leakage")
	if failures: finish(); return
	var view := PaidDoorControls.new(); root.add_child(view); view.configure(world); view.set_process(false); view._process(0.2)
	check(view._doors.get_item_text(0).contains("kPa") and view._doors.get_item_text(0).contains("leaking"), "player controls show actual commissioned pressure and leakage")
	view.free()
	var decommission := PaidDoorControls.new(); root.add_child(decommission); decommission.configure(world); decommission.set_process(false); decommission._process(0.2)
	decommission._buttons[7].pressed.emit(); step(); decommission._process(0.2)
	check(last.is_success and decommission._pending.is_empty(), "actual decommission button completes at fixed tick")
	decommission.free()
	check(pressure.constructed_rooms.is_empty() and pressure.volumes.size() == 3 and pressure.sensors.size() == 3 and absf(ambient_volume().volume_m3 - 1000.0) < 1e-9 and conserved(initial_moles), "explicit open decommission merges finite volume and gas once")
	check(leaf().effective_pressure_area_m2 == 0.0 and leaf().seal_condition == 1.0, "decommission removes service area and retains paid hardware condition")
	room_reject("door_room_decommission")
	door_command("door_close", {"door_id": door_id})
	door_command("door_seal_remove", {"door_id": door_id})
	check(production._state.store == stock, "seal recovery exactly refunds its finite material after decommission")
	print("Paid constructed pressure room: %d failures" % failures)
	finish()


func current_intent() -> Dictionary:
	return {"door_id": door_id, "expected_revision": production._state.state_revision, "control_epoch": 0}


func room_reject(operation: String, extra: Dictionary = {}) -> void:
	var before: Dictionary = production.capture_snapshot().value
	var access_before: Dictionary = access.capture_snapshot().value
	var pressure_before: Dictionary = pressure.capture_snapshot().value
	var intent: Dictionary = current_intent(); intent.merge(extra)
	sequence += 1
	var result: ServiceResult = production.apply_local(context, "room-denied-%d" % sequence, operation, intent, runner.tick_number + 1)
	check(not result.is_success, operation + " rejects")
	check(production.capture_snapshot().value == before and access.capture_snapshot().value == access_before and pressure.capture_snapshot().value == pressure_before, operation + " rejection preserves all three owners")


func leaf() -> ActuatorState:
	return access.devices[StringName(door_id)].actuator(PaidDoorConstruction.actuator_id(door_id))


func room_volume() -> PressureVolumeState:
	return pressure.volumes[StringName(pressure.constructed_rooms.keys()[0])]


func ambient_volume() -> PressureVolumeState:
	return pressure.volumes[PressureSystem.PROTOTYPE_HABITAT_ID]


func total_moles() -> float:
	var total: float = 0.0
	for volume in pressure.volumes.values(): total += volume.gas_moles
	return total


func conserved(expected: float) -> bool:
	return absf(total_moles() - expected) <= maxf(1e-9, expected * 1e-12)


func set_difference(kpa: float) -> void:
	var room: PressureVolumeState = room_volume()
	var ambient: PressureVolumeState = ambient_volume()
	var total: float = room.gas_moles + ambient.gas_moles
	var offset: float = kpa * 1000.0 / (PressureVolumeState.GAS_CONSTANT_J_PER_MOL_K * room.temperature_kelvin * (1.0 / room.volume_m3 + 1.0 / ambient.volume_m3))
	room.gas_moles = total * room.volume_m3 / (room.volume_m3 + ambient.volume_m3) + offset
	ambient.gas_moles = total - room.gas_moles


func restore_cases(saved: Dictionary) -> void:
	var target := WorldRuntime.new(); target.resource_carriers_enabled = true; root.add_child(target)
	check(target.restore_world_snapshot_json(JSON.stringify(saved)).is_success, "normalized three-owner world restore succeeds")
	target.free()
	for mutation in ["policy", "geometry", "volume", "area", "orphan", "sensor", "seal", "extra"]:
		var bad: Dictionary = saved.duplicate(true)
		var room: Dictionary = bad.systems.pressure.constructed_rooms.values()[0]
		match mutation:
			"policy": room.policy_id = "client-rated"
			"geometry": room.geometry.panels.clear()
			"volume":
				for volume in bad.systems.pressure.volumes:
					if volume.volume_id == room.volume_id: volume.volume_m3 += 1
			"area":
				for device in bad.systems.access_control.devices:
					if device.device_id == door_id: device.actuators[0].effective_pressure_area_m2 = 0.0
			"orphan": bad.systems.pressure.constructed_rooms.clear()
			"sensor": room.sensor_id = "sensor_habitat"
			"seal": bad.systems.production.doors[door_id].seal.materials.plate = 1
			"extra": room.pressure_rating = 999
		target = WorldRuntime.new(); target.resource_carriers_enabled = true; root.add_child(target)
		var before: String = target.capture_world_snapshot_json().value
		check(not target.restore_world_snapshot_json(JSON.stringify(bad)).is_success and target.capture_world_snapshot_json().value == before, "malformed cross-owner restore rejects before any mutation: " + mutation)
		target.free()
	var changed: Dictionary = production.capture_snapshot().value
	changed.panels.values()[0].principal_id = "foreign"
	check(not production.restore_snapshot_record(changed, runner.tick_number).is_success, "same-revision independent geometry restore cannot break pressure links")
	changed = pressure.capture_snapshot().value
	changed.constructed_rooms.clear()
	check(not pressure.restore_snapshot_record(changed, runner.tick_number).is_success, "independent Pressure restore cannot orphan paid area")
	changed = access.capture_snapshot().value
	for device in changed.devices:
		if device.device_id == door_id: device.actuators[0].effective_pressure_area_m2 = 0.0
	check(not access.restore_snapshot_record(changed, runner.tick_number).is_success, "independent Access restore cannot remove commissioned area")
