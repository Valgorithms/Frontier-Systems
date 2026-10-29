extends "res://tests/godot/paid_door_lifecycle_test.gd"

## Same commissioning factory as actual playable host; no sockets or seed edits.
func run() -> void:
	world = FirstPlayableBootstrap.create_playable_world(false)
	root.add_child(world)
	world.command_completed.connect(func(_command: SimulationCommand, result: ServiceResult) -> void: last = result)
	check(world.start_simulation().is_success, "real playable initialization starts")
	runner = world.get_node("SimulationRunner")
	runner.set_physics_process(false)
	production = world.get_simulation_system(ProductionSimulationSystem.SYSTEM_ID)
	inventory = world.get_simulation_system(InventorySimulationSystem.SYSTEM_ID)
	access = world.get_simulation_system(AccessControlSystem.SYSTEM_ID)
	context = AuthenticatedCommandContext.for_local_development(&"local-inventory-target", world.world_id, world.region_id)
	check(inventory.authorize(context).value == "body.human-1", "default playable body1 onboarding")
	var pristine: Dictionary = production.capture_snapshot().value
	check(pristine.schema_version == 12 and pristine.catalog_revision == 2 and ProductionSimulationSystem._mass(pristine.deposits) == 32000000, "explicit32kg new origin")
	check(production.restore_snapshot_record(pristine, 0).is_success, "pristine new snapshot validates without refill")
	move([0, 0, 0])
	inventory_action("world", {"operation": "pickup", "item_id": "resource-canister-2", "world_container_id": "world.tray-1", "destination_container_id": "body.human-1", "slot_id": ""})
	inventory_action("self", {"operation": "equip", "item_id": "extractor-2", "source_container_id": "storage.backpack-1", "destination_container_id": "", "slot_id": "hand.right"})
	inventory_action("self", {"operation": "select_hand", "item_id": "", "source_container_id": "", "destination_container_id": "", "slot_id": "hand.right"})
	check(inventory.active_tool(context, "tool.extractor").is_success and inventory.owned_resource_carriers(context).value.has("resource-canister-2"), "real pickup/equip supplies authorized tools")
	if failures: finish(); return
	var intent: Dictionary = {"deposit_id": "deposit.iron.outcrop", "carrier_id": "resource-canister-2", "amount_milligrams": 1000000}
	reject_extraction(context, intent, "out of source reach")
	move([-3000, 0, -1000])
	var foreign_carrier: Dictionary = intent.duplicate(true)
	foreign_carrier.carrier_id = "resource-canister-1"
	reject_extraction(context, foreign_carrier, "foreign carrier with otherwise valid reach/tool")
	inventory_action("self", {"operation": "select_hand", "item_id": "", "source_container_id": "", "destination_container_id": "", "slot_id": "hand.left"})
	reject_extraction(context, intent, "no active extractor")
	inventory_action("self", {"operation": "select_hand", "item_id": "", "source_container_id": "", "destination_container_id": "", "slot_id": "hand.right"})
	move([0, 0, 0]); command("power", {"station": "drill", "enabled": false}); move([-3000, 0, -1000])
	reject_extraction(context, intent, "unpowered extraction")
	move([0, 0, 0]); command("power", {"station": "drill", "enabled": true})
	for batch in range(17):
		move([-3000, 0, -1000])
		var source: String = "deposit.iron" if batch < 10 else "deposit.iron.outcrop"
		var revision: int = production._state.state_revision
		command("tool_extract", {"deposit_id": source, "carrier_id": "resource-canister-2", "amount_milligrams": 1000000})
		if batch == 0:
			var exact: Dictionary = {"expected_revision": revision, "deposit_id": source, "carrier_id": "resource-canister-2", "amount_milligrams": 1000000}
			var retained: Dictionary = production.capture_snapshot().value
			check(production.apply_local(context, "machine-test-%d" % sequence, "tool_extract", exact, runner.tick_number + 1).is_success and production.capture_snapshot().value == retained, "exact retry spends no extra source/energy")
			var changed: Dictionary = exact.duplicate(true); changed.amount_milligrams = 1
			check(not production.apply_local(context, "machine-test-%d" % sequence, "tool_extract", changed, runner.tick_number + 1).is_success and production.capture_snapshot().value == retained, "changed-intent retry rejects without mutation")
			var stale: Dictionary = {"deposit_id": source, "carrier_id": "resource-canister-2", "amount_milligrams": 1000000, "expected_revision": revision}
			reject_extraction(context, stale, "stale revision")
		if batch == 10:
			var partial: String = world.capture_world_snapshot_json().value
			constrained_extraction_checks(partial)
			reload_playable(partial, "partly depleted outcrop whole-world roundtrip")
		move([0, 0, 0])
		command("unload_cargo", {"carrier_id": "resource-canister-2", "material": "ore.iron", "amount_milligrams": 1000000})
		command("process", {"recipe_id": "refine.iron"})
		step(120)
		if failures: finish(); return
	check_extractor_wear()
	check(production._state.store.iron == 10200000 and production._state.store.tailings == 6800000, "unchanged17 refinery yields conserve all ore")
	move([-3000, 0, -1000])
	var before: Dictionary = production.capture_snapshot().value
	command("tool_extract", {"deposit_id": "deposit.iron.outcrop", "carrier_id": "resource-canister-2", "amount_milligrams": 1000000}, false)
	check(production._state.deposits == before.deposits and production._state.store == before.store and production._state.energy_joules == before.energy_joules, "exhaustion rejects without material or energy debit")
	move([0, 0, 0])
	for batch in range(8):
		command("process", {"recipe_id": "craft.plate"})
		step(120)
	command("fabricate_equipment", {"blueprint_id": "equipment.crowbar"})
	inventory_action("self", {"operation": "unequip", "item_id": "", "source_container_id": "", "destination_container_id": "storage.backpack-1", "slot_id": "hand.right"})
	var crowbar: String = ""
	for item in inventory.own_inventory_observation(context).value.items:
		if item.definition_id == "item.crowbar.fabricated": crowbar = item.item_id
	equip(crowbar)
	if failures: finish(); return
	build_paid_geometry()
	if failures: finish(); return
	door_id = production._state.doors.keys()[0]
	door_command("door_seal_install", {"door_id": door_id})
	door_command("door_room_commission", {"door_id": door_id})
	if failures: finish(); return
	var final: Dictionary = production.capture_snapshot().value
	check(final.energy_joules == 68750 and final.store.iron == 200000 and final.store.plate == 200000 and final.store.tailings == 6800000, "complete room exact material and31250J energy budget")
	check(final.deposits["deposit.iron"] == 0 and final.deposits["deposit.iron.outcrop"] == 0 and final.deposits["deposit.ice"] == 5000000 and final.deposits["deposit.regolith"] == 10000000, "both sources deplete and unrelated matter untouched")
	var pressure: PressureSystem = world.get_simulation_system(PressureSystem.SYSTEM_ID)
	check(pressure.constructed_rooms.size() == 1, "actual paid room commissioned from acquired finite matter")
	var snapshot: String = world.capture_world_snapshot_json().value
	reload_playable(snapshot, "exhausted source and built room whole-world restore")
	check(production.capture_snapshot().value.deposits == final.deposits, "restore never refills exhausted seam")
	var projection := RemoteProductionProjection.new()
	check(projection.accept_record(production.observation(context).value).is_success, "new source observation accepts v14/catalog2")
	projection.free()
	var emitted := FileAccess.open("res://var/finite-bootstrap-fixture.json", FileAccess.WRITE)
	emitted.store_string(JSON.stringify({"world": JSON.parse_string(snapshot), "persistent": production.capture_snapshot().value, "observation": production.observation(context).value, "pristine": pristine}))
	emitted.close()
	legacy_and_malformed_checks(final)
	finish()


