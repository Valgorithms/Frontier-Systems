extends "res://tests/godot/paid_room_reinforcement_test.gd"

var inner_id: String
var outer_id: String
var original_spawn: Array
var transit_remote: RemoteWorldRuntime


## Real factory and finite resources; no positive-route owner/stock/gas writes.
func run() -> void:
	world = FirstPlayableBootstrap.create_playable_world()
	root.add_child(world)
	world.command_completed.connect(func(_command: SimulationCommand, result: ServiceResult) -> void: last = result)
	check(world.start_simulation().is_success, "fresh chamber factory starts")
	runner = world.get_node("SimulationRunner"); runner.set_physics_process(false)
	production = world.get_simulation_system(ProductionSimulationSystem.SYSTEM_ID)
	inventory = world.get_simulation_system(InventorySimulationSystem.SYSTEM_ID)
	access = world.get_simulation_system(AccessControlSystem.SYSTEM_ID)
	context = AuthenticatedCommandContext.for_local_development(&"local-inventory-target", world.world_id, world.region_id)
	original_spawn = inventory.own_position(context).value.duplicate()
	var pristine: Dictionary = production.capture_snapshot().value
	check(pristine.schema_version == 15 and pristine.catalog_revision == 4 and ProductionSimulationSystem._mass(pristine.deposits) == 54000000, "explicit finite 54kg origin")
	move([0, 0, 0])
	inventory_action("world", {"operation": "pickup", "item_id": "resource-canister-2", "world_container_id": "world.tray-1", "destination_container_id": "body.human-1", "slot_id": ""})
	inventory_action("self", {"operation": "equip", "item_id": "extractor-2", "source_container_id": "storage.backpack-1", "destination_container_id": "", "slot_id": "hand.right"})
	inventory_action("self", {"operation": "select_hand", "item_id": "", "source_container_id": "", "destination_container_id": "", "slot_id": "hand.right"})
	move([-3000, 0, -1000])
	catalog_extraction_paths(world.capture_world_snapshot_json().value)
	for batch in range(39):
		move([-3000, 0, -1000])
		var source: String = "deposit.iron" if batch < 10 else ("deposit.iron.outcrop" if batch < 17 else ("deposit.iron.reinforcement" if batch < 24 else "deposit.iron.chamber"))
		if batch == 24:
			var panel := ActorPanel.new(); panel.actor = context
			root.add_child(panel); panel.configure(world); panel.set_process(false)
			var found: int = -1
			for index in range(panel._deposit.item_count):
				if panel._deposit.get_item_text(index) == source: found = index
			check(found >= 0, "actual source selector exposes distinct chamber seam")
			if found >= 0: panel._deposit.select(found)
			panel.refresh(); check(not panel._extract_button.disabled, "held extractor can acquire selected chamber ore")
			panel.free()
		command("tool_extract", {"deposit_id": source, "carrier_id": "resource-canister-2", "amount_milligrams": 1000000})
		move([0, 0, 0])
		command("unload_cargo", {"carrier_id": "resource-canister-2", "material": "ore.iron", "amount_milligrams": 1000000})
		command("process", {"recipe_id": "refine.iron"}); step(120)
		if failures: finish(); return
	for batch in range(21): command("process", {"recipe_id": "craft.plate"}); step(120)
	command("fabricate_equipment", {"blueprint_id": "equipment.crowbar"})
	inventory_action("self", {"operation": "unequip", "item_id": "", "source_container_id": "", "destination_container_id": "storage.backpack-1", "slot_id": "hand.right"})
	var crowbar: String = ""
	for item in inventory.own_inventory_observation(context).value.items:
		if item.definition_id == "item.crowbar.fabricated": crowbar = item.item_id
	equip(crowbar)
	build_chamber()
	if failures: finish(); return
	var pair: ServiceResult = PaidChamber.candidate(production._state, String(context.principal_id), "body.human-1")
	check(pair.is_success, "exact paid two-door topology")
	if not pair.is_success: finish(); return
	inner_id = pair.value.inner_door_id; outer_id = pair.value.outer_door_id
	for id in [inner_id, outer_id]:
		door_id = id; door_command("door_seal_install", {"door_id": id})
		if id == inner_id: bypass_reject("door_bypass_install")
	for id in [inner_id, outer_id]:
		door_id = id; chamber_ui(8)
		if failures: finish(); return
	door_id = inner_id
	var insufficient: Dictionary = production._state.duplicate(true)
	insufficient.store.plate = PaidChamber.MASS - 1
	var stock_before: Dictionary = production.capture_snapshot().value
	check(not PaidChamber.plan(insufficient, inventory, access, context, "insufficient-chamber-kit", "door_chamber_kit_install", {"expected_revision": stock_before.state_revision, "control_epoch": 0, "door_id": inner_id}, pressure_owner()).is_success and production.capture_snapshot().value == stock_before, "kit cannot consume insufficient detached stock or change live owners")
	chamber_ui(14); chamber_ui(16)
	if failures: finish(); return
	var paid: Dictionary = production.capture_snapshot().value
	check(paid.energy_joules == 28250 and paid.store.plate == 600000 and paid.store.iron == 400000 and paid.store.tailings == 15600000, "39kg route accounts for20.4kg installed plate, crowbar and71750J")
	for source in ["deposit.iron", "deposit.iron.outcrop", "deposit.iron.reinforcement", "deposit.iron.chamber"]: check(paid.deposits[source] == 0, "source exhausted: " + source)
	check(paid.deposits["deposit.ice"] == 5000000 and paid.deposits["deposit.regolith"] == 10000000, "untouched non-ore origin")
	var initial_moles: float = all_moles()
	var snapshot: String = world.capture_world_snapshot_json().value
	var observation: Dictionary = production.observation(context).value
	var projection := RemoteProductionProjection.new()
	check(projection.accept_record(observation).is_success, "real complete v17 projection admits chamber controls")
	projection.free()
	observation_consumers(observation)
	chamber_negatives(snapshot)
	detached_chamber_controls(snapshot)
	legacy_chamber_origins()
	check_floor_contract()
	if failures: finish(); return
	# Genuine local body starts at the original observed spawn and walks the
	# actual first-playable preview. Command movement mirrors reached positions.
	move([3600, 0, -5500]); move(original_spawn)
	await physical_transit()
	if failures: finish(); return
	reload_playable(world.capture_world_snapshot_json().value, "whole chamber reload after both physical crossings")
	check(gas_conserved(initial_moles), "all finite volumes conserve total moles across transit and reload")
	var habitat_before: float = pressure_owner().volumes[PressureSystem.PROTOTYPE_HABITAT_ID].pressure_kpa()
	for cycle in range(2):
		door_id = inner_id; chamber_ui(9); step(600); chamber_ui(10)
		check(pressure_owner().room_difference(inner_id) < 0.59, "finite inner equalization permits manual force")
		chamber_ui(1); chamber_ui(2)
		door_id = outer_id; chamber_ui(9)
		var isolated: float = pressure_owner().volumes[PressureSystem.PROTOTYPE_HABITAT_ID].gas_moles
		step(600); chamber_ui(10)
		check(pressure_owner().volumes[PressureSystem.PROTOTYPE_HABITAT_ID].gas_moles == isolated, "outer vent isolates intact habitat boundary")
		check(pressure_owner().room_difference(outer_id) < 0.59, "finite outer equalization permits manual force")
		chamber_ui(1); chamber_ui(2)
		check(gas_conserved(initial_moles), "both-direction cycle conserves all gas")
	check(pressure_owner().volumes[PressureSystem.PROTOTYPE_HABITAT_ID].pressure_kpa() < habitat_before, "repeated cycles deplete finite habitat without refill")
	door_id = inner_id; bypass_reject("door_chamber_decommission")
	chamber_ui(9)
	reload_playable(world.capture_world_snapshot_json().value, "open inner bypass resume")
	check(pressure_owner().room_valve_open(inner_id), "open paired bypass survives reload")
	chamber_ui(10)
	var fixture := FileAccess.open("res://var/paid-chamber-fixture.json", FileAccess.WRITE)
	fixture.store_string(JSON.stringify({"world": JSON.parse_string(snapshot), "observation": observation, "pristine": pristine})); fixture.close()
	finish()


