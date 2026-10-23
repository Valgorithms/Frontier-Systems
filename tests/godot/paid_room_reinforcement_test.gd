extends "res://tests/godot/commissioned_room_equalization_test.gd"

class ActorPanel extends LocalProductionPanel:
	var actor: AuthenticatedCommandContext
	func _context() -> AuthenticatedCommandContext:
		return actor

## Real playable factory, finite acquisition and actual UI command queue.
func run() -> void:
	world = FirstPlayableBootstrap.create_playable_world(true, false)
	root.add_child(world)
	world.command_completed.connect(func(_command: SimulationCommand, result: ServiceResult) -> void: last = result)
	check(world.start_simulation().is_success, "new playable reinforcement world starts")
	runner = world.get_node("SimulationRunner"); runner.set_physics_process(false)
	production = world.get_simulation_system(ProductionSimulationSystem.SYSTEM_ID)
	inventory = world.get_simulation_system(InventorySimulationSystem.SYSTEM_ID)
	access = world.get_simulation_system(AccessControlSystem.SYSTEM_ID)
	context = AuthenticatedCommandContext.for_local_development(&"local-inventory-target", world.world_id, world.region_id)
	var blueprint: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/production/manual-room-reinforcement.v1.json"))
	check(PaidRoomReinforcement.valid_blueprint(blueprint), "pinned first-party bill and game tuning")
	for field in ["retention_kpa", "assembly_energy_joules", "materials"]:
		var changed: Dictionary = blueprint.duplicate(true)
		changed[field] = 1
		check(not PaidRoomReinforcement.valid_blueprint(changed), "changed pinned blueprint rejects: " + field)
	var pristine: Dictionary = production.capture_snapshot().value
	check(pristine.schema_version == 14 and pristine.catalog_revision == 3 and ProductionSimulationSystem._mass(pristine.deposits) == 39000000, "separately versioned 39 kg origin")
	move([0, 0, 0])
	inventory_action("world", {"operation": "pickup", "item_id": "resource-canister-2", "world_container_id": "world.tray-1", "destination_container_id": "body.human-1", "slot_id": ""})
	inventory_action("self", {"operation": "equip", "item_id": "extractor-2", "source_container_id": "storage.backpack-1", "destination_container_id": "", "slot_id": "hand.right"})
	inventory_action("self", {"operation": "select_hand", "item_id": "", "source_container_id": "", "destination_container_id": "", "slot_id": "hand.right"})
	for batch in range(24):
		move([-3000, 0, -1000])
		var source: String = "deposit.iron" if batch < 10 else ("deposit.iron.outcrop" if batch < 17 else "deposit.iron.reinforcement")
		if batch == 17:
			var panel := ActorPanel.new()
			panel.actor = context
			root.add_child(panel); panel.configure(world); panel.set_process(false)
			var found: int = -1
			for index in range(panel._deposit.item_count):
				if panel._deposit.get_item_text(index) == source: found = index
			check(found >= 0, "actual source picker exposes finite reinforcement seam")
			if found >= 0: panel._deposit.select(found)
			panel.refresh()
			check(not panel._extract_button.disabled, "new source is reachable and selectable with equipped extractor")
			panel.free()
		command("tool_extract", {"deposit_id": source, "carrier_id": "resource-canister-2", "amount_milligrams": 1000000})
		move([0, 0, 0])
		command("unload_cargo", {"carrier_id": "resource-canister-2", "material": "ore.iron", "amount_milligrams": 1000000})
		command("process", {"recipe_id": "refine.iron"}); step(120)
		if failures: finish(); return
	for batch in range(12):
		command("process", {"recipe_id": "craft.plate"}); step(120)
	command("fabricate_equipment", {"blueprint_id": "equipment.crowbar"})
	inventory_action("self", {"operation": "unequip", "item_id": "", "source_container_id": "", "destination_container_id": "storage.backpack-1", "slot_id": "hand.right"})
	var crowbar: String = ""
	for item in inventory.own_inventory_observation(context).value.items:
		if item.definition_id == "item.crowbar.fabricated": crowbar = item.item_id
	equip(crowbar)
	build_paid_geometry()
	if failures: finish(); return
	door_id = production._state.doors.keys()[0]
	door_command("door_seal_install", {"door_id": door_id})
	door_command("door_room_commission", {"door_id": door_id})
	ui_action(12)
	ui_action(8)
	if failures: finish(); return
	bypass_reject("door_reinforcement_install")
	bypass_reject("door_reinforcement_recover")
	bypass_reject("door_reinforcement_install", {"retention_kpa": 1000})
	bypass_reject("door_reinforcement_install", {"control_epoch": 1})
	bypass_reject("door_reinforcement_install", {"expected_revision": production._state.state_revision - 1})
	var paid: Dictionary = production.capture_snapshot().value
	check(paid.energy_joules == 56000 and paid.store.plate == 0 and paid.store.iron == 400000 and paid.store.tailings == 9600000, "24 kg unseeded route spends exactly 44000 J and 12 kg installed plate")
	for source in ["deposit.iron", "deposit.iron.outcrop", "deposit.iron.reinforcement"]: check(paid.deposits[source] == 0, "finite source exhausted: " + source)
	check(paid.deposits["deposit.ice"] == 5000000 and paid.deposits["deposit.regolith"] == 10000000, "other sources unchanged")
	var initial: float = all_moles()
	airlock_action(AirlockState.Action.OPEN_EQUALIZATION)
	for tick in range(600):
		if pressure_owner().room_difference(door_id) > 0.65: break
		step()
	airlock_action(AirlockState.Action.CLOSE_EQUALIZATION)
	check(pressure_owner().room_difference(door_id) > 0.6, "legitimate finite airlock exchange creates crowbar-blocking differential")
	var retained: float = room().gas_moles
	step(20)
	check(room().gas_moles == retained and gas_conserved(initial), "closed reinforced boundary holds above 0.6 kPa")
	var blocked: Dictionary = production.capture_snapshot().value
	var blocked_hardware: Dictionary = access.devices[StringName(door_id)].actuator(PaidDoorConstruction.actuator_id(door_id)).to_record()
	ui_action(1, false)
	check(last.error_code == &"actuator_force_exceeded", "actual UI crowbar remains limited to 1000 N: %s" % last.error_code)
	# The real queue advances one simulation tick even when a command rejects.
	check(production._state.last_tick == int(blocked.last_tick) + 1, "rejected UI command advances exactly one tick")
	blocked.last_tick += 1
	check(production.capture_snapshot().value == blocked and room().gas_moles == retained and access.devices[StringName(door_id)].actuator(PaidDoorConstruction.actuator_id(door_id)).to_record() == blocked_hardware, "force rejection preserves all production, finite gas and actuator state")
	var snapshot: String = world.capture_world_snapshot_json().value
	var observation: Dictionary = production.observation(context).value
	reload_playable(snapshot, "reinforced three-owner JSON roundtrip")
	var fresh_request: StringName = world.next_local_request_id()
	for receipt in production._state.receipts:
		check(String(fresh_request) != receipt.request_id, "reloaded runtime cannot reuse saved UI request identity")
	check(room().gas_moles == retained and production._state.room_reinforcements == paid.room_reinforcements, "restore retains original paid kit, seal and finite gas")
	ui_action(9); step(20)
	reload_playable(world.capture_world_snapshot_json().value, "open reinforced bypass roundtrip")
	check(pressure_owner().room_valve_open(door_id), "open valve state survives strict reload")
	step(580); ui_action(10)
	check(pressure_owner().room_difference(door_id) <= PressureFlowSolver.EQUILIBRIUM_EPSILON_KPA and gas_conserved(initial), "passive paid bypass equalizes without gas creation")
	ui_action(1)
	check(access.devices[StringName(door_id)].actuator(PaidDoorConstruction.actuator_id(door_id)).position == 1.0, "same crowbar succeeds after deliberate equalization")
	ui_action(7); ui_action(13)
	check(production._state.store.plate == PaidRoomReinforcement.MASS and production._state.energy_joules == 56000 and production._state.room_reinforcements.is_empty(), "manual decommission and kit recovery refund exact bill with zero electrical work")
	bypass_reject("door_reinforcement_recover")
	ui_action(2); ui_action(6); ui_action(12)
	check(production._state.store.plate == 0 and production._state.energy_joules == 56000 and production._state.doors[door_id].seal.seal_id == paid.doors[door_id].seal.seal_id, "refit pays recovered plate without replacing or healing original seal")
	bypass_reject("door_seal_install")
	bypass_reject("door_seal_remove")
	reinforcement_negative_controls(snapshot)
	legacy_reinforcement_origin_checks()
	var fixture := FileAccess.open("res://var/room-reinforcement-fixture.json", FileAccess.WRITE)
	fixture.store_string(JSON.stringify({"world": JSON.parse_string(snapshot), "observation": observation, "pristine": pristine})); fixture.close()
	finish()