func inventory_action(operation: String, payload: Dictionary) -> void:
	sequence += 1
	var action := InventoryDevelopmentCommand.new()
	action.command_id = StringName("bootstrap-inventory-%d" % sequence)
	action.authenticated_context = context
	action.operation = operation
	action.payload = payload.duplicate(true)
	action.payload.expected_revision = inventory.own_inventory_observation(context, true).value.inventory_revision
	world.enqueue_command(action)
	step()
	check(last.is_success, "bootstrap inventory %s: %s" % [payload.operation, last.message])


func legacy_and_malformed_checks(final: Dictionary) -> void:
	for field in ["catalog_revision", "catalog_fingerprint", "schema_version", "deposits"]:
		var bad: Dictionary = final.duplicate(true)
		match field:
			"catalog_revision": bad.catalog_revision = 1
			"catalog_fingerprint": bad.catalog_fingerprint = "unknown"
			"schema_version": bad.schema_version = 13
			"deposits": bad.deposits["deposit.iron.outcrop"] = 7000000
		check(not production.restore_snapshot_record(bad, runner.tick_number).is_success and production.capture_snapshot().value == final, "invalid origin/refill rejects atomically: " + field)
	var historical := WorldRuntime.new()
	historical.resource_carriers_enabled = true
	root.add_child(historical)
	var owner: ProductionSimulationSystem = historical.get_simulation_system(ProductionSimulationSystem.SYSTEM_ID)
	var old: Dictionary = owner.capture_snapshot().value
	check(old.schema_version == 11 and old.catalog_revision == 1 and ProductionSimulationSystem._mass(old.deposits) == 25000000 and not old.deposits.has("deposit.iron.outcrop"), "historical origin has no new seam")
	check(owner.restore_snapshot_record(old, 0).is_success and owner.capture_snapshot().value == old, "historical25kg roundtrip unchanged")
	var upgrade: Dictionary = old.duplicate(true)
	upgrade.schema_version = 12; upgrade.catalog_revision = 2; upgrade.catalog_fingerprint = production._catalog_fingerprint
	check(not owner.restore_snapshot_record(upgrade, 0).is_success, "catalog upgrade cannot grant missing historical matter")
	var prior: Dictionary = owner.capture_snapshot().value
	var old_context := AuthenticatedCommandContext.for_local_development(&"local-inventory-target", historical.world_id, historical.region_id)
	check(not owner.apply_local(old_context, "legacy-outcrop-reject", "mine", {"expected_revision": 0, "deposit_id": "deposit.iron.outcrop"}, 1).is_success and owner.capture_snapshot().value == prior, "historical mounted mining cannot address absent source")
	var old_world: Dictionary = JSON.parse_string(historical.capture_world_snapshot_json().value)
	old_world.systems.erase("production")
	check(historical.restore_world_snapshot_json(JSON.stringify(old_world)).is_success and owner.capture_snapshot().value == old, "missing historical Production migrates without outcrop grant")
	historical.free()


