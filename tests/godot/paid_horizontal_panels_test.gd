extends "res://tests/godot/machinery_runtime_test.gd"


func run() -> void:
	world = WorldRuntime.new()
	world.resource_carriers_enabled = true
	root.add_child(world)
	world.command_completed.connect(func(_command: SimulationCommand, result: ServiceResult) -> void: last = result)
	check(world.start_simulation().is_success, "finite world starts")
	runner = world.get_node("SimulationRunner")
	runner.set_physics_process(false)
	production = world.get_simulation_system(ProductionSimulationSystem.SYSTEM_ID)
	inventory = world.get_simulation_system(InventorySimulationSystem.SYSTEM_ID)
	context = AuthenticatedCommandContext.for_local_development(&"local-inventory-actor", world.world_id, world.region_id)
	var old: Dictionary = production.capture_snapshot().value
	old.erase("panels")
	old["schema_version"] = 8
	check(production.validate_snapshot_record(old, 0).is_success, "save8 migrates to empty paid panels")
	check(production.restore_snapshot_record(old, 0).is_success and production.capture_snapshot().value["schema_version"] == 9, "save8 restores as save9")
	for batch in range(10):
		move([-3000, 0, -1000])
		command("extract", {"deposit_id": "deposit.iron", "carrier_id": "resource-canister-1", "amount_milligrams": 1000000})
		move([0, 0, 0])
		command("unload_cargo", {"carrier_id": "resource-canister-1", "material": "ore.iron", "amount_milligrams": 1000000})
		command("process", {"recipe_id": "refine.iron"})
		step(120)
	for index in range(4):
		command("process", {"recipe_id": "craft.plate"})
		step(120)
	command("canister_reserve", {"job_id": "panel-neighbor", "expected_reservation_revision": state()["construction"]["revision"], "control_epoch": 0})
	var claims: int = ConstructionReservationPlan.claimed(state()["construction"])
	command("panel_build", intent("floor", [500, 1400, -500, 500]))
	var dimension_id: String = state()["panels"].keys()[0]
	check(state()["panels"][dimension_id]["materials"] == {"plate": 900000}, "real900x1000 placement retains exact area bill")
	command("panel_remove", {"panel_id": dimension_id})
	check(ConstructionReservationPlan.claimed(state()["construction"]) == claims and state()["store"]["iron"] == 2000000, "panel debit/refund preserves active canister claim and iron stock")
	command("canister_cancel", {"job_id": "panel-neighbor", "expected_reservation_revision": state()["construction"]["revision"], "control_epoch": 0})
	for index in range(2):
		command("process", {"recipe_id": "craft.plate"})
		step(120)
	check(state()["store"]["plate"] == 6000000 and state()["store"]["iron"] == 0, "actual finite recipes produce six kg canonical plate stock")
	for index in range(4): command("materialize_plate", {})
	var plates: Array = production.observation(context).value["components"].duplicate()
	if plates.size() != 4: check(false, "four paid physical plates"); finish(); return
	move([5500, 0, -5500])
	command("wall_build", {"item_id": plates[0], "position": [5500, 0, -4550], "quarter_turn": 0})
	move([4000, 0, -5500])
	move([4000, 0, -4000])
	command("wall_build", {"item_id": plates[1], "position": [5050, 0, -4000], "quarter_turn": 1})
	move([4000, 0, -6000])
	move([7000, 0, -6000])
	move([7000, 0, -4000])
	command("wall_build", {"item_id": plates[2], "position": [5950, 0, -4000], "quarter_turn": 1})
	move([7000, 0, -2500])
	move([5500, 0, -2500])
	command("wall_build", {"item_id": plates[3], "position": [5500, 0, -3450], "quarter_turn": 0})
	check(closure()["interior_bounds_millimetres"] == [5100, 5900, -4500, -3500], "paid four-wall exact interior")
	var floor_intent: Dictionary = intent("floor", [5100, 5900, -4500, -3500])
	var floor_payload: Dictionary = floor_intent.duplicate(true)
	floor_payload["expected_revision"] = state()["state_revision"]
	command("panel_build", floor_intent)
	var build_id: String = "machine-test-%d" % sequence
	var floor_id: String = state()["panels"].keys()[0]
	check(state()["store"]["plate"] == 1200000, "800000mg area debit from real remaining stock")
	check(closure()["status"] == "open_or_unsupported", "missing paid ceiling does not close room")
	var before: Dictionary = stable()
	replay(build_id, "panel_build", floor_payload, true)
	check(stable() == before, "exact build retry does not debit again")
	var changed_payload: Dictionary = floor_payload.duplicate(true)
	changed_payload["kind"] = "ceiling"
	replay(build_id, "panel_build", changed_payload, false)
	replay("stale-panel", "panel_build", floor_payload, false)
	command("panel_build", floor_intent, false)
	for bounds in [[5100, 5950, -4500, -3500], [5100, 6200, -4500, -3500], [5101, 5900, -4500, -3500], [5100.5, 5900, -4500, -3500], [100000, 101000, 0, 1000], [5100, 5100, -4500, -3500]]:
		command("panel_build", intent("floor", bounds), false)
	var wrong_height: Dictionary = intent("ceiling", [5100, 5900, -4500, -3500])
	wrong_height["height_millimetres"] = 0
	command("panel_build", wrong_height, false)
	check(stable() == before, "overlap, stale, malformed and invalid bounds are atomic")
	var owner: AuthenticatedCommandContext = context
	context = AuthenticatedCommandContext.for_local_development(&"foreign-actor", world.world_id, world.region_id)
	command("panel_remove", {"panel_id": floor_id}, false)
	check(not production.construction_closure(context).is_success, "foreign actor has no query capability")
	context = owner
	command("panel_build", intent("ceiling", [5100, 5900, -4500, -3500]))
	check(closure()["status"] == "geometrically_closed", "actual paid walls and both paid surfaces close geometrically")
	before = stable()
	command("panel_build", intent("floor", [5100, 5900, -3500, -2500]), false)
	check(stable() == before, "insufficient finite plate stock cannot install an additional panel")
	check(state()["store"]["plate"] == 400000 and HorizontalPanelConstruction.mass(state()["panels"]) == 1600000, "six kg closes across four walls, two surfaces and400g stock")
	check(production.validate_snapshot_record(state(), runner.tick_number).is_success, "whole-world conservation validates")
	var projection := RemoteProductionProjection.new()
	check(projection.accept_record(production.observation(context).value).is_success, "observation9 remains compatible")
	projection.free()
	var saved: String = world.capture_world_snapshot_json().value
	var restored := WorldRuntime.new()
	restored.resource_carriers_enabled = true
	root.add_child(restored)
	check(restored.restore_world_snapshot_json(saved).is_success, "paid panels world JSON restores")
	var restored_production: ProductionSimulationSystem = restored.get_simulation_system(ProductionSimulationSystem.SYSTEM_ID)
	check(restored_production.capture_snapshot().value["panels"] == state()["panels"] and restored_production.capture_snapshot().value["store"] == state()["store"], "exact paid bills, IDs, ownership and provenance retained")
	check(restored_production.construction_closure(context).value["status"] == "geometrically_closed" and restored_production.construction_closure(context).value["production_revision"] == restored_production.capture_snapshot().value["state_revision"], "restored canonical closure uses current owner revision after reservation restore fence")
	restored.free()
	for field in ["materials", "blueprint_revision", "principal_id", "bounds_millimetres", "kind"]:
		var malformed: Dictionary = state().duplicate(true)
		malformed["panels"][floor_id][field] = {"plate": 1} if field == "materials" else null
		check(not production.validate_snapshot_record(malformed, runner.tick_number).is_success, "malformed saved " + field + " rejected")
	var overlapping: Dictionary = state().duplicate(true)
	for panel in overlapping["panels"].values():
		panel["kind"] = "floor"
		panel["height_millimetres"] = 0
	check(not production.validate_snapshot_record(overlapping, runner.tick_number).is_success, "saved same-plane overlap rejects despite conserved bill")
	var forged: Dictionary = state().duplicate(true)
	forged["panels"].erase(floor_id)
	check(not production.validate_snapshot_record(forged, runner.tick_number).is_success, "missing paid mass fails conservation")
	# Helper negative controls use detached copies, never canonical stock grants.
	var full: Dictionary = state().duplicate(true)
	full["store"]["plate"] = ProductionSimulationSystem.MAX_MASS
	check(not HorizontalPanelConstruction.plan(full, inventory, context, "full-refund", "panel_remove", {"expected_revision": 0, "panel_id": floor_id}).is_success, "refund capacity denied")
	full = state().duplicate(true)
	full["store"]["plate"] = ProductionSimulationSystem.MAX_MASS - ProductionSimulationSystem._mass(full["store"]) + int(full["store"]["plate"]) - 800000
	full["job"] = {"outputs": {"plate": 1}}
	check(not HorizontalPanelConstruction.plan(full, inventory, context, "reserved-refund", "panel_remove", {"expected_revision": 0, "panel_id": floor_id}).is_success, "reserved output capacity prevents refund")
	var occupied: Dictionary = state().duplicate(true)
	occupied["panels"] = {}
	for index in range(64):
		var tile: Dictionary = state()["panels"][floor_id].duplicate(true)
		tile["bounds_millimetres"] = [index * 50, index * 50 + 50, 0, 50]
		tile["materials"]["plate"] = 2500
		occupied["panels"]["capacity-%d" % index] = tile
	check(HorizontalPanelConstruction.valid(occupied["panels"]), "64 non-overlapping paid records meet bound")
	check(not HorizontalPanelConstruction.plan(occupied, inventory, context, "full-registry", "panel_build", floor_payload).is_success, "registry capacity denied")
	var dimensions: Dictionary = state()["panels"][floor_id].duplicate(true)
	dimensions["bounds_millimetres"] = [0, 900, 0, 1000]
	dimensions["materials"]["plate"] = 900000
	check(HorizontalPanelConstruction.valid({"paid-dimension": dimensions}), "general900x1000 paid bill valid")
	dimensions["materials"]["plate"] = 800000
	check(not HorizontalPanelConstruction.valid({"paid-dimension": dimensions}), "dimension bill mismatch denied")
	var remove_payload: Dictionary = {"expected_revision": state()["state_revision"], "panel_id": floor_id}
	command("panel_remove", {"panel_id": floor_id})
	var remove_id: String = "machine-test-%d" % sequence
	check(state()["store"]["plate"] == 1200000 and closure()["status"] == "open_or_unsupported", "removal refunds exact bill and opens closure")
	before = stable()
	replay(remove_id, "panel_remove", remove_payload, true)
	command("panel_remove", {"panel_id": floor_id}, false)
	check(stable() == before, "duplicate removal refunds once")
	# Retry history survives restore without reapplying refunded material.
	check(production.restore_snapshot_record(state(), runner.tick_number).is_success, "owner restore retains removal receipt")
	before = stable()
	replay(remove_id, "panel_remove", remove_payload, true)
	check(stable() == before, "restored exact retry refunds nothing")
	var fixture := FileAccess.open("res://var/paid-panels-fixture.json", FileAccess.WRITE)
	fixture.store_string(JSON.stringify({"persistent": state(), "legacy": old}))
	fixture.close()
	print("Paid horizontal panels: %d failures" % failures)
	finish()


func intent(kind: String, bounds: Array) -> Dictionary:
	return {"kind": kind, "bounds_millimetres": bounds, "height_millimetres": 0 if kind == "floor" else 2000}


func state() -> Dictionary:
	return production.capture_snapshot().value


func stable() -> Dictionary:
	var value: Dictionary = state()
	value.erase("last_tick")
	return value


func closure() -> Dictionary:
	var result: ServiceResult = production.construction_closure(context)
	check(result.is_success, "canonical closure query succeeds")
	return result.value if result.is_success else {}


func replay(id: String, operation: String, payload: Dictionary, success: bool) -> void:
	var action := ProductionDevelopmentCommand.new()
	action.command_id = StringName(id)
	action.authenticated_context = context
	action.operation = operation
	action.payload = payload.duplicate(true)
	world.enqueue_command(action)
	step()
	check(last.is_success == success, "exact replay/stale control: " + last.message)