func finish() -> void:
	# Skip the parent's separate legacy equalization scenario.
	if is_instance_valid(world): world.free()
	quit(1 if failures else 0)


func ui_action(index: int, accepted: bool = true) -> void:
	var controls := PaidDoorControls.new()
	root.add_child(controls); controls.configure(world, context.principal_id); controls.set_process(false); controls._process(0.2)
	check(not controls._buttons[index].disabled, "real door UI operation available: %d" % index)
	controls._buttons[index].pressed.emit()
	check(not controls._pending.is_empty(), "UI enqueues authenticated door operation")
	step()
	check(last.is_success == accepted, "UI operation %d: %s" % [index, last.message])
	controls.free()


func reinforcement_negative_controls(snapshot: String) -> void:
	for mutation in ["bill", "seal", "policy", "area", "grant", "extra"]:
		var bad: Dictionary = JSON.parse_string(snapshot)
		match mutation:
			"bill": bad.systems.production.room_reinforcements[door_id].materials.plate += 1
			"seal": bad.systems.production.room_reinforcements[door_id].seal_id = "door-seal-foreign"
			"policy": bad.systems.pressure.constructed_rooms.values()[0].policy_id = ConstructedRoomPressure.POLICY
			"area":
				for device in bad.systems.access_control.devices:
					if device.device_id == door_id: device.actuators[0].effective_pressure_area_m2 = 0.0
			"grant": bad.systems.production.store.plate += PaidRoomReinforcement.MASS
			"extra": bad.systems.production.room_reinforcements[door_id].health = 1.0
		var target: WorldRuntime = FirstPlayableBootstrap.create_playable_world(true, false); root.add_child(target)
		var before: Variant = JSON.parse_string(target.capture_world_snapshot_json().value)
		check(not target.restore_world_snapshot_json(JSON.stringify(bad)).is_success, "cross-owner malformed restore rejects: " + mutation)
		check(same_json_value(before, JSON.parse_string(target.capture_world_snapshot_json().value)), "malformed restore preserves all owners: " + mutation)
		target.free()
	for entry in [[0.6, "intact"], [-0.6, "intact"], [110.1, "intact"], [0.6, "integrity"], [-0.6, "seal_condition"]]:
		var bad: Dictionary = JSON.parse_string(snapshot)
		var room_record: Dictionary = {}
		var ambient_record: Dictionary = {}
		for volume in bad.systems.pressure.volumes:
			if volume.volume_id == bad.systems.pressure.constructed_rooms.values()[0].volume_id: room_record = volume
			if volume.volume_id == "habitat_main": ambient_record = volume
		var factor: float = PressureVolumeState.GAS_CONSTANT_J_PER_MOL_K * float(room_record.temperature_kelvin) / 1000.0
		var current: float = factor * (float(room_record.gas_moles) / float(room_record.volume_m3) - float(ambient_record.gas_moles) / float(ambient_record.volume_m3))
		var shift: float = (float(entry[0]) - current) / (factor * (1.0 / float(room_record.volume_m3) + 1.0 / float(ambient_record.volume_m3)))
		room_record.gas_moles += shift; ambient_record.gas_moles -= shift
		for device in bad.systems.access_control.devices:
			if device.device_id == door_id and entry[1] != "intact": device.actuators[0][entry[1]] = 0.5
		var target: WorldRuntime = FirstPlayableBootstrap.create_playable_world(true, false); root.add_child(target)
		check(target.restore_world_snapshot_json(JSON.stringify(bad)).is_success, "finite isolated retention control restores")
		var gas: PressureSystem = target.get_simulation_system(PressureSystem.SYSTEM_ID)
		var owner: ProductionSimulationSystem = target.get_simulation_system(ProductionSimulationSystem.SYSTEM_ID)
		var actor := AuthenticatedCommandContext.for_local_development(context.principal_id, target.world_id, target.region_id)
		var before: Dictionary = owner.capture_snapshot().value
		var rejected: ServiceResult = owner.apply_local(actor, "reinforced-force-negative", "door_open", {"expected_revision": before.state_revision, "control_epoch": 0, "door_id": door_id}, int(bad.tick_number) + 1)
		check(not rejected.is_success and rejected.error_code == &"actuator_force_exceeded" and owner.capture_snapshot().value == before, "both signs/damage preserve unchanged force guard")
		var leaking: bool = gas.room_observation(door_id).leaking
		check(leaking == (absf(float(entry[0])) > 110.0 or entry[1] != "intact"), "overrating or supported assembly damage loses reinforced retention")
		if entry[1] != "intact":
			var hardware: ActuatorState = (target.get_simulation_system(AccessControlSystem.SYSTEM_ID) as AccessControlSystem).devices[StringName(door_id)].actuator(PaidDoorConstruction.actuator_id(door_id))
			check(hardware.get(entry[1]) == 0.5, "restore preserves supported Access damage")
			var detached: Dictionary = owner._state.duplicate(true)
			detached.room_reinforcements.clear(); detached.store.plate += PaidRoomReinforcement.MASS
			var device: AccessControlledDeviceState = (target.get_simulation_system(AccessControlSystem.SYSTEM_ID) as AccessControlSystem).devices[StringName(door_id)]
			check(not PaidRoomReinforcement.plan(detached, door_id, hardware, device, target.get_simulation_system(InventorySimulationSystem.SYSTEM_ID) as InventorySimulationSystem, actor, "damaged-refit", "door_reinforcement_install", gas).is_success and hardware.get(entry[1]) == 0.5, "refit rejects damaged assembly without healing")
		var before_gas: Dictionary = gas.capture_snapshot().value
		check(target.start_simulation().is_success, "start isolated retention control")
		var clock: SimulationRunner = target.get_node("SimulationRunner"); clock.set_physics_process(false); clock._physics_process(1.0 / 60.0)
		check((gas.capture_snapshot().value.volumes != before_gas.volumes) == leaking, "actual tick applies baseline leak when rating lost")
		target.free()