func build_paid_geometry() -> void:
	for index in range(3): command("materialize_plate", {})
	if failures: return
	var plates: Array = production.observation(context).value["components"].duplicate()
	check(plates.size() == 3, "three finite physical wall plates for aperture layout")
	if failures: return
	move([5500, 0, -5500])
	if failures: return
	command("wall_build", {"item_id": plates[0], "position": [5500, 0, -4550], "quarter_turn": 0})
	if failures: return
	move([7000, 0, -5500]); move([7000, 0, -4000])
	if failures: return
	command("wall_build", {"item_id": plates[1], "position": [5950, 0, -4000], "quarter_turn": 1})
	if failures: return
	move([7000, 0, -6000]); move([7000, 0, -2500]); move([5500, 0, -2500])
	if failures: return
	command("wall_build", {"item_id": plates[2], "position": [5500, 0, -3450], "quarter_turn": 0})
	if failures: return
	move([7000, 0, -2500]); move([7000, 0, -4000])
	if failures: return
	command("panel_build", {"kind": "floor", "bounds_millimetres": [5100, 5900, -4500, -3500], "height_millimetres": 0})
	if failures: return
	command("panel_build", {"kind": "ceiling", "bounds_millimetres": [5100, 5900, -4500, -3500], "height_millimetres": 2000})
	if failures: return
	move([7000, 0, -6000]); move([3600, 0, -6000]); move([3600, 0, -4000])
	if failures: return
	command("panel_build", {"kind": "floor", "bounds_millimetres": [4100, 5100, -4500, -3500], "height_millimetres": 0})
	if failures: return
	door_command("door_build", {"position": [5050, 0, -4000], "quarter_turn": 1})
	if failures: return