func build_chamber() -> void:
	for count in range(4): command("materialize_plate", {})
	var plates: Array = production.observation(context).value.components.duplicate()
	check(plates.size() == 4, "four actually acquired physical wall plates")
	if plates.size() != 4: return
	move([6000, 0, -5000])
	for index in range(2): command("wall_build", {"item_id": plates[index], "position": [5500 + index * 1000, 0, -4550], "quarter_turn": 0})
	move([8000, 0, -5500]); move([8000, 0, -2500]); move([6000, 0, -2500])
	for index in range(2): command("wall_build", {"item_id": plates[index + 2], "position": [5500 + index * 1000, 0, -3450], "quarter_turn": 0})
	move([8000, 0, -2500]); move([8000, 0, -4000])
	for bounds in [[6100, 7000, -4500, -3500], [7000, 7900, -4500, -3500]]: command("panel_build", {"kind": "floor", "bounds_millimetres": bounds, "height_millimetres": 0})
	for bounds in [[6100, 6900, -4500, -3500]]: command("panel_build", {"kind": "ceiling", "bounds_millimetres": bounds, "height_millimetres": 2000})
	move([8000, 0, -5500]); move([6000, 0, -5000])
	command("panel_build", {"kind": "floor", "bounds_millimetres": [5100, 6100, -4500, -3500], "height_millimetres": 0})
	command("panel_build", {"kind": "ceiling", "bounds_millimetres": [5100, 6100, -4500, -3500], "height_millimetres": 2000})
	move([3600, 0, -5500]); move([3600, 0, -4000])
	command("panel_build", {"kind": "floor", "bounds_millimetres": [4100, 5100, -4500, -3500], "height_millimetres": 0})
	door_command("door_build", {"position": [5050, 0, -4000], "quarter_turn": 1})
	move([3600, 0, -5500]); move([8000, 0, -5500]); move([8000, 0, -4000])
	door_command("door_build", {"position": [6950, 0, -4000], "quarter_turn": 1})
	move([8000, 0, -5500]); move([6000, 0, -5000])