func legacy_reinforcement_origin_checks() -> void:
	var legacy: WorldRuntime = FirstPlayableBootstrap.create_playable_world(false); root.add_child(legacy)
	var owner: ProductionSimulationSystem = legacy.get_simulation_system(ProductionSimulationSystem.SYSTEM_ID)
	var before: Dictionary = owner.capture_snapshot().value
	check(before.schema_version == 12 and before.catalog_revision == 2 and not before.deposits.has("deposit.iron.reinforcement"), "explicit catalog2 route remains without new source")
	var saved: Dictionary = JSON.parse_string(legacy.capture_world_snapshot_json().value)
	check(legacy.restore_world_snapshot_json(JSON.stringify(saved)).is_success and owner.capture_snapshot().value == before, "catalog2 whole-world restore never grants reinforcement source")
	var actor := AuthenticatedCommandContext.for_local_development(&"local-inventory-target", legacy.world_id, legacy.region_id)
	check(not owner.apply_local(actor, "legacy-reinforcement-source", "mine", {"expected_revision": 0, "deposit_id": "deposit.iron.reinforcement"}, 1).is_success and owner.capture_snapshot().value == before, "absent source rejects without grant or indexing missing key")
	saved.systems.erase("production")
	check(legacy.restore_world_snapshot_json(JSON.stringify(saved)).is_success and owner._state.catalog_revision == 1 and not owner._state.deposits.has("deposit.iron.reinforcement"), "missing Production migration remains historical25kg without seam grant")
	legacy.free()