func reject_extraction(actor: AuthenticatedCommandContext, payload: Dictionary, reason: String) -> void:
	var before: Dictionary = production.capture_snapshot().value
	var intent: Dictionary = payload.duplicate(true)
	if not intent.has("expected_revision"): intent.expected_revision = before.state_revision
	sequence += 1
	var tools: ToolSimulationSystem = world.get_simulation_system(ToolSimulationSystem.SYSTEM_ID)
	var before_tools: Dictionary = tools.capture_snapshot().value
	var before_inventory: Dictionary = inventory.capture_snapshot().value
	check(not production.apply_local(actor, "bootstrap-reject-%d" % sequence, "tool_extract", intent, runner.tick_number + 1).is_success, reason + " rejects")
	check(production.capture_snapshot().value == before and tools.capture_snapshot().value == before_tools and inventory.capture_snapshot().value == before_inventory, reason + " preserves all matter/energy/tool/inventory owners")


func check_extractor_wear() -> void:
	var tools: Dictionary = (world.get_simulation_system(ToolSimulationSystem.SYSTEM_ID) as ToolSimulationSystem).capture_snapshot().value
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/tools/catalog.v1.json"))
	for part_id in tools.ledger.assemblies["extractor-2"].slots.values():
		var part: Dictionary = tools.ledger.parts[part_id]
		var wear: int = int(catalog.materials[part.material_id].wear_ppm_per_cycle) * int(catalog.components[part.definition_id].wear_scale_permille) * 17
		check(int(part.integrity_ppm) == 1000000 - wear / 1000 and int(part.wear_remainder) == wear % 1000 and int(part.integrity_ppm) > 50000, "exact17-cycle wear needs no repair: " + part_id)


## Restore admission is deliberately pre-start; resume in a fresh composition root.
func reload_playable(snapshot: String, label: String) -> void:
	var target: WorldRuntime = FirstPlayableBootstrap.create_playable_world(false)
	root.add_child(target)
	var restored: ServiceResult = target.restore_world_snapshot_json(snapshot)
	check(restored.is_success, "%s: %s" % [label, restored.message])
	if not restored.is_success:
		target.free()
		return
	var restored_snapshot: String = target.capture_world_snapshot_json().value
	DirAccess.make_dir_recursive_absolute("res://var/ci/godot")
	for entry in [["candidate", snapshot], ["restored", restored_snapshot]]:
		var record := FileAccess.open("res://var/ci/godot/finite-bootstrap-roundtrip-%d-%s.json" % [runner.tick_number, entry[0]], FileAccess.WRITE)
		record.store_string(entry[1])
		record.close()
	var candidate_record: Variant = JSON.parse_string(snapshot)
	var restored_record: Variant = JSON.parse_string(restored_snapshot)
	check(same_json_value(candidate_record, restored_record), label + " preserves exact typed JSON values and array order")
	roundtrip_comparison_controls(candidate_record)
	world.free()
	world = target
	world.command_completed.connect(func(_command: SimulationCommand, result: ServiceResult) -> void: last = result)
	runner = world.get_node("SimulationRunner")
	production = world.get_simulation_system(ProductionSimulationSystem.SYSTEM_ID)
	inventory = world.get_simulation_system(InventorySimulationSystem.SYSTEM_ID)
	access = world.get_simulation_system(AccessControlSystem.SYSTEM_ID)
	check(world.start_simulation().is_success, label + " resumes restored simulation")
	runner.set_physics_process(false)