func chamber_ui(index: int, accepted: bool = true) -> void:
	var controls := PaidDoorControls.new()
	root.add_child(controls); controls.configure(world, context.principal_id); controls.set_process(false)
	controls._process(0.2)
	for option in range(controls._doors.item_count):
		if controls._doors.get_item_metadata(option) == door_id: controls._doors.item_selected.emit(option)
	controls._process(0.2)
	check(not controls._buttons[index].disabled, "actual selected door action enabled: %d" % index)
	controls._buttons[index].pressed.emit()
	check(not controls._pending.is_empty(), "actual chamber UI queues authenticated intent")
	step(); check(last.is_success == accepted, "chamber UI%d %s: %s" % [index, door_id, last.message])
	controls.free()


func check_floor_contract() -> void:
	var full: Array[Dictionary] = []
	var short: Array[Dictionary] = []
	for id in production._state.panels:
		var panel: Dictionary = production._state.panels[id]
		full.append(HorizontalPanelConstruction.descriptor(id, panel))
		if panel.bounds_millimetres[0] < 7000: short.append(HorizontalPanelConstruction.descriptor(id, panel))
	for x in [4500, 5050, 5550, 6950, 7500]:
		var query: Dictionary = {"schema_version": 1, "expected_production_revision": 0, "footprint_millimetres": [x - 300, x + 300, -4300, -3700], "foot_height_millimetres": 0, "vertical_tolerance_millimetres": 10}
		check(HorizontalFloorSupportQuery.query(query, full, 0).value.supported, "full600mm footprint supported across both apertures:%d" % x)
		if x == 6950: check(not HorizontalFloorSupportQuery.query(query, short, 0).value.supported, "old short approach fails at outer aperture")


