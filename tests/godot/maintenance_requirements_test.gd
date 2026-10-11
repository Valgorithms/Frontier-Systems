extends SceneTree

var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := WorldRuntime.new()
	world.resource_carriers_enabled = true
	root.add_child(world)
	check(world.start_simulation().is_success, "fixture starts")
	world.get_node("SimulationRunner").set_physics_process(false)
	var context := AuthenticatedCommandContext.for_local_development(&"local-inventory-actor", world.world_id, world.region_id)
	var tools := world.get_simulation_system(ToolSimulationSystem.SYSTEM_ID) as ToolSimulationSystem
	var production := world.get_simulation_system(ProductionSimulationSystem.SYSTEM_ID) as ProductionSimulationSystem
	var inventory := world.get_simulation_system(InventorySimulationSystem.SYSTEM_ID) as InventorySimulationSystem
	var saved: Dictionary = JSON.parse_string(world.capture_world_snapshot_json().value)
	var head: String = saved["systems"]["tools"]["ledger"]["assemblies"]["extractor-1"]["slots"]["head"]
	world.free()
	# Only fixtures introduce damage; no new runtime damage/repair authority.
	saved["systems"]["tools"]["ledger"]["parts"][head]["integrity_ppm"] = 500001
	world = WorldRuntime.new()
	world.resource_carriers_enabled = true
	root.add_child(world)
	check(world.restore_world_snapshot_json(JSON.stringify(saved)).is_success and world.start_simulation().is_success, "fixture restores")
	world.get_node("SimulationRunner").set_physics_process(false)
	tools = world.get_simulation_system(ToolSimulationSystem.SYSTEM_ID)
	production = world.get_simulation_system(ProductionSimulationSystem.SYSTEM_ID)
	inventory = world.get_simulation_system(InventorySimulationSystem.SYSTEM_ID)
	var before: String = world.capture_world_snapshot_json().value
	var observed: Dictionary = tools.observation(context).value
	var station: Dictionary = production.observation(context).value
	var quote: Dictionary = observed["maintenance"][head].duplicate(true)
	check(quote["restored_ppm"] == 499999 and quote["energy_joules"] == tools.prepare_repair(context, head, 1000000, observed["state_revision"]).value["energy_joules"], "quote matches paid planner including rounded partial integrity")
	check(world.capture_world_snapshot_json().value == before, "observation and detached plan never mutate persistence")
	check(ToolObservationValidation.valid(JSON.parse_string(JSON.stringify(observed))), "v3 serialized view accepted")
	check(ToolMaintenanceView.describe(observed, station, head).contains("material stock required: none") and ToolMaintenanceView.describe(observed, station, head).contains("success is not guaranteed"), "resource and uncertainty text")
	var insufficient: Dictionary = station.duplicate(true)
	insufficient["energy_joules"] = quote["energy_joules"] - 1
	check(ToolMaintenanceView.blocker(observed, insufficient, head).contains("Insufficient"), "full-maintenance insufficient energy advisory")
	var legacy: Dictionary = observed.duplicate(true)
	legacy["schema_version"] = 2
	legacy.erase("maintenance")
	check(ToolObservationValidation.valid(legacy) and ToolMaintenanceView.describe(legacy, station, head).contains("Energy quote unavailable"), "legacy v2 accepted without invented costs")
	for field in ["amount_ppm", "restored_ppm", "energy_joules", "materials"]:
		var bad: Dictionary = observed.duplicate(true)
		bad["maintenance"][head].erase(field)
		check(not ToolObservationValidation.valid(bad), "missing quote field rejects: " + field)
	for energy in [-1, 0, 100000001, 1.5, "50", true]:
		var bad: Dictionary = observed.duplicate(true)
		bad["maintenance"][head]["energy_joules"] = energy
		check(not ToolObservationValidation.valid(bad), "invalid paid quote rejects")
	for quotes in [{}, {head: {"amount_ppm": 1}}, {"unowned": quote}]:
		var bad: Dictionary = observed.duplicate(true)
		bad["maintenance"] = quotes
		check(not ToolObservationValidation.valid(bad), "incomplete or unowned quotes reject")
	var bad: Dictionary = observed.duplicate(true)
	bad["maintenance"][head]["restored_ppm"] += 1
	check(not ToolObservationValidation.valid(bad), "condition/quote disagreement rejects")
	bad = observed.duplicate(true)
	bad["maintenance"][head]["materials"] = {"iron": 1}
	check(not ToolObservationValidation.valid(bad), "invented material costs reject")
	var remote := RemoteWorldRuntime.new()
	root.add_child(remote)
	remote.set_process(false)
	remote._authenticated = true
	remote._receive(JSON.parse_string(JSON.stringify({"type": "observation", "tools": observed, "production": station, "terrain": world.terrain_observation(context).value, "inventory": inventory.own_inventory_observation(context, true).value, "position": [0, 0, 0], "players": []})))
	check(remote._observation.get("tools", {}) == observed, "real remote receive preserves authoritative quote")
	check(ToolMaintenanceView.describe(remote._observation["tools"], remote._observation["production"], head) == ToolMaintenanceView.describe(observed, station, head), "local/remote presentation parity")
	remote._connecting = true
	remote._process(0)
	check(remote._observation.is_empty(), "disconnect clears stale quote")
	remote.free()
	observed["maintenance"][head]["energy_joules"] = 1
	check(tools.observation(context).value["maintenance"][head] == quote, "returned quotes are detached")
	var other := AuthenticatedCommandContext.for_local_development(&"local-inventory-target", world.world_id, world.region_id)
	check(not tools.observation(other).value["maintenance"].has(head), "private component quotes do not leak to other body")
	var after: String = world.capture_world_snapshot_json().value
	world.free()
	var restored := WorldRuntime.new()
	restored.resource_carriers_enabled = true
	root.add_child(restored)
	check(restored.restore_world_snapshot_json(after).is_success and restored.start_simulation().is_success, "restart restores unchanged schema")
	restored.get_node("SimulationRunner").set_physics_process(false)
	check(restored.get_simulation_system(ToolSimulationSystem.SYSTEM_ID).observation(context).value["maintenance"][head] == quote, "restart derives same quote from persisted condition")
	restored.free()
	if failures == 0: print("Maintenance requirements: owner, schema rejection, legacy, local/remote, disconnect, restart and detached persistence passed.")
	quit(0 if failures == 0 else 1)


func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