## Isolated negative fixtures never feed stock or energy into the positive route.
func constrained_extraction_checks(snapshot: String) -> void:
	for constraint in ["capacity", "energy"]:
		var candidate: Dictionary = JSON.parse_string(snapshot)
		var state: Dictionary = candidate.systems.production
		if constraint == "capacity":
			state.deposits["deposit.iron.outcrop"] -= 1000000
			state.cargo["resource-canister-2"]["ore.iron"] += 1000000
		else:
			state.energy_joules = 249
		var target: WorldRuntime = FirstPlayableBootstrap.create_playable_world(false)
		root.add_child(target)
		var restored: ServiceResult = target.restore_world_snapshot_json(JSON.stringify(candidate))
		check(restored.is_success, "isolated %s negative fixture validates: %s" % [constraint, restored.message])
		if not restored.is_success:
			target.free()
			return
		var owner: ProductionSimulationSystem = target.get_simulation_system(ProductionSimulationSystem.SYSTEM_ID)
		var before: String = target.capture_world_snapshot_json().value
		var result: ServiceResult = owner.apply_local(context, "bootstrap-" + constraint, "tool_extract", {"expected_revision": state.state_revision, "deposit_id": "deposit.iron.outcrop", "carrier_id": "resource-canister-2", "amount_milligrams": 1000000}, int(candidate.tick_number) + 1)
		var expected_message: String = "The receiving canister is full, incompatible or overpressure." if constraint == "capacity" else "Source mass, extractor power or finite energy is unavailable."
		check(not result.is_success and result.message == expected_message, "isolated %s rejects at intended resource guard: %s" % [constraint, result.message])
		check(not result.is_success and target.capture_world_snapshot_json().value == before, "isolated %s failure leaves every world owner unchanged" % constraint)
		target.free()


## JSON has one number type. Godot parses both N and N.0 as the same exact float;
## Inventory restore normalizes its integer contracts to native integers on write.
## Ignore object-key order only; no epsilon, coercion, field omission or array sort.
func same_json_value(left: Variant, right: Variant) -> bool:
	if typeof(left) != typeof(right): return false
	if typeof(left) == TYPE_DICTIONARY:
		if left.size() != right.size(): return false
		for key in left:
			if not right.has(key) or not same_json_value(left[key], right[key]): return false
		return true
	if typeof(left) == TYPE_ARRAY:
		if left.size() != right.size(): return false
		for index in range(left.size()):
			if not same_json_value(left[index], right[index]): return false
		return true
	if typeof(left) == TYPE_FLOAT and (not is_finite(left) or not is_finite(right)): return false
	return left == right


func roundtrip_comparison_controls(record: Dictionary) -> void:
	check(same_json_value(JSON.parse_string("{\"b\":1.0,\"a\":0}"), JSON.parse_string("{\"a\":0.0,\"b\":1}")), "only key order and equivalent JSON number spelling normalize")
	check(not same_json_value(JSON.parse_string("true"), JSON.parse_string("1")) and not same_json_value(JSON.parse_string("\"1\""), JSON.parse_string("1")), "comparison distinguishes bool/string/number")
	check(not same_json_value(JSON.parse_string("[1,2]"), JSON.parse_string("[2,1]")), "comparison preserves array ordering")
	for field in ["source", "energy", "receipt", "tool", "body", "tick", "missing", "extra", "array"]:
		var changed: Dictionary = record.duplicate(true)
		match field:
			"source": changed.systems.production.deposits["deposit.iron.outcrop"] += 1
			"energy": changed.systems.production.energy_joules += 1
			"receipt": changed.systems.production.receipts[0].fingerprint += "changed"
			"tool": changed.systems.tools.ledger.parts.values()[0].integrity_ppm -= 1
			"body": changed.systems.inventory.owner.bodies[0].profile_revision += 1
			"tick": changed.tick_number += 1
			"missing": changed.systems.production.erase("store")
			"extra": changed.systems.production["client_extra"] = 1
			"array": changed.systems.production.receipts.reverse()
		check(not same_json_value(record, changed), "exact world comparison rejects changed " + field)