func physical_transit() -> void:
	host = RecordingHost.new(); root.add_child(host); host.set_process(false); host._world = world
	host._keys = ["chamber-actor-000000000000000000", "chamber-target-00000000000000000"]
	world.command_completed.connect(host._on_completed); connect_door_peer(1, 1)
	transit_remote = RemoteWorldRuntime.new(); root.add_child(transit_remote); transit_remote.set_process(false)
	transit_remote._receive({"type": "authenticated", "slot": 1, "world_id": String(world.world_id), "region_id": String(world.region_id)})
	var preview := ProceduralHabitatPreview.new(); root.add_child(preview)
	check(not preview._paid_worksite_legacy_collider.disabled, "normal preview retains its legacy wall collider")
	preview.focus_production()
	preview.production.observe(production.observation(context).value)
	check(preview._paid_worksite_legacy_collider.disabled and not preview._paid_worksite_legacy_wall.visible, "production focus removes only exact obsolete worksite obstruction")
	var doors := PaidDoorContactScene.new(); root.add_child(doors); doors.bind(transit_remote); doors.set_physics_process(false)
	var panels := PaidPanelContactScene.new(); root.add_child(panels); panels.bind(transit_remote); panels.set_physics_process(false)
	var cleanup := func() -> void:
		panels.free(); doors.free(); transit_remote.free(); preview.free(); host.free()
	transit_remote._receive(publish_door(1))
	var actor: LocalHabitatCharacter = preview.character
	actor.position = ProceduralWorldInventoryPreview.DISPLAY_ORIGIN + Vector3(float(original_spawn[0]), maxf(950.0, float(original_spawn[1])), float(original_spawn[2])) / 1000.0
	actor.rotation.y = 0.0; actor.read_local_keyboard = false; actor.set_navigation_enabled(true); actor.set_physics_process(false)
	await walk_to(actor, Vector2(-2.4, -3.5))
	if failures: cleanup.call(); return
	await walk_to(actor, Vector2(-1.5, -3.5))
	if failures: cleanup.call(); return
	await walk_to(actor, Vector2(-1.5, -2.0))
	if failures: cleanup.call(); return
	check(actor.is_on_floor(), "actual spawn-to-inner-approach route remains grounded")
	var closed_start: Vector3 = actor.position
	actor.set_motion_intent(Vector2.RIGHT, false)
	for frame in range(12): await physics_frame; actor._physics_process(1.0 / 60.0)
	check(actor.position.x < -1.25, "paid closed inner leaf blocks actual body after preview cleanup")
	actor.set_motion_intent(Vector2.ZERO, false)
	# Submit observed reached positions, never reposition the body after spawn.
	await walk_to(actor, Vector2(-1.5, -3.0))
	if failures: cleanup.call(); return
	await walk_to(actor, Vector2(-0.95, -3.0))
	if failures: cleanup.call(); return
	door_id = inner_id; chamber_ui(1)
	transit_remote._receive(publish_door(1)); await physics_frame
	# The opened q1 leaf occupies x[-1.85,-0.95], z[-2.45,-2.4].
	# Walk around its free end, retaining clearance for the whole body.
	await walk_to(actor, Vector2(-2.4, -3.0))
	if failures: cleanup.call(); return
	await walk_to(actor, Vector2(-2.4, -2.0))
	if failures: cleanup.call(); return
	await walk_to(actor, Vector2(-0.45, -2.0))
	if failures: cleanup.call(); return
	chamber_ui(2)
	check(actor.position.distance_to(closed_start) > 0.5 and actor.is_on_floor(), "actual600mm body crosses inner aperture onto chamber floor")
	door_id = outer_id; chamber_ui(9); step(600); chamber_ui(10); chamber_ui(1)
	transit_remote._receive(publish_door(1)); await physics_frame
	await walk_to(actor, Vector2(1.5, -2.0))
	if failures: cleanup.call(); return
	chamber_ui(2)
	check(actor.is_on_floor(), "actual body fully crosses outer aperture onto extended paid floor")
	# Return in the opposite direction with the same finite hardware/gas.
	chamber_ui(1); transit_remote._receive(publish_door(1)); await physics_frame
	await walk_to(actor, Vector2(-0.45, -2.0))
	if failures: cleanup.call(); return
	chamber_ui(2)
	door_id = inner_id; chamber_ui(9); step(600); chamber_ui(10); chamber_ui(1)
	transit_remote._receive(publish_door(1)); await physics_frame
	await walk_to(actor, Vector2(-2.4, -2.0))
	if failures: cleanup.call(); return
	await walk_to(actor, Vector2(-2.4, -3.0))
	if failures: cleanup.call(); return
	await walk_to(actor, Vector2(-0.95, -3.0))
	if failures: cleanup.call(); return
	chamber_ui(2)
	check(actor.is_on_floor(), "actual body returns through both supported apertures")
	# Move outside both sweeps for later isolated pressure cycles.
	await walk_to(actor, Vector2(-1.5, -3.5))
	if failures: cleanup.call(); return
	await walk_to(actor, Vector2(0.0, -3.0))
	if failures: cleanup.call(); return
	cleanup.call()


func walk_to(actor: LocalHabitatCharacter, destination: Vector2) -> void:
	for frame in range(150):
		var offset: Vector2 = destination - Vector2(actor.position.x, actor.position.z)
		if offset.length() < 0.04:
			actor.set_motion_intent(Vector2.ZERO, false)
			bridge_body(actor)
			return
		actor.set_motion_intent(offset.normalized() * minf(1.0, offset.length() * 10.0), false)
		await physics_frame
		actor._physics_process(1.0 / 60.0)
	actor.set_motion_intent(Vector2.ZERO, false)
	var contacts: Array[String] = []
	for index in range(actor.get_slide_collision_count()):
		var contact: KinematicCollision3D = actor.get_slide_collision(index)
		var collider: Object = contact.get_collider()
		contacts.append("%s at%s normal%s" % [collider.get_path() if collider is Node else str(collider), contact.get_position(), contact.get_normal()])
	check(false, "actual body reached continuous walking destination: %s, actual:%s, contacts:%s" % [destination, actor.position, contacts])


func bridge_body(actor: LocalHabitatCharacter) -> void:
	var point: Vector3 = (actor.position - ProceduralWorldInventoryPreview.DISPLAY_ORIGIN) * 1000.0
	move([roundi(point.x), roundi(point.y), roundi(point.z)])


