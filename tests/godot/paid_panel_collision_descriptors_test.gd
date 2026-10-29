extends "res://tests/godot/paid_horizontal_panels_test.gd"


func run() -> void:
	world = WorldRuntime.new()
	world.resource_carriers_enabled = true
	root.add_child(world)
	world.command_completed.connect(func(_command: SimulationCommand, result: ServiceResult) -> void: last = result)
	check(world.start_simulation().is_success, "finite owners start")
	runner = world.get_node("SimulationRunner")
	runner.set_physics_process(false)
	production = world.get_simulation_system(ProductionSimulationSystem.SYSTEM_ID)
	inventory = world.get_simulation_system(InventorySimulationSystem.SYSTEM_ID)
	context = AuthenticatedCommandContext.for_local_development(&"local-inventory-actor", world.world_id, world.region_id)
	check(geometry()["boxes"].is_empty(), "empty paid registry adds no fixture floor")
	for batch in range(6):
		move([-3000, 0, -1000])
		command("extract", {"deposit_id": "deposit.iron", "carrier_id": "resource-canister-1", "amount_milligrams": 1000000})
		move([0, 0, 0])
		command("unload_cargo", {"carrier_id": "resource-canister-1", "material": "ore.iron", "amount_milligrams": 1000000})
		command("process", {"recipe_id": "refine.iron"})
		step(120)
	for index in range(2):
		command("process", {"recipe_id": "craft.plate"})
		step(120)
	command("panel_build", intent("floor", [0, 800, 0, 1000]))
	var floor_id: String = state()["panels"].keys()[0]
	var builder: AuthenticatedCommandContext = context
	context = AuthenticatedCommandContext.for_local_development(&"local-inventory-target", world.world_id, world.region_id)
	command("panel_build", intent("ceiling", [0, 800, 0, 1000]))
	var complete: Dictionary = geometry()
	check(complete["boxes"].size() == 2, "complete geometry includes another builder's paid panel")
	check(production.observation(context).value["horizontal_panels"]["surfaces"].size() == 1, "public projection remains own-only")
	check(complete["world_id"] == String(world.world_id) and complete["region_id"] == String(world.region_id) and complete["coordinate_frame"] == "station_millimetres", "explicit scope and station coordinates")
	check(complete["production_revision"] == state()["state_revision"] and complete["production_tick"] == state()["last_tick"] and complete["inventory_tick"] == inventory.capture_snapshot().value["last_tick"], "current owner provenance")
	var ids: Array = []
	for box in complete["boxes"]:
		ids.append(box["surface_id"])
		check(box["size_millimetres"] == [800, 12, 1000], "bounded exact paid rectangle solid")
		check(box["center_millimetres"] == [400, -6 if box["kind"] == "floor" else 2006, 500], "floor top0 ceiling underside2000 extrusion")
		check(not box.has("principal_id") and not box.has("materials"), "internal stable geometry has no principal or material details")
	var sorted: Array = ids.duplicate()
	sorted.sort()
	check(ids == sorted and complete["profiling"]["inspected_panels"] == 2, "stable sorted bounded derivation")
	var before: Dictionary = state()
	var inventory_before: Dictionary = inventory.capture_snapshot().value
	check(geometry() == complete and state() == before and inventory.capture_snapshot().value == inventory_before, "repeat read deterministic and nonmutating")
	var detached: Dictionary = geometry()
	detached["boxes"][0]["center_millimetres"][0] = 999
	detached["boxes"].clear()
	check(geometry() == complete, "retained output mutation cannot alter owner or next read")
	for revision in [-1, true, float(before["state_revision"]), "1", null, ProductionSimulationSystem.MAX_REVISION + 1, int(before["state_revision"]) - 1]:
		check(not production.paid_panel_collision_descriptors(context, revision).is_success, "invalid or stale expected revision rejects")
	for foreign in [null, AuthenticatedCommandContext.for_local_development(&"foreign-actor", world.world_id, world.region_id), AuthenticatedCommandContext.for_local_development(context.principal_id, &"other-world", world.region_id), AuthenticatedCommandContext.for_local_development(context.principal_id, world.world_id, &"other-region"), AuthenticatedCommandContext.from_authenticated_session(context.principal_id, &"session", world.world_id, world.region_id, PackedStringArray())]:
		check(not production.paid_panel_collision_descriptors(foreign, before["state_revision"]).is_success, "missing identity/grant and foreign scope reject")
	var saved: String = world.capture_world_snapshot_json().value
	context = builder
	command("panel_remove", {"panel_id": floor_id})
	check(geometry()["boxes"].size() == 1 and complete["boxes"].size() == 2, "fresh removal read omits floor; old result remains nonauthoritative data")
	check(not production.paid_panel_collision_descriptors(context, complete["production_revision"]).is_success, "old revision rejected after removal")
	# Restore may reuse a revision. Re-derive from restored source, not a revision cache.
	world.stop_simulation()
	world.free()
	world = WorldRuntime.new()
	world.resource_carriers_enabled = true
	root.add_child(world)
	world.command_completed.connect(func(_command: SimulationCommand, result: ServiceResult) -> void: last = result)
	var restore: ServiceResult = world.restore_world_snapshot_json(saved)
	check(restore.is_success, "real whole-world restore succeeds: " + restore.message)
	if not restore.is_success:
		finish()
		return
	runner = world.get_node("SimulationRunner")
	production = world.get_simulation_system(ProductionSimulationSystem.SYSTEM_ID)
	inventory = world.get_simulation_system(InventorySimulationSystem.SYSTEM_ID)
	check(world.start_simulation().is_success, "restored world starts")
	runner.set_physics_process(false)
	check(geometry()["boxes"] == complete["boxes"], "restored current source reintroduces paid floor")
	var changed: Dictionary = state()
	changed["panels"][floor_id]["bounds_millimetres"] = [0, 1000, 0, 800]
	check(production.restore_snapshot_record(changed, runner.tick_number).is_success, "valid equal-bill alternate restore retains same revision")
	var restored: Dictionary = geometry()
	check(restored["production_revision"] == complete["production_revision"] and restored["boxes"] != complete["boxes"], "same revision restored geometry rederived without stale cache")
	check(not production.paid_panel_collision_descriptors(context, complete).is_success, "retained descriptor is not an input grant")
	var parent: Node = inventory.get_parent()
	parent.remove_child(inventory)
	check(not production.paid_panel_collision_descriptors(context, state()["state_revision"]).is_success, "detached owner rejects")
	parent.add_child(inventory)
	check(geometry()["boxes"] == restored["boxes"], "owner reattachment derives current state")
	var panels: Dictionary = state()["panels"]
	var malformed: Dictionary = panels.duplicate(true)
	malformed[floor_id]["materials"]["plate"] += 1
	check(not PaidPanelCollisionDescriptors.describe(malformed).is_success, "invalid paid bill fails closed")
	malformed = panels.duplicate(true)
	malformed[floor_id]["bounds_millimetres"][0] = 1
	check(not PaidPanelCollisionDescriptors.describe(malformed).is_success, "off-grid geometry fails closed")
	check(not PaidPanelCollisionDescriptors.describe([]).is_success, "non-registry input rejects")
	var capacity: Dictionary = {}
	for index in range(64):
		var tile: Dictionary = panels[floor_id].duplicate(true)
		tile["bounds_millimetres"] = [-100000 + index * 50, -99950 + index * 50, -100000, -99950]
		tile["materials"]["plate"] = 2500
		capacity["capacity-%d" % index] = tile
	var maximum: ServiceResult = PaidPanelCollisionDescriptors.describe(capacity)
	check(maximum.is_success and maximum.value.size() == 64 and maximum.value[0]["center_millimetres"] == [-99975, -6, -99975], "64 minimal boxes and negative exact centers")
	capacity["over-capacity"] = capacity["capacity-0"].duplicate(true)
	check(not PaidPanelCollisionDescriptors.describe(capacity).is_success, "65 panels reject before geometry")
	# Emitted fixtures come from actual owners, not hand-written result examples.
	var fixture := FileAccess.open("res://var/paid-panel-collision-fixture.json", FileAccess.WRITE)
	fixture.store_string(JSON.stringify({"complete": complete, "restored": restored, "current": geometry()}))
	fixture.close()
	print("Paid panel collision descriptors: %d failures" % failures)
	finish()


func geometry() -> Dictionary:
	var result: ServiceResult = production.paid_panel_collision_descriptors(context, state()["state_revision"])
	check(result.is_success, "current server geometry read succeeds: " + result.message)
	return result.value if result.is_success else {}
