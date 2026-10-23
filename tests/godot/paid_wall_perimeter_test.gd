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
	# Consume the complete finite 10 kg iron source: 6 kg iron plus 4 kg tailings.
	for batch in range(10):
		move([-3000, 0, -1000])
		command("extract", {"deposit_id": "deposit.iron", "carrier_id": "resource-canister-1", "amount_milligrams": 1000000})
		move([0, 0, 0])
		command("unload_cargo", {"carrier_id": "resource-canister-1", "material": "ore.iron", "amount_milligrams": 1000000})
		command("process", {"recipe_id": "refine.iron"})
		step(120)
	for index in range(6):
		command("process", {"recipe_id": "craft.plate"})
		step(120)
		command("materialize_plate", {})
	var plates: Array = production.observation(context).value["components"].duplicate()
	check(plates.size() == 6, "six physical plates paid from finite stock")
	if plates.size() != 6: finish(); return
	var poses: Array = [
		{"position": [5500, 0, -4550], "quarter_turn": 0},
		{"position": [6500, 0, -4550], "quarter_turn": 0},
		{"position": [5050, 0, -4000], "quarter_turn": 1},
		{"position": [6950, 0, -4000], "quarter_turn": 1},
		{"position": [5500, 0, -3450], "quarter_turn": 0},
		{"position": [6500, 0, -3450], "quarter_turn": 0}]
	move([6000, 0, -5500])
	build(plates[0], {"position": [5500, 0, -4500], "quarter_turn": 0})
	var legacy_walls: Dictionary = production.capture_snapshot().value["walls"]
	var legacy_world := WorldRuntime.new()
	legacy_world.resource_carriers_enabled = true
	root.add_child(legacy_world)
	check(legacy_world.restore_world_snapshot_json(world.capture_world_snapshot_json().value).is_success, "existing 100 mm grid save restores unchanged")
	check((legacy_world.get_simulation_system(ProductionSimulationSystem.SYSTEM_ID) as ProductionSimulationSystem).capture_snapshot().value["walls"] == legacy_walls, "legacy 100 mm save retains its original ID and pose")
	legacy_world.free()
	command("wall_remove", {"wall_id": legacy_walls.keys()[0]})
	for id in production.observation(context).value["components"]:
		if not plates.has(id): plates[0] = id
	for index in range(2): build(plates[index], poses[index])
	move([4000, 0, -5500])
	move([4000, 0, -4000])
	build(plates[2], poses[2])
	move([4000, 0, -6000])
	move([8000, 0, -6000])
	move([8000, 0, -4000])
	# 50 mm penetration at a corner must reject and preserve the last three plates.
	var before: Dictionary = stable_production()
	command("wall_build", {"item_id": plates[3], "position": [6950, 0, -4050], "quarter_turn": 1}, false)
	check(stable_production() == before, "corner overlap is atomic and does not spend stock or IDs")
	build(plates[3], poses[3])
	move([8000, 0, -2500])
	move([6000, 0, -2500])
	build(plates[4], poses[4])
	check(topology(production).value.status == "open_or_unsupported", "missing paid panel grants no perimeter")
	before = stable_production()
	for invalid in [[6500.5, 0, -3450], [6501, 0, -3450], [100050, 0, 0], [6500, 50, -3450]]:
		command("wall_build", {"item_id": plates[5], "position": invalid, "quarter_turn": 0}, false)
	check(stable_production() == before, "fractional, off-grid, out-of-bounds and elevated intents preserve stock")
	var owner_context: AuthenticatedCommandContext = context
	context = AuthenticatedCommandContext.for_local_development(&"local-inventory-target", world.world_id, world.region_id)
	move([6000, 0, -2500])
	build(plates[5], poses[5], false)
	context = owner_context
	check(stable_production() == before, "other crew cannot spend the owned last plate")
	# A UI preview/cancel at the actual final 50 mm pose changes neither owner.
	var panel := MachineryPanel.new()
	root.add_child(panel)
	panel.configure(world)
	panel.observe({"production": production.observation(context).value, "inventory": inventory.own_inventory_observation(context).value, "position": inventory.own_position(context).value})
	panel._placement_kind.select(1)
	panel._placement_kind.item_selected.emit(1)
	panel._axes[0].value = 6.5
	panel._axes[2].value = -3.45
	var preview_before: String = world.capture_world_snapshot_json().value
	panel._new_wall.pressed.emit()
	panel._cancel_wall.pressed.emit()
	check(not panel._show_placement.button_pressed and is_equal_approx(panel._axes[2].value, -3.45), "cancel retains exact 50 mm draft")
	check(world.capture_world_snapshot_json().value == preview_before, "preview cancel submits no command and changes no canonical state")
	panel.free()
	# Deliberately leave a 50 mm corner gap using a valid paid placement.
	build(plates[5], {"position": [6550, 0, -3450], "quarter_turn": 0})
	check(topology(production).value.status == "open_or_unsupported", "canonical 50 mm gap grants no perimeter")
	var gap_walls: Dictionary = production.capture_snapshot().value["walls"]
	var last_id: String = wall_at(gap_walls, [6550, 0, -3450])
	command("wall_remove", {"wall_id": last_id})
	var recovered: Array = production.observation(context).value["components"]
	check(recovered.size() == 1 and recovered[0] != plates[5], "gap removal recovers exactly one receipt-derived plate")
	if recovered.size() != 1: finish(); return
	build(recovered[0], poses[5])
	var closed: ServiceResult = topology(production)
	check(closed.is_success and closed.value.status == "closed_wall_perimeter", "actual six paid canonical panels close exact corners")
	check(closed.value.interior_bounds_millimetres == [5100, 6900, -4500, -3500] and closed.value.required_surfaces == ["floor", "ceiling"], "exact interior still requires floor and ceiling")
	var paid: Dictionary = production.capture_snapshot().value
	check(paid["walls"].size() == 6 and paid["cargo"].size() == 2 and paid["store"]["plate"] == 0 and paid["store"]["iron"] == 0 and paid["store"]["tailings"] == 4000000 and paid["deposits"]["deposit.iron"] == 0, "six kilograms in walls plus four in tailings closes finite iron budget")
	check(production.validate_snapshot_record(paid, runner.tick_number).is_success, "complete fixture conservation validates")
	check(not SpatialWallConstruction.motion_clear(paid["walls"], [6000, 0, -2500], [6000, 0, -4000]), "closed south seam blocks swept body entry")
	var saved: String = world.capture_world_snapshot_json().value
	var restored := WorldRuntime.new()
	restored.resource_carriers_enabled = true
	root.add_child(restored)
	check(restored.restore_world_snapshot_json(saved).is_success, "paid 50 mm perimeter restores through JSON")
	var restored_production: ProductionSimulationSystem = restored.get_simulation_system(ProductionSimulationSystem.SYSTEM_ID)
	check(restored_production.capture_snapshot().value["walls"] == paid["walls"], "restore retains every stable wall ID and exact pose")
	check(topology(restored_production).value == closed.value, "restored canonical descriptors retain exact topology and revision")
	restored.free()
	var projection := RemoteProductionProjection.new()
	check(projection.accept_record(production.observation(context).value).is_success, "client accepts 50 mm authoritative observation")
	projection.free()
	for offset in [1, 0.5, 100050]:
		var forged: Dictionary = JSON.parse_string(saved)
		forged["systems"]["production"]["walls"][paid["walls"].keys()[0]]["position"][0] = offset
		restored = WorldRuntime.new()
		restored.resource_carriers_enabled = true
		root.add_child(restored)
		check(not restored.restore_world_snapshot_json(JSON.stringify(forged)).is_success, "malformed or out-of-bounds wall restore rejects")
		restored.free()
	# Removal of all paid panels recovers six plates, no seventh plate on retry.
	for id in paid["walls"]:
		var pose: Dictionary = paid["walls"][id]
		var position: Array = pose["position"]
		var approach: Array = position.duplicate()
		if int(pose["quarter_turn"]) == 0:
			approach[2] += -1000 if int(position[2]) < -4000 else 1000
		else:
			approach[0] += -1000 if int(position[0]) < 6000 else 1000
		# Above-wall transit avoids crossing the remaining perimeter.
		move([6000, 4000, -2500])
		move([approach[0], 4000, approach[2]])
		move(approach)
		command("wall_remove", {"wall_id": id})
		command("wall_remove", {"wall_id": id}, false)
	check(production.capture_snapshot().value["walls"].is_empty() and production.observation(context).value["components"].size() == 6, "dismantling returns exactly six conserved plates")
	print("Paid wall perimeter: %d failures" % failures)
	finish()


func build(plate: String, pose: Dictionary, success: bool = true) -> void:
	var payload: Dictionary = pose.duplicate(true)
	payload["item_id"] = plate
	command("wall_build", payload, success)


func topology(owner: ProductionSimulationSystem) -> ServiceResult:
	var described: ServiceResult = owner.construction_boundaries(context)
	check(described.is_success, "canonical boundary adapter accepts paid registry")
	return ConstructedRoomTopology.assess(described.value) if described.is_success else described


func wall_at(walls: Dictionary, position: Array) -> String:
	for id in walls:
		if walls[id]["position"] == position: return id
	return ""


func stable_production() -> Dictionary:
	var result: Dictionary = production.capture_snapshot().value
	result.erase("last_tick")
	return result