func chamber_negatives(snapshot: String) -> void:
	door_id = inner_id
	for operation in ["door_chamber_kit_install", "door_chamber_kit_recover", "door_chamber_commission", "door_chamber_decommission", "door_remove", "door_seal_remove", "door_reinforcement_install", "door_bypass_recover"]: bypass_reject(operation)
	bypass_reject("door_bypass_open", {"control_epoch": 1})
	bypass_reject("door_bypass_open", {"expected_revision": production._state.state_revision - 1})
	bypass_reject("door_chamber_commission", {"gas_moles": 1})
	var own: AuthenticatedCommandContext = context
	bypass_reject("door_chamber_decommission", {"control_epoch": 1})
	var retained: Dictionary = production._state.receipts.back()
	var retry: Dictionary = {"expected_revision": int(retained.state_revision) - 1, "control_epoch": 0, "door_id": inner_id}
	var unchanged: Dictionary = production.capture_snapshot().value
	check(production.apply_local(context, retained.request_id, "door_chamber_commission", retry, runner.tick_number + 1).is_success and production.capture_snapshot().value == unchanged, "exact chamber receipt replay cannot allocate twice")
	retry.door_id = outer_id
	check(not production.apply_local(context, retained.request_id, "door_chamber_commission", retry, runner.tick_number + 1).is_success and production.capture_snapshot().value == unchanged, "changed chamber replay cannot redirect paired intent")
	context = AuthenticatedCommandContext.for_local_development(&"local-inventory-actor", world.world_id, world.region_id)
	bypass_reject("door_bypass_open"); context = own
	door_id = outer_id; bypass_reject("door_open")
	# The legacy synchronization hook may never bypass paid admission.
	access.update_actuator_position(StringName(outer_id), PaidDoorConstruction.actuator_id(outer_id), true)
	check(access.devices[StringName(outer_id)].actuator(PaidDoorConstruction.actuator_id(outer_id)).position == 0.0, "legacy low-level synchronization cannot open paid leaf")
	for mutation in ["bill", "endpoint", "policy", "half_kit", "half_valve", "orphan", "both_doors", "both_valves", "door_valve", "area", "owner", "float_bill", "extra"]:
		var bad: Dictionary = JSON.parse_string(snapshot)
		match mutation:
			"bill": bad.systems.production.chamber_kits[inner_id].materials.plate += 1
			"float_bill": bad.systems.production.chamber_kits[inner_id].materials.plate = 6000000.5
			"endpoint": bad.systems.pressure.paid_chamber.outer_endpoint = "habitat_main"
			"policy": bad.systems.pressure.paid_chamber.policy_id = ConstructedRoomPressure.POLICY
			"half_kit": bad.systems.production.chamber_kits.clear(); bad.systems.production.store.plate += PaidChamber.MASS
			"half_valve": bad.systems.pressure.room_valves.erase(outer_id)
			"orphan": bad.systems.pressure.paid_chamber.volume_id = "paid-chamber-orphan"
			"both_valves": bad.systems.pressure.room_valves[inner_id] = true; bad.systems.pressure.room_valves[outer_id] = true
			"owner": bad.systems.pressure.paid_chamber.body_id = "body.human-2"
			"extra": bad.systems.pressure.paid_chamber.retention_kpa = 1000
			_:
				for device in bad.systems.access_control.devices:
					if device.device_id in [inner_id, outer_id]:
						for actuator_record in device.actuators:
							if mutation == "area": actuator_record.effective_pressure_area_m2 = 0.0
							elif mutation == "both_doors" or device.device_id == inner_id: actuator_record.position = 1.0
				if mutation == "door_valve": bad.systems.pressure.room_valves[outer_id] = true
		var target: WorldRuntime = FirstPlayableBootstrap.create_playable_world(); root.add_child(target)
		var before: String = target.capture_world_snapshot_json().value
		check(not target.restore_world_snapshot_json(JSON.stringify(bad)).is_success, "malformed atomic paired restore rejects:" + mutation)
		check(target.capture_world_snapshot_json().value == before, "malformed paired restore preserves every owner/tick/epoch:" + mutation)
		target.free()
	door_id = inner_id


