extends "res://tests/godot/paid_door_lifecycle_test.gd"

func run() -> void:
	world = WorldRuntime.new()
	world.resource_carriers_enabled = true
	root.add_child(world)
	world.command_completed.connect(func(_command: SimulationCommand, result: ServiceResult) -> void: last = result)
	var started: ServiceResult = world.start_simulation()
	check(started.is_success, "finite seeded owner fixture starts")
	if failures: finish(); return
	if not started.is_success: finish(); return
	runner = world.get_node("SimulationRunner")
	runner.set_physics_process(false)
	production = world.get_simulation_system(ProductionSimulationSystem.SYSTEM_ID)
	inventory = world.get_simulation_system(InventorySimulationSystem.SYSTEM_ID)
	access = world.get_simulation_system(AccessControlSystem.SYSTEM_ID)
	context = AuthenticatedCommandContext.for_local_development(&"local-inventory-actor", world.world_id, world.region_id)
	# Explicit test-only finite input: 10kg plate + 3kg raw iron. Reclassify
	# 10kg fixture ore and 3kg fixture ice; retain total initial 25kg exactly.
	# This is not a recipe or an ore-to-room feasibility demonstration.
	var seed: Dictionary = production.capture_snapshot().value
	seed.deposits["deposit.iron"] = 0
	seed.deposits["deposit.ice"] = 2000000
	seed.store.plate = 10000000
	seed.store.iron = 3000000
	var initial_seed: ServiceResult = production.restore_snapshot_record(seed, runner.tick_number)
	check(not initial_seed.is_success and initial_seed.message == "Revision-zero production must retain its initial finite fixture state.", "revision-zero fixture reclassification rejects: %s" % initial_seed.message)
	if failures: finish(); return
	# Retain a real initiating command receipt before applying the authorized
	# test-only seed; never fabricate revision or receipt history.
	command("power", {"station": "printer", "enabled": true})
	if failures: finish(); return
	seed = production.capture_snapshot().value
	seed.deposits["deposit.iron"] = 0
	seed.deposits["deposit.ice"] = 2000000
	seed.store.plate = 10000000
	seed.store.iron = 3000000
	var restored_seed: ServiceResult = production.restore_snapshot_record(seed, runner.tick_number)
	check(restored_seed.is_success, "bounded 25kg total fixture seed validates: %s" % restored_seed.message)
	if failures: finish(); return
	if failures: finish(); return
	check(ProductionSimulationSystem._mass(seed.deposits) + ProductionSimulationSystem._mass(seed.store) == 25000000, "fixture provenance retains exact initial total")
	if failures: finish(); return
	command("fabricate_equipment", {"blueprint_id": "equipment.crowbar"})
	if failures: finish(); return
	var crowbar: String = ""
	for item in inventory.own_inventory_observation(context).value.items:
		if item.definition_id == "item.crowbar.fabricated": crowbar = item.item_id
	check(not crowbar.is_empty(), "real 2kg fabricated crowbar")
	if failures: finish(); return
	if failures: finish(); return
	equip(crowbar)
	if failures: finish(); return
	command("canister_reserve", {"job_id": "opening-reservation", "expected_reservation_revision": production.capture_snapshot().value.construction.revision, "control_epoch": 0})
	if failures: finish(); return
	var claims: int = ConstructionReservationPlan.claimed(production.capture_snapshot().value.construction)
	check(claims == 1000000, "one kg live raw iron claim")
	if failures: finish(); return
	if failures: finish(); return
	for index in range(3): command("materialize_plate", {})
	if failures: finish(); return
	var plates: Array = production.observation(context).value["components"].duplicate()
	check(plates.size() == 3, "three finite physical wall plates for aperture layout")
	if failures: finish(); return
	if plates.size() != 3: finish(); return
	move([5500, 0, -5500])
	if failures: finish(); return
	command("wall_build", {"item_id": plates[0], "position": [5500, 0, -4550], "quarter_turn": 0})
	if failures: finish(); return
	move([7000, 0, -5500]); move([7000, 0, -4000])
	if failures: finish(); return
	command("wall_build", {"item_id": plates[1], "position": [5950, 0, -4000], "quarter_turn": 1})
	if failures: finish(); return
	move([7000, 0, -6000]); move([7000, 0, -2500]); move([5500, 0, -2500])
	if failures: finish(); return
	command("wall_build", {"item_id": plates[2], "position": [5500, 0, -3450], "quarter_turn": 0})
	if failures: finish(); return
	move([7000, 0, -2500]); move([7000, 0, -4000])
	if failures: finish(); return
	command("panel_build", {"kind": "floor", "bounds_millimetres": [5100, 5900, -4500, -3500], "height_millimetres": 0})
	if failures: finish(); return
	command("panel_build", {"kind": "ceiling", "bounds_millimetres": [5100, 5900, -4500, -3500], "height_millimetres": 2000})
	if failures: finish(); return
	move([7000, 0, -6000]); move([3600, 0, -6000]); move([3600, 0, -4000])
	if failures: finish(); return
	command("panel_build", {"kind": "floor", "bounds_millimetres": [4100, 5100, -4500, -3500], "height_millimetres": 0})
	if failures: finish(); return
	door_command("door_build", {"position": [5050, 0, -4000], "quarter_turn": 1})
	if failures: finish(); return
	var state: Dictionary = production.capture_snapshot().value
	check(state.store.plate == 2400000 and state.store.iron == 1000000 and ConstructionReservationPlan.claimed(state.construction) == claims, "exact 7.6kg paid build debit preserves one kg iron claim")
	if failures: finish(); return
	var revision: int = state.state_revision
	var assessment: ServiceResult = production.construction_openings(context, revision)
	check(assessment.is_success and assessment.value.status == "enclosure_with_unsealed_openings", "shared canonical walls plus own finite paid surfaces and door participate")
	if failures: finish(); return
	check(assessment.is_success and assessment.value.door_ids.size() == 1 and not assessment.value.has("wall_ids") and not assessment.value.has("materials"), "owner query returns own door IDs and aggregate geometry only")
	if failures: finish(); return
	check(production.capture_snapshot().value == state, "query does not mutate canonical state")
	if failures: finish(); return
	for bad in [revision - 1, true, str(revision), float(revision) + 0.5, null, INF]:
		check(not production.construction_openings(context, bad).is_success, "bad expected revision rejects")
	var foreign := AuthenticatedCommandContext.for_local_development(&"foreign-aperture-actor", world.world_id, world.region_id)
	var denied: ServiceResult = production.construction_openings(foreign, revision)
	check(not denied.is_success and denied.value == null, "unbound principal receives no geometry")
	if failures: finish(); return
	for scope in [[&"other-world", world.region_id], [world.world_id, &"other-region"]]:
		var wrong_scope := AuthenticatedCommandContext.for_local_development(context.principal_id, scope[0], scope[1])
		denied = production.construction_openings(wrong_scope, revision)
		check(not denied.is_success and denied.value == null, "wrong world/region receives no geometry despite principal grant")
	# Detached internal state perturbations are negative controls only; always
	# restore before commands. They prove own-only inclusion and no revision cache.
	var panel_id: String = ""
	for key in state.panels:
		if state.panels[key].kind == "ceiling": panel_id = key
	var restored: Dictionary = state.duplicate(true)
	restored.panels[panel_id].principal_id = "foreign-panel-owner"
	check(production.restore_snapshot_record(restored, runner.tick_number).is_success, "valid same-revision restore with foreign ceiling")
	if failures: finish(); return
	revision = production.capture_snapshot().value.state_revision
	check(production.construction_openings(context, revision).value.status == "open_or_unsupported", "excluded foreign panel cannot complete enclosure at same revision")
	if failures: finish(); return
	check(production.restore_snapshot_record(state, runner.tick_number).is_success, "original same-revision owner state restores")
	if failures: finish(); return
	check(production.capture_snapshot().value.state_revision == revision, "both restored states expose identical revision despite different ownership")
	if failures: finish(); return
	assessment = production.construction_openings(context, revision)
	check(assessment.value.status == "enclosure_with_unsealed_openings", "real same-revision restore recomputes ownership and geometry")
	if failures: finish(); return
	state = production.capture_snapshot().value
	var id: String = state.doors.keys()[0]
	production._state.doors[id].principal_id = "foreign-door-owner"
	check(production.construction_openings(context, revision).value.door_ids.is_empty(), "excluded foreign door identity never leaks")
	if failures: finish(); return
	production._state = state.duplicate(true)
	production._state.doors[id].body_id = "different-body"
	check(production.construction_openings(context, revision).value.status == "open_or_unsupported", "same principal wrong bound body excluded")
	if failures: finish(); return
	production._state = state.duplicate(true)
	check(production.construction_openings(context, revision).value == assessment.value, "same-revision replacement derives fresh geometry")
	if failures: finish(); return
	for operation in ["door_open", "door_close"]:
		door_command(operation, {"door_id": id})
		check(production.construction_openings(context, production.capture_snapshot().value.state_revision).value.status == "enclosure_with_unsealed_openings", "leaf position never establishes a seal")
		check(production.construction_closure(context).value.status == "open_or_unsupported", "legacy closure excludes open and closed doorway")
	door_command("door_remove", {"door_id": id})
	if failures: finish(); return
	assessment = production.construction_openings(context, production.capture_snapshot().value.state_revision)
	check(assessment.value.status == "open_or_unsupported" and assessment.value.door_ids.is_empty(), "actual disassembly removes aperture immediately")
	if failures: finish(); return
	for key in production.capture_snapshot().value.panels.keys():
		if production.capture_snapshot().value.panels[key].bounds_millimetres[0] == 4100: command("panel_remove", {"panel_id": key})
	move([4000, 0, -6000]); move([7000, 0, -6000]); move([7000, 0, -4000])
	if failures: finish(); return
	for key in production.capture_snapshot().value.panels.keys(): command("panel_remove", {"panel_id": key})
	if failures: finish(); return
	var walls: Dictionary = production.capture_snapshot().value.walls
	for key in walls:
		if walls[key].position == [5950, 0, -4000]: command("wall_remove", {"wall_id": key})
	move([7000, 0, -5500]); move([5500, 0, -5500])
	if failures: finish(); return
	for key in walls:
		if walls[key].position == [5500, 0, -4550]: command("wall_remove", {"wall_id": key})
	move([7000, 0, -5500]); move([7000, 0, -2500]); move([5500, 0, -2500])
	if failures: finish(); return
	for key in walls:
		if walls[key].position == [5500, 0, -3450]: command("wall_remove", {"wall_id": key})
	move([0, 0, 0])
	if failures: finish(); return
	var plates_to_recover: Array = production.observation(context).value.components.duplicate()
	for item in plates_to_recover: command("recycle_component", {"item_id": item})
	if failures: finish(); return
	check(production.capture_snapshot().value.store.plate == 7000000 and production.capture_snapshot().value.store.iron == 4000000, "three recovered wall plates recycle to exactly three kg iron")
	if failures: finish(); return
	for index in range(3):
		command("process", {"recipe_id": "craft.plate"})
		step(120)
	state = production.capture_snapshot().value
	check(state.store.plate == 10000000 and state.store.iron == 1000000 and state.doors.is_empty() and state.panels.is_empty() and state.walls.is_empty(), "exact seeded plate refund after complete paid recovery")
	if failures: finish(); return
	check(ConstructionReservationPlan.claimed(state.construction) == claims, "query and recovery preserve active raw iron claim")
	if failures: finish(); return
	print("Paid doorway owner query: %d failures" % failures)
	finish()