## Deliberately altered detached fixtures never fund the positive route.
func detached_chamber_controls(snapshot: String) -> void:
	var target: WorldRuntime = FirstPlayableBootstrap.create_playable_world(); root.add_child(target)
	check(target.restore_world_snapshot_json(snapshot).is_success, "isolated paired controls restore")
	var stock: ProductionSimulationSystem = target.get_simulation_system(ProductionSimulationSystem.SYSTEM_ID)
	var items: InventorySimulationSystem = target.get_simulation_system(InventorySimulationSystem.SYSTEM_ID)
	var hardware: AccessControlSystem = target.get_simulation_system(AccessControlSystem.SYSTEM_ID)
	var gas: PressureSystem = target.get_simulation_system(PressureSystem.SYSTEM_ID)
	var actor := AuthenticatedCommandContext.for_local_development(context.principal_id, target.world_id, target.region_id)
	# Reach uses trusted bound body pose, with identical legacy/real center semantics.
	for height in [0, 900]:
		items._bodies["body.human-1"].position_millimetres = [5450, height, -4000]
		check(PaidDoorConstruction.reachable(items, actor, [6950, 0, -4000]).is_success, "handle at exact1500mm accepted for y%d" % height)
		items._bodies["body.human-1"].position_millimetres = [5449, height, -4000]
		check(not PaidDoorConstruction.reachable(items, actor, [6950, 0, -4000]).is_success, "handle beyond1500mm rejected for y%d" % height)
	for principal in [&"unbound", &"local-inventory-actor"]:
		var foreign := AuthenticatedCommandContext.for_local_development(principal, target.world_id, target.region_id)
		check(not stock._admit_paid_open(inner_id, foreign).is_success, "foreign/unbound cannot borrow paid handle")
	var wrong_scope := AuthenticatedCommandContext.for_local_development(context.principal_id, &"wrong-world", target.region_id)
	check(not PaidDoorConstruction.reachable(items, wrong_scope, [6950, 0, -4000]).is_success, "handle rejects wrong world session")
	items._bodies["body.human-1"].position_millimetres = [6000, 900, -5000]
	var inner: AccessControlledDeviceState = hardware.devices[StringName(inner_id)]
	var outer: AccessControlledDeviceState = hardware.devices[StringName(outer_id)]
	var prepared := PreparedDoorChange.new(hardware, StringName(inner_id), inner, inner.to_record(), false)
	check(prepared.stage_device(StringName(outer_id), outer.to_record()).is_success, "stage second device without writes")
	outer.actuator(PaidDoorConstruction.actuator_id(outer_id)).seal_condition = 0.5
	var before: Dictionary = hardware.capture_snapshot().value
	check(not prepared.commit(hardware).is_success and hardware.capture_snapshot().value == before, "stale second CAS leaves both devices untouched")
	check(not prepared.commit(hardware).is_success, "failed paired commit remains consumed")
	check(not gas.validate_room_open(inner_id).is_success, "damaged opposite blocks opening")
	inner.actuator(PaidDoorConstruction.actuator_id(inner_id)).position = 1.0
	check(hardware.validate_door_actuation(StringName(inner_id), PaidDoorConstruction.actuator_id(inner_id), false, 0.0, true, actor).is_success, "damaged opposite never prevents own force-safe closing")
	target.free()
	for entry in [[0.6, "intact"], [-0.6, "intact"], [110.1, "intact"], [0.6, "integrity"], [-0.6, "seal_condition"]]:
		var bad: Dictionary = JSON.parse_string(snapshot)
		var room: Dictionary = {}; var habitat: Dictionary = {}
		for volume in bad.systems.pressure.volumes:
			if volume.volume_id == bad.systems.pressure.paid_chamber.volume_id: room = volume
			if volume.volume_id == "habitat_main": habitat = volume
		var factor: float = PressureVolumeState.GAS_CONSTANT_J_PER_MOL_K * float(room.temperature_kelvin) / 1000.0
		var current: float = factor * (float(room.gas_moles) / float(room.volume_m3) - float(habitat.gas_moles) / float(habitat.volume_m3))
		var shift: float = (float(entry[0]) - current) / (factor * (1.0 / float(room.volume_m3) + 1.0 / float(habitat.volume_m3)))
		room.gas_moles += shift; habitat.gas_moles -= shift
		for device in bad.systems.access_control.devices:
			if device.device_id == inner_id and entry[1] != "intact": device.actuators[0][entry[1]] = 0.5
		target = FirstPlayableBootstrap.create_playable_world(); root.add_child(target)
		check(target.restore_world_snapshot_json(JSON.stringify(bad)).is_success, "isolated finite chamber load restores")
		stock = target.get_simulation_system(ProductionSimulationSystem.SYSTEM_ID)
		gas = target.get_simulation_system(PressureSystem.SYSTEM_ID)
		actor = AuthenticatedCommandContext.for_local_development(context.principal_id, target.world_id, target.region_id)
		before = stock.capture_snapshot().value
		var rejected: ServiceResult = stock.apply_local(actor, "chamber-force-negative", "door_open", {"expected_revision": before.state_revision, "control_epoch": 0, "door_id": inner_id}, int(bad.tick_number) + 1)
		check(not rejected.is_success and rejected.error_code == &"actuator_force_exceeded" and stock.capture_snapshot().value == before, "both pressure signs preserve1000N manual limit")
		var leaking: bool = gas.room_observation(inner_id).leaking
		check(leaking == (absf(float(entry[0])) > 110.0 or entry[1] != "intact"), "chamber rating and damage independently govern retention")
		var moles_before: float = gas.volumes[StringName(gas.paid_chamber.volume_id)].gas_moles
		gas._step_paid_chamber(1.0 / 60.0)
		check((gas.volumes[StringName(gas.paid_chamber.volume_id)].gas_moles != moles_before) == leaking, "closed valves do not suppress boundary leak")
		if leaking:
			var closed_result: Dictionary = gas.capture_snapshot().value
			# Whole-world restore is startup-only; compare identical fixtures in
			# separate runtimes rather than attempting a second startup restore.
			target.free()
			target = FirstPlayableBootstrap.create_playable_world(); root.add_child(target)
			var reset: ServiceResult = target.restore_world_snapshot_json(JSON.stringify(bad))
			check(reset.is_success, "fresh runtime restores same finite leak control")
			if not reset.is_success: target.free(); return
			gas = target.get_simulation_system(PressureSystem.SYSTEM_ID)
			gas.room_valves[inner_id] = true
			gas._step_paid_chamber(1.0 / 60.0)
			check(gas.capture_snapshot().value.volumes == closed_result.volumes, "open valve plus leak uses one conductance")
		target.free()
	# A recovery-positive fixture deliberately equalizes all three finite endpoints.
	# It demonstrates the documented expensive precondition, never a vacuum refill.
	var low: Dictionary = JSON.parse_string(snapshot)
	var endpoints: Array = []
	var total_moles: float = 0.0; var total_volume: float = 0.0
	for volume in low.systems.pressure.volumes:
		if volume.volume_id in ["habitat_main", "exterior_reservoir", low.systems.pressure.paid_chamber.volume_id]:
			endpoints.append(volume); total_moles += float(volume.gas_moles); total_volume += float(volume.volume_m3)
	for volume in endpoints: volume.gas_moles = total_moles * float(volume.volume_m3) / total_volume
	target = FirstPlayableBootstrap.create_playable_world(); root.add_child(target)
	check(target.restore_world_snapshot_json(JSON.stringify(low)).is_success, "finite force-safe decommission fixture restores")
	stock = target.get_simulation_system(ProductionSimulationSystem.SYSTEM_ID)
	gas = target.get_simulation_system(PressureSystem.SYSTEM_ID)
	hardware = target.get_simulation_system(AccessControlSystem.SYSTEM_ID)
	actor = AuthenticatedCommandContext.for_local_development(context.principal_id, target.world_id, target.region_id)
	var seals: Dictionary = hardware.capture_snapshot().value
	var gas_before: float = 0.0
	for volume in gas.volumes.values(): gas_before += volume.gas_moles
	for operation in ["door_chamber_decommission", "door_chamber_kit_recover", "door_chamber_kit_install", "door_chamber_commission"]:
		if operation == "door_chamber_kit_recover":
			for reserved in [false, true]:
				var full: Dictionary = stock._state.duplicate(true)
				if reserved: full.job = {"outputs": {"plate": ProductionSimulationSystem.MAX_MASS}}
				else: full.store.tailings = ProductionSimulationSystem.MAX_MASS
				check(not PaidChamber.plan(full, target.get_simulation_system(InventorySimulationSystem.SYSTEM_ID), hardware, actor, "full-chamber-recovery", operation, {"expected_revision": full.state_revision, "control_epoch": 0, "door_id": inner_id}, gas).is_success, "recovery respects stock and reserved-output capacity")
			var damaged: ActuatorState = hardware.devices[StringName(outer_id)].actuator(PaidDoorConstruction.actuator_id(outer_id))
			damaged.integrity = 0.5
			var detached: Dictionary = stock._state.duplicate(true)
			check(not PaidChamber.plan(detached, target.get_simulation_system(InventorySimulationSystem.SYSTEM_ID), hardware, actor, "damaged-chamber-recovery", operation, {"expected_revision": detached.state_revision, "control_epoch": 0, "door_id": inner_id}, gas).is_success and damaged.integrity == 0.5, "recovery never heals a damaged original actuator")
			damaged.integrity = 1.0
		var result: ServiceResult = stock.apply_local(actor, "isolated-" + operation, operation, {"expected_revision": stock._state.state_revision, "control_epoch": 0, "door_id": inner_id}, int(low.tick_number) + 1)
		check(result.is_success, "force-safe recovery/refit: " + operation + ": " + result.message)
	check(stock._state.store.plate == 600000 and hardware.capture_snapshot().value == seals, "recover/refit conserves plate and original Access condition")
	var gas_after: float = 0.0
	for volume in gas.volumes.values(): gas_after += volume.gas_moles
	check(absf(gas_after - gas_before) < 1e-8, "decommission/refit never refills gas")
	target.free()


func catalog_extraction_paths(snapshot: String) -> void:
	var target: WorldRuntime = FirstPlayableBootstrap.create_playable_world(); root.add_child(target)
	check(target.restore_world_snapshot_json(snapshot).is_success, "isolated extraction catalog control restores actual equipped fixture")
	var owner: ProductionSimulationSystem = target.get_simulation_system(ProductionSimulationSystem.SYSTEM_ID)
	var actor := AuthenticatedCommandContext.for_local_development(context.principal_id, target.world_id, target.region_id)
	var before: Dictionary = owner.capture_snapshot().value
	var candidate: Dictionary = before.duplicate(true)
	check(owner._plan(candidate, "mine", {"expected_revision": before.state_revision, "deposit_id": "deposit.iron.chamber"}).is_success and candidate.job.outputs == {"ore.iron": 1000000}, "catalog4 scheduled mining resolves pinned source material")
	var reserved: ServiceResult = owner.apply_local(actor, "isolated-chamber-work", "start_tool_extract", {"expected_revision": before.state_revision, "deposit_id": "deposit.iron.chamber", "carrier_id": "resource-canister-2", "cycles": 1}, int(before.last_tick) + 1)
	check(reserved.is_success, "catalog4 timed extraction reserves actual seam: " + reserved.message)
	if reserved.is_success:
		check(target.start_simulation().is_success, "isolated extraction world starts")
		var clock: SimulationRunner = target.get_node("SimulationRunner"); clock.set_physics_process(false)
		for tick in range(ToolExtractionWork.CYCLE_TICKS + 1): clock._physics_process(1.0 / 60.0)
		check(owner._state.job.is_empty() and owner._state.deposits["deposit.iron.chamber"] == 14000000 and owner._state.cargo["resource-canister-2"]["ore.iron"] == 1000000, "timed completion resolves catalog4 with exact conserved output")
	target.free()


func observation_consumers(observation: Dictionary) -> void:
	var timed := TimedCanisterControls.new(); root.add_child(timed); timed.configure(world)
	var controls := HorizontalPanelControls.new(); root.add_child(controls); controls.configure(world)
	var preview := HorizontalPanelPreview.new(); root.add_child(preview)
	timed.observe(observation); controls.observe(observation); preview.observe(observation)
	check(not timed._record.is_empty() and not controls._record.is_empty() and preview._panels.size() == production._state.panels.size(), "fresh-world17 populates actual timed/panel controls and panel preview")
	var future: Dictionary = observation.duplicate(true); future.schema_version = 18
	timed.observe(future); controls.observe(future); preview.observe(future)
	check(timed._record.is_empty() and controls._record.is_empty() and preview._panels.is_empty() and not WorkstationResourceView.valid(future), "unsupported18 clears controls/preview and rejects resource projection")
	timed.free(); controls.free(); preview.free()
	check(not production.machine_recipe("extract.iron.chamber").is_empty(), "catalog4 machinery resolves distinct seam recipe")
	var exhausted: Dictionary = production._state.duplicate(true)
	var no_stock: ServiceResult = production._plan(exhausted, "extract", {"expected_revision": exhausted.state_revision, "deposit_id": "deposit.iron.chamber", "carrier_id": "resource-canister-2", "amount_milligrams": 1})
	check(not no_stock.is_success and exhausted.deposits["deposit.iron.chamber"] == 0, "exhausted chamber source cannot mint extra payload")


func legacy_chamber_origins() -> void:
	for mode in [false, true]:
		var legacy: WorldRuntime = FirstPlayableBootstrap.create_playable_world(mode, false); root.add_child(legacy)
		var owner: ProductionSimulationSystem = legacy.get_simulation_system(ProductionSimulationSystem.SYSTEM_ID)
		var before: Dictionary = owner.capture_snapshot().value
		check(before.catalog_revision == (3 if mode else 2) and not before.deposits.has("deposit.iron.chamber"), "explicit old factory receives no chamber source")
		var actor := AuthenticatedCommandContext.for_local_development(&"local-inventory-target", legacy.world_id, legacy.region_id)
		for operation in ["extract", "tool_extract", "start_tool_extract", "mine"]:
			check(not owner.apply_local(actor, "absent-chamber-" + operation, operation, {"expected_revision": 0, "deposit_id": "deposit.iron.chamber"}, 1).is_success and owner.capture_snapshot().value == before, "legacy catalog rejects absent chamber source without lookup/write:" + operation)
		check(owner.machine_recipe("extract.iron.chamber").is_empty(), "legacy machinery never advertises future source")
		var panel := ActorPanel.new(); panel.actor = actor; root.add_child(panel); panel.configure(legacy); panel.set_process(false)
		var seam_found: bool = false
		for option in range(panel._deposit.item_count): seam_found = seam_found or panel._deposit.get_item_text(option) == "deposit.iron.chamber"
		check(not seam_found, "legacy actual source selector excludes absent chamber seam")
		panel.free()
		check(legacy.restore_world_snapshot_json(legacy.capture_world_snapshot_json().value).is_success and owner.capture_snapshot().value == before, "legacy reload never grants chamber ore")
		legacy.free()
